const std = @import("std");
const buildOptions = @import("build-options");

pub var global: ?*@This() = null;

profiles: std.array_list.Managed(ProfileResult),
start: std.time.Instant,
alloc: std.mem.Allocator,

const Profiler = @This();

pub fn Create(alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.alloc = alloc;
    this.start = try std.time.Instant.now();
    this.profiles = try .initCapacity(alloc, 50);

    return this;
}

pub fn Destroy(this: *@This()) void {
    this.profiles.deinit();
}

pub fn WriteProfile(this: *@This(), profileResult: ProfileResult) !void {
    try this.profiles.append(profileResult);
}

pub fn WriteToFile(this: *@This(), filepath: []const u8) !void {
    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const buffer = try this.alloc.alloc(u8, 1024 * 8);
    defer this.alloc.free(buffer);
    var fileWriter = file.writer(buffer);
    var writer = &fileWriter.interface;
    defer writer.flush() catch {};

    _ = try writer.write("{\"otherData\": {},\"traceEvents\":[");

    for (this.profiles.items, 0..) |*profile, i| {
        if (i > 0)
            try writer.print(",", .{});

        const newName = try this.alloc.dupe(u8, profile.name);
        defer this.alloc.free(newName);
        _ = std.mem.replaceScalar(u8, newName, '"', '\'');

        try writer.print(
            \\{{"cat":"function","dur":{},"name":"{s}","ph":"X","pid":0,"tid":{},"ts":{}}}
        , .{ profile.end.since(profile.start) / std.time.ns_per_us, newName, profile.threadId, profile.start.since(this.start) / std.time.ns_per_us });
    }

    _ = try writer.write("]}");
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

const Blank = struct {
    pub fn Stop(_: @This()) void {}
};

const FuncProfiler = if (buildOptions.profiling) Timed else Blank;

threadlocal var tid: ?std.Thread.Id = null;

pub fn StartFuncProfiler(comptime src: std.builtin.SourceLocation) FuncProfiler {
    if (comptime !buildOptions.profiling)
        return Blank{};

    tid = tid orelse std.Thread.getCurrentId();

    return Timed.Start(global.?, src.fn_name ++ " from " ++ src.file, tid.?) catch @panic("error in profiler");
}
