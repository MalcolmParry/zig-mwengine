const std = @import("std");

pub fn build(b: *std.Build) !void {
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

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("Test/src/Main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // build shaders
    const compileShaderStep = b.addSystemCommand(&.{"./scripts/compile-shaders.sh"});

    // build the test exe
    exe.root_module.addImport("mwengine", module);
    const testBuildArtifact = b.addInstallArtifact(exe, .{});
    const testBuildStep = b.step("build-test", "Build the test executable");
    testBuildStep.dependOn(&testBuildArtifact.step);
    testBuildStep.dependOn(&compileShaderStep.step);

    // run the test exe
    const runCmd = b.addRunArtifact(exe);
    runCmd.cwd = b.path("Test/");
    const runStep = b.step("run", "Run the test");
    runStep.dependOn(&runCmd.step);
    runStep.dependOn(testBuildStep);
}
