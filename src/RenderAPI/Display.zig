const std = @import("std");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const Platform = @import("../Platform.zig");
const RenderPass = @import("RenderPass.zig");
const c = VK.c;

device: *Device,
window: *const Platform.Window,
_surface: c.VkSurfaceKHR,
_surfaceFormat: c.VkSurfaceFormatKHR,
_swapchain: c.VkSwapchainKHR,

pub fn Create(device: *Device, window: *const Platform.Window, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.device = device;
    this.window = window;

    const nativeInstance: c.VkInstance = device.instance._instance;
    this._surface = try Platform.Vulkan.CreateSurface(window, nativeInstance);
    this._surfaceFormat = try ChooseSurfaceFormat(&this, alloc);
    this._swapchain = null;
    try this.CreateSwapchain(alloc);

    return this;
}

pub fn Destroy(this: *@This()) void {
    c.vkDestroySwapchainKHR(this.device._device, this._swapchain, null);
    c.vkDestroySurfaceKHR(this.device.instance._instance, this._surface, null);
}

fn CreateSwapchain(this: *@This(), alloc: std.mem.Allocator) !void {
    const oldSwapchain: c.VkSwapchainKHR = this._swapchain;

    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try VK.Try(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this.device.physical._device, this._surface, &capabilities));

    var imageCount = capabilities.minImageCount + 1;
    if (capabilities.maxImageCount > 0 and imageCount > capabilities.maxImageCount) {
        imageCount = capabilities.maxImageCount;
    }

    const imageFormat = try ChooseSurfaceFormat(this, alloc);
    const extent = try ChooseSwapExtent(this);

    const createInfo: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = this._surface,
        .minImageCount = imageCount,
        .imageFormat = imageFormat.format,
        .imageColorSpace = imageFormat.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = 0, // todo
        .clipped = 1,
        .oldSwapchain = oldSwapchain,
    };

    try VK.Try(c.vkCreateSwapchainKHR(this.device._device, &createInfo, null, &this._swapchain));
}

fn ChooseSurfaceFormat(this: *const @This(), alloc: std.mem.Allocator) !c.VkSurfaceFormatKHR {
    var formatCount: u32 = 0;
    try VK.Try(c.vkGetPhysicalDeviceSurfaceFormatsKHR(this.device.physical._device, this._surface, &formatCount, null));
    if (formatCount == 0)
        return error.NoFormat;

    const formats = try alloc.alloc(c.VkSurfaceFormatKHR, formatCount);
    defer alloc.free(formats);
    try VK.Try(c.vkGetPhysicalDeviceSurfaceFormatsKHR(this.device.physical._device, this._surface, &formatCount, formats.ptr));

    for (formats) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }

    return formats[0];
}

fn ChooseSwapExtent(this: *const @This()) !c.VkExtent2D {
    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try VK.Try(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this.device.physical._device, this._surface, &capabilities));

    if (capabilities.currentExtent.width != std.math.maxInt(u32))
        return capabilities.currentExtent;

    const windowSize = this.window.GetClientSize();
    return .{
        .width = std.math.clamp(windowSize[0], capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
        .height = std.math.clamp(windowSize[1], capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
    };
}

pub const CreateRenderPass = RenderPass.Create;
