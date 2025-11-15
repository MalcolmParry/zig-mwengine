const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Framebuffer = @import("Framebuffer.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const Semaphore = @import("wait_objects.zig").Semaphore;
const Fence = @import("wait_objects.zig").Fence;

_command_buffer: vk.CommandBuffer,

pub fn init(device: *Device) !@This() {
    var command_buffer: vk.CommandBuffer = .null_handle;
    try device._device.allocateCommandBuffers(&.{
        .command_pool = device._command_pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&command_buffer));

    return .{ ._command_buffer = command_buffer };
}

pub fn deinit(this: *@This(), device: *Device) void {
    device._device.freeCommandBuffers(device._command_pool, 1, @ptrCast(&this._command_buffer));
}

pub fn begin(this: *@This(), device: *Device) !void {
    try device._device.beginCommandBuffer(this._command_buffer, &.{
        .flags = .{},
    });
}

pub fn end(this: *@This(), device: *Device) !void {
    try device._device.endCommandBuffer(this._command_buffer);
}

pub fn reset(this: *@This(), device: *Device) !void {
    try device._device.resetCommandBuffer(this._command_buffer, .{});
}

pub fn submit(this: *@This(), device: *Device, wait_semaphores: []const Semaphore, signal_semaphores: []const Semaphore, signal_fence: ?Fence) !void {
    const wait_dst_stage_mask: vk.PipelineStageFlags = .{
        .color_attachment_output_bit = true,
    };

    const submit_info: vk.SubmitInfo = .{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&this._command_buffer),
        .wait_semaphore_count = @intCast(wait_semaphores.len),
        .p_wait_semaphores = Semaphore._nativesFromSlice(wait_semaphores),
        .signal_semaphore_count = @intCast(signal_semaphores.len),
        .p_signal_semaphores = Semaphore._nativesFromSlice(signal_semaphores),
        .p_wait_dst_stage_mask = @ptrCast(&wait_dst_stage_mask),
    };

    try device._device.queueSubmit(device._queue, 1, @ptrCast(&submit_info), if (signal_fence) |fence| fence._fence else .null_handle);
}

// Graphics Commands
pub fn queueBeginRenderPass(this: *@This(), device: *Device, render_pass: RenderPass, framebuffer: Framebuffer, image_size: @Vector(2, u32)) void {
    const clear_value: vk.ClearValue = .{
        .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
    };

    device._device.cmdBeginRenderPass(this._command_buffer, &.{
        .render_pass = render_pass._render_pass,
        .framebuffer = framebuffer._framebuffer,
        .clear_value_count = 1,
        .p_clear_values = @ptrCast(&clear_value),
        .render_area = .{
            .extent = .{ .width = image_size[0], .height = image_size[1] },
            .offset = .{ .x = 0, .y = 0 },
        },
    }, .@"inline");
}

pub fn queueEndRenderPass(this: *@This(), device: *Device) void {
    device._device.cmdEndRenderPass(this._command_buffer);
}

pub fn queueDraw(this: *@This(), device: *Device, graphics_pipeline: GraphicsPipeline, image_size: @Vector(2, u32), vertex_count: u32) void {
    device._device.cmdBindPipeline(this._command_buffer, .graphics, graphics_pipeline._pipeline);

    const viewport: vk.Viewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(image_size[0]),
        .height = @floatFromInt(image_size[1]),
        .min_depth = 0,
        .max_depth = 1,
    };

    device._device.cmdSetViewport(this._command_buffer, 0, 1, @ptrCast(&viewport));

    const scissor: vk.Rect2D = .{
        .extent = .{ .width = image_size[0], .height = image_size[1] },
        .offset = .{ .x = 0, .y = 0 },
    };

    device._device.cmdSetScissor(this._command_buffer, 0, 1, @ptrCast(&scissor));
    device._device.cmdDraw(this._command_buffer, vertex_count, 1, 0, 1);
}
