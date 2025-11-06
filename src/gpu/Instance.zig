const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");

const c = vk.c;

const validation_extensions: [1][*:0]const u8 = .{
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

_instance: c.VkInstance,
_debug_messenger: c.VkDebugUtilsMessengerEXT,
_physical_devices: []Device.Physical,

//  TODO: add app version to paramerers
pub fn init(debug_logging: bool, alloc: std.mem.Allocator) !@This() {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    var this: @This() = undefined;

    const app_info: c.VkApplicationInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "placeholder",
        .applicationVersion = 0,
        .pEngineName = "mwengine",
        .engineVersion = 0, // TODO: fill in
        .apiVersion = c.VK_API_VERSION_1_0,
    };

    // TODO: check extention support
    const validation_layer: [*]const u8 = "VK_LAYER_KHRONOS_validation";
    const extensions = vk.required_extensions;
    const debug_extensions = extensions ++ validation_extensions;

    const instance_create_info: c.VkInstanceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = if (debug_logging) debug_extensions.len else extensions.len,
        .ppEnabledExtensionNames = if (debug_logging) &debug_extensions else &extensions,
        .enabledLayerCount = if (debug_logging) 1 else 0,
        .ppEnabledLayerNames = if (debug_logging) &validation_layer else null,
    };

    try vk.wrap(c.vkCreateInstance(&instance_create_info, null, &this._instance));
    errdefer c.vkDestroyInstance(this._instance, null);

    if (debug_logging) {
        const debug_messenger_create_info: c.VkDebugUtilsMessengerCreateInfoEXT = .{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debugMessengerCallback,
            .pUserData = null,
        };

        try vk.wrap(vkCreateDebugUtilsMessengerEXT(this._instance, &debug_messenger_create_info, null, &this._debug_messenger));
    } else {
        this._debug_messenger = null;
    }

    errdefer if (debug_logging) vkDestroyDebugUtilsMessengerEXT(this._instance, this._debug_messenger, null);

    var device_count: u32 = 0;
    try vk.wrap(c.vkEnumeratePhysicalDevices(this._instance, &device_count, null));
    const native_physical_devices = try alloc.alloc(c.VkPhysicalDevice, device_count);
    defer alloc.free(native_physical_devices);
    try vk.wrap(c.vkEnumeratePhysicalDevices(this._instance, &device_count, native_physical_devices.ptr));
    this._physical_devices = try alloc.alloc(Device.Physical, device_count);
    errdefer alloc.free(this._physical_devices);

    for (0..device_count) |i| {
        const device = &this._physical_devices[i];
        device._device = native_physical_devices[i];

        var queue_family_count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device._device, &queue_family_count, null);
        const queue_families = try alloc.alloc(c.VkQueueFamilyProperties, queue_family_count);
        defer alloc.free(queue_families);
        c.vkGetPhysicalDeviceQueueFamilyProperties(device._device, &queue_family_count, queue_families.ptr);
        std.debug.print("\n", .{});

        for (queue_families) |prop| {
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

pub fn deinit(this: *@This(), alloc: std.mem.Allocator) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    alloc.free(this._physical_devices);
    if (this._debug_messenger != null) vkDestroyDebugUtilsMessengerEXT(this._instance, this._debug_messenger, null);
    c.vkDestroyInstance(this._instance, null);
}

pub const initDevice = Device.init;

pub fn bestPhysicalDevice(this: *const @This(), alloc: std.mem.Allocator) !Device.Physical {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    _ = alloc;

    var best_device: ?Device.Physical = null;
    var best_score: i32 = -1;
    for (this._physical_devices) |device| {
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
        if (score > best_score) {
            best_score = score;
            best_device = device;
        }
    }

    if (best_score == -1) best_device = null;
    return best_device orelse error.NoDeviceAvailable;
}

fn debugMessengerCallback(message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, message_type: c.VkDebugUtilsMessageTypeFlagsEXT, callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, context: ?*anyopaque) callconv(.c) c.VkBool32 {
    _ = message_type;
    _ = context;

    switch (message_severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT, c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => {
            std.debug.print("VULKAN INFO: {s}\n", .{callback_data.?.pMessage});
        },
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
            std.debug.print("VULKAN ERROR: {s}\n", .{callback_data.?.pMessage});
        },
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
            std.debug.print("VULKAN WARN: {s}\n", .{callback_data.?.pMessage});
        },
        else => {
            std.debug.print("VULKAN: {s}\n", .{callback_data.?.pMessage});
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
