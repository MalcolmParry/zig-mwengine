const std = @import("std");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const c = VK.c;

const Shader = @This();

device: *const Device,
_shaderModule: c.VkShaderModule,
_stage: c.VkShaderStageFlags,

pub fn Create(device: *const Device, stage: Stage, spirvByteCode: []const u32) !@This() {
    var this: @This() = undefined;
    this.device = device;
    this._stage = switch (stage) {
        .Vertex => c.VK_SHADER_STAGE_VERTEX_BIT,
        .Pixel => c.VK_SHADER_STAGE_FRAGMENT_BIT,
    };

    const createInfo: c.VkShaderModuleCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = spirvByteCode.len * @sizeOf(u32),
        .pCode = spirvByteCode.ptr,
    };

    try VK.Try(c.vkCreateShaderModule(device._device, &createInfo, null, &this._shaderModule));

    return this;
}

pub fn Destroy(this: *@This()) void {
    c.vkDestroyShaderModule(this.device._device, this._shaderModule, null);
}

pub const Stage = enum {
    Vertex,
    Pixel,
};

pub const Set = struct {
    vertex: Shader,
    pixel: Shader,
    _toVertex: []c.VkFormat,
    alloc: std.mem.Allocator,

    pub fn Create(vertex: Shader, pixel: Shader, toVertex: []const DataType, alloc: std.mem.Allocator) !@This() {
        var this: @This() = undefined;
        this.vertex = vertex;
        this.pixel = pixel;
        this._toVertex = try _ShaderDataTypeToVK(toVertex, alloc);
        this.alloc = alloc;
        return this;
    }

    pub fn Destroy(this: *@This()) void {
        this.alloc.free(this._toVertex);
    }
};

pub const DataType = enum {
    U8,
    U8Vec2,
    U8Vec3,
    U8Vec4,
    U16,
    U16Vec2,
    U16Vec3,
    U16Vec4,
    U32,
    U32Vec2,
    U32Vec3,
    U32Vec4,
    I8,
    I8Vec2,
    I8Vec3,
    I8Vec4,
    I16,
    I16Vec2,
    I16Vec3,
    I16Vec4,
    I32,
    I32Vec2,
    I32Vec3,
    I32Vec4,
    F32,
    F32Vec2,
    F32Vec3,
    F32Vec4,
    F32Mat4x4,

    pub fn GetSize(this: @This()) usize {
        return switch (this) {
            .U8 => 1,
            .U8Vec2 => 2,
            .U8Vec3 => 3,
            .U8Vec4 => 4,
            .U16 => 2,
            .U16Vec2 => 4,
            .U16Vec3 => 6,
            .U16Vec4 => 8,
            .U32 => 4,
            .U32Vec2 => 8,
            .U32Vec3 => 12,
            .U32Vec4 => 16,
            .U64 => 8,
            .U64Vec2 => 16,
            .U64Vec3 => 24,
            .U64Vec4 => 32,
            .I8 => 1,
            .I8Vec2 => 2,
            .I8Vec3 => 3,
            .I8Vec4 => 4,
            .I16 => 2,
            .I16Vec2 => 4,
            .I16Vec3 => 6,
            .I16Vec4 => 8,
            .I32 => 4,
            .I32Vec2 => 8,
            .I32Vec3 => 12,
            .I32Vec4 => 16,
            .F32 => 4,
            .F32Vec2 => 8,
            .F32Vec3 => 12,
            .F32Vec4 => 16,
            .F32Mat4x4 => 64,
        };
    }
};

pub fn _ShaderDataTypeToVK(types: []const DataType, alloc: std.mem.Allocator) ![]c.VkFormat {
    var count: u32 = 0;

    for (types) |x| {
        switch (x) {
            .F32Mat4x4 => {
                count += 4;
            },
            else => {
                count += 1;
            },
        }
    }

    const vkTypes = try alloc.alloc(c.VkFormat, count);
    var i: u32 = 0;
    for (types) |x| {
        if (x == .F32Mat4x4) {
            vkTypes[i + 0] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vkTypes[i + 1] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vkTypes[i + 2] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            vkTypes[i + 3] = c.VK_FORMAT_R32G32B32A32_SFLOAT;
            i += 4;
            continue;
        }

        vkTypes[i] = switch (x) {
            .U8 => c.VK_FORMAT_R8_UINT,
            .U8Vec2 => c.VK_FORMAT_R8G8_UINT,
            .U8Vec3 => c.VK_FORMAT_R8G8B8_UINT,
            .U8Vec4 => c.VK_FORMAT_R8G8B8A8_UINT,
            .U16 => c.VK_FORMAT_R16_UINT,
            .U16Vec2 => c.VK_FORMAT_R16G16_UINT,
            .U16Vec3 => c.VK_FORMAT_R16G16B16_UINT,
            .U16Vec4 => c.VK_FORMAT_R16G16B16A16_UINT,
            .U32 => c.VK_FORMAT_R32_UINT,
            .U32Vec2 => c.VK_FORMAT_R32G32_UINT,
            .U32Vec3 => c.VK_FORMAT_R32G32B32_UINT,
            .U32Vec4 => c.VK_FORMAT_R32G32B32A32_UINT,
            .I8 => c.VK_FORMAT_R8_SINT,
            .I8Vec2 => c.VK_FORMAT_R8G8_SINT,
            .I8Vec3 => c.VK_FORMAT_R8G8B8_SINT,
            .I8Vec4 => c.VK_FORMAT_R8G8B8A8_SINT,
            .I16 => c.VK_FORMAT_R16_SINT,
            .I16Vec2 => c.VK_FORMAT_R16G16_SINT,
            .I16Vec3 => c.VK_FORMAT_R16G16B16_SINT,
            .I16Vec4 => c.VK_FORMAT_R16G16B16A16_SINT,
            .I32 => c.VK_FORMAT_R32_SINT,
            .I32Vec2 => c.VK_FORMAT_R32G32_SINT,
            .I32Vec3 => c.VK_FORMAT_R32G32B32_SINT,
            .I32Vec4 => c.VK_FORMAT_R32G32B32A32_SINT,
            .F32 => c.VK_FORMAT_R32_SFLOAT,
            .F32Vec2 => c.VK_FORMAT_R32G32_SFLOAT,
            .F32Vec3 => c.VK_FORMAT_R32G32B32_SFLOAT,
            .F32Vec4 => c.VK_FORMAT_R32G32B32A32_SFLOAT,
            else => {
                return error.InvalidId;
            },
        };

        i += 1;
    }

    return vkTypes;
}
