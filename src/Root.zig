const platform = @import("platform.zig");

pub const RenderAPI = @import("RenderAPI/RenderAPI.zig");
pub const RAPI = RenderAPI;

pub const Profiler = @import("Profiler.zig");
pub const StartFuncProfiler = Profiler.StartFuncProfiler;

pub const Window = platform.Window;
