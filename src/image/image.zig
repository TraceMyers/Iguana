// ::::::::::: For loading two-dimensional images from disk, into a basic standardized format.
// :: Image ::
// :::::::::::

// TODO: allocator-related free error on large alloc
// TODO: put allowed types in ImageLoadOptions

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
// !! Warning !! calling this function may require up to 3KB free stack memory.
// !! Warning !! some OS/2 BMPs are compatible, except their width and height entries are interpreted as signed integers
// (rather than the OS/2 standard for core headers, unsigned), which may lead to a failed read or row-inverted image.
pub fn loadCommonFormatImage(
    file_path: []const u8, format: ImageFormat, allocator: std.mem.Allocator, options: *const ImageLoadOptions
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
            try bmp.load(&file, &image, allocator, options);
        }
        else if (string.same(extension_lower, "tga")
            or string.same(extension_lower, "icb")
            or string.same(extension_lower, "vda")
            or string.same(extension_lower, "vst")
            or string.same(extension_lower, "tpic")
        ) {
            try tga.load(&file, &image, allocator, options);
        }
        else if (string.same(extension_lower, "png")) {
            try png.load(&file, &image, allocator, options);
        }
        else if (string.same(extension_lower, "jpg") or string.same(extension_lower, "jpeg")) {
            return ImageError.FormatUnsupported;
        }
        else {
            return ImageError.InvalidFileExtension;
        }
    }
    else switch (format) {
        .Bmp => try bmp.load(&file, &image, allocator, options),
        .Jpg => return ImageError.FormatUnsupported,
        .Png => try png.load(&file, &image, allocator, options),
        .Tga => try tga.load(&file, &image, allocator, options),
        else => unreachable,
    }
    return image;
}

pub fn getBitCt(num: anytype) comptime_int {
    return switch(@TypeOf(num)) {
        u1 => 1,
        u4 => 4,
        u5 => 5,
        u6 => 6,
        u8 => 8,
        u16 => 16,
        u24 => 24,
        u32 => 32,
        else => 0
    };
}

// for determining what format is probably best to output given the input format
pub fn autoSelectImageFormat(file_pixel_type: PixelTag, load_options: *const ImageLoadOptions) !PixelTag {
    var preference_order: [4]PixelTag = undefined;
    if (file_pixel_type.isColor()) {
        if (file_pixel_type.hasAlpha()) {
            preference_order = .{
                .RGBA32, .RGB16, .R8, .R16
            };
        }
        else if (file_pixel_type.size() == 2) {
            preference_order = .{ 
                .RGB16, .RGBA32, .R8, .R16
            };
        } else {
            preference_order = .{ 
                .RGBA32, .RGB16, .R8, .R16
            };
        }
    } else if (file_pixel_type == .U16_R) {
        preference_order = .{ 
            .R16, .R8, .RGBA32, .RGB16
        };
    } else {
        preference_order = .{ 
            .R8, .R16, .RGBA32, .RGB16
        };
    }

    inline for (0..4) |i| {
        if (load_options.output_format_allowed[@enumToInt(preference_order[i])]) {
            return preference_order[i];
        }
    }
    return ImageError.NoImageFormatsAllowed;
}

pub fn bitCtToIntType(comptime val: comptime_int) type {
    return switch(val) {
        1 => u1,
        4 => u4,
        8 => u8,
        15 => u16,
        16 => u16,
        24 => u24,
        32 => u32,
        else => void
    };
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

pub const RGBA32 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

// I was unable to get a packed struct with r:u5, g:u6, b:u5 components to work
// so, 'c' stands for components!
pub const RGB16 = extern struct {
    // r: 5, g: 6, b: 5
    c: u16,

    pub inline fn getR(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0xf800) >> 8);
    }

    pub inline fn getG(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0x07e0) >> 3);
    }

    pub inline fn getB(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0x001f) << 3);
    }

    pub inline fn setR(self: *RGB16, r: u8) void {
        self.c = (self.c & ~0xf800) | ((r & 0xf8) << 8);
    } 

    pub inline fn setG(self: *RGB16, g: u8) void {
        self.c = (self.c & ~0x07e0) | ((g & 0xfc) << 3);
    }

    pub inline fn setB(self: *RGB16, b: u8) void {
        self.c = (self.c & ~0x001f) | ((b & 0xf8) >> 3);
    }

    pub inline fn setRGB(self: *RGB16, r: u8, g: u8, b: u8) void {
        self.c = ((@intCast(u16, r) & 0xf8) << 8) | ((@intCast(u16, g) & 0xfc) << 3) | ((@intCast(u16, b) & 0xf8) >> 3);
    }

    pub inline fn setRGBFromU16(self: *RGB16, r: u16, g: u16, b: u16) void {
        self.c = (r & 0xf800) | ((g & 0xfc00) >> 5) | ((b & 0xf800) >> 11);
    }
};

pub const RGB15 = extern struct {
    // r: 5, g: 5, b: 5
    c: u16, 

    pub inline fn getR(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0x7c00) >> 8);
    }

    pub inline fn getG(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0x03e0) >> 3);
    }

    pub inline fn getB(self: *const RGB16) u8 {
        return @intCast(u8, (self.c & 0x001f) << 3);
    }

    pub inline fn setR(self: *RGB16, r: u8) void {
        // 0xfc00 here to clear the most significant 6 bits even though we're only setting the 5 least significant of 
        // the 6 most significant
        self.c = (self.c & ~0xfc00) | ((r & 0xf8) << 7);
    } 

    pub inline fn setG(self: *RGB16, g: u8) void {
        self.c = (self.c & ~0x03e0) | ((g & 0xf8) << 3);
    }

    pub inline fn setB(self: *RGB16, b: u8) void {
        self.c = (self.c & ~0x001f) | ((b & 0xf8) >> 3);
    }

    pub inline fn setRGB(self: *RGB16, r: u8, g: u8, b: u8) void {
        self.c = ((@intCast(u16, r) & 0xf8) << 7) | ((@intCast(u16, g) & 0xf8) << 3) | ((@intCast(u16, b) & 0xf8) >> 3);
    }

    pub inline fn setRGBFromU16(self: *RGB15, r: u16, g: u16, b: u16) void {
        self.c = ((r & 0xf800) >> 1) | ((g & 0xf800) >> 6) | ((b & 0xf800) >> 11);
    }
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

pub const RGBA128F = extern struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,
};

pub const RGBA128 = extern struct {
    r: u32 = 0,
    g: u32 = 0,
    b: u32 = 0,
    a: u32 = 0,
};

pub const R32F = extern struct {
    r: f32 = 0.0,
};

pub const RG64F = extern struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
};

// --- extra file load-only pixel types ---

pub const RGB24 = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
};

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

pub const RGBA64 = extern struct {
    r: u16 = 0,
    g: u16 = 0,
    b: u16 = 0,
    a: u16 = 0,
};

// --------------------------

pub const PixelTag = enum { 
    // valid image pixel formats
    RGBA32, RGB16, R8, R16, R32F, RG64F, RGBA128F, RGBA128,
    // valid internal/file pixel formats
    U32_RGBA, U32_RGB, U24_RGB, U16_RGBA, U16_RGB, U16_RGB15, U16_R, U8_R,
    
    pub fn size(self: PixelTag) usize {
        return switch(self) {
            .RGBA32 => 4,
            .RGB16 => 2,
            .R8 => 1, 
            .R16 => 2, 
            .R32F => 4,
            .RG64F => 8,
            .RGBA128F => 16,
            .RGBA128 => 16,
            .U32_RGBA => 4,
            .U32_RGB => 4,
            .U24_RGB => 3,
            .U16_RGBA => 2,
            .U16_RGB => 2,
            .U16_RGB15 => 2,
            .U16_R => 2,
            .U8_R => 1,
        };
    }

    pub fn isColor(self: PixelTag) bool {
        return switch(self) {
            .RGBA32, .RGB16, .RGBA128F, .RGBA128, .U32_RGBA, .U32_RGB, .U24_RGB, .U16_RGBA, .U16_RGB, .U16_RGB15 => true,
            else => false,
        };
    }

    pub fn hasAlpha(self: PixelTag) bool {
        return switch(self) {
            .RGBA32, .RGBA128F, .RGBA128, .U32_RGBA, .U16_RGBA => true,
            else => false,
        };
    }

    pub fn canBeLoadedFromCommonFormat(self: PixelTag) bool {
        return switch(self) {
            .RGBA32, .RGB16, .R8, .R16 => true,
            else => false,
        };
    }

    pub fn intType(comptime self: PixelTag) type {
        return switch(self) {
            .RGBA32 => u32,
            .RGB16 => u16,
            .R8 => u8, 
            .R16 => u16,
            .R32F => f32,
            .RG64F => f64,
            .RGBA128F => f128,
            .RGBA128 => u128,
            .U32_RGBA => u32,
            .U32_RGB => u32,
            .U24_RGB => u24,
            .U16_RGBA => u16,
            .U16_RGB => u16,
            .U16_RGB15 => u16,
            .U16_R => u16,
            .U8_R => u8,
        };
    }

    pub fn toType(comptime self: PixelTag) type {
        return switch(self) {
            .RGBA32 => RGBA32,
            .RGB16 => RGB16,
            .R8 => R8, 
            .R16 => R16,
            .R32F => R32F,
            .RG64F => RG64F,
            .RGBA128F => RGBA128F,
            .RGBA128 => RGBA128,
            .U32_RGBA => u32,
            .U32_RGB => u32,
            .U24_RGB => u24,
            .U16_RGBA => u16,
            .U16_RGB => u16,
            .U16_RGB15 => u16,
            .U16_R => u16,
            .U8_R => u8,
        };
    }
};

pub const PixelTagPair = struct {
    in_tag: PixelTag = PixelTag.RGBA32,
    out_tag: PixelTag = PixelTag.RGBA32,
};

pub const F32x2 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
};

pub const ImageLoadBuffer = struct {
    allocation: ?[]u8 = null,
    alignment: u29 = 0
};

pub const PixelSlice = union(PixelTag) {
    RGBA32: []RGBA32,
    RGB16: []RGB16,
    R8: []R8,
    R16: []R16,
    R32F: []R32F,
    RG64F: []RG64F,
    RGBA128F: []RGBA128F,
    RGBA128: []RGBA128,
    U32_RGBA: []u32,
    U32_RGB: []u32,
    U24_RGB: []u24,
    U16_RGBA: []u16,
    U16_RGB: []u16,
    U16_RGB15: []u16,
    U16_R: []u16,
    U8_R: []u8
};

pub const PixelContainer = struct {
    bytes: ?[]u8 = null,
    pixels: PixelSlice = PixelSlice{ .RGBA32 = undefined },
    allocator: ?std.mem.Allocator = null,

    pub fn alloc(self: *PixelContainer, in_allocator: std.mem.Allocator, tag: PixelTag, count: usize) !void {
        switch(tag) {
            .RGBA32 => self.pixels = PixelSlice{ .RGBA32 = try self.allocWithType(in_allocator, RGBA32, count) },
            .RGB16 => self.pixels = PixelSlice{ .RGB16 = try self.allocWithType(in_allocator, RGB16, count) },
            .R8 => self.pixels = PixelSlice{ .R8 = try self.allocWithType(in_allocator, R8, count) },
            .R16 => self.pixels = PixelSlice{ .R16 = try self.allocWithType(in_allocator, R16, count) },
            .R32F => self.pixels = PixelSlice{ .R32F = try self.allocWithType(in_allocator, R32F, count) },
            .RG64F => self.pixels = PixelSlice{ .RG64F = try self.allocWithType(in_allocator, RG64F, count) },
            .RGBA128F => self.pixels = PixelSlice{ .RGBA128F = try self.allocWithType(in_allocator, RGBA128F, count) },
            .RGBA128 => self.pixels = PixelSlice{ .RGBA128 = try self.allocWithType(in_allocator, RGBA128, count) },
            else => unreachable,
        }
    }

    pub fn attachToBuffer(self: *PixelContainer, buffer: []u8, tag: PixelTag, count: usize) void {
        switch(tag) {
            .RGBA32 => self.pixels = PixelSlice{ .RGBA32 = self.attachWithType(buffer, RGBA32, count) },
            .RGB16 => self.pixels = PixelSlice{ .RGB16 = self.attachWithType(buffer, RGB16, count) },
            .R8 => self.pixels = PixelSlice{ .R8 = self.attachWithType(buffer, R8, count) },
            .R16 => self.pixels = PixelSlice{ .R16 = self.attachWithType(buffer, R16, count) },
            .R32F => self.pixels = PixelSlice{ .R32F = self.attachWithType(buffer, R32F, count) },
            .RG64F => self.pixels = PixelSlice{ .RG64F = self.attachWithType(buffer, RG64F, count) },
            .RGBA128F => self.pixels = PixelSlice{ .RGBA128F = self.attachWithType(buffer, RGBA128F, count) },
            .RGBA128 => self.pixels = PixelSlice{ .RGBA128 = self.attachWithType(buffer, RGBA128, count) },
            else => unreachable,
        }
    }

    pub fn unattachFromBuffer(self: *PixelContainer) void {
        std.debug.assert(self.bytes != null and self.allocator == null);
        self.* = PixelContainer{};
    }

    pub fn free(self: *PixelContainer) void {
        if (self.bytes != null) {
            std.debug.assert(self.allocator != null);
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
        return @ptrCast([*]PixelType, @alignCast(@alignOf(PixelType), &self.bytes.?[0]))[0..count];
    }

    fn attachWithType(self: *PixelContainer, buffer: []u8, comptime PixelType: type, count: usize) []PixelType {
        self.allocator = null;
        self.bytes = buffer;
        return @ptrCast([*]PixelType, @alignCast(@alignOf(PixelType), &self.bytes.?[0]))[0..count];
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
    pub fn attachToBuffer(self: *Image, buffer: []u8, type_tag: PixelTag, width: u32, height: u32) !void {
        if (!self.isEmpty()) {
            return ImageError.NotEmptyOnSetTypeTag;
        }
        self.width = width;
        self.height = height;
        self.px_container.attachToBuffer(buffer, type_tag, self.len());
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

    pub fn getPixels(self: *const Image, comptime type_tag: PixelTag) !(std.meta.TagPayload(PixelSlice, type_tag)) {
        return switch(self.px_container.pixels) {
            type_tag => |slice| slice,
            else => ImageError.InactivePixelTag,
        };
    }

    pub inline fn XYToIdx(self: *const Image, x: u32, y: u32) usize {
        return y * self.width + x;
    }

    pub inline fn IdxToXY(self: *const Image, idx: u32) F32x2 {
        var vec: F32x2 = undefined;
        vec.y = idx / self.width;
        vec.x = idx - vec.y * self.width;
        return vec;
    }

};

pub const ImageLoadOptions = struct {
    // image loading system is not allowed to attempt to load the image as any other format than whichever
    // is first inferred or assigned. Also used internally when attempting to load as a fmt other than the first, to
    // prevent infinite recursion.
    format_comitted: bool = false,
    // for setting which pixel formats are allowed with functions; RGBA32, RGB16, R8, R16
    output_format_allowed: [4]bool = .{ true, true, true, true },

    pub fn setOnlyAllowedFormat(self: *ImageLoadOptions, type_tag: PixelTag) !void {
        switch (type_tag) {
            .RGBA32, .RGB16, .R8, .R16 => {
                inline for (0..4) |i| {
                    self.output_format_allowed[i] = false;
                }
                self.output_format_allowed[@enumToInt(type_tag)] = true;
            },
            else => return ImageError.NonImageFormatPassedIntoOptions,
        }
    }

    pub fn setFormatAllowed(self: *ImageLoadOptions, type_tag: PixelTag) !void {
        switch (type_tag) {
            .RGBA32, .RGB16, .R8, .R16 => {
                self.output_format_allowed[@enumToInt(type_tag)] = true;
            },
            else => return ImageError.NonImageFormatPassedIntoOptions,
        }
    }

    pub fn setFormatDisallowed(self: *ImageLoadOptions, type_tag: PixelTag) !void {
        switch (type_tag) {
            .RGBA32, .RGB16, .R8, .R16 => {
                self.output_format_allowed[@enumToInt(type_tag)] = false;
            },
            else => return ImageError.NonImageFormatPassedIntoOptions,
        }
    }

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

            var image = loadCommonFormatImage(path_buf.string(), ImageFormat.Bmp, allocator, &.{}) catch |e| blk: {
                if (i < 2) {
                    print("valid file {s} {any}\n", .{filename_lower.string(), e});
                }
                break :blk Image{};
            };

            if (!image.isEmpty()) {
                print("** success {s}\n", .{filename_lower.string()});
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

// pub fn targaTest() !void {
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

    while (try dir_it.next()) |entry| {
        try filename_lower.replaceLower(entry.name);
        try path_buf.append(filename_lower.string());
        defer path_buf.revertToAnchor();

        var t = bench.ScopeTimer.start("loadTga", bench.getScopeTimerID());
        defer t.stop();

        var image = loadCommonFormatImage(path_buf.string(), ImageFormat.Infer, allocator, &.{}) 
            catch |e| blk: {
                print("error {any} loading tga file {s}\n", .{e, filename_lower.string()});
                break :blk Image{};
            };

        if (!image.isEmpty()) {
            print("loaded tga file {s} successfully\n", .{filename_lower.string()});
        }

        image.clear();
    }

    bench.printAllScopeTimers();
}