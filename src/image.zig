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
        if (extension_len > 4) {
            return ImageError.LongFileExtension;
        }
        var extension_lower: [4]u8 = undefined;
        const extension: []const u8 = str.substrR(file_path, extension_idx.?);
        try str.copyLowerToBuffer(extension, &extension_lower);

        if (str.equalCount(&extension_lower, "bmp") == 3 or str.equalCount(&extension_lower, "dib") == 3) {
            try loadBmp(file, img, allocator);
        }
        else if (str.equalCount(&extension_lower, "jpg") == 3 or str.equal(&extension_lower, "jpeg")) {
            try loadJpg(file, img, allocator);
        }
        else if (str.equalCount(&extension_lower, "png") == 3) {
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

pub fn loadBmp(file: std.fs.File, img: *Image, allocator: anytype) !void {
    print("loading bmp\n", .{});
    _ = img;
    const stat = try file.stat();
    if (stat.size > mem6.MAX_SZ or stat.size < MIN_SZ_BMP) {
        return ImageError.TooLarge;
    }

    var buffer: []u8 = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytes_read: usize = try file.reader().readAll(buffer);

    if (bytes_read != stat.size) {
        // the reader reached the end of the file before reading all of the file's bytes according to file.stat()
        return ImageError.PartialRead;
    }

    const identity = buffer[0..2];

    if (!str.equal(identity, "BM")) {
        // the header may be invalid if the format doesn't match the extension, or if the image is too old. If 
        // the image is too old, it can be converted to a new version of the format.
        return ImageError.InvalidHeader;
    }

    // const field_reserved_0 = buffer[6..8];
    // const field_reserved_1 = buffer[8..10];

    const data_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const data_address = std.mem.readIntNative(u32, buffer[10..14]);

    _ = data_sz;
    _ = data_address;

    const ext_header_sz = std.mem.readIntNative(u32, buffer[14..18]);
    const width = std.mem.readIntNative(i32, buffer[18..22]);
    const height = std.mem.readIntNative(i32, buffer[22..26]);
    const color_pane_ct = std.mem.readIntNative(u16, buffer[26..28]);
    const color_depth = std.mem.readIntNative(u16, buffer[28..30]);
    const compression = std.mem.readIntNative(u32, buffer[30..34]);
    const image_sz = std.mem.readIntNative(u32, buffer[34..38]);
    const horizontal_ppm = std.mem.readIntNative(i32, buffer[38..42]);
    const vertical_ppm = std.mem.readIntNative(i32, buffer[42..46]);
    var color_ct = std.mem.readIntNative(u32, buffer[46..50]);
    if (color_ct == 0) {
        color_ct = @as(u32, 1) << @intCast(u5, (color_depth - 1));
    }
    const important_color_ct = std.mem.readIntNative(u32, buffer[50..54]);

    print("ext header sz: {d}, width: {d}, height: {d}\n", .{ext_header_sz, width, height});
    print("color pane ct: {d}, color depth: {d}, compression: {d}\n", .{color_pane_ct, color_depth, compression});
    print("image sz: {d}, horizontal ppm: {d}, vertical ppm: {d}\n", .{image_sz, horizontal_ppm, vertical_ppm});
    print("color ct: {d}, important color ct: {d}\n", .{color_ct, important_color_ct});
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
    LongFileExtension,
    TooLarge,
    PartialRead,
    InvalidHeader,
};

pub const MIN_SZ_BMP = 14;

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

