// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- load
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn loadImage(file_path: []const u8, format: ImageFormat, allocator: kMem.Allocator) !Image {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    if (format == ImageFormat.Infer) {
        var extension_idx: ?usize = str.findR(file_path, '.');
        if (extension_idx == null) {
            return ImageError.NoFileExtension;
        }

        extension_idx.? += 1;
        const extension_len = file_path.len - extension_idx.?;
        if (extension_len > 4 or extension_len < 3) {
            return ImageError.InvalidFileExtension;
        }

        const extension: []const u8 = file_path[extension_idx.?..];
        var extension_lower_buf = LocalStringBuffer(4).new();
        try extension_lower_buf.appendLower(extension);
        const extension_lower = extension_lower_buf.string();

        if (str.same(extension_lower, "bmp") or str.same(extension_lower, "dib")) {
            return try loadBmp(&file, allocator);
        }
        else if (str.same(extension_lower, "jpg") or str.same(extension_lower, "jpeg")) {
            return try loadJpg(&file, allocator);
        }
        else if (str.same(extension_lower, "png")) {
            return try loadPng(&file, allocator);
        }
        else {
            return ImageError.InvalidFileExtension;
        }
    }
    else return switch (format) {
        .Bmp => try loadBmp(&file, allocator),
        .Jpg => try loadJpg(&file, allocator),
        .Png => try loadPng(&file, allocator),
        else => unreachable,
    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------- load by encoding
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn loadBmp(file: *std.fs.File, allocator: kMem.Allocator) !Image {
    var buffer: []u8 = try loadImageFromDisk(file, allocator, min_sz_bmp);
    defer allocator.free(buffer);

    const identity = buffer[0..2];
    if (!str.same(identity, "BM")) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }

    // -- OG file header
    const file_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }

    var info = BitmapInfo{};
    info.data_offset = std.mem.readIntNative(u32, buffer[10..14]);

    // -- a forest of info headers beyond this point. we capture the headers you'd expect to see these days.
    info.header_sz = std.mem.readIntNative(u32, buffer[14..18]);

    if (buffer.len <= info.header_sz + bmp_file_header_sz or buffer.len <= info.data_offset) {
        return ImageError.UnexpectedEOF;
    }

    var color_table = BitmapColorTable{};
    var buffer_pos: usize = undefined;
    switch (info.header_sz) {
        bmp_info_header_sz_core => buffer_pos = try bmpGetCoreInfo(buffer, &info, file_sz, &color_table),
        bmp_info_header_sz_v1 => buffer_pos = try bmpGetV1Info(buffer, &info, &color_table),
        bmp_info_header_sz_v4 => buffer_pos = try bmpGetV4Info(buffer, &info, &color_table),
        bmp_info_header_sz_v5 => buffer_pos = try bmpGetV5Info(buffer, &info, &color_table),
        else => return ImageError.BmpInvalidHeaderSizeOrVersionUnsupported, 
    }
    // -- end headers and color table data

    if (info.data_offset + info.data_size != buffer.len) {
        if (info.data_size != 0) {
            return ImageError.BmpInvalidSizeInfo;
        }
        else {
            info.data_size = @intCast(u32, buffer.len) - info.data_offset;
        }
    }

    if (buffer_pos != info.data_offset) {
        return ImageError.BmpInvalidSizeInfo;
    }

    print("color space: {any}\n", .{info.color_space});

    var image = Image{};
    if (info.header_type == .Core) {
        try bmpCreateImage(buffer, &image, &info, &color_table);
    }

    print("\n// ------------------ //\n\n", .{});
    return image;
}

pub fn loadJpg(file: *std.fs.File, enclave: kMem.Allocator) !Image {
    _ = file;
    _ = enclave;
    print("loading jpg\n", .{});
    return Image{};
}

pub fn loadPng(file: *std.fs.File, enclave: kMem.Allocator) !Image {
    _ = file;
    _ = enclave;
    print("loading png\n", .{});
    return Image{};
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------- load helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadImageFromDisk(file: *std.fs.File, allocator: anytype, min_sz: usize) ![]u8 {
    const stat = try file.stat();
    if (stat.size > kMem.MAX_SZ) {
        return ImageError.TooLarge;
    }

    if (stat.size < min_sz) {
        return ImageError.InvalidSizeForFormat;
    }

    var buffer: []u8 = try allocator.alloc(u8, stat.size);
    const bytes_read: usize = try file.reader().readAll(buffer);

    if (bytes_read != stat.size) {
        // the reader reached the end of the file before reading all of the file's bytes according to file.stat()
        return ImageError.PartialRead;
    }

    return buffer;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------ bitmap helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn bmpGetCoreInfo(buffer: []u8, info: *BitmapInfo, file_sz: u32, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    info.data_size = file_sz - info.data_offset;
    color_table._type = BitmapColorTableType.BGR24;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.BGR24);
    return table_offset + color_table.length * @sizeOf(gfx.BGR24);
}

fn bmpGetV1Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V1;
    bmpFillV1HeaderPart(buffer, info);
    color_table._type = BitmapColorTableType.BGR32;
    var mask_offset: usize = 0;
    if (info.compression == BitmapCompression.BITFIELDS) {
        bmpGetColorMasks(buffer, info, false);
        mask_offset = 12;
    }
    else if (info.compression == BitmapCompression.ALPHABITFIELDS) {
        bmpGetColorMasks(buffer, info, true);
        mask_offset = 16;
    }
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v1 + mask_offset;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.BGR32);
    return table_offset + color_table.length * @sizeOf(gfx.BGR32);
}

fn bmpGetV4Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V4;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    color_table._type = BitmapColorTableType.BGR32;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v4;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.BGR32);
    return table_offset + color_table.length * @sizeOf(gfx.BGR32);
}

fn bmpGetV5Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V5;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    bmpFillV5HeaderPart(buffer, info);
    color_table._type = BitmapColorTableType.BGR32;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v5;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.BGR32);
    return table_offset + color_table.length * @sizeOf(gfx.BGR32);
}

inline fn bmpFillV1HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[28..30]));
    info.compression = @intToEnum(BitmapCompression, std.mem.readIntNative(u32, buffer[30..34]));
    info.data_size = std.mem.readIntNative(u32, buffer[34..38]);
    info.color_ct = std.mem.readIntNative(u32, buffer[46..50]);
}

fn bmpFillV4HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    bmpGetColorMasks(buffer, info, true);
    info.color_space = @intToEnum(BitmapColorSpace, std.mem.readIntNative(u32, buffer[70..74]));
    if (info.color_space == BitmapColorSpace.sRGB or info.color_space == BitmapColorSpace.WindowsCS) {
        return;
    }
    var buffer_casted = @ptrCast([*]FxPt2Dot30, @alignCast(@alignOf(FxPt2Dot30), &buffer[72]));
    @memcpy(info.cs_points.red[0..3], buffer_casted[0..3]);
    @memcpy(info.cs_points.green[0..3], buffer_casted[3..6]);
    @memcpy(info.cs_points.blue[0..3], buffer_casted[6..9]);
    info.red_gamma = std.mem.readIntNative(u32, buffer[110..114]);
    info.green_gamma = std.mem.readIntNative(u32, buffer[114..118]);
    info.blue_gamma = std.mem.readIntNative(u32, buffer[118..122]);
}

inline fn bmpFillV5HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.profile_data = std.mem.readIntNative(u32, buffer[126..130]);
    info.profile_size = std.mem.readIntNative(u32, buffer[130..134]);
}

inline fn bmpGetColorMasks(buffer: []u8, info: *BitmapInfo, alpha: bool) void {
    info.red_mask = std.mem.readIntNative(u32, buffer[54..58]);
    info.green_mask = std.mem.readIntNative(u32, buffer[58..62]);
    info.blue_mask = std.mem.readIntNative(u32, buffer[62..66]);
    if (alpha) {
        info.alpha_mask = std.mem.readIntNative(u32, buffer[66..70]);
    }
}

fn bmpGetColorTable(
    buffer: []u8, info: *const BitmapInfo, color_table: *BitmapColorTable, comptime table_type: type
) !void {
    var data_casted = @ptrCast([*]table_type, @alignCast(@alignOf(table_type), &buffer[0]));
    var table_buffer = @ptrCast([*]table_type, @alignCast(@alignOf(table_type), &color_table.buffer[0]));

    switch (info.color_depth) {
        32, 24, 16 => {
            if (info.color_ct > 0) {
                if (info.color_ct <= 256) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                return;
            }
        },
        8 => {
            if (info.color_ct > 0) {
                if (info.color_ct <= 256) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                color_table.length = 256;
            }
        },
        4 => {
            if (info.color_ct > 0) {
                if (info.color_ct <= 16) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                color_table.length = 16;
            }
        },
        1 => {
            if (info.color_ct == 0 or info.color_ct == 2) {
                color_table.length = 2;
            }
            else {
                return ImageError.BmpInvalidColorCount;
            }
        },
        else => return ImageError.BmpInvalidColorDepth,
    }

    if (buffer.len <= color_table.length * @sizeOf(table_type)) {
        return ImageError.UnexpectedEOF;
    }
    else {
        @memcpy(table_buffer[0..color_table.length], data_casted[0..color_table.length]);
    }
}

fn bmpCreateImage(buffer: []u8, image: *Image, info: *const BitmapInfo, color_table: *const BitmapColorTable) !void {
    _ = buffer;
    _ = image;
    _ = info;
    _ = color_table;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const min_sz_bmp = 36;

const bmp_file_header_sz = 14;
const bmp_info_header_sz_core = 12;
const bmp_info_header_sz_v1 = 40;
const bmp_info_header_sz_v4 = 108;
const bmp_info_header_sz_v5 = 124;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- pub enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageFormat = enum { Infer, Bmp, Jpg, Png };

pub const ImageType = enum { None, RGB, RGBA };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const BitmapColorTableType = enum { None, BGR24, BGR32 };

const BitmapHeaderType = enum(u8) { None, Core, V1, V4, V5 };

const BitmapCompression = enum(u32) { 
    RGB, RLE8, RLE4, BITFIELDS, JPEG, PNG, ALPHABITFIELDS, CMYK, CMYKRLE8, CMYKRLE4, None=std.math.maxInt(u32) 
};

const BitmapColorSpace = enum(u32) {
    CalibratedRGB = 0x0,
    ProfileLinked = 0x4c494e4b,
    ProfileEmbedded = 0x4d424544,
    WindowsCS = 0x57696e20,
    sRGB = 0x73524742,
    None = 0xffffffff,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- pub types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    bytes: ?[]u8 = null,
    _type: ImageType = .None,
    allocator: ?kMem.Allocator = null,

    pub inline fn pixelsRGB(self: *const Image) ?[]RGB24 {
        std.debug.assert(self._type == ImageType.RGB);
        if (self.bytes == null) {
            return null;
        }
        return @ptrCast([*]RGB24, @alignCast(@alignOf(RGB24), &self.bytes[0]))[0..self.width*self.height];
    }

    pub inline fn pixelsRGBA(self: *const Image) ?[]RGBA32 {
        std.debug.assert(self._type == ImageType.RGBA);
        if (self.bytes == null) {
            return null;
        }
        return @ptrCast([*]RGBA32, @alignCast(@alignOf(RGBA32), &self.bytes[0]))[0..self.width*self.height];
    }

    pub inline fn getType(self: *const Image) ImageType {
        return self._type;
    }

    pub inline fn clear(self: *Image) void {
        std.debug.assert(self.allocator != null and self.bytes != null);
        self.allocator.free(self.bytes);
        self.* = Image{};
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const ImageError = error{
    NoFileExtension,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    UnexpectedEOF,
    BmpInvalidBytesInFileHeader,
    BmpInvalidHeaderSizeOrVersionUnsupported,
    BmpInvalidDataOffset,
    BmpInvalidSizeInfo,
    BmpInvalidPlaneCt,
    BmpInvalidColorDepth,
    BmpInvalidColorCount,
    BmpInvalidColorTable,
};

const BitmapColorTable = struct {
    buffer: [256 * @sizeOf(gfx.BGR32)]u8 = undefined,
    length: usize = 0,
    _type: BitmapColorTableType = .None,

    pub fn colorSize(self: *const BitmapColorTable) usize {
        return switch(self._type) {
            .BGR24 => 3,
            .BGR32 => 4,
            else => @panic("bitmap color table's color size not set!"),
        };
    }
};

const FxPt2Dot30 = extern struct {
    data: u32,

    pub inline fn integer(self: *const FxPt2Dot30) u32 {
        return (self.data & 0xc0000000) >> 30;
    }

    pub inline fn fraction(self: *const FxPt2Dot30) u32 {
        return self.data & 0x8fffffff;
    }
};

const CieXYZTriple = extern struct {
    red: [3]FxPt2Dot30 = undefined,
    green: [3]FxPt2Dot30 = undefined,
    blue: [3]FxPt2Dot30 = undefined,
};

const BitmapInfo = extern struct {
    // offset from beginning of file to pixel data
    data_offset: u32 = 0,
    // size of the info header (comes after the file header)
    header_sz: u32 = 0,
    header_type: BitmapHeaderType = .None,
    width: i32 = 0,
    height: i32 = 0,
    // bits per pixel
    color_depth: u32 = 0,
    compression: BitmapCompression = .None,
    // pixel data size
    data_size: u32 = 0,
    // how many colors in image. mandatory for color depths of 1,2,8. if 0, using full color depth.
    color_ct: u32 = 0,
    // masks to pull color data from pixels
    red_mask: u32 = 0x0,
    green_mask: u32 = 0x0,
    blue_mask: u32 = 0x0,
    alpha_mask: u32 = 0x0,
    // how the colors should be interpreted
    color_space: BitmapColorSpace = .None,
    // if using a color space profile, info about how to interpret colors
    profile_data: u32 = undefined,
    profile_size: u32 = undefined,
    // triangle representing the color space of the image
    cs_points: CieXYZTriple = undefined,
    // function f takes two parameters: 1.) gamma and 2.) a color value c in, for example, 0 to 255. It outputs
    // a color value f(gamma, c) in 0 and 255, on a concave curve. larger gamma -> more concave.
    red_gamma: u32 = undefined,
    green_gamma: u32 = undefined,
    blue_gamma: u32 = undefined,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- tests
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// pub fn LoadImageTest() !void {
test "Load Bitmap image" {
    try kMem.autoStartup();
    defer kMem.shutdown();

    const allocator = kMem.Allocator.new(kMem.Enclave.Game);

    print("\n", .{});

    // try loadImage("test/images/puppy.bmp", ImageType.Infer, &test_img, allocator);

    var path_buf = LocalStringBuffer(128).new();

    // 2.7 has coverage over core, v1, v4, and v5
    try path_buf.append("d:/projects/zig/core/test/nocommit/bmpsuite-2.7/g/");

    // 0.9 is V1 only
    // try path_buf.append("d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/valid/");

    var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{ .access_sub_paths = false });
    var dir_it = test_dir.iterate();

    var filename_lower = LocalStringBuffer(128).new();

    while (try dir_it.next()) |entry| {
        try filename_lower.appendLower(entry.name);
        defer filename_lower.setToPrevLen();
        if (!str.sameTail(filename_lower.string(), "bmp") and !str.sameTail(filename_lower.string(), "dib")) {
            continue;
        }

        try path_buf.append(entry.name);
        defer path_buf.setToPrevLen();

        _ = try loadImage(path_buf.string(), ImageFormat.Infer, allocator);
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const gfx = @import("graphics.zig");
const RGBA32 = gfx.RGBA32;
const RGB24 = gfx.RGB24;
const std = @import("std");
const str = @import("string.zig");
const print = std.debug.print;
const kMem = @import("mem.zig");
const LocalStringBuffer = str.LocalStringBuffer;
