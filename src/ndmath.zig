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

pub const bVec2 = Vec(2, bool);
pub const bVec3 = Vec(3, bool);
pub const bVec4 = Vec(4, bool);

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
            return zero;
        }

        pub inline fn init(scalars: anytype) VecType {
            return VecType{ .parts = scalars };
        }

        pub inline fn fromArray(scalars: *const [len]ScalarType) VecType {
            return VecType{ .parts = scalars[0..len].* };
        }

        pub inline fn fromScalar(scalar: ScalarType) VecType {
            return VecType{ .parts = @splat(len, scalar) };
        }

        pub inline fn random(rand: anytype, minmax: ScalarType) VecType {
            var vec: VecType = undefined;
            for (0..len) |i| {
                vec.parts[i] = rand.random().float(ScalarType) * if(rand.random().boolean()) - minmax else minmax;
            }
            return vec;
        }

    // ------------------------------------------------------------------------------------------------------ conversion

        // copy vector with scalar type Ta and len Na into self (vector with scalar type Tb and len Nb), where Na
        // does not need to equal Nb. If Ta != Tb, then the cast must be legal by zig compiler's rules.
        // example: 
        // var new_vec3 = fVec3.new();
        // new_vec3.replicate(some_intvec4, false);
        pub fn replicate(self: *VecType, other: anytype, fill_zero: bool) void {
            const from_type_float = switch(@typeInfo(@TypeOf(other).scalar_type)) { .Float => true, else => false };
            const to_type_float = switch(@typeInfo(ScalarType)) { .Float => true, else => false };

            if (fill_zero) {
                self.* = zero;
            }

            if (from_type_float) {
                if (to_type_float) {
                    self.floatToFloat(other);
                }
                else {
                    self.floatToInt(other);
                }
            }
            else {
                if (to_type_float) {
                    self.intToFloat(other);
                }
                else {
                    self.intToInt(other);
                }
            }
        }

        inline fn floatToFloat(self: *VecType, other: anytype) void {
            const min_len = @min(len, @TypeOf(other).length);
            inline for (0..min_len) |i| {
                self.parts[i] = @floatCast(ScalarType, other.parts[i]);
            }
        }

        inline fn floatToInt(self: *VecType, other: anytype) void {
            const min_len = @min(len, @TypeOf(other).length);
            inline for (0..min_len) |i| {
                self.parts[i] = @floatToInt(ScalarType, other.parts[i]);
            }
        }

        inline fn intToFloat(self: *VecType, other: anytype) void {
            const min_len = @min(len, @TypeOf(other).length);
            inline for (0..min_len) |i| {
                self.parts[i] = @intToFloat(ScalarType, other.parts[i]);
            }
        }

        inline fn intToInt(self: *VecType, other: anytype) void {
            const min_len = @min(len, @TypeOf(other).length);
            inline for (0..min_len) |i| {
                self.parts[i] = @intCast(ScalarType, other.parts[i]);
            }
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

        pub inline fn xAdd(self: *VecType, val: ScalarType) void {
            self.parts[0] += val;
        }

        pub inline fn yAdd(self: *VecType, val: ScalarType) void {
            self.parts[1] += val;
        }

        pub inline fn zAdd(self: *VecType, val: ScalarType) void {
            self.parts[2] += val;
        }

        pub inline fn wAdd(self: *VecType, val: ScalarType) void {
            self.parts[3] += val;
        }

        pub inline fn xSub(self: *VecType, val: ScalarType) void {
            self.parts[0] -= val;
        }

        pub inline fn ySub(self: *VecType, val: ScalarType) void {
            self.parts[1] -= val;
        }

        pub inline fn zSub(self: *VecType, val: ScalarType) void {
            self.parts[2] -= val;
        }

        pub inline fn wSub(self: *VecType, val: ScalarType) void {
            self.parts[3] -= val;
        }

        pub inline fn xMul(self: *VecType, val: ScalarType) void {
            self.parts[0] *= val;
        }

        pub inline fn yMul(self: *VecType, val: ScalarType) void {
            self.parts[1] *= val;
        }

        pub inline fn zMul(self: *VecType, val: ScalarType) void {
            self.parts[2] *= val;
        }

        pub inline fn wMul(self: *VecType, val: ScalarType) void {
            self.parts[3] *= val;
        }

        pub inline fn xDiv(self: *VecType, val: ScalarType) void {
            self.parts[0] /= val;
        }

        pub inline fn yDiv(self: *VecType, val: ScalarType) void {
            self.parts[1] /= val;
        }

        pub inline fn zDiv(self: *VecType, val: ScalarType) void {
            self.parts[2] /= val;
        }

        pub inline fn wDiv(self: *VecType, val: ScalarType) void {
            self.parts[3] /= val;
        }

        pub inline fn setX(self: *VecType, in_x: ScalarType) void {
            self.parts[0] = in_x;
        }

        pub inline fn setY(self: *VecType, in_y: ScalarType) void {
            self.parts[1] = in_y;
        }

        pub inline fn setZ(self: *VecType, in_z: ScalarType) void {
            self.parts[2] = in_z;
        }

        pub inline fn setW(self: *VecType, in_w: ScalarType) void {
            self.parts[3] = in_w;
        }

        pub inline fn component(self: *const VecType, idx: usize) ScalarType {
            return self.parts[idx];
        }

        pub inline fn setComponent(self: *VecType, idx: usize, scalar: ScalarType) void {
            self.parts[idx] = scalar;
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
                    2, 3 => vAddcLoop(self, other),
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
                    2, 3 => vAddLoop(self, other),
                    else => blk: {
                        if (@TypeOf(other).length != len) {
                            break :blk vAddLoop(self, other);
                        }
                        else {
                            self.parts = self.parts + other.parts;
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
                    2, 3 => vSubcLoop(self, other),
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
                    2, 3 => vSubLoop(self, other),
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
                    2, 3 => vMulcLoop(self, other),
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
                    2, 3 => vMulLoop(self, other),
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
                    2, 3 => vDivcLoop(self, other),
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
                    2, 3 => vDivLoop(self, other),
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
                return VecType{ .parts = .{
                    self.parts[0] + other.parts[0], 
                    self.parts[1] + other.parts[1], 
                    self.parts[2] + other.parts[2]
                }};
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
                return VecType{ .parts = .{
                    self.parts[0] - other.parts[0], 
                    self.parts[1] - other.parts[1], 
                    self.parts[2] - other.parts[2]}
                };
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
                return VecType{ .parts = .{
                    self.parts[0] * other.parts[0], 
                    self.parts[1] * other.parts[1], 
                    self.parts[2] * other.parts[2]}
                };
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
                return VecType{ .parts = .{
                    self.parts[0] / other.parts[0], 
                    self.parts[1] / other.parts[1], 
                    self.parts[2] / other.parts[2]}
                };
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
                self.parts[2] * other.parts[0] - other.parts[2] * self.parts[0],
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
            const a: @Vector(len, ScalarType) = self.parts;
            const b: @Vector(len, ScalarType) = other.parts;
            const diff = a - b;
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
            const diff = @Vector(3, ScalarType){
                self.parts[0] - other.parts[0], 
                self.parts[1] - other.parts[1], 
                self.parts[2] - other.parts[2]
            };
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq3d(self: VecType, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){
                self.parts[0] - other.parts[0], 
                self.parts[1] - other.parts[1], 
                self.parts[2] - other.parts[2]
            };
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
                self = zero;
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

        pub inline fn componentMax(self: VecType) ScalarType {
            return @reduce(.Max, self.parts);
        }

        pub inline fn componentMin(self: VecType) ScalarType {
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

        pub const scalar_type = ScalarType;
        pub const length = len;
        pub const zero = std.mem.zeroes(VecType);
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

        pub fn format(
            self: VecType, 
            comptime _: []const u8, 
            _: std.fmt.FormatOptions, 
            writer: anytype
        ) std.os.WriteError!void {
            inline for(0..len) |i| {
                try writer.print(" {d:>16.3}", .{self.parts[i]});
            }
        }


    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------- VecNxN (for SIMD)
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

// ------ 128 bit ------

pub const hVec2x8 = Vec2xN(8, f16);
pub const hVec3x8 = Vec3xN(8, f16);
pub const hVec4x8 = Vec4xN(8, f16);

pub const fVec2x4 = Vec2xN(4, f32);
pub const fVec3x4 = Vec3xN(4, f32);
pub const fVec4x4 = Vec4xN(4, f32);

// ------ 256 bit ------

pub const hVec2x16 = Vec2xN(16, f16);
pub const hVec3x16 = Vec3xN(16, f16);
pub const hVec4x16 = Vec4xN(16, f16);

pub const fVec2x8 = Vec2xN(8, f32);
pub const fVec3x8 = Vec3xN(8, f32);
pub const fVec4x8 = Vec4xN(8, f32);

pub const dVec2x4 = Vec2xN(4, f64);
pub const dVec3x4 = Vec3xN(4, f64);
pub const dVec4x4 = Vec4xN(4, f64);

// ------------------------------------------------------------------------------------------------------ type functions

pub fn Vec2xN(comptime _width: comptime_int, comptime ScalarType: type) type {

    return struct {
        const SelfType = @This();

        x: @Vector(_width, ScalarType) = undefined,
        y: @Vector(_width, ScalarType) = undefined,

        pub inline fn new() SelfType {
            return std.mem.zeroes(SelfType);
        }

        pub inline fn fromVec(vec: Vec(2, ScalarType)) SelfType {
            return SelfType {
                .x = @splat(_width, vec.parts[0]),
                .y = @splat(_width, vec.parts[1]),
            };
        }

        pub inline fn fromScalar(scalar: ScalarType) SelfType {
            return SelfType {
                .x = @splat(_width, scalar),
                .y = @splat(_width, scalar),
            };
        }

        pub inline fn set(self: *SelfType, vec: Vec(2, ScalarType)) void {
            self.x = @splat(_width, vec.parts[0]);
            self.y = @splat(_width, vec.parts[1]);
        }

        pub inline fn setSingle(self: *SelfType, vec: Vec(2, ScalarType), idx: usize) void {
            self.x[idx] = vec.parts[0];
            self.y[idx] = vec.parts[1];
        }

        pub inline fn setTransposed(self: *SelfType, vec: Vec(2, ScalarType)) void {
            const long_vec = @Vector(_width, ScalarType) {vec.parts[0], vec.parts[1], vec.parts[0], vec.parts[1]};
            self.x = long_vec;
            self.y = long_vec;
        }

        pub fn setTransposed2(self: *SelfType, vec1: Vec(2, ScalarType), vec2: Vec(2, ScalarType)) void {
            const long_vec = @Vector(_width, ScalarType) {vec1.parts[0], vec1.parts[1], vec2.parts[0], vec2.parts[1]};
            self.x = long_vec;
            self.y = long_vec;
        }

        pub inline fn setSingleFromMulti(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
        }

        pub inline fn setRangeFromMulti(self: *SelfType, other: *SelfType, start: usize, end: usize) void {
            std.debug.assert(start < end and end <= _width);
            @memcpy(@ptrCast([*]ScalarType, &self.x[0])[start..end], @ptrCast([*]ScalarType, &other.x[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.y[0])[start..end], @ptrCast([*]ScalarType, &other.y[0])[start..end]);
        }

        pub inline fn swapSingle(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            var temp: [2]ScalarType = undefined;
            temp[0] = self.x[self_idx];
            temp[1] = self.y[self_idx];
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
            other.x[other_idx] = temp[0];
            other.y[other_idx] = temp[1];
        }

        pub inline fn vector(self: *const SelfType, idx: usize) Vec(2, ScalarType) {
            return Vec(2, ScalarType).init(.{self.x[idx], self.y[idx]});
        }

        pub const scalar_type = ScalarType;
        pub const height = 2;
        pub const width = _width;

    };

}

pub fn Vec3xN(comptime _width: comptime_int, comptime ScalarType: type) type {
    
    return struct {
        const SelfType = @This();

        x: @Vector(_width, ScalarType) = undefined,
        y: @Vector(_width, ScalarType) = undefined,
        z: @Vector(_width, ScalarType) = undefined,

        pub inline fn new() SelfType {
            return std.mem.zeroes(SelfType);
        }

        pub inline fn fromVec(vec: Vec(3, ScalarType)) SelfType {
            return SelfType {
                .x = @splat(_width, vec.parts[0]),
                .y = @splat(_width, vec.parts[1]),
                .z = @splat(_width, vec.parts[2]),
            };
        }

        pub inline fn fromScalar(scalar: ScalarType) SelfType {
            return SelfType {
                .x = @splat(_width, scalar),
                .y = @splat(_width, scalar),
                .z = @splat(_width, scalar),
            };
        }

        pub inline fn set(self: *SelfType, vec: Vec(3, ScalarType)) void {
            self.x = @splat(_width, vec.parts[0]);
            self.y = @splat(_width, vec.parts[1]);
            self.z = @splat(_width, vec.parts[2]);
        }

        pub inline fn setSingle(self: *SelfType, vec: Vec(3, ScalarType), idx: usize) void {
            self.x[idx] = vec.parts[0];
            self.y[idx] = vec.parts[1];
            self.z[idx] = vec.parts[2];
        }

        pub inline fn setTransposed(self: *SelfType, vec: Vec(3, ScalarType)) void {
            const long_vec = @Vector(_width, ScalarType) {vec.parts[0], vec.parts[1], vec.parts[2], 0.0};
            self.x = long_vec;
            self.y = long_vec;
            self.z = long_vec;
        }

        pub inline fn setSingleFromMulti(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
            self.z[self_idx] = other.z[other_idx];
        }

        pub inline fn setRangeFromMulti(self: *SelfType, other: *SelfType, start: usize, end: usize) void {
            std.debug.assert(start < end and end <= _width);
            @memcpy(@ptrCast([*]ScalarType, &self.x[0])[start..end], @ptrCast([*]ScalarType, &other.x[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.y[0])[start..end], @ptrCast([*]ScalarType, &other.y[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.z[0])[start..end], @ptrCast([*]ScalarType, &other.z[0])[start..end]);
        }

        pub fn swapSingle(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            var temp: [3]ScalarType = undefined;
            temp[0] = self.x[self_idx];
            temp[1] = self.y[self_idx];
            temp[2] = self.z[self_idx];
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
            self.z[self_idx] = other.z[other_idx];
            other.x[other_idx] = temp[0];
            other.y[other_idx] = temp[1];
            other.z[other_idx] = temp[2];
        }

        pub inline fn vector(self: *const SelfType, idx: usize) Vec(3, ScalarType) {
            return Vec(3, ScalarType).init(.{self.x[idx], self.y[idx], self.z[idx]});
        }

        pub const scalar_type = ScalarType;
        pub const height = 3;
        pub const width = _width;

    };

}

pub fn Vec4xN(comptime _width: comptime_int, comptime ScalarType: type) type {
    
    return struct {
        const SelfType = @This();

        x: @Vector(_width, ScalarType) = undefined,
        y: @Vector(_width, ScalarType) = undefined,
        z: @Vector(_width, ScalarType) = undefined,
        w: @Vector(_width, ScalarType) = undefined,

        pub inline fn new() SelfType {
            return std.mem.zeroes(SelfType);
        }

        pub inline fn fromVec(vec: Vec(4, ScalarType)) SelfType {
            return SelfType {
                .x = @splat(_width, vec.parts[0]),
                .y = @splat(_width, vec.parts[1]),
                .z = @splat(_width, vec.parts[2]),
                .w = @splat(_width, vec.parts[3]),
            };
        }

        pub inline fn fromScalar(scalar: ScalarType) SelfType {
            return SelfType {
                .x = @splat(_width, scalar),
                .y = @splat(_width, scalar),
                .z = @splat(_width, scalar),
                .w = @splat(_width, scalar),
            };
        }

        pub inline fn set(self: *SelfType, vec: Vec(4, ScalarType)) void {
            self.x = @splat(_width, vec.parts[0]);
            self.y = @splat(_width, vec.parts[1]);
            self.z = @splat(_width, vec.parts[2]);
            self.w = @splat(_width, vec.parts[3]);
        }

        pub inline fn setSingle(self: *SelfType, vec: Vec(4, ScalarType), idx: usize) void {
            self.x[idx] = vec.parts[0];
            self.y[idx] = vec.parts[1];
            self.z[idx] = vec.parts[2];
            self.w[idx] = vec.parts[3];
        }

        pub inline fn setTransposed(self: *SelfType, vec: Vec(4, ScalarType)) void {
            self.x = vec;
            self.y = vec;
            self.z = vec;
            self.w = vec;
        }

        pub inline fn setSingleFromMulti(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
            self.z[self_idx] = other.z[other_idx];
            self.w[self_idx] = other.w[other_idx];
        }

        pub inline fn setRangeFromMulti(self: *SelfType, other: *SelfType, start: usize, end: usize) void {
            std.debug.assert(start < end and end <= _width);
            @memcpy(@ptrCast([*]ScalarType, &self.x[0])[start..end], @ptrCast([*]ScalarType, &other.x[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.y[0])[start..end], @ptrCast([*]ScalarType, &other.y[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.z[0])[start..end], @ptrCast([*]ScalarType, &other.z[0])[start..end]);
            @memcpy(@ptrCast([*]ScalarType, &self.w[0])[start..end], @ptrCast([*]ScalarType, &other.w[0])[start..end]);
        }

        pub fn swapSingle(self: *SelfType, other: *SelfType, self_idx: usize, other_idx: usize) void {
            var temp: [4]ScalarType = undefined;
            temp[0] = self.x[self_idx];
            temp[1] = self.y[self_idx];
            temp[2] = self.z[self_idx];
            temp[3] = self.w[self_idx];
            self.x[self_idx] = other.x[other_idx];
            self.y[self_idx] = other.y[other_idx];
            self.z[self_idx] = other.z[other_idx];
            self.w[self_idx] = other.w[other_idx];
            other.x[other_idx] = temp[0];
            other.y[other_idx] = temp[1];
            other.z[other_idx] = temp[2];
            other.w[other_idx] = temp[3];
        }

        pub inline fn vector(self: *const SelfType, idx: usize) Vec(4, ScalarType) {
            return Vec(4, ScalarType).init(.{self.x[idx], self.y[idx], self.z[idx], self.w[idx]});
        }

        // note: assumes normality!
        pub inline fn plane(self: *const SelfType, idx: usize) Plane(ScalarType) {
            return Plane(ScalarType) {
                .normal = Vec(3, ScalarType){.parts = .{self.x[idx], self.y[idx], self.z[idx]}}, 
                .odist = self.w[idx]
            };
        }

        pub const scalar_type = ScalarType;
        pub const height = 4;
        pub const width = _width;

    };

}

pub fn MultiVec(comptime vec_len: comptime_int, comptime width: comptime_int, comptime ScalarType: type) type {
    return switch(width) {
        4, 8, 16 => return switch(vec_len) {
            2 => Vec2xN(width, ScalarType),
            3 => Vec3xN(width, ScalarType),
            4 => Vec4xN(width, ScalarType),
            else => unreachable,
        },
        else => unreachable,
    };
}

// ---------------------------------------------------------------------------------------------------------------- math

pub inline fn multiAdd(multi_a: anytype, multi_b: @TypeOf(multi_a), result: @TypeOf(multi_a)) void {
    result.x = multi_a.x + multi_b.x;
    result.y = multi_a.y + multi_b.y;

    switch (@TypeOf(multi_a.*).height) {
        2 => {},
        3 => {
            result.z = multi_a.z + multi_b.z;
        },
        4 => {
            result.z = multi_a.z + multi_b.z;
            result.w = multi_a.w + multi_b.w;
        },
        else => unreachable,
    }
}

pub inline fn multiSub(multi_a: anytype, multi_b: @TypeOf(multi_a), result: @TypeOf(multi_a)) void {
    result.x = multi_a.x - multi_b.x;
    result.y = multi_a.y - multi_b.y;

    switch (@TypeOf(multi_a.*).height) {
        2 => {},
        3 => {
            result.z = multi_a.z - multi_b.z;
        },
        4 => {
            result.z = multi_a.z - multi_b.z;
            result.w = multi_a.w - multi_b.w;
        },
        else => unreachable,
    }
}

pub inline fn multiMul(multi_a: anytype, multi_b: @TypeOf(multi_a), result: @TypeOf(multi_a)) void {
    result.x = multi_a.x * multi_b.x;
    result.y = multi_a.y * multi_b.y;

    switch (@TypeOf(multi_a.*).height) {
        2 => {},
        3 => {
            result.z = multi_a.z * multi_b.z;
        },
        4 => {
            result.z = multi_a.z * multi_b.z;
            result.w = multi_a.w * multi_b.w;
        },
        else => unreachable,
    }
}

pub fn multiDot(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_mul = multi_a.x * multi_b.x;

    switch (@TypeOf(multi_a.*).height) {
        2 => {
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.y, x_mul);
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.y, x_mul);
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.z, multi_b.z, cur_sum);
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.y, x_mul);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.z, multi_b.z, cur_sum);
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.w, multi_b.w, cur_sum2);
        },
        else => unreachable,
    }
}

pub fn multiCross(multi_a: anytype, multi_b: @TypeOf(multi_a), result: @TypeOf(multi_a)) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    switch (@TypeOf(multi_a.*).height) {
        3, 4 => {
            // x = a.y * b.z - a.z * b.y
            // y = a.z * b.x - a.x * b.z
            // z = a.x * b.y - a.y * b.x // 6 + 12 = 18
            const x_neg_part = multi_a.z * multi_b.y; // 6 + 6 = 12
            result.x = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.z, -x_neg_part);
            const y_neg_part = multi_a.x * multi_b.z;
            result.y = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.z, multi_b.x, -y_neg_part);
            const z_neg_part = multi_a.y * multi_b.x;
            result.z = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.x, multi_b.y, -z_neg_part);
        },
        else => unreachable,
    }
}

pub fn multiDistSq(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;

    switch (@TypeOf(multi_a.*).height) {
        2 => {
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
            const z_sub = multi_a.z - multi_b.z;
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum);
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
            const z_sub = multi_a.z - multi_b.z;
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum);
            const w_sub = multi_a.w - multi_b.w;
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), w_sub, w_sub, cur_sum2);
        },
        else => unreachable,
    }
}

pub inline fn multiDist(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;

    switch (@TypeOf(multi_a.*).height) {
        2 => {
            result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square));
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
            const z_sub = multi_a.z - multi_b.z;
            result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum));
            
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
            const z_sub = multi_a.z - multi_b.z;
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum);
            const w_sub = multi_a.w - multi_b.w;
            result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), w_sub, w_sub, cur_sum2));
        },
        else => unreachable,
    }
}

pub fn multiNormalizeUnsafe(multi_vec: anytype) void {
    @setFloatMode(std.builtin.FloatMode.Optimized);
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            multi_vec.x *= size_inv;
            multi_vec.y *= size_inv;
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            multi_vec.x *= size_inv;
            multi_vec.y *= size_inv;
            multi_vec.z *= size_inv;
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2);
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            multi_vec.x *= size_inv;
            multi_vec.y *= size_inv;
            multi_vec.z *= size_inv;
            multi_vec.w *= size_inv;
        },
        else => unreachable,
    }
}

pub fn multiNormalizeSafe(multi_vec: anytype) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const safe_to_mul = size_sq >= @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            const size_inv_safe = @select(scalar_type, safe_to_mul, size_inv, @splat(scalar_width, @as(scalar_type, 0.0)));
            multi_vec.x *= size_inv_safe;
            multi_vec.y *= size_inv_safe;
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const safe_to_mul = size_sq >= @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            const size_inv_safe = @select(scalar_type, safe_to_mul, size_inv, @splat(scalar_width, @as(scalar_type, 0.0)));
            multi_vec.x *= size_inv_safe;
            multi_vec.y *= size_inv_safe;
            multi_vec.z *= size_inv_safe;
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2);
            const safe_to_mul = size_sq >= @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            const size_inv = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
            const size_inv_safe = @select(scalar_type, safe_to_mul, size_inv, @splat(scalar_width, @as(scalar_type, 0.0)));
            multi_vec.x *= size_inv_safe;
            multi_vec.y *= size_inv_safe;
            multi_vec.z *= size_inv_safe;
            multi_vec.w *= size_inv_safe;
        },
        else => unreachable,
    }
}

pub fn multiClampSize(multi_vec: anytype, scalar: @TypeOf(multi_vec.*).scalar_type) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            const size = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square));
            const splat = @splat(scalar_width, scalar);
            const do_scale = size > splat;
            const scales = splat / size;
            const selected_scales = @select(scalar_type, do_scale, scales, @splat(scalar_width, @as(scalar_type, 1.0)));
            multi_vec.x *= selected_scales;
            multi_vec.y *= selected_scales;
        },
        3 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const size = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum));
            const splat = @splat(scalar_width, scalar);
            const do_scale = size > splat;
            const scales = splat / size;
            const selected_scales = @select(scalar_type, do_scale, scales, @splat(scalar_width, @as(scalar_type, 1.0)));
            multi_vec.x *= selected_scales;
            multi_vec.y *= selected_scales;
            multi_vec.z *= selected_scales;
        },
        4 => {
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum));
            const size = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2);
            const splat = @splat(scalar_width, scalar);
            const do_scale = size > splat;
            const scales = splat / size;
            const selected_scales = @select(scalar_type, do_scale, scales, @splat(scalar_width, @as(scalar_type, 1.0)));
            multi_vec.x *= selected_scales;
            multi_vec.y *= selected_scales;
            multi_vec.z *= selected_scales;
            multi_vec.w *= selected_scales;
        },
        else => unreachable,
    }
} 

pub fn multiSizeSq(multi_vec: anytype, result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            multiSizeSq2d(multi_vec, result);
        },
        3 => {
            multiSizeSq3d(multi_vec, result);
        },
        4 => {
            const x_square = multi_vec.x * multi_vec.x;
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2);
        },
        else => unreachable,
    }
}

pub fn multiSize(multi_vec: anytype, result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            multiSize2d(multi_vec, result);
        },
        3 => {
            multiSize3d(multi_vec, result);
        },
        4 => {
            const x_square = multi_vec.x * multi_vec.x;
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2));
        },
        else => unreachable,
    }
}

pub inline fn multiAbs(multi_vec: anytype) void {
    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            multi_vec.x = @fabs(multi_vec.x);
            multi_vec.y = @fabs(multi_vec.y);
        },
        3 => {
            multiAbs3d(multi_vec);
        },
        4 => {
            multi_vec.x = @fabs(multi_vec.x);
            multi_vec.y = @fabs(multi_vec.y);
            multi_vec.z = @fabs(multi_vec.z);
            multi_vec.w = @fabs(multi_vec.w);
        },
        else => unreachable,
    }
}

pub inline fn multiNegate(multi_vec: anytype) void {
    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            multi_vec.x = -multi_vec.x;
            multi_vec.y = -multi_vec.y;
        },
        3 => {
            multiNegate3d(multi_vec);
        },
        4 => {
            multi_vec.x = -multi_vec.x;
            multi_vec.y = -multi_vec.y;
            multi_vec.z = -multi_vec.z;
            multi_vec.w = -multi_vec.w;
        },
        else => unreachable,
    }
}

pub fn multiNearlyEqual(multi_a: anytype, multi_b: @TypeOf(multi_a), result: *[@TypeOf(multi_a.*).width]bool) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;
    const epsilon = @splat(scalar_width, @as(scalar_type, epsilonMedium(scalar_type)));

    const x_diff_abs = @fabs(multi_a.x - multi_b.x);
    const x_eq = x_diff_abs <= epsilon;
    const y_diff_abs = @fabs(multi_a.y - multi_b.y);
    const y_eq = y_diff_abs <= epsilon;

    switch (@TypeOf(multi_a.*).height) {
        2 => {
            result.* = x_eq and y_eq;
        },
        3 => {
            const z_diff_abs = @fabs(multi_a.z - multi_b.z);
            const z_eq = z_diff_abs <= epsilon;
            result.* = x_eq and y_eq and z_eq;
        },
        4 => {
            const z_diff_abs = @fabs(multi_a.z - multi_b.z);
            const z_eq = z_diff_abs <= epsilon;
            const w_diff_abs = @fabs(multi_a.w - multi_b.w);
            const w_eq = w_diff_abs <= epsilon;
            result.* = x_eq and y_eq and z_eq and w_eq;
        },
        else => unreachable,
    }
}

pub inline fn multiNearlyZero(multi_vec: anytype, result: *[@TypeOf(multi_vec.*).width]bool) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;
    const epsilon = @splat(scalar_width, @as(scalar_type, epsilonMedium(scalar_type)));

    const x_zero = @fabs(multi_vec.x) < epsilon;
    const y_zero = @fabs(multi_vec.y) < epsilon;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            result.* = x_zero and y_zero;
        },
        3 => {
            const z_zero = @fabs(multi_vec.z) < epsilon;
            result.* = x_zero and y_zero and z_zero;
        },
        4 => {
            const z_zero = @fabs(multi_vec.z) < epsilon;
            const w_zero = @fabs(multi_vec.w) < epsilon;
            result.* = x_zero and y_zero and z_zero and w_zero;
        },
        else => unreachable,
    }
} 

pub fn multiNearlyEqual2d(multi_a: anytype, multi_b: @TypeOf(multi_a), result: *[@TypeOf(multi_a.*).width]bool) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;
    const epsilon = @splat(scalar_width, @as(scalar_type, epsilonMedium(scalar_type)));

    const x_diff_abs = @fabs(multi_a.x - multi_b.x);
    const x_eq = x_diff_abs <= epsilon;
    const y_diff_abs = @fabs(multi_a.y - multi_b.y);
    const y_eq = y_diff_abs <= epsilon;
    result.* = x_eq and y_eq;
}

pub fn multiNearlyEqual3d(multi_a: anytype, multi_b: @TypeOf(multi_a), result: *[@TypeOf(multi_a.*).width]bool) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;
    const epsilon = @splat(scalar_width, @as(scalar_type, epsilonMedium(scalar_type)));

    const x_diff_abs = @fabs(multi_a.x - multi_b.x);
    const x_eq = x_diff_abs <= epsilon;
    const y_diff_abs = @fabs(multi_a.y - multi_b.y);
    const y_eq = y_diff_abs <= epsilon;
    const z_diff_abs = @fabs(multi_a.z - multi_b.z);
    const z_eq = z_diff_abs <= epsilon;
    result.* = x_eq and y_eq and z_eq;
   
}

pub fn multiNormalizeUnsafe3d(multi_vec: anytype) void {
    @setFloatMode(std.builtin.FloatMode.Optimized);
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
    const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
    const size = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
    multi_vec.x *= size;
    multi_vec.y *= size;
    multi_vec.z *= size;
}

pub fn multiNormalizeSafe3d(multi_vec: anytype) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
    const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
    const safe_to_mul = size_sq >= @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
    const size = @splat(scalar_width, @as(scalar_type, 1.0)) / @sqrt(size_sq);
    const size_safe = @select(scalar_type, safe_to_mul, size, @splat(4, @as(scalar_type, 0.0)));
    multi_vec.x *= size_safe;
    multi_vec.y *= size_safe;
    multi_vec.z *= size_safe;
}

pub inline fn multiAbs3d(multi_vec: anytype) void {
    multi_vec.x = @fabs(multi_vec.x);
    multi_vec.y = @fabs(multi_vec.y);
    multi_vec.z = @fabs(multi_vec.z);
}

pub inline fn multiNegate3d(multi_vec: anytype) void {
    multi_vec.x = -multi_vec.x;
    multi_vec.y = -multi_vec.y;
    multi_vec.z = -multi_vec.z;
}

pub inline fn multiSizeSq2d(
    multi_vec: anytype, 
    result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
}

pub inline fn multiSizeSq3d(
    multi_vec: anytype, 
    result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
}

pub inline fn multiSize2d(
    multi_vec: anytype, 
    result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;
    const x_square = multi_vec.x * multi_vec.x;
    result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square));
}

pub inline fn multiSize3d(
    multi_vec: anytype, 
    result: *[@TypeOf(multi_vec.*).width]@TypeOf(multi_vec.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    const x_square = multi_vec.x * multi_vec.x;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
    result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum));
}

pub fn multiIsNorm(multi_vec: anytype, result: *[@TypeOf(multi_vec.*).width]bool) void {
    const scalar_type = @TypeOf(multi_vec.*).scalar_type;
    const scalar_width = @TypeOf(multi_vec.*).width;

    switch (@TypeOf(multi_vec.*).height) {
        2 => {
            const x_square = multi_vec.x * multi_vec.x;
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const epsilon = @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            result.* = @fabs(@splat(scalar_width, @as(scalar_type, 1.0) - size_sq)) <= epsilon;
        },
        3 => {
            const x_square = multi_vec.x * multi_vec.x;
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const epsilon = @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            result.* = @fabs(@splat(scalar_width, @as(scalar_type, 1.0) - size_sq)) <= epsilon;
        },
        4 => {
            const x_square = multi_vec.x * multi_vec.x;
            const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.y, multi_vec.y, x_square);
            const cur_sum2 = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.z, multi_vec.z, cur_sum);
            const size_sq = @mulAdd(@Vector(scalar_width, scalar_type), multi_vec.w, multi_vec.w, cur_sum2);
            const epsilon = @splat(scalar_width, @as(scalar_type, epsilonSmall(scalar_type)));
            result.* = @fabs(@splat(scalar_width, @as(scalar_type, 1.0) - size_sq)) <= epsilon;
        },
        else => unreachable,
    }
}

pub inline fn multiDot2d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_mul = multi_a.x * multi_b.x;
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.y, x_mul);
}

pub inline fn multiDot3d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_mul = multi_a.x * multi_b.x;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.y, multi_b.y, x_mul);
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), multi_a.z, multi_b.z, cur_sum);
}

pub inline fn multiDistSq2d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
}

pub inline fn multiDist2d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;
    result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square));
}

pub fn multiDistSq3d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
    const z_sub = multi_a.z - multi_b.z;
    result.* = @mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum);
}

pub fn multiDist3d(
    multi_a: anytype, 
    multi_b: @TypeOf(multi_a), 
    result: *[@TypeOf(multi_a.*).width]@TypeOf(multi_a.*).scalar_type
) void {
    const scalar_type = @TypeOf(multi_a.*).scalar_type;
    const scalar_width = @TypeOf(multi_a.*).width;

    const x_sub = multi_a.x - multi_b.x;
    const x_square = x_sub * x_sub;
    const y_sub = multi_a.y - multi_b.y;
    const cur_sum = @mulAdd(@Vector(scalar_width, scalar_type), y_sub, y_sub, x_square);
    const z_sub = multi_a.z - multi_b.z;
    result.* = @sqrt(@mulAdd(@Vector(scalar_width, scalar_type), z_sub, z_sub, cur_sum));
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------- Vec Array Helper Types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

// ------ 128 bit ------

// --- f16

pub const hVAScalarResult2x8 = VAResult(2, 8, f16, f16);
pub const hVAScalarResult3x8 = VAResult(3, 8, f16, f16);
pub const hVAScalarResult4x8 = VAResult(4, 8, f16, f16);

pub const hVABoolResult2x8 = VAResult(2, 8, f16, bool);
pub const hVABoolResult3x8 = VAResult(3, 8, f16, bool);
pub const hVABoolResult4x8 = VAResult(4, 8, f16, bool);

pub const hVAMultiResult2x8 = VAResult(2, 8, f16, hVec2x8);
pub const hVAMultiResult3x8 = VAResult(3, 8, f16, hVec3x8);
pub const hVAMultiResult4x8 = VAResult(4, 8, f16, hVec4x8);

// --- f32

pub const fVAScalarResult2x4 = VAResult(2, 4, f32, f32);
pub const fVAScalarResult3x4 = VAResult(3, 4, f32, f32);
pub const fVAScalarResult4x4 = VAResult(4, 4, f32, f32);

pub const fVABoolResult2x4 = VAResult(2, 4, f32, bool);
pub const fVABoolResult3x4 = VAResult(3, 4, f32, bool);
pub const fVABoolResult4x4 = VAResult(4, 4, f32, bool);

pub const fVAMultiResult2x4 = VAResult(2, 4, f32, fVec2x4);
pub const fVAMultiResult3x4 = VAResult(3, 4, f32, fVec3x4);
pub const fVAMultiResult4x4 = VAResult(4, 4, f32, fVec4x4);

// ------ 256 bit ------

// --- f16

pub const hVAScalarResult2x16 = VAResult(2, 16, f16, f16);
pub const hVAScalarResult3x16 = VAResult(3, 16, f16, f16);
pub const hVAScalarResult4x16 = VAResult(4, 16, f16, f16);

pub const hVABoolResult2x16 = VAResult(2, 16, f16, bool);
pub const hVABoolResult3x16 = VAResult(3, 16, f16, bool);
pub const hVABoolResult4x16 = VAResult(4, 16, f16, bool);

pub const hVAMultiResult2x16 = VAResult(2, 16, f16, hVec2x16);
pub const hVAMultiResult3x16 = VAResult(3, 16, f16, hVec3x16);
pub const hVAMultiResult4x16 = VAResult(4, 16, f16, hVec4x16);

// --- f32

pub const fVAScalarResult2x8 = VAResult(2, 8, f32, f32);
pub const fVAScalarResult3x8 = VAResult(3, 8, f32, f32);
pub const fVAScalarResult4x8 = VAResult(4, 8, f32, f32);

pub const fVABoolResult2x8 = VAResult(2, 8, f32, bool);
pub const fVABoolResult3x8 = VAResult(3, 8, f32, bool);
pub const fVABoolResult4x8 = VAResult(4, 8, f32, bool);

pub const fVAMultiResult2x8 = VAResult(2, 8, f32, fVec2x8);
pub const fVAMultiResult3x8 = VAResult(3, 8, f32, fVec3x8);
pub const fVAMultiResult4x8 = VAResult(4, 8, f32, fVec4x8);

// --- f64

pub const dVAScalarResult2x4 = VAResult(2, 4, f64, f64);
pub const dVAScalarResult3x4 = VAResult(3, 4, f64, f64);
pub const dVAScalarResult4x4 = VAResult(4, 4, f64, f64);

pub const dVABoolResult2x4 = VAResult(2, 4, f64, bool);
pub const dVABoolResult3x4 = VAResult(3, 4, f64, bool);
pub const dVABoolResult4x4 = VAResult(4, 4, f64, bool);

pub const dVAMultiResult2x4 = VAResult(2, 4, f64, dVec2x4);
pub const dVAMultiResult3x4 = VAResult(3, 4, f64, dVec3x4);
pub const dVAMultiResult4x4 = VAResult(4, 4, f64, dVec4x4);

// ------------------------------------------------------------------------------------------------------ type functions

const VARange = struct {
    start: usize = undefined,
    vec_start: usize = undefined,
    end: usize = undefined,
    vec_end: usize = undefined
};

// TODO: this could get all of its type information from the ResultType

pub fn VAResult(
    comptime vec_len: comptime_int, 
    comptime vec_width: comptime_int, 
    comptime ScalarType: type, 
    comptime ResultType: type
) type {

    return struct {

        const SelfType = @This();

        items: ?[]ResultType = null,
        start: usize = undefined,
        end: usize = undefined,
        range: VARange = undefined,

        pub inline fn new() SelfType {
            return SelfType{.start = 0, .end = 0, .range = std.mem.zeroes(VARange)};
        }

        pub fn init(
            self: *SelfType, 
            array: *VecArray(vec_len, vec_width, ScalarType), 
            allocator: *const std.mem.Allocator
        ) !void {
            std.debug.assert(array.vector_ct > 0);

            self.start = 0;
            self.end = array.vector_ct;

            self.range.start = 0;
            self.range.end = array.items.len - 1;
            self.range.vec_start = 0;
            self.range.vec_end = array.vector_ct % vec_len;
            if (self.range.vec_end == 0) {
                self.range.vec_end = vec_len;
            }
            else {
                self.range.vec_end += 1;
            }

            const alloc_ct: usize = switch(ResultType) {
                ScalarType, bool => array.items.len * vec_width,
                MultiVec(vec_len, vec_width, ScalarType) => array.items.len,
                else => unreachable,
            };

            if (self.items) |items| {
                if (alloc_ct != self.items.?.len) {
                    self.items = try allocator.realloc(items, alloc_ct);
                }
            }
            else {
                self.items = try allocator.alloc(ResultType, alloc_ct);
            }
        }

        pub fn initRange(self: *SelfType, start_idx: usize, end_idx: usize, allocator: *const std.mem.Allocator) !void {
            VecArray(vec_len, vec_width, ScalarType).boundariesToRange(.{start_idx, end_idx}, end_idx, &self.range);
            self.start = start_idx % vec_width;
            self.end = end_idx + self.start;

            const multi_ct = self.range.end - self.range.start + 1;
            const alloc_ct: usize = switch(ResultType) {
                ScalarType, bool => multi_ct * vec_width,
                MultiVec(vec_len, vec_width, ScalarType) => multi_ct,
                else => unreachable,
            };

            if (self.items) |items| {
                if (alloc_ct != self.items.?.len) {
                    self.items = try allocator.realloc(items, alloc_ct);
                }
            }
            else {
                self.items = try allocator.alloc(ResultType, alloc_ct);
            }
        }

        // reset this result. not necessary, but is good practice for debugability. Requires the items array has been
        // passed to another structure or deallocated.
        pub inline fn reset(self: *SelfType) void {
            std.debug.assert(self.items == null);
            self.start = 0;
            self.end = 0;
            self.range = std.mem.zeroes(VARange);
        }

        pub inline fn free(self: *SelfType, allocator: *const std.mem.Allocator) void {
            if (self.items != null) {
                allocator.free(self.items);
                self.items = null;
            }
        }

        // indexing to a primitive result (scalar, bool). takes range into account. unavailable for MultiVec results,
        // because indexing to an individual vector is costly. For MultiVec results, the results array should be
        // handed over to a VecArray and translated to individual vectors in bulk.
        inline fn resultPrimitiveOnly(self: *const SelfType, idx: usize) ResultType {
            return self.items.?[idx + self.start];
        }

        const result = switch(ResultType) {
            bool, ScalarType => resultPrimitiveOnly,
            else => unreachable,
        };

        // indexing to any type of result. does not take range into account!
        pub inline fn item(self: *const SelfType, idx: usize) ResultType {
            return self.items.?[idx];
        }

        // the number of bools, Scalars, vectors originally desired.
        pub inline fn lengthSingleResults(self: *const SelfType) usize {
            return self.end - self.start;
        }

        // the number of results gotten. may, and often will be, larger than the number of results desired.
        // if MultiVec result, this is the number of MultiVecs, not the number of vectors.
        pub inline fn lengthResults(self: *const SelfType) usize {
            return self.items.?.len;
        }


        // TODO: access logic for multivec results
        
    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------- VecArray (Array of Structs of Arrays for SIMD)
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ---------------------------------------------------------------------------------------------------------------- DOCS
// given "math operations" means individual vector operations like dot() and dist(), VecArray is valuable when...

// (m) >= 4n(a) + 3(c) for f32x4 vectors
// (m) >= 3n(a) + 2(c) for f32x8 vectors

// n = number of vectors in VecArray
// m = math operations
// a = allocations (for one VecArray or one result/output array)
// c = individual conversions

// - in general, it's a good idea to reuse results structs (and their allocations) for multiple operations and/or store
//   them long-term when possible, where/when it doesn't disrupt cache performance.
// - VecArrays should likely be stored long-term most of the time, since they require allocations themselves.
// - rules of thumb...
//      - are not meant to stand in for performance measurements. they are guidance for design choices.
//      - are based on measurements gotten from tests using 128 and 1024 vectors in a tight loop on my machine.  the
//        rate of increasing advantage to SIMD depends on host specs and the program's performance characteristics.
//      - may change as further performance improvements are introduced.
// - as with many things, using a VecArray may end up slower than the traditional approach in debug builds. in tests,
//   building in debug, using an f32 4x8 with multiDot was somewhat faster than single dot products. f32 4x4 was slower.

// TODO: continue work om mem6 so this can move away from using zig allocator
// TODO: all SIMD needs a cleanup pass for user-friendliness and readability

// ------------------------------------------------------------------------------------------------- convenience aliases

// ------ 128 bit ------

// --- f16

pub const hVec2x8Array = VecArray(2, 8, f16);
pub const hVec3x8Array = VecArray(3, 8, f16);
pub const hVec4x8Array = VecArray(4, 8, f16);

// --- f32

pub const fVec2x4Array = VecArray(2, 4, f32);
pub const fVec3x4Array = VecArray(3, 4, f32);
pub const fVec4x4Array = VecArray(4, 4, f32);

// ------ 256 bit ------

// --- f16

pub const hVec2x16Array = VecArray(2, 16, f16);
pub const hVec3x16Array = VecArray(3, 16, f16);
pub const hVec4x16Array = VecArray(4, 16, f16);

// --- f32

pub const fVec2x8Array = VecArray(2, 8, f32);
pub const fVec3x8Array = VecArray(3, 8, f32);
pub const fVec4x8Array = VecArray(4, 8, f32);

// --- f64

pub const dVec2x4Array = VecArray(2, 4, f64);
pub const dVec3x4Array = VecArray(3, 4, f64);
pub const dVec4x4Array = VecArray(4, 4, f64);

// ------------------------------------------------------------------------------------------------------- type function

pub fn VecArray(comptime vec_len: comptime_int, comptime vec_width: comptime_int, comptime ScalarType: type) type {

    return struct {

        const VecArrayType = @This();

        items: []MultiVec(vec_len, vec_width, ScalarType) = undefined,
        vector_ct: usize = undefined,
        // if set using fromResult(), this denotes the index at which the ranged results begin. so, if the result was
        // ranged to vector indices 2-9, this will be 2 and vector_ct will be 8. this is very, very important to pay
        // attention to when doing ranged math operations. for example, in order to preserve index-correct information
        // when chaining multiple ranged ops, successive ops will need the same range as the first op, and in the end
        // the desired results begin at this offset.
        result_offset: usize = 0, 

// ---------------------------------------------------------------------------------------------------------------- init

        pub inline fn new(vec_ct: usize, allocator: *const std.mem.Allocator) !VecArrayType {
            std.debug.assert(vec_ct > 0);
            const array_ct = vecCtToMultiVecCt(vec_ct);
            return VecArrayType {
                .items = try allocator.alloc(MultiVec(vec_len, vec_width, ScalarType), array_ct),
                .vector_ct = vec_ct,
            };
        }

        // takes ownership of a result's memory, resets it, and returns a VecArray preserving the properties of
        // the result. !! if the result's range started on an index s.t. vec_start % vec_width != 0, result_offset
        // will be set to a nonzero number denoting the index at which the desired results begin. vector_ct will
        // include the first few undesired vectors (n = result_offset). doing things this way trades incredibly slow
        // copy-backs for a slightly less convenient system.
        pub inline fn fromResult(
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) VecArrayType {
            defer blk: {
                result.items = null;
                break :blk result.reset();
            }
            const multi_diff = result.range.end - result.range.start;
            return VecArrayType {
                .items = result.items.?[0..result.items.?.len],
                .vector_ct = multi_diff * vec_width + result.range.vec_end,
                .result_offset = result.range.vec_start,
            };
        }

        pub inline fn zero(self: *VecArrayType) void {
            for (0..self.items.len) |i| {
                self.items[i] = std.mem.zeroes(MultiVec(vec_len, vec_width, ScalarType));
            }
        }

// -------------------------------------------------------------------------------------------------------- reallocation

        pub inline fn resize(self: *VecArrayType, vec_ct: usize, allocator: *const std.mem.Allocator) void {
            std.debug.assert(vec_ct > 0);
            const array_ct = vecCtToMultiVecCt(vec_ct);
            if (array_ct != self.items.len) {
                self.items = try allocator.realloc(self.items, array_ct);
            }
            self.vector_ct = vec_ct; 
        }

        pub inline fn shrink(self: *VecArrayType, allocator: *const std.mem.Allocator) void {
            if (self.items.len > 0) {
                const multivec_ct = vecCtToMultiVecCt(self.vector_ct);
                if (multivec_ct < self.items.len) {
                    self.items = try allocator.realloc(self.items, multivec_ct);
                }
            }
            self.vector_ct = self.items.len * vec_width;
        }

// -------------------------------------------------------------------------------------------------------------- counts

        pub inline fn vectorCt(self: *const VecArrayType) usize {
            return self.vector_ct - self.result_offset;
        }

        pub inline fn allocCt(self: *const VecArrayType) usize {
            return self.items.len * vec_width;
        }

// -------------------------------------------------------------------------------------------------- get/set/add/remove

        pub fn getRange(self: *VecArrayType, vectors: []Vec(vec_len, ScalarType), boundaries: anytype) void {
            var range = VARange{};
            boundariesToRange(boundaries, @as(usize, vectors.len), &range);
            std.debug.assert(self.dbgValidateRange(&range));

            if (range.start == range.end) {
                var multi_vec: *MultiVec(vec_len, vec_width, ScalarType) = &self.items[range.start];
                for (range.vec_start..range.vec_end) |i| {
                    const vector_offset: usize = i - range.vec_start;
                    vectors[vector_offset] = multi_vec.vector(i);
                }
            }
            else {
                var vec_idx: usize = 0;
                for (range.start..range.end + 1) |i| {
                    var multi_vec: *MultiVec(vec_len, vec_width, ScalarType) = &self.items[i];
                    if (i == range.start) {
                        for (range.vec_start..vec_width) |j| {
                            vectors[vec_idx] = multi_vec.vector(j);
                            vec_idx += 1;
                        }
                    }
                    else if (i == range.end) {
                        for (0..range.vec_end) |j| {
                            vectors[vec_idx] = multi_vec.vector(j);
                            vec_idx += 1;
                        }
                    }
                    else for (0..vec_width) |j| {
                        vectors[vec_idx] = multi_vec.vector(j);
                        vec_idx += 1;
                    }
                }
            }
        }

        pub fn setRange(self: *VecArrayType, vectors: []const Vec(vec_len, ScalarType), boundaries: anytype) void {
            var range = VARange{};
            boundariesToRange(boundaries, @as(usize, vectors.len), &range);
            std.debug.assert(self.dbgValidateRange(&range));

            if (range.start == range.end) {
                var multi_vec: *MultiVec(vec_len, vec_width, ScalarType) = &self.items[range.start];
                for (range.vec_start..range.vec_end) |i| {
                    const vector_offset: usize = i - range.vec_start;
                    multi_vec.setSingle(vectors[vector_offset], i);
                }
            }
            else {
                var vec_idx: usize = 0;
                for (range.start..range.end + 1) |i| {
                    var multi_vec: *MultiVec(vec_len, vec_width, ScalarType) = &self.items[i];
                    if (i == range.start) {
                        for (range.vec_start..vec_width) |j| {
                            multi_vec.setSingle(vectors[vec_idx], j);
                            vec_idx += 1;
                        }
                    }
                    else if (i == range.end) {
                        for (0..range.vec_end) |j| {
                            multi_vec.setSingle(vectors[vec_idx], j);
                            vec_idx += 1;
                        }
                    }
                    else for (0..vec_width) |j| {
                        multi_vec.setSingle(vectors[vec_idx], j);
                        vec_idx += 1;
                    }
                }
            }
        }

        // copies data from the provided result, using the same ranges as the result. if instead you want to make
        // a new VecArray using the result's allocation, use fromResult()
        pub fn copyResult(
            self: *VecArrayType, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            if (result.range.start == result.range.end) {
                self.items[result.start].setRangeFromMulti(&result.items[0], result.range.vec_start, result.range.vec_end);
            }
            else {
                const exclusive_end = result.range.end + 1;
                var result_idx: usize = 0;
                for (result.range.start..exclusive_end) |i| {
                    if (i == result.range.start) {
                        self.items[i].setRangeFromMulti(&result.items[0], result.range.vec_start, vec_width);
                    }
                    else if (i == result.range.end) {
                        self.items[i].setRangeFromMulti(&result.items[result_idx], 0, result.range.vec_end);
                    }
                    else {
                        self.items[i] = result.items[result_idx];
                    }
                    result_idx += 1;
                }
            }
        }

        pub inline fn getSingle(self: *const VecArrayType, idx: usize) Vec(vec_len, ScalarType) {
            var array_idx: usize = undefined;
            var in_array_idx: usize = undefined;
            vecIdxToArrayIndices(idx + self.result_offset, &array_idx, &in_array_idx);
            return self.items[array_idx].vector(in_array_idx);
        }
       
        pub inline fn setSingle(self: *VecArrayType, vec: Vec(vec_len, ScalarType), idx: usize) void {
            var array_idx: usize = undefined;
            var in_array_idx: usize = undefined;
            vecIdxToArrayIndices(idx + self.result_offset, &array_idx, &in_array_idx);
            var multi_vec: *MultiVec(vec_len, vec_width, ScalarType) = &self.items[array_idx];
            multi_vec.setSingle(vec, in_array_idx);
        }

        pub fn removeSingle(self: *VecArrayType, vec_idx: usize) usize {
            const true_idx = vec_idx + self.result_offset;
            std.debug.assert(true_idx < self.vector_ct);
            self.vector_ct -= 1;
            var rm_array_idx: usize = undefined;
            var rm_in_array_idx: usize = undefined;
            vecIdxToArrayIndices(true_idx, &rm_array_idx, &rm_in_array_idx);
            var cb_array_idx: usize = undefined;
            var cb_in_array_idx: usize = undefined;
            vecIdxToArrayIndices(self.vector_ct, &cb_array_idx, &cb_in_array_idx);
            var rm_multi_vec = &self.items[rm_array_idx];
            var last_multi_vec = &self.items[cb_array_idx];
            rm_multi_vec.setSingleFromMulti(&last_multi_vec, rm_in_array_idx, cb_in_array_idx);
            return self.vector_ct;
        }

        pub inline fn pushSingle(self: *VecArrayType, vec: Vec(vec_len, ScalarType)) void {
            std.debug.assert(self.vector_ct < self.items.len * vec_width);
            var add_array_idx: usize = undefined;
            var add_in_array_idx: usize = undefined;
            vecIdxToArrayIndices(self.vector_ct, &add_array_idx, &add_in_array_idx);
            var multi_vec = &self.items[add_array_idx];
            multi_vec.setSingle(vec, add_in_array_idx);
            self.vector_ct += 1;
        }

        pub fn swap(self: *VecArrayType, idx_a: usize, idx_b: usize) void {
            const true_idx_a = idx_a + self.result_offset;
            const true_idx_b = idx_b + self.result_offset;
            std.debug.assert(true_idx_a < self.vector_ct and true_idx_b < self.vector_ct);
            var a_array_idx: usize = undefined;
            var a_in_array_idx: usize = undefined;
            vecIdxToArrayIndices(true_idx_a, &a_array_idx, &a_in_array_idx);
            var b_array_idx: usize = undefined;
            var b_in_array_idx: usize = undefined;
            vecIdxToArrayIndices(true_idx_b, &b_array_idx, &b_in_array_idx);
            self.items[a_array_idx].swapSingle(&self.items[b_array_idx], a_in_array_idx, b_in_array_idx);
        }

// ---------------------------------------------------------------------------------------------------------------- math

        pub inline fn mul(self: *const VecArrayType, vec: anytype) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (0..self.items.len) |i| {
                multiMul(&self.items[i], &vec_multi, &self.items[i]);
            }
        }

        pub inline fn add(self: *const VecArrayType, vec: anytype) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (0..self.items.len) |i| {
                multiAdd(&self.items[i], &vec_multi, &self.items[i]);
            }
        }

        pub inline fn sub(self: *const VecArrayType, vec: anytype) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (0..self.items.len) |i| {
                multiSub(&self.items[i], &vec_multi, &self.items[i]);
            }
        }

        pub inline fn subFrom(self: *const VecArrayType, vec: anytype) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (0..self.items.len) |i| {
                multiSub(&vec_multi, &self.items[i], &self.items[i]);
            }
        }

        pub inline fn mulc(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiMul(&self.items[i], &vec_multi, &result.items.?[i]);
            }
        }

        pub inline fn addc(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiAdd(&self.items[i], &vec_multi, &result.items.?[i]);
            }
        }

        pub inline fn subc(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiSub(&self.items[i], &vec_multi, &result.items.?[i]);
            }
        }

        pub inline fn subFromc(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiSub(&vec_multi, &self.items[i], &result.items.?[i]);
            }
        }

        pub inline fn dot(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, ScalarType)
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiDot(&self.items[i], &vec_multi, (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn cross(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, MultiVec(vec_len, vec_width, ScalarType))
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiCross(&self.items[i], &vec_multi, &result.items.?[i]);
            }
        }

        pub inline fn sizeSq(
            self: *const VecArrayType, 
            result: *VAResult(vec_len, vec_width, ScalarType, ScalarType)
        ) void {
            for (result.range.start..result.range.end + 1) |i| {
                multiSizeSq(&self.items[i], (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn size(
            self: *const VecArrayType, 
            result: *VAResult(vec_len, vec_width, ScalarType, ScalarType)
        ) void {
            for (result.range.start..result.range.end + 1) |i| {
                multiSize(&self.items[i], (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn distSq(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, ScalarType)
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiDistSq(&self.items[i], &vec_multi, (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn dist(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, ScalarType)
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiDist(&self.items[i], &vec_multi, (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn nearlyEqual(
            self: *const VecArrayType, 
            vec: anytype, 
            result: *VAResult(vec_len, vec_width, ScalarType, bool)
        ) void {
            var vec_multi = MultiVec(vec_len, vec_width, ScalarType).fromVec(vec);
            for (result.range.start..result.range.end + 1) |i| {
                multiNearlyEqual(&self.items[i], &vec_multi, (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn isNorm(self: *const VecArrayType, result: *VAResult(vec_len, vec_width, ScalarType, bool)) void {
            for (result.range.start..result.range.end + 1) |i| {
                multiIsNorm(&self.items[i], (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn nearlyZero(
            self: *const VecArrayType, 
            result: *VAResult(vec_len, vec_width, ScalarType, bool)
        ) void {
            for (result.range.start..result.range.end + 1) |i| {
                multiNearlyZero(&self.items[i], (result.items.?[i*vec_width..(i+1)*vec_width])[0..vec_width]);
            }
        }

        pub inline fn abs(self: *VecArrayType) void {
            for (0..self.items.len) |i| {
                multiAbs(&self.items[i]);
            }
        }

        pub inline fn negate(self: *VecArrayType) void {
            for (0..self.items.len) |i| {
                multiNegate(&self.items[i]);
            }
        }

        pub inline fn normalizeSafe(self: *VecArrayType) void {
            for (0..self.items.len) |i| {
                multiNormalizeSafe(&self.items[i]);
            }
        }

        pub inline fn normalizeUnsafe(self: *VecArrayType) void {
            for (0..self.items.len) |i| {
                multiNormalizeUnsafe(&self.items[i]);
            }
        }

        pub inline fn clampSize(self: *VecArrayType, scalar: ScalarType) void {
            for (0..self.items.len) |i| {
                multiClampSize(&self.items[i], scalar);
            }
        }

// ------------------------------------------------------------------------------------------------------------- helpers

        inline fn vecCtToMultiVecCt(vec_ct: usize) usize {
            return (vec_ct / @as(usize, vec_width)) 
                + if (vec_ct % @as(usize, vec_width) > @as(usize, 0)) 
                @as(usize, 1) 
                else @as(usize, 0);
        }

        inline fn vecIdxToArrayIndices(vec_idx: usize, array_idx: *usize, in_array_idx: *usize) void {
            if (vec_idx == 0) {
                array_idx.* = 0;
                in_array_idx.* = 0;
            }
            else {
                const idx_div_vec_width = @divTrunc(vec_idx, vec_width);
                const idx_is_multiple_of_vec_width = @intCast(u32, @boolToInt(vec_idx % vec_width == 0));
                array_idx.* = idx_div_vec_width - idx_is_multiple_of_vec_width;
                in_array_idx.* = vec_idx - array_idx.* * vec_width;
            }
        }

        inline fn arrayIndicesToVecIdx(array_idx: usize, in_array_idx: usize, vec_idx: *usize) void {
            vec_idx.* = array_idx * vec_width + in_array_idx;
        }

        fn boundariesToRange(
            boundaries: anytype, 
            vector_ct: usize,
            indices: *VARange
        ) void {
            var vec_start_idx: usize = undefined;
            var vec_end_idx: usize = undefined;
            switch(boundaries.len) {
                0 => {
                    vec_start_idx = 0;
                    vec_end_idx = vector_ct;
                },
                1 => {
                    vec_start_idx = @as(usize, boundaries[0]);
                    vec_end_idx = vec_start_idx + vector_ct;
                },
                2 => {
                    vec_start_idx = @as(usize, boundaries[0]);
                    vec_end_idx = @as(usize, boundaries[1]);
                    std.debug.assert(vec_end_idx - vec_start_idx <= vector_ct);
                },
                else => unreachable,
            }
            vecIdxToArrayIndices(vec_start_idx, &indices.start, &indices.vec_start);
            vecIdxToArrayIndices(vec_end_idx, &indices.end, &indices.vec_end);
        }

        fn dbgValidateRange(self: *const VecArrayType, range: *const VARange) bool {
            var start_idx: usize = undefined;
            var end_idx: usize = undefined;
            arrayIndicesToVecIdx(range.start, range.vec_start, &start_idx);
            arrayIndicesToVecIdx(range.end, range.vec_end, &end_idx);
            return end_idx > start_idx and end_idx <= self.vector_ct;
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

        pub inline fn fromParts(norm: Vec(3, ScalarType), origin_distance: ScalarType) !PlaneType {
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

        pub inline fn fromVec(vec: Vec(4, ScalarType)) QuaternionType {
            return QuaternionType{ .parts = vec.parts };
        }

        // angle in radians. axis must be normalized.
        pub inline fn fromAxisAngle(axis: Vec(3, ScalarType), angle: ScalarType) QuaternionType {
            std.debug.assert(axis.isNorm());
            const half_angle = angle * 0.5;
            const sin_half_angle = std.math.sin(half_angle);
            const cos_half_angle = std.math.cos(half_angle);

            return QuaternionType {.parts = .{
                axis.parts[0] * sin_half_angle,
                axis.parts[1] * sin_half_angle,
                axis.parts[2] * sin_half_angle,
                cos_half_angle
            }};
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

        pub inline fn normSafe(self: *QuaternionType) QuaternionType {
            const size_sq = self.sizeSq();
            if (size_sq <= epsilonSmall(ScalarType)) {
                return zero;
            }
            return QuaternionType{.parts = self.parts * @splat(4, 1.0 / @sqrt(size_sq))};
        }

        pub fn mul(self: *QuaternionType, other: QuaternionType) void {
            const neg_vec: @Vector(4, ScalarType) = .{1.0, 1.0, 1.0, -1.0};
            const wsplat = @splat(4, self.parts[3]) * other.parts;

            const a_shuf1 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){0, 1, 2, 0}) * neg_vec;
            const b_shuf1 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){3, 3, 3, 0});
            const result_1 = @mulAdd(@Vector(4, ScalarType), a_shuf1, b_shuf1, wsplat);

            const a_shuf2 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){1, 2, 0, 1}) * neg_vec;
            const b_shuf2 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){2, 0, 1, 1});
            const result_2 = @mulAdd(@Vector(4, ScalarType), a_shuf2, b_shuf2, result_1);

            const a_shuf3 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){2, 0, 1, 2});
            const b_shuf3 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){1, 2, 0, 2});
            const result_3 = a_shuf3 * b_shuf3;

            self.parts = result_2 - result_3;
            self.normalizeSafe();
        }

        pub fn mulc(self: *const QuaternionType, other: QuaternionType) QuaternionType {
            const neg_vec: @Vector(4, ScalarType) = .{1.0, 1.0, 1.0, -1.0};
            const wsplat = @splat(4, self.parts[3]) * other.parts;

            const a_shuf1 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){0, 1, 2, 0}) * neg_vec;
            const b_shuf1 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){3, 3, 3, 0});
            const result_1 = @mulAdd(@Vector(4, ScalarType), a_shuf1, b_shuf1, wsplat);

            const a_shuf2 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){1, 2, 0, 1}) * neg_vec;
            const b_shuf2 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){2, 0, 1, 1});
            const result_2 = @mulAdd(@Vector(4, ScalarType), a_shuf2, b_shuf2, result_1);

            const a_shuf3 = @shuffle(ScalarType, self.parts, self.parts, @Vector(4, i32){2, 0, 1, 2});
            const b_shuf3 = @shuffle(ScalarType, other.parts, other.parts, @Vector(4, i32){1, 2, 0, 2});
            const result_3 = a_shuf3 * b_shuf3;

            return QuaternionType.init(result_2 - result_3).normSafe();
        }

    // ------------------------------------------------------------------------------------------------------- constants

        pub const zero = QuaternionType.init(.{0.0, 0.0, 0.0, 0.0});
        pub const identity = QuaternionType.new();
        pub const length = 4;

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- Matrix
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------------------------------- convenience aliases

pub const hMat3x3 = Matrix(3, 3, f16);
pub const hMat3x4 = Matrix(3, 4, f16);
pub const hMat4x3 = Matrix(4, 3, f16);
pub const hMat4x4 = Matrix(4, 4, f16);

pub const fMat3x3 = Matrix(3, 3, f32);
pub const fMat3x4 = Matrix(3, 4, f32);
pub const fMat4x3 = Matrix(4, 3, f32);
pub const fMat4x4 = Matrix(4, 4, f32);

pub const dMat3x3 = Matrix(3, 3, f64);
pub const dMat3x4 = Matrix(3, 4, f64);
pub const dMat4x3 = Matrix(4, 3, f64);
pub const dMat4x4 = Matrix(4, 4, f64);

// ------------------------------------------------------------------------------------------------------ type functions

pub fn Matrix(comptime h: comptime_int, comptime w: comptime_int, comptime ScalarType: type) type {

    comptime {
        std.debug.assert(ScalarType == f16 or ScalarType == f32 or ScalarType == f64);
    }

    return struct {

        const MatrixType = @This();

        parts: [h * w]ScalarType = undefined,

        pub inline fn new() MatrixType {
            return zero;
        }

        pub inline fn random(rand: anytype, minmax: ScalarType) MatrixType {
            var mat: MatrixType = undefined;
            for (0..h*w) |i| {
                mat.parts[i] = rand.random().float(ScalarType) * if(rand.random().boolean()) -minmax else minmax;
            }
            return mat;
        }

        pub fn setDiagWithScalar(self: *MatrixType, scalar: ScalarType) void {
            inline for (0..min_dimension) |i| {
                self.parts[i * w + i] = scalar;
            }
        }

        // copy this vector into the diagonal of a new matrix. can be used to make a scaling matrix if 
        // size == vec.len + 1.
        pub fn setDiag(self: *MatrixType, vec: anytype) void {
            const vec_len: comptime_int = @TypeOf(vec).length;
            std.debug.assert(min_dimension >= vec_len);

            inline for (0..vec_len) |i| {
                self.parts[i * w + i] = vec.parts[i];
            }
            return self;
        }

        // copy this vector into the right column of a new matrix. can be used to make a translation matrix if
        // size == vec.len + 1. diagonal entries (except potentially the bottom right if overwritten) are identity.
        pub fn setRightCol(self: *MatrixType, vec: anytype) void {
            const vec_len: comptime_int = @TypeOf(vec).length;
            std.debug.assert(min_dimension >= vec_len);

            inline for (0..vec_len) |i| {
                self.parts[i * w + (w - 1)] = vec.parts[i];
            }
        }

        pub inline fn vMul(self: *const MatrixType, other: Vec(w, ScalarType)) Vec(h, ScalarType) {
            if (h == 4 and w == 4) {
                return self.vMul4x4(other);
            }
            else {
                return self.vMulLoop(other);
            }
        }

        pub fn mMul(
            self: *const MatrixType, 
            other: anytype, 
            out: *Matrix(MatrixType.height, @TypeOf(other.*).width, ScalarType)
        ) void {
            const other_width: comptime_int = @TypeOf(other.*).width;
            var other_transposed: Matrix(other_width, @TypeOf(other.*).height, ScalarType) = undefined;
            other.transpose(&other_transposed);
            inline for (0..h) |i| {
                const selfrow = Vec(w, ScalarType).init(self.parts[i*w..(i+1)*w].*);
                out.parts[i*other_width..(i+1)*other_width].* = other_transposed.vMul(selfrow).parts;
            }
        }

        pub inline fn transpose(self: *const MatrixType, out: *Matrix(w, h, ScalarType)) void {
            switch (h) {
                3 => switch(w) {
                    3 => self.transpose3x3(out),
                    4 => self.transpose3x4(out),
                    else => unreachable,
                },
                4 => switch(w) {
                    3 => self.transpose4x3(out),
                    4 => self.transpose4x4(out),
                    else => unreachable,
                },
                else => unreachable,
            }
        }

        fn transpose3x3(self: *const MatrixType, out: *Matrix(3, 3, ScalarType)) void {
            if (ScalarType == f64) {
                const row01: @Vector(4, ScalarType) = self.parts[0..4].*;
                const row12: @Vector(4, ScalarType) = self.parts[4..8].*;

                const mask0 = @Vector(4, i32){0, 3, -3, 1};
                const mask1 = @Vector(4, i32){-1, -4, 2, -2};

                out.parts[0..4].* = @shuffle(ScalarType, row01, row12, mask0);
                out.parts[4..8].* = @shuffle(ScalarType, row01, row12, mask1);
                out.parts[8] = self.parts[8];
            }
            else {
                const row012: @Vector(8, ScalarType) = self.parts[0..8].*;

                const mask0 = @Vector(8, i32){
                    0, 3, 6, 
                    1, 4, 7, 
                    2, 5
                };
                out.parts[0..8].* = @shuffle(ScalarType, row012, row012, mask0);
                out.parts[8] = self.parts[8];
            }
        }

        fn transpose3x4(self: *const MatrixType, out: *Matrix(w, h, ScalarType)) void {
            if (ScalarType == f64) {
                const mask0 = @Vector(4, i32){0, -1, 2, -3};
                const mask1 = @Vector(4, i32){1, 3, -2, -4};
                const mask2 = @Vector(4, i32){0, -2, 2, -4};

                const row0: @Vector(4, ScalarType) = self.parts[0..4].*;
                const row1: @Vector(4, ScalarType) = self.parts[4..8].*;
                const row2: @Vector(4, ScalarType) = self.parts[8..12].*;

                const temp0 = @shuffle(ScalarType, row0, row1, mask0);
                const temp1 = @shuffle(ScalarType, row1, row2, mask1);
                const temp2 = @shuffle(ScalarType, row2, row0, mask2);

                const mask3 = @Vector(4, i32){0, 1, -1, -2};
                const mask4 = @Vector(4, i32){0, 1, -3, -4};
                const mask5 = @Vector(4, i32){2, 3, -3, -4};
                out.parts[0..4].* = @shuffle(ScalarType, temp0, temp2, mask3);
                out.parts[4..8].* = @shuffle(ScalarType, temp1, temp0, mask4);
                out.parts[8..12].* = @shuffle(ScalarType, temp2, temp1, mask5);
            }
            else {
                const row01: @Vector(8, ScalarType) = self.parts[0..8].*;
                const row12: @Vector(8, ScalarType) = self.parts[4..12].*;

                const mask0 = @Vector(8, i32){0, 4, -5, 1, 5, -6, 2, 6};
                const mask1 = @Vector(4, i32){-7, 3, 7, -8};

                out.parts[0..8].* = @shuffle(ScalarType, row01, row12, mask0);
                out.parts[8..12].* = @shuffle(ScalarType, row01, row12, mask1);
            }
        }

        fn transpose4x3(self: *const MatrixType, out: *Matrix(w, h, ScalarType)) void {
            if (ScalarType == f64) {
                const mask0 = @Vector(4, i32){0, 3, -3, 0};
                const mask1 = @Vector(4, i32){0, 3, -3, 0};
                const mask2 = @Vector(4, i32){1, -1, -4, 0};

                const row01: @Vector(4, ScalarType) = self.parts[0..4].*; 
                const row12: @Vector(4, ScalarType) = self.parts[4..8].*;
                const row23: @Vector(4, ScalarType) = self.parts[8..12].*;

                const temp0 = @shuffle(ScalarType, row01, row12, mask0);
                const temp1 = @shuffle(ScalarType, row12, row23, mask1);
                const temp2 = @shuffle(ScalarType, row12, row23, mask2);

                const mask3 = @Vector(4, i32){0, 1, 2, -2};
                const mask4 = @Vector(4, i32){1, -1, -2, -3};
                const mask5 = @Vector(4, i32){2, -1, -2, -3};
                out.parts[0..4].* = @shuffle(ScalarType, temp0, row23, mask3);
                out.parts[4..8].* = @shuffle(ScalarType, row01, temp1, mask4);
                out.parts[8..12].* = @shuffle(ScalarType, row01, temp2, mask5);
            }
            else {
                const mask0 = @Vector(8, i32){0, 3, 6, -6, 1, 4, 7, -7};
                const mask1 = @Vector(4, i32){2, 5, -5, -8};

                const row012: @Vector(8, ScalarType) = self.parts[0..8].*;
                const row23: @Vector(8, ScalarType) = self.parts[4..12].*;

                out.parts[0..8].* = @shuffle(ScalarType, row012, row23, mask0);
                out.parts[8..12].* = @shuffle(ScalarType, row012, row23, mask1);
            }
        }

        fn transpose4x4(self: *const MatrixType, out: *Matrix(4, 4, ScalarType)) void {
            if (ScalarType == f64) {
                const mask1 = @Vector(4, i32){0, -1, 1, -2};
                const mask2 = @Vector(4, i32){2, -3, 3, -4};

                const row0: @Vector(4, ScalarType) = self.parts[0..4].*;
                const row1: @Vector(4, ScalarType) = self.parts[4..8].*;
                const temp0 = @shuffle(ScalarType, row0, row1, mask1);
                const temp1 = @shuffle(ScalarType, row0, row1, mask2);

                const row2: @Vector(4, ScalarType) = self.parts[8..12].*;
                const row3: @Vector(4, ScalarType) = self.parts[12..16].*;
                const temp2 = @shuffle(ScalarType, row2, row3, mask1);
                const temp3 = @shuffle(ScalarType, row2, row3, mask2);

                const mask3 = @Vector(4, i32){0, 1, -1, -2};
                const mask4 = @Vector(4, i32){2, 3, -3, -4};

                out.parts[0..4].* = @shuffle(ScalarType, temp0, temp2, mask3);
                out.parts[4..8].* = @shuffle(ScalarType, temp0, temp2, mask4);
                out.parts[8..12].* = @shuffle(ScalarType, temp1, temp3, mask3);
                out.parts[12..16].* = @shuffle(ScalarType, temp1, temp3, mask4);
            }
            else {
                const row01: @Vector(8, ScalarType) = self.parts[0..8].*;
                const row23: @Vector(8, ScalarType) = self.parts[8..16].*;

                const mask1 = @Vector(8, i32){
                    0, 4, -1, -5, 
                    1, 5, -2, -6
                };
                const mask2 = @Vector(8, i32){
                    2, 6, -3, -7,
                    3, 7, -4, -8
                };
                out.parts[0..8].* = @shuffle(ScalarType, row01, row23, mask1);
                out.parts[8..16].* = @shuffle(ScalarType, row01, row23, mask2);
            }
        }

        fn vMulLoop(self: *const MatrixType, other: Vec(w, ScalarType)) Vec(h, ScalarType) {
            var out_vec: Vec(h, ScalarType) = undefined;
            inline for (0..h) |i| {
                const row_vec : @Vector(w, ScalarType) = self.parts[i*w..][0..w].*;
                out_vec.parts[i] = @reduce(.Add, other.parts * row_vec);
            }
            return out_vec;
        }

        fn vMul4x4(self: *const MatrixType, other: Vec(4, ScalarType)) Vec(4, ScalarType) {
            if (ScalarType == f64) {
                const row0: @Vector(4, ScalarType) = self.parts[0..4].*;
                const temp0 = row0 * other.parts;
                const row1: @Vector(4, ScalarType) = self.parts[4..8].*;
                const temp1 = row1 * other.parts;
                const row2: @Vector(4, ScalarType) = self.parts[8..12].*;
                const temp2 = row2 * other.parts;
                const row3: @Vector(4, ScalarType) = self.parts[12..16].*;
                const temp3 = row3 * other.parts;

                const mask1 = @Vector(4, i32){0, -1, 1, -2};
                const mask2 = @Vector(4, i32){2, -3, 3, -4};
                const temp4 = @shuffle(ScalarType, temp0, temp1, mask1);
                const temp5 = @shuffle(ScalarType, temp0, temp1, mask2);
                const temp6 = @shuffle(ScalarType, temp2, temp3, mask1);
                const temp7 = @shuffle(ScalarType, temp2, temp3, mask2);

                const mask3 = @Vector(4, i32){0, 1, -1, -2};
                const mask4 = @Vector(4, i32){2, 3, -3, -4};
                const add_row0 = @shuffle(ScalarType, temp4, temp6, mask3);
                const add_row1 = @shuffle(ScalarType, temp4, temp6, mask4);
                const add_row2 = @shuffle(ScalarType, temp5, temp7, mask3);
                const add_row3 = @shuffle(ScalarType, temp5, temp7, mask4);
                return Vec(4, ScalarType).init(add_row0 + add_row1 + add_row2 + add_row3);
            }
            else { 
                const vecparts_mask = @Vector(8, i32){0, 1, 2, 3, 0, 1, 2, 3};
                const vecparts_8 = @shuffle(ScalarType, other.parts, other.parts, vecparts_mask);
                const row01: @Vector(8, ScalarType) = self.parts[0..8].*;
                const row23: @Vector(8, ScalarType) = self.parts[8..16].*;

                const temp1 = vecparts_8 * row01;
                const temp2 = vecparts_8 * row23;

                const mask1 = @Vector(8, i32){
                    0, 4, -1, -5, 
                    1, 5, -2, -6
                };
                const mask2 = @Vector(8, i32){
                    2, 6, -3, -7, 
                    3, 7, -4, -8
                };
                const temp3: @Vector(8, ScalarType) = @shuffle(ScalarType, temp1, temp2, mask1);
                const temp4: @Vector(8, ScalarType) = @shuffle(ScalarType, temp1, temp2, mask2);
                const temp6 = temp3 + temp4;

                const mask3 = @Vector(4, i32){0, 1, 2, 3};
                const mask4 = @Vector(4, i32){4, 5, 6, 7};
                const temp7 = @shuffle(ScalarType, temp6, temp6, mask3);
                const temp8 = @shuffle(ScalarType, temp6, temp6, mask4);

                return Vec(4, ScalarType).init(temp7 + temp8);
            }
        }

        // pub inline fn fromQuaternion(quat: Quaternion(ScalarType)) MatrixType {
        //     switch (h) {
        //         3 => switch(w) {
        //             3 => return fromQuaternion3x3(quat),
        //             else => unreachable,
        //         },
        //         4 => switch(w) {
        //             4 => return fromQuaternion4x4(quat),
        //             else => unreachable,
        //         },
        //         else => unreachable,
        //     }
        // }

        // fn fromQuaternion3x3(quat: Quaternion(ScalarType)) MatrixType {

        // }
        pub fn fromQuaternion4x4(quat: Quaternion(ScalarType)) MatrixType {
            // if (ScalarType == f64) {
                const y_squared = quat.parts[1] * quat.parts[1];
                const shuf1 = @shuffle(ScalarType, quat.parts, quat.parts, @Vector(4, i32){0, 3, 2, 0});
                // x^2, yw, z^2, xw
                const prod1 = quat.parts * shuf1;

                const shuf3 = @shuffle(ScalarType, prod1, prod1, @Vector(4, i32){0, 2, 2, 1});
                const load1 = @Vector(4, ScalarType){y_squared, y_squared, shuf3[0], 0};
                const sum1 = @splat(4, @as(ScalarType, 2.0)) * (shuf3 + load1);

                // xz, xy, yz, zw
                const shuf2 = @shuffle(ScalarType, quat.parts, quat.parts, @Vector(4, i32){3, 0, 1, 2});
                const prod2 = quat.parts * shuf2;

                const alt_neg = @Vector(4, ScalarType){1.0, -1.0, 1.0, -1.0};
                const shuf4 = @shuffle(ScalarType, prod2, prod2, @Vector(4, i32){2, 2, 1, 1});
                const shuf5 = @shuffle(ScalarType, prod2, prod1, @Vector(4, i32){-4, -4, 3, 3}) * alt_neg;
                // [ yz + xw |#| yz - yw |#| xy + zw |#| xy - zw ]
                const base_2 = @splat(4, @as(ScalarType, 2.0)) * (shuf4 + shuf5);
                
                const sub_vec = @Vector(4, ScalarType){1.0, 1.0, 1.0, 2.0 * prod2[0]};
                // [ 1 - 2(x^2 + y^2) |#| 1 - 2(z^2 + y^2) |#| 1 - 2(x^2 + z^2) |#| 2(xz - yw) ]
                const base_1 = sub_vec - sum1;

                const _2xz_plus_zw = 2.0 * (prod2[0] + prod2[3]);

                var mat: MatrixType = undefined;
                const col1 = @Vector(4, ScalarType){base_1[1], base_2[3], _2xz_plus_zw, 0.0};
                mat.parts[0..4].* = col1;
                // putting a zero in
                const base_2b = @shuffle(ScalarType, base_2, col1, @Vector(4, i32){0, 1, 2, -4});
                mat.parts[4..8].* = @shuffle(ScalarType, base_1, base_2b, @Vector(4, i32){-3, 2, -2, -4});
                mat.parts[8..12].* = @shuffle(ScalarType, base_1, base_2b, @Vector(4, i32){3, -1, 0, -4});
                mat.parts[12..16].* = @Vector(4, ScalarType){0.0, 0.0, 0.0, 1.0};

                return mat; 
            // }
            // else {
                // TODO: 8-len
                // const mask0 = @Vetctor(i32, 8){0, 1, 2, 3, 0, 1, 2, 3};
                // const temp0 = @shuffle(ScalarType, quat.parts, quat.parts, mask0);
            // }
        }

        pub fn format(
            self: MatrixType, 
            comptime _: []const u8, 
            _: std.fmt.FormatOptions, 
            writer: anytype
        ) std.os.WriteError!void {
            inline for(0..h) |i| {
                inline for (0..w) |j| {
                    try writer.print(" {d:>16.3}", .{self.parts[i * w + j]});
                }
                if (i != h - 1) {
                    try writer.print("\n", .{});
                }
            }
        }



    // ------------------------------------------------------------------------------------------------------- constants

        pub const height = h;
        pub const width = w;
        pub const min_dimension = @min(w, h);
        pub const zero = MatrixType{.parts = std.mem.zeroes([h * w]ScalarType)};
        pub const identity = blk: {
            var mat = std.mem.zeroes(MatrixType);
            for (0..@min(w, h)) |i| {
                mat.parts[i * w + i] = 1.0;
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
    // var q1 = fQuat.init(.{1.0, 2.0, 3.0, 4.0});
    // var m1 = fMat4x4.fromQuaternion(q1);
    // _ = m1;
    // print("\n{any}\n", .{m1});
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
    var v4 = fVec3.new();
    v4.replicate(v2, false);
    var v5 = fVec4.new();
    v5.replicate(v2, false);
    var v6 = fVec2.new();
    v6.replicate(v2, false);
    
    try expect(vf3zero.dist(v1) < epsilonSmall(f32));
    try expect(@fabs(v2.x()) < epsilonSmall(f32) and @fabs(v2.y() - 1.0) < epsilonSmall(f32) and @fabs(v2.z() - 2.0) < epsilonSmall(f32));
    try expect(@fabs(v3.x() - 3.0001) < epsilonSmall(f32) and @fabs(v3.y() - 3.0001) < epsilonSmall(f32) and @fabs(v3.z() - 3.0001) < epsilonSmall(f32));
    try expect(v4.dist(v2) < epsilonSmall(f32) and v4.distSq(v2) < epsilonSmall(f32));
    try expect(v5.dist3d(v2) < epsilonSmall(f32) and v5.distSq3d(v2) < epsilonSmall(f32) and @fabs(v5.w()) < epsilonSmall(f32));
    try expect(v6.dist2d(v2) < epsilonSmall(f32) and v6.distSq2d(v2) < epsilonSmall(f32));

    var v7 = iVec3(i32).new();
    var v8 = uVec3(u32).new();
    v7.replicate(v3, false);
    v8.replicate(v3, false);
    var v9 = dVec3.new();
    v9.replicate(v7, false);
    var v9a = dVec3.new();
    v9a.replicate(v3, false);

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

    var va = fVec2.new();
    var vb = fVec2.new();
    var vc = fVec2.new();
    var vd = fVec2.new();
    va.replicate(vf4_sum, false);
    vb.replicate(vf4_dif, false);
    vc.replicate(vf4_prd, false);
    vd.replicate(vf4_qot, false);

    try expect(v10sum.nearlyEqualAutoTolerance(va));
    try expect(v10dif.nearlyEqualAutoTolerance(vb));
    try expect(v10prd.nearlyEqualAutoTolerance(vc));
    try expect(v10qot.nearlyEqualAutoTolerance(vd));

    var ve = fVec3.new();
    var vf = fVec3.new();
    var vg = fVec3.new();
    var vh = fVec3.new();
    ve.replicate(vf4_sum, false);
    vf.replicate(vf4_dif, false);
    vg.replicate(vf4_prd, false);
    vh.replicate(vf4_qot, false);

    try expect(v11sum.nearlyEqualAutoTolerance(ve));
    try expect(v11dif.nearlyEqualAutoTolerance(vf));
    try expect(v11prd.nearlyEqualAutoTolerance(vg));
    try expect(v11qot.nearlyEqualAutoTolerance(vh));

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

    const test1: @Vector(4, f32) = .{0.0, 0.0, 0.0, 0.0};
    var test2 = fVec4.init(test1);
    _ = test2;
}

test "Multi Vec" {
    var v1 = fVec2x4.new();
    multiNormalizeSafe(&v1);
    var v2 = fVec2x4.fromVec(fVec2.init(.{1.0, 2.0}));
    multiAdd(&v1, &v2, &v1);

    var vw1 = fVec2x4.fromScalar(9.0);
    v2.setRangeFromMulti(&vw1, 0, 2);
    print("** v2 **\n", .{});
    print("{any}\n", .{v2});

    var r1: [8]f32 = undefined;
    multiDot(&v1, &v2, r1[0..4]);
    for (4..8) |i| {
        r1[i] = 1.5;
    }
    print("\nr1:\n{any}\n", .{r1});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var vectors: [8]fVec3 = undefined;
    for (0..8) |i| {
        vectors[i].set(.{1.0, 2.0, 3.0});
    }
    var arr1 = try fVec3x4Array.new(8, &allocator);
    arr1.zero();
    arr1.setRange(&vectors, .{});
    // print("\nvec array:\n{any}\n", .{arr1});

    var vectors2: [9]fVec4 = undefined;
    for (0..9) |i| {
        vectors2[i].set(.{1.0, 2.0, 3.0, 4.0});
    }
    var arr2 = try fVec4x4Array.new(10, &allocator);
    arr2.zero();
    arr2.setRange(&vectors2, .{});
    // print("\nvec array 2:\n{any}\n", .{arr2});
    
    var vectors3: [12]fVec4 = undefined;
    for (0..12) |i| {
        vectors3[i].set(.{4.0, 3.0, 2.0, 1.0});
    }
    arr2.setRange(&vectors3, .{0, 10});

    print("\nvec array2:\n", .{});
    for (0..arr2.items.len) |i| {
        print("{any}\n", .{arr2.items[i]});
    }

    var r2 = fVAScalarResult4x4.new();
    try r2.init(&arr2, &allocator);
    arr2.dot(vectors3[0], &r2);

    print("\ndot result:\n", .{});
    for (0..r2.lengthSingleResults()) |i| {
        print("{d}\n", .{r2.item(i)});
    }

    print("\nout of range dot result:\n", .{});
    for (0..r2.items.?.len) |i| {
        print("{d}\n", .{r2.items.?[i]});
    }

    const perf_test_ct: usize = 1024;

    var arr3 = try fVec3x4Array.new(perf_test_ct, &allocator);
    arr3.zero();
    var vectors4: [perf_test_ct]fVec3 = undefined;
    {
        for (0..2048) |i| {
            var t = ScopeTimer.start("getRange()", getScopeTimerID());
            defer t.stop();
            _ = i;
            arr3.getRange(&vectors4, .{});
        }
    }
    print("{any}\n", .{vectors4[0]});

    var vtest1 = vectors4[0];
    var vtestresult1: [perf_test_ct]f32 = undefined;
    {
        for (0..perf_test_ct) |i| {
            vtestresult1[i] = 1.0;
        }
    }
    print("{d}\n", .{vtestresult1[0]});
    {
        for (0..2048) |i| {
            _ = i;
            var t = ScopeTimer.start("dot()", getScopeTimerID());
            defer t.stop();
            for (0..perf_test_ct) |j| {
                vtestresult1[j] = vtest1.dot(vectors4[j]);
            }
        }
    }
    print("{d}\n", .{vtestresult1[0]});
    {
        var result = fVAScalarResult3x4.new();
        for (0..2048) |i| {
            _ = i;
            var t = ScopeTimer.start("multidotx4()", getScopeTimerID());
            defer t.stop();
            try result.init(&arr3, &allocator);
            arr3.dot(vtest1, &result);
        }
        print("{d}\n", .{result.items.?[0]});
    }
    var arr4 = try fVec3x8Array.new(perf_test_ct, &allocator);
    arr4.zero();
    {
        var result = fVAScalarResult3x8.new();
        for (0..2048) |i| {
            _ = i;
            var t = ScopeTimer.start("multidotx8()", getScopeTimerID());
            defer t.stop();
            try result.init(&arr4, &allocator);
            arr4.dot(vtest1, &result);
        }
        print("{d}\n", .{result.items.?[0]});
    }

    const cross_result_ct: usize = 1024;
    var cross_results_single: [cross_result_ct]fVec3 = undefined;
    // var cross_results_multi: [cross_result_ct/8]fVec3x8 = undefined;

    var rand = Prng.init(0);
    var cross_inputs: [cross_result_ct]fVec3 = undefined;
    for (0..cross_result_ct) |i| {
        cross_inputs[i].set(.{rand.random().float(f32) * 1000.0, rand.random().float(f32), rand.random().float(f32)});
        if (rand.random().boolean()) {
            cross_inputs[i].parts[0] = -cross_inputs[i].parts[0];
        }
        if (rand.random().boolean()) {
            cross_inputs[i].parts[1] = -cross_inputs[i].parts[1];
        }
        if (rand.random().boolean()) {
            cross_inputs[i].parts[2] = -cross_inputs[i].parts[2];
        }
    }

    var cross_with = fVec3.init(.{rand.random().float(f32) * 1000.0, rand.random().float(f32) * 1000.0, rand.random().float(f32) * 1000.0});

    var arr_cross = try fVec3x8Array.new(cross_result_ct, &allocator);
    arr_cross.setRange(&cross_inputs, .{});

    {
        var result = fVAMultiResult3x8.new();
        for (0..2048) |i| {
            _ = i;
            var t = ScopeTimer.start("multiCrossx8()", getScopeTimerID());
            defer t.stop();
            try result.init(&arr_cross, &allocator);
            arr_cross.cross(cross_with, &result);
        }
        print("{any}\n", .{result.items.?[0]});
        const from_test = fVec3x8Array.fromResult(&result);
        _ = from_test;
    }
    {
        for (0..2048) |i| {
            _ = i;
            var t = ScopeTimer.start("cross()", getScopeTimerID());
            defer t.stop();
            for (0..cross_result_ct) |j| {
                cross_results_single[j] = cross_inputs[j].cross(cross_with);
            }
        }
    }
    print("{any}\n", .{cross_results_single[0]});
    

    benchmark.printAllScopeTimers();
}

pub fn testQuaternion() void {
    var q1 = fQuat.init(.{0.0, 1.0, 2.0, 3.0});
    var q2 = fQuat.init(.{4.0, 5.0, 6.0, 7.0});
    // print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
    q1.mul(q2);
    // print("\nq1\n{any}\nq2\n{any}\n", .{q1, q2});
}

test "testQuaternion" {
    var q1 = fQuat.init(.{0.0, 1.0, 2.0, 3.0});
    var q2 = fQuat.init(.{4.0, 5.0, 6.0, 7.0});
    q1.mul(q2);

}

test "Matrix" {
    var rand = Prng.init(0);

    const mul_vec_ct: usize = 2048;
    const iter_ct = 2048;
    var m1 = fMat4x4.identity;
    var mul_vectors: [mul_vec_ct]fVec4 = undefined;
    for (0..mul_vec_ct) |i| {
        mul_vectors[i].set(.{
            rand.random().float(f32) * 100.0,
            rand.random().float(f32) * 100.0,
            rand.random().float(f32) * 100.0,
            rand.random().float(f32) * 100.0
        });
        if (rand.random().boolean()) {
            mul_vectors[i].parts[0] = -mul_vectors[i].parts[0];
        }
        if (rand.random().boolean()) {
            mul_vectors[i].parts[1] = -mul_vectors[i].parts[1];
        }
        if (rand.random().boolean()) {
            mul_vectors[i].parts[2] = -mul_vectors[i].parts[2];
        }
        if (rand.random().boolean()) {
            mul_vectors[i].parts[3] = -mul_vectors[i].parts[3];
        }
    }

    var result_vectors: [mul_vec_ct]fVec4 = undefined;
    for (0..mul_vec_ct) |i| {
        result_vectors[i].scalarFill(1.0);
    }

    {
        for (0..iter_ct) |i| {
            _ = i;
            var t = ScopeTimer.start("matrix mul 4x4", getScopeTimerID());
            defer t.stop();

            for (0..mul_vec_ct) |j| {
                result_vectors[j] = m1.vMulLoop(mul_vectors[j]);
            }
        }
        print("{any}\n", .{result_vectors[0]});
    }
    {
        for (0..iter_ct) |i| {
            _ = i;
            var t = ScopeTimer.start("matrix mul 4x4 simd", getScopeTimerID());
            defer t.stop();

            for (0..mul_vec_ct) |j| {
                result_vectors[j] = m1.vMul(mul_vectors[j]);
            }
        }
        print("{any}\n", .{result_vectors[0]});
    }

    var randmat = fMat4x4.random(&rand, 100.0);
    var result1 = randmat.vMul(mul_vectors[0]);
    var result2 = randmat.vMulLoop(mul_vectors[0]);
    print("\n\nresult 1\n{any}\n", .{result1});
    print("result 2\n{any}\n", .{result2});
    // try expect(result1.dist(result2) < epsilonMedium(f32));


    var randvec = fVec3.random(&rand, 100.0);
    var randmat2 = fMat3x3.random(&rand, 100.0);
    var result3 = randmat2.vMul(randvec);
    var result4 = randmat2.vMulLoop(randvec);
    print("\n\nresult 3\n{any}\n", .{result3});
    print("result 4\n{any}\n", .{result4});
    try expect(result3.dist(result4) < epsilonMedium(f32));

    var mul_vecs2: [mul_vec_ct]fVec3 = undefined;
    for (0..mul_vec_ct) |i| {
        mul_vecs2[i] = fVec3.random(&rand, 100.0);
    }

    var result_vectors2: [mul_vec_ct]fVec3 = undefined;
    for (0..mul_vec_ct) |i| {
        result_vectors2[i].scalarFill(1.0);
    }

    var randmat3f = fMat4x4.random(&rand, 1.0);
    var randmat3ft: fMat4x4 = undefined;
    randmat3f.transpose(&randmat3ft);
    var randmat3d = dMat4x4.random(&rand, 1.0);
    var randmat3dt: dMat4x4 = undefined;
    randmat3d.transpose(&randmat3dt);


    // const test_allocator = std.heap.testAllocator;
    // const mat_str = try std.fmt.allocPrint(test_allocator, )
    print("\n 4x4:\n{s}\n", .{randmat3f});
    print("\n 4x4 t:\n{s}\n", .{randmat3ft});

    var randmat4f = fMat3x4.random(&rand, 1.0);
    var randmat4ft: fMat4x3 = undefined;
    randmat4f.transpose(&randmat4ft);
    var randmat4ftt: fMat3x4 = undefined;
    randmat4ft.transpose(&randmat4ftt);

    print("\n 3x4:\n{s}\n", .{randmat4f});
    print("\n3x4 t:\n{s}\n", .{randmat4ft});
    print("\n3x4 tt:\n{s}\n", .{randmat4ftt});

    randmat3f.mMul(&randmat3ft, &randmat3f);

    var randmat5f = fMat3x3.new();
    randmat4f.mMul(&randmat4ft, &randmat5f);

    const q1 = fQuat.fromAxisAngle(fVec3.up, math.pi * 0.5);
    const mq1 = fMat4x4.fromQuaternion4x4(q1);
    const vq1 = fVec4.right;
    const vq2 = mq1.vMul(vq1);
    print("\nvq1: {s}\nvq2: {s}\n", .{vq1, vq2});

    // print("\nrandmat3f\n", .{});
    // for (0..4) |i| {
    //     for (0..4) |j| {
    //         print("{d:.2} ", .{randmat3f.parts[i * 4 + j]});
    //     }
    //     print("\n", .{});
    // }
    // print("\nrandmat3f transposed\n", .{});
    // for (0..4) |i| {
    //     for (0..4) |j| {
    //         print("{d:.2} ", .{randmat3ft.parts[i * 4 + j]});
    //     }
    //     print("\n", .{});
    // }
    // print("\nrandmat3d\n", .{});
    // for (0..4) |i| {
    //     for (0..4) |j| {
    //         print("{d:.2} ", .{randmat3d.parts[i * 4 + j]});
    //     }
    //     print("\n", .{});
    // }
    // print("\nrandmat3d transposed\n", .{});
    // for (0..4) |i| {
    //     for (0..4) |j| {
    //         print("{d:.2} ", .{randmat3dt.parts[i * 4 + j]});
    //     }
    //     print("\n", .{});
    // }
    // benchmark.printAllScopeTimers();
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

    // benchmark.printAllScopeTimers();
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
        }
        if (rand.random().boolean()) {
            quats[i].parts[2] *= 10000.0;
        }
        else {
            quats[i].parts[2] *= -10000.0;
        }
        if (rand.random().boolean()) {
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

    // benchmark.printAllScopeTimers();
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