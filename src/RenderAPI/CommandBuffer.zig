const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Framebuffer = @import("Framebuffer.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
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

// Graphics Commands
pub fn QueueBeginRenderPass(this: *@This(), renderPass: *RenderPass, framebuffer: *Framebuffer) void {
    const size = framebuffer.imageSize;

    const clearValue: c.VkClearValue = .{
        .color = .{
            .float32 = .{ 0, 0, 0, 1 },
        },
    };

    const renderPassInfo: c.VkRenderPassBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = renderPass._renderPass,
        .framebuffer = framebuffer._framebuffer,
        .renderArea = .{
            .extent = .{ .width = size[0], .height = size[1] },
            .offset = .{ .x = 0, .y = 0 },
        },
        .clearValueCount = 1,
        .pClearValues = &clearValue,
    };

    c.vkCmdBeginRenderPass(this._commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
}

pub fn QueueEndRenderPass(this: *@This()) void {
    c.vkCmdEndRenderPass(this._commandBuffer);
}

pub fn QueueDraw(this: *@This(), graphicsPipeline: *GraphicsPipeline, framebuffer: *Framebuffer) void {
    c.vkCmdBindPipeline(this._commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline._pipeline);

    const viewport: c.VkViewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(framebuffer.imageSize[0]),
        .height = @floatFromInt(framebuffer.imageSize[1]),
        .minDepth = 0,
        .maxDepth = 1,
    };

    c.vkCmdSetViewport(this._commandBuffer, 0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .extent = .{ .width = framebuffer.imageSize[0], .height = framebuffer.imageSize[1] },
        .offset = .{ .x = 0, .y = 0 },
    };

    c.vkCmdSetScissor(this._commandBuffer, 0, 1, &scissor);
    c.vkCmdDraw(this._commandBuffer, graphicsPipeline.vertexCount, 1, 0, 0);
}
