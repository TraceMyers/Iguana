
pub const RGBA32 = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

pub const fMVP = struct {
    model: fMat4x4 align(16) = undefined,
    view: fMat4x4 align(16) = undefined,
    projection: fMat4x4 align(16) = undefined,
};

const nd = @import("ndmath.zig");
const fMat4x4 = nd.fMat4x4;