const std = @import("std");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Image = @import("Image.zig");
const c = vk.c;

image_size: @Vector(2, u32),
_framebuffer: c.VkFramebuffer,

pub fn init(device: *Device, render_pass: *RenderPass, image_size: @Vector(2, u32), image_views: []const *Image.View, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.image_size = image_size;

    const attachments = try alloc.alloc(c.VkImageView, image_views.len);
    defer alloc.free(attachments);
    for (attachments, image_views) |*attachment, image_view| {
        attachment.* = image_view._image_view;
    }

    const create_info: c.VkFramebufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .renderPass = render_pass._render_pass,
        .attachmentCount = @intCast(attachments.len),
        .pAttachments = attachments.ptr,
        .width = image_size[0],
        .height = image_size[1],
        .layers = 1, // TODO: see what this is
    };

    try vk.wrap(c.vkCreateFramebuffer(device._device, &create_info, null, &this._framebuffer));

    return this;
}

pub fn deinit(this: *@This(), device: *Device) void {
    c.vkDestroyFramebuffer(device._device, this._framebuffer, null);
}
