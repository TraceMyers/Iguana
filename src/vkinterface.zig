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
    try createSwapchain();
    try createImageViews();
}

pub fn cleanup() void {

    for (swapchain.image_views.items[0..swapchain.image_views.count()]) |view| {
        vk.vkDestroyImageView(vk_logical, view, null);
    }
    vk.vkDestroySwapchainKHR(vk_logical, swapchain.vk_swapchain, null);
    swapchain.reset();
    vk.vkDestroyDevice(vk_logical, null);
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
    var unique_qfam_indices = LocalArray(u32, 4).new();
    const unique_qfam_ct: usize = physical.getUniqueQueueFamilyIndices(&unique_qfam_indices);

    var queue_infos = LocalArray(vk.VkDeviceQueueCreateInfo, 4).new();
    queue_infos.setCount(unique_qfam_ct);

    const queue_priority: f32 = 1.0;
    for (0..unique_qfam_ct) |i| {
        queue_infos.items[i] = vk.VkDeviceQueueCreateInfo {
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = unique_qfam_indices.items[i],
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
            .pNext = null,
            .flags = 0
        };
    }

    const required_extension: [*c]const u8 = vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME;

    var device_info = vk.VkDeviceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = @intCast(u32, unique_qfam_ct),
        .pQueueCreateInfos = queue_infos.cptr(),
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = &required_extension,
        .pEnabledFeatures = null
    };

    const result = vk.vkCreateDevice(physical.vk_physical, &device_info, null, &vk_logical);
    if (result != VK_SUCCESS) {
        return VkError.CreateLogicalDevice;
    }

    vk.vkGetDeviceQueue(vk_logical, physical.present_idx.?, 0, &present_queue);
    vk.vkGetDeviceQueue(vk_logical, physical.graphics_idx.?, 0, &graphics_queue);
    if (physical.compute_idx) |compute_idx| {
        vk.vkGetDeviceQueue(vk_logical, compute_idx, 0, &compute_queue);
    }
    if (physical.transfer_idx) |transfer_idx| {
        vk.vkGetDeviceQueue(vk_logical, transfer_idx, 0, &compute_queue);
    }
}

fn createSwapchain() !void {
    const surface_format: vk.VkSurfaceFormatKHR = chooseSwapchainSurfaceFormat(&swapchain);
    const present_mode: vk.VkPresentModeKHR = chooseSwapchainPresentMode(&swapchain);
    const extent: vk.VkExtent2D = chooseSwapchainExtent(&swapchain);
    var image_ct: u32 = swapchain.surface_capabilities.minImageCount + 1;

    if (image_ct > Swapchain.MAX_IMAGE_CT) {
        return VkError.CreateSwapchain;
    }

    var qfam_indices_array = LocalArray(u32, 4).new();
    const unique_qfam_idx_ct = @intCast(u32, physical.getUniqueQueueFamilyIndices(&qfam_indices_array));

    var image_share_mode: vk.VkSharingMode = undefined;
    var qfam_index_ct: u32 = undefined;
    var qfam_indices: [*c]u32 = undefined;

    // TODO: transfer and compute queues
    if (unique_qfam_idx_ct > 1) {
        image_share_mode = vk.VK_SHARING_MODE_CONCURRENT;
        qfam_index_ct = unique_qfam_idx_ct;
        qfam_indices = qfam_indices_array.cptr();
    }
    else {
        image_share_mode = vk.VK_SHARING_MODE_EXCLUSIVE;
        qfam_index_ct = 0;
        qfam_indices = null;
    }

    const swapchain_info = vk.VkSwapchainCreateInfoKHR{
        .sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .surface = vk_surface,
        .minImageCount = image_ct,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = image_share_mode,
        .queueFamilyIndexCount = qfam_index_ct,
        .pQueueFamilyIndices = qfam_indices,
        .preTransform = swapchain.surface_capabilities.currentTransform,
        .compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = vk.VK_TRUE,
        .oldSwapchain = null,
    };

    {
        const result = vk.vkCreateSwapchainKHR(vk_logical, &swapchain_info, null, &swapchain.vk_swapchain);
        if (result != VK_SUCCESS) {
            return VkError.CreateSwapchain;
        }
    }
    {
        const result = vk.vkGetSwapchainImagesKHR(vk_logical, swapchain.vk_swapchain, &image_ct, null);
        if (result != VK_SUCCESS) {
            return VkError.CreateSwapchain;
        }
    }
    {
        const result = vk.vkGetSwapchainImagesKHR(vk_logical, swapchain.vk_swapchain, &image_ct, swapchain.images.cptr());
        if (result != VK_SUCCESS) {
            return VkError.CreateSwapchain;
        }
        swapchain.images.setCount(image_ct);
    }

    swapchain.extent = extent;
    swapchain.image_fmt = surface_format.format;
}

fn createImageViews() !void {
    swapchain.image_views.sZero();
    swapchain.image_views.setCount(swapchain.images.count());

    var create_info = vk.VkImageViewCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .image = null,
        .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
        .format = swapchain.image_fmt,
        .components = vk.VkComponentMapping{
            .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = vk.VkImageSubresourceRange{
            .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1
        },
    };
    for (0..swapchain.image_views.count()) |i| {
        create_info.image = swapchain.images.items[i];
        const result = vk.vkCreateImageView(vk_logical, &create_info, null, &swapchain.image_views.items[i]);
        if (result != VK_SUCCESS) {
            return VkError.CreateImageViews;
        }
    }
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

fn chooseSwapchainSurfaceFormat(swapc: *Swapchain) vk.VkSurfaceFormatKHR {
    for (swapc.surface_formats.items[0..swapc.surface_formats.count()]) |*format| {
        if (format.format == vk.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format.*;
        }
    }
    return swapc.surface_formats.items[0];
}

fn chooseSwapchainPresentMode(swapc: *Swapchain) vk.VkPresentModeKHR {
    for (swapc.present_modes.items[0..swapc.present_modes.count()]) |mode| {
        if (mode == vk.VK_PRESENT_MODE_MAILBOX_KHR) {
            return mode;
        }
    }
    return vk.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapchainExtent(swapc: *Swapchain) vk.VkExtent2D {
    if (swapc.surface_capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return swapc.surface_capabilities.currentExtent;
    }

    var width: i32 = 0;
    var height: i32 = 0;
    vk.glfwGetFramebufferSize(window.get(), &width, &height);

    var pixel_extent = vk.VkExtent2D{ .width = @intCast(u32, width), .height = @intCast(u32, height) };
    pixel_extent.width = std.math.clamp(
        pixel_extent.width, swapc.surface_capabilities.minImageExtent.width, swapc.surface_capabilities.maxImageExtent.width
    );
    pixel_extent.height = std.math.clamp(
        pixel_extent.height, swapc.surface_capabilities.minImageExtent.height, swapc.surface_capabilities.maxImageExtent.height
    );

    return pixel_extent;
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

    pub fn getUniqueQueueFamilyIndices(self: *PhysicalDevice, indices: *LocalArray(u32, 4)) usize {
        indices.resetCount();
        if (self.present_idx != null) {
            indices.push(self.present_idx.?);
        }
        if (self.graphics_idx != null and indices.find(self.graphics_idx.?) == null) {
            indices.push(self.graphics_idx.?);
        }
        if (self.compute_idx != null and indices.find(self.compute_idx.?) == null) {
            indices.push(self.compute_idx.?);
        }
        if (self.transfer_idx != null and indices.find(self.transfer_idx.?) == null) {
            indices.push(self.transfer_idx.?);
        }
        return indices.count();
    } 
};

const Swapchain = struct {
    const MAX_FORMAT_CT: u32 = 8;
    const MAX_MODE_CT: u32 = 8;
    const MAX_IMAGE_CT: u32 = 4;
    
    vk_swapchain: vk.VkSwapchainKHR = null,
    extent: vk.VkExtent2D = vk.VkExtent2D {
        .width = 0,
        .height = 0,
    },
    images: LocalArray(vk.VkImage, MAX_IMAGE_CT) = LocalArray(vk.VkImage, MAX_IMAGE_CT).new(),
    image_fmt: vk.VkFormat = undefined,
    image_views: LocalArray(vk.VkImageView, MAX_IMAGE_CT) = LocalArray(vk.VkImageView, MAX_IMAGE_CT).new(),
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
    surface_formats : LocalArray(vk.VkSurfaceFormatKHR, MAX_FORMAT_CT) = LocalArray(vk.VkSurfaceFormatKHR, MAX_FORMAT_CT).new(),
    present_modes : LocalArray(vk.VkPresentModeKHR, MAX_MODE_CT) = LocalArray(vk.VkPresentModeKHR, MAX_MODE_CT).new(),

    pub fn reset(self: *Swapchain) void {
        self.* = Swapchain{};
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// VkInstance is ?*struct_VkInstance_T
var vk_instance: VkInstance = null;
var vk_surface: VkSurfaceKHR = null;
var vk_logical: VkDevice = null;
var present_queue: VkQueue = null;
var graphics_queue: VkQueue = null;
var compute_queue: VkQueue = null;
var transfer_queue: VkQueue = null;

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
    CreateLogicalDevice,
    CreateSwapchain,
    CreateImageViews,
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
const VkQueue = vk.VkQueue;

const std = @import("std");
const print = std.debug.print;
const array = @import("array.zig");
const window = @import("window.zig");
const LocalArray = array.LocalArray;