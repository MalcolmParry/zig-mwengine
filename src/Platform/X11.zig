const std = @import("std");
const Event = @import("../Event.zig");
const VK = @import("../RenderAPI/Vulkan.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

pub const Window = struct {
    _display: *c.Display,
    _window: c.Window,
    _wmDeleteMessage: c.Atom,

    pub fn Create(class: []const u8, width: u32, height: u32) !Window {
        var this: Window = undefined;

        this._display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;
        errdefer _ = c.XCloseDisplay(this._display);

        this._window = c.XCreateSimpleWindow(this._display, c.XDefaultRootWindow(this._display), 0, 0, width, height, 0, 0, 0);
        if (this._window == 0) return error.FailedToCreateWindow;
        errdefer _ = c.XDestroyWindow(this._display, this._window);

        this._wmDeleteMessage = c.XInternAtom(this._display, "WM_DELETE_WINDOW", 0);
        if (this._wmDeleteMessage == c.None) return error.FailedToCreateAtom;

        const ntClass = try std.heap.c_allocator.dupeZ(u8, class);
        defer std.heap.c_allocator.free(ntClass);

        const classHint = c.XAllocClassHint();
        if (classHint == null) return error.OutOfMemory;
        defer _ = c.XFree(classHint);
        classHint.*.res_name = ntClass;
        classHint.*.res_class = ntClass;
        if (c.XSetClassHint(this._display, this._window, classHint) == 0) return error.FailedToSetWindowClass;

        if (c.XSetWMProtocols(this._display, this._window, &this._wmDeleteMessage, 1) == 0) return error.FailedToSetProtocols;
        if (c.XMapWindow(this._display, this._window) == 0) return error.FailedToMapWindow;
        if (c.XSync(this._display, 0) == 0) return error.FailedToSync;

        return this;
    }

    pub fn Destroy(this: *Window) void {
        _ = c.XDestroyWindow(this._display, this._window);
        _ = c.XCloseDisplay(this._display);
    }

    pub fn SetTitle(this: *Window, title: []const u8) !void {
        const alloc = std.heap.c_allocator;
        const titleC = try alloc.dupeZ(u8, title);
        defer alloc.free(titleC);

        if (c.XStoreName(this._display, this._window, titleC) == 0) return error.FailedToSetTitle;
        if (c.XFlush(this._display) == 0) return error.FailedToFlush;
    }

    pub fn EventPending(this: *const Window) bool {
        return c.XPending(this._display) != 0;
    }

    pub fn PopEvent(this: *Window) ?Event.Event {
        if (c.XPending(this._display) == 0)
            return null;

        var event: c.XEvent = undefined;
        _ = c.XNextEvent(this._display, &event);

        switch (event.type) {
            c.ClientMessage => {
                if (event.xclient.data.l[0] == this._wmDeleteMessage)
                    return .{ .type = Event.Event.Type.Closed };
            },
            else => {},
        }

        return null;
    }

    pub fn GetClientSize(this: *const Window) @Vector(2, u32) {
        var root: c.Window = undefined;
        var x: c_int = undefined;
        var y: c_int = undefined;
        var width: c_uint = undefined;
        var height: c_uint = undefined;
        var border: c_uint = undefined;
        var depth: c_uint = undefined;

        _ = c.XGetGeometry(this._display, this._window, &root, &x, &y, &width, &height, &border, &depth);

        return @Vector(2, u32){ width, height };
    }
};

pub const Vulkan = struct {
    pub const requiredExtentions: [2][*:0]const u8 = .{
        "VK_KHR_surface",
        "VK_KHR_xlib_surface",
    };

    pub fn CreateSurface(window: *Window, instance: VK.c.VkInstance) !VK.c.VkSurfaceKHR {
        var surface: VK.c.VkSurfaceKHR = undefined;

        const createInfo: VK.c.VkXlibSurfaceCreateInfoKHR = .{
            .sType = VK.c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = @ptrCast(window._display),
            .window = window._window,
        };

        try VK.Try(VK.c.vkCreateXlibSurfaceKHR(instance, &createInfo, null, &surface));
        return surface;
    }
};
