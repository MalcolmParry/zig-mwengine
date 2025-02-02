const std = @import("std");
const VK = @import("Vulkan.zig");
const Instance = @import("Instance.zig");
const c = VK.c;

pub const Physical = struct {
    device: c.VkPhysicalDevice,
};

_device: c.VkDevice,

pub fn Create(instance: *const Instance, physicalDevice: *const Physical, alloc: std.mem.Allocator) !@This() {
    _ = instance;

    var this: @This() = undefined;

    var queueCreateInfo: c.VkDeviceQueueCreateInfo = undefined;

    top: {
        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice.device, &queueFamilyCount, null);
        const queueFamilies = try alloc.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer alloc.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice.device, &queueFamilyCount, queueFamilies.ptr);

        const queuePriority: f32 = 1;

        var i: u32 = 0;
        for (queueFamilies) |prop| {
            if (prop.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
                queueCreateInfo = .{
                    .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .queueFamilyIndex = i,
                    .queueCount = 1,
                    .pQueuePriorities = &queuePriority,
                };

                break :top;
            }

            i += 1;
        }
    }

    const features: c.VkPhysicalDeviceFeatures = .{
        .samplerAnisotropy = c.VK_TRUE,
    };

    const createInfo: c.VkDeviceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pQueueCreateInfos = &queueCreateInfo,
        .queueCreateInfoCount = 1,
        .pEnabledFeatures = &features,
        .enabledExtensionCount = VK.requiredDeviceExtentions.len,
        .ppEnabledExtensionNames = &VK.requiredDeviceExtentions,
    };

    try VK.Try(c.vkCreateDevice(physicalDevice.device, &createInfo, null, &this._device));

    return this;
}

pub fn Destroy(this: *const @This()) void {
    c.vkDestroyDevice(this._device, null);
}
