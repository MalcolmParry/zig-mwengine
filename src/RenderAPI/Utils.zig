const std = @import("std");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const c = VK.c;

pub fn GetDepthFormat(phys: c.VkPhysicalDevice) !c.VkFormat {
    const formats: [3]c.VkFormat = .{ c.VK_FORMAT_D32_SFLOAT, c.VK_FORMAT_D32_SFLOAT_S8_UINT, c.VK_FORMAT_D24_UNORM_S8_UINT };
    for (formats) |format| {
        var props: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(phys, format, &props);

        if (props.optimalTilingFeatures & c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT > 0)
            return format;
    }

    return error.NoDepthFormatSuitable;
}

fn FindMemoryType(phys: c.VkPhysicalDevice, typeFilter: u32, props: c.VkMemoryPropertyFlags) !u32 {
    var memProps: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(phys, &memProps);

    for (0..memProps.memoryTypeCount) |i| {
        if ((typeFilter & (@as(u32, 1) << @intCast(i))) != 0 and (memProps.memoryTypes[i].propertyFlags & props) == props)
            return @intCast(i);
    }

    return error.NoMemoryTypeSuitable;
}

pub fn CreateBuffer(device: c.VkDevice, phys: c.VkPhysicalDevice, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, props: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, devMem: *c.VkDeviceMemory) !void {
    const bufferInfo: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    try VK.Try(c.vkCreateBuffer(device, &bufferInfo, null, buffer));
    errdefer c.vkDestroyBuffer(device, buffer.*, null);

    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer.*, &memRequirements);

    const allocInfo: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = size,
        .memoryTypeIndex = try FindMemoryType(phys, memRequirements.memoryTypeBits, props),
    };

    try VK.Try(c.vkAllocateMemory(device, &allocInfo, null, devMem));
    errdefer c.vkFreeMemory(device, devMem.*, null);

    try VK.Try(c.vkBindBufferMemory(device, buffer.*, devMem.*, 0));
}

pub fn CopyBuffer(device: *const Device, src: c.VkBuffer, dst: c.VkBuffer, size: u32, srcOffset: u32, dstOffset: u32) void {
    const commandBuffer = try BeginSingleUseCommandBuffer(device);

    const copyRegion: c.VkBufferCopy = .{
        .srcOffset = srcOffset,
        .dstOffset = dstOffset,
        .size = size,
    };

    c.vkCmdCopyBuffer(commandBuffer, src, dst, 1, &copyRegion);
    try EndSingleUseCommandBuffer(device, commandBuffer);
}

fn BeginSingleUseCommandBuffer(device: *const Device) !c.VkCommandBuffer {
    const allocInfo: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = device._commandPool,
        .commandBufferCount = 1,
    };

    var commandBuffer: c.VkCommandBuffer = undefined;
    try VK.Try(c.vkAllocateCommandBuffers(device._device, &allocInfo, &commandBuffer));
    errdefer c.vkFreeCommandBuffers(device._device, device._commandPool, 1, &commandBuffer);

    const beginInfo: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    c.vkBeginCommandBuffer(commandBuffer, &beginInfo);

    return commandBuffer;
}

fn EndSingleUseCommandBuffer(device: *const Device, commandBuffer: c.VkCommandBuffer) !void {
    try VK.Try(c.vkEndCommandBuffer(commandBuffer));

    const submitInfo: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
    };

    c.vkQueueSubmit(device._graphicsQueue, 1, &submitInfo, null);
    c.vkQueueWaitIdle(device._graphicsQueue);

    c.vkFreeCommandBuffers(device._device, device._commandPool, 1, &commandBuffer);
}
