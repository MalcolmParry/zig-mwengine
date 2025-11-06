const std = @import("std");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const c = vk.c;

pub const Semaphore = struct {
    device: *Device,
    _semaphore: c.VkSemaphore,

    pub fn init(device: *Device) !@This() {
        var this: @This() = undefined;
        this.device = device;

        // TODO: allow creation of timeline semaphores
        const create_info: c.VkSemaphoreCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .flags = 0,
        };

        try vk.wrap(c.vkCreateSemaphore(device._device, &create_info, null, &this._semaphore));

        return this;
    }

    pub fn deinit(this: *@This()) void {
        c.vkDestroySemaphore(this.device._device, this._semaphore, null);
    }
};

pub const Fence = struct {
    device: *Device,
    _fence: c.VkFence,

    pub fn init(device: *Device, signaled: bool) !@This() {
        var this: @This() = undefined;
        this.device = device;

        const create_info: c.VkFenceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = if (signaled) c.VK_FENCE_CREATE_SIGNALED_BIT else 0,
        };

        try vk.wrap(c.vkCreateFence(device._device, &create_info, null, &this._fence));

        return this;
    }

    pub fn deinit(this: *@This()) void {
        c.vkDestroyFence(this.device._device, this._fence, null);
    }

    pub fn reset(this: *@This()) !void {
        try vk.wrap(c.vkResetFences(this.device._device, 1, &this._fence));
    }

    pub fn wait(this: *@This(), timeout_ns: ?u64) !void {
        const wait_all = c.VK_TRUE;
        try vk.wrap(c.vkWaitForFences(this.device._device, 1, &this._fence, wait_all, timeout_ns orelse std.math.maxInt(u64)));
    }
};
