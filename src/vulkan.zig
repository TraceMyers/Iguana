// TODO: just cImport vulkincl.h
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
    try createRenderPass();
    try createGraphicsPipeline();
    try createFramebuffers();
    try createCommandPools();
    try createVertexBuffer();
    try createCommandBuffers();
    try createSyncObjects();
}

pub fn cleanup() void {
    if (in_flight_fences[0] != null) {
        _ = c.vkWaitForFences(vk_logical, MAX_FRAMES_IN_FLIGHT, &in_flight_fences[0], c.VK_TRUE, ONE_SECOND_IN_NANOSECONDS);
    }
    cleanupSwapchain();
    c.vkDestroyBuffer(vk_logical, vertex_buffer, null);
    c.vkFreeMemory(vk_logical, vertex_buffer_memory, null);
    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroySemaphore(vk_logical, sem_image_available[i], null);
        c.vkDestroySemaphore(vk_logical, sem_render_finished[i], null);
        c.vkDestroyFence(vk_logical, in_flight_fences[i], null);
    }
    c.vkDestroyCommandPool(vk_logical, present_command_pool, null);
    c.vkDestroyCommandPool(vk_logical, graphics_command_pool, null);
    c.vkDestroyCommandPool(vk_logical, compute_command_pool, null);
    c.vkDestroyCommandPool(vk_logical, transfer_command_pool, null);
    c.vkDestroyPipelineLayout(vk_logical, vk_pipeline_layout, null);
    c.vkDestroyRenderPass(vk_logical, vk_render_pass, null);
    c.vkDestroyPipeline(vk_logical, vk_pipeline, null);
    
    swapchain.reset();
    c.vkDestroyDevice(vk_logical, null);
    c.vkDestroySurfaceKHR(vk_instance, vk_surface, null);
    c.vkDestroyInstance(vk_instance, null);
}

pub fn drawFrame() !void {
    // var t1 = ScopeTimer.start("vkinterface.drawFrame", getScopeTimerID());
    // defer t1.stop();

    _ = c.vkWaitForFences(vk_logical, 1, &in_flight_fences[current_frame], c.VK_TRUE, std.math.maxInt(u64));
    var image_idx: u32 = undefined;

    // var t2 = ScopeTimer.start("vkinterface.drawFrame(after fence)", getScopeTimerID());
    // defer t2.stop();

    var result: c.VkResult = c.vkAcquireNextImageKHR(
        vk_logical, swapchain.vk_swapchain, std.math.maxInt(u64), sem_image_available[current_frame], null, &image_idx
    );
    if (result == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try recreateSwapchain();
        return;
    }
    else if (result != c.VK_SUCCESS and result != c.VK_SUBOPTIMAL_KHR) {
        return VkError.AcquireSwapchainImage;
    }
    _ = c.vkResetFences(vk_logical, 1, &in_flight_fences[current_frame]);

    _ = c.vkResetCommandBuffer(graphics_command_buffers[current_frame], 0);
    try recordCommandBuffer(graphics_command_buffers[current_frame], image_idx);

    const wait_stage: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

    const submit_info = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &sem_image_available[current_frame],
        .pWaitDstStageMask = &wait_stage,
        .commandBufferCount = 1,
        .pCommandBuffers = &graphics_command_buffers[current_frame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &sem_render_finished[current_frame],
    };

    result = c.vkQueueSubmit(graphics_queue, 1, &submit_info, in_flight_fences[current_frame]);
    if (result != VK_SUCCESS) {
        return VkError.DrawFrame;
    }

    const present_info = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &sem_render_finished[current_frame],
        .swapchainCount = 1,
        .pSwapchains = &swapchain.vk_swapchain,
        .pImageIndices = &image_idx,
        .pResults = null,
    };

    result = c.vkQueuePresentKHR(present_queue, &present_info);
    if (result == c.VK_ERROR_OUT_OF_DATE_KHR or result == c.VK_SUBOPTIMAL_KHR or framebuffer_resized) {
        framebuffer_resized = false;
        try recreateSwapchain();
    }
    else if (result != c.VK_SUCCESS) {
        return VkError.PresentSwapchainImage;
    }

    current_frame = @mod((current_frame + 1), MAX_FRAMES_IN_FLIGHT);
}

pub fn setFramebufferResized() void {
    framebuffer_resized = true;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------ frame-by-frame
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn recordCommandBuffer(command_buffer: VkCommandBuffer, image_idx: u32) !void {
    const begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    {
        const result = c.vkBeginCommandBuffer(command_buffer, &begin_info);
        if (result != VK_SUCCESS) {
            return VkError.RecordCommandBuffer;
        }
    }

    const clear_color = c.VkClearValue{
        .color = c.VkClearColorValue{.float32 = .{0.1, 0.0, 0.3, 1.0}},
    };

    const render_begin_info = c.VkRenderPassBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .pNext = null,
        .renderPass = vk_render_pass,
        .framebuffer = swapchain.framebuffers.items[image_idx],
        .renderArea = c.VkRect2D { 
            .offset = c.VkOffset2D { .x = 0, .y = 0 },
            .extent = swapchain.extent
        },
        .clearValueCount = 1,
        .pClearValues = &clear_color,
    };

    c.vkCmdBeginRenderPass(command_buffer, &render_begin_info, c.VK_SUBPASS_CONTENTS_INLINE);
    c.vkCmdBindPipeline(command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, vk_pipeline);

    const offset: c.VkDeviceSize = 0;
    c.vkCmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffer, &offset);

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swapchain.extent.width),
        .height = @intToFloat(f32, swapchain.extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    c.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0},
        .extent = swapchain.extent
    };

    c.vkCmdSetScissor(command_buffer, 0, 1, &scissor);
    c.vkCmdDraw(command_buffer, @intCast(u32, vertices.len), 1, 0, 0);
    c.vkCmdEndRenderPass(command_buffer);

    {
        const result = c.vkEndCommandBuffer(command_buffer);
        if (result != VK_SUCCESS) {
            return VkError.RecordCommandBuffer;
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------- infrequent
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn recreateSwapchain() !void {
    // wait out minimization until the window has width or height; note this halts the game sim as well... which
    // seems like a silly thing to give up to the renderer. TODO: change renderer halting sim
    var width: i32 = 0;
    var height: i32 = 0;
    c.glfwGetFramebufferSize(window.get(), &width, &height);
    while (width == 0 or height == 0) {
        c.glfwGetFramebufferSize(window.get(), &width, &height);
        c.glfwWaitEvents();
    }
    // var t1 = ScopeTimer.start("vkinterface.recreateSwapchain", getScopeTimerID());
    // defer t1.stop();

    _ = c.vkDeviceWaitIdle(vk_logical);

    cleanupSwapchain();

    // this was added to re-get the surface's current dimensions, but obviously that's already done above. this
    // may be otherwise useful; TODO: check if this updates anything else in a useful way and check if this is slow
    _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
        physical.vk_physical, vk_surface, &swapchain.surface_capabilities
    );

    try createSwapchain();
    try createImageViews();
    try createFramebuffers();
}

fn cleanupSwapchain() void {
    for (swapchain.framebuffers.items[0..swapchain.framebuffers.count()]) |buf| {
        c.vkDestroyFramebuffer(vk_logical, buf, null);
    }
    for (swapchain.image_views.items[0..swapchain.image_views.count()]) |view| {
        c.vkDestroyImageView(vk_logical, view, null);
    }
    c.vkDestroySwapchainKHR(vk_logical, swapchain.vk_swapchain, null);
}

fn createBuffer(
    size: c.VkDeviceSize, 
    usage: c.VkBufferUsageFlags, 
    property_flags: c.VkMemoryPropertyFlags, 
    buffer: *c.VkBuffer,
    buffer_memory: *c.VkDeviceMemory
) !void {
    const qfam_indices: *LocalArray(u32, 4) = physical.getUniqueQueueFamilyIndices();
    const buffer_info = c.VkBufferCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_CONCURRENT,
        .queueFamilyIndexCount = @intCast(u32, qfam_indices.count()),
        .pQueueFamilyIndices = qfam_indices.cptr(),
    };

    var result = c.vkCreateBuffer(vk_logical, &buffer_info, null, @ptrCast([*c]c.VkBuffer, buffer));
    if (result != VK_SUCCESS) {
        return VkError.CreateBuffer;
    }

    var memory_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(vk_logical, buffer.*, &memory_requirements);

    const memory_type: u32 = try findMemoryType(memory_requirements.memoryTypeBits, property_flags);
    const allocate_info = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = memory_requirements.size,
        .memoryTypeIndex = memory_type,
    };

    result = c.vkAllocateMemory(vk_logical, &allocate_info, null, @ptrCast([*c]c.VkDeviceMemory, buffer_memory));
    if (result != VK_SUCCESS) {
        return VkError.AllocateBufferMemory;
    }
    _ = c.vkBindBufferMemory(vk_logical, buffer.*, buffer_memory.*, 0);
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------- creation sequence
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn createInstance() !void {
    var app_info = c.VkApplicationInfo {
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Hello Triangle",
        .applicationVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .pEngineName = "VGCore",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = c.VK_API_VERSION_1_0,
    };

    var glfw_extension_ct: u32 = 0;
    const glfw_required_extensions: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfw_extension_ct);

    var extension_ct: u32 = 0;
    var extensions = LocalArray(c.VkExtensionProperties, 512).new();
    _ = c.vkEnumerateInstanceExtensionProperties(null, &extension_ct, &extensions.items);
    extensions.setCount(extension_ct);

    var layer_ct: u32 = 0;
    var available_layers = LocalArray(c.VkLayerProperties, 512).new();
    _ = c.vkEnumerateInstanceLayerProperties(&layer_ct, &available_layers.items);
    available_layers.setCount(layer_ct);

    // TODO: multiple layers?
    const validation_layer: [*c]const u8 = "VK_LAYER_KHRONOS_validation";

    const create_info = c.VkInstanceCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = glfw_extension_ct,
        .ppEnabledExtensionNames = glfw_required_extensions,
        .enabledLayerCount = 1,
        .ppEnabledLayerNames = &validation_layer,
    };

    {
        const result: VkResult = c.vkCreateInstance(&create_info, null, &vk_instance);

        if (result != VK_SUCCESS) {
            return VkError.CreateInstance;
        }
    }
}

fn createSurface() !void {
    const result: VkResult = c.glfwCreateWindowSurface(vk_instance, window.get(), null, &vk_surface);
    if (result != VK_SUCCESS) {
        return VkError.CreateSurface;
    }
}

fn getPhysicalDevice() !void {
    var physical_device_ct: u32 = 0;
    {
        const result = c.vkEnumeratePhysicalDevices(
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
        const result = c.vkEnumeratePhysicalDevices(
            vk_instance, 
            &physical_device_ct, 
            physical_devices.cptr()
        );
        if (result != VK_SUCCESS) {
            return VkError.GetPhysicalDevices;
        }
    }

    var best_device: ?VkPhysicalDevice = null;
    var best_device_vram_sz: c.VkDeviceSize = 0;
    var best_device_type: c.VkPhysicalDeviceType = c.VK_PHYSICAL_DEVICE_TYPE_OTHER;

    for (physical_devices.items[0..physical_devices.count()]) |device| {
        if (!getPhysicalDeviceCapabilities(device, &swapchain, &physical)) {
            continue;
        }

        var device_props: c.VkPhysicalDeviceProperties = undefined;
        c.vkGetPhysicalDeviceProperties(device, &device_props);

        switch(device_props.deviceType) {
            c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => {
                const device_sz = getPhysicalDeviceVRAMSize(device);
                if (best_device_type != c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU or device_sz > best_device_vram_sz) {
                    best_device = device;
                    best_device_type = c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
                    best_device_vram_sz = device_sz;
                }
            },
            c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => {
                if (best_device_type != c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                    const device_sz = getPhysicalDeviceVRAMSize(device);
                    if (device_sz > best_device_vram_sz) {
                        best_device = device;
                        best_device_type = c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU;
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
    var unique_qfam_indices: *LocalArray(u32, 4) = physical.getUniqueQueueFamilyIndices();

    var queue_infos = LocalArray(c.VkDeviceQueueCreateInfo, 4).new();
    queue_infos.setCount(unique_qfam_indices.count());

    const queue_priority: f32 = 1.0;
    for (0..unique_qfam_indices.count()) |i| {
        queue_infos.items[i] = c.VkDeviceQueueCreateInfo {
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = unique_qfam_indices.items[i],
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
            .pNext = null,
            .flags = 0
        };
    }

    const required_extension: [*c]const u8 = c.VK_KHR_SWAPCHAIN_EXTENSION_NAME;

    var device_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = @intCast(u32, unique_qfam_indices.count()),
        .pQueueCreateInfos = queue_infos.cptr(),
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = &required_extension,
        .pEnabledFeatures = null
    };

    const result = c.vkCreateDevice(physical.vk_physical, &device_info, null, &vk_logical);
    if (result != VK_SUCCESS) {
        return VkError.CreateLogicalDevice;
    }

    c.vkGetDeviceQueue(vk_logical, physical.present_idx.?, 0, &present_queue);
    c.vkGetDeviceQueue(vk_logical, physical.graphics_idx.?, 0, &graphics_queue);
    if (physical.compute_idx) |compute_idx| {
        c.vkGetDeviceQueue(vk_logical, compute_idx, 0, &compute_queue);
    }
    if (physical.transfer_idx) |transfer_idx| {
        c.vkGetDeviceQueue(vk_logical, transfer_idx, 0, &transfer_queue);
    }
}

fn createSwapchain() !void {
    const surface_format: c.VkSurfaceFormatKHR = chooseSwapchainSurfaceFormat(&swapchain);
    const present_mode: c.VkPresentModeKHR = chooseSwapchainPresentMode(&swapchain);
    const extent: c.VkExtent2D = chooseSwapchainExtent(&swapchain);
    var image_ct: u32 = swapchain.surface_capabilities.minImageCount + 1;

    if (image_ct > Swapchain.MAX_IMAGE_CT) {
        return VkError.CreateSwapchain;
    }

    var qfam_indices_array: *LocalArray(u32, 4) = physical.getUniqueQueueFamilyIndices();
    const unique_qfam_idx_ct = @intCast(u32, qfam_indices_array.count());

    var image_share_mode: c.VkSharingMode = undefined;
    var qfam_index_ct: u32 = undefined;
    var qfam_indices: [*c]u32 = undefined;

    if (unique_qfam_idx_ct > 1) {
        image_share_mode = c.VK_SHARING_MODE_CONCURRENT;
        qfam_index_ct = unique_qfam_idx_ct;
        qfam_indices = qfam_indices_array.cptr();
    }
    else {
        image_share_mode = c.VK_SHARING_MODE_EXCLUSIVE;
        qfam_index_ct = 0;
        qfam_indices = null;
    }

    const swapchain_info = c.VkSwapchainCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .surface = vk_surface,
        .minImageCount = image_ct,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = image_share_mode,
        .queueFamilyIndexCount = qfam_index_ct,
        .pQueueFamilyIndices = qfam_indices,
        .preTransform = swapchain.surface_capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
    };

    var result = c.vkCreateSwapchainKHR(vk_logical, &swapchain_info, null, &swapchain.vk_swapchain);
    if (result != VK_SUCCESS) {
        return VkError.CreateSwapchain;
    }
    result = c.vkGetSwapchainImagesKHR(vk_logical, swapchain.vk_swapchain, &image_ct, swapchain.images.cptr());
    if (result != VK_SUCCESS) {
        return VkError.CreateSwapchain;
    }
    swapchain.images.setCount(image_ct);

    swapchain.extent = extent;
    swapchain.image_fmt = surface_format.format;
}

fn createImageViews() !void {
    swapchain.image_views.sZero();
    swapchain.image_views.setCount(swapchain.images.count());

    var create_info = c.VkImageViewCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .image = null,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = swapchain.image_fmt,
        .components = c.VkComponentMapping{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1
        },
    };
    for (0..swapchain.image_views.count()) |i| {
        create_info.image = swapchain.images.items[i];
        const result = c.vkCreateImageView(vk_logical, &create_info, null, &swapchain.image_views.items[i]);
        if (result != VK_SUCCESS) {
            return VkError.CreateImageViews;
        }
    }
}

fn createRenderPass() !void {
    const color_attachment = c.VkAttachmentDescription{
        .flags = 0,
        .format = swapchain.image_fmt,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    const color_attachment_ref = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass = c.VkSubpassDescription{
        .flags = 0,
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .inputAttachmentCount = 0,
        .pInputAttachments = 0,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
        .pResolveAttachments = null,
        .pDepthStencilAttachment = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
    };

    const dependency = c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        .dependencyFlags = 0,
    };

    const render_pass_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    const result = c.vkCreateRenderPass(vk_logical, &render_pass_info, null, &vk_render_pass);
    if (result != VK_SUCCESS) {
        return VkError.CreateRenderPass;
    }
}

fn createGraphicsPipeline() !void {
    var vert_module: c.VkShaderModule = try createShaderModule("test/shaders/trivert.spv");
    defer c.vkDestroyShaderModule(vk_logical, vert_module, null);
    var frag_module: c.VkShaderModule = try createShaderModule("test/shaders/trifrag.spv");
    defer c.vkDestroyShaderModule(vk_logical, frag_module, null);

    const vert_shader_info = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vert_module,
        .pName = "main",
        .pSpecializationInfo = null,
    };

    const frag_shader_info = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = frag_module,
        .pName = "main",
        .pSpecializationInfo = null,
    };

    var shader_stages: [2]c.VkPipelineShaderStageCreateInfo = .{vert_shader_info, frag_shader_info};

    const binding_description: c.VkVertexInputBindingDescription = gfxmath.getVertexInputBindingDescription();
    var attribute_descriptions = LocalArray(c.VkVertexInputAttributeDescription, 2).new();
    gfxmath.getAttributeDescriptions(&attribute_descriptions);

    const vertex_input_info = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &binding_description,
        .vertexAttributeDescriptionCount = @intCast(u32, attribute_descriptions.count()),
        .pVertexAttributeDescriptions = attribute_descriptions.cptr(),
    };

    const pipeline_assembly_info = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swapchain.extent.width),
        .height = @intToFloat(f32, swapchain.extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D { .x = 0.0, .y = 0.0 },
        .extent = swapchain.extent, 
    };

    var dynamic_states: [2]c.VkDynamicState = .{c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR};

    const dynamic_state_info = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .dynamicStateCount = 2,
        .pDynamicStates = &dynamic_states[0],
    };

    const viewport_info = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    const raster_info = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
        .lineWidth = 1.0,
    };

    const multisample_info = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = c.VK_FALSE,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
    };

    const color_blend = c.VkPipelineColorBlendAttachmentState{
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
        .colorWriteMask = 
            c.VK_COLOR_COMPONENT_R_BIT 
            | c.VK_COLOR_COMPONENT_B_BIT 
            | c.VK_COLOR_COMPONENT_G_BIT 
            | c.VK_COLOR_COMPONENT_A_BIT,
    };

    const color_blend_info = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend,
        .blendConstants = .{0.0, 0.0, 0.0, 0.0},
    };

    const pipeline_layout_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 0,
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    {
        const result = c.vkCreatePipelineLayout(vk_logical, &pipeline_layout_info, null, &vk_pipeline_layout);
        if (result != VK_SUCCESS) {
            return VkError.CreatePipelineLayout;
        }
    }

    const pipeline_info = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stageCount = 2,
        .pStages = &shader_stages[0],
        .pVertexInputState = &vertex_input_info,
        .pInputAssemblyState = &pipeline_assembly_info,
        .pTessellationState = null,
        .pViewportState = &viewport_info,
        .pRasterizationState = &raster_info,
        .pMultisampleState = &multisample_info,
        .pDepthStencilState = null,
        .pColorBlendState = &color_blend_info,
        .pDynamicState = &dynamic_state_info,
        .layout = vk_pipeline_layout,
        .renderPass = vk_render_pass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    {
        const result = c.vkCreateGraphicsPipelines(vk_logical, null, 1, &pipeline_info, null, &vk_pipeline);
        if (result != VK_SUCCESS) {
            return VkError.CreatePipeline;
        }
    }
}

fn createFramebuffers() !void {
    swapchain.framebuffers.sZero();
    swapchain.framebuffers.setCount(swapchain.images.count());

    for (0..swapchain.framebuffers.count()) |i| {
        var attachment: *c.VkImageView = &swapchain.image_views.items[i];

        const frame_buffer_info = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .renderPass = vk_render_pass,
            .attachmentCount = 1,
            .pAttachments = attachment,
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        };

        const result = c.vkCreateFramebuffer(vk_logical, &frame_buffer_info, null, &swapchain.framebuffers.items[i]);
        if (result != VK_SUCCESS) {
            return VkError.CreateFramebuffers;
        }
    }
}

fn createCommandPools() !void {
    var command_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = physical.present_idx.?,
    };

    var result = c.vkCreateCommandPool(vk_logical, &command_pool_info, null, &present_command_pool);
    if (result != VK_SUCCESS) {
        return VkError.CreateCommandPool;
    }

    command_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = physical.graphics_idx.?,
    };

    result = c.vkCreateCommandPool(vk_logical, &command_pool_info, null, &graphics_command_pool);
    if (result != VK_SUCCESS) {
        return VkError.CreateCommandPool;
    }

    if (physical.compute_idx != null) {
        command_pool_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = physical.compute_idx.?,
        };

        result = c.vkCreateCommandPool(vk_logical, &command_pool_info, null, &compute_command_pool);
        if (result != VK_SUCCESS) {
            return VkError.CreateCommandPool;
        }
    }

    if (physical.transfer_idx != null) {
        command_pool_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = physical.transfer_idx.?,
        };

        result = c.vkCreateCommandPool(vk_logical, &command_pool_info, null, &transfer_command_pool);
        if (result != VK_SUCCESS) {
            return VkError.CreateCommandPool;
        }
    }
}

fn createVertexBuffer() !void {
    const buffer_size = @sizeOf(@TypeOf(vertices[0])) * vertices.len;
    const memory_property_flags: c.VkMemoryPropertyFlags = 
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    try createBuffer(buffer_size, c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, memory_property_flags, &vertex_buffer, &vertex_buffer_memory);

    var vertex_data : ?[*]Vertex = null;
    _ = c.vkMapMemory(vk_logical, vertex_buffer_memory, 0, buffer_size, 0, @ptrCast([*c]?*anyopaque, &vertex_data));
    @memcpy(vertex_data.?[0..vertices.len], &vertices);
    c.vkUnmapMemory(vk_logical, vertex_buffer_memory);
}

fn createCommandBuffers() !void {
    var buffer_allocate_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = present_command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    };

    var result = c.vkAllocateCommandBuffers(vk_logical, &buffer_allocate_info, &present_command_buffers[0]);
    if (result != VK_SUCCESS) {
        return VkError.CreateCommandBuffer;
    }

    buffer_allocate_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = graphics_command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = MAX_FRAMES_IN_FLIGHT,
    };

    result = c.vkAllocateCommandBuffers(vk_logical, &buffer_allocate_info, &graphics_command_buffers[0]);
    if (result != VK_SUCCESS) {
        return VkError.CreateCommandBuffer;
    }

    if (physical.compute_idx != null) {
        buffer_allocate_info = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = compute_command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = MAX_FRAMES_IN_FLIGHT,
        };

        result = c.vkAllocateCommandBuffers(vk_logical, &buffer_allocate_info, &compute_command_buffers[0]);
        if (result != VK_SUCCESS) {
            return VkError.CreateCommandBuffer;
        }
    }

    if (physical.transfer_idx != null) {
        buffer_allocate_info = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = transfer_command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = MAX_FRAMES_IN_FLIGHT,
        };

        result = c.vkAllocateCommandBuffers(vk_logical, &buffer_allocate_info, &transfer_command_buffers[0]);
        if (result != VK_SUCCESS) {
            return VkError.CreateCommandBuffer;
        }
    }

}

fn createSyncObjects() !void {
    const semaphore_info = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    const fence_info = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        {
            const result = c.vkCreateSemaphore(vk_logical, &semaphore_info, null, &sem_image_available[i]);
            if (result != VK_SUCCESS) {
                return VkError.CreateSyncObjects;
            }
        }
        {
            const result = c.vkCreateSemaphore(vk_logical, &semaphore_info, null, &sem_render_finished[i]);
            if (result != VK_SUCCESS) {
                return VkError.CreateSyncObjects;
            }
        }
        {
            const result = c.vkCreateFence(vk_logical, &fence_info, null, &in_flight_fences[i]);
            if (result != VK_SUCCESS) {
                return VkError.CreateSyncObjects;
            }
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
        const result = c.vkEnumerateDeviceExtensionProperties(
            device, null, &extension_prop_ct, null
        );
        if (result != VK_SUCCESS or extension_prop_ct == 0) {
            return false;
        }
    }

    var extension_props = std.ArrayList(c.VkExtensionProperties).initCapacity(gpa.allocator(), extension_prop_ct)
        catch return false;
    extension_props.expandToCapacity();
    defer extension_props.deinit();

    {
        const result = c.vkEnumerateDeviceExtensionProperties(
            device, 
            null, 
            &extension_prop_ct, 
            @ptrCast([*c]c.VkExtensionProperties, extension_props.items)
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
        const result = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
            device, vk_surface, &swapc_details.surface_capabilities
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    var format_ct: u32 = 0;
    {
        const result = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, vk_surface, &format_ct, null);
        if (result != VK_SUCCESS or format_ct == 0) {
            return false;
        }
    }

    if (format_ct > Swapchain.MAX_FORMAT_CT) {
        return false;
    }
    swapc_details.surface_formats.setCount(format_ct);

    {
        const result = c.vkGetPhysicalDeviceSurfaceFormatsKHR(
            device, vk_surface, &format_ct, swapc_details.surface_formats.cptr()
        );
        if (result != VK_SUCCESS) {
            return false;
        }
    }

    var present_mode_ct: u32 = 0;
    {
        const result = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, vk_surface, &present_mode_ct, null);
        if (result != VK_SUCCESS or present_mode_ct == 0) {
            return false;
        }
    }

    if (present_mode_ct > Swapchain.MAX_MODE_CT) {
        return false;
    }
    swapc_details.present_modes.setCount(present_mode_ct);

    {
        const result = c.vkGetPhysicalDeviceSurfacePresentModesKHR(
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
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_ct, null);
    if (queue_family_ct == 0) {
        return false;
    }

    var queue_family_props = std.ArrayList(c.VkQueueFamilyProperties).initCapacity(gpa.allocator(), queue_family_ct)
        catch return false;
    queue_family_props.expandToCapacity();
    defer queue_family_props.deinit();

    c.vkGetPhysicalDeviceQueueFamilyProperties(
        device, &queue_family_ct, @ptrCast([*c]c.VkQueueFamilyProperties, queue_family_props.items)
    );

    var p_high_score: i32 = -100;
    var g_high_score: i32 = -100;
    var c_high_score: i32 = -100;
    var t_high_score: i32 = -100;
    for (0..queue_family_ct) |i| {
        const idx32: u32 = @intCast(u32, i);
        var vk_family_supports_present: c.VkBool32 = undefined;

        const result = c.vkGetPhysicalDeviceSurfaceSupportKHR(device, idx32, vk_surface, &vk_family_supports_present);
        if (result != VK_SUCCESS) {
            continue;
        }

        const family_props: *c.VkQueueFamilyProperties = &queue_family_props.items[i];
        const family_supports_present = vk_family_supports_present > 0;
        const family_supports_graphics = (family_props.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) > 0;
        const family_supports_compute = (family_props.queueFlags & c.VK_QUEUE_COMPUTE_BIT) > 0;
        const family_supports_transfer = (family_props.queueFlags & c.VK_QUEUE_TRANSFER_BIT) > 0;

        // preferences for queue family separation per operation: p & g together, c alone, t alone
        const p_base: i32 = @boolToInt(family_supports_present);
        const g_base: i32 = @boolToInt(family_supports_graphics);
        const pg_base: i32 = p_base + g_base;
        const c_base: i32 = @boolToInt(family_supports_compute);
        const t_base: i32 = @boolToInt(family_supports_transfer);

        const pg_score = pg_base - c_base - t_base;
        const c_score = c_base - pg_base - t_base;
        var t_score = t_base - pg_base - c_base;

        // if graphics won't be reassigned to this index and graphics idx == transfer idx, try to create separation
        // between the two by biasing transfer to reassign to this idx. this is done to attempt to account for situations
        // where two queue families score equally for graphics and transfer, which wouldn't get transfer to reassign.
        if (pg_score <= g_high_score 
            and t_score <= t_high_score
            and device_interface.graphics_idx != null
            and device_interface.transfer_idx != null
            and device_interface.graphics_idx.? == device_interface.transfer_idx.?
        ) {
            t_score += pg_base;
        }

        if (family_supports_present and pg_score > p_high_score) {
            device_interface.present_idx = idx32;
            p_high_score = pg_score;
        }
        if (family_supports_graphics and pg_score > g_high_score) {
            device_interface.graphics_idx = idx32;
            g_high_score = pg_score;
        }
        if (family_supports_compute and c_score > c_high_score) {
            device_interface.compute_idx = idx32;
            c_high_score = c_score;
        }
        if (family_supports_transfer and t_score > t_high_score) {
            device_interface.transfer_idx = idx32;
            t_high_score = t_score;
        }
    }
    // print("p: {}, g: {}, c: {}, t: {}\n", 
    //     .{
    //         device_interface.present_idx.?, 
    //         device_interface.graphics_idx.?, 
    //         device_interface.compute_idx.?, 
    //         device_interface.transfer_idx.?
    //     }
    // );

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

fn getPhysicalDeviceVRAMSize(device: VkPhysicalDevice) c.VkDeviceSize {
    var device_mem_props: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(device, &device_mem_props);

    const memory_heaps: [16]c.VkMemoryHeap = device_mem_props.memoryHeaps;
    for (0..device_mem_props.memoryHeapCount) |i| {
        const heap: *const c.VkMemoryHeap = &memory_heaps[i];
        if ((heap.flags & c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) > 0) {
            return heap.size;
        }
    }
    return 0;
}

fn chooseSwapchainSurfaceFormat(swapc: *Swapchain) c.VkSurfaceFormatKHR {
    for (swapc.surface_formats.items[0..swapc.surface_formats.count()]) |*format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format.*;
        }
    }
    return swapc.surface_formats.items[0];
}

fn chooseSwapchainPresentMode(swapc: *Swapchain) c.VkPresentModeKHR {
    for (swapc.present_modes.items[0..swapc.present_modes.count()]) |mode| {
        if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return mode;
        }
    }
    return c.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapchainExtent(swapc: *Swapchain) c.VkExtent2D {
    if (swapc.surface_capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return swapc.surface_capabilities.currentExtent;
    }

    var width: i32 = 0;
    var height: i32 = 0;
    c.glfwGetFramebufferSize(window.get(), &width, &height);

    var pixel_extent = c.VkExtent2D{ .width = @intCast(u32, width), .height = @intCast(u32, height) };
    pixel_extent.width = std.math.clamp(
        pixel_extent.width, swapc.surface_capabilities.minImageExtent.width, swapc.surface_capabilities.maxImageExtent.width
    );
    pixel_extent.height = std.math.clamp(
        pixel_extent.height, swapc.surface_capabilities.minImageExtent.height, swapc.surface_capabilities.maxImageExtent.height
    );

    return pixel_extent;
}

fn createShaderModule(file_name: []const u8) !c.VkShaderModule {
    var file = std.fs.cwd().openFile(file_name, .{}) catch return VkError.BadShaderModuleName;
    defer file.close();

    var stat = try file.stat();
    if (stat.size > 65536) {
        return VkError.ShaderTooLarge;
    }

    var buffer: [65536]u8 = undefined;
    const bytes_read: usize = file.reader().readAll(&buffer) catch return VkError.UnknownReadError;

    if (bytes_read == 0 or @mod(bytes_read, 4) != 0) {
        return VkError.BadShaderSize;
    }

    const shader_info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = bytes_read,
        .pCode = @ptrCast([*c]u32, @alignCast(@alignOf(u32), &buffer[0])),
    };

    var shader_module: c.VkShaderModule = undefined;
    const result = c.vkCreateShaderModule(vk_logical, &shader_info, null, &shader_module);
    if (result != VK_SUCCESS) {
        return VkError.CreateShaderModule;
    }

    return shader_module;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------ allocation callbacks
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// pub const PFN_vkAllocationFunction = ?*const fn (?*anyopaque, usize, usize, VkSystemAllocationScope) callconv(.C) ?*anyopaque;
// pub const PFN_vkReallocationFunction = ?*const fn (?*anyopaque, ?*anyopaque, usize, usize, VkSystemAllocationScope) callconv(.C) ?*anyopaque;
// pub const PFN_vkFreeFunction = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;
// pub const PFN_vkInternalAllocationNotification = ?*const fn (?*anyopaque, usize, VkInternalAllocationType, VkSystemAllocationScope) callconv(.C) void;
// pub const PFN_vkInternalFreeNotification = ?*const fn (?*anyopaque, usize, VkInternalAllocationType, VkSystemAllocationScope) callconv(.C) void;

// typedef enum VkSystemAllocationScope {
//     VK_SYSTEM_ALLOCATION_SCOPE_COMMAND = 0,
//     VK_SYSTEM_ALLOCATION_SCOPE_OBJECT = 1,
//     VK_SYSTEM_ALLOCATION_SCOPE_CACHE = 2,
//     VK_SYSTEM_ALLOCATION_SCOPE_DEVICE = 3,
//     VK_SYSTEM_ALLOCATION_SCOPE_INSTANCE = 4,
// } VkSystemAllocationScope;

pub fn vkInterfaceAllocate(
    user_data: ?*anyopaque, 
    sz: usize, 
    alignment: usize, 
    alloc_scope: c.VkSystemAllocationScope
) callconv(.C) ?*anyopaque {
    _ = user_data;
    _ = sz;
    _ = alignment;
    _ = alloc_scope;
}

pub fn vkInterfaceReallocate(
    user_data: ?*anyopaque, 
    original_alloc: ?*anyopaque, 
    sz: usize, 
    alignment: usize, 
    alloc_scope: c.VkSystemAllocationScope
) callconv(.C) ?*anyopaque {
    _ = user_data;
    _ = original_alloc;
    _ = sz;
    _ = alignment;
    _ = alloc_scope;
}

pub fn vkInterfaceFree(user_data: ?*anyopaque, alloc: ?*anyopaque) callconv(.C) void {
    _ = user_data;
    _ = alloc;
}

pub fn vkInterfaceInternalAllocateNotification(
    user_data: ?*anyopaque, 
    sz: usize, 
    alloc_type: c.VkInternalAllocationType, 
    alloc_scope: c.VkSystemAllocationScope
) callconv(.C) void {
    _ = user_data;
    _ = sz;
    _ = alloc_type;
    _ = alloc_scope;
}

pub fn vkInterfaceInternalFreeNotification(
    user_data: ?*anyopaque, 
    sz: usize, 
    alloc_type: c.VkInternalAllocationType, 
    alloc_scope: c.VkSystemAllocationScope
) callconv(.C) void {
    _ = user_data;
    _ = sz;
    _ = alloc_type;
    _ = alloc_scope;
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
    dtype: c.VkPhysicalDeviceType = c.VK_PHYSICAL_DEVICE_TYPE_OTHER,
    sz: c.VkDeviceSize = 0,
    present_idx: ?u32 = null,
    graphics_idx: ?u32 = null,
    compute_idx: ?u32 = null,
    transfer_idx: ?u32 = null,
    qfam_capabilities: QFamCapabilities = QFamCapabilities.None,
    qfam_unique_indices: LocalArray(u32, 4) = LocalArray(u32, 4).new(),

    pub fn reset(self: *PhysicalDevice) void {
        self.* = PhysicalDevice{};
    }

    pub fn getUniqueQueueFamilyIndices(self: *PhysicalDevice) *LocalArray(u32, 4) {
        if (self.qfam_unique_indices.count() == 0) {
            if (self.present_idx != null) {
                self.qfam_unique_indices.push(self.present_idx.?);
            }
            if (self.graphics_idx != null and self.qfam_unique_indices.find(self.graphics_idx.?) == null) {
                self.qfam_unique_indices.push(self.graphics_idx.?);
            }
            if (self.compute_idx != null and self.qfam_unique_indices.find(self.compute_idx.?) == null) {
                self.qfam_unique_indices.push(self.compute_idx.?);
            }
            if (self.transfer_idx != null and self.qfam_unique_indices.find(self.transfer_idx.?) == null) {
                self.qfam_unique_indices.push(self.transfer_idx.?);
            }
        }
        return &self.qfam_unique_indices;
    } 
};

const Swapchain = struct {
    const MAX_FORMAT_CT: u32 = 8;
    const MAX_MODE_CT: u32 = 8;
    const MAX_IMAGE_CT: u32 = 4;
    
    vk_swapchain: c.VkSwapchainKHR = null,
    extent: c.VkExtent2D = c.VkExtent2D {
        .width = 0,
        .height = 0,
    },
    images: LocalArray(c.VkImage, MAX_IMAGE_CT) = LocalArray(c.VkImage, MAX_IMAGE_CT).new(),
    image_fmt: c.VkFormat = undefined,
    image_views: LocalArray(c.VkImageView, MAX_IMAGE_CT) = LocalArray(c.VkImageView, MAX_IMAGE_CT).new(),
    framebuffers: LocalArray(c.VkFramebuffer, MAX_IMAGE_CT) = LocalArray(c.VkFramebuffer, MAX_IMAGE_CT).new(),
    surface_capabilities: c.VkSurfaceCapabilitiesKHR = c.VkSurfaceCapabilitiesKHR {
        .minImageCount = 0,
        .maxImageCount = 0,
        .currentExtent = c.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .minImageExtent = c.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .maxImageExtent = c.VkExtent2D {
            .width = 0,
            .height = 0,
        },
        .maxImageArrayLayers = 0,
        .supportedTransforms = 0,
        .currentTransform = 0,
        .supportedCompositeAlpha = 0,
        .supportedUsageFlags = 0,
    },
    surface_formats : LocalArray(c.VkSurfaceFormatKHR, MAX_FORMAT_CT) = LocalArray(c.VkSurfaceFormatKHR, MAX_FORMAT_CT).new(),
    present_modes : LocalArray(c.VkPresentModeKHR, MAX_MODE_CT) = LocalArray(c.VkPresentModeKHR, MAX_MODE_CT).new(),

    pub fn reset(self: *Swapchain) void {
        self.* = Swapchain{};
    }
};

fn findMemoryType(type_filter: u32, props: c.VkMemoryPropertyFlags) !u32 {
    var memory_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical.vk_physical, &memory_properties);

    for (0..memory_properties.memoryTypeCount) |i| {
        const i_u32 = @intCast(u32, i);
        const suitable_type = (type_filter & @shlExact(@as(u32, 1), @intCast(u5, i_u32))) != 0;
        const cpu_accessible = (memory_properties.memoryTypes[i].propertyFlags & @intCast(u32, props)) == @intCast(u32, props);
        if (suitable_type and cpu_accessible) {
            return i_u32;
        }
    }

    return VkError.NoSuitableGraphicsMemoryType;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// VkInstance is ?*struct_VkInstance_T
var vk_instance: VkInstance = null;
var vk_surface: VkSurfaceKHR = null;
var vk_logical: VkDevice = null;
var vk_render_pass: VkRenderPass = null;
var vk_pipeline_layout: VkPipelineLayout = null;
var vk_pipeline: VkPipeline = null;
var sem_image_available: [MAX_FRAMES_IN_FLIGHT]VkSemaphore = .{null, null};
var sem_render_finished: [MAX_FRAMES_IN_FLIGHT]VkSemaphore = .{null, null};
var in_flight_fences: [MAX_FRAMES_IN_FLIGHT]VkFence = .{null, null};

var vma_allocator: c.VmaAllocator = null;

var vertex_buffer: VkBuffer = null;
var vertex_buffer_memory: VkDeviceMemory = null;

var present_command_pool: VkCommandPool = null;
var graphics_command_pool: VkCommandPool = null;
var compute_command_pool: VkCommandPool = null;
var transfer_command_pool: VkCommandPool = null;

var present_queue: VkQueue = null;
var graphics_queue: VkQueue = null;
var compute_queue: VkQueue = null;
var transfer_queue: VkQueue = null;

var present_command_buffers: [MAX_FRAMES_IN_FLIGHT]VkCommandBuffer = .{null, null};
var graphics_command_buffers: [MAX_FRAMES_IN_FLIGHT]VkCommandBuffer = .{null, null};
var compute_command_buffers: [MAX_FRAMES_IN_FLIGHT]VkCommandBuffer = .{null, null};
var transfer_command_buffers: [MAX_FRAMES_IN_FLIGHT]VkCommandBuffer = .{null, null};

var swapchain : Swapchain = Swapchain{};
var physical: PhysicalDevice = PhysicalDevice{};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var current_frame: u32 = 0;
var framebuffer_resized: bool = false;

var vertices: [3]Vertex = .{
    Vertex{.position = Vec2.init(0.0, -0.5), .color = Vec3.init(1.0, 1.0, 0.8)},
    Vertex{.position = Vec2.init(0.5, 0.5),  .color = Vec3.init(0.0, 1.0, 0.0)},
    Vertex{.position = Vec2.init(-0.5, 0.5),  .color = Vec3.init(0.0, 0.0, 1.0)},
};

var vk_allocation_callbacks = c.VkAllocationCallbacks{
    .pUserData = null,
    .pfnAllocation = vkInterfaceAllocate,
    .pfnReallocation = vkInterfaceReallocate,
    .pfnFree = vkInterfaceFree,
    .pfnInternalAllocation = vkInterfaceInternalAllocateNotification,
    .pfnInternalFree = vkInterfaceInternalFreeNotification,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const ONE_SECOND_IN_NANOSECONDS: u32 = 1_000_000_000;
const MAX_FRAMES_IN_FLIGHT: u32 = 2;

const OP_TYPE = enum {Present, Graphics, Compute, Transfer};

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
    CreateRenderPass,
    BadShaderModuleName,
    BadShaderSize,
    ShaderTooLarge,
    UnknownReadError, // hate this
    CreateShaderModule,
    CreatePipelineLayout,
    CreatePipeline,
    CreateFramebuffers,
    CreateCommandPool,
    CreateCommandBuffer,
    CreateSyncObjects,
    RecordCommandBuffer,
    DrawFrame,
    AcquireSwapchainImage,
    PresentSwapchainImage,
    CreateVertexBuffer,
    NoSuitableGraphicsMemoryType,
    AllocatevertexBufferMemory,
    CreateBuffer,
    AllocateBufferMemory,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const c = @cImport({
    @cInclude("glfwvulk.h");
    @cInclude("vk_mem_alloc.h");
});

const VkResult = c.VkResult;
const VK_SUCCESS = c.VK_SUCCESS;
const VkInstance = c.VkInstance;
const GLFWwindow = c.GLFWwindow;
const VkPhysicalDevice = c.VkPhysicalDevice;
const VkSurfaceKHR = c.VkSurfaceKHR;
const VkDevice = c.VkDevice;
const VkQueue = c.VkQueue;
const VkRenderPass = c.VkRenderPass;
const VkPipelineLayout = c.VkPipelineLayout;
const VkPipeline = c.VkPipeline;
const VkCommandPool = c.VkCommandPool;
const VkCommandBuffer = c.VkCommandBuffer;
const VkSemaphore = c.VkSemaphore;
const VkFence = c.VkFence;
const VkBuffer = c.VkBuffer;
const VkDeviceMemory = c.VkDeviceMemory;

const std = @import("std");
const print = std.debug.print;
const array = @import("array.zig");
const window = @import("window.zig");
const LocalArray = array.LocalArray;
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const getScopeTimerID = benchmark.getScopeTimerID;
const gfxmath = @import("gfxmath.zig");
const Vertex = gfxmath.Vertex;
const linalg = @import("linalg.zig");
const Vec2 = linalg.Vec2;
const Vec3 = linalg.Vec3;