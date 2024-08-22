const std = @import("std");

pub export fn testfn() void {
    std.debug.print("Hello world!\n", .{});
}
