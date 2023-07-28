pub fn init() !void {

}

pub fn loadImage(file_path: []const u8, img_type: ImageType, img: *Image, allocator: *mem6.Allocator) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    if (img_type == ImageType.Infer) {
        var extension_idx: ?usize = str.findR(file_path, '.');
        if (extension_idx == null) {
            return ImageError.NoFileExtension;
        }
        const extension: []const u8 = str.substrR(file_path, extension_idx.? + 1);
        var extension_lower = try str.copyLower(extension, allocator);
        defer str.freeSmall(extension_lower, allocator);

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

pub fn loadBmp(file: std.fs.File, img: *Image, allocator: *mem6.Allocator) !void {
    _ = file;
    _ = img;
    _ = allocator;
    print("loading bmp\n", .{});
}

pub fn loadJpg(file: std.fs.File, img: *Image, allocator: *mem6.Allocator) !void {
    _ = file;
    _ = img;
    _ = allocator;
    print("loading jpg\n", .{});
}

pub fn loadPng(file: std.fs.File, img: *Image, allocator: *mem6.Allocator) !void {
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
};

const gfxtypes = @import("gfxtypes.zig");
const RGBA32 = gfxtypes.RGBA32;
const std = @import("std");
const str = @import("string.zig");
const print = std.debug.print;
const mem6 = @import("mem6.zig");

test "Load Image" {
    try mem6.startup();
    defer mem6.shutdown();

    var test_img = Image{}; 
    print("\n", .{});
    try loadImage("fish.pNg", ImageType.Infer, &test_img, &std.testing.allocator);
    try loadImage("fish.jpG", ImageType.Infer, &test_img, &std.testing.allocator);
    try loadImage("fish.jPeg", ImageType.Infer, &test_img, &std.testing.allocator);
    try loadImage("fish.DIB", ImageType.Infer, &test_img, &std.testing.allocator);
    try loadImage("fish.bmp", ImageType.Infer, &test_img, &std.testing.allocator);
}