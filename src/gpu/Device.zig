const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");
// const Display = @import("Display.zig");
// const Buffer = @import("Buffer.zig");

pub const Physical = struct {
    _device: vk.PhysicalDevice,
};

instance: *const Instance,
physical: *const Physical,
_device: vk.DeviceProxy,
_graphics_queue: vk.Queue,
_graphics_queue_family_index: u32,
_command_pool: vk.CommandPool,

// pub fn init(instance: *const Instance, physical_device: *const Physical, alloc: std.mem.Allocator) !@This() {
//     var prof = Profiler.startFuncProfiler(@src());
//     defer prof.stop();
//
//     var this: @This() = undefined;
//     this.instance = instance;
//     this.physical = physical_device;
//
//     const queue_create_info: c.VkDeviceQueueCreateInfo = top: {
//         var queue_family_count: u32 = 0;
//         c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device._device, &queue_family_count, null);
//         const queue_families = try alloc.alloc(c.VkQueueFamilyProperties, queue_family_count);
//         defer alloc.free(queue_families);
//         c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device._device, &queue_family_count, queue_families.ptr);
//
//         const queue_priority: f32 = 1;
//
//         var i: u32 = 0;
//         for (queue_families) |prop| {
//             if (prop.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
//                 this._graphics_queue_family_index = i;
//
//                 break :top .{
//                     .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
//                     .queueFamilyIndex = i,
//                     .queueCount = 1,
//                     .pQueuePriorities = &queue_priority,
//                 };
//             }
//
//             i += 1;
//         }
//
//         return error.NoGraphicsQueue;
//     };
//
//     var maintenance_features: c.VkPhysicalDeviceSwapchainMaintenance1FeaturesKHR = .{
//         .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_KHR,
//         .swapchainMaintenance1 = c.VK_TRUE,
//     };
//
//     const features: c.VkPhysicalDeviceFeatures = .{
//         .samplerAnisotropy = c.VK_TRUE,
//     };
//
//     var features2: c.VkPhysicalDeviceFeatures2 = .{
//         .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
//         .features = features,
//         .pNext = &maintenance_features,
//     };
//
//     // TODO: check extention support
//     const create_info: c.VkDeviceCreateInfo = .{
//         .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
//         .pQueueCreateInfos = &queue_create_info,
//         .queueCreateInfoCount = 1,
//         .enabledExtensionCount = vk.required_device_extensions.len,
//         .ppEnabledExtensionNames = &vk.required_device_extensions,
//         .pNext = &features2,
//     };
//
//     try vk.wrap(c.vkCreateDevice(physical_device._device, &create_info, null, &this._device));
//     errdefer c.vkDestroyDevice(this._device, null);
//     c.vkGetDeviceQueue(this._device, this._graphics_queue_family_index, 0, &this._graphics_queue);
//
//     const pool_info: c.VkCommandPoolCreateInfo = .{
//         .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
//         .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
//         .queueFamilyIndex = this._graphics_queue_family_index,
//     };
//
//     try vk.wrap(c.vkCreateCommandPool(this._device, &pool_info, null, &this._command_pool));
//
//     return this;
// }
//
// pub fn deinit(this: *@This()) void {
//     var prof = Profiler.startFuncProfiler(@src());
//     defer prof.stop();
//
//     c.vkDestroyCommandPool(this._device, this._command_pool, null);
//     c.vkDestroyDevice(this._device, null);
// }
//
// pub fn waitUntilIdle(this: *const @This()) !void {
//     try vk.wrap(c.vkDeviceWaitIdle(this._device));
// }
//
// pub const initDisplay = Display.init;
// pub const initBuffer = Buffer.init;
