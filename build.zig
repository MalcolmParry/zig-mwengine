const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("mwengine", .{
        .root_source_file = b.path("src/Root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    module.linkSystemLibrary("X11", .{});
    module.linkSystemLibrary("vulkan", .{});
}
