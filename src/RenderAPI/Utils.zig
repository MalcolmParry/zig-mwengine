const std = @import("std");
const VK = @import("Vulkan.zig");
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
