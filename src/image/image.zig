// ::::::::::: For loading two-dimensional images from disk, into a basic standardized format.
// :: Image ::
// :::::::::::

// TODO: allocator-related free error on large alloc

pub const ImageError = error{
    NoFileExtension,
    NoAllocatorOnFree,
    NotEmptyOnCreate,
    NotEmptyOnSetTypeTag,
    InactivePixelTag,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    UnexpectedEOF,
    UnexpectedEndOfImageBuffer,
    FormatUnsupported,
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
    TgaNoData,
    TgaUnexpectedReadStartIndex,
    TgaUnsupportedImageOrigin,
    TgaColorTableImageNot8BitColorDepth,
    TgaGreyscale8BitOnly,
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
    errdefer image.clear();

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
            or string.same(extension_lower, "tpic")
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

pub const ImageAlpha = enum { None, Normal, Premultiplied };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// --- Image pixel types ---

pub const RGB24 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
};

pub const RGBA32 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

pub const R8 = extern struct {
    r: u8 = 0,
};

pub const R16 = extern struct {
    r: u16 = 0,
};

pub const R32 = extern struct {
    r: u32 = 0,
};

pub const RA16 = extern struct {
    r: u8 = 0,
    a: u8 = 0,
};

pub const RA32 = extern struct {
    r: u16 = 0,
    a: u16 = 0,
};

// --- extra file load-only pixel types ---

pub const RGB32 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    reserved: u8 = 0,
};

pub const BGR24 = extern struct {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
};

pub const BGR32 = extern struct {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
    reserved: u8 = 0,
};

pub const ARGB64 = extern struct {
    a: u16,
    r: u16,
    g: u16,
    b: u16,
};

// --------------------------

pub const PixelTag = enum { 
    RGB24, RGBA32, R8, R16, R32, RA16, RA32,
    
    pub fn size(self: PixelTag) usize {
        return switch(self) {
            RGB24 => 3, 
            RGBA32 => 4, 
            R8 => 1, 
            R16 => 2, 
            R32 => 4, 
            RA16 => 2, 
            RA32 => 4,
        };
    }
};

pub const PixelSlice = union(PixelTag) {
    RGB24: ?[]RGB24,
    RGBA32: ?[]RGBA32,
    R8: ?[]R8,
    R16: ?[]R16,
    R32: ?[]R32,
    RA16: ?[]RA16,
    RA32: ?[]RA32,
};

pub const PixelContainer = struct {
    bytes: ?[]u8 = null,
    pixels: PixelSlice = PixelSlice{ .RGB24 = null },
    allocator: ?std.mem.Allocator = null,

    pub fn alloc(self: *PixelContainer, in_allocator: std.mem.Allocator, tag: PixelTag, count: usize) !void {
        switch(tag) {
            .RGB24 => self.pixels = PixelSlice{ .RGB24 = try self.allocWithType(in_allocator, RGB24, count) },
            .RGBA32 => self.pixels = PixelSlice{ .RGBA32 = try self.allocWithType(in_allocator, RGBA32, count) },
            .R8 => self.pixels = PixelSlice{ .R8 = try self.allocWithType(in_allocator, R8, count) },
            .R16 => self.pixels = PixelSlice{ .R16 = try self.allocWithType(in_allocator, R16, count) },
            .R32 => self.pixels = PixelSlice{ .R32 = try self.allocWithType(in_allocator, R32, count) },
            .RA16 => self.pixels = PixelSlice{ .RA16 = try self.allocWithType(in_allocator, RA16, count) },
            .RA32 => self.pixels = PixelSlice{ .RA32 = try self.allocWithType(in_allocator, RA32, count) },
        }
    }

    pub fn attachToBuffer(self: *PixelContainer, buffer: []u8, tag: PixelTag, count: usize) void {
        switch(tag) {
            .RGB24 => self.pixels = PixelSlice{ .RGB24 = self.attachWithType(buffer, RGB24, count) },
            .RGBA32 => self.pixels = PixelSlice{ .RGBA32 = self.attachWithType(buffer, RGBA32, count) },
            .R8 => self.pixels = PixelSlice{ .R8 = self.attachWithType(buffer, R8, count) },
            .R16 => self.pixels = PixelSlice{ .R16 = self.attachWithType(buffer, R16, count) },
            .R32 => self.pixels = PixelSlice{ .R32 = self.attachWithType(buffer, R32, count) },
            .RA16 => self.pixels = PixelSlice{ .RA16 = self.attachWithType(buffer, RA16, count) },
            .RA32 => self.pixels = PixelSlice{ .RA32 = self.attachWithType(buffer, RA32, count) },
        }
    }

    pub fn unattachFromBuffer(self: *PixelContainer) void {
        std.debug.assert(self.bytes != null and self.allocator == null);
        self.* = PixelContainer{};
    }

    pub fn free(self: *PixelContainer) !void {
        if (self.bytes != null) {
            if (self.allocator == null) {
                return ImageError.NoAllocatorOnFree;
            }
            self.allocator.?.free(self.bytes.?);
        }
        self.* = PixelContainer{};
    }

    pub inline fn isEmpty(self: *const PixelContainer) bool {
        return self.bytes == null and self.allocator == null;
    }

    fn allocWithType(
        self: *PixelContainer, in_allocator: std.mem.Allocator, comptime PixelType: type, count: usize
    ) ![]PixelType {
        const sz = @sizeOf(PixelType) * count;
        self.allocator = in_allocator;
        self.bytes = try self.allocator.?.alloc(u8, sz);
        return @ptrCast([*]PixelType, @alignCast(@alignOf(PixelType), &self.bytes[0]))[0..count];
    }

    fn attachWithType(self: *PixelContainer, buffer: []u8, comptime PixelType: type, count: usize) []PixelType {
        self.allocator = null;
        self.bytes = buffer;
        return @ptrCast([*]PixelType, @alignCast(@alignOf(PixelType), &self.bytes[0]))[0..count];
    }

};

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    px_container: PixelContainer = PixelContainer{},
    premultiplied_alpha: bool = false,

    pub fn init(self: *Image, in_allocator: std.mem.Allocator, type_tag: PixelTag, width: u32, height: u32) !void {
        if (!self.isEmpty()) {
            return ImageError.NotEmptyOnCreate;
        }
        self.width = width;
        self.height = height;
        try self.px_container.alloc(in_allocator, type_tag, self.len());
    }

    pub fn clear(self: *Image) void {
        self.width = 0;
        self.height = 0;
        self.px_container.free();
        self.premultiplied_alpha = false;
    }

    pub inline fn len(self: *const Image) usize {
        return @intCast(usize, self.width) * @intCast(usize, self.height);
    }

    pub inline fn activePixelTag(self: *const Image) PixelTag {
        return std.meta.activeTag(self.px_container.pixels);
    }

    pub inline fn isEmpty(self: *const Image) bool {
        return self.px_container.isEmpty();
    }

    pub inline fn getBytes(self: *Image) []u8 {
        return self.px_container.bytes.?;
    }

    // attach/unattach can cause a memory leak if you're manually unattaching from heap buffers. using attach/unattach 
    // with heap buffers is not recommended.
    pub fn attachToBuffer(self: *Image, buffer: []u8, type_tag: PixelTag, ct: usize) !void {
        if (!self.isEmpty()) {
            return ImageError.NotEmptyOnSetTypeTag;
        }
        self.width = ct;
        self.height = 1;
        self.px_container.attachToBuffer(buffer, type_tag, ct);
        self.premultiplied_alpha = false;
    }

    // attach/unattach can cause a memory leak if you're manually unattaching from heap buffers. using attach/unattach 
    // with heap buffers is not recommended.
    pub fn unattachFromBuffer(self: *Image) void {
        self.width = 0;
        self.height = 0;
        self.px_container.unattachFromBuffer();
        self.premultiplied_alpha = false;
    }

    pub fn getPixels(self: *Image, comptime type_tag: PixelTag) !fieldType(type_tag) {
        return switch(self.px_container.pixels) {
            type_tag => |slice| slice.?,
            else => ImageError.InactivePixelTag,
        };
    }

    pub fn fieldType(comptime tag: PixelTag) type {
        return std.meta.fields(PixelTag)[@enumToInt(tag)].field_type;
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

    const alloc_sz = 4_194_304 / 2; // 2MB
    const load_options = ImageLoadOptions{
        .load_buffer = ImageLoadBuffer{
            .alignment = 4,
            .allocation = try allocator.alignedAlloc(u8, 4, alloc_sz)
        },
    };

    for (0..directory_ct) |i| {
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

            if (!image.isEmpty()) {
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

pub fn targaTest() !void {
// test "load targa [image]" {
    // try memory.autoStartup();
    // defer memory.shutdown();
    // const allocator = memory.GameAllocator.allocator();

    // print("\n", .{});

    // var path_buf = LocalStringBuffer(128).new();
    // try path_buf.append("d:/projects/zig/core/test/nocommit/mytgatestsuite/good/");
    // path_buf.setAnchor();

    // var filename_lower = LocalStringBuffer(64).new();

    // var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{});
    // var dir_it = test_dir.iterate();

    // while (try dir_it.next()) |entry| {
    //     try filename_lower.replaceLower(entry.name);
    //     try path_buf.append(filename_lower.string());
    //     defer path_buf.revertToAnchor();

    //     var t = bench.ScopeTimer.start("loadTga", bench.getScopeTimerID());
    //     defer t.stop();

    //     var image = loadImage(path_buf.string(), ImageFormat.Infer, allocator, .{}) 
    //         catch |e| blk: {
    //             print("error {any} loading tga file {s}\n", .{e, filename_lower.string()});
    //             break :blk Image{};
    //         };

    //     if (image.pixels != null) {
    //         print("loaded tga file {s} successfully\n", .{filename_lower.string()});
    //     }

    //     image.clear();
    // }

    // bench.printAllScopeTimers();
}