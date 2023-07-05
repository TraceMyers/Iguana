// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------- float precision
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// determine precision given the scalar type. for checking equality between floats when the floats involved
// are very large numbers (for f32: -2^20 to 2^20 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonLarge(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 0.25,
        f32 => return 7e-2,
        f64 => return 2e-5,
        else => unreachable
    }
}

// determine precision given the scalar type. for checking equality between floats when the floats involved
// are mediumish numbers (for f32: -2^16 to 2^16 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonMedium(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 2e-2,
        f32 => return 4e-3,
        f64 => return 5e-7,
        else => unreachable
    }
}

// determine precision given the scalar type. for checking equality between floats when the floats involved
// are small numbers (-2 to 2 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonSmall(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 1e-3,
        f32 => return 2e-7,
        f64 => return 3e-16,
        else => unreachable
    }
}

// determine precision for equality between two floats. works for positive and negative values 2^-32 to 2^32 if f32
// or 2^-64 to 2^64 if f64. assumes the precision desired is the largest (least precise) precision of the two.
pub inline fn epsilonAuto(scalar_a: anytype, scalar_b: anytype) @TypeOf(scalar_a, scalar_b) {
    return switch(@TypeOf(scalar_a)) {
        f32 => return @max(epsilonAuto32(scalar_a), epsilonAuto32(scalar_b)),
        f64 => return @max(epsilonAuto64(scalar_a), epsilonAuto64(scalar_b)),
        else => unreachable,
    };
}

pub inline fn nearlyEqual(scalar_a: anytype, scalar_b: anytype) @TypeOf(scalar_a, scalar_b) {
    const eps = switch(@TypeOf(scalar_a)) {
        f32 => return @max(epsilonAuto32(scalar_a), epsilonAuto32(scalar_b)),
        f64 => return @max(epsilonAuto64(scalar_a), epsilonAuto64(scalar_b)),
        else => unreachable,
    };
    return @fabs(scalar_a - scalar_b) <= eps;
}

inline fn epsilonAuto32(scalar: f32) f32 {
    const exponent = getExponent32(scalar);
    if (exponent >= 0) {
        if (exponent > 32) {
            return std.math.f32_max;
        }
        else {
            return f32_epsilons[@intCast(usize, exponent)];
        }
    }
    else {
        if (exponent < -32) {
            return 0.0;
        }
        else {
            return f32_epsilons[@intCast(usize, std.math.absCast(exponent) + 32)];
        }
    }
}

inline fn epsilonAuto64(scalar: f64) f64 {
    const exponent = getExponent64(scalar);
    if (exponent >= 0) {
        if (exponent > 64) {
            return std.math.f64_max;
        }
        else {
            return f64_epsilons[@intCast(usize, exponent)];
        }
    }
    else {
        if (exponent < -64) {
            return 0.0;
        }
        else {
            return f64_epsilons[@intCast(usize, std.math.absCast(exponent) + 64)];
        }
    }
}

// copied from std.math.frexp(), because it runs faster when you only want the exponent. thank you zig devs!
fn getExponent32(x: f32) i32 {
    var exponent: i32 = undefined;
    var y = @bitCast(u32, x);
    const e = @intCast(i32, y >> 23) & 0xFF;

    if (e == 0) {
        if (x != 0) {
            // subnormal
            exponent = getExponent32(x * 0x1.0p64) - 64;
        } else {
            // frexp(+-0) = (+-0, 0)
            exponent = 0;
        }
        return exponent;
    }
    else if (e == 0xFF) {
        // frexp(nan) = (nan, undefined)
        exponent = undefined;

        // frexp(+-inf) = (+-inf, 0)
        if (math.isInf(x)) {
            exponent = 0;
        }

        return exponent;
    }

    return e - 0x7E;
}

// copied from std.math.frexp(), because it runs faster when you only want the exponent. thank you zig devs!
fn getExponent64(x: f64) i32 {
    var exponent: i32 = undefined;
    var y = @bitCast(u64, x);
    const e = @intCast(i32, y >> 52) & 0x7FF;

    if (e == 0) {
        if (x != 0) {
            // subnormal
            exponent = getExponent64(x * 0x1.0p64) - 64;
        } else {
            // frexp(+-0) = (+-0, 0)
            exponent = 0;
        }
        return exponent;
    } else if (e == 0x7FF) {
        // frexp(nan) = (nan, undefined)
        exponent = undefined;

        // frexp(+-inf) = (+-inf, 0)
        if (math.isInf(x)) {
            exponent = 0;
        }

        return exponent;
    }

    return e - 0x3FE;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const f16_epsilon_divisor: comptime_float = 1024.0;
const f32_epsilon_divisor: comptime_float = 8388608.0;
const f64_epsilon_divisor: comptime_float = 4503599627370496.0;

pub const f16_epsilons: [24]f16 = .{
    @intToFloat(f16, 1      ) / f16_epsilon_divisor,
    @intToFloat(f16, 1      ) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  1) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  2) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  3) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  4) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  5) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  6) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  7) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  8) / f16_epsilon_divisor,
    @intToFloat(f16, 1 <<  9) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 10) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 11) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 12) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 13) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 14) / f16_epsilon_divisor,
    @intToFloat(f16, 1 << 15) / f16_epsilon_divisor,
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 1)),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 2)),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 3)),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 4)),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 5)),
    @intToFloat(f16, 1      ) / (f16_epsilon_divisor * (1 << 6)),
};

pub const f32_epsilons: [65]f32 = .{
    @intToFloat(f32, 1      ) / f32_epsilon_divisor,
    @intToFloat(f32, 1      ) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  1) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  2) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  3) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  4) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  5) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  6) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  7) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  8) / f32_epsilon_divisor,
    @intToFloat(f32, 1 <<  9) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 10) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 11) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 12) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 13) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 14) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 15) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 16) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 17) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 18) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 19) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 20) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 21) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 22) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 23) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 24) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 25) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 26) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 27) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 28) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 29) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 30) / f32_epsilon_divisor,
    @intToFloat(f32, 1 << 31) / f32_epsilon_divisor,
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 1)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 2)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 3)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 4)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 5)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 6)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 7)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 8)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 9)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 10)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 11)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 12)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 13)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 14)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 15)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 16)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 17)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 18)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 19)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 20)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 21)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 22)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 23)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 24)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 25)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 26)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 27)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 28)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 29)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 30)),
    @intToFloat(f32, 1      ) / (f32_epsilon_divisor * (1 << 31)),
};

pub const f64_epsilons: [129]f64 = .{
    @intToFloat(f64, 1      ) / f64_epsilon_divisor,
    @intToFloat(f64, 1      ) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  1) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  2) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  3) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  4) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  5) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  6) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  7) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  8) / f64_epsilon_divisor,
    @intToFloat(f64, 1 <<  9) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 10) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 11) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 12) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 13) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 14) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 15) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 16) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 17) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 18) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 19) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 20) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 21) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 22) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 23) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 24) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 25) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 26) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 27) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 28) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 29) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 30) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 31) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 32) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 33) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 34) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 35) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 36) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 37) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 38) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 39) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 40) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 41) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 42) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 43) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 44) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 45) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 46) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 47) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 48) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 49) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 50) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 51) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 52) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 53) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 54) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 55) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 56) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 57) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 58) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 59) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 60) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 61) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 62) / f64_epsilon_divisor,
    @intToFloat(f64, 1 << 63) / f64_epsilon_divisor,
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 1)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 2)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 3)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 4)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 5)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 6)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 7)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 8)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 9)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 10)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 11)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 12)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 13)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 14)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 15)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 16)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 17)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 18)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 19)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 20)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 21)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 22)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 23)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 24)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 25)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 26)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 27)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 28)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 29)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 30)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 31)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 32)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 33)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 34)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 35)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 36)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 37)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 38)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 39)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 40)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 41)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 42)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 43)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 44)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 45)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 46)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 47)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 48)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 49)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 50)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 51)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 52)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 53)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 54)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 55)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 56)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 57)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 58)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 59)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 60)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 61)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 62)),
    @intToFloat(f64, 1      ) / (f64_epsilon_divisor * (1 << 63)),
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const math = std.math;