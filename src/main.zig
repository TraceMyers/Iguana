pub fn main() !void {
    defer memory.shutdown();
    try memory.autoStartup();

    defer window.cleanup();
    try window.init(1024, 768, "yay");

    input.init();

    defer vk.cleanup();
    try vk.init(vk.RenderMethod.Direct);

    var should_run: bool = true;
    var delta_time: f32 = 1.0 / 60.0;

    while (should_run) {
        var t = ScopeTimer.start("frame", bench.getScopeTimerID());
        var frame_timer = try std.time.Timer.start();
        defer {
            const time_elasped_ns: u64 = bench.waitUntil(&frame_timer, sync_time_ns);
            delta_time = @floatCast(f32, convert.nanoToMilli(@intToFloat(f64, time_elasped_ns)));
            t.stop();
        }

        window.pollEvents();
        if (window.shouldClose()) {
            should_run = false;
        }

        input.frameUpdate();
        try vk.drawFrame(delta_time);
    }

    bench.printAllScopeTimers();
    // try img.LoadImageTest();
}

var sync_time_ns: u64 = 4_166_600; // 240 fps max

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const array = @import("array.zig");
const LocalArray = array.LocalArray;
const bench = @import("benchmark.zig");
const ScopeTimer = bench.ScopeTimer;
const memory = @import("memory.zig");
const kmath = @import("math.zig");
const window = @import("io/window.zig");
const vk = @import("vulkan.zig");
const str = @import("string.zig");
const input = @import("io/input.zig");
const convert = @import("convert.zig");
