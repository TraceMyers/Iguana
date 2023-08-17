// inline for (std.meta.fields(@TypeOf(info))) |f| {
//     const value = @as(f.type, @field(info, f.name));
//     print("{s}: {any}\n", .{f.name, value});
// }

// TODO: bmp size verification before reads, in as few steps / in as few places as possible

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
        .Bmp => try loadBmp(file, img, allocator),
        .Jpg => try loadJpg(file, img, allocator),
        .Png => try loadPng(file, img, allocator),
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

inline fn bmpFillV1HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[28..30]));
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

inline fn bmpFillCoreHeaderInfo(buffer: []u8, info: *BitmapInfo, file_sz: u32) void {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    info.size = file_sz - info.data_offset;
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

fn bmpGetColorTable(buffer: []u8, info: *const BitmapInfo, table_buffer: *[256]RGB24) ![]RGB24 {
    var buffer_casted = @ptrCast([*]RGB24, @alignCast(@alignOf(RGB24), &buffer[26]));
    return switch(info.color_depth) {
        24 => blk: {
            break :blk table_buffer.*[0..0];
        },
        8 => blk: {
            // do stuff
            @memcpy(table_buffer.*[0..256], buffer_casted[0..256]);
            break :blk table_buffer.*[0..256];
        },
        4 => blk: {
            // do stuff
            @memcpy(table_buffer.*[0..16], buffer_casted[0..16]);
            break :blk table_buffer.*[0..16];
        },
        1 => blk: {
            // do stuff   
            @memcpy(table_buffer.*[0..2], buffer_casted[0..2]);
            break :blk table_buffer.*[0..2];
        },
        else => ImageError.BmpInvalidColorDepth,
    };
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
    var color_table_buffer: [256]RGB24 = undefined;

    // --- OG file header ---
    const file_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }

    // offset to image data from 0
    info.data_offset = @intCast(u8, std.mem.readIntNative(u32, buffer[10..14]));

    // --- A Forest of different headers beyond this point (this captures about half of them) ---
    // sz of the info (not file) header, including these 4 bytes
    info.header_sz = @intCast(u8, std.mem.readIntNative(u32, buffer[14..18]));

    switch(info.header_sz) {
        12 => bmpFillCoreHeaderInfo(buffer, &info, file_sz),
        40 => bmpFillV1HeaderInfo(buffer, &info),
        108 => bmpFillV4HeaderInfo(buffer, &info),
        124 => bmpFillV5HeaderInfo(buffer, &info),
        else => return ImageError.BmpInvalidHeaderSizeOrFormatUnsupported, // try converting to a newer format
    }

    if (info.data_offset + info.size != buffer.len) {
        return ImageError.BmpInvalidSizeInfo;
    }

    if (info.header_type == BitmapHeaderType.Core) {
        const color_table: []RGB24 = try bmpGetColorTable(buffer, &info, &color_table_buffer);
        print("{any}\n", .{color_table});
    }

    if (info.header_type == BitmapHeaderType.V1 
        and (info.compression == BitmapCompression.BITFIELDS or info.compression == BitmapCompression.ALPHABITFIELDS)
    ) {

    }
    print("{any}\n", .{info.header_type});

    // inline for (std.meta.fields(@TypeOf(info))) |f| {
    //     const value = @as(f.type, @field(info, f.name));
    //     print("{s}: {any}\n", .{f.name, value});
    // }
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
    Bmp,
    Jpg,
    Png
};

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: []RGBA32 = undefined,
};

const ImageError = error {
    NoFileExtension,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    BmpInvalidIdentifier,
    BmpInvalidBytesInFileHeader,
    BmpInvalidHeaderSizeOrFormatUnsupported,
    BmpInvalidDataOffset,
    BmpInvalidSizeInfo,
    BmpInvalidPlaneCt,
    BmpInvalidColorDepth,
};

const BitmapHeaderType = enum(u8) {
    Core,
    V1,
    V4,
    V5,
};

const BitmapCompression = enum(u32) {
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
    data_offset: u8 = undefined,
    header_sz: u8 = undefined,
    header_type: BitmapHeaderType = undefined,
    width: i32 = undefined,
    height: i32 = undefined,
    color_depth: u32 = undefined,
    compression: BitmapCompression = undefined,
    size: u32 = undefined,
    color_ct: u32 = undefined,
    red_mask: u32 = undefined,
    green_mask: u32 = undefined,
    blue_mask: u32 = undefined,
    alpha_mask: u32 = undefined,
    color_space: BitmapColorSpace = undefined,
    profile_data: u32 = undefined,
    profile_size: u32 = undefined,
    cs_points: CieXYZTriple = undefined,
    red_gamma: u32 = undefined,
    green_gamma: u32 = undefined,
    blue_gamma: u32 = undefined,
};

pub const MIN_SZ_BMP = 36;

// pub fn LoadImageTest() !void {
test "Load Image Bitmap" {
    try mem6.autoStartup();
    defer mem6.shutdown();
    const allocator = mem6.Allocator(mem6.Enclave.Game);

    var test_img = Image{}; 
    print("\n", .{});

    try loadImage("test/images/puppy.bmp", ImageType.Infer, &test_img, allocator);

    var path_buf = LocalStringBuffer(2048).new();
    try path_buf.append("d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/valid/");

    var test_dir = try std.fs.openIterableDirAbsolute(
        path_buf.string(), 
        .{.access_sub_paths=false}
    );
    var dir_it = test_dir.iterate();

    while (try dir_it.next()) |entry| {
        try path_buf.append(entry.name);
        // print("file: {s}\n", .{path_buf.string()});
        try loadImage(path_buf.string(), ImageType.Infer, &test_img, allocator);
        path_buf.setToPreviousLength();
    }

}

const gfxtypes = @import("gfxtypes.zig");
const RGBA32 = gfxtypes.RGBA32;
const RGB24 = gfxtypes.RGB24;
const std = @import("std");
const str = @import("string.zig");
const print = std.debug.print;
const mem6 = @import("mem6.zig");
const LocalStringBuffer = str.LocalStringBuffer;

