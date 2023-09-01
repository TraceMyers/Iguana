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
        defer endFrame(&frame_timer, &t, &delta_time);

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

inline fn endFrame(frame_timer: *std.time.Timer, scope_timer: *ScopeTimer, delta_time: *f32) void {
    var time_elapsed_ns: u64 = undefined;
    if (sync_endframe) {
        time_elapsed_ns = bench.waitUntil(frame_timer, sync_time_ns);
    }
    else {
        time_elapsed_ns = frame_timer.read();
    }
    delta_time.* = @floatCast(f32, convert.nanoToMilli(@intToFloat(f64, time_elapsed_ns)));

    if (print_dt) {
        if (pdt_timer >= pdt_interval) {
            pdt_timer = 0.0;
            print("delta time: {d:.4}\n", .{delta_time.*});
        }
        else {
            pdt_timer += delta_time.*;
        }
    }

    scope_timer.stop();
}


var sync_endframe: bool = true;
var print_dt: bool = true;
var sync_time_ns: u64 = 4_166_600; // 240 fps max
var pdt_timer: f32 = 0.0;
const pdt_interval: f32 = convert.baseToMilli(1.0);

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
