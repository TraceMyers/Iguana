
pub fn main() !void {
    try mem6.perfMicroRun();
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
const linalg = @import("linalg.zig");
const Vec2 = linalg.Vec2;
const Vec3 = linalg.Vec3;
const Plane = linalg.Plane;
