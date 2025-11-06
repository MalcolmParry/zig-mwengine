const std = @import("std");
const Event = @import("../Event.zig");
const vk = @import("../render_api/vulkan.zig");

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
});

pub const Window = struct {
    _display: *c.Display,
    _window: c.Window,
    _wm_delete_message: c.Atom,

    pub fn init(class: []const u8, width: u32, height: u32) !Window {
        var this: Window = undefined;

        this._display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;
        errdefer _ = c.XCloseDisplay(this._display);

        this._window = c.XCreateSimpleWindow(this._display, c.XDefaultRootWindow(this._display), 0, 0, width, height, 0, 0, 0);
        if (this._window == 0) return error.FailedToCreateWindow;
        errdefer _ = c.XDestroyWindow(this._display, this._window);

        this._wm_delete_message = c.XInternAtom(this._display, "WM_DELETE_WINDOW", 0);
        if (this._wm_delete_message == c.None) return error.FailedToCreateAtom;

        const nt_class = try std.heap.c_allocator.dupeZ(u8, class);
        defer std.heap.c_allocator.free(nt_class);

        const class_hint = c.XAllocClassHint();
        if (class_hint == null) return error.OutOfMemory;
        defer _ = c.XFree(class_hint);
        class_hint.*.res_name = nt_class;
        class_hint.*.res_class = nt_class;
        if (c.XSetClassHint(this._display, this._window, class_hint) == 0) return error.FailedToSetWindowClass;

        if (c.XSetWMProtocols(this._display, this._window, &this._wm_delete_message, 1) == 0) return error.FailedToSetProtocols;
        if (c.XMapWindow(this._display, this._window) == 0) return error.FailedToMapWindow;
        if (c.XSync(this._display, 0) == 0) return error.FailedToSync;

        return this;
    }

    pub fn deinit(this: *Window) void {
        _ = c.XDestroyWindow(this._display, this._window);
        _ = c.XCloseDisplay(this._display);
    }

    pub fn setTitle(this: *Window, title: []const u8) !void {
        const alloc = std.heap.c_allocator;
        const title_c = try alloc.dupeZ(u8, title);
        defer alloc.free(title_c);

        if (c.XStoreName(this._display, this._window, title_c) == 0) return error.FailedToSetTitle;
        if (c.XFlush(this._display) == 0) return error.FailedToFlush;
    }

    pub fn eventPending(this: *const Window) bool {
        return c.XPending(this._display) != 0;
    }

    pub fn popEvent(this: *Window) ?Event {
        if (c.XPending(this._display) == 0)
            return null;

        var event: c.XEvent = undefined;
        _ = c.XNextEvent(this._display, &event);

        switch (event.type) {
            c.ClientMessage => {
                if (event.xclient.data.l[0] == this._wm_delete_message)
                    return .{ .type = Event.Type.closed };
            },
            else => {},
        }

        return null;
    }

    pub fn getClientSize(this: *const Window) @Vector(2, u32) {
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

pub const vulkan = struct {
    pub const required_extensions: [2][*:0]const u8 = .{
        "VK_KHR_surface",
        "VK_KHR_xlib_surface",
    };

    pub fn createSurface(window: *Window, instance: vk.c.VkInstance) !vk.c.VkSurfaceKHR {
        var surface: vk.c.VkSurfaceKHR = undefined;

        const create_info: vk.c.VkXlibSurfaceCreateInfoKHR = .{
            .sType = vk.c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = @ptrCast(window._display),
            .window = window._window,
        };

        try vk.wrap(vk.c.vkCreateXlibSurfaceKHR(instance, &create_info, null, &surface));
        return surface;
    }
};
