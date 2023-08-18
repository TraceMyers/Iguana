
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn init(width: i32, height: i32, name_opt: ?[*c]const u8) !void {
    const init_state: c_int = c.glfwInit();
    if (init_state == c.GLFW_FALSE) {
        return GLFWError.InitFail;
    }

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);

    if (name_opt) |name| {
        window = c.glfwCreateWindow(width, height, name, null, null);
    }
    else {
        window = c.glfwCreateWindow(width, height, "It's a window!", null, null);
    }
    _ = c.glfwSetFramebufferSizeCallback(window, resizeCallback);

    // c.glfwSwapBuffers(window: ?*GLFWwindow)
    if (window == null) {
        return GLFWError.WindowCreateFail;
    }
}

pub inline fn get() *c.GLFWwindow {
    return window.?;
}

pub inline fn pollEvents() void {
    c.glfwPollEvents();
}

pub inline fn shouldClose() bool {
    if (c.glfwWindowShouldClose(window.?) > 0) {
        return true;
    }
    return false;
}

pub inline fn cleanup() void {
    if (window) |win| {
        c.glfwDestroyWindow(win);
    }
    c.glfwTerminate();
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------- interaction
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn resizeCallback(win: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = win;
    _ = width;
    _ = height;
    vk.setFramebufferResized();
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

var window: ?*c.GLFWwindow = null;

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

const vk = @import("vulkan.zig");
const gfx = @import("graphics.zig");
const c = gfx.c;
const print = @import("std").debug.print;