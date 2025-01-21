const Event = @import("../Event.zig");

pub const Window = struct {
    pub fn Create(width: u32, height: u32) !Window {
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
