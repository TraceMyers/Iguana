
pub inline fn getVertexInputBindingDescription() c.VkVertexInputBindingDescription {
    return c.VkVertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
    };
}

pub inline fn getAttributeDescriptions(descriptions: *LocalArray(c.VkVertexInputAttributeDescription, 2)) void {
    descriptions.resetCount();
    descriptions.push(c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 0,
        .format = c.VK_FORMAT_R32G32_SFLOAT,
        .offset = @offsetOf(Vertex, "position"),
    });
    descriptions.push(c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 1,
        .format = c.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @offsetOf(Vertex, "color"),
    });
}

const gm = @import("gmath.zig");
const fVec2 = gm.fVec2;
const fVec3 = gm.fVec3;
const array = @import("array.zig");
const LocalArray = array.LocalArray;
const gfxtypes = @import("gfxtypes.zig");
const Vertex = gfxtypes.Vertex;
const c = gfxtypes.c;