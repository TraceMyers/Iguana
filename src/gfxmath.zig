
pub const Vertex = struct {
    position: Vec2 = undefined,
    color: Vec3 = undefined
};

pub inline fn getVertexInputBindingDescription() vk.VkVertexInputBindingDescription {
    return vk.VkVertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
    };
}

pub inline fn getAttributeDescriptions(descriptions: *LocalArray(vk.VkVertexInputAttributeDescription, 2)) void {
    descriptions.resetCount();
    descriptions.push(vk.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 0,
        .format = vk.VK_FORMAT_R32G32_SFLOAT,
        .offset = @offsetOf(Vertex, "position"),
    });
    descriptions.push(vk.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 1,
        .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @offsetOf(Vertex, "color"),
    });
}

const linalg = @import("linalg.zig");
const Vec2 = linalg.Vec2;
const Vec3 = linalg.Vec3;
const vk = @import("vkdecl.zig");
const array = @import("array.zig");
const LocalArray = array.LocalArray;