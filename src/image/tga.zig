const std = @import("std");
const imagef = @import("image.zig");
const Image = imagef.Image;
const memory = @import("../memory.zig");
const ImageError = imagef.ImageError;
const print = std.debug.print;
const string = @import("../string.zig");

/// - Color Types
///     - PsuedoColor: pixels are indices to a color table/map
///     - TrueColor: pixels are subdivided into rgb fields
///     - DirectColor: pixels are subdivided into r, g, and b indices to independent color tables defining intensity
/// - TGA files are little-endian

pub fn load(
    file: *std.fs.File, image: *Image, allocator: std.mem.Allocator, options: *const imagef.ImageLoadOptions
) !void {
    var info = TgaInfo{};
    try readFooter(file, &info);
    try readHeader(file, &info);
    _ = options;
    _ = image;
    _ = allocator;
}

pub fn readFooter(file: *std.fs.File, info: *TgaInfo) !void {
    const stat = try file.stat();
    info.file_sz = stat.size;
    if (info.file_sz > memory.MAX_SZ) {
        return ImageError.TooLarge;
    }
    if (info.file_sz < tga_min_sz) {
        return ImageError.InvalidSizeForFormat;
    }

    const footer_loc = stat.size - footer_end_offset;
    try file.seekTo(footer_loc);

    info.footer = try file.reader().readStruct(TgaFooter);
    info.file_type = if (string.same(info.footer.signature[0..], tga_signature)) TgaFileType.V2 else TgaFileType.V1;

    try file.seekTo(0);
}

pub fn readHeader(file: *std.fs.File, info: *TgaInfo) !void {
    if (info.file_type == .V2) {
        if (info.file_sz < tga_min_sz + footer_end_offset) {
            return ImageError.InvalidSizeForFormat;
        }
    }

    info.header = try file.reader().readStruct(TgaHeader);
    print("\n{any}\n", .{info.header});
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

const ExtensionArea = extern struct {
    extension_sz: u16,
    author_name: [41]u8,
    author_comments: [324]u8,
    timestamp: [6]u16,
    job_name: [41]u8,
    job_time: [3]u16,
    software_id: [41]u16,
    software_version: [3]u8,
    key_color: u32,
    pixel_aspect_ratio: [2]u16,
    gamma: [2]u16,
    color_correction_offset: u32,
    postage_stamp_offset: u32,
    scanline_offset: u32,
    attributes_type: u8
};

const TgaFooter = extern struct {
    extension_area_offset: u32,
    developer_directory_offset: u32,
    signature: [16]u8
};

const TgaInfo = extern struct {
    file_type: TgaFileType = .None,
    file_sz: usize = 0,
    header: TgaHeader = undefined,
    extension_area: ExtensionArea = undefined,
    footer: TgaFooter = undefined,
    scanline_table: [*]u8 = undefined,
    postage_stamp_table: [*]u8 = undefined,
    color_correction_table: [*]u16 = undefined,
    scanline_len: u32 = 0,
    postage_len: u32 = 0,
    color_correction_len: u32 = 0,
};

const TgaFileType = enum(u8) { None, V1, V2 };

const tga_min_sz = @sizeOf(TgaHeader);
const footer_end_offset = @sizeOf(TgaFooter) + 2;
const tga_signature = "TRUEVISION-XFILE";