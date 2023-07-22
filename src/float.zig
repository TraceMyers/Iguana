// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------- float precision
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// get a small number given the scalar type. for checking equality between floats when the floats involved
// are very large numbers (for f32: -2^20 to 2^20 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonLarge(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 0.25,
        f32 => return 7e-2,
        f64 => return 2e-5,
        else => unreachable
    }
}

// get a small number given the scalar type. for checking equality between floats when the floats involved
// are mediumish numbers (for f32: -2^16 to 2^16 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonMedium(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 2e-2,
        f32 => return 4e-3,
        f64 => return 5e-7,
        else => unreachable
    }
}

// get a small number given the scalar type. for checking equality between floats when the floats involved
// are small numbers (-2 to 2 exclusive). not useful for differences between very small numbers.
pub inline fn epsilonSmall(comptime ScalarType: anytype) comptime_float {
    switch(ScalarType) {
        f16 => return 1e-3,
        f32 => return 2e-7,
        f64 => return 3e-16,
        else => unreachable
    }
}

// determine precision for equality between two floats. works for positive and negative values over all of f32
// and 2^-128 to 2^128 for f64. assumes the precision desired is the largest (least precise) precision of the two.
// using this is (I believe) as precise as you can get, and it is useful for differences between very small numbers.
// **for f16, this simply returns epsilonMedium()**
pub inline fn epsilonAuto(scalar_a: anytype, scalar_b: anytype) @TypeOf(scalar_a, scalar_b) {
    return switch(@TypeOf(scalar_a)) {
        f16 => epsilonMedium(f16),
        f32 => epsilonAuto32(@max(@fabs(scalar_a), @fabs(scalar_b))),
        f64 => epsilonAuto64(@max(@fabs(scalar_a), @fabs(scalar_b))),
        else => unreachable,
    };
}

// determine if two floats are approximately equal, accounting for the (I believe) maximum potential error from a single
// subtraction between the floats. works for positive and negative values over all of f32 and 2^-128 to 2^128 for f64.
// assumes the precision desired is the largest (least precise) precision of the two. using this is (I believe) as
// precise as you can get, and it is useful for differences between very small numbers (1e-24, 1e-28, etc.).
// **for f16, this simply returns whether the difference is leq epsilonMedium()**
pub inline fn nearlyEqual(scalar_a: anytype, scalar_b: anytype) @TypeOf(scalar_a, scalar_b) {
    return @fabs(scalar_a - scalar_b) <= epsilonAuto(scalar_a, scalar_b);
}

// copied from std.math.frexp(), because it runs faster when you only want the exponent. thank you zig devs!
pub fn getExponent32(x: f32) i32 {
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
pub fn getExponent64(x: f64) i32 {
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

inline fn epsilonAuto32(scalar: f32) f32 {
    const exponent = getExponent32(scalar);
    if (exponent >= 0) {
        return f32_epsilons[@intCast(usize, exponent)];
    }
    else {
        return f32_epsilons[@intCast(usize, std.math.absCast(exponent) + 128)];
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


// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const f16_epsilon_divisor: comptime_float = 1024.0;
const f32_epsilon_divisor: comptime_float = 8388608.0;
const f64_epsilon_divisor: comptime_float = 4503599627370496.0;

pub const f16_epsilons: [31]f16 = .{
    @intToFloat(comptime_float, 1      ) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  1) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  2) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  3) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  4) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  5) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  6) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  7) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  8) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  9) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 10) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 11) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 12) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 13) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 14) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 15) / f16_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 1)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 2)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 3)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 4)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 5)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 6)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 7)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 8)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 9)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 10)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 11)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 12)),
    @intToFloat(comptime_float, 1      ) / (f16_epsilon_divisor * (1 << 13)),
};

pub const f32_epsilons: [255]f32 = .{
    @intToFloat(comptime_float, 1      ) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  1) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  2) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  3) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  4) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  5) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  6) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  7) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  8) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  9) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 10) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 11) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 12) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 13) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 14) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 15) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 16) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 17) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 18) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 19) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 20) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 21) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 22) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 23) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 24) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 25) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 26) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 27) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 28) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 29) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 30) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 31) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 32) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 33) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 34) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 35) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 36) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 37) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 38) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 39) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 40) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 41) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 42) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 43) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 44) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 45) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 46) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 47) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 48) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 49) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 50) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 51) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 52) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 53) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 54) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 55) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 56) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 57) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 58) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 59) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 60) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 61) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 62) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 63) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 64) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 65) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 66) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 67) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 68) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 69) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 70) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 71) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 72) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 73) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 74) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 75) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 76) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 77) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 78) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 79) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 80) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 81) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 82) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 83) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 84) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 85) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 86) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 87) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 88) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 89) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 90) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 91) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 92) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 93) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 94) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 95) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 96) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 97) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 98) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 99) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 100) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 101) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 102) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 103) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 104) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 105) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 106) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 107) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 108) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 109) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 110) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 111) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 112) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 113) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 114) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 115) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 116) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 117) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 118) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 119) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 120) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 121) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 122) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 123) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 124) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 125) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 126) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 127) / f32_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 1)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 2)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 3)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 4)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 5)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 6)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 7)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 8)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 9)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 10)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 11)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 12)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 13)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 14)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 15)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 16)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 17)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 18)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 19)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 20)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 21)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 22)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 23)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 24)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 25)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 26)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 27)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 28)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 29)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 30)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 31)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 32)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 33)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 34)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 35)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 36)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 37)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 38)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 39)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 40)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 41)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 42)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 43)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 44)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 45)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 46)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 47)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 48)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 49)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 50)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 51)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 52)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 53)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 54)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 55)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 56)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 57)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 58)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 59)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 60)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 61)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 62)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 63)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 64)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 65)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 66)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 67)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 68)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 69)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 70)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 71)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 72)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 73)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 74)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 75)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 76)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 77)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 78)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 79)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 80)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 81)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 82)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 83)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 84)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 85)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 86)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 87)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 88)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 89)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 90)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 91)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 92)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 93)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 94)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 95)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 96)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 97)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 98)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 99)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 100)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 101)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 102)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 103)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 104)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 105)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 106)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 107)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 108)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 109)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 110)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 111)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 112)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 113)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 114)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 115)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 116)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 117)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 118)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 119)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 120)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 121)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 122)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 123)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 124)),
    @intToFloat(comptime_float, 1      ) / (f32_epsilon_divisor * (1 << 125)),
};

pub const f64_epsilons: [255]f64 = .{
    @intToFloat(comptime_float, 1      ) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  1) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  2) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  3) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  4) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  5) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  6) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  7) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  8) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 <<  9) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 10) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 11) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 12) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 13) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 14) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 15) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 16) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 17) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 18) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 19) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 20) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 21) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 22) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 23) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 24) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 25) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 26) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 27) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 28) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 29) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 30) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 31) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 32) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 33) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 34) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 35) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 36) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 37) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 38) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 39) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 40) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 41) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 42) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 43) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 44) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 45) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 46) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 47) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 48) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 49) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 50) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 51) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 52) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 53) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 54) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 55) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 56) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 57) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 58) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 59) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 60) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 61) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 62) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 63) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 64) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 65) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 66) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 67) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 68) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 69) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 70) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 71) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 72) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 73) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 74) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 75) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 76) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 77) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 78) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 79) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 80) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 81) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 82) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 83) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 84) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 85) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 86) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 87) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 88) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 89) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 90) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 91) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 92) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 93) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 94) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 95) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 96) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 97) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 98) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 99) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 100) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 101) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 102) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 103) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 104) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 105) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 106) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 107) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 108) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 109) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 110) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 111) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 112) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 113) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 114) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 115) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 116) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 117) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 118) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 119) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 120) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 121) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 122) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 123) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 124) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 125) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 126) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1 << 127) / f64_epsilon_divisor,
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 1)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 2)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 3)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 4)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 5)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 6)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 7)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 8)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 9)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 10)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 11)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 12)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 13)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 14)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 15)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 16)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 17)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 18)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 19)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 20)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 21)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 22)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 23)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 24)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 25)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 26)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 27)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 28)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 29)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 30)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 31)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 32)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 33)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 34)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 35)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 36)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 37)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 38)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 39)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 40)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 41)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 42)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 43)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 44)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 45)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 46)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 47)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 48)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 49)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 50)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 51)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 52)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 53)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 54)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 55)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 56)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 57)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 58)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 59)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 60)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 61)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 62)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 63)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 64)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 65)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 66)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 67)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 68)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 69)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 70)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 71)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 72)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 73)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 74)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 75)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 76)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 77)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 78)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 79)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 80)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 81)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 82)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 83)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 84)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 85)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 86)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 87)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 88)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 89)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 90)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 91)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 92)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 93)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 94)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 95)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 96)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 97)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 98)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 99)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 100)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 101)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 102)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 103)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 104)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 105)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 106)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 107)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 108)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 109)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 110)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 111)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 112)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 113)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 114)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 115)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 116)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 117)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 118)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 119)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 120)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 121)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 122)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 123)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 124)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 125)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 126)),
    @intToFloat(comptime_float, 1      ) / (f64_epsilon_divisor * (1 << 127)),
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- tests
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// test "epsilon arrays" {
//     print("\n--- f16 exponent ---\n", .{});
//     print("{d} to {d}\n", .{math.log2(math.f16_min), math.round(math.log2(math.f16_max))});

//     print("--- f32 exponent ---\n", .{});
//     print("{d} to {d}\n", .{math.log2(math.f32_min), math.round(math.log2(math.f32_max))});

//     print("--- f64 exponent ---\n", .{});
//     print("{d} to {d}\n", .{math.log2(math.f64_min), math.log2(math.f64_max)});
// }