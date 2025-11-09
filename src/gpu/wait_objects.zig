const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");

pub const Semaphore = struct {
    _semaphore: vk.Semaphore,

    pub fn init(device: *Device) !@This() {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        const semaphore = try device._device.createSemaphore(&.{
            .flags = .{},
        }, vk_alloc);

        return .{ ._semaphore = semaphore };
    }

    pub fn deinit(this: *@This(), device: *Device) void {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        device._device.destroySemaphore(this._semaphore, vk_alloc);
    }

    pub fn _nativesFromSlice(these: []@This()) []vk.Semaphore {
        return @ptrCast(these);
    }
};

pub const Fence = struct {
    _fence: vk.Fence,

    pub fn init(device: *Device, signaled: bool) !@This() {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        const fence = try device._device.createFence(&.{
            .flags = .{
                .signaled_bit = signaled,
            },
        }, vk_alloc);

        return .{ ._fence = fence };
    }

    pub fn deinit(this: *@This(), device: *Device) void {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        device._device.destroyFence(this._fence, vk_alloc);
    }

    pub fn reset(this: *@This(), device: *Device) !void {
        try device._device.resetFences(1, @ptrCast(&this._fence));
    }

    pub const WaitForEnum = enum { single, all };
    pub const WaitForResult = enum { success, timeout };

    pub fn waitMany(these: []@This(), device: *Device, how_many: WaitForEnum, timeout_ns: ?u64) !WaitForResult {
        const natives = _nativesFromSlice(these);
        return switch (try device._device.waitForFences(natives.len, natives.ptr, how_many == .all, timeout_ns orelse std.math.maxInt(u64))) {
            .success => .success,
            .timeout => .timeout,
            else => unreachable,
        };
    }

    pub fn wait(this: @This(), device: *Device, how_many: WaitForEnum, timeout_ns: ?u64) !void {
        return waitMany(&.{this}, device, how_many, timeout_ns);
    }

    pub fn checkSignaled(this: @This(), device: *Device) bool {
        return switch (try device._device.getFenceStatus(this._fence)) {
            .success => true,
            .not_ready => false,
            else => unreachable,
        };
    }

    pub fn _nativesFromSlice(these: []@This()) []vk.Fence {
        return @ptrCast(these);
    }
};
