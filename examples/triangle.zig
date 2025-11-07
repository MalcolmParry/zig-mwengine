const std = @import("std");
const mw = @import("mwengine");
const gpu = mw.gpu;

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
    // const alloc = std.heap.smp_allocator;
    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_alloc.deinit();
    const alloc = debug_alloc.allocator();

    var profiler = try mw.Profiler.init(alloc);
    defer profiler.deinit();
    defer profiler.writeToFile("profiler.json") catch @panic("error from profiler");
    mw.Profiler.global = &profiler;

    window = try mw.Window.init("TEST", 480, 340, alloc);
    try window.setTitle("TEST", alloc);
    defer window.deinit();

    var instance = try gpu.Instance.init(true, alloc);
    defer instance.deinit(alloc);

    const physical_device = try instance.bestPhysicalDevice(alloc);
    var device = try instance.initDevice(&physical_device, alloc);
    defer device.deinit(alloc);

    var display = try device.initDisplay(&instance, &window, alloc);
    // const frames_in_flight: u32 = @intCast(display.image_views.len);
    defer display.deinit(alloc);

    var render_pass = try display.initRenderPass();
    defer render_pass.deinit(&display);

    const framebuffers = try alloc.alloc(gpu.Framebuffer, display.image_views.len);
    defer alloc.free(framebuffers);
    for (framebuffers, display.image_views) |*framebuffer, image_view| {
        framebuffer.* = try .init(&device, &render_pass, display.image_size, &.{image_view});
    }
    defer for (framebuffers) |*framebuffer| {
        framebuffer.deinit(&device);
    };

    // var buffer = try device.initBuffer(16, .{ .dst = true });
    // defer buffer.deinit();
    // const data: u128 = std.math.maxInt(u128);
    // try buffer.setData(std.mem.asBytes(&data));

    var vertex_shader = try createShader(&device, "res/shaders/triangle.vert.spv", .vertex, alloc);
    defer vertex_shader.deinit(&device);

    var pixel_shader = try createShader(&device, "res/shaders/triangle.frag.spv", .pixel, alloc);
    defer pixel_shader.deinit(&device);

    var shader_set = try gpu.Shader.Set.init(vertex_shader, pixel_shader, &.{}, alloc);
    defer shader_set.deinit(alloc);

    // var graphics_pipeline = try gpu.GraphicsPipeline.init(.{
    //     .device = &device,
    //     .render_pass = &render_pass,
    //     .shader_set = &shader_set,
    //     .vertex_count = 3,
    //     .framebuffer_size = window.getClientSize(),
    // });
    // defer graphics_pipeline.deinit();
    //
    // const command_buffers = try alloc.alloc(gpu.CommandBuffer, frames_in_flight);
    // for (command_buffers) |*command_buffer| {
    //     command_buffer.* = try .init(&device);
    // }
    // defer {
    //     for (command_buffers) |*command_buffer| {
    //         command_buffer.deinit(&device);
    //     }
    //     alloc.free(command_buffers);
    // }
    //
    // const image_available_semaphores = try alloc.alloc(gpu.Semaphore, frames_in_flight);
    // for (image_available_semaphores) |*x| {
    //     x.* = try .init(&device);
    // }
    // defer {
    //     for (image_available_semaphores) |*x| {
    //         x.deinit();
    //     }
    //     alloc.free(image_available_semaphores);
    // }
    //
    // const render_finished_semaphores = try alloc.alloc(gpu.Semaphore, frames_in_flight);
    // for (render_finished_semaphores) |*x| {
    //     x.* = try .init(&device);
    // }
    // defer {
    //     for (render_finished_semaphores) |*x| {
    //         x.deinit();
    //     }
    //     alloc.free(render_finished_semaphores);
    // }
    //
    // const in_flight_fences = try alloc.alloc(gpu.Fence, frames_in_flight);
    // for (in_flight_fences) |*x| {
    //     x.* = try .init(&device, true);
    // }
    // defer {
    //     for (in_flight_fences) |*x| {
    //         x.deinit();
    //     }
    //     alloc.free(in_flight_fences);
    // }

    // defer device.waitUntilIdle() catch @panic("failed waiting for device");
    // var frame: u32 = 0;
    while (running) {
        // var command_buffer = command_buffers[frame];
        // var image_available_semaphore = image_available_semaphores[frame];
        // var render_finished_semaphore = render_finished_semaphores[frame];
        // var in_flight_fence = in_flight_fences[frame];
        //
        // try in_flight_fence.wait(1_000_000_000);
        // try in_flight_fence.reset();
        //
        // var framebuffer_index: u32 = undefined;
        // while (true) {
        //     if (display.acquireFramebufferIndex(&image_available_semaphore, null, 1_000_000_000)) |x| {
        //         framebuffer_index = x;
        //         break;
        //     } else |err| switch (err) {
        //         error.DisplayOutOfDate => {
        //             try device.waitUntilIdle();
        //             for (framebuffers) |*framebuffer| {
        //                 framebuffer.deinit(&device);
        //             }
        //             try display.rebuild(window.getClientSize(), alloc);
        //             for (framebuffers, display.image_views) |*framebuffer, *image_view| {
        //                 framebuffer.* = try .init(&device, &render_pass, display.image_size, &.{image_view}, alloc);
        //             }
        //         },
        //         else => return err,
        //     }
        // }
        // const framebuffer = &framebuffers[framebuffer_index];
        // // std.log.debug("{}\n", .{framebuffer_index});
        //
        // try command_buffer.reset();
        // try command_buffer.begin();
        // command_buffer.queueBeginRenderPass(&render_pass, framebuffer);
        // command_buffer.queueDraw(&graphics_pipeline, framebuffer);
        // command_buffer.queueEndRenderPass();
        // try command_buffer.end();
        // try command_buffer.submit(&device, &image_available_semaphore, &render_finished_semaphore, null);
        // display.presentFramebuffer(framebuffer_index, &render_finished_semaphore, &in_flight_fence) catch |err| switch (err) {
        //     error.DisplayOutOfDate => {
        //         try device.waitUntilIdle();
        //         for (framebuffers) |*x| {
        //             x.deinit(&device);
        //         }
        //         try display.rebuild(window.getClientSize(), alloc);
        //         for (framebuffers, display.image_views) |*x, *image_view| {
        //             x.* = try .init(&device, &render_pass, display.image_size, &.{image_view}, alloc);
        //         }
        //     },
        //     else => return err,
        // };

        eventHandler() catch {};

        // frame = (frame + 1) % frames_in_flight;
    }
}

fn createShader(device: *gpu.Device, filepath: []const u8, stage: gpu.Shader.Stage, alloc: std.mem.Allocator) !gpu.Shader {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const fileSize = try file.getEndPos();
    const buffer = try alloc.alloc(u32, try std.math.divCeil(usize, fileSize, @sizeOf(u32)));
    defer alloc.free(buffer);

    const read = try file.readAll(std.mem.sliceAsBytes(buffer));
    if (read != fileSize)
        return error.CouldntReadShaderFile;
    return gpu.Shader.fromSpirv(device, stage, buffer);
}
