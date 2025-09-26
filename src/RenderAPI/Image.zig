const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const Platform = @import("../Platform.zig");
const c = VK.c;

const Image = @This();

_image: c.VkImage,

pub const View = struct {
    device: *Device,
    _imageView: c.VkImageView,
};
