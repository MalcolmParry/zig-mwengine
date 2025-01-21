const std = @import("std");
const Event = @import("../Event.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

pub const Window = struct {
    display: *c.Display,
    window: c.Window,
    wmDeleteMessage: c.Atom,

    pub fn Create(class: []const u8, title: []const u8, width: u32, height: u32) !Window {
        var this: Window = undefined;

        this.display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;
        errdefer _ = c.XCloseDisplay(this.display);

        this.window = c.XCreateSimpleWindow(this.display, c.XDefaultRootWindow(this.display), 0, 0, width, height, 0, 0, 0);
        if (this.window == 0) return error.FailedToCreateWindow;
        errdefer _ = c.XDestroyWindow(this.display, this.window);

        this.wmDeleteMessage = c.XInternAtom(this.display, "WM_DELETE_WINDOW", 0);
        if (this.wmDeleteMessage == c.None) return error.FailedToCreateAtom;

        const ntClass = try std.heap.c_allocator.dupeZ(u8, class);
        defer std.heap.c_allocator.free(ntClass);

        const ntTitle = try std.heap.c_allocator.dupeZ(u8, title);
        defer std.heap.c_allocator.free(ntTitle);

        const classHint = c.XAllocClassHint();
        if (classHint == null) return error.OutOfMemory;
        defer _ = c.XFree(classHint);
        classHint.*.res_name = ntTitle;
        classHint.*.res_class = ntClass;
        if (c.XSetClassHint(this.display, this.window, classHint) == 0) return error.FailedToSetWindowClass;

        if (c.XSetWMProtocols(this.display, this.window, &this.wmDeleteMessage, 1) == 0) return error.FailedToSetProtocols;
        if (c.XMapWindow(this.display, this.window) == 0) return error.FailedToMapWindow;
        if (c.XSync(this.display, 0) == 0) return error.FailedToSync;

        return this;
    }

    pub fn Destroy(this: *const Window) void {
        _ = c.XDestroyWindow(this.display, this.window);
        _ = c.XCloseDisplay(this.display);
    }

    pub fn SetTitle(this: *const Window, title: []const u8) !void {
        const alloc = std.heap.c_allocator;
        const titleC = try alloc.dupeZ(u8, title);
        defer alloc.free(titleC);

        if (c.XStoreName(this.display, this.window, titleC) == 0) return error.FailedToSetTitle;
        if (c.XFlush(this.display) == 0) return error.FailedToFlush;
    }

    pub fn EventPending(this: *const Window) bool {
        return c.XPending(this.display) != 0;
    }

    pub fn PopEvent(this: *const Window) ?Event.Event {
        if (c.XPending(this.display) == 0)
            return null;

        var event: c.XEvent = undefined;
        _ = c.XNextEvent(this.display, &event);

        switch (event.type) {
            c.ClientMessage => {
                if (event.xclient.data.l[0] == this.wmDeleteMessage)
                    return .{ .type = Event.Event.Type.Closed };
            },
            else => {},
        }

        return null;
    }
};
