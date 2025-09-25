const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const c = VK.c;

pub const Semaphore = struct {
    device: *Device,
    _semaphore: c.VkSemaphore,

    pub fn Create(device: *Device) !@This() {
        var this: @This() = undefined;
        this.device = device;

        // TODO: allow creation of timeline semaphores
        const createInfo: c.VkSemaphoreCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .flags = 0,
        };

        try VK.Try(c.vkCreateSemaphore(device._device, &createInfo, null, &this._semaphore));

        return this;
    }

    pub fn Destroy(this: *@This()) void {
        c.vkDestroySemaphore(this.device._device, this._semaphore, null);
    }
};

pub const Fence = struct {
    device: *Device,
    _fence: c.VkFence,

    pub fn Create(device: *Device, signaled: bool) !@This() {
        var this: @This() = undefined;
        this.device = device;

        const createInfo: c.VkFenceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = if (signaled) c.VK_FENCE_CREATE_SIGNALED_BIT else 0,
        };

        try VK.Try(c.vkCreateFence(device._device, &createInfo, null, &this._fence));

        return this;
    }

    pub fn Destroy(this: *@This()) void {
        c.vkDestroyFence(this.device._device, this._fence, null);
    }

    pub fn Reset(this: *@This()) !void {
        try VK.Try(c.vkResetFences(this.device._device, 1, &this._fence));
    }

    pub fn WaitFor(this: *@This(), timeoutNs: ?u64) !void {
        try VK.Try(c.vkWaitForFences(this.device._device, 1, &this._fence, c.VK_TRUE, timeoutNs orelse std.math.maxInt(u64)));
    }
};
