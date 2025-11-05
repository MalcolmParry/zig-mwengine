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
    const alloc = std.heap.smp_allocator;

    var profiler = try mw.Profiler.init(alloc);
    defer profiler.deinit();
    defer profiler.writeToFile("profiler.json") catch @panic("error from profiler");
    mw.Profiler.global = &profiler;

    window = try mw.Window.init("TEST", 480, 340);
    try window.setTitle("TEST");
    defer window.deinit();

    var instance = try mw.RAPI.Instance.init(true, alloc);
    defer instance.deinit(alloc);

    const physical_device = try instance.bestPhysicalDevice(alloc);
    var device = try instance.initDevice(&physical_device, alloc);
    defer device.deinit();

    var display = try device.initDisplay(&window, alloc);
    // const framesInFlight: u32 = @intCast(display.imageViews.len);
    defer display.deinit(alloc);

    var render_pass = try display.initRenderPass();
    defer render_pass.deinit();

    const framebuffers = try alloc.alloc(mw.RAPI.Framebuffer, display.image_views.len);
    defer alloc.free(framebuffers);
    for (framebuffers, display.image_views) |*framebuffer, *image_view| {
        framebuffer.* = try .init(&device, &render_pass, display.image_size, &.{image_view}, alloc);
    }
    defer for (framebuffers) |*framebuffer| {
        framebuffer.deinit(&device);
    };

    //const buffer = try device.CreateBuffer(16, .{ .vertex = true });
    //defer buffer.Destroy();

    var vertexShader = try createShader(&device, "res/Shaders/Triangle.glsl.vert.spv", .vertex, alloc);
    defer vertexShader.deinit();

    var pixelShader = try createShader(&device, "res/Shaders/Triangle.glsl.frag.spv", .pixel, alloc);
    defer pixelShader.deinit();

    var shader_set = try mw.RAPI.Shader.Set.init(vertexShader, pixelShader, &.{}, alloc);
    defer shader_set.deinit();

    var graphicsPipeline = try mw.RAPI.GraphicsPipeline.init(.{
        .device = &device,
        .render_pass = &render_pass,
        .shader_set = &shader_set,
        .vertex_count = 3,
        .framebuffer_size = window.getClientSize(),
    });
    defer graphicsPipeline.deinit();

    // const commandBuffers = try alloc.alloc(mw.RAPI.CommandBuffer, framesInFlight);
    // for (commandBuffers) |*commandBuffer| {
    //     commandBuffer.* = try .Create(&device);
    // }
    // defer alloc.free(commandBuffers);
    // defer for (commandBuffers) |*commandBuffer| {
    //     commandBuffer.Destroy(&device);
    // };
    //
    // const imageAvailableSemaphores = try alloc.alloc(mw.RAPI.Semaphore, framesInFlight);
    // for (imageAvailableSemaphores) |*x| {
    //     x.* = try .Create(&device);
    // }
    // defer alloc.free(imageAvailableSemaphores);
    // defer for (imageAvailableSemaphores) |*x| {
    //     x.Destroy();
    // };
    //
    // const renderFinishedSemaphores = try alloc.alloc(mw.RAPI.Semaphore, framesInFlight);
    // for (renderFinishedSemaphores) |*x| {
    //     x.* = try .Create(&device);
    // }
    // defer alloc.free(renderFinishedSemaphores);
    // defer for (renderFinishedSemaphores) |*x| {
    //     x.Destroy();
    // };
    //
    // const inFLightFences = try alloc.alloc(mw.RAPI.Fence, framesInFlight);
    // for (inFLightFences) |*x| {
    //     x.* = try .Create(&device, true);
    // }
    // defer alloc.free(inFLightFences);
    // defer for (inFLightFences) |*x| {
    //     x.Destroy();
    // };
    //
    // defer device.WaitUntilIdle() catch unreachable;
    // var frame: u32 = 0;
    // while (running) {
    //     var commandBuffer = commandBuffers[frame];
    //     var imageAvailableSemaphore = imageAvailableSemaphores[frame];
    //     var renderFinishedSemaphore = renderFinishedSemaphores[frame];
    //     var inFLightFence = inFLightFences[frame];
    //
    //     try inFLightFence.WaitFor(1_000_000_000);
    //     try inFLightFence.Reset();
    //
    //     var framebufferIndex: u32 = undefined;
    //     while (true) {
    //         if (display.AcquireFramebufferIndex(&imageAvailableSemaphore, null, 1_000_000_000)) |x| {
    //             framebufferIndex = x;
    //             break;
    //         } else |err| switch (err) {
    //             error.DisplayOutOfDate => {
    //                 try device.WaitUntilIdle();
    //                 for (framebuffers) |*framebuffer| {
    //                     framebuffer.Destroy(&device);
    //                 }
    //                 try display.Rebuild(window.GetClientSize(), alloc);
    //                 for (framebuffers, display.imageViews) |*framebuffer, *imageView| {
    //                     framebuffer.* = try .Create(&device, &render_pass, display.imageSize, &.{imageView}, alloc);
    //                 }
    //             },
    //             else => return err,
    //         }
    //     }
    //     const framebuffer = &framebuffers[framebufferIndex];
    //     // std.log.debug("{}\n", .{framebufferIndex});
    //
    //     try commandBuffer.Reset();
    //     try commandBuffer.Begin();
    //     commandBuffer.QueueBeginRenderPass(&render_pass, framebuffer);
    //     commandBuffer.QueueDraw(&graphicsPipeline, framebuffer);
    //     commandBuffer.QueueEndRenderPass();
    //     try commandBuffer.End();
    //     try commandBuffer.Submit(&device, &imageAvailableSemaphore, &renderFinishedSemaphore, null);
    //     display.PresentFramebuffer(framebufferIndex, &renderFinishedSemaphore, &inFLightFence) catch |err| switch (err) {
    //         error.DisplayOutOfDate => {
    //             try device.WaitUntilIdle();
    //             for (framebuffers) |*x| {
    //                 x.Destroy(&device);
    //             }
    //             try display.Rebuild(window.GetClientSize(), alloc);
    //             for (framebuffers, display.imageViews) |*x, *imageView| {
    //                 x.* = try .Create(&device, &render_pass, display.imageSize, &.{imageView}, alloc);
    //             }
    //         },
    //         else => return err,
    //     };
    //
    //     EventHandler() catch {};
    //
    //     frame = (frame + 1) % framesInFlight;
    // }
}

fn createShader(device: *const mw.RAPI.Device, filepath: []const u8, stage: mw.RAPI.Shader.Stage, alloc: std.mem.Allocator) !mw.RAPI.Shader {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const fileSize = try file.getEndPos();
    const buffer = try alloc.alloc(u32, try std.math.divCeil(usize, fileSize, @sizeOf(u32)));
    defer alloc.free(buffer);

    const read = try file.readAll(std.mem.sliceAsBytes(buffer));
    if (read != fileSize)
        return error.CouldntReadShaderFile;
    return mw.RAPI.Shader.fromSpirv(device, stage, buffer);
}
