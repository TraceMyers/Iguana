const std = @import("std");
const c = @import("../ext.zig").c;
const window = @import("window.zig");
const print = std.debug.print;

pub fn init() void {
    for (0..keyboard_max) |i| {
        keyboard_switches[i] = .None;
    }
}

pub fn frameUpdate() void {
    for (0..keyboard_max) |i| {
        const glfw_state: u32 = @intCast(u32, c.glfwGetKey(window.get(), @intCast(c_int, i)));
        const key_state = keyboard_switches[i];
        if (glfw_state == c.GLFW_PRESS) {
            if (key_state == .Released or key_state == .None) {
                keyboard_switches[i] = .Pressed;
            }
            else if (key_state == .Pressed) {
                keyboard_switches[i] = .Held;
            }
        }
        else if (glfw_state == c.GLFW_RELEASE) {
            if (key_state == .Pressed or key_state == .Held) {
                keyboard_switches[i] = .Released;
            }
            else if (key_state == .Released) {
                keyboard_switches[i] = .None;
            }
        }
    }
}

pub inline fn keyboardCheck(input: KeyboardInput) bool {
    return keyboard_switches[@enumToInt(input)].isOn();
}

pub inline fn keyboardPressed(input: KeyboardInput) bool {
    keyboard_switches[@enumToInt(input)] == SwitchState.Pressed;
}

pub inline fn keyboardReleased(input: KeyboardInput) bool {
    return keyboard_switches[@enumToInt(input)] == SwitchState.Released;
}

pub inline fn keyboardState(input: KeyboardInput) SwitchState {
    return keyboard_switches[@enumToInt(input)];
}

pub const KeyboardInput = enum(u16) {
    Num0 = c.GLFW_KEY_0,
    Num1 = c.GLFW_KEY_1,
    Num2 = c.GLFW_KEY_2,
    Num3 = c.GLFW_KEY_3,
    Num4 = c.GLFW_KEY_4,
    Num5 = c.GLFW_KEY_5,
    Num6 = c.GLFW_KEY_6,
    Num7 = c.GLFW_KEY_7,
    Num8 = c.GLFW_KEY_8,
    Num9 = c.GLFW_KEY_9,
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
    Space = c.GLFW_KEY_SPACE,
    Up = c.GLFW_KEY_UP,
    Down = c.GLFW_KEY_DOWN,
    Left = c.GLFW_KEY_LEFT,
    Right = c.GLFW_KEY_RIGHT,
    None = std.math.maxInt(u16),
};

pub const ControllerInput = enum(u8) {
    None = std.math.maxInt(u8),
};

pub const SwitchState = enum(u4) {
    None = 0x0,     // no input
    // OnPressed = 0x1, ghost state. (OnPressed | Held) = Pressed
    Held = 0x2,     // switch is on, but it was not switched on this frame
    Pressed = 0x3,  // switched on this frame
    Released = 0x4, // switched off this frame

    pub inline fn isOn(self: SwitchState) bool {
        return (@enumToInt(self) & @enumToInt(SwitchState.Pressed)) != 0;
    }

    pub inline fn isOff(self: SwitchState) bool {
        return (@enumToInt(self) & @enumToInt(SwitchState.Pressed)) == 0;
    }
};

pub const InputTorch = packed struct {
    id: u16,
    controller_input: ControllerInput = .None,
    keyboard_input: KeyboardInput = .None,
};

const keyboard_max: comptime_int = 350;

var keyboard_switches: [keyboard_max]SwitchState = undefined;
