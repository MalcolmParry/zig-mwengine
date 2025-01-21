const std = @import("std");
const Platform = @import("../Platform.zig");

const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

const linuxRequiredExtentions: [2][*:0]const u8 = .{
    "VK_KHR_surface",
    "VK_KHR_xlib_surface",
};

const validationExtentions: [1][*:0]const u8 = .{
    c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
};

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

pub const Instance = struct {
    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,

    fn DebugMessengerCallback(messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: c.VkDebugUtilsMessageTypeFlagsEXT, callbackData: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, userData: ?*anyopaque) callconv(.C) c.VkBool32 {
        _ = messageSeverity;
        _ = messageType;
        _ = userData;

        std.debug.print("fdsgksdfn;g {s}\n", .{callbackData.?.pMessage});

        return c.VK_FALSE;
    }

    //  TODO: add app version to paramerers
    pub fn Create(window: *Platform.Window, debugLogging: bool, alloc: std.mem.Allocator) !Instance {
        const vkAlloc: [*c]c.VkAllocationCallbacks = null;

        var this: Instance = undefined;

        _ = window;
        _ = alloc;

        const appInfo: c.VkApplicationInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "placeholder",
            .applicationVersion = 0,
            .pEngineName = "mwengine",
            .apiVersion = c.VK_API_VERSION_1_0,
        };

        const validationLayer: [*]const u8 = "VK_LAYER_KHRONOS_validation";
        const extentions = linuxRequiredExtentions;
        const debugExtentions = linuxRequiredExtentions ++ validationExtentions;

        const instanceCreateInfo: c.VkInstanceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = if (debugLogging) debugExtentions.len else extentions.len,
            .ppEnabledExtensionNames = if (debugLogging) &debugExtentions else &extentions,
            .enabledLayerCount = if (debugLogging) 1 else 0,
            .ppEnabledLayerNames = if (debugLogging) &validationLayer else null,
        };

        if (c.vkCreateInstance(&instanceCreateInfo, vkAlloc, &this.instance) != c.VK_SUCCESS) {
            return error.vkCreateInstanceFailure;
        }

        errdefer c.vkDestroyInstance(this.instance, vkAlloc);

        if (debugLogging) {
            const debugMessengerCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{
                .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
                .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                .pfnUserCallback = DebugMessengerCallback,
                .pUserData = null,
            };

            if (vkCreateDebugUtilsMessengerEXT(this.instance, &debugMessengerCreateInfo, vkAlloc, &this.debugMessenger) != c.VK_SUCCESS) {
                return error.VKCreateDebugUtilsMessengerEXTFailure;
            }
        } else {
            this.debugMessenger = null;
        }

        errdefer if (debugLogging) vkDestroyDebugUtilsMessengerEXT(this.instance, this.debugMessenger, vkAlloc);

        return this;
    }

    pub fn Destroy(this: *const Instance, alloc: std.mem.Allocator) void {
        const vkAlloc: [*c]c.VkAllocationCallbacks = null;
        _ = alloc;

        if (this.debugMessenger != null) {
            vkDestroyDebugUtilsMessengerEXT(this.instance, this.debugMessenger, vkAlloc);
        }

        c.vkDestroyInstance(this.instance, vkAlloc);
    }
};
