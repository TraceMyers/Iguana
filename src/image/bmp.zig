const graphics = @import("../graphics.zig");
const std = @import("std");
const string = @import("../string.zig");
const memory = @import("../memory.zig");
const imagef = @import("image.zig");
const bench = @import("../benchmark.zig");
const png = @import("png.zig");
const math = @import("../math.zig");
const readerf = @import("reader.zig");

const LocalStringBuffer = string.LocalStringBuffer;
const RGBA32 = graphics.RGBA32;
const RGB24 = graphics.RGB24;
const print = std.debug.print;
const Image = imagef.Image;
const ImageError = imagef.ImageError;
const InlinePixelReader = readerf.InlinePixelReader;
const RLEReader = readerf.RLEReader;
const RLEAction = readerf.RLEAction;
const ColorLayout = readerf.ColorLayout;

// calibration notes for when it becomes useful:

// X = Sum_lambda=(380)^780 [S(lambda) xbar(lambda)]
// Y = Sum_lambda=(380)^780 [S(lambda) ybar(lambda)]
// Z = Sum_lambda=(380)^780 [S(lambda) zbar(lambda)]
// the continuous version is the same, but integrated over lambda, 0 to inf. S(lambda) also called I(lambda)

// ybar color-matching function == equivalent response of the human eye to range of of light on visible spectrum
// Y is CIE Luminance, indicating overall intensity of light

// Color Intensity = (Voltage + MonitorBlackLevel)^(Gamma)
// where MonitorBlackLevel is ideally 0
// for most monitors, g ~ 2.5
// 0 to 255 ~ corresponds to voltage range of a pixel p

// "Lightness" value, approximate to human perception...
// L* = if (Y/Yn <= 0.008856) 903.3 * (Y/Yn);
//      else 116 * (Y/Yn)^(1/3) - 16
//      in (0, 100)
// ... where each integral increment of L* corresponds to a perceivably change in lightness
// ... and where Yn is a white level.

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- load!
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn load(file: *std.fs.File, image: *Image, allocator: std.mem.Allocator, options: *const imagef.ImageLoadOptions) !void {
    var externally_allocated: bool = undefined;
    var buffer: []u8 = try loadFileAndCoreHeaders(file, allocator, bmp_min_sz, options, &externally_allocated);
    defer if (!externally_allocated) allocator.free(buffer);

    const format: imagef.ImageFormat = try validateIdentity(buffer);
    switch (format) {
        .Bmp => {},
        .Jpg => {
            return ImageError.FormatUnsupported;
        },
        .Png => {
            try redirectToPng(file, image, allocator, options, buffer);
            return;
        },
        else => unreachable,
    }

    var info = BitmapInfo{};
    if (!readInitial(buffer, &info)) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }
    if (buffer.len <= info.header_sz + bmp_file_header_sz or buffer.len <= info.data_offset) {
        return ImageError.UnexpectedEOF;
    }

    try loadRemainder(file, buffer, &info);

    var color_table = BitmapColorTable{};
    var buffer_pos: usize = undefined;
    switch (info.header_sz) {
        bmp_info_header_sz_core => buffer_pos = try readCoreInfo(buffer, &info, &color_table),
        bmp_info_header_sz_v1 => buffer_pos = try readV1Info(buffer, &info, &color_table),
        bmp_info_header_sz_v4 => buffer_pos = try readV4Info(buffer, &info, &color_table),
        bmp_info_header_sz_v5 => buffer_pos = try readV5Info(buffer, &info, &color_table),
        else => return ImageError.BmpInvalidHeaderSizeOrVersionUnsupported,
    }

    if (!colorSpaceSupported(&info)) {
        return ImageError.BmpColorSpaceUnsupported;
    }
    if (!compressionSupported(&info)) {
        return ImageError.BmpCompressionUnsupported;
    }

    try createImage(buffer, image, &info, &color_table, allocator);
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------- gathering information
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadFileAndCoreHeaders(
    file: *std.fs.File, 
    allocator: std.mem.Allocator, 
    min_sz: usize, 
    options: *const imagef.ImageLoadOptions, 
    externally_allocated: *bool
) ![]u8 {
    const stat = try file.stat();
    if (stat.size + 4 > memory.MAX_SZ) {
        return ImageError.TooLarge;
    }
    if (stat.size < min_sz) {
        return ImageError.InvalidSizeForFormat;
    }

    var buffer: []u8 = undefined;
    if (options.load_buffer.alignment == 4 
        and options.load_buffer.allocation != null 
        and options.load_buffer.allocation.?.len >= stat.size + 4
    ) {
        externally_allocated.* = true;
        buffer = options.load_buffer.allocation.?;
    } else {
        externally_allocated.* = false;
        buffer = try allocator.alignedAlloc(u8, 4, stat.size + 4);
    }

    for (0..bmp_file_header_sz + bmp_info_header_sz_core) |i| {
        buffer[i] = try file.reader().readByte();
    }

    return buffer;
}

fn redirectToPng(
    file: *std.fs.File, 
    image: *Image, 
    allocator: std.mem.Allocator, 
    options: *const imagef.ImageLoadOptions, 
    buffer: []u8
) !void {
    var retry_options = options.*;
    retry_options.format_comitted = true;
    if (options.load_buffer.allocation == null) {
        retry_options.load_buffer = imagef.ImageLoadBuffer{ .allocation = buffer, .alignment = 4 };
    }
    try file.seekTo(0);
    try png.load(file, image, allocator, &retry_options);
}

fn loadRemainder(file: *std.fs.File, buffer: []u8, info: *BitmapInfo) !void {
    const cur_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    if (info.data_offset > bmp_file_header_sz + bmp_info_header_sz_v5 + @sizeOf(RGBA32) * 256 + 4 
        or info.data_offset <= cur_offset
    ) {
        return ImageError.BmpInvalidBytesInInfoHeader;
    }

    for (cur_offset..info.data_offset) |i| {
        buffer[i] = try file.reader().readByte();
    }

    // aligning pixel data to a 4 byte boundary (requirement)
    const offset_mod_4 = info.data_offset % 4;
    const offset_mod_4_neq_0 = @intCast(u32, @boolToInt(offset_mod_4 != 0));
    info.data_offset = info.data_offset + offset_mod_4_neq_0 * (4 - offset_mod_4);

    var data_buf: []u8 = buffer[info.data_offset..];
    _ = try file.reader().read(data_buf);
}

inline fn readInitial(buffer: []const u8, info: *BitmapInfo) bool {
    info.file_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return false;
    }
    info.data_offset = std.mem.readIntNative(u32, buffer[10..14]);
    info.header_sz = std.mem.readIntNative(u32, buffer[14..18]);
    return true;
}

fn validateIdentity(buffer: []const u8) !imagef.ImageFormat {
    const identity = buffer[0..2];
    if (string.same(identity, imagef.bmp_identifier)) {
        return imagef.ImageFormat.Bmp;
    }
    // png identity string is 8 bytes
    if (string.same(buffer[0..8], imagef.png_identifier)) {
        return imagef.ImageFormat.Png;
    }
    // identity strings acceptable for forms of OS/2 bitmaps. microsoft shouldered-out IBM and started taking over
    // the format during windows 3.1 times.
    if (string.same(identity, "BA") 
        or string.same(identity, "CI") 
        or string.same(identity, "CP") 
        or string.same(identity, "IC") 
        or string.same(identity, "PT")
    ) {
        return ImageError.BmpFlavorUnsupported;
    } else {
        return ImageError.BmpInvalidBytesInFileHeader;
    }
}

fn readCoreInfo(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    const data_size_signed = @intCast(i32, info.file_sz) - @intCast(i32, info.data_offset);
    if (data_size_signed < 4) {
        return ImageError.BmpInvalidBytesInInfoHeader;
    }
    info.data_size = @intCast(u32, data_size_signed);
    info.compression = BitmapCompression.RGB;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB24);
    return table_offset + color_table.length * @sizeOf(graphics.RGB24);
}

fn readV1Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V1;
    try readV1HeaderPart(buffer, info);
    var mask_offset: usize = 0;
    if (info.compression == BitmapCompression.BITFIELDS) {
        readColorMasks(buffer, info, false);
        mask_offset = 12;
    } else if (info.compression == BitmapCompression.ALPHABITFIELDS) {
        readColorMasks(buffer, info, true);
        mask_offset = 16;
    }
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v1 + mask_offset;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

fn readV4Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V4;
    try readV1HeaderPart(buffer, info);
    try readV4HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v4;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

fn readV5Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V5;
    try readV1HeaderPart(buffer, info);
    try readV4HeaderPart(buffer, info);
    readV5HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v5;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

fn readV1HeaderPart(buffer: []u8, info: *BitmapInfo) !void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[28..30]));
    const compression_int = std.mem.readIntNative(u32, buffer[30..34]);
    if (compression_int > 9) {
        return ImageError.BmpInvalidBytesInInfoHeader;
    }
    info.compression = @intToEnum(BitmapCompression, compression_int);
    info.data_size = std.mem.readIntNative(u32, buffer[34..38]);
    info.color_ct = std.mem.readIntNative(u32, buffer[46..50]);
}

fn readV4HeaderPart(buffer: []u8, info: *BitmapInfo) !void {
    readColorMasks(buffer, info, true);
    const color_space_int = std.mem.readIntNative(u32, buffer[70..74]);
    if (color_space_int != 0 
        and color_space_int != 0x4c494e4b 
        and color_space_int != 0x4d424544 
        and color_space_int != 0x57696e20 
        and color_space_int != 0x73524742
    ) {
        return ImageError.BmpInvalidBytesInInfoHeader;
    }
    info.color_space = @intToEnum(BitmapColorSpace, color_space_int);
    if (info.color_space != BitmapColorSpace.CalibratedRGB) {
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

inline fn readV5HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.profile_data = std.mem.readIntNative(u32, buffer[126..130]);
    info.profile_size = std.mem.readIntNative(u32, buffer[130..134]);
}

inline fn readColorMasks(buffer: []u8, info: *BitmapInfo, alpha: bool) void {
    info.red_mask = std.mem.readIntNative(u32, buffer[54..58]);
    info.green_mask = std.mem.readIntNative(u32, buffer[58..62]);
    info.blue_mask = std.mem.readIntNative(u32, buffer[62..66]);
    if (alpha) {
        info.alpha_mask = std.mem.readIntNative(u32, buffer[66..70]);
    }
}

fn readColorTable(
    buffer: []const u8, 
    info: *const BitmapInfo, 
    color_table: *BitmapColorTable, 
    comptime ColorType: type
) !void {
    var data_casted = @ptrCast([*]const ColorType, @alignCast(@alignOf(ColorType), &buffer[0]));

    switch (info.color_depth) {
        32, 24, 16 => {
            color_table.length = 0;
            return;
        },
        8, 4, 1 => {
            const max_color_ct = @as(u32, 1) << @intCast(u5, info.color_depth);
            if (info.color_ct == 0) {
                color_table.length = max_color_ct;
            } else if (info.color_ct >= 2 and info.color_ct <= max_color_ct) {
                color_table.length = info.color_ct;
            } else {
                return ImageError.BmpInvalidColorCount;
            }
        },
        else => return ImageError.BmpInvalidColorDepth,
    }

    if (buffer.len <= color_table.length * @sizeOf(ColorType)) {
        return ImageError.UnexpectedEOF;
    }
    else for (0..color_table.length) |i| {
        const table_color: *RGBA32 = &color_table.buffer[i];
        const buffer_color: *const ColorType = &data_casted[i];
        // bgr to rgb
        table_color.a = 255;
        table_color.b = buffer_color.r;
        table_color.g = buffer_color.g;
        table_color.r = buffer_color.b;
    }
}

pub fn colorSpaceSupported(info: *const BitmapInfo) bool {
    return switch (info.color_space) {
        // calibration information is unused because it doesn't make sense to calibrate individual textures in a game engine
        .CalibratedRGB => true,
        // I see no reason to support profiles. Seems like a local machine and/or printing thing
        .ProfileLinked => false,
        .ProfileEmbedded => false,
        .WindowsCS => true,
        .sRGB => true,
        .None => true,
    };
}

pub fn compressionSupported(info: *const BitmapInfo) bool {
    return switch (info.compression) {
        .RGB => true,
        .RLE8 => true,
        .RLE4 => true,
        .BITFIELDS => true,
        .JPEG => false,
        .PNG => false,
        .ALPHABITFIELDS => true,
        .CMYK => false,
        .CMYKRLE8 => false,
        .CMYKRLE4 => false,
        .None => false,
    };
}

inline fn bufferLongEnough(pixel_buf: []const u8, image: *const Image, row_length: usize) bool {
    return pixel_buf.len >= row_length * image.height;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------- creation helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

inline fn bytesPerRow(comptime PixelType: type, image_width: u32) u32 {
    var byte_ct_floor: u32 = undefined;
    var colors_per_byte: u32 = undefined;
    switch (PixelType) {
        u1 => {
            byte_ct_floor = image_width >> 3;
            colors_per_byte = 8;
        },
        u4 => {
            byte_ct_floor = image_width >> 1;
            colors_per_byte = 2;
        },
        u8 => {
            byte_ct_floor = image_width;
            colors_per_byte = 1;
        },
        else => unreachable,
    }
    const row_remainder_exists = @intCast(u32, @boolToInt((image_width - byte_ct_floor * colors_per_byte) > 0));
    return byte_ct_floor + row_remainder_exists;
}

fn readColorTableImageRow(
    index_row: []const u8, 
    image_row: []RGBA32, 
    colors: []const RGBA32, 
    row_byte_ct: u32, 
    comptime base_mask: comptime_int,
    comptime PixelType: type,
) !void {
    const bit_width: comptime_int = @typeInfo(PixelType).Int.bits;
    const colors_per_byte: comptime_int = 8 / bit_width;

    var img_idx: usize = 0;
    for (0..row_byte_ct) |byte| {
        const idx_byte = index_row[byte];
        inline for (0..colors_per_byte) |j| {
            if (img_idx + j >= image_row.len) {
                return;
            }
            const mask_shift: comptime_int = j * bit_width;
            const result_shift: comptime_int = ((colors_per_byte - 1) - j) * bit_width;
            const mask = @as(u8, base_mask) >> mask_shift;
            const col_idx: u8 = (idx_byte & mask) >> result_shift;
            if (col_idx >= colors.len) {
                return ImageError.BmpInvalidColorTableIndex;
            }
            image_row[img_idx + j] = colors[col_idx];
        }
        img_idx += colors_per_byte;
    }
}

// valid masks don't intersect, can't overflow their type (ie 17 bits used w/ 16 bit color), and according to the
// standard, they should also be contiguous, but I don't see why that matters.
fn validColorMasks(comptime PixelType: type, info: *const BitmapInfo) bool {
    const mask_intersection = info.red_mask & info.green_mask & info.blue_mask & info.alpha_mask;
    if (mask_intersection > 0) {
        return false;
    }
    const mask_union = info.red_mask | info.green_mask | info.blue_mask | info.alpha_mask;
    const type_overflow = ((@as(u32, @sizeOf(u32)) << 3) - @clz(mask_union)) > (@as(u32, @sizeOf(PixelType)) << 3);
    if (type_overflow) {
        return false;
    }
    return true;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------------ creation
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn createImage(
    buffer: []const u8, 
    image: *Image, 
    info: *BitmapInfo, 
    color_table: *const BitmapColorTable, 
    allocator: std.mem.Allocator
) !void {
    image.width = @intCast(u32, try std.math.absInt(info.width));
    image.height = @intCast(u32, try std.math.absInt(info.height));

    const img_sz = @intCast(usize, image.width) * @intCast(usize, image.height) * @sizeOf(RGBA32);
    if (img_sz > memory.MAX_SZ) {
        return ImageError.TooLarge;
    }
    // basic check width & height information isn't corrupted
    const remain_sz_div4 = (buffer.len - info.data_offset) >> @as(u5, 2);
    if (image.width > remain_sz_div4 or image.height > remain_sz_div4) {
        if (info.compression != .RLE8 and info.compression != .RLE4) {
            return ImageError.BmpInvalidSizeInfo;
        }
    }
    if (image.width == 0 or image.height == 0) {
        return ImageError.BmpInvalidSizeInfo;
    }

    image.allocator = allocator;
    image.pixels = try image.allocator.?.alloc(graphics.RGBA32, image.width * image.height);

    // get row length in bytes as a multiple of 4 (rows are padded to 4 byte increments)
    const row_length = ((image.width * info.color_depth + 31) & ~@as(u32, 31)) >> 3;
    const pixel_buf = buffer[info.data_offset..buffer.len];
    info.data_size = @intCast(u32, buffer.len - info.data_offset);

    try switch (info.compression) {
        .RGB => switch (info.color_depth) {
            1 => try readColorTableImage(u1, pixel_buf, info, color_table, image, row_length),
            4 => try readColorTableImage(u4, pixel_buf, info, color_table, image, row_length),
            8 => try readColorTableImage(u8, pixel_buf, info, color_table, image, row_length),
            16 => try readInlinePixelImage(u16, pixel_buf, info, image, row_length, true),
            24 => try readInlinePixelImage(u24, pixel_buf, info, image, row_length, true),
            32 => try readInlinePixelImage(u32, pixel_buf, info, image, row_length, true),
            else => ImageError.BmpInvalidColorDepth,
        },
        .RLE4 => try readRunLengthEncodedImage(u4, @ptrCast([*]const u8, &pixel_buf[0]), info, color_table, image),
        .RLE8 => try readRunLengthEncodedImage(u8, @ptrCast([*]const u8, &pixel_buf[0]), info, color_table, image),
        .BITFIELDS, .ALPHABITFIELDS => switch (info.color_depth) {
            16 => try readInlinePixelImage(u16, pixel_buf, info, image, row_length, false),
            32 => try readInlinePixelImage(u32, pixel_buf, info, image, row_length, false),
            else => return ImageError.BmpInvalidCompression,
        },
        else => return ImageError.BmpCompressionUnsupported,
    };
}

fn readColorTableImage(
    comptime PixelType: type, 
    pixel_buf: []const u8, 
    info: *const BitmapInfo, 
    color_table: *const BitmapColorTable, 
    image: *Image, 
    row_sz: usize
) !void {
    if (color_table.length < 2) {
        return ImageError.BmpInvalidColorTable;
    }
    if (!bufferLongEnough(pixel_buf, image, row_sz)) {
        return ImageError.UnexpectedEOF;
    }

    const direction_info = BitmapDirectionInfo.new(info, image.width, image.height);
    const row_byte_ct = bytesPerRow(PixelType, image.width);
    const colors: []const RGBA32 = color_table.slice();

    var px_row_start: usize = 0;
    for (0..image.height) |i| {
        const row_start = @intCast(usize, direction_info.begin + direction_info.increment * @intCast(i32, i));
        const row_end = row_start + image.width;

        var index_row: []const u8 = pixel_buf[px_row_start .. px_row_start + row_sz];
        var image_row: []RGBA32 = image.pixels.?[row_start..row_end];

        // over each pixel (index to the color table) in the buffer row...
        switch (PixelType) {
            u1 => try readColorTableImageRow(index_row, image_row, colors, row_byte_ct, 0x80, u1),
            u4 => try readColorTableImageRow(index_row, image_row, colors, row_byte_ct, 0xf0, u4),
            u8 => try readColorTableImageRow(index_row, image_row, colors, row_byte_ct, 0xff, u8),
            else => unreachable,
        }
        px_row_start += row_sz;
    }
}

fn readInlinePixelImage(
    comptime PixelType: type, 
    pixel_buf: []const u8, 
    info: *const BitmapInfo, 
    image: *Image, 
    row_sz: usize, 
    standard_masks: bool
) !void {
    var alpha_mask_present = info.compression == .ALPHABITFIELDS or info.alpha_mask > 0;

    if (!bufferLongEnough(pixel_buf, image, row_sz)) {
        return ImageError.UnexpectedEOF;
    }
    if (!standard_masks or alpha_mask_present) {
        if (PixelType == u24) {
            alpha_mask_present = false;
        }
        if (!validColorMasks(PixelType, info)) {
            return ImageError.BmpInvalidColorMasks;
        }
    }

    const direction_info = BitmapDirectionInfo.new(info, image.width, image.height);
    const mask_set =
        if (standard_masks) try InlinePixelReader(PixelType, .ABGR).standard(info.alpha_mask) 
        else try InlinePixelReader(PixelType, .ABGR).fromInfo(info);

    var px_start: usize = 0;
    for (0..image.height) |i| {
        const img_start = @intCast(usize, direction_info.begin + direction_info.increment * @intCast(i32, i));
        const img_end = img_start + image.width;

        var image_row = image.pixels.?[img_start..img_end];
        var file_buffer_row = pixel_buf[px_start .. px_start + row_sz];

        // apply custom or standard rgb/rgba masks to each u16, u24 or u32 pixel in the row, store in RGBA32 image
        mask_set.extractRow(image_row, file_buffer_row, alpha_mask_present, false);

        px_start += row_sz;
    }
}

// bmps can have a form of compression, RLE, which does the simple trick of encoding repeating pixels via
// a number n (repeat ct) and pixel p in contiguous bytes. 
fn readRunLengthEncodedImage(
    comptime PixelType: type,
    pbuf: [*]const u8,
    info: *const BitmapInfo,
    color_table: *const BitmapColorTable,
    image: *Image,
) !void {
    if (color_table.length < 2) {
        return ImageError.BmpInvalidColorTable;
    }
    if (info.color_depth != rle_bit_sizes[@enumToInt(info.compression)]) {
        return ImageError.BmpInvalidCompression;
    }

    var reader = try RLEReader(PixelType).new(image.width, image.height);

    var i: usize = 0;
    const iter_max: usize = image.width * image.height;
    // the compiler is giving me garbage on the passed-in pbuf (as slice) and the only fix I found is to take a slice of
    // pbuf (as ptr) s.t. the result is exactly what pbuf should be.
    const pixel_buf = pbuf[0..info.data_size];

    while (i < iter_max) : (i += 1) {
        const action = try reader.readAction(pixel_buf);
        switch (action) {
            .ReadPixels =>      try reader.readPixels(pixel_buf, color_table, image),
            .RepeatPixels =>    try reader.repeatPixel(color_table, image),
            .Move =>            try reader.changeCoordinates(pixel_buf),
            .EndRow =>          reader.incrementRow(),
            .EndImage =>        break,
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const bmp_file_header_sz = 14;
const bmp_info_header_sz_core = 12;
const bmp_info_header_sz_v1 = 40;
const bmp_info_header_sz_v4 = 108;
const bmp_info_header_sz_v5 = 124;
const bmp_row_align = 4; // bmp pixel rows pad to 4 bytes
const bmp_rgb24_sz = 3;
// the smallest possible (hard disk) bmp has a core header, 1 bit px sz (2 colors in table), width in [1,32] and height = 1
const bmp_min_sz = bmp_file_header_sz + bmp_info_header_sz_core + 2 * bmp_rgb24_sz + bmp_row_align;

const rle_bit_sizes: [3]u32 = .{ 0, 8, 4 };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const BitmapColorTableType = enum { None, RGB24, RGB32 };

const BitmapHeaderType = enum(u32) { None, Core, V1, V4, V5 };

pub const BitmapCompression = enum(u32) { 
    RGB, RLE8, RLE4, BITFIELDS, JPEG, PNG, ALPHABITFIELDS, CMYK, CMYKRLE8, CMYKRLE4, None 
};

const BitmapReadDirection = enum(u8) { BottomUp = 0, TopDown = 1 };

pub const BitmapColorSpace = enum(u32) {
    CalibratedRGB = 0x0,
    ProfileLinked = 0x4c494e4b,
    ProfileEmbedded = 0x4d424544,
    WindowsCS = 0x57696e20,
    sRGB = 0x73524742,
    None = 0xffffffff,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const BitmapInfo = struct {
    file_sz: u32 = 0,
    // offset from beginning of file to pixel data
    data_offset: u32 = 0,
    // size of the info header (comes after the file header)
    header_sz: u32 = 0,
    header_type: BitmapHeaderType = .None,
    width: i32 = 0,
    height: i32 = 0,
    // bits per pixel
    color_depth: u32 = 0,
    compression: BitmapCompression = .None,
    // pixel data size; may not always be valid.
    data_size: u32 = 0,
    // how many colors in image. mandatory for color depths of 1,4,8. if 0, using full color depth.
    color_ct: u32 = 0,
    // masks to pull color data from pixels. only used if compression is BITFIELDS or ALPHABITFIELDS
    red_mask: u32 = 0x0,
    green_mask: u32 = 0x0,
    blue_mask: u32 = 0x0,
    alpha_mask: u32 = 0x0,
    // how the colors should be interpreted
    color_space: BitmapColorSpace = .None,
    // if using a color space profile, info about how to interpret colors
    profile_data: u32 = undefined,
    profile_size: u32 = undefined,
    // triangle representing the color space of the image
    cs_points: CieXYZTriple = undefined,
    // function f takes two parameters: 1.) gamma and 2.) a color value c in, for example, 0 to 255. It outputs
    // a color value f(gamma, c) in 0 and 255, on a concave curve. larger gamma -> more concave.
    red_gamma: u32 = undefined,
    green_gamma: u32 = undefined,
    blue_gamma: u32 = undefined,
};

pub const BitmapColorTable = struct {
    buffer: [256]graphics.RGBA32 = undefined,
    length: usize = 0,

    pub inline fn slice(self: *const BitmapColorTable) []const graphics.RGBA32 {
        return self.buffer[0..self.length];
    }
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

const BitmapDirectionInfo = struct {
    begin: i32,
    increment: i32,

    // bitmaps are stored bottom to top, meaning the top-left corner of the image is idx 0 of the last row, unless the
    // height param is negative. we always read top to bottom and write up or down depending.
    fn new(info: *const BitmapInfo, width: u32, height: u32) BitmapDirectionInfo {
        const write_direction = @intToEnum(BitmapReadDirection, @intCast(u8, @boolToInt(info.height < 0)));
        if (write_direction == .BottomUp) {
            return BitmapDirectionInfo{
                .begin = (@intCast(i32, height) - 1) * @intCast(i32, width),
                .increment = -@intCast(i32, width),
            };
        } else {
            return BitmapDirectionInfo{
                .begin = 0,
                .increment = @intCast(i32, width),
            };
        }
    }
};

