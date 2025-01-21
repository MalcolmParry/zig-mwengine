const std = @import("std");
const Event = @import("../Event.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

pub const Window = struct {
    display: *c.Display,
    window: c.Window,
    wmDeleteMessage: c.Atom,

    pub fn Create(width: u32, height: u32) !Window {
        var this: Window = undefined;

        this.display = c.XOpenDisplay(null).?;
        this.window = c.XCreateSimpleWindow(this.display, c.XDefaultRootWindow(this.display), 0, 0, width, height, 0, 0, 0);
        this.wmDeleteMessage = c.XInternAtom(this.display, "WM_DELETE_WINDOW", 0);

        _ = c.XSetWMProtocols(this.display, this.window, &this.wmDeleteMessage, 1);
        _ = c.XMapWindow(this.display, this.window);
        _ = c.XSync(this.display, 0);

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

        _ = c.XStoreName(this.display, this.window, titleC);
        _ = c.XFlush(this.display);
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
