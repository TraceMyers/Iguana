// ::::::::::: For loading two-dimensional images from disk, into a basic standardized format.
// :: Image ::
// :::::::::::

pub const ImageError = error{
    NoFileExtension,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    UnexpectedEOF,
    FormatUnsupported,
    DimensionTooLarge,
    BmpFlavorUnsupported,
    BmpInvalidBytesInFileHeader,
    BmpInvalidBytesInInfoHeader,
    BmpInvalidHeaderSizeOrVersionUnsupported,
    BmpInvalidDataOffset,
    BmpInvalidSizeInfo,
    BmpInvalidPlaneCt,
    BmpInvalidColorDepth,
    BmpInvalidColorCount,
    BmpInvalidColorTable,
    BmpInvalidColorTableIndex,
    BmpColorSpaceUnsupported,
    BmpCompressionUnsupported,
    Bmp24BitCustomMasksUnsupported,
    BmpInvalidCompression,
    BmpInvalidColorMasks,
    BmpRLECoordinatesOutOfBounds,
    BmpInvalidRLEData,
};

const graphics = @import("../graphics.zig");
const std = @import("std");
const string = @import("../string.zig");
const memory = @import("../memory.zig");
const bmp = @import("bmp.zig");
const bench = @import("../benchmark.zig");

const print = std.debug.print;
const LocalStringBuffer = string.LocalStringBuffer;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// load an image from disk. format is optionally inferrable via the file extension.
// !! Warning !! calling this function may require up to 1.5KB free stack memory.
// !! Warning !! some OS/2 BMPs are compatible, except their width and height entries are interpreted as signed integers
// (rather than the OS/2 standard for core headers, unsigned), which may lead to a failed read or row-inverted image.
pub fn loadImage(file_path: []const u8, format: ImageFormat, allocator: memory.Allocator) !Image {
    var t = bench.ScopeTimer.start("loadImage", bench.getScopeTimerID());
    defer t.stop();

    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var image = Image{};

    if (format == ImageFormat.Infer) {
        var extension_idx: ?usize = string.findR(file_path, '.');
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

        if (string.same(extension_lower, "bmp") or string.same(extension_lower, "dib")) {
            try bmp.load(&file, &image, allocator);
        } else if (string.same(extension_lower, "jpg") or string.same(extension_lower, "jpeg")) {
            return ImageError.FormatUnsupported;
        } else if (string.same(extension_lower, "png")) {
            return ImageError.FormatUnsupported;
        } else {
            return ImageError.InvalidFileExtension;
        }
    } else switch (format) {
        .Bmp => try bmp.load(&file, &image, allocator),
        .Jpg => return ImageError.FormatUnsupported,
        .Png => return ImageError.FormatUnsupported,
        else => unreachable,
    }
    return image;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageFormat = enum { Infer, Bmp, Jpg, Png };

pub const ImageType = enum { None, RGB, RGBA };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]graphics.RGBA32 = null,
    allocator: ?memory.Allocator = null,

    pub inline fn clear(self: *Image) void {
        std.debug.assert(self.allocator != null and self.pixels != null);
        self.allocator.?.free(self.pixels.?);
        self.* = Image{};
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> tests
// ---------------------------------------------------------------------------------------------------------------------
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// zig test src/image/image.zig -lc --test-filter image --main-pkg-path ../
// pub fn LoadImageTest() !void {
test "Load Bitmap image" {
    try memory.autoStartup();
    defer memory.shutdown();

    const allocator = memory.Allocator.new(memory.Enclave.Game);

    print("\n", .{});

    // 2.7 has coverage over core, v1, v4, and v5
    // 0.9 is V1 only

    var path_buf = LocalStringBuffer(128).new();
    var valid_paths: [2][]const u8 = .{
        "d:/projects/zig/core/test/nocommit/bmpsuite-2.7/g/",
        "d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/valid/",
    };

    var filename_lower = LocalStringBuffer(128).new();
    var passed_all: bool = true;
    var valid_total: u32 = 0;
    var valid_supported: u32 = 0;

    inline for (0..2) |i| {
        try path_buf.replace(valid_paths[i]);
        var valid_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{ .access_sub_paths = false });
        var valid_it = valid_dir.iterate();

        while (try valid_it.next()) |entry| {
            try filename_lower.appendLower(entry.name);
            defer filename_lower.setToPrevLen();
            if (!string.sameTail(filename_lower.string(), "bmp") and !string.sameTail(filename_lower.string(), "dib")) {
                continue;
            }

            try path_buf.append(entry.name);
            defer path_buf.setToPrevLen();

            // print("loading {s}\n", .{filename_lower.string()});
            // print("load error {any}\n", .{e})
            // var image = loadImage(path_buf.string(), ImageFormat.Infer, allocator)
            //     catch Image{};
            var image = loadImage(path_buf.string(), ImageFormat.Infer, allocator) catch |e| blk: {
                print("file {s} {any}\n", .{filename_lower.string(), e});
                break :blk Image{};
            };

            if (image.pixels != null) {
                valid_supported += 1;
                // print("*** processed ***\n", .{});
                image.clear();
            } else {
                passed_all = false;
            }
            valid_total += 1;
            // print("\n// ------------------ //\n\n", .{});
        }
        path_buf.setToPrevLen();
    }

    const valid_perc = @intToFloat(f32, valid_supported) / @intToFloat(f32, valid_total) * 100.0;
    print("bmp test suite 0.9 and 2.7\n", .{});
    print("valid\n", .{});
    print("total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ valid_total, valid_supported, valid_perc });

    bench.printAllScopeTimers();
    // try std.testing.expect(passed_all);
}
