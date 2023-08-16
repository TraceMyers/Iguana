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

fn bmpFillCoreHeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    info.header_type = BitmapHeaderType.WindowsCore;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u8, std.mem.readIntNative(u16, buffer[24..26]));
}

fn bmpFillCore2HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillCore2ShortHeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillWindowsV1HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillWindowsV2HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillWindowsV3HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillWindowsV4HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

fn bmpFillWindowsV5HeaderInfo(buffer: []u8, info: *BitmapInfo) !void {
    _ = buffer;
    _ = info;
    return ImageError.BMPFormatUnsupported;
}

pub fn loadBmp(file: std.fs.File, img: *Image, allocator: anytype) !void {
    _ = img;
    
    var buffer: []u8 = try loadImageFromDisk(file, allocator, MIN_SZ_BMP);
    defer allocator.free(buffer);

    const identity = buffer[0..2];

    if (!str.equal(identity, "BM")) {
        // the header may be invalid if the format doesn't match the extension, or if the image is too old. If 
        // the image is too old, it can be converted to a new version of the format.
        return ImageError.BMPInvalidHeader;
    }

    var info: BitmapInfo = undefined;

    // --- OG File header ---
    // whole file sz
    const data_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return ImageError.BMPInvalidReservedFieldValue;
    }

    // offset to image data from 0
    info.data_offset = @intCast(u8, std.mem.readIntNative(u32, buffer[10..14]));

    // --- A Forest of different headers beyond this point ---
    // sz of the extended header, including these 4 bytes
    info.header_sz = @intCast(u8, std.mem.readIntNative(u32, buffer[14..18]));

    try switch(info.header_sz) {
        12 => bmpFillCoreHeaderInfo(buffer, &info),
        16 => bmpFillCore2ShortHeaderInfo(buffer, &info),
        64 => bmpFillCore2HeaderInfo(buffer, &info),
        40 => bmpFillWindowsV1HeaderInfo(buffer, &info),
        52 => bmpFillWindowsV2HeaderInfo(buffer, &info),
        56 => bmpFillWindowsV3HeaderInfo(buffer, &info),
        108 => bmpFillWindowsV4HeaderInfo(buffer, &info),
        124 => bmpFillWindowsV5HeaderInfo(buffer, &info),
        else => return ImageError.BMPInvalidHeaderSize,
    };

    _ = data_sz;

    // const width = std.mem.readIntNative(i32, buffer[18..22]);
    // const height = std.mem.readIntNative(i32, buffer[22..26]);
    // const color_plane_ct = std.mem.readIntNative(u16, buffer[26..28]);
    // const color_depth = std.mem.readIntNative(u16, buffer[28..30]);
    // const compression = std.mem.readIntNative(u32, buffer[30..34]);
    // const image_sz = std.mem.readIntNative(u32, buffer[34..38]);
    // var color_ct = std.mem.readIntNative(u32, buffer[46..50]);
    // if (color_ct == 0) {
    //     if (color_depth == 32) {
    //         color_ct = std.math.maxInt(u32);
    //     }
    //     else {
    //         color_ct = @as(u32, 1) << @intCast(u5, color_depth);
    //     }
    // }
    // const important_color_ct = std.mem.readIntNative(u32, buffer[50..54]);

    // if (color_plane_ct != 1) {
    //     // apparently this is an error...
    // }

    // print("ext header sz: {d}, width: {d}, height: {d}\n", .{ext_header_sz, width, height});
    // print("color plane ct: {d}, color depth: {d}, compression: {d}\n", .{color_plane_ct, color_depth, compression});
    // print("image sz: {d}\n", .{image_sz});
    // print("color ct: {d}, important color ct: {d}\n", .{color_ct, important_color_ct});
    // print("data sz: {}, data_address: {}\n", .{data_sz, data_offset});
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
    BMPInvalidHeader,
    BMPInvalidReservedFieldValue,
    BMPInvalidHeaderSize,
    BMPFormatUnsupported,
};

const BitmapHeaderType = enum(u8) {
    Os2Core, // this format can't be told apart from WindowsCore, so WindowsCore is default
    Os2Core2,
    Os2Core2Short,
    WindowsCore,
    WindowsV1,
    WindowsV2,
    WindowsV3,
    WindowsV4,
    WindowsV5,
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

const BitmapColorSpace = enum(u8) {
    CalibratedRGB,
    sRGB,
    WindowsCS,
    ProfileLinked,
    ProfileEmbedded,
};

const FxPt2Dot30 = struct {
    dot: u30,
    pt: u2,
};

const CieXYZ = struct {
    points: [3]FxPt2Dot30 = undefined,
};

const BitmapInfo = struct {
    header_sz: u8,
    header_type: BitmapHeaderType,
    data_offset: u8,
    color_depth: u8,
    compression: ?BitmapCompression,
    color_space: ?BitmapColorSpace,
    width: i32,
    height: i32,
    size: u32,
    color_ct: ?u32,
    red_mask: ?u32,
    green_mask: ?u32,
    blue_mask: ?u32,
    alpha_mask: ?u32,
    red_cs: ?CieXYZ,
    green_cs: ?CieXYZ,
    blue_cs: ?CieXYZ,
    red_gamma: ?u32,
    green_gamma: ?u32,
    blue_gamma: ?u32,
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

