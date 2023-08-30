const std = @import("std");
const imagef = @import("image.zig");
const Image = imagef.Image;
const memory = @import("../memory.zig");

pub fn load(
    file: *std.fs.File, image: *Image, allocator: memory.Allocator, options: *const imagef.ImageLoadOptions
) !void {
    _ = file;
    _ = image;
    _ = allocator;
    _ = options;
}