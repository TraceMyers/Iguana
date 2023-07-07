
pub const Vertex = struct {
    position: fVec2 = undefined,
    color: fVec3 = undefined
};

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

const nd = @import("ndmath.zig");
const fVec2 = nd.fVec2;
const fVec3 = nd.fVec3;
const c = @import("vulkan.zig").c;
const array = @import("array.zig");
const LocalArray = array.LocalArray;