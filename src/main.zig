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
        var t = ScopeTimer.start("frame", benchmark.getScopeTimerID());
        defer t.stop();
        // frame_timer_short.start();
        frame_timer_long.start();
        defer {
            // frame_timer_short.stop();
            frame_timer_long.stop();
            delta_time = frame_timer_long.runningAvgMs32();
        }

        window.pollEvents();
        if (window.shouldClose()) {
            should_run = false;
        }
        // std.time.sleep(convert.milliToNano(2));

        input.frameUpdate(delta_time);

        try vk.drawFrame(delta_time);
    }
    print("avg delta time: {d:.3}\n", .{delta_time});

    benchmark.printAllScopeTimers();
    // try img.LoadImageTest();
}

// var frame_timer_short = benchmark.WindowTimer(4).new();
var frame_timer_long = benchmark.WindowTimer(128).new();
var frame_timer_print_ctr: u16 = 0;
const frame_timer_print_rate: u16 = 1;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const array = @import("array.zig");
const LocalArray = array.LocalArray;
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const memory = @import("memory.zig");
const kmath = @import("math.zig");
const window = @import("io/window.zig");
const vk = @import("vulkan.zig");
const str = @import("string.zig");
const input = @import("io/input.zig");
const convert = @import("convert.zig");
