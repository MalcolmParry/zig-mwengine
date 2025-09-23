const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const c = VK.c;

device: *Device,
_commandBuffer: c.VkCommandBuffer,

pub fn Create(device: *Device) !@This() {
    var this: @This() = undefined;
    this.device = device;

    const allocInfo: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = device._commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    try VK.Try(c.vkAllocateCommandBuffers(device._device, &allocInfo, &this._commandBuffer));

    return this;
}

pub fn Destroy(this: *@This()) void {
    c.vkFreeCommandBuffers(this.device._device, this.device._commandPool, 1, &this._commandBuffer);
}
