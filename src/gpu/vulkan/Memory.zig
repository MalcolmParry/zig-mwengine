const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");

const Size = u64;
const Requirements = enum(u32) { _ };

device_memory: vk.DeviceMemory,

pub fn allocate(device: *Device, size: Size, requirements: Requirements) !@This() {
    const vk_alloc: ?*vk.AllocationCallbacks = null;
    const properties: u32 = 0;
    const mem_properties = device.instance._instance.getPhysicalDeviceMemoryProperties(device._phys);
    const mem_index: u32 = blk: {
        for (mem_properties.memory_types[0..mem_properties.memory_type_count], 0..) |mem_type, i| {
            if ((@intFromEnum(requirements) & (@as(u32, 1) << @intCast(i)) > 0) and (@as(u32, @bitCast(mem_type.property_flags)) & properties == properties))
                break :blk @intCast(i);
        }

        return error.Failed;
    };

    const device_memory = try device._device.allocateMemory(&.{
        .allocation_size = size,
        .memory_type_index = mem_index,
    }, vk_alloc);

    return .{
        .device_memory = device_memory,
    };
}

pub fn free(this: @This(), device: *Device) void {
    const vk_alloc: ?*vk.AllocationCallbacks = null;
    device._device.freeMemory(this.device_memory, vk_alloc);
}
