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

    window = try mw.Window.Create("TEST", 480, 340);
    try window.SetTitle("TEST");
    defer window.Destroy();

    const instance = try mw.Instance.Create(true, alloc);
    defer instance.Destroy(alloc);

    const physicalDevice = try instance.BestPhysicalDevice(alloc);
    var device = try instance.CreateDevice(&physicalDevice, alloc);
    defer device.Destroy();

    const display = try device.CreateDisplay(&window, alloc);
    defer display.Destroy();

    const renderPass = try display.CreateRenderPass();
    defer renderPass.Destroy();

    //const buffer = try device.CreateBuffer(16, .{ .vertex = true });
    //defer buffer.Destroy();

    while (running) {
        EventHandler() catch {};
    }
}
