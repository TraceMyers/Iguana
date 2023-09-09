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
    OverlappingData,
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
    TgaInvalidTableSize,
    TgaImageTypeUnsupported,
    TgaColorMapDataInNonColorMapImage
};

const graphics = @import("../graphics.zig");
const std = @import("std");
const string = @import("../string.zig");
const memory = @import("../memory.zig");
const bmp = @import("bmp.zig");
const bench = @import("../benchmark.zig");
const png = @import("png.zig");
const tga = @import("tga.zig");

const print = std.debug.print;
const LocalStringBuffer = string.LocalStringBuffer;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// load an image from disk. format is optionally inferrable via the file extension.
// !! Warning !! calling this function may require up to 1.5KB free stack memory.
// !! Warning !! some OS/2 BMPs are compatible, except their width and height entries are interpreted as signed integers
// (rather than the OS/2 standard for core headers, unsigned), which may lead to a failed read or row-inverted image.
pub fn loadImage(
    file_path: []const u8, format: ImageFormat, allocator: std.mem.Allocator, options: ImageLoadOptions
) !Image {
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
            try bmp.load(&file, &image, allocator, &options);
        }
        else if (string.same(extension_lower, "tga")
            or string.same(extension_lower, "icb")
            or string.same(extension_lower, "vda")
            or string.same(extension_lower, "vst")
        ) {
            try tga.load(&file, &image, allocator, &options);
        }
        else if (string.same(extension_lower, "png")) {
            try png.load(&file, &image, allocator, &options);
        }
        else if (string.same(extension_lower, "jpg") or string.same(extension_lower, "jpeg")) {
            return ImageError.FormatUnsupported;
        }
        else {
            return ImageError.InvalidFileExtension;
        }
    }
    else switch (format) {
        .Bmp => try bmp.load(&file, &image, allocator, &options),
        .Jpg => return ImageError.FormatUnsupported,
        .Png => try png.load(&file, &image, allocator, &options),
        .Tga => try tga.load(&file, &image, allocator, &options),
        else => unreachable,
    }
    return image;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------- debug params
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub var rle_debug_output: bool = false;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const bmp_identifier: []const u8 = "BM";
pub const png_identifier: []const u8 = "\x89PNG\x0d\x0a\x1a\x0a";

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageFormat = enum { Infer, Bmp, Jpg, Png, Tga };

pub const ImageType = enum { None, RGB, RGBA };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ARGB64 = extern struct {
    a: u16,
    r: u16,
    g: u16,
    b: u16,
};

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]graphics.RGBA32 = null,
    allocator: ?std.mem.Allocator = null,

    pub inline fn clear(self: *Image) void {
        if (self.pixels != null) {
            std.debug.assert(self.allocator != null);
            self.allocator.?.free(self.pixels.?);
        }
        self.* = Image{};
    }
};

pub const ImageLoadBuffer = struct {
    allocation: ?[]u8 = null,
    alignment: u29 = 0
};

pub const ImageLoadOptions = struct {
    // image loading system is not allowed to attempt to load the image as any other format than whichever
    // is first inferred or assigned. Also used internally when attempting to load as a fmt other than the first, to
    // prevent infinite recursion.
    format_comitted: bool = false,
    // if you want to provide a buffer that will be used during image loading, rather than allocating and freeing
    // a loading buffer. will be ignored if too small or if alignment is incorrect for the format. WARNING: providing a
    // load buffer with incorrectly denoted alignment can cause an image to be loaded improperly or fail to load.
    // - BMPs have an alignment of 4 bytes
    load_buffer: ImageLoadBuffer = ImageLoadBuffer{},
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> tests
// ---------------------------------------------------------------------------------------------------------------------
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// zig test src/image/image.zig -lc --test-filter image --main-pkg-path ../
// pub fn LoadImageTest() !void {
test "load bitmap [image]" {
    try memory.autoStartup();
    defer memory.shutdown();
    const allocator = memory.EnclaveAllocator(memory.Enclave.Game).allocator();

    print("\n", .{});

    // 2.7 has coverage over core, v1, v4, and v5
    // 0.9 is V1 only

    var path_buf = LocalStringBuffer(128).new();
    const test_paths: [6][]const u8 = .{
        "d:/projects/zig/core/test/nocommit/bmpsuite-2.7/g/",
        "d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/valid/",
        "d:/projects/zig/core/test/nocommit/bmpsuite-2.7/q/",
        "d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/questionable/",
        "d:/projects/zig/core/test/nocommit/bmpsuite-2.7/b/",
        "d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/corrupt/",
    };

    var filename_lower = LocalStringBuffer(64).new();
    var valid_total: u32 = 0;
    var valid_supported: u32 = 0;
    var questionable_total: u32 = 0;
    var questionable_supported: u32 = 0;
    var corrupt_total: u32 = 0;
    var corrupt_supported: u32 = 0;

    const alloc_sz = 4_194_304 / 2; // 2MB
    const load_options = ImageLoadOptions{
        .load_buffer = ImageLoadBuffer{
            .alignment = 4,
            .allocation = try allocator.alignedAlloc(u8, 4, alloc_sz)
        },
    };

    for (0..6) |i| {
        try path_buf.replace(test_paths[i]);
        path_buf.setAnchor();
        var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{ .access_sub_paths = false });
        var test_it = test_dir.iterate();

        while (try test_it.next()) |entry| {
            try filename_lower.replaceLower(entry.name);
            if (!string.sameTail(filename_lower.string(), "bmp") 
                and !string.sameTail(filename_lower.string(), "dib")
                and !string.sameTail(filename_lower.string(), "jpg")
                and !string.same(filename_lower.string(), "nofileextension")
            ) {
                continue;
            }

            var t = bench.ScopeTimer.start("loadBmp", bench.getScopeTimerID());
            defer t.stop();

            try path_buf.append(entry.name);
            defer path_buf.revertToAnchor();

            var image = loadImage(path_buf.string(), ImageFormat.Bmp, allocator, load_options) catch |e| blk: {
                if (i < 2) {
                    print("valid file {s} {any}\n", .{filename_lower.string(), e});
                }
                break :blk Image{};
            };

            if (image.pixels != null) {
                if (i < 2) {
                    valid_supported += 1;
                }
                else if (i < 4) {
                    questionable_supported += 1;
                }
                else {
                    corrupt_supported += 1;
                }
                image.clear();
            }

            if (i < 2) {
                valid_total += 1;
            }
            else if (i < 4) {
                questionable_total += 1;
            }
            else {
                corrupt_total += 1;
            }
        }
    }

    const valid_perc = @intToFloat(f32, valid_supported) / @intToFloat(f32, valid_total) * 100.0;
    const quest_perc = @intToFloat(f32, questionable_supported) / @intToFloat(f32, questionable_total) * 100.0;
    const corpt_perc = @intToFloat(f32, corrupt_supported) / @intToFloat(f32, corrupt_total) * 100.0;
    print("bmp test suite 0.9 and 2.7\n", .{});
    print("[VALID]        total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ valid_total, valid_supported, valid_perc });
    print("[QUESTIONABLE] total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ questionable_total, questionable_supported, quest_perc });
    print("[CORRUPT]      total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ corrupt_total, corrupt_supported, corpt_perc });

    // bench.printAllScopeTimers();
    // try std.testing.expect(passed_all);
}

test "load targa [image]" {
    try memory.autoStartup();
    defer memory.shutdown();

    const allocator = memory.GameAllocator.allocator();

    print("\n", .{});

    var path_buf = LocalStringBuffer(128).new();
    try path_buf.append("d:/projects/zig/core/test/nocommit/mytgatestsuite/good/");
    path_buf.setAnchor();

    var filename_lower = LocalStringBuffer(64).new();

    var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{});
    var dir_it = test_dir.iterate();

    while(try dir_it.next()) |entry| {
        try filename_lower.replaceLower(entry.name);
        try path_buf.append(filename_lower.string());
        defer path_buf.revertToAnchor();

        var t = bench.ScopeTimer.start("loadTga", bench.getScopeTimerID());
        defer t.stop();

        var image = loadImage(path_buf.string(), ImageFormat.Infer, allocator, .{}) 
            catch |e| blk: {
                print("error {any} loading tga file {s}\n", .{e, filename_lower.string()});
                break :blk Image{};
            };
        _ = image;
    }

    bench.printAllScopeTimers();
}