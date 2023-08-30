const std = @import("std");
const c = @import("../ext.zig").c;
const window = @import("window.zig");
const print = std.debug.print;

pub fn init() void {
    for (0..keyboard_max) |i| {
        keyboard_switches[i] = InputSwitch{};
    }
}

pub fn frameUpdate(delta_time: f32) void {
    _ = delta_time;
    for (0..keyboard_max) |i| {
        const key_state: i32 = c.glfwGetKey(window.get(), @intCast(c_int, i));
        var key_switch: *InputSwitch = &keyboard_switches[i];
        if (key_state == c.GLFW_PRESS) {
            if (key_switch.states[@enumToInt(SwitchState.Held)]) {
                key_switch.states[@enumToInt(SwitchState.Pressed)] = false;
                key_switch.states[@enumToInt(SwitchState.Released)] = false;
            }
            else {
                key_switch.states[@enumToInt(SwitchState.Held)] = true;
                key_switch.states[@enumToInt(SwitchState.Pressed)] = true;
                key_switch.states[@enumToInt(SwitchState.Released)] = false;
            }
        }
        else {
            if (key_switch.states[@enumToInt(SwitchState.Held)]) {
                key_switch.states[@enumToInt(SwitchState.Held)] = false;
                key_switch.states[@enumToInt(SwitchState.Pressed)] = false;
                key_switch.states[@enumToInt(SwitchState.Released)] = true;
            }
            else {
                key_switch.states[@enumToInt(SwitchState.Pressed)] = false;
                key_switch.states[@enumToInt(SwitchState.Released)] = false;
            }
        }
    }
}

pub const KeyboardInput = enum(u16) {
    num_0 = c.GLFW_KEY_0,
    num_1 = c.GLFW_KEY_1,
    num_2 = c.GLFW_KEY_2,
    num_3 = c.GLFW_KEY_3,
    num_4 = c.GLFW_KEY_4,
    num_5 = c.GLFW_KEY_5,
    num_6 = c.GLFW_KEY_6,
    num_7 = c.GLFW_KEY_7,
    num_8 = c.GLFW_KEY_8,
    num_9 = c.GLFW_KEY_9,
    Q = c.GLFW_KEY_Q,
    W = c.GLFW_KEY_W,
    E = c.GLFW_KEY_E,
    R = c.GLFW_KEY_R,
    T = c.GLFW_KEY_T,
    Y = c.GLFW_KEY_Y,
    U = c.GLFW_KEY_U,
    I = c.GLFW_KEY_I,
    O = c.GLFW_KEY_O,
    P = c.GLFW_KEY_P,
    A = c.GLFW_KEY_A,
    S = c.GLFW_KEY_S,
    D = c.GLFW_KEY_D,
    F = c.GLFW_KEY_F,
    G = c.GLFW_KEY_G,
    H = c.GLFW_KEY_H,
    J = c.GLFW_KEY_J,
    K = c.GLFW_KEY_K,
    L = c.GLFW_KEY_L,
    Z = c.GLFW_KEY_Z,
    X = c.GLFW_KEY_X,
    C = c.GLFW_KEY_C,
    V = c.GLFW_KEY_V,
    B = c.GLFW_KEY_B,
    N = c.GLFW_KEY_N,
    M = c.GLFW_KEY_M,
    space = c.GLFW_KEY_SPACE,
    up = c.GLFW_KEY_UP,
    down = c.GLFW_KEY_DOWN,
    left = c.GLFW_KEY_LEFT,
    right = c.GLFW_KEY_RIGHT,
};

const keyboard_max: comptime_int = 348;
var keyboard_switches: [keyboard_max]InputSwitch = undefined;

const InputSwitch = struct {
    states: [3]bool = .{ false, false, false },
};

pub const SwitchState = enum(u8) {
    Held = 0,
    Pressed = 1,
    Released = 2
};

pub inline fn keyboardCheck(input: KeyboardInput, state: SwitchState) bool {
    return keyboard_switches[@enumToInt(input)].states[@enumToInt(state)];
}