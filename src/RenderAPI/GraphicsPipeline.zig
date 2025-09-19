const std = @import("std");
const Profiler = @import("../Profiler.zig");
const VK = @import("Vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Shader = @import("Shader.zig");
const c = VK.c;

const GraphicsPipeline = @This();

device: *const Device,
_pipeline: c.VkPipeline,
_pipelineLayout: c.VkPipelineLayout,

pub fn Create(createInfo: CreateInfo) !@This() {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    var this: @This() = undefined;
    this.device = createInfo.device;

    const extent: c.VkExtent2D = .{
        .width = createInfo.framebufferSize[0],
        .height = createInfo.framebufferSize[1],
    };

    // TODO: add per vertex data
    const vertexShaderStageInfo: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = createInfo.shaderSet.vertex._shaderModule,
        .pName = "main",
    };

    const fragmentShaderStageInfo: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = createInfo.shaderSet.pixel._shaderModule,
        .pName = "main",
    };

    const shaderStages: [2]c.VkPipelineShaderStageCreateInfo = .{
        vertexShaderStageInfo,
        fragmentShaderStageInfo,
    };

    const dynamicStates: [2]c.VkDynamicState = .{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamicStateCreateInfo: c.VkPipelineDynamicStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamicStates.len,
        .pDynamicStates = &dynamicStates,
    };

    const vertexInputInfo: c.VkPipelineVertexInputStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
    };

    const inputAssembly: c.VkPipelineInputAssemblyStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, // TODO: allow more options
        .primitiveRestartEnable = c.VK_FALSE, // TODO: implement (allows you to seperate triangle strip)
    };

    const viewport: c.VkViewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(extent.width),
        .height = @floatFromInt(extent.height),
        .minDepth = 0, // TODO: maybe allow these to change? idk
        .maxDepth = 1,
    };

    const scissor: c.VkRect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = extent,
    };

    const viewportState: c.VkPipelineViewportStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    const rasterizer: c.VkPipelineRasterizationStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE, // TODO: maybe the source of depth buffer issues
        .rasterizerDiscardEnable = c.VK_FALSE, // TODO: allow rasterizer to be disabled
        .polygonMode = c.VK_POLYGON_MODE_FILL, // TODO: allow change
        .lineWidth = 1, // TODO: allow change
        .cullMode = c.VK_CULL_MODE_NONE, // TODO: allow change
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE, // TODO: allow change
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
    };

    const multisampling: c.VkPipelineMultisampleStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = c.VK_FALSE,
        .minSampleShading = 1,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
    };

    const colorBlendAttachment: c.VkPipelineColorBlendAttachmentState = .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const colorBlending: c.VkPipelineColorBlendStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment,
        .blendConstants = .{ 0, 0, 0, 0 },
    };

    const depthStencil: c.VkPipelineDepthStencilStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_FALSE,
        .depthWriteEnable = c.VK_FALSE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .minDepthBounds = 0,
        .maxDepthBounds = 1,
        .stencilTestEnable = c.VK_FALSE,
        .front = .{},
        .back = .{},
    };

    // TODO: could be separated into different objects
    const pipelineLayoutInfo: c.VkPipelineLayoutCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0, // TODO: add descriptor sets
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    try VK.Try(c.vkCreatePipelineLayout(this.device._device, &pipelineLayoutInfo, null, &this._pipelineLayout));

    const pipelineInfo: c.VkGraphicsPipelineCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pDepthStencilState = &depthStencil,
        .pColorBlendState = &colorBlending,
        .pDynamicState = &dynamicStateCreateInfo,
        .layout = this._pipelineLayout,
        .renderPass = createInfo.renderPass._renderPass,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    try VK.Try(c.vkCreateGraphicsPipelines(createInfo.device._device, null, 1, &pipelineInfo, null, &this._pipeline));

    return this;
}

pub fn Destroy(this: *@This()) void {
    var prof = Profiler.StartFuncProfiler(@src());
    defer prof.Stop();

    c.vkDestroyPipeline(this.device._device, this._pipeline, null);
    c.vkDestroyPipelineLayout(this.device._device, this._pipelineLayout, null);
}

pub const CreateInfo = struct {
    device: *Device,
    renderPass: *const RenderPass,
    framebufferSize: @Vector(2, u32),
    shaderSet: *Shader.Set,
    oldGraphicsPipeline: ?*GraphicsPipeline,
};
