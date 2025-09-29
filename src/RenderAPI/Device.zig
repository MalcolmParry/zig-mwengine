const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Instance = @import("Instance.zig");
const Display = @import("Display.zig");
const Buffer = @import("Buffer.zig");
const c = VK.c;

pub const Physical = struct {
    _device: c.VkPhysicalDevice,
};

instance: *const Instance,
physical: *const Physical,
_device: c.VkDevice,
_graphicsQueue: c.VkQueue,
_graphicsQueueFamilyIndex: u32,
_commandPool: c.VkCommandPool,

pub fn Create(instance: *const Instance, physicalDevice: *const Physical, alloc: std.mem.Allocator) !@This() {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    var this: @This() = undefined;
    this.instance = instance;
    this.physical = physicalDevice;

    var queueCreateInfo: c.VkDeviceQueueCreateInfo = undefined;

    top: {
        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice._device, &queueFamilyCount, null);
        const queueFamilies = try alloc.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer alloc.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice._device, &queueFamilyCount, queueFamilies.ptr);

        const queuePriority: f32 = 1;

        var i: u32 = 0;
        for (queueFamilies) |prop| {
            if (prop.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
                this._graphicsQueueFamilyIndex = i;

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
        .enabledExtensionCount = VK.requiredDeviceExtensions.len,
        .ppEnabledExtensionNames = &VK.requiredDeviceExtensions,
    };

    try VK.Try(c.vkCreateDevice(physicalDevice._device, &createInfo, null, &this._device));
    errdefer c.vkDestroyDevice(this._device, null);
    c.vkGetDeviceQueue(this._device, this._graphicsQueueFamilyIndex, 0, &this._graphicsQueue);

    const poolInfo: c.VkCommandPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = this._graphicsQueueFamilyIndex,
    };

    try VK.Try(c.vkCreateCommandPool(this._device, &poolInfo, null, &this._commandPool));

    return this;
}

pub fn Destroy(this: *@This()) void {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    c.vkDestroyCommandPool(this._device, this._commandPool, null);
    c.vkDestroyDevice(this._device, null);
}

pub fn WaitUntilIdle(this: *const @This()) !void {
    try VK.Try(c.vkDeviceWaitIdle(this._device));
}

pub const CreateDisplay = Display.Create;
pub const CreateBuffer = Buffer.Create;
