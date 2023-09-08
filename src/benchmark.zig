// TODO: getScopeTimerID() is not thread-safe + they're still currently statically allocated.
// each enclave needs its own array of timers.
// TODO: resize array of timers... ? (how to keep times from getting skewed by allocations)

// :::::::::::::::::: For easy scope-based benchmarking. 
// ::: ScopeTimer ::: 
// ::::::::::::::::::

// Usage:
// {
//      var scope_timer_var = ScopeTimer.start("Scope Name", getScopeTimerID());
//      defer scope_timer_var.stop();
//      .. code you want to benchmark
// }
//
// Names are limited to 63 characters.
//
// At the end of the program (or whenever you're interested in the times), call printAllScopeTimers().


pub inline fn getScopeTimerID() usize {
    const LocalID = struct {
        var id: i32 = -1;
    };
    if (LocalID.id == -1) {
        LocalID.id = scopeTimerIDCounter();
    }
    return @intCast(usize, LocalID.id);
}

fn scopeTimerIDCounter() i32 {
    const Counter = struct {
        var ctr: i32 = -1;
    };
    Counter.ctr += 1;
    return Counter.ctr;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: timer with a single tracked value that always directly assigns times higher than it, and blends with lower
// times, which works in an average-like way while making spikes more noticeable in the number. or, maybe just always
// average the numbers but weigh larger times greater than lower times, such as (0.8 vs 0.2).

pub const ScopeTimer = struct {
    idx: usize = undefined,
    start_time: u64 = undefined,

    pub inline fn start(comptime in_name: []const u8, in_idx: usize) ScopeTimer {
        addTimer(in_idx, in_name);
        var start_inst = time.Instant.now() catch time.Instant{.timestamp=0};
        return ScopeTimer{.idx=in_idx, .start_time=start_inst.timestamp};
    }

    pub inline fn stop(self: *ScopeTimer) void {
        var end_inst = time.Instant.now() catch time.Instant{.timestamp=self.start_time};
        logEndTime(self.idx, end_inst.timestamp - self.start_time);
    }
};

pub inline fn waitUntil(timer: *std.time.Timer, nanoseconds: u64) u64 {
    var time_elapsed: u64 = timer.read();
    while (time_elapsed < nanoseconds) {
        std.time.sleep(10_000);
        time_elapsed = timer.read();
    }
    return time_elapsed;
}

// pub fn WindowTimer(comptime window_size: comptime_int) type {

//     return struct {

//         const TimerType = @This();

//         const inv_window_size = 1.0 / @floatCast(comptime_float, window_size);

//         times: [window_size]u64 = undefined,
//         time_idx: usize = 0,
//         start_time: i128 = 0,

//         pub inline fn new() TimerType {
//             return TimerType{.times = std.mem.zeroes([window_size]u64)};
//         }

//         pub inline fn seedTime(self: *TimerType, seed: f32) void {
//             for (0..window_size) |i| {
//                 self.times[i] = @floatToInt(u64, convert.milliToNano(seed));
//             }
//         }

//         pub inline fn start(self: *TimerType) void {
//             self.start_time = std.time.nanoTimestamp();
//         }

//         pub inline fn stop(self: *TimerType) void {
//             const diff: i128 = std.time.nanoTimestamp() - self.start_time;
//             self.times[self.time_idx] = if (diff < 0) @as(u64, 0) else @intCast(u64, diff);
//             self.time_idx = if (self.time_idx == window_size - 1) 0 else self.time_idx + 1;
//         }

//         pub inline fn currentWait(self: *const TimerType) f32 {
//             const diff: i128 = std.time.nanoTimestamp() - self.start_time;
//             const diff_gt0: u64 = if (diff < 0) @as(u64, 0) else @intCast(u64, diff);
//             return @floatCast(f32, convert.nanoToMilli(@intToFloat(f64, diff_gt0)));
//         }

//         pub fn runningAvgMs64(self: *const TimerType) f64 {
//             var ms: f64 = 0.0;
//             for (0..window_size) |i| {
//                 ms += convert.nanoToMilli(@intToFloat(f64, self.times[i]));
//             }
//             return ms * inv_window_size;
//         }

//         pub fn runningAvgMs32(self: *const TimerType) f32 {
//             var ns : u64 = 0;
//             for (0..window_size) |i| {
//                 ns += self.times[i];
//             }
//             return @floatCast(f32, convert.nanoToMilli(@intToFloat(f64, ns) * inv_window_size));
//         }
//     };
// }

pub fn printAllScopeTimers() void {
    print("\n", .{});
    for (timers.items()) |timer| {
        if (timer.initialized) {
            var total_time_f = @intToFloat(f64, timer.total_time);
            var ticks_f = @intToFloat(f64, timer.log_ct);
            var avg_time_f = convert.nano100ToMilli(total_time_f / ticks_f);
            var max_time_f = convert.nano100ToMilli(@intToFloat(f64, timer.max_time));
            var min_time_f = convert.nano100ToMilli(@intToFloat(f64, timer.min_time));

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
    total_time: u64 = 0, // in nanoseconds
    max_time: u64 = 0,
    min_time: u64 = std.math.maxInt(u64),
    log_ct: u64 = 0,
    initialized: bool = false,
};


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// convert 100s of nanoseconds to milliseconds
// const _100_ns_to_ms = 1e-4;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: resize array
var timers = LocalBuffer(InternalTimer, 128).new();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------------- private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

inline fn addTimer(idx: usize, name: []const u8) void {
    if (!timers.buffer[idx].initialized) {
        var timer = &timers.buffer[idx];
        timer.* = InternalTimer{};
        for (0..name.len) |c| {
            if (c >= 63) {
                break;
            }
            timer.name[c] = name[c];
        }
        timer.name[name.len] = 0;
        if (idx >= timers.len) {
            timers.setLen(idx + 1);
        }
        timer.initialized = true;
    }
}

inline fn logEndTime(id: usize, time_ns: u64) void {
    var timer = &timers.items()[id];

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
const array = @import("array.zig");
const LocalBuffer = array.LocalBuffer;
const assert = std.debug.assert;
const time = std.time;
const RandGen = std.rand.DefaultPrng;
const expect = std.testing.expect;
const convert = @import("convert.zig");

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- tests
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// fn fibonacci(x: u64) u64 {
//     if (x == 0) {
//         return 0;
//     }

//     var a: u64 = 0;
//     var b: u64 = 1;
//     var c: u64 = undefined;
//     for (2..x+1) |i| {
//         _ = i;
//         c = a + b;
//         a = b;
//         b = c;
//     }

//     return b;
// }

// fn doStuff() void {
//     var rand = RandGen.init(0);

//     var d = ScopeTimer.start("d", 3); defer d.stop();
//     var e = ScopeTimer.start("e", 4); defer e.stop();
//     for (0..100) |i| {
//         _ = i;
//         var random_number = @mod(rand.random().int(u64), 64);
//         var fib = fibonacci(random_number);
//         _ = fib;
//     }
// }

// this is more of a basic no-crash test with a little validation; prints can be looked over to make sure they
// make sense
// test "multi scope test" {

//     var rand = RandGen.init(0);

//     for (0..100) |j| {
//         _ = j;
//         var a = ScopeTimer.start("a", 0); defer a.stop();
//         var b = ScopeTimer.start("b", 1); defer b.stop();
//         var c = ScopeTimer.start("c", 2); defer c.stop();
//         for (0..100) |i| {
//             _ = i;
//             var random_number = @mod(rand.random().int(u64), 64);
//             var fib = fibonacci(random_number);
//             _ = fib;
//         }
//         doStuff();
//     }

//     // doStuff() timers start later and stop sooner, so their time should be less.
//     try expect(timers.items[3].total_time < timers.items[0].total_time);
//     try expect(timers.items[3].total_time < timers.items[1].total_time);
//     try expect(timers.items[3].total_time < timers.items[2].total_time);
//     try expect(timers.items[4].total_time < timers.items[0].total_time);
//     try expect(timers.items[4].total_time < timers.items[1].total_time);
//     try expect(timers.items[4].total_time < timers.items[2].total_time);
//     try expect(timers.items[3].total_time > 0);
//     try expect(timers.items[4].total_time > 0);

//     printAllScopeTimers();
// }
