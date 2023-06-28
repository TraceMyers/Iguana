
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn init(width: i32, height: i32, name_opt: ?[*c]const u8) !void {
    const init_state: c_int = vk.glfwInit();
    if (init_state == vk.GLFW_FALSE) {
        return GLFWError.InitFail;
    }

    vk.glfwWindowHint(vk.GLFW_CLIENT_API, vk.GLFW_NO_API);
    vk.glfwWindowHint(vk.GLFW_RESIZABLE, vk.GLFW_TRUE);

    if (name_opt) |name| {
        window = vk.glfwCreateWindow(width, height, name, null, null);
    }
    else {
        window = vk.glfwCreateWindow(width, height, "It's a window!", null, null);
    }
    _ = vk.glfwSetFramebufferSizeCallback(window, resizeCallback);

    if (window == null) {
        return GLFWError.WindowCreateFail;
    }
}

pub inline fn get() *GLFWwindow {
    return window.?;
}

pub inline fn pollEvents() void {
    vk.glfwPollEvents();
}

pub inline fn shouldClose() bool {
    if (vk.glfwWindowShouldClose(window.?) > 0) {
        return true;
    }
    return false;
}

pub inline fn cleanup() void {
    if (window) |win| {
        vk.glfwDestroyWindow(win);
    }
    vk.glfwTerminate();
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------- interaction
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn resizeCallback(win: ?*GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = win;
    _ = width;
    _ = height;
    vkinterface.setFramebufferResized();
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

var window: ?*GLFWwindow = null;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const GLFWError = error {
    InitFail,
    WindowCreateFail
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const vk = @import("vkdecl.zig");
const GLFWwindow = vk.GLFWwindow;
const print = @import("std").debug.print;
const vkinterface = @import("vkinterface.zig");