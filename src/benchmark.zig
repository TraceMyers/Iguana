// :::::::::::::::::: For easy scope-based benchmarking. For now, meant to be used with scripts/timerid.py to set the
// ::: ScopeTimer ::: timer ids. Usage assumes python 3.x is installed and python.exe is in your environment variables.
// ::::::::::::::::::

// Usage:
// {
//      const scope_timer_var = ScopeTimer(0, "Scope Name").start();
//      defer scope_timer_var.stop();
//      .. code you want to benchmark
// }
//
// After creating any new scope timer, run timerid.py with python to automatically replace the passed-in id (the zero)
// with a unique id. this should ensure that each timer has a unique id. In practice, you can put any number inside
// the parentheses and it will likely be changed. I will be working this into the build process to be handled
// automatically per some build args.
//
// Names are limited to 63 characters.
//
// At the end of the program (or whenever you're interested in the times), call printAllScopeTimers().
//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn ScopeTimer(comptime in_idx: usize, comptime in_name: []const u8) type {
    return struct {
        const Self = @This();
        idx: usize = undefined,
        start: u64 = undefined,

        pub fn start() Self {
            addTimer(in_idx, in_name);
            var start_inst = time.Instant.now() catch time.Instant{.timestamp=0};
            return Self{.idx=in_idx, .start=start_inst.timestamp};
        }

        pub fn stop(self: Self) void {
            var end_inst = time.Instant.now() catch time.Instant{.timestamp=self.start};
            logEndTime(self.idx, end_inst.timestamp - self.start);
        }
    };
}

pub fn printAllScopeTimers() void {
    for (0..timers.count()) |idx| {
        var timer = &timers.items[idx];
        if (timer.initialized) {
            var total_time_f = @intToFloat(f64, timer.total_time);
            var ticks_f = @intToFloat(f64, timer.log_ct);
            var avg_time_f = total_time_f / ticks_f * _100_ns_to_ms;
            var max_time_f = @intToFloat(f64, timer.max_time) * _100_ns_to_ms;
            var min_time_f = @intToFloat(f64, timer.min_time) * _100_ns_to_ms;

            print("--- scope timer |{s}| ---\n", .{timer.name});
            print("avg: {d:0.5} ms // max: {d:0.4} ms // min: {d:0.4} ms\n", .{avg_time_f, max_time_f, min_time_f});
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const InternalTimer = struct {
    name: [64]u8 = undefined, 
    total_time: u64 = 0, // in hundreds of nanoseconds
    max_time: u64 = 0,
    min_time: u64 = std.math.maxInt(u64),
    log_ct: u64 = 0,
    initialized: bool = false,
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// convert 100s of nanoseconds to milliseconds
const _100_ns_to_ms = 1e-4;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: resize array
var timers = LocalArray(InternalTimer, 128).new();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------------- private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn addTimer(idx: usize, name: []const u8) void {
    if (!timers.items[idx].initialized) {
        var timer = &timers.items[idx];
        timer.* = InternalTimer{};
        for (0..name.len) |c| {
            if (c >= 63) {
                break;
            }
            timer.name[c] = name[c];
        }
        timer.name[name.len] = 0;
        if (idx >= timers.count()) {
            timers.setCount(idx + 1);
        }
        timer.initialized = true;
    }
}

fn logEndTime(id: usize, time_ns: u64) void {
    var timer = &timers.items[id];

    timer.total_time += time_ns;
    timer.log_ct += 1;

    if (time_ns > timer.max_time) {
        timer.max_time = time_ns;
    }
    if (time_ns < timer.min_time) {
        timer.min_time = time_ns;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const print = std.debug.print;
const zarray = @import("array.zig");
const LocalArray = zarray.LocalArray;
const assert = std.debug.assert;
const time = std.time;
const RandGen = std.rand.DefaultPrng;
const expect = std.testing.expect;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- tests
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn fibonacci(x: u64) u64 {
    if (x == 0) {
        return 0;
    }

    var a: u64 = 0;
    var b: u64 = 1;
    var c: u64 = undefined;
    for (2..x+1) |i| {
        _ = i;
        c = a + b;
        a = b;
        b = c;
    }

    return b;
}

fn doStuff() void {
    var rand = RandGen.init(0);

    const d = ScopeTimer(3, "d").start(); defer d.stop();
    const e = ScopeTimer(4, "e").start(); defer e.stop();
    for (0..100) |i| {
        _ = i;
        var random_number = @mod(rand.random().int(u64), 64);
        var fib = fibonacci(random_number);
        _ = fib;
    }
}

// this is more of a basic no-crash test with a little validation; prints can be looked over to make sure they
// make sense
test "multi scope test" {

    var rand = RandGen.init(0);

    for (0..100) |j| {
        _ = j;
        const a = ScopeTimer(0, "a").start(); defer a.stop();
        const b = ScopeTimer(1, "b").start(); defer b.stop();
        const c = ScopeTimer(2, "c").start(); defer c.stop();
        for (0..100) |i| {
            _ = i;
            var random_number = @mod(rand.random().int(u64), 64);
            var fib = fibonacci(random_number);
            _ = fib;
        }
        doStuff();
    }

    // doStuff() timers start later and stop sooner, so their time should be less.
    try expect(timers.items[3].total_time < timers.items[0].total_time);
    try expect(timers.items[3].total_time < timers.items[1].total_time);
    try expect(timers.items[3].total_time < timers.items[2].total_time);
    try expect(timers.items[4].total_time < timers.items[0].total_time);
    try expect(timers.items[4].total_time < timers.items[1].total_time);
    try expect(timers.items[4].total_time < timers.items[2].total_time);
    try expect(timers.items[3].total_time > 0);
    try expect(timers.items[4].total_time > 0);

    printAllScopeTimers();
}
