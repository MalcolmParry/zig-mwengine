const std = @import("std");
const Profiler = @import("../Profiler.zig");
const vk = @import("vulkan.zig");
const Device = @import("Device.zig");
const RenderPass = @import("RenderPass.zig");
const Shader = @import("Shader.zig");
const c = vk.c;

const GraphicsPipeline = @This();

device: *const Device,
_pipeline: c.VkPipeline,
_pipeline_layout: c.VkPipelineLayout,
vertex_count: u32,

pub fn init(create_info: CreateInfo) !@This() {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    var this: @This() = undefined;
    this.device = create_info.device;
    this.vertex_count = create_info.vertex_count;

    const extent: c.VkExtent2D = .{
        .width = create_info.framebuffer_size[0],
        .height = create_info.framebuffer_size[1],
    };

    // TODO: add per vertex data
    const vertex_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = create_info.shader_set.vertex._shader_module,
        .pName = "main",
    };

    const fragment_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = create_info.shader_set.pixel._shader_module,
        .pName = "main",
    };

    const shader_stages: [2]c.VkPipelineShaderStageCreateInfo = .{
        vertex_shader_stage_info,
        fragment_shader_stage_info,
    };

    const dynamic_states: [2]c.VkDynamicState = .{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamic_state_create_info: c.VkPipelineDynamicStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamic_states.len,
        .pDynamicStates = &dynamic_states,
    };

    const vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
    };

    const input_assembly: c.VkPipelineInputAssemblyStateCreateInfo = .{
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

    const viewport_state: c.VkPipelineViewportStateCreateInfo = .{
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

    const color_blend_attachment: c.VkPipelineColorBlendAttachmentState = .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const color_blending: c.VkPipelineColorBlendStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = .{ 0, 0, 0, 0 },
    };

    const depth_stencil: c.VkPipelineDepthStencilStateCreateInfo = .{
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
    const pipeline_layout_info: c.VkPipelineLayoutCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0, // TODO: add descriptor sets
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    try vk.wrap(c.vkCreatePipelineLayout(this.device._device, &pipeline_layout_info, null, &this._pipeline_layout));

    const pipeline_info: c.VkGraphicsPipelineCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_input_info,
        .pInputAssemblyState = &input_assembly,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pDepthStencilState = &depth_stencil,
        .pColorBlendState = &color_blending,
        .pDynamicState = &dynamic_state_create_info,
        .layout = this._pipeline_layout,
        .renderPass = create_info.render_pass._render_pass,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    try vk.wrap(c.vkCreateGraphicsPipelines(create_info.device._device, null, 1, &pipeline_info, null, &this._pipeline));

    return this;
}

pub fn deinit(this: *@This()) void {
    var prof = Profiler.startFuncProfiler(@src());
    defer prof.stop();

    c.vkDestroyPipeline(this.device._device, this._pipeline, null);
    c.vkDestroyPipelineLayout(this.device._device, this._pipeline_layout, null);
}

pub const CreateInfo = struct {
    device: *Device,
    render_pass: *const RenderPass,
    framebuffer_size: @Vector(2, u32),
    shader_set: *Shader.Set,
    vertex_count: u32,
};
