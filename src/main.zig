pub fn main() !void {

    defer window.cleanup();
    try window.init(1024, 768, "yay");

    defer vk.cleanup();
    try vk.init();

    var should_run: bool = true;
    while (should_run) {
        window.pollEvents();
        if (window.shouldClose()) {
            should_run = false;
        }
        try vk.drawFrame();
    }

    benchmark.printAllScopeTimers();
}

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const zarray = @import("array.zig");
const LocalArray = zarray.LocalArray;
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const mem6 = @import("mem6.zig");
const alloc = mem6.alloc;
const free = mem6.free;
const ndm = @import("ndmath.zig");
const Vec2 = ndm.Vec2;
const Vec3 = ndm.Vec3;
const Plane = ndm.Plane;
const window = @import("window.zig");
const vk = @import("vulkan.zig");