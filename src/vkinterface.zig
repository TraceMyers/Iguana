// TODO: rename vk stuff to not have "vk"

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn init() !void {
    try createInstance();
    try createSurface();
}

pub fn cleanup() void {
    vk.vkDestroySurfaceKHR(vk_inst, vk_surf, null);
    vk.vkDestroyInstance(vk_inst, null);
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------- creation sequence
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn createInstance() !void {
    var app_info = vk.VkApplicationInfo {
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Hello Triangle",
        .applicationVersion = vk.VK_MAKE_VERSION(0, 0, 1),
        .pEngineName = "VGCore",
        .engineVersion = vk.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = vk.VK_API_VERSION_1_0,
    };

    var glfw_extension_ct: u32 = 0;
    const glfw_required_extensions: [*c][*c]const u8 = vk.glfwGetRequiredInstanceExtensions(&glfw_extension_ct);

    var extension_ct: u32 = 0;
    var extensions = LocalArray(vk.VkExtensionProperties, 512).new();
    _ = vk.vkEnumerateInstanceExtensionProperties(null, &extension_ct, &extensions.items);
    extensions.setCount(extension_ct);

    var layer_ct: u32 = 0;
    var available_layers = LocalArray(vk.VkLayerProperties, 512).new();
    _ = vk.vkEnumerateInstanceLayerProperties(&layer_ct, &available_layers.items);
    available_layers.setCount(layer_ct);

    // TODO: multiple layers?
    const validation_layer: [*c]const u8 = "VK_LAYER_KHRONOS_validation";

    const create_info = vk.VkInstanceCreateInfo {
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = glfw_extension_ct,
        .ppEnabledExtensionNames = glfw_required_extensions,
        .enabledLayerCount = 1,
        .ppEnabledLayerNames = &validation_layer,
    };

    {
        const result: VkResult = vk.vkCreateInstance(&create_info, null, &vk_inst);

        if (result != VK_SUCCESS) {
            return VkError.CreateInstanceFail;
        }
    }
}

fn createSurface() !void {
    const result: VkResult = vk.glfwCreateWindowSurface(vk_inst, window.get(), null, &vk_surf);
    if (result != VK_SUCCESS) {
        return VkError.CreateSurfaceFail;
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// VkInstance is ?*struct_VkInstance_T
var vk_inst: VkInstance = null;
var vk_surf: VkSurfaceKHR = null;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const VkError = error {
    CreateInstanceFail,
    CreateSurfaceFail,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const vk = @import("vkdecl.zig");
const VkResult = vk.VkResult;
const VK_SUCCESS = vk.VK_SUCCESS;
const VkInstance = vk.VkInstance;
const GLFWwindow = vk.GLFWwindow;
const VkSurfaceKHR = vk.VkSurfaceKHR;

const std = @import("std");
const print = std.debug.print;
const array = @import("array.zig");
const window = @import("window.zig");
const LocalArray = array.LocalArray;