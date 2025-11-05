const std = @import("std");
const mw = @import("mwengine");

var window: mw.Window = undefined;
var running: bool = true;

fn eventHandler() !void {
    while (window.eventPending()) {
        const event = window.popEvent() orelse break;

        switch (event.type) {
            .closed => {
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
    const frames_in_flight: u32 = @intCast(display.image_views.len);
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

    var vertex_shader = try createShader(&device, "res/Shaders/Triangle.glsl.vert.spv", .vertex, alloc);
    defer vertex_shader.deinit();

    var pixel_shader = try createShader(&device, "res/Shaders/Triangle.glsl.frag.spv", .pixel, alloc);
    defer pixel_shader.deinit();

    var shader_set = try mw.RAPI.Shader.Set.init(vertex_shader, pixel_shader, &.{}, alloc);
    defer shader_set.deinit();

    var graphics_pipeline = try mw.RAPI.GraphicsPipeline.init(.{
        .device = &device,
        .render_pass = &render_pass,
        .shader_set = &shader_set,
        .vertex_count = 3,
        .framebuffer_size = window.getClientSize(),
    });
    defer graphics_pipeline.deinit();

    const command_buffers = try alloc.alloc(mw.RAPI.CommandBuffer, frames_in_flight);
    for (command_buffers) |*command_buffer| {
        command_buffer.* = try .init(&device);
    }

    defer {
        for (command_buffers) |*command_buffer| {
            command_buffer.deinit(&device);
        }
        alloc.free(command_buffers);
    }

    const image_available_semaphores = try alloc.alloc(mw.RAPI.Semaphore, frames_in_flight);
    for (image_available_semaphores) |*x| {
        x.* = try .init(&device);
    }

    defer {
        for (image_available_semaphores) |*x| {
            x.deinit();
        }
        alloc.free(image_available_semaphores);
    }

    const render_finished_semaphores = try alloc.alloc(mw.RAPI.Semaphore, frames_in_flight);
    for (render_finished_semaphores) |*x| {
        x.* = try .init(&device);
    }
    defer alloc.free(render_finished_semaphores);
    defer for (render_finished_semaphores) |*x| {
        x.deinit();
    };

    // const inFLightFences = try alloc.alloc(mw.RAPI.Fence, frames_in_flight);
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
    //     var command_buffer = command_buffers[frame];
    //     var image_available_semaphore = image_available_semaphores[frame];
    //     var render_finished_semaphore = render_finished_semaphores[frame];
    //     var inFLightFence = inFLightFences[frame];
    //
    //     try inFLightFence.WaitFor(1_000_000_000);
    //     try inFLightFence.Reset();
    //
    //     var framebufferIndex: u32 = undefined;
    //     while (true) {
    //         if (display.AcquireFramebufferIndex(&image_available_semaphore, null, 1_000_000_000)) |x| {
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
    //     try command_buffer.Reset();
    //     try command_buffer.Begin();
    //     command_buffer.QueueBeginRenderPass(&render_pass, framebuffer);
    //     command_buffer.QueueDraw(&graphics_pipeline, framebuffer);
    //     command_buffer.QueueEndRenderPass();
    //     try command_buffer.End();
    //     try command_buffer.Submit(&device, &image_available_semaphore, &render_finished_semaphore, null);
    //     display.PresentFramebuffer(framebufferIndex, &render_finished_semaphore, &inFLightFence) catch |err| switch (err) {
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
    //     frame = (frame + 1) % frames_in_flight;
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
