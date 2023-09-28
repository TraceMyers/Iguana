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
