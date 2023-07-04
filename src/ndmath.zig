
// TODO: is there a way to cast scalar types such that same-bitwidth vector types could do arithmetic with each other?
// TODO: ... or just make it easy to convert between them.
// TODO: test @setFloatMode() (a per-scope thing that allows ffast-math optimizations)

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------------- Vec
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const fVec2 = Vec(2, f32);
pub const fVec3 = Vec(3, f32);
pub const fVec4 = Vec(4, f32);

pub const dfVec2 = Vec(2, f64);
pub const dVec3 = Vec(3, f64);
pub const dfVec4 = Vec(4, f64);

pub const iVec2 = Vec(2, i32);
pub const iVec3 = Vec(3, i32);
pub const iVec4 = Vec(4, i32);

pub const diVec2 = Vec(2, i64);
pub const diVec3 = Vec(3, i64);
pub const diVec4 = Vec(4, i64);

pub const uVec2 = Vec(2, u32);
pub const uVec3 = Vec(3, u32);
pub const uVec4 = Vec(4, u32);

pub const duVec2 = Vec(2, u64);
pub const duVec3 = Vec(3, u64);
pub const duVec4 = Vec(4, u64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn Vec(comptime length: comptime_int, comptime ScalarType: type) type {

    return struct {

    // compile time information throughout these functions allows for them to be reduced to branchless execution
    // according to compiler explorer. for example, vAddc() with two vectors of the same length will simply be
    // return VecType{ .val = self.val + other.val };. thanks compiler explorer and thanks to zsf for allowing more
    // direct, explicit communication with the compiler :)

        const VecType = @This();

        val: @Vector(length, ScalarType) = undefined,

    // ------------------------------------------------------------------------------------------------------------ init

        pub inline fn new() VecType {
            return VecType{ .val = std.mem.zeroes([length]ScalarType) };
        }

        pub inline fn init(scalars: [length]ScalarType) VecType {
            return VecType{ .val = scalars };
        }

        pub inline fn fromScalar(scalar: ScalarType) VecType {
            return VecType{ .val = @splat(length, scalar) };
        }

        // convert vector with scalar type Ta and length Na to a vector with scalar type Tb and length Nb, where Na
        // does not need to equal Nb. If Ta != Tb, then bitwidth(Tb) must be >= bitwidth(Ta)
        // example: var new_vec3 = fVec3.fromVec(some_vec4);
        pub inline fn fromVec(vec: anytype) VecType {
            if (length > @TypeOf(vec).componentLenCpt()) {
                var self = VecType{ .val = std.mem.zeroes([length]ScalarType) };
                inline for (0..@TypeOf(vec).componentLenCpt()) |i| {
                    self.val[i] = vec.val[i];
                }
                return self;
            }
            else if (length < @TypeOf(vec).componentLenCpt() or @TypeOf(vec) != VecType) {
                var self: VecType = undefined;
                inline for (0..length) |i| {
                    self.val[i] = vec.val[i];
                }
                return self;
            }
            else {
                return vec;
            }
        }

    // ------------------------------------------------------------------------------------------------------ conversion

        pub inline fn toIntVec(self: *const VecType, comptime IntType: type) Vec(length, IntType) {
            var int_vec: Vec(length, IntType) = undefined;
            inline for(0..length) |i| {
                int_vec.val[i] = @floatToInt(IntType, self.val[i]);
            }
            return int_vec;
        }

        pub inline fn toIntVecRounded(self: *const VecType, comptime IntType: type) Vec(length, IntType) {
            var int_vec: Vec(length, IntType) = undefined;
            inline for(0..length) |i| {
                int_vec.val[i] = @floatToInt(IntType, @round(self.val[i]) + VecType.epsilonCpt());
            }
            return int_vec;
        }

        pub inline fn toFloatVec(self: *const VecType, comptime FloatType: type) Vec(length, FloatType) {
            var float_vec: Vec(length, FloatType) = undefined;
            inline for(0..length) |i| {
                float_vec.val[i] = @intToFloat(FloatType, self.val[i]);
            }
            return float_vec;
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn set(self: *VecType, scalars: [length]ScalarType) void {
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..length], &scalars);
        }

        pub inline fn scalarFill(self: *VecType, scalar: ScalarType) void {
            self.val = @splat(length, scalar);
        }

        pub inline fn copyAssymetric(self: *VecType, vec: anytype) void {
            const copy_len = @min(@TypeOf(vec).componentLenCpt(), length);
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..copy_len], @ptrCast([*]const ScalarType, &vec.val[0])[0..copy_len]);
        }

    // ------------------------------------------------------------------------------------------------------ components

        pub inline fn x(self: *const VecType) ScalarType {
            return self.val[0];
        }

        pub inline fn y(self: *const VecType) ScalarType {
            return self.val[1];
        }

        pub inline fn z(self: *const VecType) ScalarType {
            return self.val[2];
        }

        pub inline fn w(self: *const VecType) ScalarType {
            return self.val[3];
        }

        pub inline fn setX(self: *VecType, in_x: f32) void {
            self.val[0] = in_x;
        }

        pub inline fn setY(self: *VecType, in_y: f32) void {
            self.val[1] = in_y;
        }

        pub inline fn setZ(self: *VecType, in_z: f32) void {
            self.val[2] = in_z;
        }

        pub inline fn setW(self: *VecType, in_w: f32) void {
            self.val[3] = in_w;
        }

        pub inline fn componentLen(self: *const VecType) usize {
            _ = self;
            return length;
        }

    // ---------------------------------------------------------------------------------------------------- compile time

        // get the compoment length of this vector. important for use anytime a function can have its branches removed
        // with comptime information.
        pub inline fn componentLenCpt() comptime_int {
            return length;
        }

        // comptime function giving roughly these ranges of equality between float values:
        // f16: -32 to 32
        // f32: -65_535 to 65_535
        // f64; -1_000_000 to 1_000_000 (or more, untested)
        pub inline fn epsilonCpt() comptime_float {
            switch(ScalarType) {
                f16 => return 1e-1,
                f32 => return 1e-2,
                f64 => return 1e-9,
                else => unreachable
            }
        }

    // ----------------------------------------------------------------------------------------------- vector arithmetic

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn addc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType) {
                return sAddc(self, other);
            }
            else {
                return switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vAddcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vAddcLoop(self, other);
                        }
                        else {
                            return VecType{ .val = self.val + other.val };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lengths inline
        pub inline fn add(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType) {
                sAdd(self, other);
            }
            else {
                switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vAddLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vAddLoop(self, other);
                        }
                        else {
                            self.val += other.val;
                        }
                    },
                }
            }
        }

        // subtract two vectors of same or differing lengths with copy for assignment
        pub inline fn subc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType) {
                return sSubc(self, other);
            }
            else {
                return switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vSubcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vSubcLoop(self, other);
                        }
                        else {
                            return VecType{ .val = self.val - other.val };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lengths inline
        pub inline fn sub(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType) {
                sSub(self, other);
            }
            else {
                switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vSubLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vSubLoop(self, other);
                        }
                        else {
                            self.val -= other.val;
                        }
                    },
                }
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn mulc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType) {
                return sMulc(self, other);
            }
            else {
                return switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vMulcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vMulcLoop(self, other);
                        }
                        else {
                            return VecType{ .val = self.val * other.val };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lengths inline
        pub inline fn mul(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType) {
                sMul(self, other);
            }
            else {
                switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vMulLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vMulLoop(self, other);
                        }
                        else {
                            self.val *= other.val;
                        }
                    },
                }
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn divc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType) {
                return sDivc(self, other);
            }
            else {
                return switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vDivcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vDivcLoop(self, other);
                        }
                        else {
                            return VecType{ .val = self.val / other.val };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lengths inline
        pub inline fn div(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType) {
                sDiv(self, other);
            }
            else {
                switch(length) {
                    0, 1 => unreachable,
                    2, 3 => vDivLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).componentLenCpt() != length) {
                            break :blk vDivLoop(self, other);
                        }
                        else {
                            self.val /= other.val;
                        }
                    },
                }
            }
        }

    // ------------------------------------------------------------------------------- explicit length vector arithmetic

        pub inline fn add2dc(self: *VecType, other: anytype) VecType {
            if (length > 2) {
                var add_vec = self.*;
                add_vec.val[0] += other.val[0];
                add_vec.val[1] += other.val[1];
                return add_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] + other.val[0], self.val[1] + other.val[1]} };
            }
        }

        pub inline fn add2d(self: *VecType, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
        }

        pub inline fn sub2dc(self: *VecType, other: anytype) VecType {
            if (length > 2) {
                var sub_vec = self.*;
                sub_vec.val[0] -= other.val[0];
                sub_vec.val[1] -= other.val[1];
                return sub_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] - other.val[0], self.val[1] - other.val[1]} };
            }
        }

        pub inline fn sub2d(self: *VecType, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
        }

        pub inline fn mul2dc(self: *VecType, other: anytype) VecType {
            if (length > 2) {
                var mul_vec = self.*;
                mul_vec.val[0] *= other.val[0];
                mul_vec.val[1] *= other.val[1];
                return mul_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] * other.val[0], self.val[1] * other.val[1]} };
            }
        }

        pub inline fn mul2d(self: *VecType, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
        }

        pub inline fn div2dc(self: *VecType, other: anytype) VecType {
            if (length > 2) {
                var div_vec = self.*;
                div_vec.val[0] /= other.val[0];
                div_vec.val[1] /= other.val[1];
                return div_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] / other.val[0], self.val[1] / other.val[1]} };
            }
        }

        pub inline fn div2d(self: *VecType, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
        }

        pub inline fn add3dc(self: *VecType, other: anytype) VecType {
            if (length > 3) {
                var add_vec = self.*;
                add_vec.val[0] += other.val[0];
                add_vec.val[1] += other.val[1];
                add_vec.val[2] += other.val[2];
                return add_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] + other.val[0], self.val[1] + other.val[1], self.val[2] + other.val[2]} };
            }
        }

        pub inline fn add3d(self: *VecType, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
            self.val[2] += other.val[2];
        }

        pub inline fn sub3dc(self: *VecType, other: anytype) VecType {
            if (length > 3) {
                var sub_vec = self.*;
                sub_vec.val[0] -= other.val[0];
                sub_vec.val[1] -= other.val[1];
                sub_vec.val[2] -= other.val[2];
                return sub_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]} };
            }
        }

        pub inline fn sub3d(self: *VecType, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
            self.val[2] -= other.val[2];
        }

        pub inline fn mul3dc(self: *VecType, other: anytype) VecType {
            if (length > 3) {
                var mul_vec = self.*;
                mul_vec.val[0] *= other.val[0];
                mul_vec.val[1] *= other.val[1];
                mul_vec.val[2] *= other.val[2];
                return mul_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] * other.val[0], self.val[1] * other.val[1], self.val[2] * other.val[2]} };
            }
        }

        pub inline fn mul3d(self: *VecType, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
            self.val[2] *= other.val[2];
        }

        pub inline fn div3dc(self: *VecType, other: anytype) VecType {
            if (length > 3) {
                var div_vec = self.*;
                div_vec.val[0] /= other.val[0];
                div_vec.val[1] /= other.val[1];
                div_vec.val[2] /= other.val[2];
                return div_vec;
            }
            else {
                return VecType{ .val = .{self.val[0] / other.val[0], self.val[1] / other.val[1], self.val[2] / other.val[2]} };
            }
        }

        pub inline fn div3d(self: *VecType, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
            self.val[2] /= other.val[2];
        }

    // -------------------------------------------------------------------------------------------------- linear algebra

        pub inline fn dot(self: VecType, other: VecType) ScalarType {
            return @reduce(.Add, self.val * other.val);
        }

        pub inline fn dot2d(self: VecType, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1];
        }

        pub inline fn dot3d(self: VecType, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1] + self.val[2] * other.val[2];
        }

        pub inline fn determinant2d(self: VecType, other: VecType) ScalarType {
            return self.val[0] * other.val[1] - other.val[0] * self.val[1];
        }

        pub inline fn cross(self: VecType, other: VecType) VecType {
            return VecType { .val = @Vector(length, ScalarType){
                self.val[1] * other.val[2] - self.val[2] * other.val[1],
                self.val[2] * other.val[0] - self.val[0] * other.val[2],
                self.val[0] * other.val[1] - self.val[1] * other.val[0]
            }};
        }

    // ------------------------------------------------------------------------------------------------------------ size

        pub inline fn size(self: VecType) ScalarType {
            return @sqrt(@reduce(.Add, self.val * self.val));
        }

        pub inline fn sizeSq(self: VecType) ScalarType {
            return @reduce(.Add, self.val * self.val);
        }

        pub inline fn size2d(self: VecType) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1]);
        }

        pub inline fn sizeSq2d(self: VecType) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1];
        }

        pub inline fn size3d(self: VecType) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2]);
        }

        pub inline fn sizeSq3d(self: VecType) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2];
        }

    // -------------------------------------------------------------------------------------------------------- distance

        pub inline fn dist(self: VecType, other: VecType) ScalarType {
            const diff = self.val - other.val;
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq(self: VecType, other: VecType) ScalarType {
            const diff = self.val - other.val;
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist2d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq2d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist3d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq3d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @reduce(.Add, diff * diff);
        }

    // ---------------------------------------------------------------------------------------------------------- normal

        pub inline fn normSafe(self: VecType) VecType {
            const size_sq = self.sizeSq();
            if (size_sq < @TypeOf(self).epsilonCpt()) {
                return VecType.new();
            }
            return self.sMulc(1.0 / @sqrt(size_sq));
        }

        pub inline fn normUnsafe(self: VecType) VecType {
            return self.sMulc(1.0 / self.size());
        }

        pub inline fn isNorm(self: VecType) bool {
            return @fabs(1.0 - self.sizeSq()) < @TypeOf(self).epsilonCpt();
        }

    // --------------------------------------------------------------------------------------------------------- max/min

        pub inline fn componentMax(self: VecType) ScalarType {
            return @reduce(.Max, self.val);
        }

        pub inline fn componentMin(self: VecType) ScalarType {
            return @reduce(.Min, self.val);
        }

    // -------------------------------------------------------------------------------------------------------- equality

        pub inline fn exactlyEqual(self: VecType, other: VecType) bool {
            inline for(0..length) |i| {
                if (self.val[i] != other.val[i]) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqual(self: VecType, other: VecType) bool {
            const diff = self.val - other.val;
            inline for(0..length) |i| {
                if (@fabs(diff[i]) > F32_EPSILON) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqualByTolerance(self: VecType, other: VecType, tolerance: ScalarType) bool {
            const diff = self.val - other.val;
            inline for(0..length) |i| {
                if (@fabs(diff[i]) > tolerance) {
                    return false;
                }
            }
            return true;
        }
    // ------------------------------------------------------------------------------------------------------------ sign

        pub inline fn abs(self: VecType) VecType {
            var abs_vec = self;
            inline for (0..length) |i| {
                abs_vec.val[i] = @fabs(abs_vec.val[i]);
            }
        }

        pub inline fn flip(self: VecType) VecType {
            var flip_vec = self;
            inline for (0..length) |i| {
                flip_vec.val[i] = -flip_vec.val[i];
            }
        }

    // ----------------------------------------------------------------------------------------------------------- clamp

        pub fn clampComponents(self: VecType, min: ScalarType, max: ScalarType) VecType {
            var clamp_vec = self;
            inline for (0..length) |i| {
                clamp_vec.val[i] = std.math.clamp(clamp_vec.val[i], min, max);
            }
        }

        pub fn clampSize(self: VecType, max: ScalarType) VecType {
            const size_sq = self.sizeSq();
            if (size_sq > max * max) {
                return self.sMulc(max / @sqrt(size_sq));
            }
            return self;
        }

    // ---------------------------------------------------------------------------------------------------- trigonometry

        pub fn cosAngle(self: VecType, other: VecType) ScalarType {
            const size_product = self.size() * other.size();
            return self.dot(other) / size_product;
        }

        pub fn angle(self: VecType, other: VecType) ScalarType {
            const size_product = self.size() * other.size();
            return math.acos(self.dot(other) / size_product);
        }

        pub fn cosAnglePrenorm(self: VecType, other: VecType) ScalarType {
            return self.dot(other);
        }

        pub fn anglePrenorm(self: VecType, other: VecType) ScalarType {
            return math.acos(self.dot(other));
        }

    // ------------------------------------------------------------------------------------------------------ projection

        pub fn projectOnto(self: VecType, other: VecType) VecType {
            return other.sMulc(self.dot(other) / other.sizeSq());
        }

        pub fn projectOntoNorm(self: VecType, other: VecType) VecType {
            return other.sMulc(self.dot(other));
        }

    // ------------------------------------------------------------------------------------------------------- direction

        pub fn nearlyParallel(self: VecType, other: VecType) bool {
            const self_norm = self.normSafe();
            const other_norm = other.normSafe();
            return self_norm.dot(other_norm) > (1.0 - VecType.epsilonCpt());
        }

        pub inline fn nearlyParallelPrenorm(self_norm: VecType, other_norm: VecType) bool {
            return self_norm.dot(other_norm) > (1.0 - VecType.epsilonCpt());
        }

        pub fn nearlyOrthogonal(self: VecType, other: VecType) bool {
            const self_norm = self.normSafe();
            const other_norm = other.normSafe();
            return self_norm.dot(other_norm) < VecType.epsilonCpt();
        }

        pub inline fn nearlyOrthogonalPrenorm(self_norm: VecType, other_norm: VecType) bool {
            return self_norm.dot(other_norm) < VecType.epsilonCpt();
        }

        pub inline fn similarDirection(self: VecType, other: VecType) bool {
            return self.dot(other) > VecType.epsilonCpt();
        }

    // -------------------------------------------------------------------------------------------------------- internal

        inline fn sAddc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(length, other);
            return VecType{ .val = self.val + add_vec };
        }

        inline fn sAdd(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val += add_vec;
        }

        inline fn sSubc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(length, other);
            return VecType{ .val = self.val - add_vec };
        }

        inline fn sSub(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val -= add_vec;
        }

        inline fn sMulc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(length, other);
            return VecType{ .val = self.val * add_vec };
        }

        inline fn sMul(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val *= add_vec;
        }

        inline fn sDivc(self: VecType, other: ScalarType) VecType {
            const mul_scalar = 1.0 / other;
            return self.sMulc(mul_scalar);
        }

        inline fn sDiv(self: VecType, other: ScalarType) void {
            const mul_scalar = 1.0 / other;
            self.sMul(mul_scalar);
        }

        inline fn vAddcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                add_vec.val[i] += vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vAddLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                vec_a.val[i] += vec_b.val[i];
            }
        }

        inline fn vSubcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                add_vec.val[i] -= vec_b.val[i];
            }
            return add_vec;
        }

        inline fn vSubLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                vec_a.val[i] -= vec_b.val[i];
            }
        }

        inline fn vMulcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                add_vec.val[i] *= vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vMulLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                vec_a.val[i] *= vec_b.val[i];
            }
        }


        inline fn vDivcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                add_vec.val[i] /= vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vDivLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenCpt(), length)) |i| {
                vec_a.val[i] /= vec_b.val[i];
            }
        }

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- fRay
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const fRay = struct {

    origin: fVec3 = undefined,
    normal: fVec3 = undefined,

    pub inline fn new() fRay {
        return fRay{
            .origin = fVec3.new(),
            .normal = fVec3.init(.{1.0, 0.0, 0.0})
        };
    }

    pub inline fn fromNorm(in_normal: fVec3) !fRay {
        if (!in_normal.isNorm()) {
            return NDMathError.RayNormalNotNormalized;
        }
        return fRay {
            .origin = fVec3.new(),
            .normal = in_normal
        };
    }

    pub inline fn fromComponents(in_origin: fVec3, in_normal: fVec3) !fRay {
        if (!in_normal.isNorm()) {
            return NDMathError.RayNormalNotNormalized;
        }
        return fRay {
            .origin = in_origin,
            .normal = in_normal
        };
    }

    pub inline fn flip(self: *fRay) void {
        self.normal = self.normal.flip();
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- fPlane
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const fPlane = struct {

    normal: fVec3 = undefined,
    w: f32 = undefined,

    pub inline fn new() fPlane {
        return fPlane{
            .normal = fVec3.init(.{1.0, 0.0, 0.0}),
            .w = 0.0
        };
    }

    pub inline fn fromNorm(norm: fVec3) !fPlane {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        return fPlane {
            .normal = norm,
            .w = 0.0
        };
    }

    pub inline fn fromComponents(norm: fVec3, origin_distance: f32) !fPlane {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        return fPlane {
            .normal = norm,
            .w = origin_distance
        };
    }

    pub inline fn flipped(from_plane: fPlane) fPlane {
        var plane = from_plane;
        plane.flip();
        return plane;
    }

    // ------------------------------------------------------------------------------------------------------ components

    pub inline fn setNormFromVec(self: *fPlane, vec: fVec3) !void {
        const norm_vec = vec.normSafe();
        // vec could have components that are too small to normalize
        if (!norm_vec.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        self.normal = norm_vec;
    }

    pub inline fn setOriginDistance(self: *fPlane, origin_distance: f32) void {
        self.w = origin_distance;
    }

    pub inline fn setComponents(self: *fPlane, norm: fVec3, origin_distance: f32) !void {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        self.normal = norm;
        self.w = origin_distance;
    }

    pub inline fn normX(self: *const fPlane) f32 {
        return self.normal.val[0];
    }

    pub inline fn normY(self: *const fPlane) f32 {
        return self.normal.val[1];
    }

    pub inline fn normZ(self: *const fPlane) f32 {
        return self.normal.val[2];
    }

    pub inline fn originDistance(self: *const fPlane) f32 {
        return self.w;
    }

    pub inline fn flip(self: *const fPlane) void {
        self.normal = self.normal.flip();
    }

    // -------------------------------------------------------------------------------------------------- linear algebra

    pub inline fn pNormalDot(self: fPlane, other: fPlane) f32 {
        return self.normal.dot(other.normal);
    }

    pub inline fn vNormalDot(self: fPlane, other: fVec3) f32 {
        return self.normal.dot(other);
    }

    pub inline fn pNormalCross(self: fPlane, other: fPlane) fVec3 {
        return self.normal.cross(other.normal);
    }

    pub inline fn vNormalCross(self: fPlane, other: fVec3) fVec3 {
        return self.normal.cross(other);
    }

    // ---------------------------------------------------------------------------------------------------- trigonometry

    pub inline fn pNormalAngle(self: fPlane, other: fPlane) f32 {
        return self.normal.anglePrenorm(other.normal);
    }

    pub inline fn pNormalCosAngle(self: fPlane, other: fPlane) f32 {
        return self.normal.cosAnglePrenorm(other.normal);
    }

    pub inline fn vNormalAngle(self: fPlane, other: fVec3) f32 {
        return self.normal.angle(other);
    }

    pub inline fn vNormalCosAngle(self: fPlane, other: fVec3) f32 {
        return self.normal.cosAngle(other);
    }

    pub inline fn vNormalAnglePrenorm(self: fPlane, norm: fVec3) f32 {
        return self.normal.anglePrenorm(norm);
    }

    pub inline fn vNormalCosAnglePrenorm(self: fPlane, norm: fVec3) f32 {
        return self.normal.cosAnglePrenorm(norm);
    }

    // -------------------------------------------------------------------------------------------------------- equality

    pub inline fn exactlyEqual(self: fPlane, other: fPlane) bool {
        return self.normal.exactlyEqual(other.normal) and self.w == other.w;
    }

    pub inline fn nearlyEqual(self: fPlane, other: fPlane) bool {
        return self.normal.nearlyEqual(other.normal) and @fabs(self.w - other.w) < F32_EPSILON;
    }

    pub inline fn exactlyEqualNorm(self: fPlane, other: fVec3) bool {
        return self.normal.exactlyEqual(other);
    }

    pub inline fn nearlyEqualNorm(self: fPlane, other: fVec3) bool {
        return self.normal.nearlyEqual(other);
    }

    // ------------------------------------------------------------------------------------------------------- direction

    pub inline fn pNearlyParallel(self: fPlane, other: fPlane) bool {
        return self.normal.nearlyParallelPrenorm(other.normal);
    }

    pub inline fn pNearlyOrthogonal(self: fPlane, other: fPlane) bool {
        return self.normal.nearlyOrthogonalPrenorm(other.normal);
    }

    pub inline fn pSimilarDirection(self: fPlane, other: fPlane) bool {
        return self.normal.similarDirection(other.normal);
    }

    pub inline fn vNearlyParallel(self: fPlane, other: fVec3) bool {
        return self.normal.nearlyParallel(other);
    }

    pub inline fn vNearlyOrthogonal(self: fPlane, other: fVec3) bool {
        return self.normal.nearlyOrthogonal(other);
    }

    pub inline fn vSimilarDirection(self: fPlane, other: fVec3) bool {
        return self.normal.similarDirection(other);
    }

    pub inline fn vNearlyParallelPrenorm(self: fPlane, other: fVec3) bool {
        return self.normal.nearlyParallelPrenorm(other);
    }

    pub inline fn vNearlyOrthogonalPrenorm(self: fPlane, other: fVec3) bool {
        return self.normal.nearlyOrthogonalPrenorm(other);
    }

    // ---------------------------------------------------------------------------------------------- vector interaction

    pub inline fn pointDistSigned(self: fPlane, point: fVec3) f32 {
        return -(self.normal.dot(point) - self.w);
    }

    pub inline fn pointDist(self: fPlane, point: fVec3) f32 {
        return @fabs(self.pointDistSigned(point));
    }

    pub inline fn pointDiff(self: fPlane, point: fVec3) f32 {
        const dist = self.pointDistSigned(point);
        return fVec3.init(.{
            self.normal.val[0] * dist,
            self.normal.val[1] * dist,
            self.normal.val[2] * dist,
        });
    }

    pub inline fn pointProject(self: fPlane, point: fVec3) f32 {
        const dist = self.pointDistSigned(point);
        return fVec3.init(.{
            point.val[0] + self.normal.val[0] * dist,
            point.val[1] + self.normal.val[1] * dist,
            point.val[2] + self.normal.val[2] * dist,
        });
    }

    pub inline fn pointMirror(self: fPlane, point: fVec3) f32 {
        const double_diff = self.pointDiff(point).sMulc(2.0);
        return point.vAddc(double_diff);
    }

    pub inline fn reflect(self: fPlane, vec: fVec3) f32 {
        const reflect_dist = self.vNormalDot(vec) * -2.0;
        const reflect_diff = self.normal.sMulc(reflect_dist);
        return vec.vAddc(reflect_diff);
    }

    pub fn rayIntersect(self: fPlane, ray: fRay, distance: *f32) ?fVec3 {
        const normal_direction_product = self.vNormalDot(ray.normal);
        if (normal_direction_product >= -F32_EPSILON) {
            return null;
        }

        const normal_origin_product = self.vNormalDot(ray.origin);
        distance.* = normal_origin_product - self.w;

        if (distance.* < 0.0) {
            return null;
        }

        distance.* = distance.* / -normal_direction_product;
        const diff = ray.normal.sMulc(distance.*);
        return ray.origin.vAddc(diff);
    }

    pub fn rayIntersectEitherFace(self: fPlane, ray: fRay, distance: *f32) ?fVec3 {
        const normal_origin_product = self.vNormalDot(ray.origin);
        const normal_direction_product = self.vNormalDot(ray.normal);
        distance.* = (normal_origin_product - self.w) / -normal_direction_product;

        if (distance.* < 0.0) {
            return null;
        }

        const diff = ray.normal.sMulc(distance.*);
        return ray.origin.vAddc(diff);
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------- Quaternion
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const fQuat = Quaternion(f32);
pub const dQuat = Quaternion(f64);

pub const fquat_zero = Quaternion(f32){ .val = .{0.0, 0.0, 0.0, 0.0} };
pub const fquat_identity = Quaternion(f32){ .val = .{0.0, 0.0, 0.0, 1.0} };

pub const dquat_zero = Quaternion(f64){ .val = .{0.0, 0.0, 0.0, 0.0} };
pub const dquat_identity = Quaternion(f64){ .val = .{0.0, 0.0, 0.0, 1.0} };

// ------------------------------------------------------------------------------------------------------- type function

pub fn Quaternion(comptime ScalarType: type) type {

    return struct {
        const Self = @This();
        
        val: Vec(4, ScalarType) = undefined,

        pub fn new() Self {
            return Self{ .val = .{0.0, 0.0, 0.0, 1.0} };
        }

        pub const identity = new;

        pub inline fn init(scalars: [4]ScalarType) Self {
            return Self{ .val = scalars };
        }

        pub inline fn fromScalar(scalar: ScalarType) Self {
            return Self{ .val = @splat(4, scalar) };
        }

        pub inline fn fromVec(vec: anytype) Self {
            return Self{ .val = vec.val };
        }

        pub inline fn zero() Self {
            return Self{ .val = .{0.0, 0.0, 0.0, 0.0} };
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn set(self: *Self, scalars: [4]ScalarType) void {
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..4], &scalars);
        }

        pub inline fn scalarFill(self: *Self, scalar: ScalarType) void {
            self.val = @splat(4, scalar);
        }

        pub inline fn copyVecAssymetric(self: *Self, vec: anytype) void {
            const copy_len = @min(@TypeOf(vec).componentLenCpt(), 4);
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..copy_len], @ptrCast([*]const ScalarType, &vec.val[0])[0..copy_len]);
        }

    // ------------------------------------------------------------------------------------------------------ components

        pub inline fn x(self: *const Self) ScalarType {
            return self.val[0];
        }

        pub inline fn y(self: *const Self) ScalarType {
            return self.val[1];
        }

        pub inline fn z(self: *const Self) ScalarType {
            return self.val[2];
        }

        pub inline fn w(self: *const Self) ScalarType {
            return self.val[3];
        }

        pub inline fn setX(self: *Self, in_x: f32) void {
            self.val[0] = in_x;
        }

        pub inline fn setY(self: *Self, in_y: f32) void {
            self.val[1] = in_y;
        }

        pub inline fn setZ(self: *Self, in_z: f32) void {
            self.val[2] = in_z;
        }

        pub inline fn setW(self: *Self, in_w: f32) void {
            self.val[3] = in_w;
        }


    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------- Square Matrix
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Identity2x2: [2][2]f32 = .{
    .{1.0, 0.0},
    .{0.0, 1.0},
};

pub const Identity3x3: [3][3]f32 = .{
    .{1.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0},
    .{0.0, 0.0, 1.0}
};

pub const Identity4x4: [3][3]f32 = .{
    .{1.0, 0.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0, 0.0},
    .{0.0, 0.0, 1.0, 0.0},
    .{0.0, 0.0, 0.0, 1.0}
};

pub const Identity5x5: [5][5]f32 = .{
    .{1.0, 0.0, 0.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0, 0.0, 0.0},
    .{0.0, 0.0, 1.0, 0.0, 0.0},
    .{0.0, 0.0, 0.0, 1.0, 0.0},
    .{0.0, 0.0, 0.0, 0.0, 1.0}
};

pub fn SquareMatrix(comptime size: u32) type {

    std.debug.assert(size >= 2);

    return struct {
        const Self = @This();

        values : [size][size]f32 = undefined,

        pub fn new() Self {
            return Self{.values = std.mem.zeroes(Self)};
        }

        pub fn identity() Self {
            if (size <= 5) {
                return Self{ .values = 
                    switch(size) {
                        2 => Identity2x2,
                        3 => Identity3x3,
                        4 => Identity4x4,
                        5 => Identity5x5,
                        else => unreachable
                    }
                };
            }
            else {
                var self: Self = std.mem.zeroes(Self);
                for (0..size) |i| {
                    self.values[i][i] = 1.0;
                }
                return self;
            }
        }

        pub fn fromScalar(scalar: f32) Self {
            var self: Self = std.mem.zeroes(Self);
            inline for (0..size) |i| {
                self.values[i][i] = scalar;
            }
            return self;
        }

        // copy this vector into the diagonal of a new matrix. can be used to make a scaling matrix if 
        // size == vec.len + 1. remaining diagonal entries are identity.
        pub fn fromVecOnDiag(vec: anytype) Self {
            const vec_len = @TypeOf(vec).componentLenCpt();
            std.debug.assert(size >= vec_len);

            var self = Self.new();
            inline for(0..vec_len) |i| {
                self.values[i][i] = vec.val[i];
            }
            inline for(vec_len..size) |i| {
                self.values[i][i] = 1.0;
            }
            return self;
        }

        // copy this vector into the right column of a new matrix. can be used to make a translation matrix if
        // size == vec.len + 1. diagonal entries (except potentially the bottom right if overwritten) are identity.
        pub fn fromVecOnRightCol(vec: anytype) Self {
            const vec_len = @TypeOf(vec).componentLenCpt();
            std.debug.assert(size >= vec_len);
            var self = Self.identity();
            inline for(0..vec_len) |i| {
                self.values[i][size-1] = vec.val[i];
            }
            return self;
        }
    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const F32_EPSILON: f32 = 1e-5;
const F64_EPSILON: f64 = 1e-15;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const NDMathError = error{
    PlaneNormalNotNormalized,
    RayNormalNotNormalized,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const print = std.debug.print;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- test
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

test "SquareMatrix" {
    var m1 = SquareMatrix(3).identity();
    _ = m1;
}

test "fVec" {
    var vf3zero = fVec3.init(.{0.0, 0.0, 0.0});
    var vf2a = fVec2.init(.{5.0, 1.0});
    var vf2b = fVec2.init(.{10.0, 1.0});
    var vf3a = fVec3.init(.{5.0, 1.0, 2.101});
    var vf3b = fVec3.init(.{10.0, 1.0, -3.0});
    var vf4a = fVec4.init(.{5.0, 1.0, 2.101, -9.8282});
    var vf4b = fVec4.init(.{10.0, 1.0, -3.0, 3.333});

    const abx_sum = 5.0 + 10.0;
    const aby_sum = 1.0 + 1.0;
    const abz_sum = 2.101 + (-3.0);
    const abw_sum = -9.8282 + 3.333;

    const abx_dif = 5.0 - 10.0;
    const aby_dif = 1.0 - 1.0;
    const abz_dif = 2.101 - (-3.0);
    const abw_dif = -9.8282 - 3.333;

    const abx_prd = 5.0 * 10.0;
    const aby_prd = 1.0 * 1.0;
    const abz_prd = 2.101 * (-3.0);
    const abw_prd = -9.8282 * 3.333;

    const abx_qot = 5.0 / 10.0;
    const aby_qot = 1.0 / 1.0;
    const abz_qot = 2.101 / (-3.0);
    const abw_qot = -9.8282 / 3.333;

    var vf4_sum = fVec4.init(.{abx_sum, aby_sum, abz_sum, abw_sum});
    var vf4_dif = fVec4.init(.{abx_dif, aby_dif, abz_dif, abw_dif});
    var vf4_prd = fVec4.init(.{abx_prd, aby_prd, abz_prd, abw_prd});
    var vf4_qot = fVec4.init(.{abx_qot, aby_qot, abz_qot, abw_qot});

    var v1 = fVec3.new();
    var v2 = fVec3.init(.{0.0, 1.0, 2.0});
    var v3 = fVec3.fromScalar(3.0001);
    var v4 = fVec3.fromVec(v2);
    var v5 = fVec4.fromVec(v2);
    var v6 = fVec2.fromVec(v2);
    
    try expect(vf3zero.dist(v1) < F32_EPSILON);
    try expect(@fabs(v2.x()) < F32_EPSILON and @fabs(v2.y() - 1.0) < F32_EPSILON and @fabs(v2.z() - 2.0) < F32_EPSILON);
    try expect(@fabs(v3.x() - 3.0001) < F32_EPSILON and @fabs(v3.y() - 3.0001) < F32_EPSILON and @fabs(v3.z() - 3.0001) < F32_EPSILON);
    try expect(v4.dist(v2) < F32_EPSILON and v4.distSq(v2) < F32_EPSILON);
    try expect(v5.dist3d(v2) < F32_EPSILON and v5.distSq3d(v2) < F32_EPSILON and @fabs(v5.w()) < F32_EPSILON);
    try expect(v6.dist2d(v2) < F32_EPSILON and v6.distSq2d(v2) < F32_EPSILON);

    var v7: iVec3 = v3.toIntVec(i32);
    var v8: uVec3 = v3.toIntVec(u32);
    var v9: dVec3 = v7.toFloatVec(f64);
    var v9a = dVec3.fromVec(v3);

    try expect(v7.x() == 3 and v7.y() == 3 and v7.z() == 3);
    try expect(v8.x() == 3 and v8.y() == 3 and v8.z() == 3);
    try expect(@fabs(v9.x() - 3.0) < F32_EPSILON and @fabs(v9.y() - 3.0) < F32_EPSILON and @fabs(v9.z() - 3.0) < F32_EPSILON);
    try expect(@fabs(v9a.x() - 3.0001) < F32_EPSILON and @fabs(v9a.y() - 3.0001) < F32_EPSILON and @fabs(v9a.z() - 3.0001) < F32_EPSILON);

    v3.set(.{ 4.001, 4.001, 5.001 });
    v6.scalarFill(2.58);

    try expect(@fabs(v3.x() - 4.001) < F32_EPSILON and @fabs(v3.y() - 4.001) < F32_EPSILON and @fabs(v3.z() - 5.001) < F32_EPSILON);
    try expect(@fabs(v6.x() - 2.58) < F32_EPSILON and @fabs(v6.y() - 2.58) < F32_EPSILON);

    v6.copyAssymetric(v3);

    try expect(v6.dist2d(v3) < F32_EPSILON);

    var v10sum = vf2a.addc(vf2b);
    var v11sum = vf3a.addc(vf3b);
    var v12sum = vf4a.addc(vf4b);

    var v10dif = vf2a.subc(vf2b);
    var v11dif = vf3a.subc(vf3b);
    var v12dif = vf4a.subc(vf4b);

    var v10prd = vf2a.mulc(vf2b);
    var v11prd = vf3a.mulc(vf3b);
    var v12prd = vf4a.mulc(vf4b);

    var v10qot = vf2a.divc(vf2b);
    var v11qot = vf3a.divc(vf3b);
    var v12qot = vf4a.divc(vf4b);

    try expect(v10sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v11sum.dist3d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist(vf4_sum) < F32_EPSILON);

    try expect(v10dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v11dif.dist3d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist(vf4_dif) < F32_EPSILON);

    try expect(v10prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v11prd.dist3d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist(vf4_prd) < F32_EPSILON);

    try expect(v10qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v11qot.dist3d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist(vf4_qot) < F32_EPSILON);

    v10sum = vf2a;
    v11sum = vf3a;
    v12sum = vf4a;
    v10sum.add(vf2b);
    v11sum.add(vf3b);
    v12sum.add(vf4b);

    v10dif = vf2a;
    v11dif = vf3a;
    v12dif = vf4a;
    v10dif.sub(vf2b);
    v11dif.sub(vf3b);
    v12dif.sub(vf4b);

    v10prd = vf2a;
    v11prd = vf3a;
    v12prd = vf4a;
    v10prd.mul(vf2b);
    v11prd.mul(vf3b);
    v12prd.mul(vf4b);

    v10qot = vf2a;
    v11qot = vf3a;
    v12qot = vf4a;
    v10qot.div(vf2b);
    v11qot.div(vf3b);
    v12qot.div(vf4b);

    try expect(v10sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v11sum.dist3d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist(vf4_sum) < F32_EPSILON);

    try expect(v10dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v11dif.dist3d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist(vf4_dif) < F32_EPSILON);

    try expect(v10prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v11prd.dist3d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist(vf4_prd) < F32_EPSILON);

    try expect(v10qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v11qot.dist3d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist(vf4_qot) < F32_EPSILON);

    v10sum = vf2a;
    v11sum = vf3a;
    v12sum = vf4a;
    v10sum.add2d(vf2b);
    v11sum.add2d(vf2b);
    v12sum.add2d(vf2b);

    v10dif = vf2a;
    v11dif = vf3a;
    v12dif = vf4a;
    v10dif.sub2d(vf2b);
    v11dif.sub2d(vf2b);
    v12dif.sub2d(vf2b);

    v10prd = vf2a;
    v11prd = vf3a;
    v12prd = vf4a;
    v10prd.mul2d(vf2b);
    v11prd.mul2d(vf2b);
    v12prd.mul2d(vf2b);

    v10qot = vf2a;
    v11qot = vf3a;
    v12qot = vf4a;
    v10qot.div2d(vf2b);
    v11qot.div2d(vf2b);
    v12qot.div2d(vf2b);

    try expect(v10sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v11sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist2d(vf4_sum) < F32_EPSILON);

    try expect(v10dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v11dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist2d(vf4_dif) < F32_EPSILON);

    try expect(v10prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v11prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist2d(vf4_prd) < F32_EPSILON);

    try expect(v10qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v11qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist2d(vf4_qot) < F32_EPSILON);

    v10sum = vf2a.add2dc(vf2b);
    v11sum = vf3a.add2dc(vf2b);
    v12sum = vf4a.add2dc(vf2b);

    v10dif = vf2a.sub2dc(vf2b);
    v11dif = vf3a.sub2dc(vf2b);
    v12dif = vf4a.sub2dc(vf2b);

    v10prd = vf2a.mul2dc(vf2b);
    v11prd = vf3a.mul2dc(vf2b);
    v12prd = vf4a.mul2dc(vf2b);

    v10qot = vf2a.div2dc(vf2b);
    v11qot = vf3a.div2dc(vf2b);
    v12qot = vf4a.div2dc(vf2b);

    try expect(v10sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v11sum.dist2d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist2d(vf4_sum) < F32_EPSILON);

    try expect(v10dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v11dif.dist2d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist2d(vf4_dif) < F32_EPSILON);

    try expect(v10prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v11prd.dist2d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist2d(vf4_prd) < F32_EPSILON);

    try expect(v10qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v11qot.dist2d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist2d(vf4_qot) < F32_EPSILON);

    v11sum = vf3a;
    v12sum = vf4a;
    v11sum.add3d(vf3b);
    v12sum.add3d(vf3b);

    v11dif = vf3a;
    v12dif = vf4a;
    v11dif.sub3d(vf3b);
    v12dif.sub3d(vf3b);

    v11prd = vf3a;
    v12prd = vf4a;
    v11prd.mul3d(vf3b);
    v12prd.mul3d(vf3b);

    v11qot = vf3a;
    v12qot = vf4a;
    v11qot.div3d(vf3b);
    v12qot.div3d(vf3b);

    try expect(v11sum.dist3d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist3d(vf4_sum) < F32_EPSILON);

    try expect(v11dif.dist3d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist3d(vf4_dif) < F32_EPSILON);

    try expect(v11prd.dist3d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist3d(vf4_prd) < F32_EPSILON);

    try expect(v11qot.dist3d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist3d(vf4_qot) < F32_EPSILON);

    v11sum = vf3a.add3dc(vf3b);
    v12sum = vf4a.add3dc(vf4b);

    v11dif = vf3a.sub3dc(vf3b);
    v12dif = vf4a.sub3dc(vf4b);

    v11prd = vf3a.mul3dc(vf3b);
    v12prd = vf4a.mul3dc(vf4b);

    v11qot = vf3a.div3dc(vf3b);
    v12qot = vf4a.div3dc(vf4b);

    try expect(v11sum.dist3d(vf4_sum) < F32_EPSILON);
    try expect(v12sum.dist3d(vf4_sum) < F32_EPSILON);

    try expect(v11dif.dist3d(vf4_dif) < F32_EPSILON);
    try expect(v12dif.dist3d(vf4_dif) < F32_EPSILON);

    try expect(v11prd.dist3d(vf4_prd) < F32_EPSILON);
    try expect(v12prd.dist3d(vf4_prd) < F32_EPSILON);

    try expect(v11qot.dist3d(vf4_qot) < F32_EPSILON);
    try expect(v12qot.dist3d(vf4_qot) < F32_EPSILON);

    const v13x: f32 = 0.1;
    const v13y: f32 = 0.2;
    const v13z: f32 = 0.3;
    const v13w: f32 = -14.9;
    const add_val: f32 = 1.339;
    const v13xsum = v13x + add_val;
    const v13ysum = v13y + add_val;
    const v13zsum = v13z + add_val;
    const v13wsum = v13w + add_val;
    var v13 = fVec4.init(.{v13x, v13y, v13z, v13w});
    v13.add(add_val);
    var v13sumcheck = fVec4.init(.{v13xsum, v13ysum, v13zsum, v13wsum});

    try expect(v13.dist(v13sumcheck) < F32_EPSILON);

    var v14 = fVec3.init(.{-2201.3, 10083.2, 15.0});
    var v15 = fVec3.init(.{3434.341, 9207.8888, -22.87});
    var dot_product = v14.val[0] * v15.val[0] + v14.val[1] * v15.val[1] + v14.val[2] * v15.val[2];

    try expect(@fabs(v14.dot(v15) - dot_product) < F32_EPSILON);

    var v16 = v14.cross(v15).normSafe();

    try expect(v14.nearlyOrthogonal(v16) and v15.nearlyOrthogonal(v16));
    try expect(v16.isNorm() and @fabs(v16.sizeSq() - 1.0) < F32_EPSILON);

    var v17 = v14.projectOnto(v15);

    try expect(v17.nearlyParallel(v15));
    try expect(!v16.nearlyParallel(v15));
    try expect(!v16.similarDirection(v15));

    var v18 = fVec2.init(.{1.001, 2.001});
    var v19 = fVec2.init(.{1.002, 2.002});

    try expect(!v18.nearlyEqual(v19));
}

// test "float precision" {
//     var f1: f16 = 0.0;
//     var f2: f16 = 0.0;

//     var i: usize = 0;
//     while(@fabs(f2 - f1) <= 0.1) : (i += 1) {
//         f1 = @intToFloat(f16, i) * 0.09;
//         f2 = @intToFloat(f16, i + 1) * 0.09;
//     }

//     print("\nfloat 16: {d}, {d}\n", .{f1, f2});

//     var f3: f32 = 0.0;
//     var f4: f32 = 0.0;

//     i = 0;
//     while(@fabs(f4 - f3) <= 1e-2) : (i += 1) {
//         f3 = @intToFloat(f32, i) * 9e-4;
//         f4 = @intToFloat(f32, i + 1) * 9e-4;
//     }

//     print("float 32: {d}, {d}\n", .{f3, f4});

//     const start: f64 = 1_000_000.0;
//     var f5: f64 = 0.0;
//     var f6: f64 = 0.0;

//     i = 0;
//     var broke: bool = false;
//     while(@fabs(f6 - f5) <= 1e-9) : (i += 1) {
//         f5 = start + @intToFloat(f64, i) * 9e-10;
//         f6 = start + @intToFloat(f64, i + 1) * 9e-10;
//         if (i > 100000000) {
//             broke = true;
//             break;
//         }
//     }

//     print("float 64: {d}, {d}, break: {}\n", .{f5, f6, broke});
// }