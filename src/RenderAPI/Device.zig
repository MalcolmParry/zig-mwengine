const std = @import("std");
const VK = @import("Vulkan.zig");
const c = VK.c;

pub const Physical = struct {
    device: c.VkPhysicalDevice,
};

device: c.VkDevice,

pub fn Destroy(this: *const @This()) void {
    c.vkDestroyDevice(this.device, null);
}
