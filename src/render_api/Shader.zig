const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const c = vk.c;

const Shader = @This();

device: *const Device,
_shader_module: c.VkShaderModule,
_stage: c.VkShaderStageFlags,

pub fn fromSpirv(device: *const Device, stage: Stage, spirvByteCode: []const u32) !@This() {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    var this: @This() = undefined;
    this.device = device;
    this._stage = switch (stage) {
        .vertex => c.VK_SHADER_STAGE_VERTEX_BIT,
        .pixel => c.VK_SHADER_STAGE_FRAGMENT_BIT,
    };

    const create_info: c.VkShaderModuleCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = spirvByteCode.len * @sizeOf(u32),
        .pCode = spirvByteCode.ptr,
    };

    try vk.wrap(c.vkCreateShaderModule(device._device, &create_info, null, &this._shader_module));

    return this;
}

pub fn deinit(this: *@This()) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    c.vkDestroyShaderModule(this.device._device, this._shader_module, null);
}

pub const Stage = enum {
    vertex,
    pixel,
};

pub const Set = struct {
    vertex: Shader,
    pixel: Shader,
    _per_vertex: []c.VkFormat,
    alloc: std.mem.Allocator,

    pub fn init(vertex: Shader, pixel: Shader, per_vertex: []const DataType, alloc: std.mem.Allocator) !@This() {
        var this: @This() = undefined;
        std.debug.assert(vertex._stage == c.VK_SHADER_STAGE_VERTEX_BIT);
        std.debug.assert(pixel._stage == c.VK_SHADER_STAGE_FRAGMENT_BIT);

        this.vertex = vertex;
        this.pixel = pixel;
        this._per_vertex = try shaderDataTypeToVK(per_vertex, alloc);
        this.alloc = alloc;

        return this;
    }

    pub fn deinit(this: *@This()) void {
        this.alloc.free(this._per_vertex);
    }
};

pub const DataType = enum {
    uint8,
    uint8x2,
    uint8x3,
    uint8x4,
    uint16,
    uint16x2,
    uint16x3,
    uint16x4,
    uint32,
    uint32x2,
    uint32x3,
    uint32x4,
    sint8,
    sint8x2,
    sint8x3,
    sint8x4,
    sint16,
    sint16x2,
    sint16x3,
    sint16x4,
    sint32,
    sint32x2,
    sint32x3,
    sint32x4,
    float16,
    float16x2,
    float16x3,
    float16x4,
    float32,
    float32x2,
    float32x3,
    float32x4,
    float32x4x4,

    pub fn size(this: @This()) usize {
        return switch (this) {
            .uint8 => 1,
            .uint8x2 => 2,
            .uint8x3 => 3,
            .uint8x4 => 4,
            .uint16 => 2,
            .uint16x2 => 4,
            .uint16x3 => 6,
            .uint16x4 => 8,
            .uint32 => 4,
            .uint32x2 => 8,
            .uint32x3 => 12,
            .uint32x4 => 16,
            .uint64 => 8,
            .uint64x2 => 16,
            .uint64x3 => 24,
            .uint64x4 => 32,
            .sint8 => 1,
            .sint8x2 => 2,
            .sint8x3 => 3,
            .sint8x4 => 4,
            .sint16 => 2,
            .sint16x2 => 4,
            .sint16x3 => 6,
            .sint16x4 => 8,
            .sint32 => 4,
            .sint32x2 => 8,
            .sint32x3 => 12,
            .sint32x4 => 16,
            .float32 => 4,
            .float32x2 => 8,
            .float32x3 => 12,
            .float32x4 => 16,
            .float32x4x4 => 64,
        };
    }
};

pub fn shaderDataTypeToVK(types: []const DataType, alloc: std.mem.Allocator) ![]c.VkFormat {
    var count: u32 = 0;

    for (types) |x| {
        switch (x) {
            .float32x4x4 => {
                count += 4;
            },
            else => {
                count += 1;
            },
        }
    }

    const vk_types = try alloc.alloc(c.VkFormat, count);
    var i: u32 = 0;
    for (types) |t| {
        if (t == .float32x4x4) {
            vk_types[i + 0] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vk_types[i + 1] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vk_types[i + 2] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vk_types[i + 3] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            i += 4;
            continue;
        }

        vk_types[i] = switch (t) {
            .uint8 => c.VK_FORMAT_R8_UINT,
            .uint8x2 => c.VK_FORMAT_R8G8_UINT,
            .uint8x3 => c.VK_FORMAT_R8G8B8_UINT,
            .uint8x4 => c.VK_FORMAT_R8G8B8A8_UINT,
            .uint16 => c.VK_FORMAT_R16_UINT,
            .uint16x2 => c.VK_FORMAT_R16G16_UINT,
            .uint16x3 => c.VK_FORMAT_R16G16B16_UINT,
            .uint16x4 => c.VK_FORMAT_R16G16B16A16_UINT,
            .uint32 => c.VK_FORMAT_R32_UINT,
            .uint32x2 => c.VK_FORMAT_R32G32_UINT,
            .uint32x3 => c.VK_FORMAT_R32G32B32_UINT,
            .uint32x4 => c.VK_FORMAT_R32G32B32A32_UINT,
            .sint8 => c.VK_FORMAT_R8_SINT,
            .sint8x2 => c.VK_FORMAT_R8G8_SINT,
            .sint8x3 => c.VK_FORMAT_R8G8B8_SINT,
            .sint8x4 => c.VK_FORMAT_R8G8B8A8_SINT,
            .sint16 => c.VK_FORMAT_R16_SINT,
            .sint16x2 => c.VK_FORMAT_R16G16_SINT,
            .sint16x3 => c.VK_FORMAT_R16G16B16_SINT,
            .sint16x4 => c.VK_FORMAT_R16G16B16A16_SINT,
            .sint32 => c.VK_FORMAT_R32_SINT,
            .sint32x2 => c.VK_FORMAT_R32G32_SINT,
            .sint32x3 => c.VK_FORMAT_R32G32B32_SINT,
            .sint32x4 => c.VK_FORMAT_R32G32B32A32_SINT,
            .float16 => c.VK_FORMAT_R16_SFLOAT,
            .float16x2 => c.VK_FORMAT_R16G16_SFLOAT,
            .float16x3 => c.VK_FORMAT_R16G16B16_SFLOAT,
            .float16x4 => c.VK_FORMAT_R16G16B16A16_SFLOAT,
            .float32 => c.VK_FORMAT_R32_SFLOAT,
            .float32x2 => c.VK_FORMAT_R32G32_SFLOAT,
            .float32x3 => c.VK_FORMAT_R32G32B32_SFLOAT,
            .float32x4 => c.VK_FORMAT_R32G32B32A32_SFLOAT,
            .float32x4x4 => unreachable,
        };

        i += 1;
    }

    return vk_types;
}
