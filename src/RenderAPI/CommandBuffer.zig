const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const Semaphore = @import("WaitObjects.zig").Semaphore;
const Fence = @import("WaitObjects.zig").Fence;
const c = VK.c;

_commandBuffer: c.VkCommandBuffer,

pub fn Create(device: *Device) !@This() {
    var this: @This() = undefined;

    const allocInfo: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = device._commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    try VK.Try(c.vkAllocateCommandBuffers(device._device, &allocInfo, &this._commandBuffer));

    return this;
}

pub fn Destroy(this: *@This(), device: *Device) void {
    c.vkFreeCommandBuffers(device._device, device._commandPool, 1, &this._commandBuffer);
}

pub fn Begin(this: *@This()) !void {
    const beginInfo: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = 0, // TODO: allow for flags
        .pInheritanceInfo = null,
    };

    try VK.Try(c.vkBeginCommandBuffer(this._commandBuffer, &beginInfo));
}

pub fn End(this: *@This()) !void {
    try VK.Try(c.vkEndCommandBuffer(this._commandBuffer));
}

pub fn Reset(this: *@This()) !void {
    try VK.Try(c.vkResetCommandBuffer(this._commandBuffer, 0));
}

// TODO: allow for multiple semaphores
pub fn Submit(this: *@This(), device: *Device, waitSemaphore: ?*Semaphore, signalSemaphore: ?*Semaphore, signalFence: ?*Fence) !void {
    const nativeWaitSemaphore = if (waitSemaphore) |x| &x._semaphore else null;
    const nativeSignalSemaphore = if (signalSemaphore) |x| &x._semaphore else null;
    const nativeSignalFence = if (signalFence) |x| x._fence else null;

    const waitDstStageMask: u32 = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    const submitInfo: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &this._commandBuffer,
        .waitSemaphoreCount = if (waitSemaphore) |_| 1 else 0,
        .pWaitSemaphores = nativeWaitSemaphore,
        .pWaitDstStageMask = &waitDstStageMask,
        .signalSemaphoreCount = if (signalSemaphore) |_| 1 else 0,
        .pSignalSemaphores = nativeSignalSemaphore,
    };

    try VK.Try(c.vkQueueSubmit(device._graphicsQueue, 1, &submitInfo, nativeSignalFence));
}
