const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const Platform = @import("../Platform.zig");
const RenderPass = @import("RenderPass.zig");
const Semaphore = @import("WaitObjects.zig").Semaphore;
const Fence = @import("WaitObjects.zig").Fence;
const Image = @import("Image.zig");
const c = VK.c;

device: *Device,
imageSize: @Vector(2, u32),
images: []Image,
imageViews: []Image.View,
_surface: c.VkSurfaceKHR,
_surfaceFormat: c.VkSurfaceFormatKHR,
_swapchain: c.VkSwapchainKHR,

pub fn Create(device: *Device, window: *Platform.Window, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.device = device;
    this.imageSize = window.GetClientSize();

    const nativeInstance: c.VkInstance = device.instance._instance;
    this._surface = try Platform.Vulkan.CreateSurface(window, nativeInstance);
    this._surfaceFormat = try ChooseSurfaceFormat(&this, alloc);
    this._swapchain = null;
    try this.CreateSwapchain(alloc);

    return this;
}

pub fn Destroy(this: *@This(), alloc: std.mem.Allocator) void {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    for (this.imageViews) |*imageView| {
        c.vkDestroyImageView(this.device._device, imageView._imageView, null);
    }

    alloc.free(this.imageViews);
    alloc.free(this.images);
    c.vkDestroySwapchainKHR(this.device._device, this._swapchain, null);
    c.vkDestroySurfaceKHR(this.device.instance._instance, this._surface, null);
}

pub fn GetNextFramebufferIndex(this: *const @This(), signalSemaphore: ?*Semaphore, signalFence: ?*Fence, timeoutNs: u64) !u32 {
    const nativeSemaphore = if (signalSemaphore) |x| x._semaphore else null;
    const nativeFence = if (signalFence) |x| x._fence else null;
    var index: u32 = undefined;

    if (VK.Try(c.vkAcquireNextImageKHR(this.device._device, this._swapchain, timeoutNs, nativeSemaphore, nativeFence, &index))) {
        return index;
    } else |err| switch (err) {
        VK.Error.VK_SUBOPTIMAL_KHR => return index, // TODO: allow app to rebuild when suboptimal
        else => return err,
    }
}

fn CreateSwapchain(this: *@This(), alloc: std.mem.Allocator) !void {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    const oldSwapchain: c.VkSwapchainKHR = this._swapchain;

    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try VK.Try(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this.device.physical._device, this._surface, &capabilities));

    var minImageCount = capabilities.minImageCount + 1;
    if (capabilities.maxImageCount > 0 and minImageCount > capabilities.maxImageCount) {
        minImageCount = capabilities.maxImageCount;
    }

    const imageFormat = try ChooseSurfaceFormat(this, alloc);
    const extent = try ChooseSwapExtent(this);

    const createInfo: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = this._surface,
        .minImageCount = minImageCount,
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
        .presentMode = 0, // TODO: implement
        .clipped = 1,
        .oldSwapchain = oldSwapchain,
    };

    try VK.Try(c.vkCreateSwapchainKHR(this.device._device, &createInfo, null, &this._swapchain));

    var imageCount: u32 = undefined;
    try VK.Try(c.vkGetSwapchainImagesKHR(this.device._device, this._swapchain, &imageCount, null));
    const images = try alloc.alloc(c.VkImage, imageCount);
    defer alloc.free(images);
    try VK.Try(c.vkGetSwapchainImagesKHR(this.device._device, this._swapchain, &imageCount, images.ptr));

    this.images = try alloc.alloc(Image, imageCount);
    errdefer alloc.free(this.images);
    for (this.images, 0..) |*image, i| {
        image.* = .{
            ._image = images[i],
        };
    }

    this.imageViews = try alloc.alloc(Image.View, imageCount);
    errdefer alloc.free(this.imageViews);
    for (this.images, this.imageViews) |*image, *imageView| {
        imageView.* = .{
            .device = this.device,
            ._imageView = null,
        };

        const viewCreateInfo: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image._image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D, // TODO: allow for different types
            .format = imageFormat.format,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0, // TODO: allow for mip mapping
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        try VK.Try(c.vkCreateImageView(this.device._device, &viewCreateInfo, null, &imageView._imageView));
    }
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

    return .{
        .width = std.math.clamp(this.imageSize[0], capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
        .height = std.math.clamp(this.imageSize[1], capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
    };
}

pub const CreateRenderPass = RenderPass.Create;
