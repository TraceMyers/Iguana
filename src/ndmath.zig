
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------- convenience Vec aliases
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const fVec2 = Vec(2, f32);
pub const fVec3 = Vec(3, f32);
pub const fVec4 = Vec(4, f32);

pub const dVec2 = Vec(2, f64);
pub const dVec3 = Vec(3, f64);
pub const dVec4 = Vec(4, f64);

pub const iVec2 = Vec(2, i32);
pub const iVec3 = Vec(3, i32);
pub const iVec4 = Vec(4, i32);

pub const ilVec2 = Vec(2, i64);
pub const ilVec3 = Vec(3, i64);
pub const ilVec4 = Vec(4, i64);

pub const uVec2 = Vec(2, u32);
pub const uVec3 = Vec(3, u32);
pub const uVec4 = Vec(4, u32);

pub const ulVec2 = Vec(2, u64);
pub const ulVec3 = Vec(3, u64);
pub const ulVec4 = Vec(4, u64);

// TODO: comptime-optimized scalar div possible?
// TODO: is there a way to cast scalar types such that same-bitwidth vector types could do arithmetic with each other?
// TODO: ... or just make it easy to convert between them.
// TODO: test @setFloatMode() (a per-scope thing that allows ffast-math optimizations)

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------------- Vec
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn Vec(comptime length: comptime_int, comptime ScalarType: type) type {
    return struct {
        const Self = @This();

        val: @Vector(length, ScalarType) = undefined,

    // ------------------------------------------------------------------------------------------------------------ init

        pub inline fn new() Self {
            return Self{ .val = std.mem.zeroes([length]ScalarType) };
        }

        pub inline fn init(scalars: [length]ScalarType) Self {
            return Self{ .val = scalars };
        }

        pub inline fn fromScalar(scalar: ScalarType) Self {
            return Self{ .val = @splat(length, scalar) };
        }

        pub inline fn fromVec(vec: anytype) Self {
            const copy_len = @min(@TypeOf(vec).componentLenStatic(), length);
            var self = Self{ .val = std.mem.zeroes([length]ScalarType) };
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..copy_len], @ptrCast([*]const ScalarType, &vec.val[0])[0..copy_len]);
            return self;
        }

    // ------------------------------------------------------------------------------------------------------ conversion

        pub inline fn toIntVec(self: *const Self, comptime IntType: type) Vec(length, IntType) {
            var int_vec: Vec(length, IntType) = undefined;
            inline for(0..length) |i| {
                int_vec.val[i] = @floatToInt(IntType, self.val[i]);
            }
            return int_vec;
        }

        pub inline fn toFloatVec(self: *const Self, comptime FloatType: type) Vec(length, FloatType) {
            var float_vec: Vec(length, FloatType) = undefined;
            inline for(0..length) |i| {
                float_vec.val[i] = @intToFloat(FloatType, self.val[i]);
            }
            return float_vec;
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn set(self: *Self, scalars: [length]ScalarType) void {
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..length], &scalars);
        }

        pub inline fn scalarFill(self: *Self, scalar: ScalarType) void {
            self.val = @splat(length, scalar);
        }

        pub inline fn copyAssymetric(self: *Self, vec: anytype) void {
            const copy_len = @min(@TypeOf(vec).componentLenStatic(), length);
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

        pub inline fn componentLen(self: *const Self) usize {
            _ = self;
            return length;
        }

    // --------------------------------------------------------------------------------------------------------- statics

        // get the compoment length of this vector. important for use anytime a function can have its branches removed
        // with comptime information.
        pub inline fn componentLenStatic() comptime_int {
            return length;
        }

        pub inline fn epsilonStatic() comptime_float {
            switch(ScalarType) {
                f32 => return 1e-5,
                f64 => return 1e-15,         
                else => unreachable
            }
        }

    // ----------------------------------------------------------------------------------------------- vector arithmetic
    // compile time information throughout these function allows for them to be reduced to branchless execution
    // according to compiler explorer. for example, vAddc() with two vectors of the same length will simply be
    // return Self{ .val = self.val + other.val };

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vAddc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vAddcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vAddcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val + other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vAdd(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vAddLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vAddLoop(self, other);
                    }
                    else {
                        self.val += other.val;
                    }
                },
            }
        }

        // subtract two vectors of same or differing lengths with copy for assignment
        pub inline fn vSubc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vSubcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vSubcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val - other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vSub(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vSubLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vSubLoop(self, other);
                    }
                    else {
                        self.val -= other.val;
                    }
                },
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vMulc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vMulcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vMulcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val * other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vMul(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vMulLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vMulLoop(self, other);
                    }
                    else {
                        self.val *= other.val;
                    }
                },
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vDivc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vDivcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vDivcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val / other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vDiv(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vDivLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vDivLoop(self, other);
                    }
                    else {
                        self.val /= other.val;
                    }
                },
            }
        }

    // ------------------------------------------------------------------------------- explicit length vector arithmetic

        pub inline fn vAdd2dc(self: Self, other: anytype) Self {
            var add_vec: Self = undefined;
            add_vec.val[0] = self.val[0] + other.val[0];
            add_vec.val[1] = self.val[1] + other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &add_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return add_vec;
        }

        pub inline fn vAdd2d(self: *Self, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
        }

        pub inline fn vSub2dc(self: Self, other: anytype) Self {
            var sub_vec: Self = undefined;
            sub_vec.val[0] = self.val[0] - other.val[0];
            sub_vec.val[1] = self.val[1] - other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &sub_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return sub_vec;
        }

        pub inline fn vSub2d(self: *Self, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
        }

        pub inline fn vMul2dc(self: Self, other: anytype) Self {
            var mul_vec: Self = undefined;
            mul_vec.val[0] = self.val[0] * other.val[0];
            mul_vec.val[1] = self.val[1] * other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &mul_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return mul_vec;
        }

        pub inline fn vMul2d(self: *Self, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
        }

        pub inline fn vDiv2dc(self: Self, other: anytype) Self {
            var div_vec: Self = undefined;
            div_vec.val[0] = self.val[0] / other.val[0];
            div_vec.val[1] = self.val[1] / other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &div_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return div_vec;
        }

        pub inline fn vDiv2d(self: *Self, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
        }

        pub inline fn vAdd3dc(self: Self, other: anytype) Self {
            var add_vec: Self = undefined;
            add_vec.val[0] = self.val[0] + other.val[0];
            add_vec.val[1] = self.val[1] + other.val[1];
            add_vec.val[2] = self.val[2] + other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &add_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return add_vec;
        }

        pub inline fn vAdd3d(self: *Self, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
            self.val[2] += other.val[2];
        }

        pub inline fn vSub3dc(self: Self, other: anytype) Self {
            var sub_vec: Self = undefined;
            sub_vec.val[0] = self.val[0] - other.val[0];
            sub_vec.val[1] = self.val[1] - other.val[1];
            sub_vec.val[2] = self.val[2] - other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &sub_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return sub_vec;
        }

        pub inline fn vSub3d(self: *Self, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
            self.val[2] -= other.val[2];
        }

        pub inline fn vMul3dc(self: Self, other: anytype) Self {
            var mul_vec: Self = undefined;
            mul_vec.val[0] = self.val[0] * other.val[0];
            mul_vec.val[1] = self.val[1] * other.val[1];
            mul_vec.val[2] = self.val[2] * other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &mul_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return mul_vec;
        }

        pub inline fn vMul3d(self: *Self, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
            self.val[2] *= other.val[2];
        }

        pub inline fn vDiv3dc(self: Self, other: anytype) Self {
            var div_vec: Self = undefined;
            div_vec.val[0] = self.val[0] / other.val[0];
            div_vec.val[1] = self.val[1] / other.val[1];
            div_vec.val[2] = self.val[2] / other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &div_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return div_vec;
        }

        pub inline fn vDiv3d(self: *Self, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
            self.val[2] /= other.val[2];
        }

    // ----------------------------------------------------------------------------------------------- scalar arithmetic

        pub inline fn sAddc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self + add_vec;
        }

        pub inline fn sAdd(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val += add_vec;
        }

        pub inline fn sSubc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self - add_vec;
        }

        pub inline fn sSub(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val -= add_vec;
        }

        pub inline fn sMulc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self * add_vec;
        }

        pub inline fn sMul(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val *= add_vec;
        }

        pub inline fn sDivc(self: Self, other: ScalarType) Self {
            const mul_scalar = 1.0 / other;
            return self.sMulc(mul_scalar);
        }

        pub inline fn sDiv(self: Self, other: ScalarType) void {
            const mul_scalar = 1.0 / other;
            self.sMul(mul_scalar);
        }

    // -------------------------------------------------------------------------------------------------- linear algebra

        pub inline fn dot(self: Self, other: Self) ScalarType {
            return @reduce(.Add, self.val * other.val);
        }

        pub inline fn dot2d(self: Self, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1];
        }

        pub inline fn dot3d(self: Self, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1] + self.val[2] * other.val[2];
        }

        pub inline fn determinant2d(self: Self, other: Self) ScalarType {
            return self.val[0] * other.val[1] - other.val[0] * self.val[1];
        }

        pub inline fn cross(self: Self, other: Self) Self {
            return Self { .val = @Vector(length, ScalarType){
                self.val[1] * other.val[2] - self.val[2] * other.val[1],
                self.val[2] * other.val[0] - self.val[0] * other.val[2],
                self.val[0] * other.val[1] - self.val[1] * other.val[0]
            }};
        }

    // ------------------------------------------------------------------------------------------------------------ size

        pub inline fn size(self: Self) ScalarType {
            return @sqrt(@reduce(.Add, self.val * self.val));
        }

        pub inline fn sizeSq(self: Self) ScalarType {
            return @reduce(.Add, self.val * self.val);
        }

        pub inline fn size2d(self: Self) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1]);
        }

        pub inline fn sizeSq2d(self: Self) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1];
        }

        pub inline fn size3d(self: Self) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2]);
        }

        pub inline fn sizeSq3d(self: Self) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2];
        }

    // -------------------------------------------------------------------------------------------------------- distance

        pub inline fn dist(self: Self, other: Self) ScalarType {
            const diff = self.val - other.val;
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq(self: Self, other: Self) ScalarType {
            const diff = self.val - other.val;
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist2d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq2d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist3d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq3d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @reduce(.Add, diff * diff);
        }

    // ---------------------------------------------------------------------------------------------------------- normal

        pub inline fn normSafe(self: Self) Self {
            const size_sq = self.sizeSq();
            if (size_sq < @TypeOf(self).epsilonStatic()) {
                return Self.new();
            }
            return self.sMulc(1.0 / @sqrt(size_sq));
        }

        pub inline fn normUnsafe(self: Self) Self {
            return self.sMulc(1.0 / self.size());
        }

        pub inline fn isNorm(self: Self) bool {
            return @fabs(1.0 - self.sizeSq()) < @TypeOf(self).epsilonStatic();
        }

    // --------------------------------------------------------------------------------------------------------- max/min

        pub inline fn componentMax(self: Self) ScalarType {
            return @reduce(.Max, self.val);
        }

        pub inline fn componentMin(self: Self) ScalarType {
            return @reduce(.Min, self.val);
        }

    // -------------------------------------------------------------------------------------------------------- equality

        pub inline fn exactlyEqual(self: Self, other: Self) bool {
            inline for(0..length) |i| {
                if (self.val[i] != other.val[i]) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn nearlyEqual(self: Self, other: Self) bool {
            return self.distSq(other) < Self.componentLenStatic();
        }

    // ------------------------------------------------------------------------------------------------------------ sign

        pub inline fn abs(self: Self) Self {
            var abs_vec = self;
            inline for (0..length) |i| {
                abs_vec.val[i] = @fabs(abs_vec.val[i]);
            }
        }

        pub inline fn flip(self: Self) Self {
            var flip_vec = self;
            inline for (0..length) |i| {
                flip_vec.val[i] = -flip_vec.val[i];
            }
        }

    // ----------------------------------------------------------------------------------------------------------- clamp

        pub fn clampComponents(self: Self, min: ScalarType, max: ScalarType) Self {
            var clamp_vec = self;
            inline for (0..length) |i| {
                clamp_vec.val[i] = std.math.clamp(clamp_vec.val[i], min, max);
            }
        }

        pub fn clampSize(self: Self, max: ScalarType) Self {
            const size_sq = self.sizeSq();
            if (size > max * max) {
                return self.sMulc(max / @sqrt(size_sq));
            }
            return self;
        }

    // ---------------------------------------------------------------------------------------------------- trigonometry

        pub fn cosAngle(self: Self, other: Self) ScalarType {
            const size_product = self.size() * other.size();
            return self.dot(other) / size_product;
        }

        pub fn angle(self: Self, other: Self) ScalarType {
            const size_product = self.size() * other.size();
            return math.acos(self.dot(other) / size_product);
        }

        pub fn cosAnglePrenorm(self: Self, other: Self) ScalarType {
            return self.dot(other);
        }

        pub fn anglePrenorm(self: Self, other: Self) ScalarType {
            return math.acos(self.dot(other));
        }

    // ------------------------------------------------------------------------------------------------------ projection

        pub fn projectOnto(self: Self, other: Self) Self {
            return other.fMulc(self.dot(other) / other.sizeSq());
        }

        pub fn projectOntoNorm(self: Self, other: Self) Self {
            return other.fMulc(self.dot(other));
        }

    // ------------------------------------------------------------------------------------------------------- direction

        pub fn nearlyParallel(self: Self, other: Self) bool {
            const self_norm = self.normSafe();
            const other_norm = other.normSafe();
            return self_norm.dot(other_norm) > (1.0 - Self.epsilonStatic());
        }

        pub inline fn nearlyParallelPrenorm(self_norm: Self, other_norm: Self) bool {
            return self_norm.dot(other_norm) > (1.0 - Self.epsilonStatic());
        }

        pub fn nearlyOrthogonal(self: Self, other: Self) bool {
            const self_norm = self.normSafe();
            const other_norm = other.normSafe();
            return self_norm.dot(other_norm) < Self.epsilonStatic();
        }

        pub inline fn nearlyOrthogonalPrenorm(self_norm: Self, other_norm: Self) bool {
            return self_norm.dot(other_norm) < Self.epsilonStatic();
        }

        pub inline fn similarDirection(self: Self, other: Self) bool {
            return self.dot(other) > Self.epsilonStatic();
        }

    // -------------------------------------------------------------------------------------------------------- internal

        inline fn vAddcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] + vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vAddLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] += vec_b.val[i];
            }
        }

        inline fn vSubcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] - vec_b.val[i];
            }
            return add_vec;
        }

        inline fn vSubLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] -= vec_b.val[i];
            }
        }

        inline fn vMulcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] * vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vMulLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] *= vec_b.val[i];
            }
        }


        inline fn vDivcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] / vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vDivLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
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

const Quaternion = struct {

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 1.0,

    pub fn new() Quaternion {
        return Quaternion{};
    }

    

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------- Square Matrix
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const Identity2x2: [2][2]f32 = .{
    .{1.0, 0.0},
    .{0.0, 1.0},
};

const Identity3x3: [3][3]f32 = .{
    .{1.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0},
    .{0.0, 0.0, 1.0}
};

const Identity4x4: [3][3]f32 = .{
    .{1.0, 0.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0, 0.0},
    .{0.0, 0.0, 1.0, 0.0},
    .{0.0, 0.0, 0.0, 1.0}
};

const Identity5x5: [5][5]f32 = .{
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

        // pub fn fromScaleVec(vec: anytype) Self {
        //     std.debug.assert(size >= vec.len());
        //     var self: Self = std.mem.zeroes(Self);
        //     switch(@TypeOf(vec)) {
        //         Vec2 => {
        //             self.values[0][0] = vec.x;
        //             self.values[1][1] = vec.y;
        //             inline for (2..size) |i| {
        //                 self.values[i][i] = 1.0;
        //             }
        //         },
        //         Vec3 => {
        //             self.values[0][0] = vec.x;
        //             self.values[1][1] = vec.y;
        //             self.values[2][2] = vec.z;
        //             inline for (3..size) |i| {
        //                 self.values[i][i] = 1.0;
        //             }
        //         },
        //         Vec4 => {
        //             self.values[0][0] = vec.values[0];
        //             self.values[1][1] = vec.values[1];
        //             self.values[2][2] = vec.values[2];
        //             self.values[3][3] = vec.values[3];
        //             inline for (4..size) |i| {
        //                 self.values[i][i] = 1.0;
        //             }
        //         },
        //         else => unreachable
        //     }
        //     return self;
        // }

        pub fn fromScalar(scalar: f32) Self {
            var self: Self = std.mem.zeroes(Self);
            inline for (0..size) |i| {
                self.values[i][i] = scalar;
            }
            return self;
        }

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const quaternion_zero = Quaternion{.w = 0.0};
pub const quaternion_identity = Quaternion{};

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

    try expect(v7.x() == 3 and v7.y() == 3 and v7.z() == 3);
    try expect(v8.x() == 3 and v8.y() == 3 and v8.z() == 3);
    try expect(@fabs(v9.x() - 3.0) < F32_EPSILON and @fabs(v9.y() - 3.0) < F32_EPSILON and @fabs(v9.z() - 3.0) < F32_EPSILON);

    v3.set(.{ 4.001, 4.001, 5.001 });
    v6.scalarFill(2.58);

    try expect(@fabs(v3.x() - 4.001) < F32_EPSILON and @fabs(v3.y() - 4.001) < F32_EPSILON and @fabs(v3.z() - 5.001) < F32_EPSILON);
    try expect(@fabs(v6.x() - 2.58) < F32_EPSILON and @fabs(v6.y() - 2.58) < F32_EPSILON);

    v6.copyAssymetric(v3);

    try expect(v6.dist2d(v3) < F32_EPSILON);

    var v10sum = vf2a.vAddc(vf2b);
    var v11sum = vf3a.vAddc(vf3b);
    var v12sum = vf4a.vAddc(vf4b);

    var v10dif = vf2a.vSubc(vf2b);
    var v11dif = vf3a.vSubc(vf3b);
    var v12dif = vf4a.vSubc(vf4b);

    var v10prd = vf2a.vMulc(vf2b);
    var v11prd = vf3a.vMulc(vf3b);
    var v12prd = vf4a.vMulc(vf4b);

    var v10qot = vf2a.vDivc(vf2b);
    var v11qot = vf3a.vDivc(vf3b);
    var v12qot = vf4a.vDivc(vf4b);

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
    v10sum.vAdd(vf2b);
    v11sum.vAdd(vf3b);
    v12sum.vAdd(vf4b);

    v10dif = vf2a;
    v11dif = vf3a;
    v12dif = vf4a;
    v10dif.vSub(vf2b);
    v11dif.vSub(vf3b);
    v12dif.vSub(vf4b);

    v10prd = vf2a;
    v11prd = vf3a;
    v12prd = vf4a;
    v10prd.vMul(vf2b);
    v11prd.vMul(vf3b);
    v12prd.vMul(vf4b);

    v10qot = vf2a;
    v11qot = vf3a;
    v12qot = vf4a;
    v10qot.vDiv(vf2b);
    v11qot.vDiv(vf3b);
    v12qot.vDiv(vf4b);

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

    
}
