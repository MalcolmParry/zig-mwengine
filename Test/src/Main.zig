const std = @import("std");
const mw = struct {
    const mwengine = @import("mwengine");
    pub usingnamespace mwengine;
    pub usingnamespace mwengine.RenderAPI;
};

var window: mw.Window = undefined;
var running: bool = true;

fn EventHandler() !void {
    while (window.EventPending()) {
        const event = window.PopEvent() orelse break;

        switch (event.type) {
            .Closed => {
                running = false;
            },
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var profiler = try mw.Profiler.Create("Start", "mwengine-profile-start.json", alloc);
    defer profiler.Destroy() catch @panic("error from profiler");
    mw.Profiler.global = &profiler;

    window = try mw.Window.Create("TEST", 480, 340);
    try window.SetTitle("TEST");
    defer window.Destroy();

    var instance = try mw.Instance.Create(true, alloc);
    defer instance.Destroy(alloc);

    const physicalDevice = try instance.BestPhysicalDevice(alloc);
    var device = try instance.CreateDevice(&physicalDevice, alloc);
    defer device.Destroy();

    var display = try device.CreateDisplay(&window, alloc);
    defer display.Destroy();

    var renderPass = try display.CreateRenderPass();
    defer renderPass.Destroy();

    //const buffer = try device.CreateBuffer(16, .{ .vertex = true });
    //defer buffer.Destroy();

    var vertexShader = try CreateShader(&device, "res/Shaders/Triangle.glsl.vert.spv", .Vertex, alloc);
    defer vertexShader.Destroy();

    var pixelShader = try CreateShader(&device, "res/Shaders/Triangle.glsl.frag.spv", .Pixel, alloc);
    defer pixelShader.Destroy();

    var shaderSet = try mw.Shader.Set.Create(vertexShader, pixelShader, &.{}, alloc);
    defer shaderSet.Destroy();

    const graphicsPipelineCreateInfo: mw.GraphicsPipeline.CreateInfo = .{
        .oldGraphicsPipeline = null,
        .device = &device,
        .renderPass = &renderPass,
        .shaderSet = &shaderSet,
        .framebufferSize = window.GetClientSize(),
    };

    var graphicsPipeline = try mw.GraphicsPipeline.Create(graphicsPipelineCreateInfo);
    defer graphicsPipeline.Destroy();

    while (running) {
        EventHandler() catch {};
    }
}

fn CreateShader(device: *const mw.Device, filepath: []const u8, stage: mw.Shader.Stage, alloc: std.mem.Allocator) !mw.Shader {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const fileSize = try file.getEndPos();
    const buffer = try alloc.alloc(u32, std.mem.alignForward(u64, fileSize, @sizeOf(u32)) / @sizeOf(u32));
    defer alloc.free(buffer);

    const read = try file.readAll(std.mem.sliceAsBytes(buffer));
    if (read != fileSize)
        return error.CouldntReadShaderFile;
    return mw.Shader.Create(device, stage, buffer);
}
