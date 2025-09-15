const std = @import("std");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const c = VK.c;

device: *const Device,
_buffer: c.VkBuffer,
_deviceMemory: c.VkDeviceMemory,
_size: usize,
_stagingBuffer: c.VkBuffer,
_stagingMemory: c.VkDeviceMemory,

pub fn Create(device: *const Device, size: usize, usage: BufferUsage) !@This() {
    var this: @This() = undefined;
    this.device = device;
    this._size = size;
    this._stagingBuffer = null;
    this._stagingMemory = null;

    var vkUsage: c.VkBufferUsageFlags = 0;
    if (usage.vertex or usage.instance) vkUsage |= c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
    if (usage.index) vkUsage |= c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
    if (usage.uniform) vkUsage |= c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
    if (usage.src) vkUsage |= c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    if (usage.dst) vkUsage |= c.VK_BUFFER_USAGE_TRANSFER_DST_BIT;

    try VK.Utils.CreateBuffer(device._device, device.physical._device, size, vkUsage, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &this._buffer, &this._deviceMemory);

    return this;
}

pub fn Destroy(this: *const @This()) void {
    c.vkDestroyBuffer(this.device._device, this._buffer, null);
    c.vkFreeMemory(this.device._device, this._deviceMemory, null);
}

pub fn MapData(this: *const @This()) ![]u8 {
    if (this._stagingBuffer or this._stagingMemory)
        return error.AlreadyMapped;

    VK.Utils.CreateBuffer(this.device._device, this.device.physical._device, this._size, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &this._stagingBuffer, &this._stagingMemory);

    var map: [*]u8 = undefined;
    c.vkMapMemory(this.device._device, this._stagingMemory, 0, this._size, 0, &map);
    return map[0 .. this._size - 1];
}

pub fn UnmapData(this: *const @This()) !void {
    c.vkUnmapMemory(this.device._device, this._stagingMemory);

    VK.Utils.CopyBuffer(this.device._device, this._stagingBuffer, this._buffer, this._size, 0, 0);

    c.vkDestroyBuffer(this.device, this._stagingBuffer, null);
    c.vkFreeMemory(this.device, this._stagingMemory, null);
}

pub fn SetData(this: *const @This(), data: []u8) !void {
    const map = try this.MapData();
    @memcpy(map, data);
    try this.UnmapData();
}

const BufferUsage = struct {
    vertex: bool = false,
    index: bool = false,
    instance: bool = false,
    uniform: bool = false,
    src: bool = false,
    dst: bool = false,
};
