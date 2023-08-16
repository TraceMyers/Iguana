// inline for (std.meta.fields(@TypeOf(info))) |f| {
//     const value = @as(f.type, @field(info, f.name));
//     print("{s}: {any}\n", .{f.name, value});
// }

pub fn init() !void {

}

pub fn loadImage(file_path: []const u8, img_type: ImageType, img: *Image, allocator: anytype) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    if (img_type == ImageType.Infer) {
        var extension_idx: ?usize = str.findR(file_path, '.');
        if (extension_idx == null) {
            return ImageError.NoFileExtension;
        }
        extension_idx.? += 1;
        const extension_len = file_path.len - extension_idx.?;
        if (extension_len > 4 or extension_len < 3) {
            return ImageError.InvalidFileExtension;
        }
        const extension: []const u8 = str.substrR(file_path, extension_idx.?);
        var extension_lower_buf: [4]u8 = undefined;
        try str.copyLowerToBuffer(extension, &extension_lower_buf);
        var extension_lower = extension_lower_buf[0..extension.len];

        if (str.equal(extension_lower, "bmp") or str.equal(extension_lower, "dib")) {
            try loadBmp(file, img, allocator);
        }
        else if (str.equal(extension_lower, "jpg") or str.equal(extension_lower, "jpeg")) {
            try loadJpg(file, img, allocator);
        }
        else if (str.equal(extension_lower, "png")) {
            try loadPng(file, img, allocator);
        }
        else {
            return ImageError.InvalidFileExtension;
        }
        return;
    }

    switch(img_type) {
        .BMP => try loadBmp(file, img, allocator),
        .JPG => try loadJpg(file, img, allocator),
        .PNG => try loadPng(file, img, allocator),
        else => unreachable,
    }
}

fn loadImageFromDisk(file: std.fs.File, allocator: anytype, min_sz: usize) ![]u8 {
    const stat = try file.stat();
    if (stat.size > mem6.MAX_SZ) {
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

inline fn bmpFillCoreHeaderInfo(buffer: []u8, info: *BitmapInfo, data_sz: u32) void {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u8, std.mem.readIntNative(u16, buffer[24..26]));
    info.size = data_sz - 26;
}

inline fn bmpFillV1HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u8, std.mem.readIntNative(u16, buffer[28..30]));
    info.compression = @intToEnum(BitmapCompression, std.mem.readIntNative(u32, buffer[30..34]));
    info.size = std.mem.readIntNative(u32, buffer[34..38]);
    info.color_ct = std.mem.readIntNative(u32, buffer[46..50]);
}

fn bmpFillV4HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.red_mask = std.mem.readIntNative(u32, buffer[54..58]);
    info.green_mask = std.mem.readIntNative(u32, buffer[58..62]);
    info.blue_mask = std.mem.readIntNative(u32, buffer[62..66]);
    info.alpha_mask = std.mem.readIntNative(u32, buffer[66..70]);
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

inline fn bmpFillV1HeaderInfo(buffer: []u8, info: *BitmapInfo) void {
    info.header_type = BitmapHeaderType.V1;
    bmpFillV1HeaderPart(buffer, info);
}

fn bmpFillV4HeaderInfo(buffer: []u8, info: *BitmapInfo) void {
    info.header_type = BitmapHeaderType.V4;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
}

fn bmpFillV5HeaderInfo(buffer: []u8, info: *BitmapInfo) void {
    info.header_type = BitmapHeaderType.V5;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    bmpFillV5HeaderPart(buffer, info);
}

pub fn loadBmp(file: std.fs.File, img: *Image, allocator: anytype) !void {
    _ = img;
    
    var buffer: []u8 = try loadImageFromDisk(file, allocator, MIN_SZ_BMP);
    defer allocator.free(buffer);

    const identity = buffer[0..2];

    if (!str.equal(identity, "BM")) {
        return ImageError.BmpInvalidIdentifier;
    }

    var info = BitmapInfo{};

    // --- OG file header ---
    const data_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return ImageError.BmpInvalidBytesInHeader;
    }

    // offset to image data from 0
    info.data_offset = @intCast(u8, std.mem.readIntNative(u32, buffer[10..14]));

    // --- A Forest of different headers beyond this point (this captures about half of them) ---
    // sz of the info (not file) header, including these 4 bytes
    info.header_sz = @intCast(u8, std.mem.readIntNative(u32, buffer[14..18]));

    if (info.header_sz + 14 != info.data_offset or buffer.len <= info.data_offset) {
        return ImageError.BmpInvalidDataOffset;
    }

    switch(info.header_sz) {
        12 => bmpFillCoreHeaderInfo(buffer, &info, data_sz),
        40 => bmpFillV1HeaderInfo(buffer, &info),
        108 => bmpFillV4HeaderInfo(buffer, &info),
        124 => bmpFillV5HeaderInfo(buffer, &info),
        else => return ImageError.BmpInvalidHeaderSizeOrFormatUnsupported, // try converting to a newer format
    }

    if (info.data_offset + info.size != buffer.len) {
        return ImageError.BmpInvalidSizeInfo;
    }

    inline for (std.meta.fields(@TypeOf(info))) |f| {
        const value = @as(f.type, @field(info, f.name));
        print("{s}: {any}\n", .{f.name, value});
    }
}

pub fn loadJpg(file: std.fs.File, img: *Image, allocator: anytype) !void {
    _ = file;
    _ = img;
    _ = allocator;
    print("loading jpg\n", .{});
}

pub fn loadPng(file: std.fs.File, img: *Image, allocator: anytype) !void {
    _ = file;
    _ = img;
    _ = allocator;
    print("loading png\n", .{});
}

pub const ImageType = enum {
    Infer,
    BMP,
    JPG,
    PNG
};

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: []RGBA32 = undefined,
};

const ImageError = error {
    TempError,
    NoFileExtension,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    BmpInvalidIdentifier,
    BmpInvalidBytesInHeader,
    BmpInvalidHeaderSizeOrFormatUnsupported,
    BmpFormatUnsupported,
    BmpInvalidDataOffset,
    BmpInvalidSizeInfo,
};

const BitmapHeaderType = enum(u8) {
    Core,
    V1,
    V4,
    V5,
};

const BitmapCompression = enum(u8) {
    RGB,
    RLE8,
    RLE4,
    BITFIELDS,
    JPEG,
    PNG,
    ALPHABITFIELDS,
    CMYK,
    CMYKRLE8,
    CMYKRLE4
};

const BitmapColorSpace = enum(u32) {
    CalibratedRGB = 0x0,
    ProfileLinked = 0x4C494E4B,
    ProfileEmbedded = 0x4D424544,
    WindowsCS = 0x57696E20,
    sRGB = 0x73524742,
};

const FxPt2Dot30 = packed struct {
    integer: u2,
    fraction: u30,
};

// const CieXYZ = packed struct {
//     components: [3]FxPt2Dot30 = undefined,
// };

const CieXYZTriple = struct {
    red: [3]FxPt2Dot30 = undefined,
    green: [3]FxPt2Dot30 = undefined,
    blue: [3]FxPt2Dot30 = undefined,
};

const BitmapInfo = struct {
    data_offset: u8 = undefined,
    header_sz: u8 = undefined,
    header_type: BitmapHeaderType = undefined,
    color_depth: u8 = undefined,
    compression: ?BitmapCompression = null,
    color_space: ?BitmapColorSpace = null,
    width: i32 = undefined,
    height: i32 = undefined,
    size: u32 = undefined,
    color_ct: ?u32 = null,
    red_mask: ?u32 = null,
    green_mask: ?u32 = null,
    blue_mask: ?u32 = null,
    alpha_mask: ?u32 = null,
    cs_points: CieXYZTriple = undefined,
    red_gamma: ?u32 = null,
    green_gamma: ?u32 = null,
    blue_gamma: ?u32 = null,
    profile_data: ?u32 = null,
    profile_size: ?u32 = null
};

pub const MIN_SZ_BMP = 25;

// pub fn LoadImageTest() !void {
test "Load Image" {
    try mem6.autoStartup();
    defer mem6.shutdown();
    const allocator = mem6.Allocator(mem6.Enclave.Game);

    var test_img = Image{}; 
    print("\n", .{});
    try loadImage("test/images/puppy.png", ImageType.Infer, &test_img, allocator);
    try loadImage("test/images/puppy.jpg", ImageType.Infer, &test_img, allocator);
    try loadImage("test/images/puppy.bmp", ImageType.Infer, &test_img, allocator);
}

const gfxtypes = @import("gfxtypes.zig");
const RGBA32 = gfxtypes.RGBA32;
const std = @import("std");
const str = @import("string.zig");
const print = std.debug.print;
const mem6 = @import("mem6.zig");

