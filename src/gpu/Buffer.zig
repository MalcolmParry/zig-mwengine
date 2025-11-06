const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const c = vk.c;

device: *Device,
_buffer: c.VkBuffer,
_device_memory: c.VkDeviceMemory,
_size: usize,
_staging_buffer: c.VkBuffer,
_staging_memory: c.VkDeviceMemory,

pub fn init(device: *Device, size: usize, usage: BufferUsage) !@This() {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    var this: @This() = undefined;
    this.device = device;
    this._size = size;
    this._staging_buffer = null;
    this._staging_memory = null;

    var vkUsage: c.VkBufferUsageFlags = 0;
    if (usage.vertex or usage.instance) vkUsage |= c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
    if (usage.index) vkUsage |= c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
    if (usage.uniform) vkUsage |= c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
    if (usage.src) vkUsage |= c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    if (usage.dst) vkUsage |= c.VK_BUFFER_USAGE_TRANSFER_DST_BIT;

    try vk.utils.createBuffer(device._device, device.physical._device, size, vkUsage, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &this._buffer, &this._device_memory);

    return this;
}

pub fn deinit(this: *const @This()) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    c.vkDestroyBuffer(this.device._device, this._buffer, null);
    c.vkFreeMemory(this.device._device, this._device_memory, null);
}

pub fn mapData(this: *@This()) ![]u8 {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    if (this._staging_buffer != null or this._staging_memory != null)
        return error.AlreadyMapped;

    try vk.utils.createBuffer(this.device._device, this.device.physical._device, this._size, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &this._staging_buffer, &this._staging_memory);

    var map: [*]u8 = undefined;
    try vk.wrap(c.vkMapMemory(this.device._device, this._staging_memory, 0, this._size, 0, @ptrCast(&map)));
    return map[0..this._size];
}

pub fn unmapData(this: *@This()) !void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    c.vkUnmapMemory(this.device._device, this._staging_memory);

    try vk.utils.copyBuffer(this.device, this._staging_buffer, this._buffer, @intCast(this._size), 0, 0);

    c.vkDestroyBuffer(this.device._device, this._staging_buffer, null);
    c.vkFreeMemory(this.device._device, this._staging_memory, null);
}

pub fn setData(this: *@This(), data: []const u8) !void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    const map = try this.mapData();
    @memcpy(map, data);
    try this.unmapData();
}

const BufferUsage = packed struct {
    vertex: bool = false,
    index: bool = false,
    instance: bool = false,
    uniform: bool = false,
    src: bool = false,
    dst: bool = false,
};
