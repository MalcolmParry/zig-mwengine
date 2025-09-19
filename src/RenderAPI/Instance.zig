const std = @import("std");
const Profiler = @import("../Profiler.zig");
const Platform = @import("../Platform.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");

const c = VK.c;

const validationExtentions: [1][*:0]const u8 = .{
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

_instance: c.VkInstance,
_debugMessenger: c.VkDebugUtilsMessengerEXT,
_physicalDevices: []Device.Physical,

//  TODO: add app version to paramerers
pub fn Create(debugLogging: bool, alloc: std.mem.Allocator) !@This() {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

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

    try VK.Try(c.vkCreateInstance(&instanceCreateInfo, null, &this._instance));
    errdefer c.vkDestroyInstance(this._instance, null);

    if (debugLogging) {
        const debugMessengerCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = DebugMessengerCallback,
            .pUserData = null,
        };

        try VK.Try(vkCreateDebugUtilsMessengerEXT(this._instance, &debugMessengerCreateInfo, null, &this._debugMessenger));
    } else {
        this._debugMessenger = null;
    }

    errdefer if (debugLogging) vkDestroyDebugUtilsMessengerEXT(this._instance, this._debugMessenger, null);

    var deviceCount: u32 = 0;
    try VK.Try(c.vkEnumeratePhysicalDevices(this._instance, &deviceCount, null));
    const nativePhysicalDevices = try alloc.alloc(c.VkPhysicalDevice, deviceCount);
    defer alloc.free(nativePhysicalDevices);
    try VK.Try(c.vkEnumeratePhysicalDevices(this._instance, &deviceCount, nativePhysicalDevices.ptr));
    this._physicalDevices = try alloc.alloc(Device.Physical, deviceCount);
    errdefer alloc.free(this._physicalDevices);

    for (0..deviceCount) |i| {
        const device = &this._physicalDevices[i];
        device._device = nativePhysicalDevices[i];

        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device._device, &queueFamilyCount, null);
        const queueFamilies = try alloc.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer alloc.free(queueFamilies);
        c.vkGetPhysicalDeviceQueueFamilyProperties(device._device, &queueFamilyCount, queueFamilies.ptr);
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

pub fn Destroy(this: *@This(), alloc: std.mem.Allocator) void {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    alloc.free(this._physicalDevices);
    if (this._debugMessenger != null) vkDestroyDebugUtilsMessengerEXT(this._instance, this._debugMessenger, null);
    c.vkDestroyInstance(this._instance, null);
}

pub const CreateDevice = Device.Create;

pub fn BestPhysicalDevice(this: *const @This(), alloc: std.mem.Allocator) !Device.Physical {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    _ = alloc;

    var bestDevice: ?Device.Physical = null;
    var bestScore: i32 = -1;
    for (this._physicalDevices) |device| {
        var properties: c.VkPhysicalDeviceProperties = undefined;
        var features: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceProperties(device._device, &properties);
        c.vkGetPhysicalDeviceFeatures(device._device, &features);

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
