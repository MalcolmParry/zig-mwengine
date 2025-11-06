const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Framebuffer = @import("Framebuffer.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const Semaphore = @import("wait_objects.zig").Semaphore;
const Fence = @import("wait_objects.zig").Fence;
const c = vk.c;

_command_buffer: c.VkCommandBuffer,

pub fn init(device: *Device) !@This() {
    var this: @This() = undefined;

    const alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = device._command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    try vk.wrap(c.vkAllocateCommandBuffers(device._device, &alloc_info, &this._command_buffer));

    return this;
}

pub fn deinit(this: *@This(), device: *Device) void {
    c.vkFreeCommandBuffers(device._device, device._command_pool, 1, &this._command_buffer);
}

pub fn begin(this: *@This()) !void {
    const begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = 0, // TODO: allow for flags
        .pInheritanceInfo = null,
    };

    try vk.wrap(c.vkBeginCommandBuffer(this._command_buffer, &begin_info));
}

pub fn end(this: *@This()) !void {
    try vk.wrap(c.vkEndCommandBuffer(this._command_buffer));
}

pub fn reset(this: *@This()) !void {
    try vk.wrap(c.vkResetCommandBuffer(this._command_buffer, 0));
}

// TODO: allow for multiple semaphores
pub fn submit(this: *@This(), device: *Device, wait_semaphore: ?*Semaphore, signal_semaphore: ?*Semaphore, signal_fence: ?*Fence) !void {
    const native_wait_semaphore = if (wait_semaphore) |x| &x._semaphore else null;
    const native_signal_semaphore = if (signal_semaphore) |x| &x._semaphore else null;
    const native_signal_fence = if (signal_fence) |x| x._fence else null;

    const wait_dst_stage_mask: u32 = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &this._command_buffer,
        .waitSemaphoreCount = if (wait_semaphore) |_| 1 else 0,
        .pWaitSemaphores = native_wait_semaphore,
        .pWaitDstStageMask = &wait_dst_stage_mask,
        .signalSemaphoreCount = if (signal_semaphore) |_| 1 else 0,
        .pSignalSemaphores = native_signal_semaphore,
    };

    try vk.wrap(c.vkQueueSubmit(device._graphics_queue, 1, &submit_info, native_signal_fence));
}

// Graphics Commands
pub fn queueBeginRenderPass(this: *@This(), render_pass: *RenderPass, framebuffer: *Framebuffer) void {
    const size = framebuffer.image_size;

    const clear_value: c.VkClearValue = .{
        .color = .{
            .float32 = .{ 0, 0, 0, 1 },
        },
    };

    const render_pass_info: c.VkRenderPassBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = render_pass._render_pass,
        .framebuffer = framebuffer._framebuffer,
        .renderArea = .{
            .extent = .{ .width = size[0], .height = size[1] },
            .offset = .{ .x = 0, .y = 0 },
        },
        .clearValueCount = 1,
        .pClearValues = &clear_value,
    };

    c.vkCmdBeginRenderPass(this._command_buffer, &render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);
}

pub fn queueEndRenderPass(this: *@This()) void {
    c.vkCmdEndRenderPass(this._command_buffer);
}

pub fn queueDraw(this: *@This(), graphics_pipeline: *GraphicsPipeline, framebuffer: *Framebuffer) void {
    c.vkCmdBindPipeline(this._command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphics_pipeline._pipeline);

    const viewport: c.VkViewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(framebuffer.image_size[0]),
        .height = @floatFromInt(framebuffer.image_size[1]),
        .minDepth = 0,
        .maxDepth = 1,
    };

    c.vkCmdSetViewport(this._command_buffer, 0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .extent = .{ .width = framebuffer.image_size[0], .height = framebuffer.image_size[1] },
        .offset = .{ .x = 0, .y = 0 },
    };

    c.vkCmdSetScissor(this._command_buffer, 0, 1, &scissor);
    c.vkCmdDraw(this._command_buffer, graphics_pipeline.vertex_count, 1, 0, 0);
}
