pub const Vertex = struct {
    position: fVec2 = undefined,
    color: fVec3 = undefined,
    tex_coords: fVec2 = undefined,

    pub inline fn getBindingDescription() c.VkVertexInputBindingDescription {
        return c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate  = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };
    }

    pub inline fn getAttributeDesriptions() [3]c.VkVertexInputAttributeDescription {
        var desc: [3]c.VkVertexInputAttributeDescription = undefined;
        desc[0] = c.VkVertexInputAttributeDescription{
            .location = 0,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "position")
        };
        desc[1] = c.VkVertexInputAttributeDescription{
            .location = 1,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "color")
        };
        desc[2] = c.VkVertexInputAttributeDescription{
            .location = 2,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "tex_coords")
        };
        return desc;
    }
};

// --- Image pixel types ---

const PixelContainerError = error {
    NoAllocatorOnFree,
};

pub const PixelTag = enum { RGB24, RGBA32, R8, R16, R32, RA16, RA32 };

pub const PixelSlice = union(PixelTag) {
    RGB24: ?[]RGB24,
    RGBA32: ?[]RGBA32,
    R8: ?[]R8,
    R16: ?[]R16,
    R32: ?[]R32,
    RA16: ?[]RA16,
    RA32: ?[]RA32,
};

pub const PixelContainer = struct {
    bytes: ?[]u8 = null,
    pixels: PixelSlice = PixelSlice{ .RGB24 = null },
    allocator: ?std.mem.Allocator = null,

    pub fn alloc(self: *PixelContainer, in_allocator: std.mem.Allocator, tag: PixelTag, count: usize) !void {
        switch(tag) {
            .RGB24 => self.pixels = PixelSlice{ .RGB24 = self.allocWithType(in_allocator, RGB24, count) },
            .RGBA32 => self.pixels = PixelSlice{ .RGBA32 = self.allocWithType(in_allocator, RGBA32, count) },
            .R8 => self.pixels = PixelSlice{ .R8 = self.allocWithType(in_allocator, R8, count) },
            .R16 => self.pixels = PixelSlice{ .R16 = self.allocWithType(in_allocator, R16, count) },
            .R32 => self.pixels = PixelSlice{ .R32 = self.allocWithType(in_allocator, R32, count) },
            .RA16 => self.pixels = PixelSlice{ .RA16 = self.allocWithType(in_allocator, RA16, count) },
            .RA32 => self.pixels = PixelSlice{ .RA32 = self.allocWithType(in_allocator, RA32, count) },
        }
    }

    pub fn free(self: *PixelContainer) !void {
        if (self.bytes != null) {
            if (self.allocator == null) {
                return PixelContainerError.NoAllocatorOnFree;
            }
            self.allocator.?.free(self.bytes.?);
        }
        self = PixelContainer{};
    }

    pub inline fn isEmpty(self: *const PixelContainer) bool {
        return self.bytes == null;
    }

    fn allocWithType(
        self: *PixelContainer, in_allocator: std.mem.Allocator, comptime PixelType: type, count: usize
    ) ![]PixelType {
        const sz = @sizeOf(PixelType) * count;
        self.allocator = in_allocator;
        self.bytes = try self.allocator.?.alloc(u8, sz);
        return @ptrCast([*]PixelType, @alignCast(@alignOf(PixelType), &self.bytes[0]))[0..count];
    }
};

pub const RGB24 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
};

pub const RGBA32 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

pub const R8 = extern struct {
    r: u8 = 0,
};

pub const R16 = extern struct {
    r: u16 = 0,
};

pub const R32 = extern struct {
    r: u32 = 0,
};

pub const RA16 = extern struct {
    r: u8 = 0,
    a: u8 = 0,
};

pub const RA32 = extern struct {
    r: u16 = 0,
    a: u16 = 0,
};

// ------------------------

pub const RGB32 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    reserved: u8 = 0,
};

pub const BGR24 = extern struct {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
};

pub const BGR32 = extern struct {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
    reserved: u8 = 0,
};

pub const fMVP = struct {
    model: fMat4x4 align(16) = undefined,
    view: fMat4x4 align(16) = undefined,
    projection: fMat4x4 align(16) = undefined,
};

const kmath = @import("math.zig");
const fMat4x4 = kmath.fMat4x4;
const fVec2 = kmath.fVec2;
const fVec3 = kmath.fVec3;
const LocalArray = @import("array.zig").LocalArray;
const c = @import("ext.zig").c;
const std = @import("std");
