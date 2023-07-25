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


pub const RGBA32 = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

pub const fMVP = struct {
    model: fMat4x4 align(16) = undefined,
    view: fMat4x4 align(16) = undefined,
    projection: fMat4x4 align(16) = undefined,
};

const nd = @import("ndmath.zig");
const fMat4x4 = nd.fMat4x4;
const fVec2 = nd.fVec2;
const fVec3 = nd.fVec3;
const LocalArray = @import("array.zig").LocalArray;

pub const c = @cImport({
    @cInclude("glfwvulk.h");
    @cInclude("vk_mem_alloc.h");
});