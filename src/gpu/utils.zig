const std = @import("std");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const c = vk.c;

pub fn getDepthFormat(phys: c.VkPhysicalDevice) !c.VkFormat {
    const formats: [3]c.VkFormat = .{ c.VK_FORMAT_D32_SFLOAT, c.VK_FORMAT_D32_SFLOAT_S8_UINT, c.VK_FORMAT_D24_UNORM_S8_UINT };
    for (formats) |format| {
        var props: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(phys, format, &props);

        if (props.optimalTilingFeatures & c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT > 0)
            return format;
    }

    return error.NoDepthFormatSuitable;
}

fn findMemoryType(phys: c.VkPhysicalDevice, typeFilter: u32, props: c.VkMemoryPropertyFlags) !u32 {
    var mem_props: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(phys, &mem_props);

    for (0..mem_props.memoryTypeCount) |i| {
        if ((typeFilter & (@as(u32, 1) << @intCast(i))) != 0 and (mem_props.memoryTypes[i].propertyFlags & props) == props)
            return @intCast(i);
    }

    return error.NoMemoryTypeSuitable;
}

pub fn createBuffer(device: c.VkDevice, phys: c.VkPhysicalDevice, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, props: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, dev_mem: *c.VkDeviceMemory) !void {
    const buffer_info: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    try vk.wrap(c.vkCreateBuffer(device, &buffer_info, null, buffer));
    errdefer c.vkDestroyBuffer(device, buffer.*, null);

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer.*, &mem_requirements);

    const alloc_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = size,
        .memoryTypeIndex = try findMemoryType(phys, mem_requirements.memoryTypeBits, props),
    };

    try vk.wrap(c.vkAllocateMemory(device, &alloc_info, null, dev_mem));
    errdefer c.vkFreeMemory(device, dev_mem.*, null);

    try vk.wrap(c.vkBindBufferMemory(device, buffer.*, dev_mem.*, 0));
}

pub fn copyBuffer(device: *const Device, src: c.VkBuffer, dst: c.VkBuffer, size: u32, srcOffset: u32, dstOffset: u32) !void {
    const command_buffer = try beginSingleUseCommandBuffer(device);

    const copy_region: c.VkBufferCopy = .{
        .srcOffset = srcOffset,
        .dstOffset = dstOffset,
        .size = size,
    };

    c.vkCmdCopyBuffer(command_buffer, src, dst, 1, &copy_region);
    try endSingleUseCommandBuffer(device, command_buffer);
}

fn beginSingleUseCommandBuffer(device: *const Device) !c.VkCommandBuffer {
    const alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = device._command_pool,
        .commandBufferCount = 1,
    };

    var command_buffer: c.VkCommandBuffer = undefined;
    try vk.wrap(c.vkAllocateCommandBuffers(device._device, &alloc_info, &command_buffer));
    errdefer c.vkFreeCommandBuffers(device._device, device._command_pool, 1, &command_buffer);

    const begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    try vk.wrap(c.vkBeginCommandBuffer(command_buffer, &begin_info));

    return command_buffer;
}

fn endSingleUseCommandBuffer(device: *const Device, command_buffer: c.VkCommandBuffer) !void {
    try vk.wrap(c.vkEndCommandBuffer(command_buffer));

    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
    };

    try vk.wrap(c.vkQueueSubmit(device._graphics_queue, 1, &submit_info, null));
    try vk.wrap(c.vkQueueWaitIdle(device._graphics_queue));

    c.vkFreeCommandBuffers(device._device, device._command_pool, 1, &command_buffer);
}
