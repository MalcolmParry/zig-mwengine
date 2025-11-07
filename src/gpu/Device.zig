const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan");
const Instance = @import("Instance.zig");
// const Display = @import("Display.zig");
// const Buffer = @import("Buffer.zig");

pub const required_extensions: [2][*:0]const u8 = .{
    vk.extensions.khr_swapchain.name,
    vk.extensions.ext_swapchain_maintenance_1.name,
};

pub const Physical = struct {
    _device: vk.PhysicalDevice,
};

_device: vk.DeviceProxy,
_queue: vk.Queue,
_queue_family_index: u32,
_command_pool: vk.CommandPool,

pub fn init(instance: *const Instance, physical_device: *const Physical, alloc: std.mem.Allocator) !@This() {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    const vk_alloc: ?*vk.AllocationCallbacks = null;
    const queue_priority: f32 = 1;
    const queue_family_index: u32 = blk: {
        const queue_familes = try instance._instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(physical_device._device, alloc);
        defer alloc.free(queue_familes);

        for (queue_familes, 0..) |prop, i| {
            if (prop.queue_flags.graphics_bit and prop.queue_flags.transfer_bit)
                break :blk @intCast(i);
        }

        return error.NoSuitableQueue;
    };

    const queue_create_info: vk.DeviceQueueCreateInfo = .{
        .queue_family_index = queue_family_index,
        .queue_count = 1,
        .p_queue_priorities = @ptrCast(&queue_priority),
    };

    var swapchain_maintenance: vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT = .{
        .swapchain_maintenance_1 = .true,
    };

    // TODO: check extention support
    const device_handle = try instance._instance.createDevice(physical_device._device, &.{
        .p_queue_create_infos = @ptrCast(&queue_create_info),
        .queue_create_info_count = 1,
        .enabled_extension_count = required_extensions.len,
        .pp_enabled_extension_names = &required_extensions,
        .p_next = &vk.PhysicalDeviceFeatures2{
            .features = .{
                .sampler_anisotropy = .true,
            },
            .p_next = &swapchain_maintenance,
        },
    }, vk_alloc);

    const device_wrapper = try alloc.create(vk.DeviceWrapper);
    errdefer alloc.destroy(device_wrapper);
    device_wrapper.* = .load(device_handle, instance._instance.wrapper.dispatch.vkGetDeviceProcAddr orelse return error.CantLoadVulkan);
    const device = vk.DeviceProxy.init(device_handle, device_wrapper);
    errdefer device.destroyDevice(vk_alloc);

    const queue = device.getDeviceQueue(queue_family_index, 0);
    const command_pool = try device.createCommandPool(&.{
        .queue_family_index = queue_family_index,
        .flags = .{
            .reset_command_buffer_bit = true,
        },
    }, vk_alloc);

    return .{
        ._device = device,
        ._queue = queue,
        ._queue_family_index = queue_family_index,
        ._command_pool = command_pool,
    };
}

pub fn deinit(this: *@This()) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    const vk_alloc: ?*vk.AllocationCallbacks = null;
    this._device.destroyCommandPool(this._command_pool, vk_alloc);
    this._device.destroyDevice(vk_alloc);
}

pub fn waitUntilIdle(this: *const @This()) !void {
    try this._device.deviceWaitIdle();
}

// pub const initDisplay = Display.init;
// pub const initBuffer = Buffer.init;
