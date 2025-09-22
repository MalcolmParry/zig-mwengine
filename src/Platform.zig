const std = @import("std");
const builtin = @import("builtin");

const Platform = switch (builtin.os.tag) {
    .linux => @import("Platform/Linux.zig"),
    else => @compileError("Platform not supported."),
};

pub const Window = Platform.Window;
pub const Vulkan = Platform.Vulkan;
