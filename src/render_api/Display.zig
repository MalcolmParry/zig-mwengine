const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const platform = @import("../platform.zig");
const RenderPass = @import("RenderPass.zig");
const Semaphore = @import("wait_objects.zig").Semaphore;
const Fence = @import("wait_objects.zig").Fence;
const Image = @import("Image.zig");
const c = vk.c;

device: *Device,
image_size: @Vector(2, u32),
images: []Image,
image_views: []Image.View,
_surface: c.VkSurfaceKHR,
_surface_format: c.VkSurfaceFormatKHR,
_swapchain: c.VkSwapchainKHR,

pub fn init(device: *Device, window: *platform.Window, alloc: std.mem.Allocator) !@This() {
    var this: @This() = undefined;
    this.device = device;
    this.image_size = window.getClientSize();

    this._surface = try platform.vulkan.createSurface(window, device.instance._instance);
    this._surface_format = try chooseSurfaceFormat(&this, alloc);
    this._swapchain = null;
    try this.createSwapchain(alloc);

    return this;
}

pub fn deinit(this: *@This(), alloc: std.mem.Allocator) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    this.destroySwapchain(alloc);
    c.vkDestroySwapchainKHR(this.device._device, this._swapchain, null);
    c.vkDestroySurfaceKHR(this.device.instance._instance, this._surface, null);
}

pub const initRenderPass = RenderPass.init;

pub fn acquireFramebufferIndex(this: *@This(), signal_semaphore: ?*Semaphore, signal_fence: ?*Fence, timeout_ns: u64) !u32 {
    const native_semaphore = if (signal_semaphore) |x| x._semaphore else null;
    const native_fence = if (signal_fence) |x| x._fence else null;
    var index: u32 = undefined;

    if (vk.wrap(c.vkAcquireNextImageKHR(this.device._device, this._swapchain, timeout_ns, native_semaphore, native_fence, &index))) {
        return index;
    } else |err| switch (err) {
        vk.Error.VK_SUBOPTIMAL_KHR, vk.Error.VK_ERROR_OUT_OF_DATE_KHR => return error.DisplayOutOfDate,
        else => return err,
    }
}

pub fn releaseFramebufferIndex(this: *@This(), index: u32) !void {
    const release_info: c.VkReleaseSwapchainImagesInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_RELEASE_SWAPCHAIN_IMAGES_INFO_KHR,
        .swapchain = this._swapchain,
        .imageIndexCount = 1,
        .pImageIndices = &index,
    };

    try vk.wrap(vkReleaseSwapchainImagesEXT(this.device._device, &release_info));
}

// TODO: allow for multiple semaphores and fences
pub fn presentFramebuffer(this: *@This(), index: u32, wait_semaphore: ?*Semaphore, signal_fence: ?*Fence) !void {
    const native_semaphore = if (wait_semaphore) |x| &x._semaphore else null;

    const present_fence_info: ?c.VkSwapchainPresentFenceInfoKHR = if (signal_fence) |x| .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_FENCE_INFO_KHR,
        .swapchainCount = 1,
        .pFences = &x._fence,
    } else null;

    const present_info: c.VkPresentInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = if (wait_semaphore) |_| 1 else 0,
        .pWaitSemaphores = native_semaphore,
        .swapchainCount = 1,
        .pSwapchains = &this._swapchain,
        .pImageIndices = &index,
        .pResults = null,
        .pNext = if (signal_fence) |_| &present_fence_info.? else null,
    };

    if (vk.wrap(c.vkQueuePresentKHR(this.device._graphics_queue, &present_info))) {} else |err| switch (err) {
        vk.Error.VK_SUBOPTIMAL_KHR, vk.Error.VK_ERROR_OUT_OF_DATE_KHR => return error.DisplayOutOfDate,
        else => return err,
    }
}

pub fn rebuild(this: *@This(), image_size: @Vector(2, u32), alloc: std.mem.Allocator) !void {
    const old_swapchain = this._swapchain;
    this.destroySwapchain(alloc);
    this.image_size = image_size;
    try this.createSwapchain(alloc);
    c.vkDestroySwapchainKHR(this.device._device, old_swapchain, null);
}

fn createSwapchain(this: *@This(), alloc: std.mem.Allocator) !void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    const old_swapchain: c.VkSwapchainKHR = this._swapchain;

    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try vk.wrap(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this.device.physical._device, this._surface, &capabilities));

    var min_image_count = capabilities.minImageCount + 1;
    if (capabilities.maxImageCount > 0 and min_image_count > capabilities.maxImageCount) {
        min_image_count = capabilities.maxImageCount;
    }

    const image_format = try chooseSurfaceFormat(this, alloc);
    const extent = try chooseSwapExtent(this);

    const create_info: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = this._surface,
        .minImageCount = min_image_count,
        .imageFormat = image_format.format,
        .imageColorSpace = image_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = c.VK_PRESENT_MODE_IMMEDIATE_KHR, // TODO: allow change
        .clipped = 1,
        .oldSwapchain = old_swapchain,
    };

    try vk.wrap(c.vkCreateSwapchainKHR(this.device._device, &create_info, null, &this._swapchain));

    var image_count: u32 = undefined;
    try vk.wrap(c.vkGetSwapchainImagesKHR(this.device._device, this._swapchain, &image_count, null));
    const images = try alloc.alloc(c.VkImage, image_count);
    defer alloc.free(images);
    try vk.wrap(c.vkGetSwapchainImagesKHR(this.device._device, this._swapchain, &image_count, images.ptr));

    this.images = try alloc.alloc(Image, image_count);
    errdefer alloc.free(this.images);
    for (this.images, 0..) |*image, i| {
        image.* = .{
            ._image = images[i],
        };
    }

    this.image_views = try alloc.alloc(Image.View, image_count);
    errdefer alloc.free(this.image_views);
    for (this.images, this.image_views) |*image, *imageView| {
        imageView.* = .{
            .device = this.device,
            ._image_view = null,
        };

        const view_create_info: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image._image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D, // TODO: allow for different types
            .format = image_format.format,
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0, // TODO: allow for mip mapping
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        try vk.wrap(c.vkCreateImageView(this.device._device, &view_create_info, null, &imageView._image_view));
    }
}

fn destroySwapchain(this: *@This(), alloc: std.mem.Allocator) void {
    for (this.image_views) |*imageView| {
        c.vkDestroyImageView(this.device._device, imageView._image_view, null);
    }

    alloc.free(this.image_views);
    alloc.free(this.images);
}

fn chooseSurfaceFormat(this: *const @This(), alloc: std.mem.Allocator) !c.VkSurfaceFormatKHR {
    var format_count: u32 = 0;
    try vk.wrap(c.vkGetPhysicalDeviceSurfaceFormatsKHR(this.device.physical._device, this._surface, &format_count, null));
    if (format_count == 0)
        return error.NoFormat;

    const formats = try alloc.alloc(c.VkSurfaceFormatKHR, format_count);
    defer alloc.free(formats);
    try vk.wrap(c.vkGetPhysicalDeviceSurfaceFormatsKHR(this.device.physical._device, this._surface, &format_count, formats.ptr));

    for (formats) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }

    return formats[0];
}

fn chooseSwapExtent(this: *const @This()) !c.VkExtent2D {
    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try vk.wrap(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this.device.physical._device, this._surface, &capabilities));

    if (capabilities.currentExtent.width != std.math.maxInt(u32))
        return capabilities.currentExtent;

    return .{
        .width = std.math.clamp(this.image_size[0], capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
        .height = std.math.clamp(this.image_size[1], capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
    };
}

fn vkReleaseSwapchainImagesEXT(device: ?*c.struct_VkDevice_T, pReleaseInfo: [*c]const c.struct_VkReleaseSwapchainImagesInfoKHR) c.VkResult {
    const func = @as(c.PFN_vkReleaseSwapchainImagesEXT, @ptrCast(c.vkGetDeviceProcAddr(device, "vkReleaseSwapchainImagesEXT")));
    if (func != null) {
        return func.?(device, pReleaseInfo);
    } else {
        return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}
