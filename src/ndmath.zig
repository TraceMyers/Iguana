
// TODO: is there a way to cast scalar types such that same-bitw vector types could do arithmetic with each other?
// TODO: ... or just make it easy to convert between them.
// TODO: test @setFloatMode() (a per-scope thing that allows ffast-math optimizations)

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------------- Vec
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const hVec2 = Vec(2, f16);
pub const hVec3 = Vec(3, f16);
pub const hVec4 = Vec(4, f16);

pub const fVec2 = Vec(2, f32);
pub const fVec3 = Vec(3, f32);
pub const fVec4 = Vec(4, f32);

pub const dVec2 = Vec(2, f64);
pub const dVec3 = Vec(3, f64);
pub const dVec4 = Vec(4, f64);

pub inline fn iVec2(comptime ScalarType: type) type {
    return switch (ScalarType) {
        i16, i32, i64 => return Vec(2, ScalarType),
        else => unreachable,
    };
}

pub inline fn iVec3(comptime ScalarType: type) type {
    return switch (ScalarType) {
        i16, i32, i64 => return Vec(3, ScalarType),
        else => unreachable,
    };
}

pub inline fn iVec4(comptime ScalarType: type) type {
    return switch (ScalarType) {
        i16, i32, i64 => return Vec(4, ScalarType),
        else => unreachable,
    };
}

pub inline fn uVec2(comptime ScalarType: type) type {
    return switch (ScalarType) {
        u16, u32, u64 => return Vec(2, ScalarType),
        else => unreachable,
    };
}

pub inline fn uVec3(comptime ScalarType: type) type {
    return switch (ScalarType) {
        u16, u32, u64 => return Vec(3, ScalarType),
        else => unreachable,
    };
}

pub inline fn uVec4(comptime ScalarType: type) type {
    return switch (ScalarType) {
        u16, u32, u64 => return Vec(4, ScalarType),
        else => unreachable,
    };
}

// ------------------------------------------------------------------------------------------------------- type function

pub fn Vec(comptime len: comptime_int, comptime ScalarType: type) type {

    return struct {

        const VecType = @This();

        parts: @Vector(len, ScalarType) = undefined,

    // ------------------------------------------------------------------------------------------------------------ init

        pub inline fn new() VecType {
            return VecType{ .parts = std.mem.zeroes([len]ScalarType) };
        }

        pub inline fn init(scalars: anytype) VecType {
            return VecType{ .parts = scalars };
        }

        pub inline fn fromScalar(scalar: ScalarType) VecType {
            return VecType{ .parts = @splat(len, scalar) };
        }

        // convert vector with scalar type Ta and len Na to a vector with scalar type Tb and len Nb, where Na
        // does not need to equal Nb. If Ta != Tb, then bitw(Tb) must be >= bitw(Ta)
        // example: var new_vec3 = fVec3.fromVec(some_vec4);
        pub inline fn fromVec(vec: anytype) VecType {
            if (len > @TypeOf(vec).length) {
                var self = VecType{ .parts = std.mem.zeroes([len]ScalarType) };
                inline for (0..@TypeOf(vec).length) |i| {
                    self.parts[i] = vec.parts[i];
                }
                return self;
            }
            else if (len < @TypeOf(vec).length or @TypeOf(vec) != VecType) {
                var self: VecType = undefined;
                inline for (0..len) |i| {
                    self.parts[i] = vec.parts[i];
                }
                return self;
            }
            else {
                return vec;
            }
        }

    // ------------------------------------------------------------------------------------------------------ conversion

        pub inline fn toIntVec(self: *const VecType, comptime IntType: type) Vec(len, IntType) {
            var int_vec: Vec(len, IntType) = undefined;
            inline for(0..len) |i| {
                int_vec.parts[i] = @floatToInt(IntType, self.parts[i]);
            }
            return int_vec;
        }

        pub inline fn toIntVecRounded(self: *const VecType, comptime IntType: type) Vec(len, IntType) {
            var int_vec: Vec(len, IntType) = undefined;
            inline for(0..len) |i| {
                int_vec.parts[i] = @floatToInt(IntType, @round(self.parts[i]) + epsilonLarge(ScalarType));
            }
            return int_vec;
        }

        pub inline fn toFloatVec(self: *const VecType, comptime FloatType: type) Vec(len, FloatType) {
            var float_vec: Vec(len, FloatType) = undefined;
            inline for(0..len) |i| {
                float_vec.parts[i] = @intToFloat(FloatType, self.parts[i]);
            }
            return float_vec;
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn set(self: *VecType, scalars: anytype) void {
            self.parts = scalars;
        }

        pub inline fn scalarFill(self: *VecType, scalar: ScalarType) void {
            self.parts = @splat(len, scalar);
        }

        pub inline fn copyAssymetric(self: *VecType, vec: anytype) void {
            const copy_len = @min(@TypeOf(vec).length, len);
            @memcpy(@ptrCast([*]ScalarType, &self.parts[0])[0..copy_len], @ptrCast([*]const ScalarType, &vec.parts[0])[0..copy_len]);
        }

    // ------------------------------------------------------------------------------------------------------ parts

        pub inline fn x(self: *const VecType) ScalarType {
            return self.parts[0];
        }

        pub inline fn y(self: *const VecType) ScalarType {
            return self.parts[1];
        }

        pub inline fn z(self: *const VecType) ScalarType {
            return self.parts[2];
        }

        pub inline fn w(self: *const VecType) ScalarType {
            return self.parts[3];
        }

        pub inline fn setX(self: *VecType, in_x: f32) void {
            self.parts[0] = in_x;
        }

        pub inline fn setY(self: *VecType, in_y: f32) void {
            self.parts[1] = in_y;
        }

        pub inline fn setZ(self: *VecType, in_z: f32) void {
            self.parts[2] = in_z;
        }

        pub inline fn setW(self: *VecType, in_w: f32) void {
            self.parts[3] = in_w;
        }

        pub inline fn part(self: *const VecType, idx: usize) ScalarType {
            return self.parts[idx];
        }

    // ----------------------------------------------------------------------------------------------- vector arithmetic

        // add two vectors of same or differing lens with copy for assignment
        pub inline fn addc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                return sAddc(self, other);
            }
            else {
                return switch(len) {
                    0, 1 => unreachable,
                    2 => vAddcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vAddcLoop(self, other);
                        }
                        else {
                            return VecType{ .parts = self.parts + other.parts };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lens inline
        pub inline fn add(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                sAdd(self, other);
            }
            else {
                switch(len) {
                    0, 1 => unreachable,
                    2 => vAddLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vAddLoop(self, other);
                        }
                        else {
                            self.parts += other.parts;
                        }
                    },
                }
            }
        }

        // subtract two vectors of same or differing lens with copy for assignment
        pub inline fn subc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                return sSubc(self, other);
            }
            else {
                return switch(len) {
                    0, 1 => unreachable,
                    2 => vSubcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vSubcLoop(self, other);
                        }
                        else {
                            return VecType{ .parts = self.parts - other.parts };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lens inline
        pub inline fn sub(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                sSub(self, other);
            }
            else {
                switch(len) {
                    0, 1 => unreachable,
                    2 => vSubLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vSubLoop(self, other);
                        }
                        else {
                            self.parts -= other.parts;
                        }
                    },
                }
            }
        }

        // add two vectors of same or differing lens with copy for assignment
        pub inline fn mulc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                return sMulc(self, other);
            }
            else {
                return switch(len) {
                    0, 1 => unreachable,
                    2 => vMulcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vMulcLoop(self, other);
                        }
                        else {
                            return VecType{ .parts = self.parts * other.parts };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lens inline
        pub inline fn mul(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                sMul(self, other);
            }
            else {
                switch(len) {
                    0, 1 => unreachable,
                    2 => vMulLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vMulLoop(self, other);
                        }
                        else {
                            self.parts *= other.parts;
                        }
                    },
                }
            }
        }

        // add two vectors of same or differing lens with copy for assignment
        pub inline fn divc(self: VecType, other: anytype) VecType {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                return sDivc(self, other);
            }
            else {
                return switch(len) {
                    0, 1 => unreachable,
                    2 => vDivcLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vDivcLoop(self, other);
                        }
                        else {
                            return VecType{ .parts = self.parts / other.parts };
                        }
                    },
                };
            }
        }

        // add two vectors of same or differing lens inline
        pub inline fn div(self: *VecType, other: anytype) void {
            if (@TypeOf(other) == ScalarType or @TypeOf(other) == comptime_float) {
                sDiv(self, other);
            }
            else {
                switch(len) {
                    0, 1 => unreachable,
                    2 => vDivLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vDivLoop(self, other);
                        }
                        else {
                            self.parts /= other.parts;
                        }
                    },
                }
            }
        }

    // ------------------------------------------------------------------------------- explicit len vector arithmetic

        pub inline fn add2dc(self: *VecType, other: anytype) VecType {
            if (len > 2) {
                var add_vec = self.*;
                add_vec.parts[0] += other.parts[0];
                add_vec.parts[1] += other.parts[1];
                return add_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] + other.parts[0], self.parts[1] + other.parts[1]} };
            }
        }

        pub inline fn add2d(self: *VecType, other: anytype) void {
            self.parts[0] += other.parts[0];
            self.parts[1] += other.parts[1];
        }

        pub inline fn sub2dc(self: *VecType, other: anytype) VecType {
            if (len > 2) {
                var sub_vec = self.*;
                sub_vec.parts[0] -= other.parts[0];
                sub_vec.parts[1] -= other.parts[1];
                return sub_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] - other.parts[0], self.parts[1] - other.parts[1]} };
            }
        }

        pub inline fn sub2d(self: *VecType, other: anytype) void {
            self.parts[0] -= other.parts[0];
            self.parts[1] -= other.parts[1];
        }

        pub inline fn mul2dc(self: *VecType, other: anytype) VecType {
            if (len > 2) {
                var mul_vec = self.*;
                mul_vec.parts[0] *= other.parts[0];
                mul_vec.parts[1] *= other.parts[1];
                return mul_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] * other.parts[0], self.parts[1] * other.parts[1]} };
            }
        }

        pub inline fn mul2d(self: *VecType, other: anytype) void {
            self.parts[0] *= other.parts[0];
            self.parts[1] *= other.parts[1];
        }

        pub inline fn div2dc(self: *VecType, other: anytype) VecType {
            if (len > 2) {
                var div_vec = self.*;
                div_vec.parts[0] /= other.parts[0];
                div_vec.parts[1] /= other.parts[1];
                return div_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] / other.parts[0], self.parts[1] / other.parts[1]} };
            }
        }

        pub inline fn div2d(self: *VecType, other: anytype) void {
            self.parts[0] /= other.parts[0];
            self.parts[1] /= other.parts[1];
        }

        pub inline fn add3dc(self: *VecType, other: anytype) VecType {
            if (len > 3) {
                var add_vec = self.*;
                add_vec.parts[0] += other.parts[0];
                add_vec.parts[1] += other.parts[1];
                add_vec.parts[2] += other.parts[2];
                return add_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] + other.parts[0], self.parts[1] + other.parts[1], self.parts[2] + other.parts[2]} };
            }
        }

        pub inline fn add3d(self: *VecType, other: anytype) void {
            self.parts[0] += other.parts[0];
            self.parts[1] += other.parts[1];
            self.parts[2] += other.parts[2];
        }

        pub inline fn sub3dc(self: *VecType, other: anytype) VecType {
            if (len > 3) {
                var sub_vec = self.*;
                sub_vec.parts[0] -= other.parts[0];
                sub_vec.parts[1] -= other.parts[1];
                sub_vec.parts[2] -= other.parts[2];
                return sub_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] - other.parts[0], self.parts[1] - other.parts[1], self.parts[2] - other.parts[2]} };
            }
        }

        pub inline fn sub3d(self: *VecType, other: anytype) void {
            self.parts[0] -= other.parts[0];
            self.parts[1] -= other.parts[1];
            self.parts[2] -= other.parts[2];
        }

        pub inline fn mul3dc(self: *VecType, other: anytype) VecType {
            if (len > 3) {
                var mul_vec = self.*;
                mul_vec.parts[0] *= other.parts[0];
                mul_vec.parts[1] *= other.parts[1];
                mul_vec.parts[2] *= other.parts[2];
                return mul_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] * other.parts[0], self.parts[1] * other.parts[1], self.parts[2] * other.parts[2]} };
            }
        }

        pub inline fn mul3d(self: *VecType, other: anytype) void {
            self.parts[0] *= other.parts[0];
            self.parts[1] *= other.parts[1];
            self.parts[2] *= other.parts[2];
        }

        pub inline fn div3dc(self: *VecType, other: anytype) VecType {
            if (len > 3) {
                var div_vec = self.*;
                div_vec.parts[0] /= other.parts[0];
                div_vec.parts[1] /= other.parts[1];
                div_vec.parts[2] /= other.parts[2];
                return div_vec;
            }
            else {
                return VecType{ .parts = .{self.parts[0] / other.parts[0], self.parts[1] / other.parts[1], self.parts[2] / other.parts[2]} };
            }
        }

        pub inline fn div3d(self: *VecType, other: anytype) void {
            self.parts[0] /= other.parts[0];
            self.parts[1] /= other.parts[1];
            self.parts[2] /= other.parts[2];
        }

    // -------------------------------------------------------------------------------------------------- linear algebra

        pub inline fn dot(self: VecType, other: VecType) ScalarType {
            return @reduce(.Add, self.parts * other.parts);
        }

        pub inline fn dot2d(self: VecType, other: anytype) ScalarType {
            return self.parts[0] * other.parts[0] + self.parts[1] * other.parts[1];
        }

        pub inline fn dot3d(self: VecType, other: anytype) ScalarType {
            return self.parts[0] * other.parts[0] + self.parts[1] * other.parts[1] + self.parts[2] * other.parts[2];
        }

        pub inline fn determinant2d(self: VecType, other: VecType) ScalarType {
            return self.parts[0] * other.parts[1] - other.parts[0] * self.parts[1];
        }

        pub inline fn cross(self: VecType, other: Vec(3, ScalarType)) Vec(3, ScalarType) {
            return Vec(3, ScalarType){ .parts = .{
                self.parts[1] * other.parts[2] - other.parts[1] * self.parts[2],
                other.parts[0] * self.parts[2] - other.parts[2] * self.parts[0],
                self.parts[0] * other.parts[1] - other.parts[0] * self.parts[1]
            }};
        }

    // ------------------------------------------------------------------------------------------------------------ size

        pub inline fn size(self: VecType) ScalarType {
            return @sqrt(@reduce(.Add, self.parts * self.parts));
        }

        pub inline fn sizeSq(self: VecType) ScalarType {
            return @reduce(.Add, self.parts * self.parts);
        }

        pub inline fn size2d(self: VecType) ScalarType {
            return @sqrt(self.parts[0] * self.parts[0] + self.parts[1] * self.parts[1]);
        }

        pub inline fn sizeSq2d(self: VecType) ScalarType {
            return self.parts[0] * self.parts[0] + self.parts[1] * self.parts[1];
        }

        pub inline fn size3d(self: VecType) ScalarType {
            return @sqrt(self.parts[0] * self.parts[0] + self.parts[1] * self.parts[1] + self.parts[2] * self.parts[2]);
        }

        pub inline fn sizeSq3d(self: VecType) ScalarType {
            return self.parts[0] * self.parts[0] + self.parts[1] * self.parts[1] + self.parts[2] * self.parts[2];
        }

    // -------------------------------------------------------------------------------------------------------- distance

        pub inline fn dist(self: VecType, other: VecType) ScalarType {
            const diff = self.parts - other.parts;
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq(self: VecType, other: VecType) ScalarType {
            const diff = self.parts - other.parts;
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist2d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.parts[0] - other.parts[0], self.parts[1] - other.parts[1]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq2d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.parts[0] - other.parts[0], self.parts[1] - other.parts[1]};
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist3d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.parts[0] - other.parts[0], self.parts[1] - other.parts[1], self.parts[2] - other.parts[2]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq3d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.parts[0] - other.parts[0], self.parts[1] - other.parts[1], self.parts[2] - other.parts[2]};
            return @reduce(.Add, diff * diff);
        }

    // ---------------------------------------------------------------------------------------------------------- normal

        pub inline fn normalSafe(self: VecType) VecType {
            const size_sq = self.sizeSq();
            if (size_sq <= epsilonSmall(ScalarType)) {
                return VecType.new();
            }
            return self.sMulc(1.0 / @sqrt(size_sq));
        }

        pub inline fn normalUnsafe(self: VecType) VecType {
            @setFloatMode(std.builtin.FloatMode.Optimized);
            const sz = @sqrt(@reduce(.Add, self.parts * self.parts));
            const inv_size_vec = @splat(len, 1.0 / sz);
            return VecType{ .parts = self.parts * inv_size_vec };
        }

        pub inline fn normalizeSafe(self: *VecType) void {
            const size_sq = self.sizeSq();
            if (size_sq <= epsilonSmall(ScalarType)) {
                self.parts = .{0.0, 0.0, 0.0};
            }
            self.sMul(1.0 / @sqrt(size_sq));
        }

        pub inline fn normalizeUnsafe(self: *VecType) void {
            @setFloatMode(std.builtin.FloatMode.Optimized);
            const vec_size = @sqrt(@reduce(.Add, self.parts * self.parts));
            const inv_size_vec = @splat(len, 1.0 / vec_size);
            self.parts *= inv_size_vec;
        }

        pub inline fn isNorm(self: VecType) bool {
            return @fabs(1.0 - self.sizeSq()) <= epsilonSmall(ScalarType);
        }

    // --------------------------------------------------------------------------------------------------------- max/min

        pub inline fn partMax(self: VecType) ScalarType {
            return @reduce(.Max, self.parts);
        }

        pub inline fn partMin(self: VecType) ScalarType {
            return @reduce(.Min, self.parts);
        }

    // -------------------------------------------------------------------------------------------------------- equality

        pub inline fn exactlyEqual(self: VecType, other: VecType) bool {
            inline for(0..len) |i| {
                if (self.parts[i] != other.parts[i]) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqual(self: VecType, other: VecType) bool {
            const diff = self.parts - other.parts;
            inline for(0..len) |i| {
                if (@fabs(diff[i]) > epsilonMedium(ScalarType)) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqualByTolerance(self: VecType, other: VecType, tolerance: ScalarType) bool {
            const diff = self.parts - other.parts;
            inline for(0..len) |i| {
                if (@fabs(diff[i]) > tolerance) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqualAutoTolerance(self: VecType, other: VecType) bool {
            const diff = self.parts - other.parts;
            inline for(0..len) |i| {
                const diff_parts = diff[i];
                if (@fabs(diff_parts) > epsilonAuto(self.parts[i], other.parts[i])) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyZero(self: VecType) bool {
            inline for(0..len) |i| {
                if (@fabs(self.parts[i]) > epsilonSmall(ScalarType)) {
                    return false;
                }
            }
            return true;
        }

    // ------------------------------------------------------------------------------------------------------------ sign

        pub inline fn abs(self: VecType) VecType {
            var abs_vec = self;
            inline for (0..len) |i| {
                abs_vec.parts[i] = @fabs(abs_vec.parts[i]);
            }
        }

        pub inline fn negate(self: VecType) VecType {
            var negate_vec = self;
            inline for (0..len) |i| {
                negate_vec.parts[i] = -negate_vec.parts[i];
            }
        }

    // ----------------------------------------------------------------------------------------------------------- clamp

        pub fn clampparts(self: VecType, min: ScalarType, max: ScalarType) VecType {
            var clamp_vec = self;
            inline for (0..len) |i| {
                clamp_vec.parts[i] = std.math.clamp(clamp_vec.parts[i], min, max);
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
            const self_norm = self.normalSafe();
            const other_norm = other.normalSafe();
            return self_norm.dot(other_norm) >= (1.0 - epsilonSmall(ScalarType));
        }

        pub inline fn nearlyParallelPrenorm(self_norm: VecType, other_norm: VecType) bool {
            return self_norm.dot(other_norm) >= (1.0 - VecType.epsilonSmall(ScalarType));
        }

        pub fn nearlyOrthogonal(self: VecType, other: VecType) bool {
            const self_norm = self.normalSafe();
            const other_norm = other.normalSafe();
            return self_norm.dot(other_norm) <= epsilonSmall(ScalarType);
        }

        pub inline fn nearlyOrthogonalPrenorm(self_norm: VecType, other_norm: VecType) bool {
            return self_norm.dot(other_norm) <= epsilonSmall(ScalarType);
        }

        pub inline fn similarDirection(self: VecType, other: VecType) bool {
            return self.dot(other) >= epsilonSmall(ScalarType);
        }

    // ------------------------------------------------------------------------------------------------------- constants

        pub const length = len;
        pub const zero = VecType.new();
        pub const posx = switch(len) {
            2 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{1.0,  0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{1, 0}),
                else => unreachable
            },
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{1.0, 0.0, 0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{1, 0, 0}),
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{1.0, 0.0, 0.0, 0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{1, 0, 0, 0}),
                else => unreachable
            },
            else => undefined
        };
        pub const posy = switch(len) {
            2 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0,  1.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 1}),
                else => unreachable
            },
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 1.0, 0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 1, 0}),
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 1.0, 0.0, 0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 1, 0, 0}),
                else => unreachable
            },
            else => undefined
        };
        pub const posz = switch(len) {
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, 1.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 0, 1}),
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, 1.0, 0.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 0, 1, 0}),
                else => unreachable
            },
            else => undefined
        };
        pub const negx = switch(len) {
            2 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{-1.0,  0.0}),
                i16, i32, i64 => VecType.init(.{-1, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{-1.0, 0.0, 0.0}),
                i16, i32, i64 => VecType.init(.{-1, 0, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{-1.0, 0.0, 0.0, 0.0}),
                i16, i32, i64 => VecType.init(.{-1, 0, 0, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            else => undefined
        };
        pub const negy = switch(len) {
            2 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0,  -1.0}),
                i16, i32, i64 => VecType.init(.{0, -1}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, -1.0, 0.0}),
                i16, i32, i64 => VecType.init(.{0, -1, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, -1.0, 0.0, 0.0}),
                i16, i32, i64 => VecType.init(.{0, -1, 0, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            else => undefined
        };
        pub const negz = switch(len) {
            3 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, -1.0}),
                i16, i32, i64 => VecType.init(.{0, 0, -1}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, -1.0, 0.0}),
                i16, i32, i64 => VecType.init(.{0, 0, -1, 0}),
                u16, u32, u64 => undefined,
                else => unreachable
            },
            else => undefined
        };
        pub const posw = switch(len) {
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, 0.0, 1.0}),
                i16, i32, i64, u16, u32, u64 => VecType.init(.{0, 0, 0, 1}),
                else => unreachable,
            },
            else => undefined,
        };
        pub const negw = switch(len) {
            4 => switch(ScalarType) {
                f16, f32, f64 => VecType.init(.{0.0, 0.0, 0.0 , -1.0}),
                i16, i32, i64 => VecType.init(.{0, 0, 0, -1}),
                u16, u32, u64 => undefined,
                else => unreachable,
            },
            else => undefined,
        };
        pub const front = posy;
        pub const back = negy;
        pub const right = posx;
        pub const left = negx;
        pub const up = posz;
        pub const down = negz;

    // -------------------------------------------------------------------------------------------------------- internal

        inline fn sAddc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(len, other);
            return VecType{ .parts = self.parts + add_vec };
        }

        inline fn sAdd(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(len, other);
            self.parts += add_vec;
        }

        inline fn sSubc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(len, other);
            return VecType{ .parts = self.parts - add_vec };
        }

        inline fn sSub(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(len, other);
            self.parts -= add_vec;
        }

        inline fn sMulc(self: VecType, other: ScalarType) VecType {
            const add_vec = @splat(len, other);
            return VecType{ .parts = self.parts * add_vec };
        }

        inline fn sMul(self: *VecType, other: ScalarType) void {
            const add_vec = @splat(len, other);
            self.parts *= add_vec;
        }

        inline fn sDivc(self: VecType, other: ScalarType) VecType {
            const mul_scalar = 1.0 / other;
            const mul_vec = @splat(len, mul_scalar);
            return self.parts * mul_vec;
        }

        inline fn sDiv(self: *VecType, other: ScalarType) void {
            const mul_scalar = 1.0 / other;
            const mul_vec = @splat(len, mul_scalar);
            self.parts *= mul_vec;
        }

        inline fn vAddcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                add_vec.parts[i] += vec_b.parts[i];
            }
            return add_vec;
        }

        inline fn vAddLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                vec_a.parts[i] += vec_b.parts[i];
            }
        }

        inline fn vSubcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                add_vec.parts[i] -= vec_b.parts[i];
            }
            return add_vec;
        }

        inline fn vSubLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                vec_a.parts[i] -= vec_b.parts[i];
            }
        }

        inline fn vMulcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                add_vec.parts[i] *= vec_b.parts[i];
            }
            return add_vec;
        }


        inline fn vMulLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                vec_a.parts[i] *= vec_b.parts[i];
            }
        }


        inline fn vDivcLoop(vec_a: VecType, vec_b: anytype) VecType {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                add_vec.parts[i] /= vec_b.parts[i];
            }
            return add_vec;
        }


        inline fn vDivLoop(vec_a: *VecType, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).length, len)) |i| {
                vec_a.parts[i] /= vec_b.parts[i];
            }
        }

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------------- Ray
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const hRay = Ray(f16);
pub const fRay = Ray(f32);
pub const dRay = Ray(f64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn Ray(comptime ScalarType: type) type {

    return struct {

        const RayType = @This();

        origin: Vec(3, ScalarType) = undefined,
        normal: Vec(3, ScalarType) = undefined,

        pub inline fn new() RayType {
            return RayType{
                .origin = Vec(3, ScalarType).new(),
                .normal = Vec(3, ScalarType).init(.{1.0, 0.0, 0.0})
            };
        }

        pub inline fn fromNorm(in_normal: Vec(3, ScalarType)) !RayType {
            if (!in_normal.isNorm()) {
                return NDMathError.RayNormalNotNormalized;
            }
            return RayType {
                .origin = Vec(3, ScalarType).new(),
                .normal = in_normal
            };
        }

        pub inline fn fromparts(in_origin: Vec(3, ScalarType), in_normal: Vec(3, ScalarType)) !RayType {
            if (!in_normal.isNorm()) {
                return NDMathError.RayNormalNotNormalized;
            }
            return RayType {
                .origin = in_origin,
                .normal = in_normal
            };
        }

        pub inline fn negateNormal(self: *RayType) void {
            self.normal = self.normal.negate();
        }

        pub inline fn normpart(self: *const RayType, idx: usize) ScalarType {
            return self.normal[idx];
        }

        pub inline fn originpart(self: *const RayType, idx: usize) ScalarType {
            return self.normal[idx];
        }

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- Plane
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const hPlane = Plane(f16);
pub const fPlane = Plane(f32);
pub const dPlane = Plane(f64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn Plane(comptime ScalarType: type) type {

    return struct {
        
        const PlaneType = @This();

        normal: Vec(3, ScalarType) = undefined,
        odist: ScalarType = undefined,

        pub inline fn new() PlaneType {
            return PlaneType{
                .normal = Vec(3, ScalarType).init(.{1.0, 0.0, 0.0}),
                .odist = 0.0
            };
        }

        pub inline fn fromNormal(norm: Vec(3, ScalarType)) !PlaneType {
            if (!norm.isNorm()) {
                return NDMathError.PlaneNormalNotNormalized;
            }
            return PlaneType {
                .normal = norm,
                .odist = 0.0
            };
        }

        pub inline fn fromparts(norm: Vec(3, ScalarType), origin_distance: ScalarType) !PlaneType {
            if (!norm.isNorm()) {
                return NDMathError.PlaneNormalNotNormalized;
            }
            return PlaneType {
                .normal = norm,
                .odist = origin_distance
            };
        }

    // ------------------------------------------------------------------------------------------------------ parts

        pub inline fn setNormal(self: *PlaneType, normal: Vec(3, ScalarType)) void {
            if (!normal.isNorm()) {
                return NDMathError.PlaneNormalNotNormalized;
            }
            self.normal = normal;
        }

        pub inline fn setOriginDistance(self: *PlaneType, origin_distance: ScalarType) void {
            self.odist = origin_distance;
        }

        pub inline fn setparts(self: *PlaneType, norm: Vec(3, ScalarType), origin_distance: ScalarType) !void {
            if (!norm.isNorm()) {
                return NDMathError.PlaneNormalNotNormalized;
            }
            self.normal = norm;
            self.odist = origin_distance;
        }

        pub inline fn normalX(self: *const PlaneType) f32 {
            return self.normal.parts[0];
        }

        pub inline fn normalY(self: *const PlaneType) ScalarType {
            return self.normal.parts[1];
        }

        pub inline fn normalZ(self: *const PlaneType) ScalarType {
            return self.normal.parts[2];
        }

        pub inline fn normalpart(self: *const PlaneType, idx: usize) ScalarType {
            return self.normal[idx];
        }

        pub inline fn originDist(self: *const PlaneType) ScalarType {
            return self.odist;
        }

        pub inline fn negateNormal(self: *const PlaneType) void {
            self.normal = self.normal.negate();
        }

    // -------------------------------------------------------------------------------------------------- linear algebra

        pub inline fn pNormalDot(self: PlaneType, other: PlaneType) ScalarType {
            return self.normal.dot(other.normal);
        }

        pub inline fn vNormalDot(self: PlaneType, other: Vec(3, ScalarType)) ScalarType {
            return self.normal.dot(other);
        }

        pub inline fn pNormalCross(self: PlaneType, other: PlaneType) Vec(3, ScalarType) {
            return self.normal.cross(other.normal);
        }

        pub inline fn vNormalCross(self: PlaneType, other: Vec(3, ScalarType)) Vec(3, ScalarType) {
            return self.normal.cross(other);
        }

    // ---------------------------------------------------------------------------------------------------- trigonometry

        pub inline fn pNormalAngle(self: PlaneType, other: PlaneType) ScalarType {
            return self.normal.anglePrenorm(other.normal);
        }

        pub inline fn pNormalCosAngle(self: PlaneType, other: PlaneType) ScalarType {
            return self.normal.cosAnglePrenorm(other.normal);
        }

        pub inline fn vNormalAngle(self: PlaneType, other: Vec(3, ScalarType)) ScalarType {
            return self.normal.angle(other);
        }

        pub inline fn vNormalCosAngle(self: PlaneType, other: Vec(3, ScalarType)) ScalarType {
            return self.normal.cosAngle(other);
        }

        pub inline fn vNormalAnglePrenorm(self: PlaneType, norm: Vec(3, ScalarType)) ScalarType {
            return self.normal.anglePrenorm(norm);
        }

        pub inline fn vNormalCosAnglePrenorm(self: PlaneType, norm: Vec(3, ScalarType)) ScalarType {
            return self.normal.cosAnglePrenorm(norm);
        }

        // -------------------------------------------------------------------------------------------------------- equality

        pub inline fn exactlyEqual(self: PlaneType, other: PlaneType) bool {
            return self.normal.exactlyEqual(other.normal) and self.odist == other.odist;
        }

        pub inline fn nearlyEqual(self: PlaneType, other: PlaneType) bool {
            return self.normal.nearlyEqual(other.normal) and @fabs(self.odist - other.odist) <= epsilonMedium(ScalarType);
        }

        pub inline fn exactlyEqualNorm(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.exactlyEqual(other);
        }

        pub inline fn nearlyEqualNorm(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.nearlyEqual(other);
        }

    // ------------------------------------------------------------------------------------------------------- direction

        pub inline fn pNearlyParallel(self: PlaneType, other: PlaneType) bool {
            return self.normal.nearlyParallelPrenorm(other.normal);
        }

        pub inline fn pNearlyOrthogonal(self: PlaneType, other: PlaneType) bool {
            return self.normal.nearlyOrthogonalPrenorm(other.normal);
        }

        pub inline fn pSimilarDirection(self: PlaneType, other: PlaneType) bool {
            return self.normal.similarDirection(other.normal);
        }

        pub inline fn vNearlyParallel(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.nearlyParallel(other);
        }

        pub inline fn vNearlyOrthogonal(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.nearlyOrthogonal(other);
        }

        pub inline fn vSimilarDirection(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.similarDirection(other);
        }

        pub inline fn vNearlyParallelPrenorm(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.nearlyParallelPrenorm(other);
        }

        pub inline fn vNearlyOrthogonalPrenorm(self: PlaneType, other: Vec(3, ScalarType)) bool {
            return self.normal.nearlyOrthogonalPrenorm(other);
        }

    // ---------------------------------------------------------------------------------------------- vector interaction

        pub inline fn pointDistSigned(self: PlaneType, point: Vec(3, ScalarType)) ScalarType {
            return -(self.normal.dot(point) - self.odist);
        }

        pub inline fn pointDist(self: PlaneType, point: Vec(3, ScalarType)) ScalarType {
            return @fabs(self.pointDistSigned(point));
        }

        pub inline fn pointDiff(self: PlaneType, point: Vec(3, ScalarType)) ScalarType {
            const dist = self.pointDistSigned(point);
            return Vec(3, ScalarType).init(.{
                self.normal.parts[0] * dist,
                self.normal.parts[1] * dist,
                self.normal.parts[2] * dist,
            });
        }

        pub inline fn pointProject(self: PlaneType, point: Vec(3, ScalarType)) ScalarType {
            const dist = self.pointDistSigned(point);
            return Vec(3, ScalarType).init(.{
                point.parts[0] + self.normal.parts[0] * dist,
                point.parts[1] + self.normal.parts[1] * dist,
                point.parts[2] + self.normal.parts[2] * dist,
            });
        }

        pub inline fn pointMirror(self: PlaneType, point: Vec(3, ScalarType)) ScalarType {
            const double_diff = self.pointDiff(point).sMulc(2.0);
            return point.vAddc(double_diff);
        }

        pub inline fn reflect(self: PlaneType, vec: Vec(3, ScalarType)) ScalarType {
            const reflect_dist = self.vNormalDot(vec) * -2.0;
            const reflect_diff = self.normal.sMulc(reflect_dist);
            return vec.vAddc(reflect_diff);
        }

        pub fn rayIntersect(self: PlaneType, ray: fRay, distance: *ScalarType) ?Vec(3, ScalarType) {
            const normal_direction_product = self.vNormalDot(ray.normal);
            if (normal_direction_product > -epsilonMedium(ScalarType)) {
                return null;
            }

            const normal_origin_product = self.vNormalDot(ray.origin);
            distance.* = normal_origin_product - self.odist;

            if (distance.* < 0.0) {
                return null;
            }

            distance.* = distance.* / -normal_direction_product;
            const diff = ray.normal.sMulc(distance.*);
            return ray.origin.vAddc(diff);
        }

        pub fn rayIntersectEitherFace(self: PlaneType, ray: fRay, distance: *ScalarType) ?Vec(3, ScalarType) {
            const normal_origin_product = self.vNormalDot(ray.origin);
            const normal_direction_product = self.vNormalDot(ray.normal);
            distance.* = (normal_origin_product - self.odist) / -normal_direction_product;

            if (distance.* < 0.0) {
                return null;
            }

            const diff = ray.normal.sMulc(distance.*);
            return ray.origin.vAddc(diff);
        }

    // ------------------------------------------------------------------------------------------------------- constants

        pub const length = 4;

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------- Quaternion
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const hQuat = Quaternion(f16);
pub const fQuat = Quaternion(f32);
pub const dQuat = Quaternion(f64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn Quaternion(comptime ScalarType: type) type {

    return struct {

        const QuaternionType = @This();
        
        parts: @Vector(4, ScalarType) = undefined,

        pub inline fn new() QuaternionType {
            return QuaternionType{ .parts = .{0.0, 0.0, 0.0, 1.0} };
        }

        pub inline fn init(scalars: [4]ScalarType) QuaternionType {
            return QuaternionType{ .parts = scalars };
        }

        pub inline fn fromScalar(scalar: ScalarType) QuaternionType {
            return QuaternionType{ .parts = @splat(4, scalar) };
        }

        pub inline fn fromVec(vec: anytype) QuaternionType {
            return QuaternionType{ .parts = vec.parts };
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn set(self: *QuaternionType, scalars: anytype) void {
            self.parts = scalars;
        }

        pub inline fn setFromScalar(self: *QuaternionType, scalar: ScalarType) void {
            self.parts = @splat(4, scalar);
        }

        pub inline fn setFromVec(self: *QuaternionType, vec: Vec(4, ScalarType)) void {
            self.parts = vec.parts;
        }
        
        pub inline fn setFromVecXYZ(self: *QuaternionType, vec: Vec(3, ScalarType)) void {
            self.parts[0] = vec.parts[0];
            self.parts[1] = vec.parts[1];
            self.parts[2] = vec.parts[2];
        }

    // ----------------------------------------------------------------------------------------------------------- parts

        pub inline fn x(self: *const QuaternionType) ScalarType {
            return self.parts[0];
        }

        pub inline fn y(self: *const QuaternionType) ScalarType {
            return self.parts[1];
        }

        pub inline fn z(self: *const QuaternionType) ScalarType {
            return self.parts[2];
        }

        pub inline fn w(self: *const QuaternionType) ScalarType {
            return self.parts[3];
        }

        pub inline fn setX(self: *QuaternionType, in_x: f32) void {
            self.parts[0] = in_x;
        }

        pub inline fn setY(self: *QuaternionType, in_y: f32) void {
            self.parts[1] = in_y;
        }

        pub inline fn setZ(self: *QuaternionType, in_z: f32) void {
            self.parts[2] = in_z;
        }

        pub inline fn setW(self: *QuaternionType, in_w: f32) void {
            self.parts[3] = in_w;
        }

        pub inline fn negateXYZ(self: *QuaternionType) void {
            self.parts[0] = -self.parts[0];
            self.parts[1] = -self.parts[1];
            self.parts[2] = -self.parts[2];
        }

        pub inline fn size(self: QuaternionType) ScalarType {
            return @sqrt(@reduce(.Add, self.parts * self.parts));
        }

        pub inline fn sizeSq(self: QuaternionType) ScalarType {
            return @reduce(.Add, self.parts * self.parts);
        }

        pub inline fn normalizeSafe(self: *QuaternionType) void {
            const size_sq = self.sizeSq();
            if (size_sq <= epsilonSmall(ScalarType)) {
                self.parts = .{0.0, 0.0, 0.0, 0.0};
            }
            self.parts *= @splat(4, 1.0 / @sqrt(size_sq));
        }

        pub inline fn normalizeUnsafe(self: *QuaternionType) void {
            @setFloatMode(std.builtin.FloatMode.Optimized);
            const quat_size = @sqrt(@reduce(.Add, self.parts * self.parts));
            const inv_size_vec = @splat(4, 1.0 / quat_size);
            self.parts *= inv_size_vec;
        }

        pub fn mul(self: *QuaternionType, other: QuaternionType) void {
            const neg_vec: @Vector(4, f32) = .{1.0, 1.0, 1.0, -1.0};
            const wsplat = @splat(4, self.parts[3]) * other.parts;

            const a_shuf1 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){0, 1, 2, 0}) * neg_vec;
            const b_shuf1 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){3, 3, 3, 0});
            const result_1 = @mulAdd(@Vector(4, f32), a_shuf1, b_shuf1, wsplat);

            const a_shuf2 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){1, 2, 0, 1}) * neg_vec;
            const b_shuf2 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){2, 0, 1, 1});
            const result_2 = @mulAdd(@Vector(4, f32), a_shuf2, b_shuf2, result_1);

            const a_shuf3 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){2, 0, 1, 2});
            const b_shuf3 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){1, 2, 0, 2});
            const result_3 = a_shuf3 * b_shuf3;

            self.parts = result_2 - result_3;
        }

        pub fn mulc(self: *const QuaternionType, other: QuaternionType) QuaternionType {
            const neg_vec: @Vector(4, f32) = .{1.0, 1.0, 1.0, -1.0};
            const wsplat = @splat(4, self.parts[3]) * other.parts;

            const a_shuf1 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){0, 1, 2, 0}) * neg_vec;
            const b_shuf1 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){3, 3, 3, 0});
            const result_1 = @mulAdd(@Vector(4, f32), a_shuf1, b_shuf1, wsplat);

            const a_shuf2 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){1, 2, 0, 1}) * neg_vec;
            const b_shuf2 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){2, 0, 1, 1});
            const result_2 = @mulAdd(@Vector(4, f32), a_shuf2, b_shuf2, result_1);

            const a_shuf3 = @shuffle(f32, self.parts, self.parts, @Vector(4, i32){2, 0, 1, 2});
            const b_shuf3 = @shuffle(f32, other.parts, other.parts, @Vector(4, i32){1, 2, 0, 2});
            const result_3 = a_shuf3 * b_shuf3;

            return QuaternionType.init(result_2 - result_3);
        }

    // ------------------------------------------------------------------------------------------------------- constants

        pub const zero = QuaternionType.init(.{0.0, 0.0, 0.0, 0.0});
        pub const identity = QuaternionType.new();
        pub const length = 4;

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------- Square Matrix
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub fn SquareMatrix(comptime size: u32, comptime ScalarType: type) type {
    return Matrix(size, size, ScalarType);
}

pub const hMat2x2 = SquareMatrix(2, f16);
pub const hMat3x3 = SquareMatrix(3, f16);
pub const hMat4x4 = SquareMatrix(4, f16);
pub const hMat5x5 = SquareMatrix(5, f16);

pub const fMat2x2 = SquareMatrix(2, f32);
pub const fMat3x3 = SquareMatrix(3, f32);
pub const fMat4x4 = SquareMatrix(4, f32);
pub const fMat5x5 = SquareMatrix(5, f32);

pub const dMat2x2 = SquareMatrix(2, f64);
pub const dMat3x3 = SquareMatrix(3, f64);
pub const dMat4x4 = SquareMatrix(4, f64);
pub const dMat5x5 = SquareMatrix(5, f64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn Matrix(comptime h: u32, comptime w: u32, comptime ScalarType: type) type {

    return struct {

        const MatrixType = @This();

        parts: [h][w]ScalarType = undefined,

        pub inline fn new() MatrixType {
            return MatrixType{.parts = std.mem.zeroes(MatrixType)};
        }

        pub inline fn fromScalar(scalar: ScalarType) MatrixType {
            var self = std.mem.zeroes(MatrixType);
            inline for (0..min_dimension) |i| {
                self.parts[i][i] = scalar;
            }
            return self;
        }

        // copy this vector into the diagonal of a new matrix. can be used to make a scaling matrix if 
        // size == vec.len + 1. remaining diagonal entries are identity.
        pub fn fromVecOnDiag(vec: anytype) MatrixType {
            const vec_len = @TypeOf(vec).length;
            std.debug.assert(min_dimension >= vec_len);

            var self = MatrixType.new();
            inline for(0..vec_len) |i| {
                self.parts[i][i] = vec.parts[i];
            }
            inline for(vec_len..min_dimension) |i| {
                self.parts[i][i] = 1.0;
            }
            return self;
        }

        // copy this vector into the right column of a new matrix. can be used to make a translation matrix if
        // size == vec.len + 1. diagonal entries (except potentially the bottom right if overwritten) are identity.
        pub fn fromVecOnRightCol(vec: anytype) MatrixType {
            const vec_len = @TypeOf(vec).length;
            std.debug.assert(min_dimension >= vec_len);
            var self = MatrixType.identity();
            inline for(0..vec_len) |i| {
                self.parts[i][width - 1] = vec.parts[i];
            }
            return self;
        }

    // ------------------------------------------------------------------------------------------------------- constants

        pub const height = h;
        pub const width = w;
        pub const min_dimension = @min(w, h);
        pub const zero = MatrixType.new();
        pub const identity = blk: {
            var mat = std.mem.zeroes(MatrixType);
            for (0..@min(w, h)) |i| {
                mat.parts[i][i] = 1.0;
            }
            break :blk mat;
        };

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const getScopeTimerID = benchmark.getScopeTimerID;
const Prng = std.rand.DefaultPrng;
const flt = @import("float.zig");
const epsilonLarge = flt.epsilonLarge;
const epsilonMedium = flt.epsilonMedium;
const epsilonSmall = flt.epsilonSmall;
const epsilonAuto = flt.epsilonAuto;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- test
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// need to add -lc arg for testing to link libc

test "SquareMatrix" {
    var m1 = fMat3x3.identity;
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
    
    try expect(vf3zero.dist(v1) < epsilonSmall(f32));
    try expect(@fabs(v2.x()) < epsilonSmall(f32) and @fabs(v2.y() - 1.0) < epsilonSmall(f32) and @fabs(v2.z() - 2.0) < epsilonSmall(f32));
    try expect(@fabs(v3.x() - 3.0001) < epsilonSmall(f32) and @fabs(v3.y() - 3.0001) < epsilonSmall(f32) and @fabs(v3.z() - 3.0001) < epsilonSmall(f32));
    try expect(v4.dist(v2) < epsilonSmall(f32) and v4.distSq(v2) < epsilonSmall(f32));
    try expect(v5.dist3d(v2) < epsilonSmall(f32) and v5.distSq3d(v2) < epsilonSmall(f32) and @fabs(v5.w()) < epsilonSmall(f32));
    try expect(v6.dist2d(v2) < epsilonSmall(f32) and v6.distSq2d(v2) < epsilonSmall(f32));

    var v7 = v3.toIntVec(i32);
    var v8 = v3.toIntVec(u32);
    var v9: dVec3 = v7.toFloatVec(f64);
    var v9a = dVec3.fromVec(v3);

    try expect(v7.x() == 3 and v7.y() == 3 and v7.z() == 3);
    try expect(v8.x() == 3 and v8.y() == 3 and v8.z() == 3);
    try expect(@fabs(v9.x() - 3.0) < epsilonSmall(f32) and @fabs(v9.y() - 3.0) < epsilonSmall(f32) and @fabs(v9.z() - 3.0) < epsilonSmall(f32));
    try expect(@fabs(v9a.x() - 3.0001) < epsilonSmall(f32) and @fabs(v9a.y() - 3.0001) < epsilonSmall(f32) and @fabs(v9a.z() - 3.0001) < epsilonSmall(f32));

    v3.set(.{ 4.001, 4.001, 5.001 });
    v6.scalarFill(2.58);

    try expect(@fabs(v3.x() - 4.001) < epsilonSmall(f32) and @fabs(v3.y() - 4.001) < epsilonSmall(f32) and @fabs(v3.z() - 5.001) < epsilonSmall(f32));
    try expect(@fabs(v6.x() - 2.58) < epsilonSmall(f32) and @fabs(v6.y() - 2.58) < epsilonSmall(f32));

    v6.copyAssymetric(v3);

    try expect(v6.dist2d(v3) < epsilonSmall(f32));

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

    try expect(v10sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v11sum.dist3d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist(vf4_sum) < epsilonMedium(f32));

    try expect(v10dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v11dif.dist3d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist(vf4_dif) < epsilonMedium(f32));

    try expect(v10prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v11prd.dist3d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist(vf4_prd) < epsilonMedium(f32));

    try expect(v10qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v11qot.dist3d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist(vf4_qot) < epsilonMedium(f32));

    try expect(v10sum.nearlyEqualAutoTolerance(fVec2.fromVec(vf4_sum)));
    try expect(v10dif.nearlyEqualAutoTolerance(fVec2.fromVec(vf4_dif)));
    try expect(v10prd.nearlyEqualAutoTolerance(fVec2.fromVec(vf4_prd)));
    try expect(v10qot.nearlyEqualAutoTolerance(fVec2.fromVec(vf4_qot)));

    try expect(v11sum.nearlyEqualAutoTolerance(fVec3.fromVec(vf4_sum)));
    try expect(v11dif.nearlyEqualAutoTolerance(fVec3.fromVec(vf4_dif)));
    try expect(v11prd.nearlyEqualAutoTolerance(fVec3.fromVec(vf4_prd)));
    try expect(v11qot.nearlyEqualAutoTolerance(fVec3.fromVec(vf4_qot)));

    try expect(v12sum.nearlyEqualAutoTolerance(vf4_sum));
    try expect(v12dif.nearlyEqualAutoTolerance(vf4_dif));
    try expect(v12prd.nearlyEqualAutoTolerance(vf4_prd));
    try expect(v12qot.nearlyEqualAutoTolerance(vf4_qot));

    try expect(v12sum.nearlyEqual(vf4_sum));
    try expect(v12dif.nearlyEqual(vf4_dif));
    try expect(v12prd.nearlyEqual(vf4_prd));
    try expect(v12qot.nearlyEqual(vf4_qot));

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

    try expect(v10sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v11sum.dist3d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist(vf4_sum) < epsilonMedium(f32));

    try expect(v10dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v11dif.dist3d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist(vf4_dif) < epsilonMedium(f32));

    try expect(v10prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v11prd.dist3d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist(vf4_prd) < epsilonMedium(f32));

    try expect(v10qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v11qot.dist3d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist(vf4_qot) < epsilonMedium(f32));

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

    try expect(v10sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v11sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist2d(vf4_sum) < epsilonMedium(f32));

    try expect(v10dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v11dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist2d(vf4_dif) < epsilonMedium(f32));

    try expect(v10prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v11prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist2d(vf4_prd) < epsilonMedium(f32));

    try expect(v10qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v11qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist2d(vf4_qot) < epsilonMedium(f32));

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

    try expect(v10sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v11sum.dist2d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist2d(vf4_sum) < epsilonMedium(f32));

    try expect(v10dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v11dif.dist2d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist2d(vf4_dif) < epsilonMedium(f32));

    try expect(v10prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v11prd.dist2d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist2d(vf4_prd) < epsilonMedium(f32));

    try expect(v10qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v11qot.dist2d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist2d(vf4_qot) < epsilonMedium(f32));

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

    try expect(v11sum.dist3d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist3d(vf4_sum) < epsilonMedium(f32));

    try expect(v11dif.dist3d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist3d(vf4_dif) < epsilonMedium(f32));

    try expect(v11prd.dist3d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist3d(vf4_prd) < epsilonMedium(f32));

    try expect(v11qot.dist3d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist3d(vf4_qot) < epsilonMedium(f32));

    v11sum = vf3a.add3dc(vf3b);
    v12sum = vf4a.add3dc(vf4b);

    v11dif = vf3a.sub3dc(vf3b);
    v12dif = vf4a.sub3dc(vf4b);

    v11prd = vf3a.mul3dc(vf3b);
    v12prd = vf4a.mul3dc(vf4b);

    v11qot = vf3a.div3dc(vf3b);
    v12qot = vf4a.div3dc(vf4b);

    try expect(v11sum.dist3d(vf4_sum) < epsilonMedium(f32));
    try expect(v12sum.dist3d(vf4_sum) < epsilonMedium(f32));

    try expect(v11dif.dist3d(vf4_dif) < epsilonMedium(f32));
    try expect(v12dif.dist3d(vf4_dif) < epsilonMedium(f32));

    try expect(v11prd.dist3d(vf4_prd) < epsilonMedium(f32));
    try expect(v12prd.dist3d(vf4_prd) < epsilonMedium(f32));

    try expect(v11qot.dist3d(vf4_qot) < epsilonMedium(f32));
    try expect(v12qot.dist3d(vf4_qot) < epsilonMedium(f32));

    const v13x: f32 = 0.1;
    const v13y: f32 = 0.2;
    const v13z: f32 = 0.3;
    const v13w: f32 = -14.9;
    const add_parts: f32 = 1.339;
    const v13xsum = v13x + add_parts;
    const v13ysum = v13y + add_parts;
    const v13zsum = v13z + add_parts;
    const v13wsum = v13w + add_parts;
    var v13 = fVec4.init(.{v13x, v13y, v13z, v13w});
    v13.add(add_parts);
    var v13sumcheck = fVec4.init(.{v13xsum, v13ysum, v13zsum, v13wsum});

    try expect(v13.dist(v13sumcheck) < epsilonSmall(f32));

    var v14 = fVec3.init(.{-2201.3, 10083.2, 15.0});
    var v15 = fVec3.init(.{3434.341, 9207.8888, -22.87});
    var dot_product = v14.parts[0] * v15.parts[0] + v14.parts[1] * v15.parts[1] + v14.parts[2] * v15.parts[2];

    try expect(@fabs(v14.dot(v15) - dot_product) < epsilonSmall(f32));

    var v16 = v14.cross(v15).normalSafe();

    try expect(v14.nearlyOrthogonal(v16) and v15.nearlyOrthogonal(v16));
    try expect(v16.isNorm() and @fabs(v16.sizeSq() - 1.0) < epsilonSmall(f32));

    var v17 = v14.projectOnto(v15);

    try expect(v17.nearlyParallel(v15));
    try expect(!v16.nearlyParallel(v15));
    try expect(!v16.similarDirection(v15));

    var v18 = fVec2.init(.{1.01, 2.01});
    var v19 = fVec2.init(.{1.02, 2.02});

    try expect(!v18.nearlyEqualAutoTolerance(v19));

    var v20 = fVec3.zero;
    try expect(v20.nearlyZero());

    var v21 = fVec2.posx;
    var v22 = fVec3.posx;
    var v23 = fVec4.posx;
    try expect (v21.isNorm());
    try expect (v22.isNorm());
    try expect (v23.isNorm());
}

pub fn testQuaternion() void {
    var q1 = fQuat.init(.{0.0, 1.0, 2.0, 3.0});
    var q2 = fQuat.init(.{4.0, 5.0, 6.0, 7.0});
    print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
    q1.mul(q2);
    print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
}

test "testQuaternion" {
    var q1 = fQuat.init(.{0.0, 1.0, 2.0, 3.0});
    var q2 = fQuat.init(.{4.0, 5.0, 6.0, 7.0});
    print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
    q1.mul(q2);
    print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
}
// test "epsilon auto performance" {
//     const iterations: usize = 1_000_000;
//     var rand = Prng.init(0);

//     var parts: [iterations]f32 = undefined;
//     for (0..iterations) |i| {
//         parts[i] = rand.random().float(f32) * std.math.f32_max;
//         if (i % 2 == 0) {
//             parts[i] *= -1.0;
//         }
//     }

//     {
//         var t = ScopeTimer.start("epsilon auto 32", getScopeTimerID());
//         defer t.stop();
//         for (1..iterations-1) |i| {
//             parts[i-1] = epsilonAuto(parts[i], parts[i + 1]);
//         }
//     }
    
//     benchmark.printAllScopeTimers();
// }

fn stopOptim() u64 {
    const k = struct {
        var i: i64 = -1;
    };
    k.i += 1;
    return @intCast(u64, k.i);
}

pub fn crossPerformance() void {
    const iterations: usize = 1_000_00;
    var rand = Prng.init(stopOptim());

    var vecs: [iterations]fVec3 = undefined;

    for (0..iterations) |i| {
        vecs[i].set(.{rand.random().float(f32), rand.random().float(f32), rand.random().float(f32)});
        vecs[i].mul(100000.0);
        if (i % 2 == 0) {
            vecs[i].mul(-1.0);
        }
    }
    var output: [iterations]fVec3 = undefined;

    {
        var t = ScopeTimer.start("cross", getScopeTimerID());
        defer t.stop();
        for (0..iterations-1) |i| {
            output[i] = vecs[i].cross(vecs[i + 1]);
        }
    }

    benchmark.printAllScopeTimers();
}

pub fn quatMulPerformance() void {
    const iterations: usize = 1_000_00;
    var rand = Prng.init(stopOptim());

    var quats: [iterations]fQuat = undefined;

    for (0..iterations) |i| {
        quats[i].set(.{rand.random().float(f32), rand.random().float(f32), rand.random().float(f32), rand.random().float(f32)});
        if (rand.random().boolean()) {
            quats[i].parts[0] *= 10000.0;
        }
        else {
            quats[i].parts[0] *= -10000.0;
        }
        if (rand.random().boolean()) {
            quats[i].parts[1] *= 10000.0;
        }
        else {
            quats[i].parts[1] *= -10000.0;
        }if (rand.random().boolean()) {
            quats[i].parts[2] *= 10000.0;
        }
        else {
            quats[i].parts[2] *= -10000.0;
        }if (rand.random().boolean()) {
            quats[i].parts[3] *= 10000.0;
        }
        else {
            quats[i].parts[3] *= -10000.0;
        }
    }
    var output: [iterations]fQuat = undefined;

    {
        var t = ScopeTimer.start("quat mul simd", getScopeTimerID());
        defer t.stop();
        for (0..iterations-1) |i| {
            output[i] = quats[i].mulc(quats[i + 1]);
        }
    }

    print("{any}\n", .{output[0]});

    benchmark.printAllScopeTimers();
}

// test "vector math performance" {
//     const iterations: usize = 10_000;
//     var rand = Prng.init(0);

//     var vecs3_32: [iterations]fVec3 = undefined;
//     var vecs3_32_out: [iterations]fVec3 = undefined;
//     for (0..iterations) |i| {
//         vecs3_32[i].set(.{rand.random().float(f32), rand.random().float(f32), rand.random().float(f32)});
//         vecs3_32[i].sub(0.5);
//         vecs3_32[i].mul(2.0);
//         vecs3_32[i].mul(std.math.f32_max);
//     }

//     var vecs3_64: [iterations]dVec3 = undefined;
//     var vecs3_64_out: [iterations]dVec3 = undefined;
//     for (0..iterations) |i| {
//         vecs3_64[i].set(.{rand.random().float(f64), rand.random().float(f64), rand.random().float(f64)});
//         vecs3_64[i].sub(0.5);
//         vecs3_64[i].mul(2.0);
//         vecs3_64[i].mul(std.math.f32_max);
//     }


//     var vecs4_32: [iterations]fVec4 = undefined;
//     var vecs4_32_out: [iterations]fVec4 = undefined;
//     for (0..iterations) |i| {
//         vecs4_32[i].set(.{rand.random().float(f32), rand.random().float(f32), rand.random().float(f32), rand.random().float(f32)});
//         vecs4_32[i].sub(0.5);
//         vecs4_32[i].mul(2.0);
//         vecs4_32[i].mul(std.math.f32_max);
//     }

//     var vecs4_64: [iterations]dVec4 = undefined;
//     var vecs4_64_out: [iterations]dVec4 = undefined;
//     for (0..iterations) |i| {
//         vecs4_64[i].set(.{rand.random().float(f64), rand.random().float(f64), rand.random().float(f64), rand.random().float(f64)});
//         vecs4_64[i].sub(0.5);
//         vecs4_64[i].mul(2.0);
//         vecs4_64[i].mul(std.math.f32_max);
//     }

//     {
//         var t = ScopeTimer.start("fVec3", getScopeTimerID());
//         defer t.stop();
//         for (0..iterations-1) |i| {
//             // vecs3_32_out[i] = vecs3_32[i].cross(vecs3_32[i + 1]);
//             vecs3_32_out[i].add(500.0);
//             vecs3_32_out[i].sub(2038.388);
//             vecs3_32_out[i].mul(2.388);
//             vecs3_32_out[i].div(8.388);
//             vecs3_32_out[i].add(vecs3_32[i].dot(vecs3_32[i + 1]));
//             vecs3_32_out[i].mul(vecs3_32[i].clampSize(3.999));
//             vecs3_32_out[i].add(vecs3_32[i].normSafe());
//             vecs3_32_out[i].add(vecs3_32[i + 1].normSafe());
//         }
//     }
//     {
//         var t = ScopeTimer.start("dVec3", getScopeTimerID());
//         defer t.stop();
//         for (0..iterations-1) |i| {
//             // vecs3_64_out[i] = vecs3_64[i].cross(vecs3_64[i + 1]);
//             vecs3_64_out[i].add(500.0);
//             vecs3_64_out[i].sub(2038.388);
//             vecs3_64_out[i].mul(2.388);
//             vecs3_64_out[i].div(8.388);
//             vecs3_64_out[i].add(vecs3_64[i].dot(vecs3_64[i + 1]));
//             vecs3_64_out[i].mul(vecs3_64[i].clampSize(3.999));
//             vecs3_64_out[i].add(vecs3_64[i].normSafe());
//             vecs3_64_out[i].add(vecs3_64[i + 1].normSafe());
//         }
//     }
//     {
//         var t = ScopeTimer.start("fVec4", getScopeTimerID());
//         defer t.stop();
//         for (0..iterations-1) |i| {
//             // vecs4_32_out[i] = vecs4_32[i].cross(vecs4_32[i + 1]);
//             vecs4_32_out[i].add(500.0);
//             vecs4_32_out[i].sub(2038.388);
//             vecs4_32_out[i].mul(2.388);
//             vecs4_32_out[i].div(8.388);
//             vecs4_32_out[i].add(vecs4_32[i].dot(vecs4_32[i + 1]));
//             vecs4_32_out[i].mul(vecs4_32[i].clampSize(3.999));
//             vecs4_32_out[i].add(vecs4_32[i].normSafe());
//             vecs4_32_out[i].add(vecs4_32[i + 1].normSafe());
//         }
//     }
//     {
//         var t = ScopeTimer.start("dVec4", getScopeTimerID());
//         defer t.stop();
//         for (0..iterations-1) |i| {
//             // vecs4_64_out[i] = vecs4_64[i].cross(vecs4_64[i + 1]);
//             vecs4_64_out[i].add(500.0);
//             vecs4_64_out[i].sub(2038.388);
//             vecs4_64_out[i].mul(2.388);
//             vecs4_64_out[i].div(8.388);
//             vecs4_64_out[i].add(vecs4_64[i].dot(vecs4_64[i + 1]));
//             vecs4_64_out[i].mul(vecs4_64[i].clampSize(3.999));
//             vecs4_64_out[i].add(vecs4_64[i].normSafe());
//             vecs4_64_out[i].add(vecs4_64[i + 1].normSafe());
//         }
//     }
//     benchmark.printAllScopeTimers();
// }