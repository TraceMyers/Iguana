pub fn main() !void {
    // defer mem6.shutdown();
    // try mem6.autoStartup();

    // defer window.cleanup();
    // try window.init(1024, 768, "yay");

    // defer vk.cleanup();
    // try vk.init(vk.RenderMethod.Direct);

    // var should_run: bool = true;
    // while (should_run) {
    //     // frame_timer.start();

    //     window.pollEvents();
    //     if (window.shouldClose()) {
    //         should_run = false;
    //     }
    //     try vk.drawFrame();

    //     // frame_timer.stop();
    //     // if (frame_timer_print_ctr >= frame_timer_print_rate) {
    //     //     print("avg frame time: {d}\n", .{frame_timer.runningAvgMs()});
    //     //     frame_timer_print_ctr = 0;
    //     // }
    //     // else {
    //     //     frame_timer_print_ctr += 1;
    //     // }
    // }

    // benchmark.printAllScopeTimers();
    try img.LoadImageTest();
}

var frame_timer = benchmark.WindowTimer(4).new();
var frame_timer_print_ctr: u16 = 0;
const frame_timer_print_rate: u16 = 1;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const zarray = @import("array.zig");
const LocalArray = zarray.LocalArray;
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const mem6 = @import("mem6.zig");
const gm = @import("gmath.zig");
const window = @import("window.zig");
const vk = @import("vulkan.zig");
const str = @import("string.zig");
const img = @import("image.zig");
