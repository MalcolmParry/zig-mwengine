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

    pub fn wait(this: *@This(), device: *Device, timeout_ns: ?u64) !void {
        const wait_all: vk.Bool32 = .true;
        return switch (try device._device.waitForFences(1, @ptrCast(&this._fence), wait_all, timeout_ns orelse std.math.maxInt(u64))) {
            .success => {},
            .timeout => error.Timeout,
            else => unreachable,
        };
    }
};
