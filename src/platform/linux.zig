const window_impl = @import("x11.zig");

pub const Window = window_impl.Window;
pub const vulkan = struct {
    pub const lib_path = "libvulkan.so.1";
    pub const createSurface = window_impl.vulkan.createSurface;
    pub const required_extensions = window_impl.vulkan.required_extensions;
};
