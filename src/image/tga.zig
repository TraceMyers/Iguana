const std = @import("std");
const imagef = @import("image.zig");
const Image = imagef.Image;
const memory = @import("../memory.zig");

pub fn load(
    file: *std.fs.File, image: *Image, allocator: std.mem.Allocator, options: *const imagef.ImageLoadOptions
) !void {
    _ = file;
    _ = image;
    _ = allocator;
    _ = options;
}

const TgaImageType = enum(u8) {
    NoData = 0,
    ColorMap = 1,
    TrueColor = 2,
    Greyscale = 3,
    RleColorMap = 9,
    RleTrueColor = 10,
    RleGreyscale = 11,
    HuffmanDeltaRleColorMap = 32,
    HuffmanDeltaRleQuadtreeColorMap = 33,
};

const TgaColorMapSpec = extern struct {
    first_color_map_idx: u16,
    color_map_len: u16,
    color_map_entry_bit_ct: u8
};

const TgaImageSpec = extern struct {
    origin_x: u16,
    origin_y: u16,
    image_width: u16,
    image_height: u16,
    color_depth: u8,
    descriptor: u8
};

const TgaHeader = extern struct {
    id: u8,
    color_map_type: u8,
    image_type: TgaImageType,
    color_map_spec: TgaColorMapSpec,
    image_spec: TgaImageSpec,
};

const