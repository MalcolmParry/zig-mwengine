const platform = @import("platform.zig");

pub const math = @import("math.zig");
pub const gpu = @import("gpu.zig");

pub const Window = platform.Window;

comptime {
    _ = math;
}
