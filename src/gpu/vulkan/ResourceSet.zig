const std = @import("std");
const vk = @import("vulkan");
const Device = @import("Device.zig");
const Shader = @import("Shader.zig");

pub const Type = enum {
    uniform,
    image,
};

pub const Layout = struct {
    _layout: vk.DescriptorSetLayout,

    pub const Descriptor = struct {
        t: Type,
        stage: Shader.StageFlags,
        binding: u32,
        count: u32,
    };

    pub const CreateInfo = struct {
        alloc: std.mem.Allocator,
        descriptors: []const Descriptor,
    };

    pub fn init(device: *Device, info: CreateInfo) !@This() {
        const bindings = try info.alloc.alloc(vk.DescriptorSetLayoutBinding, info.descriptors.len);
        defer info.alloc.free(bindings);

        for (bindings, info.descriptors, 0..) |*binding, descriptor, i| {
            binding.* = .{
                .binding = @intCast(i),
                .descriptor_type = switch (descriptor.t) {
                    .uniform => .uniform_buffer,
                    .image => .combined_image_sampler,
                },
                .descriptor_count = descriptor.count,
                .stage_flags = .{
                    .vertex_bit = descriptor.stage.vertex,
                    .fragment_bit = descriptor.stage.pixel,
                },
            };
        }

        const vk_alloc: ?*vk.AllocationCallbacks = null;
        const layout = try device._device.createDescriptorSetLayout(&.{
            .binding_count = @intCast(bindings.len),
            .p_bindings = @ptrCast(bindings.ptr),
        }, vk_alloc);

        return .{
            ._layout = layout,
        };
    }

    pub fn deinit(this: @This(), device: *Device) void {
        const vk_alloc: ?*vk.AllocationCallbacks = null;
        device._device.destroyDescriptorSetLayout(this._layout, vk_alloc);
    }

    pub fn _nativesFromSlice(these: []const @This()) []const vk.DescriptorSetLayout {
        return @ptrCast(these);
    }
};
