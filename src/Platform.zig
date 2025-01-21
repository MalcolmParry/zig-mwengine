const std = @import("std");
const builtin = @import("builtin");

const nullPlatform = @import("Platform/Null.zig");
const platform = switch (builtin.os.tag) {
    .linux => @import("Platform/Linux.zig"),
    else => nullPlatform,
};

pub const Window = platform.Window;
