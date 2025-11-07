const vk = @import("vulkan");
const Device = @import("Device.zig");

const Image = @This();

_image: vk.Image,

pub const View = struct {
    _image_view: vk.ImageView,
};
