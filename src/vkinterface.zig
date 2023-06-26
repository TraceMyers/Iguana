// TODO: rename vk stuff to not have "vk"

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn init() !void {
    try createInstance();
    try createSurface();
    try getPhysicalDevice();
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
            return VkError.CreateInstance;
        }
    }
}

fn createSurface() !void {
    const result: VkResult = vk.glfwCreateWindowSurface(vk_inst, window.get(), null, &vk_surf);
    if (result != VK_SUCCESS) {
        return VkError.CreateSurface;
    }
}

fn getPhysicalDevice() !void {
    var physical_device_ct: u32 = 0;
    {
        const result = vk.vkEnumeratePhysicalDevices(
            vk_inst, 
            &physical_device_ct, 
            null
        );
        if (result != VK_SUCCESS) {
            return VkError.GetPhysicalDevices;
        }
    }

    if (physical_device_ct == 0) {
        return VkError.ZeroPhysicalDevices;
    }

    var physical_devices = try std.ArrayList(VkPhysicalDevice).initCapacity(
        gpa.allocator(), physical_device_ct
    );
    defer physical_devices.deinit();
    {
        const result = vk.vkEnumeratePhysicalDevices(
            vk_inst, 
            &physical_device_ct, 
            @ptrCast([*c]VkPhysicalDevice, physical_devices.items)
        );
        if (result != VK_SUCCESS) {
            return VkError.GetPhysicalDevices;
        }
    }

    // var best_device_idx: ?VkPhysicalDevice = null;
    // _ = best_device_idx;
    // var best_device_vram_sz = 0;
    // _ = best_device_vram_sz;
    // var best_device_type = vk.VK_PHYSICAL_DEVICE_TYPE_OTHER;
    // _ = best_device_type;

    for (physical_devices.items) |device| {
        const adequate_device: bool = try isAdequatePhysicalDevice(device);
        if (!adequate_device) {
            continue;
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------- creation sequence helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn isAdequatePhysicalDevice(device: VkPhysicalDevice) !bool {
    const valid_extension_properties = try physicalDeviceHasValidExtensionProperties(device);
    if (!valid_extension_properties) {
        return false;
    }

    return true;
}

fn physicalDeviceHasValidExtensionProperties(device: VkPhysicalDevice) !bool {
    var extension_prop_ct: u32 = 0;
    {
        const result = vk.vkEnumerateDeviceExtensionProperties(
            device, null, &extension_prop_ct, null
        );
        if (result != VK_SUCCESS or extension_prop_ct == 0) {
            return false;
        }
    }

    var extension_props = try std.ArrayList(
        vk.VkExtensionProperties).initCapacity(gpa.allocator(), extension_prop_ct
    );
    defer extension_props.deinit();
    {
        const result = vk.vkEnumerateDeviceExtensionProperties(
            device, 
            null, 
            &extension_prop_ct, 
            @ptrCast([*c]vk.VkExtensionProperties, extension_props.items)
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    // TODO: check extension properties
    // for (extension_props) |prop| {

    // }

    return true;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// VkInstance is ?*struct_VkInstance_T
var vk_inst: VkInstance = null;
var vk_surf: VkSurfaceKHR = null;
var vk_phys: VkPhysicalDevice = null;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const VkError = error {
    CreateInstance,
    CreateSurface,
    GetPhysicalDevices,
    ZeroPhysicalDevices,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const vk = @import("vkdecl.zig");
const VkResult = vk.VkResult;
const VK_SUCCESS = vk.VK_SUCCESS;
const VkInstance = vk.VkInstance;
const GLFWwindow = vk.GLFWwindow;
const VkPhysicalDevice = vk.VkPhysicalDevice;
const VkSurfaceKHR = vk.VkSurfaceKHR;

const std = @import("std");
const print = std.debug.print;
const array = @import("array.zig");
const window = @import("window.zig");
const LocalArray = array.LocalArray;