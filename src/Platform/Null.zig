const Event = @import("../Event.zig");

const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const Window = struct {
    pub fn Create(class: []const u8, width: u32, height: u32) !Window {
        _ = class;
        _ = width;
        _ = height;
    }

    pub fn Destroy(this: *const Window) void {
        _ = this;
    }

    pub fn SetTitle(this: *const Window, title: []const u8) !void {
        _ = this;
        _ = title;
    }

    pub fn EventPending(this: *const Window) bool {
        _ = this;

        return false;
    }

    pub fn PopEvent(this: *const Window) ?Event.Event {
        _ = this;

        return null;
    }
};

pub const Vulkan = struct {
    pub const requiredExtentions: [0][*:0]const u8 = .{};

    pub fn CreateSurface(window: *const Window, instance: c.VKInstance) !c.VkSurfaceKHR {
        _ = window;
        _ = instance;

        return error.NullPlatform;
    }
};
