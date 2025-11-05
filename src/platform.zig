const builtin = @import("builtin");

const impl = switch (builtin.os.tag) {
    .linux => @import("platform/linux.zig"),
    else => @compileError("Platform not supported."),
};

pub const Window = impl.Window;
pub const vulkan = impl.vulkan;
