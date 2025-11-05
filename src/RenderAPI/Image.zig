const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const c = vk.c;

const Image = @This();

_image: c.VkImage,

pub const View = struct {
    device: *Device,
    _image_view: c.VkImageView,
};
