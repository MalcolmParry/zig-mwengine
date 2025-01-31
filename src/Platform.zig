const std = @import("std");
const builtin = @import("builtin");

const nullPlatform = @import("Platform/Null.zig");
pub usingnamespace switch (builtin.os.tag) {
    .linux => @import("Platform/Linux.zig"),
    else => nullPlatform,
};
