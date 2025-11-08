const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;

const shader_path = "examples/shaders/";
const shader_output = "res/shaders/";

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const profiling = b.option(bool, "profiling", "Enable profiling") orelse (optimize == .Debug);

    const opts = b.addOptions();
    opts.addOption(bool, "profiling", profiling);

    const module = b.addModule("mwengine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const vulkan = b.dependency("vulkan", .{
        .registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml"),
    }).module("vulkan-zig");

    module.addOptions("build-options", opts);
    module.addImport("vulkan", vulkan);
    module.linkSystemLibrary("X11", .{});

    // example
    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/triangle.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{
                .name = "mwengine",
                .module = module,
            }},
        }),
    });

    // build the example
    const example_build_artifact = b.addInstallArtifact(example, .{});
    const example_build_step = b.step("example", "Build the example executable");
    example_build_step.dependOn(&example_build_artifact.step);
    try buildShaders(b, example_build_step);

    // run the example
    const run_command = b.addRunArtifact(example);
    run_command.setCwd(.{ .cwd_relative = b.install_prefix });
    run_command.step.dependOn(example_build_step);

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_command.step);
}

fn buildShaders(b: *Build, build_step: *Build.Step) !void {
    const dir = try b.build_root.handle.openDir(shader_path, .{ .iterate = true });
    var iter = try dir.walk(b.allocator);
    defer iter.deinit();

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".glsl")) continue;

        try buildShader(b, build_step, entry, "vert", &.{"-D_VERTEX"});
        try buildShader(b, build_step, entry, "frag", &.{"-D_PIXEL"});
    }
}

fn buildShader(b: *Build, build_step: *Build.Step, entry: std.fs.Dir.Walker.Entry, t: []const u8, defines: []const []const u8) !void {
    const src = b.path(b.fmt("{s}/{s}", .{ shader_path, entry.path }));
    var name_iter = std.mem.splitScalar(u8, entry.basename, '.');
    const name = name_iter.next() orelse return error.Failed;
    const out_name = b.fmt("{s}.{s}.spv", .{ name, t });

    const command = b.addSystemCommand(&.{ "glslangValidator", "-S", t });
    command.addArgs(defines);
    command.addArg("-V");
    command.addFileInput(src);
    command.addFileArg(src);
    command.addArg("-o");

    const out = command.addOutputFileArg(out_name);
    const install = b.addInstallFile(out, b.fmt("{s}/{s}", .{ shader_output, out_name }));
    install.step.dependOn(&command.step);
    build_step.dependOn(&install.step);
}
