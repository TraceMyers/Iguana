// TODO: rename vk stuff to not have "vk"
// TODO: better error handling

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn init() !void {
    try createInstance();
    try createSurface();
    try getPhysicalDevice();
    try createLogicalDevice();
}

pub fn cleanup() void {
    vk.vkDestroySurfaceKHR(vk_instance, vk_surface, null);
    vk.vkDestroyInstance(vk_instance, null);
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
        const result: VkResult = vk.vkCreateInstance(&create_info, null, &vk_instance);

        if (result != VK_SUCCESS) {
            return VkError.CreateInstance;
        }
    }
}

fn createSurface() !void {
    const result: VkResult = vk.glfwCreateWindowSurface(vk_instance, window.get(), null, &vk_surface);
    if (result != VK_SUCCESS) {
        return VkError.CreateSurface;
    }
}

fn getPhysicalDevice() !void {
    var physical_device_ct: u32 = 0;
    {
        const result = vk.vkEnumeratePhysicalDevices(
            vk_instance, 
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

    var physical_devices = LocalArray(VkPhysicalDevice, 128).new();
    if (physical_device_ct > 128) {
        return VkError.NotEnoughPhysicalDeviceStorage;
    }
    physical_devices.setCount(physical_device_ct);

    {
        const result = vk.vkEnumeratePhysicalDevices(
            vk_instance, 
            &physical_device_ct, 
            physical_devices.cptr()
        );
        if (result != VK_SUCCESS) {
            return VkError.GetPhysicalDevices;
        }
    }

    var best_device: ?VkPhysicalDevice = null;
    var best_device_vram_sz: vk.VkDeviceSize = 0;
    var best_device_type: vk.VkPhysicalDeviceType = vk.VK_PHYSICAL_DEVICE_TYPE_OTHER;

    for (physical_devices.items[0..physical_devices.count()]) |device| {
        if (!getPhysicalDeviceCapabilities(device, &swapchain, &physical)) {
            continue;
        }

        var device_props: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(device, &device_props);

        switch(device_props.deviceType) {
            vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => {
                const device_sz = getPhysicalDeviceVRAMSize(device);
                if (best_device_type != vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU or device_sz > best_device_vram_sz) {
                    best_device = device;
                    best_device_type = vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
                    best_device_vram_sz = device_sz;
                }
            },
            vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => {
                if (best_device_type != vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                    const device_sz = getPhysicalDeviceVRAMSize(device);
                    if (device_sz > best_device_vram_sz) {
                        best_device = device;
                        best_device_type = vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU;
                        best_device_vram_sz = device_sz;
                    }
                }
            },
            else => {}
        }
    }

    if (best_device) |device| {
        _ = getPhysicalDeviceQueueFamilyCapabilities(device, &physical);
        _ = getPhysicalDeviceSurfaceCapabilities(device, &swapchain);
        physical.vk_physical = device;
        physical.dtype = best_device_type;
        physical.sz = best_device_vram_sz;
    }
    else {
        return VkError.NoAdequatePhysicalDevice;
    }
}

fn createLogicalDevice() !void {

}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------- creation sequence helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn getPhysicalDeviceCapabilities(device: VkPhysicalDevice, swapc_details: *Swapchain, phys_interface: *PhysicalDevice) bool {
    if (!physicalDeviceHasAdequateExtensionProperties(device)) {
        return false;
    }
    if (!getPhysicalDeviceSurfaceCapabilities(device, swapc_details)) {
        return false;
    }
    if (!getPhysicalDeviceQueueFamilyCapabilities(device, phys_interface)) {
        return false;
    }
    return true;
}

fn physicalDeviceHasAdequateExtensionProperties(device: VkPhysicalDevice) bool {
    var extension_prop_ct: u32 = 0;
    {
        const result = vk.vkEnumerateDeviceExtensionProperties(
            device, null, &extension_prop_ct, null
        );
        if (result != VK_SUCCESS or extension_prop_ct == 0) {
            return false;
        }
    }

    var extension_props = std.ArrayList(vk.VkExtensionProperties).initCapacity(gpa.allocator(), extension_prop_ct)
        catch return false;
    extension_props.expandToCapacity();
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

fn getPhysicalDeviceSurfaceCapabilities(device: VkPhysicalDevice, swapc_details: *Swapchain) bool {
    swapc_details.reset();

    {
        const result = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
            device, vk_surface, &swapc_details.surface_capabilities
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    var format_ct: u32 = 0;
    {
        const result = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, vk_surface, &format_ct, null);
        if (result != VK_SUCCESS or format_ct == 0) {
            return false;
        }
    }

    if (format_ct > Swapchain.MAX_FORMAT_CT) {
        return false;
    }
    swapc_details.surface_formats.setCount(format_ct);

    {
        const result = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(
            device, vk_surface, &format_ct, swapc_details.surface_formats.cptr()
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    var present_mode_ct: u32 = 0;
    {
        const result = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, vk_surface, &present_mode_ct, null);
        if (result != VK_SUCCESS or present_mode_ct == 0) {
            return false;
        }
    }

    if (present_mode_ct > Swapchain.MAX_MODE_CT) {
        return false;
    }
    swapc_details.present_modes.setCount(present_mode_ct);

    {
        const result = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(
            device, vk_surface, &present_mode_ct, swapc_details.present_modes.cptr()
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    return true;
}

fn getPhysicalDeviceQueueFamilyCapabilities(device: VkPhysicalDevice, device_interface: *PhysicalDevice) bool {
    device_interface.reset();

    var queue_family_ct: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_ct, null);
    if (queue_family_ct == 0) {
        return false;
    }

    var queue_family_props = std.ArrayList(vk.VkQueueFamilyProperties).initCapacity(gpa.allocator(), queue_family_ct)
        catch return false;
    queue_family_props.expandToCapacity();
    defer queue_family_props.deinit();

    vk.vkGetPhysicalDeviceQueueFamilyProperties(
        device, &queue_family_ct, @ptrCast([*c]vk.VkQueueFamilyProperties, queue_family_props.items)
    );

    for (0..queue_family_ct) |i| {
        const idx32: u32 = @intCast(u32, i);
        var vk_family_supports_present: vk.VkBool32 = undefined;

        const result = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, idx32, vk_surface, &vk_family_supports_present);
        if (result != VK_SUCCESS) {
            continue;
        }

        const family_props: *vk.VkQueueFamilyProperties = &queue_family_props.items[i];
        const family_supports_present = vk_family_supports_present > 0;
        const family_supports_graphics = (family_props.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT) > 0;
        const family_supports_compute = (family_props.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) > 0;
        const family_supports_transfer = (family_props.queueFlags & vk.VK_QUEUE_TRANSFER_BIT) > 0;
        const family_supports_all = 
            family_supports_present 
            and family_supports_graphics 
            and family_supports_compute
            and family_supports_transfer;

        if (family_supports_all) {
            device_interface.present_idx = idx32;
            device_interface.graphics_idx = idx32;
            device_interface.compute_idx = idx32;
            device_interface.transfer_idx = idx32;
            break;
        }
        if (family_supports_present) {
            device_interface.present_idx = idx32;
        }
        if (family_supports_graphics) {
            device_interface.graphics_idx = idx32;
        }
        if (family_supports_compute) {
            device_interface.compute_idx = idx32;
        }
        if (family_supports_transfer) {
            device_interface.transfer_idx = idx32;
        }
    }

    if (device_interface.present_idx == null or device_interface.graphics_idx == null) {
        return false;
    }

    if (device_interface.compute_idx != null) {
        if (device_interface.transfer_idx != null) {
            device_interface.qfam_capabilities = QFamCapabilities.PGCT;
        }
        else {
            device_interface.qfam_capabilities = QFamCapabilities.PGC;
        }
    }
    else if (device_interface.transfer_idx != null) {
        device_interface.qfam_capabilities = QFamCapabilities.PGT;
    }
    else {
        device_interface.qfam_capabilities = QFamCapabilities.PG;
    }

    return true;
}

fn getPhysicalDeviceVRAMSize(device: VkPhysicalDevice) vk.VkDeviceSize {
    var device_mem_props: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(device, &device_mem_props);

    const memory_heaps: [16]vk.VkMemoryHeap = device_mem_props.memoryHeaps;
    for (0..device_mem_props.memoryHeapCount) |i| {
        const heap: *const vk.VkMemoryHeap = &memory_heaps[i];
        if ((heap.flags & vk.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) > 0) {
            return heap.size;
        }
    }
    
    return 0;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const QFamCapabilities = enum(u32) { 
    None        = 0x00,
    Present     = 0x01,
    Graphics    = 0x02,
    Compute     = 0x04,
    Transfer    = 0x08,
    PG          = 0x01 | 0x02,
    PGC         = 0x01 | 0x02 | 0x04,
    PGT         = 0x01 | 0x02 | 0x08,
    PGCT        = 0x01 | 0x02 | 0x04 | 0x08,
};

const PhysicalDevice = struct {
    vk_physical: VkPhysicalDevice = null,
    dtype: vk.VkPhysicalDeviceType = vk.VK_PHYSICAL_DEVICE_TYPE_OTHER,
    sz: vk.VkDeviceSize = 0,
    present_idx: ?u32 = null,
    graphics_idx: ?u32 = null,
    compute_idx: ?u32 = null,
    transfer_idx: ?u32 = null,
    qfam_capabilities: QFamCapabilities = QFamCapabilities.None,

    pub fn reset(self: *PhysicalDevice) void {
        self.* = PhysicalDevice{};
    }
};

const Swapchain = struct {
    const MAX_FORMAT_CT: u32 = 8;
    const MAX_MODE_CT: u32 = 8;
    
    vk_swapchain: vk.VkSwapchainKHR = null,
    surface_capabilities: vk.VkSurfaceCapabilitiesKHR = vk.VkSurfaceCapabilitiesKHR {
        .minImageCount = 0,
        .maxImageCount = 0,
        .currentExtent = vk.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .minImageExtent = vk.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .maxImageExtent = vk.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .maxImageArrayLayers = 0,
        .supportedTransforms = 0,
        .currentTransform = 0,
        .supportedCompositeAlpha = 0,
        .supportedUsageFlags = 0,
    },
    surface_formats : LocalArray(vk.VkSurfaceFormatKHR, MAX_FORMAT_CT) = undefined,
    present_modes : LocalArray(vk.VkPresentModeKHR, MAX_MODE_CT) = undefined,

    pub fn reset(self: *Swapchain) void {
        self.* = Swapchain{};
        self.surface_formats.resetCount();
        self.present_modes.resetCount();
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// VkInstance is ?*struct_VkInstance_T
var vk_instance: VkInstance = null;
var vk_surface: VkSurfaceKHR = null;
var vk_logical: VkDevice = null;

var swapchain : Swapchain = Swapchain{};
var physical: PhysicalDevice = PhysicalDevice{};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const VkError = error {
    CreateInstance,
    CreateSurface,
    GetPhysicalDevices,
    ZeroPhysicalDevices,
    NoAdequatePhysicalDevice,
    NotEnoughPhysicalDeviceStorage,
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
const VkDevice = vk.VkDevice;

const std = @import("std");
const print = std.debug.print;
const array = @import("array.zig");
const window = @import("window.zig");
const LocalArray = array.LocalArray;