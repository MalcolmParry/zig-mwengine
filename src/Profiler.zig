const std = @import("std");

pub var global: ?*@This() = null;

name: []const u8,
outputFile: std.fs.File,
profileCount: u32,
start: std.time.Instant,
alloc: std.mem.Allocator,

const Profiler = @This();

pub fn Create(name: []const u8, filepath: []const u8, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.name = name;
    this.profileCount = 0;
    this.alloc = alloc;
    this.start = try std.time.Instant.now();
    this.outputFile = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    _ = try this.outputFile.write("{\"otherData\": {},\"traceEvents\":[");
    try this.outputFile.sync();

    return this;
}

pub fn Destroy(this: *@This()) !void {
    defer this.outputFile.close();

    _ = try this.outputFile.write("]}");
    try this.outputFile.sync();
}

pub fn WriteProfile(this: *@This(), profileResult: ProfileResult) !void {
    if (this.profileCount > 0)
        _ = try this.outputFile.write(",");

    this.profileCount += 1;
    const newName = try this.alloc.dupe(u8, profileResult.name);
    defer this.alloc.free(newName);
    _ = std.mem.replaceScalar(u8, newName, '"', '\'');

    _ = try this.outputFile.write("{");
    try this.outputFile.writer().print(
        \\"cat":"function","dur":{},"name":"{s}","ph":"X","pid":0,"tid":{},"ts":{}
    , .{ profileResult.end.since(profileResult.start) / std.time.ns_per_us, profileResult.name, profileResult.threadId, profileResult.start.since(this.start) / std.time.ns_per_us });
    _ = try this.outputFile.write("}");

    try this.outputFile.sync();
}

const ProfileResult = struct {
    name: []const u8,
    threadId: u64,
    start: std.time.Instant,
    end: std.time.Instant,
};

pub const Timed = struct {
    profiler: *Profiler,
    result: ProfileResult,

    pub fn Start(profiler: *Profiler, name: []const u8, threadId: u64) !@This() {
        var this: @This() = undefined;
        this.profiler = profiler;
        this.result.name = name;
        this.result.threadId = threadId;
        this.result.start = try std.time.Instant.now();
        this.result.end = this.result.start;
        return this;
    }

    pub fn Stop(this: *@This()) void {
        this.result.end = std.time.Instant.now() catch @panic("error in profiler");
        this.profiler.WriteProfile(this.result) catch {
            @panic("error in profiler");
        };
    }
};

pub fn StartFuncProfiler(comptime src: std.builtin.SourceLocation) Timed {
    return Timed.Start(global.?, src.fn_name ++ " from " ++ src.file, std.Thread.getCurrentId()) catch @panic("error in profiler");
}
