const std = @import("std");
const mw = @import("mwengine");

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

    var profiler = try mw.Profiler.Create(alloc);
    defer profiler.Destroy();
    defer profiler.WriteToFile("profiler.json") catch @panic("error from profiler");
    mw.Profiler.global = &profiler;

    window = try mw.Window.Create("TEST", 480, 340);
    try window.SetTitle("TEST");
    defer window.Destroy();

    var instance = try mw.RAPI.Instance.Create(true, alloc);
    defer instance.Destroy(alloc);

    const physicalDevice = try instance.BestPhysicalDevice(alloc);
    var device = try instance.CreateDevice(&physicalDevice, alloc);
    defer device.Destroy();

    var display = try device.CreateDisplay(&window, alloc);
    const framesInFlight: u32 = @intCast(display.imageViews.len);
    defer display.Destroy(alloc);

    var renderPass = try display.CreateRenderPass();
    defer renderPass.Destroy();

    const framebuffers = try alloc.alloc(mw.RAPI.Framebuffer, display.imageViews.len);
    defer alloc.free(framebuffers);
    for (framebuffers, display.imageViews) |*framebuffer, *imageView| {
        framebuffer.* = try .Create(&device, &renderPass, display.imageSize, &.{imageView}, alloc);
    }
    defer for (framebuffers) |*framebuffer| {
        framebuffer.Destroy(&device);
    };

    //const buffer = try device.CreateBuffer(16, .{ .vertex = true });
    //defer buffer.Destroy();

    var vertexShader = try CreateShader(&device, "res/Shaders/Triangle.glsl.vert.spv", .Vertex, alloc);
    defer vertexShader.Destroy();

    var pixelShader = try CreateShader(&device, "res/Shaders/Triangle.glsl.frag.spv", .Pixel, alloc);
    defer pixelShader.Destroy();

    var shaderSet = try mw.RAPI.Shader.Set.Create(vertexShader, pixelShader, &.{}, alloc);
    defer shaderSet.Destroy();

    const graphicsPipelineCreateInfo: mw.RAPI.GraphicsPipeline.CreateInfo = .{
        .oldGraphicsPipeline = null,
        .device = &device,
        .renderPass = &renderPass,
        .shaderSet = &shaderSet,
        .vertexCount = 3,
        .framebufferSize = window.GetClientSize(),
    };

    var graphicsPipeline = try mw.RAPI.GraphicsPipeline.Create(graphicsPipelineCreateInfo);
    defer graphicsPipeline.Destroy();

    const commandBuffers = try alloc.alloc(mw.RAPI.CommandBuffer, framesInFlight);
    for (commandBuffers) |*commandBuffer| {
        commandBuffer.* = try .Create(&device);
    }
    defer alloc.free(commandBuffers);
    defer for (commandBuffers) |*commandBuffer| {
        commandBuffer.Destroy(&device);
    };

    const imageAvailableSemaphores = try alloc.alloc(mw.RAPI.Semaphore, framesInFlight);
    for (imageAvailableSemaphores) |*x| {
        x.* = try .Create(&device);
    }
    defer alloc.free(imageAvailableSemaphores);
    defer for (imageAvailableSemaphores) |*x| {
        x.Destroy();
    };

    const renderFinishedSemaphores = try alloc.alloc(mw.RAPI.Semaphore, framesInFlight);
    for (renderFinishedSemaphores) |*x| {
        x.* = try .Create(&device);
    }
    defer alloc.free(renderFinishedSemaphores);
    defer for (renderFinishedSemaphores) |*x| {
        x.Destroy();
    };

    const inFLightFences = try alloc.alloc(mw.RAPI.Fence, framesInFlight);
    for (inFLightFences) |*x| {
        x.* = try .Create(&device, true);
    }
    defer alloc.free(inFLightFences);
    defer for (inFLightFences) |*x| {
        x.Destroy();
    };

    defer device.WaitUntilIdle() catch unreachable;
    var frame: u32 = 0;
    while (running) {
        var commandBuffer = commandBuffers[frame];
        var imageAvailableSemaphore = imageAvailableSemaphores[frame];
        var renderFinishedSemaphore = renderFinishedSemaphores[frame];
        var inFLightFence = inFLightFences[frame];

        try inFLightFence.WaitFor(1_000_000_000);
        try inFLightFence.Reset();

        var framebufferIndex: u32 = undefined;
        while (true) {
            if (display.GetNextFramebufferIndex(&imageAvailableSemaphore, null, 1_000_000_000)) |x| {
                framebufferIndex = x;
                break;
            } else |err| switch (err) {
                error.DisplayOutOfDate => {
                    try device.WaitUntilIdle();
                    for (framebuffers) |*framebuffer| {
                        framebuffer.Destroy(&device);
                    }
                    try display.Rebuild(window.GetClientSize(), alloc);
                    for (framebuffers, display.imageViews) |*framebuffer, *imageView| {
                        framebuffer.* = try .Create(&device, &renderPass, display.imageSize, &.{imageView}, alloc);
                    }
                },
                else => return err,
            }
        }
        const framebuffer = &framebuffers[framebufferIndex];
        // std.log.debug("{}\n", .{framebufferIndex});

        try commandBuffer.Reset();
        try commandBuffer.Begin();
        commandBuffer.QueueBeginRenderPass(&renderPass, framebuffer);
        commandBuffer.QueueDraw(&graphicsPipeline, framebuffer);
        commandBuffer.QueueEndRenderPass();
        try commandBuffer.End();
        try commandBuffer.Submit(&device, &imageAvailableSemaphore, &renderFinishedSemaphore, &inFLightFence);
        display.PresentFramebuffer(framebufferIndex, &renderFinishedSemaphore) catch |err| switch (err) {
            error.DisplayOutOfDate => {
                try device.WaitUntilIdle();
                for (framebuffers) |*x| {
                    x.Destroy(&device);
                }
                try display.Rebuild(window.GetClientSize(), alloc);
                for (framebuffers, display.imageViews) |*x, *imageView| {
                    x.* = try .Create(&device, &renderPass, display.imageSize, &.{imageView}, alloc);
                }
            },
            else => return err,
        };

        EventHandler() catch {};

        frame = (frame + 1) % framesInFlight;
    }
}

fn CreateShader(device: *const mw.RAPI.Device, filepath: []const u8, stage: mw.RAPI.Shader.Stage, alloc: std.mem.Allocator) !mw.RAPI.Shader {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const fileSize = try file.getEndPos();
    const buffer = try alloc.alloc(u32, std.mem.alignForward(u64, fileSize, @sizeOf(u32)) / @sizeOf(u32));
    defer alloc.free(buffer);

    const read = try file.readAll(std.mem.sliceAsBytes(buffer));
    if (read != fileSize)
        return error.CouldntReadShaderFile;
    return mw.RAPI.Shader.Create(device, stage, buffer);
}
