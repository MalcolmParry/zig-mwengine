const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Image = @import("Image.zig");
const Platform = @import("../Platform.zig");
const c = VK.c;

imageSize: @Vector(2, u32),
_framebuffer: c.VkFramebuffer,

pub fn Create(device: *Device, renderPass: *RenderPass, imageSize: @Vector(2, u32), imageViews: []const *Image.View, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.imageSize = imageSize;

    const attachments = try alloc.alloc(c.VkImageView, imageViews.len);
    defer alloc.free(attachments);
    for (attachments, imageViews) |*attachment, imageView| {
        attachment.* = imageView._imageView;
    }

    const createInfo: c.VkFramebufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .renderPass = renderPass._renderPass,
        .attachmentCount = @intCast(attachments.len),
        .pAttachments = attachments.ptr,
        .width = imageSize[0],
        .height = imageSize[1],
        .layers = 1, // TODO: see what this is
    };

    try VK.Try(c.vkCreateFramebuffer(device._device, &createInfo, null, &this._framebuffer));

    return this;
}

pub fn Destroy(this: *@This(), device: *Device) void {
    c.vkDestroyFramebuffer(device._device, this._framebuffer, null);
}
