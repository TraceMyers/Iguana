// ::::::::::: For loading two-dimensional images from disk, into a basic standardized format.
// :: Image ::
// :::::::::::

// TODO: allocator-related free error on large alloc
const std = @import("std");
const bmp = @import("bmp.zig");
const png = @import("png.zig");
const tga = @import("tga.zig");
const jpg = @import("jpg.zig");
const string = @import("../utils/string.zig");
const time = @import("../utils/time.zig");
const config = @import("config.zig");
pub const types = @import("types.zig");
// const bench = @import("../benchmark.zig");

pub const Image = types.Image;
const print = std.debug.print;
const LocalStringBuffer = string.LocalStringBuffer;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// load an image from disk. format is optionally inferrable via the file extension or, if that fails, the file's data.
// !! Warning !! calling this function may require up to 7KB free stack memory.
// !! Warning !! some OS/2 BMPs are compatible, except their width and height entries are interpreted as signed integers
// (rather than the OS/2 standard for core headers, unsigned), which may lead to a failed read or row-inverted image.
pub fn loadImage(
    path: []const u8, 
    file_name: []const u8, 
    format: ImageFormat, 
    allocator: std.mem.Allocator, 
    options: *const types.ImageLoadOptions
) !Image {
    const t = if (config.run_scope_timers) time.ScopeTimer.start(time.callsiteID("loadImage", 0)) else null;
    defer if (config.run_scope_timers) t.stop();

    var full_path_buf = LocalStringBuffer(std.fs.MAX_PATH_BYTES + std.fs.MAX_NAME_BYTES).new();
    const full_path = try getFullPath(&full_path_buf, path, file_name, options.local_path, .Full);

    var file: std.fs.File = try std.fs.cwd().openFile(full_path, .{});
    defer file.close();

    var image = Image{};
    errdefer image.clear();

    var file_format = if (format == .Infer) try inferFormat(&file, file_name) else format;

    switch (file_format) {
        .Bmp => if (comptime config.disable_load_bmp)
            return ImageError.FormatDisabled
        else
            try bmp.load(&file, &image, allocator, options),
        .Jpg => if (comptime config.disable_load_jpg)
            return ImageError.FormatDisabled
        else
            try jpg.load(&file, &image, allocator, options),
        .Png => if (comptime config.disable_load_png)
            return ImageError.FormatDisabled
        else
            try bmp.load(&file, &image, allocator, options),
        .Tga => if (comptime config.disable_load_tga)
            return ImageError.FormatDisabled
        else
            try tga.load(&file, &image, allocator, options),
        else => unreachable,
    }
    return image;
}

pub fn saveImage(
    path: []const u8, 
    file_name: []const u8, 
    format: ImageFormat, 
    image: *const Image, 
    options: *const types.ImageSaveOptions
) !void {
    var t = if (config.run_scope_timers) time.ScopeTimer.start(time.callsiteID("saveImage", 0)) else null;
    defer if (config.run_scope_timers) t.stop();

    const file_format = if (format == .Infer) try inferFormatFromExtension(file_name) else format;
    if (file_format == .Infer) {
        return ImageError.UnableToInferFormat;
    }

    // get the directory...
    var full_path_buf = LocalStringBuffer(std.fs.MAX_PATH_BYTES + std.fs.MAX_NAME_BYTES).new();
    const directory_path = try getFullPath(&full_path_buf, path, file_name, options.local_path, .Directory);
    // .. and test to make sure the directory exists
    const dir = try std.fs.openDirAbsolute(directory_path, .{});
    dir.close();
    // append the file name
    const full_path = try getFullPath(&full_path_buf, path, file_name, options.local_path, .File);

    // try to open the file. if can't, then create.
    var file: std.fs.File = 
        try std.fs.openFileAbsolute(full_path, std.fs.File.OpenFlags{ .mode = .write_only }) 
        catch try std.fs.createFileAbsolute(full_path, .{});

    defer file.close();

    switch (file_format) {
        .Bmp => bmp.save(&file, image, options),
        .Jpg => return ImageError.FormatUnsupported,
        .Png => return ImageError.FormatUnsupported,
        .Tga => return ImageError.FormatUnsupported,
        else => unreachable,
    }
}

pub fn getFullPath(
    buffer: *LocalStringBuffer(std.fs.MAX_PATH_BYTES + std.fs.MAX_NAME_BYTES), 
    path: []const u8, 
    file_name: []const u8, 
    path_is_local: bool, 
    path_step: PathStep
) ![]const u8 {
    if (path_step == .Full or path_step == .Directory) {
        buffer.empty();
        if (path.len > std.fs.MAX_PATH_BYTES) {
            return ImageError.FullPathTooLong;
        }
        if (path_is_local) {
            const real_path: []u8 = try std.fs.cwd().realpath(path, buffer.bytes[0..std.fs.MAX_PATH_BYTES]);
            buffer.len = real_path.len;
        } else {
            try buffer.append(path);
        }
        if (buffer.len + file_name.len + 1 > buffer.bytes.len) {
            return ImageError.FullPathTooLong;
        }
    }

    if (path_step == .Full or path_step == .File) {
        try buffer.append("/");
        try buffer.append(file_name);
    }

    return buffer.string();
}

// determine whether a file is bmp, png, etc...
// file ptr should be at byte 0 before call. seeks to 0 before returning if format is inferred from the file data
pub inline fn inferFormat(file: *std.fs.File, file_path: []const u8) !ImageFormat {
    var format = try inferFormatFromExtension(file_path);
    if (format != .Infer) {
        return format;
    }
    format = try inferFormatFromFile(file);
    try file.seekTo(0);
    return format;
}

pub fn inferFormatFromExtension(file_path: []const u8) !ImageFormat {
    var extension_idx: ?usize = string.findR(file_path, '.');
    if (extension_idx == null) {
        return .Infer;
    }

    extension_idx.? += 1;
    const extension_len = file_path.len - extension_idx.?;
    if (extension_len > 4 or extension_len < 3) {
        return .Infer;
    }

    const extension: []const u8 = file_path[extension_idx.?..];
    var extension_lower_buf = LocalStringBuffer(4).new();
    try extension_lower_buf.appendLower(extension);
    const extension_lower = extension_lower_buf.string();

    if (string.same(extension_lower, "bmp") or string.same(extension_lower, "dib")) {
        return ImageFormat.Bmp;
    } else if (string.same(extension_lower, "tga") 
        or string.same(extension_lower, "icb") 
        or string.same(extension_lower, "vda") 
        or string.same(extension_lower, "vst") 
        or string.same(extension_lower, "tpic")
    ) {
        return ImageFormat.Tga;
    } else if (string.same(extension_lower, "png")) {
        return ImageFormat.Png;
    } else if (string.same(extension_lower, "jpg") or string.same(extension_lower, "jpeg")) {
        return ImageFormat.Jpg;
    } else {
        return .Infer;
    }
}

pub fn inferFormatFromFile(file: *std.fs.File) !ImageFormat {
    const stat = try file.stat();
    if (stat.size < 8) {
        return ImageError.InvalidSize;
    }

    const header_buffer: [8]u8 = try file.reader().readBytesNoEof(8);
    if (string.same(bmp_identifier, header_buffer[0..2])) {
        return ImageFormat.Bmp;
    } else if (string.same(png_identifier, header_buffer[0..8])) {
        return ImageFormat.Png;
    } else if (stat.size >= tga.footer_end_offset) {
        const tga_footer_begin = stat.size - tga.footer_end_offset;
        try file.seekTo(tga_footer_begin);
        const tga_footer = try file.reader().readStruct(tga.TgaFooter);
        if (string.same(tga_identifier, &tga_footer.signature)) {
            return ImageFormat.Tga;
        }
    }

    return ImageError.UnableToInferFormat;
}

pub fn bitCt(num: anytype) comptime_int {
    return switch (@TypeOf(num)) {
        u1 => 1,
        u4 => 4,
        u5 => 5,
        u6 => 6,
        u8 => 8,
        u16 => 16,
        u24 => 24,
        u32 => 32,
        else => 0,
    };
}

// for determining what format is probably best to output given the input format
pub fn autoSelectImageFormat(file_pixel_type: types.PixelTag, load_options: *const types.ImageLoadOptions) !types.PixelTag {
    var preference_order: [4]types.PixelTag = undefined;
    if (file_pixel_type.isColor()) {
        if (file_pixel_type.hasAlpha()) {
            preference_order = .{ .RGBA32, .RGB16, .R8, .R16 };
        } else if (file_pixel_type.size() == 2) {
            preference_order = .{ .RGB16, .RGBA32, .R8, .R16 };
        } else {
            preference_order = .{ .RGBA32, .RGB16, .R8, .R16 };
        }
    } else if (file_pixel_type == .U16_R) {
        preference_order = .{ .R16, .R8, .RGBA32, .RGB16 };
    } else {
        preference_order = .{ .R8, .R16, .RGBA32, .RGB16 };
    }

    inline for (0..4) |i| {
        if (load_options.output_format_allowed[@intFromEnum(preference_order[i])]) {
            return preference_order[i];
        }
    }
    return ImageError.NoImageFormatsAllowed;
}

pub fn bitCtToIntType(comptime val: comptime_int) type {
    return switch (val) {
        1 => u1,
        4 => u4,
        8 => u8,
        15 => u16,
        16 => u16,
        24 => u24,
        32 => u32,
        else => void,
    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------- debug params
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub var rle_debug_output: bool = false;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const bmp_identifier = "BM";
pub const png_identifier = "\x89PNG\x0d\x0a\x1a\x0a";
pub const tga_identifier = "TRUEVISION-XFILE";

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageFormat = enum { Bmp, Jpg, Png, Tga, Infer };

pub const ImageType = enum { None, RGB, RGBA };

pub const ImageAlpha = enum { None, Normal, Premultiplied };

pub const SaveAlpha = enum { None, UseImageAlpha, UndoPremultiplied, ForcePremultiplied };

const PathStep = enum { Full, Directory, File };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageError = error{
    FullPathTooLong,
    NoAllocatorOnFree,
    NotEmptyOnCreate,
    NotEmptyOnSetTypeTag,
    InactivePixelTag,
    InvalidFileExtension,
    AllocTooLarge,
    InvalidSizeForFormat,
    PartialRead,
    UnexpectedEOF,
    UnexpectedEndOfImageBuffer,
    FormatUnsupported,
    FormatDisabled,
    DimensionTooLarge,
    OverlappingData,
    ColorTableImageEmptyTable,
    InvalidColorTableIndex,
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
    BmpColorSpaceUnsupported,
    BmpCompressionUnsupported,
    Bmp24BitCustomMasksUnsupported,
    BmpInvalidCompression,
    BmpInvalidColorMasks,
    BmpRLECoordinatesOutOfBounds,
    BmpInvalidRLEData,
    TgaInvalidTableSize,
    TgaImageTypeUnsupported,
    TgaColorMapDataInNonColorMapImage,
    TgaNonStandardColorTableUnsupported,
    TgaNonStandardColorDepthUnsupported,
    TgaNonStandardColorDepthForPixelFormat,
    TgaNoData,
    TgaUnexpectedReadStartIndex,
    TgaUnsupportedImageOrigin,
    TgaColorTableImageNot8BitColorDepth,
    TgaGreyscale8BitOnly,
    CannotDisallowRGBA32,
    BitmapColorReaderInvalidComptimeInputs,
    NoImageFormatsAllowed,
    NonImageFormatPassedIntoOptions,
    UnevenImageLengthsInTransfer,
    TransferBetweenFormatsUnsupported,
    UnableToVerifyFileImageFormat,
    TgaFlavorUnsupported,
    NoImageTypeAttachedToPixelTag,
    InvalidSize,
    UnableToInferFormat,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> tests
// ---------------------------------------------------------------------------------------------------------------------
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// zig test src/image/image.zig -lc --test-filter image --main-pkg-path ../

// pub fn imageTest() !void {
//     config.dbg_verbose = false;
//     try LoadImageTest();
//     config.dbg_verbose = true;
//     try targaTest();
// }

// pub fn LoadImageTest() !void {
test "load bitmap [image]" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // try memory.autoStartup();
    // defer memory.shutdown();
    // const allocator = memory.EnclaveAllocator(memory.Enclave.Game).allocator();

    if (config.run_scope_timers) try time.initScopeTimers(1, allocator);

    print("\n", .{});

    // 2.7 has coverage over core, v1, v4, and v5
    // 0.9 is V1 only

    const directory_ct = 6;
    var path_buf = LocalStringBuffer(128).new();
    const test_paths: [directory_ct][]const u8 = .{
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

    for (0..directory_ct) |i| {
        try path_buf.replace(test_paths[i]);

        var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{ .access_sub_paths = false });
        defer test_dir.close();

        var test_it = test_dir.iterate();

        while (try test_it.next()) |entry| {
            try filename_lower.replaceLower(entry.name);
            if (!string.sameTail(filename_lower.string(), "bmp") and !string.sameTail(filename_lower.string(), "dib") and !string.sameTail(filename_lower.string(), "jpg") and !string.same(filename_lower.string(), "nofileextension")) {
                continue;
            }
            const t = if (config.run_scope_timers) time.ScopeTimer.start(time.callsiteID("loadBmp", 0));
            defer if (config.run_scope_timers) t.stop();

            var image = loadImage(path_buf.string(), entry.name, ImageFormat.Bmp, allocator, &.{}) catch |e| blk: {
                if (i < 2) {
                    print("valid file {s} {any}\n", .{ filename_lower.string(), e });
                }
                break :blk Image{};
            };

            if (!image.isEmpty()) {
                // print("** success {s}\n", .{filename_lower.string()});
                if (i < 2) {
                    valid_supported += 1;
                } else if (i < 4) {
                    questionable_supported += 1;
                } else {
                    corrupt_supported += 1;
                }
                image.clear();
            }

            if (i < 2) {
                valid_total += 1;
            } else if (i < 4) {
                questionable_total += 1;
            } else {
                corrupt_total += 1;
            }
        }
    }

    const valid_perc = @as(f32, @floatFromInt(valid_supported)) / @as(f32, @floatFromInt(valid_total)) * 100.0;
    const quest_perc = @as(f32, @floatFromInt(questionable_supported)) / @as(f32, @floatFromInt(questionable_total)) * 100.0;
    const corpt_perc = @as(f32, @floatFromInt(corrupt_supported)) / @as(f32, @floatFromInt(corrupt_total)) * 100.0;
    print("bmp test suite 0.9 and 2.7\n", .{});
    print("[VALID]        total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ valid_total, valid_supported, valid_perc });
    print("[QUESTIONABLE] total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ questionable_total, questionable_supported, quest_perc });
    print("[CORRUPT]      total: {}, passed: {}, passed percentage: {d:0.1}%\n", .{ corrupt_total, corrupt_supported, corpt_perc });

    if (config.run_scope_timers) time.shutdownScopeTimers(true);
    // try std.testing.expect(valid_supported == valid_total);
}

// pub fn targaTest() !void {
test "load targa [image]" {
    // try memory.autoStartup();
    // defer memory.shutdown();
    // const allocator = memory.GameAllocator.allocator();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (config.run_scope_timers) try time.initScopeTimers(1, allocator);

    print("\n", .{});

    var path_buf = LocalStringBuffer(128).new();
    try path_buf.append("d:/projects/zig/core/test/nocommit/mytgatestsuite/good/");
    path_buf.setAnchor();

    var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{});
    defer test_dir.close();

    var dir_it = test_dir.iterate();

    while (try dir_it.next()) |entry| {
        const t = if (config.run_scope_timers) time.ScopeTimer.start(time.callsiteID("loadTga", 0)) else null;
        defer if (config.run_scope_timers) t.stop();

        var image = loadImage(path_buf.string(), entry.name, ImageFormat.Infer, allocator, &.{}) catch |e| blk: {
            print("error {any} loading tga file {s}\n", .{ e, entry.name });
            break :blk Image{};
        };

        if (!image.isEmpty()) {
            // print("loaded tga file {s} successfully\n", .{filename_lower.string()});
        }

        image.clear();
    }

    if (config.run_scope_timers) time.shutdownScopeTimers(true);
}
