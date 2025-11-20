const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");

const Buffer = @This();
const Size = Device.Size;
const Usage = packed struct {
    const BackingInt = @typeInfo(@TypeOf(@This())).@"struct".backing_integer.?;
    const all = std.math.maxInt(BackingInt);

    map_read: bool = false,
    map_write: bool = false,
    src: bool = false,
    dst: bool = false,
    vertex: bool = false,
    instance: bool = false,
    index: bool = false,
    uniform: bool = false,
};

_staging: ?_Staging,
_buffer: vk.Buffer,
_memory_region: Device._MemoryRegion,
_usage: Usage,

pub fn init(device: *Device, size: Size, usage: Usage) !@This() {
    const vk_alloc: ?*vk.AllocationCallbacks = null;
    const vk_usage: vk.BufferUsageFlags = .{
        .vertex_buffer_bit = usage.vertex or usage.instance,
        .index_buffer_bit = usage.index,
        .uniform_buffer_bit = usage.uniform,
        .transfer_src_bit = usage.src or usage.map_read,
        .transfer_dst_bit = usage.dst or usage.map_write,
    };

    const buffer = try device._device.createBuffer(&.{
        .size = size,
        .usage = vk_usage,
        .sharing_mode = .exclusive,
    }, vk_alloc);
    errdefer device._device.destroyBuffer(buffer, vk_alloc);

    const properties: vk.MemoryPropertyFlags = .{ .device_local_bit = true };
    const mem_region = try device._allocateMemory(device._device.getBufferMemoryRequirements(buffer), properties);
    errdefer device._freeMemory(mem_region);
    try device._device.bindBufferMemory(buffer, mem_region.memory, mem_region.offset);

    const staging: ?_Staging = if (usage.map_read or usage.map_write) try _Staging.init(device, size, usage.map_read, usage.map_write) else null;

    return .{
        ._staging = staging,
        ._buffer = buffer,
        ._memory_region = mem_region,
        ._usage = usage,
    };
}

pub fn deinit(this: *@This(), device: *Device) void {
    const vk_alloc: ?*vk.AllocationCallbacks = null;
    if (this._staging) |*staging| staging.deinit(device);
    device._device.destroyBuffer(this._buffer, vk_alloc);
    device._freeMemory(this._memory_region);
}

pub fn map(this: *@This(), device: *Device) ![]u8 {
    const region: Region = .{
        .buffer = this,
        .offset = 0,
        .size = this._memory_region.size,
    };

    return region.map(device);
}

pub fn unmap(this: *@This(), device: *Device) void {
    const region: Region = .{
        .buffer = this,
        .offset = 0,
        .size = this._memory_region.size,
    };

    region.unmap(device);
}

pub const Region = struct {
    buffer: *Buffer,
    offset: Size,
    size: Size,

    pub fn map(this: @This(), device: *Device) ![]u8 {
        const staging = this.buffer._staging.?;
        const data = (try device._device.mapMemory(staging._memory_region.memory, staging._memory_region.offset, staging._memory_region.size, .{})).?;
        const many_ptr: [*]u8 = @ptrCast(data);
        return many_ptr[0..this.size];
    }

    pub fn unmap(this: @This(), device: *Device) void {
        device._device.unmapMemory(this.buffer._staging.?._memory_region.memory);
        // TODO: copy data from staging buffer
    }
};

pub const _Staging = struct {
    _buffer: vk.Buffer,
    _memory_region: Device._MemoryRegion,

    pub fn init(device: *Device, size: Size, read: bool, write: bool) !@This() {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        const buffer = try device._device.createBuffer(&.{
            .size = size,
            .usage = .{
                .transfer_src_bit = write,
                .transfer_dst_bit = read,
            },
            .sharing_mode = .exclusive,
        }, vk_alloc);
        errdefer device._device.destroyBuffer(buffer, vk_alloc);

        const properties: vk.MemoryPropertyFlags = .{ .host_visible_bit = true };
        const mem_region = try device._allocateMemory(device._device.getBufferMemoryRequirements(buffer), properties);
        errdefer device._freeMemory(mem_region);
        try device._device.bindBufferMemory(buffer, mem_region.memory, mem_region.offset);

        return .{
            ._buffer = buffer,
            ._memory_region = mem_region,
        };
    }

    pub fn deinit(this: *@This(), device: *Device) void {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        device._device.destroyBuffer(this._buffer, vk_alloc);
        device._freeMemory(this._memory_region);
    }
};
