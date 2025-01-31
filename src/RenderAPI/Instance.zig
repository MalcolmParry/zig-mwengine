const std = @import("std");
const Platform = @import("../Platform.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");

const c = VK.c;

const validationExtentions: [1][*:0]const u8 = .{
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

instance: c.VkInstance,
debugMessenger: c.VkDebugUtilsMessengerEXT,
physicalDevices: []Device.Physical,

//  TODO: add app version to paramerers
pub fn Create(debugLogging: bool, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;

    const appInfo: c.VkApplicationInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "placeholder",
        .applicationVersion = 0,
        .pEngineName = "mwengine",
        .apiVersion = c.VK_API_VERSION_1_0,
    };

    const validationLayer: [*]const u8 = "VK_LAYER_KHRONOS_validation";
    const extentions = VK.requiredExtentions;
    const debugExtentions = extentions ++ validationExtentions;

    const instanceCreateInfo: c.VkInstanceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = if (debugLogging) debugExtentions.len else extentions.len,
        .ppEnabledExtensionNames = if (debugLogging) &debugExtentions else &extentions,
        .enabledLayerCount = if (debugLogging) 1 else 0,
        .ppEnabledLayerNames = if (debugLogging) &validationLayer else null,
    };

    try VK.Try(c.vkCreateInstance(&instanceCreateInfo, null, &this.instance));
    errdefer c.vkDestroyInstance(this.instance, null);

    if (debugLogging) {
        const debugMessengerCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = DebugMessengerCallback,
            .pUserData = null,
        };

        try VK.Try(vkCreateDebugUtilsMessengerEXT(this.instance, &debugMessengerCreateInfo, null, &this.debugMessenger));
    } else {
        this.debugMessenger = null;
    }

    errdefer if (debugLogging) vkDestroyDebugUtilsMessengerEXT(this.instance, this.debugMessenger, null);

    var deviceCount: u32 = 0;
    try VK.Try(c.vkEnumeratePhysicalDevices(this.instance, &deviceCount, null));
    const nativePhysicalDevices = try alloc.alloc(c.VkPhysicalDevice, deviceCount);
    defer alloc.free(nativePhysicalDevices);
    try VK.Try(c.vkEnumeratePhysicalDevices(this.instance, &deviceCount, nativePhysicalDevices.ptr));
    this.physicalDevices = try alloc.alloc(Device.Physical, deviceCount);
    errdefer alloc.free(this.physicalDevices);

    for (0..deviceCount) |i| {
        const device = &this.physicalDevices[i];
        device.device = nativePhysicalDevices[i];

        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device.device, &queueFamilyCount, null);
        const queueFamilies = try alloc.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer alloc.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(device.device, &queueFamilyCount, queueFamilies.ptr);
        std.debug.print("\n", .{});

        for (queueFamilies) |prop| {
            std.debug.print("queue family {}: ", .{prop.queueCount});

            if (prop.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
                std.debug.print("graphics ", .{});
            }

            if (prop.queueFlags & c.VK_QUEUE_COMPUTE_BIT > 0) {
                std.debug.print("compute ", .{});
            }

            if (prop.queueFlags & c.VK_QUEUE_TRANSFER_BIT > 0) {
                std.debug.print("transfer ", .{});
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    return this;
}

pub fn Destroy(this: *const @This(), alloc: std.mem.Allocator) void {
    alloc.free(this.physicalDevices);
    if (this.debugMessenger != null) vkDestroyDebugUtilsMessengerEXT(this.instance, this.debugMessenger, null);
    c.vkDestroyInstance(this.instance, null);
}

pub fn CreateDevice(this: *const @This(), physicalDevice: Device.Physical, alloc: std.mem.Allocator) !Device {
    _ = this;

    var device: Device = undefined;

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

    try VK.Try(c.vkCreateDevice(physicalDevice.device, &createInfo, null, &device.device));

    return device;
}

pub fn BestPhysicalDevice(this: *const @This(), alloc: std.mem.Allocator) !Device.Physical {
    _ = alloc;

    var bestDevice: ?Device.Physical = null;
    var bestScore: i32 = -1;
    for (this.physicalDevices) |device| {
        var properties: c.VkPhysicalDeviceProperties = undefined;
        var features: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceProperties(device.device, &properties);
        c.vkGetPhysicalDeviceFeatures(device.device, &features);

        var score: i32 = 0;

        if (properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            score += 1000;
        }

        score += @intCast(properties.limits.maxImageDimension2D);

        std.debug.print("Device ({}): {s}\n", .{ score, properties.deviceName });
        if (score > bestScore) {
            bestScore = score;
            bestDevice = device;
        }
    }

    if (bestScore == -1) bestDevice = null;
    return bestDevice orelse error.NoDeviceAvailable;
}

fn DebugMessengerCallback(messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: c.VkDebugUtilsMessageTypeFlagsEXT, callbackData: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, userData: ?*anyopaque) callconv(.C) c.VkBool32 {
    _ = messageType;
    _ = userData;

    switch (messageSeverity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT, c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => {
            std.debug.print("VULKAN INFO: {s}\n", .{callbackData.?.pMessage});
        },
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
            std.debug.print("VULKAN ERROR: {s}\n", .{callbackData.?.pMessage});
        },
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
            std.debug.print("VULKAN WARN: {s}\n", .{callbackData.?.pMessage});
        },
        else => {
            std.debug.print("VULKAN: {s}\n", .{callbackData.?.pMessage});
        },
    }

    return c.VK_FALSE;
}

fn vkCreateDebugUtilsMessengerEXT(instance: c.VkInstance, pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: [*c]const c.VkAllocationCallbacks, pDebugMessenger: *c.VkDebugUtilsMessengerEXT) c.VkResult {
    const func = @as(c.PFN_vkCreateDebugUtilsMessengerEXT, @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")));
    if (func != null) {
        return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
    } else {
        return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}

fn vkDestroyDebugUtilsMessengerEXT(instance: c.VkInstance, debugMessenger: c.VkDebugUtilsMessengerEXT, pAllocator: [*c]const c.VkAllocationCallbacks) void {
    const func = @as(c.PFN_vkDestroyDebugUtilsMessengerEXT, @ptrCast(c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")));
    if (func != null) {
        func.?(instance, debugMessenger, pAllocator);
    }
}
