
const graphics = @import("../graphics.zig");
const std = @import("std");
const string = @import("../string.zig");
const memory = @import("../memory.zig");
const imagef = @import("image.zig");
const bench = @import("../benchmark.zig");

const LocalStringBuffer = string.LocalStringBuffer;
const RGBA32 = graphics.RGBA32;
const RGB24 = graphics.RGB24;
const print = std.debug.print;
const Image = imagef.Image;
const ImageError = imagef.ImageError;

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
// ------------------------------------------------------------------------------------------------------- pub functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn load(file: *std.fs.File, image: *Image, allocator: memory.Allocator) !void {
    var buffer: []u8 = try loadFileAndCoreHeaders(file, allocator, bmp_min_sz);
    defer allocator.free(buffer);

    try validateIdentity(buffer); 

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
    print("{}\n", .{buffer[0]});
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadFileAndCoreHeaders(file: *std.fs.File, allocator: anytype, min_sz: usize) ![]u8 {
    const stat = try file.stat();
    if (stat.size + 4 > memory.MAX_SZ) {
        return ImageError.TooLarge;
    }
    if (stat.size < min_sz) {
        return ImageError.InvalidSizeForFormat;
    }
    var buffer: []u8 = try allocator.allocExplicitAlign(u8, stat.size + 4, 4);
    for (0..bmp_file_header_sz + bmp_info_header_sz_core) |i| {
        buffer[i] = try file.reader().readByte();
    }
    return buffer;
}

fn loadRemainder(file: *std.fs.File, buffer: []u8, info: *BitmapInfo) !void {
    const cur_offset = bmp_file_header_sz + bmp_info_header_sz_core;
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

fn validateIdentity(buffer: []const u8) !void {
    const identity = buffer[0..2];
    if (!string.same(identity, "BM")) {
        // identity strings acceptable for forms of OS/2 bitmaps. microsoft shouldered-out IBM and started taking over
        // the format during windows 3.1 times.
        if (string.same(identity, "BA")
            or string.same(identity, "CI")
            or string.same(identity, "CP")
            or string.same(identity, "IC")
            or string.same(identity, "PT")
        ) {
            return ImageError.BmpFlavorUnsupported;
        }
        else {
            return ImageError.BmpInvalidBytesInFileHeader;
        }
    }
}

fn readCoreInfo(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    info.data_size = info.file_sz - info.data_offset;
    info.compression = BitmapCompression.RGB;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB24);
    return table_offset + color_table.length * @sizeOf(graphics.RGB24);
}

fn readV1Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V1;
    readV1HeaderPart(buffer, info);
    var mask_offset: usize = 0;
    if (info.compression == BitmapCompression.BITFIELDS) {
        readColorMasks(buffer, info, false);
        mask_offset = 12;
    }
    else if (info.compression == BitmapCompression.ALPHABITFIELDS) {
        readColorMasks(buffer, info, true);
        mask_offset = 16;
    }
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v1 + mask_offset;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

fn readV4Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V4;
    readV1HeaderPart(buffer, info);
    readV4HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v4;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

fn readV5Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V5;
    readV1HeaderPart(buffer, info);
    readV4HeaderPart(buffer, info);
    readV5HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v5;
    try readColorTable(buffer[table_offset..], info, color_table, graphics.RGB32);
    return table_offset + color_table.length * @sizeOf(graphics.RGB32);
}

inline fn readV1HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[28..30]));
    info.compression = @intToEnum(BitmapCompression, std.mem.readIntNative(u32, buffer[30..34]));
    info.data_size = std.mem.readIntNative(u32, buffer[34..38]);
    info.color_ct = std.mem.readIntNative(u32, buffer[46..50]);
}

fn readV4HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    readColorMasks(buffer, info, true);
    info.color_space = @intToEnum(BitmapColorSpace, std.mem.readIntNative(u32, buffer[70..74]));
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
    buffer: []const u8, info: *const BitmapInfo, color_table: *BitmapColorTable, comptime ColorType: type
) !void {
    var data_casted = @ptrCast([*]const ColorType, @alignCast(@alignOf(ColorType), &buffer[0]));

    switch (info.color_depth) {
        32, 24, 16 => {
            if (info.color_ct > 0) {
                // (nowadays typical) large color depths might have a color table in order to support 256 bit
                // video adapters. currently this function will retrieve the table, but it goes unused.
                if (info.color_ct >= 2 and info.color_ct <= 256) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                color_table.length = 0;
                return;
            }
        },
        8 => {
            if (info.color_ct > 0) {
                if (info.color_ct >= 2 and info.color_ct <= 256) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                color_table.length = 256;
            }
        },
        4 => {
            if (info.color_ct > 0) {
                if (info.color_ct >= 2 and info.color_ct <= 16) {
                    color_table.length = info.color_ct;
                }
                else {
                    return ImageError.BmpInvalidColorCount;
                }
            }
            else {
                color_table.length = 16;
            }
        },
        1 => {
            if (info.color_ct == 0 or info.color_ct == 2) {
                color_table.length = 2;
            }
            else {
                return ImageError.BmpInvalidColorCount;
            }
        },
        else => return ImageError.BmpInvalidColorDepth,
    }

    if (buffer.len <= color_table.length * @sizeOf(ColorType)) {
        return ImageError.UnexpectedEOF;
    }
    else {
        for (0.. color_table.length) |i| {
            const table_color: *RGBA32 = &color_table.buffer[i];
            const buffer_color: *const ColorType = &data_casted[i];
            // bgr to rgb
            table_color.a = 255;
            table_color.b = buffer_color.r;
            table_color.g = buffer_color.g;
            table_color.r = buffer_color.b;
        }
    }
}

inline fn colorSpaceSupported(info: *const BitmapInfo) bool {
    return switch(info.color_space) {
        // calibration information is unused because it doesn't make sense to calibrate individual textures in a game engine
        .CalibratedRGB => true, 
        // I see no reason to support profiles. Seems like a local / printing thing
        .ProfileLinked => false,
        .ProfileEmbedded => false,
        .WindowsCS => true,
        .sRGB => true,
        .None => true,
    };
}

inline fn compressionSupported(info: *const BitmapInfo) bool {
    return switch(info.compression) {
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

fn createImage(
    buffer: []const u8, 
    image: *Image, 
    info: *const BitmapInfo, 
    color_table: *const BitmapColorTable, 
    allocator: memory.Allocator
) !void {
    image.width = @intCast(u32, try std.math.absInt(info.width));
    image.height = @intCast(u32, try std.math.absInt(info.height));
    image.allocator = allocator;

    // get row length in bytes as a multiple of 4 (rows are padded to 4 byte increments)
    const row_length = ((image.width * info.color_depth + 31) & ~@as(u32, 31)) >> 3;    
    const pixel_buf = buffer[info.data_offset..buffer.len];

    image.pixels = try image.allocator.?.alloc(graphics.RGBA32, image.width * image.height);
    errdefer image.clear();

    try switch(info.compression) {
        .RGB => switch(info.color_depth) {
            1 => try readColorTableImage(u1, pixel_buf, info, color_table, image, row_length),
            4 => try readColorTableImage(u4, pixel_buf, info, color_table, image, row_length),
            8 => try readColorTableImage(u8, pixel_buf, info, color_table, image, row_length),
            16 => try readInlinePixelImage(u16, pixel_buf, info, image, row_length, true),
            24 => try readInlinePixelImage(u24, pixel_buf, info, image, row_length, true),
            32 => try readInlinePixelImage(u32, pixel_buf, info, image, row_length, true),
            else => ImageError.BmpInvalidColorDepth,
        },
        .RLE8 => {
            if (info.color_depth != 8) {
                return ImageError.BmpInvalidCompression;
            }
            if (color_table.length < 2) {
                return ImageError.BmpInvalidColorTable;
            }
            try readRunLengthEncodedImage(@ptrCast([*]const u8, &pixel_buf[0]), info, color_table, image, row_length);
        },
        .RLE4 => {
            if (info.color_depth != 4) {
                return ImageError.BmpInvalidCompression;
            }
            if (color_table.length < 2) {
                return ImageError.BmpInvalidColorTable;
            }
            return ImageError.BmpCompressionUnsupported;
            // try readRunLengthEncodedImage(u4, pixel_buf, info, color_table, image, row_length);
        },
        .BITFIELDS, .ALPHABITFIELDS => switch(info.color_depth) {
            16 => try readInlinePixelImage(u16, pixel_buf, info, image, row_length, false),
            24 => try readInlinePixelImage(u24, pixel_buf, info, image, row_length, false),
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

    const byte_iter_ct = switch(PixelType) {
        u1 => image.width >> 3,
        u4 => image.width >> 1,
        u8 => 1,
        else => unreachable,
    };
    const indices_per_byte = switch(PixelType) {
        u1 => 8,
        u4 => 2,
        u8 => 1,
        else => unreachable,
    };
    const row_remainder = image.width - byte_iter_ct * indices_per_byte;

    const colors = color_table.slice();
    var px_row_start: usize = 0;
   
    for (0..image.height) |i| {
        const row_start = @intCast(usize, direction_info.begin + direction_info.increment * @intCast(i32, i));
        const row_end = row_start + image.width;

        var index_row = pixel_buf[px_row_start..px_row_start + row_sz];
        var image_row = image.pixels.?[row_start..row_end];

        // over each pixel (index to the color table) in the buffer row...
        switch(PixelType) {
            u1 => {
                var img_idx: usize = 0;
                for (0..byte_iter_ct) |byte| {
                    const idx_byte = index_row[byte];
                    // mask each bit in the byte and get the index to the 2-color table
                    inline for (0..8) |j| {
                        const mask: comptime_int = @as(u8, 0x80) >> @intCast(u3, j);
                        const col_idx: u8 = (idx_byte & mask) >> @intCast(u3, 7-j);
                        if (col_idx >= colors.len) {
                            return ImageError.BmpInvalidColorTableIndex;
                        }
                        image_row[img_idx+j] = colors[col_idx];
                    }
                    img_idx += 8;
                }
                // if there are 1-7 indices left at the end, get the remaining colors
                if (row_remainder > 0) {
                    const idx_byte = index_row[byte_iter_ct];
                    for (0..row_remainder) |j| {
                        const mask = @as(u8, 0x80) >> @intCast(u3, j);
                        const col_idx: u8 = (idx_byte & mask) >> @intCast(u3, 7-j);
                        if (col_idx >= colors.len) {
                            return ImageError.BmpInvalidColorTableIndex;
                        }
                        image_row[img_idx+j] = colors[col_idx];
                    }
                }
            },
            u4 => {
                var img_idx: usize = 0;
                for (0..byte_iter_ct) |byte| {
                    // mask each 4bit index (0 to 15) in the byte and get the color table entry
                    inline for(0..2) |j| {
                        const mask: comptime_int = @as(u8, 0xf0) >> (j*4);
                        const col_idx: u8 = (index_row[byte] & mask) >> (4-(j*4));
                        if (col_idx >= colors.len) {
                            return ImageError.BmpInvalidColorTableIndex;
                        }
                        image_row[img_idx+j] = colors[col_idx];
                    }
                    img_idx += 2;
                }
                // if there is a single remaining index, get the remaining color
                if (row_remainder > 0) {
                    const col_idx: u8 = (index_row[byte_iter_ct] & @as(u8, 0xf0)) >> 4;
                    if (col_idx >= colors.len) {
                        return ImageError.BmpInvalidColorTableIndex;
                    }
                    image_row[img_idx] = colors[col_idx];
                }
            },
            u8 => {
                // each byte is an index to the color table
                for (0..image.width) |img_idx| {
                    const col_idx: u8 = index_row[img_idx];
                    if (col_idx >= colors.len) {
                        return ImageError.BmpInvalidColorTableIndex;
                    }
                    image_row[img_idx] = colors[col_idx];
                }
            },
            else => unreachable,
        }
        px_row_start += row_sz;
    }
}

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

fn readInlinePixelImage(
    comptime PixelType: type,
    pixel_buf: []const u8,
    info: *const BitmapInfo,
    image: *Image,
    row_sz: usize,
    standard_masks: bool
) !void {
    const alpha_mask_present = info.compression == .ALPHABITFIELDS or info.alpha_mask > 0;

    if (!bufferLongEnough(pixel_buf, image, row_sz)) {
        return ImageError.UnexpectedEOF;
    }
    if (!standard_masks or alpha_mask_present) {
        if (PixelType == u24) {
            return ImageError.Bmp24BitCustomMasksUnsupported;
        }
        if (!validColorMasks(PixelType, info)) {
            return ImageError.BmpInvalidColorMasks;
        }
    }

    const direction_info = BitmapDirectionInfo.new(info, image.width, image.height);
    const mask_set = 
        if (standard_masks) try BitmapColorMaskSet(PixelType).standard(info)
        else try BitmapColorMaskSet(PixelType).fromInfo(info);

    var px_start: usize = 0;

    for (0..image.height) |i| {
        const img_start = @intCast(usize, direction_info.begin + direction_info.increment * @intCast(i32, i));
        const img_end = img_start + image.width;

        var image_row = image.pixels.?[img_start..img_end];
        var file_buffer_row = pixel_buf[px_start..px_start + row_sz];

        // apply custom or standard rgb/rgba masks to each u16, u24 or u32 pixel in the row, store in RGBA32 image
        mask_set.extractRow(image_row, file_buffer_row, alpha_mask_present);

        px_start += row_sz;
    }
}

noinline fn readRunLengthEncodedImage(
    pbuf: [*]const u8,
    info: *const BitmapInfo,
    color_table: *const BitmapColorTable,
    image: *Image,
    row_sz: usize
) !void {
    var reader = try RLEReader.new(info, image.width, image.height, @intCast(u32, row_sz));

    var i: usize = 0;
    const iter_max: usize = image.width * image.height;
    const pixel_buf = pbuf[0..row_sz * image.height]; // this is a hack because the compiler is giving me garbage

    while (i < iter_max) : (i += 1) {
        const action = try reader.readAction(pixel_buf);
        switch(action) {
            .ReadPixels => {
                try reader.readPixels(pixel_buf, color_table, image);
            },
            .RepeatPixels => {
                try reader.repeatPixel(color_table, image);
            },
            .Move => {
                try reader.moveImagePosition(pixel_buf);
            },
            .EndRow => {
                try reader.incrementRow();
            },
            .EndImage => {
                break;
            },
        }
        if (reader.img_col > image.width) {
            print("hey, listen\n", .{});
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
// the smallest possible (hard disk) bmp has a core header, 1 bit px / 2 colors in table, width in [1,32] and height = 1
const bmp_min_sz = bmp_file_header_sz + bmp_info_header_sz_core + 2 * bmp_rgb24_sz + bmp_row_align;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const BitmapColorTableType = enum { None, RGB24, RGB32 };

const BitmapHeaderType = enum(u32) { None, Core, V1, V4, V5 };

const BitmapCompression = enum(u32) { 
    RGB, RLE8, RLE4, BITFIELDS, JPEG, PNG, ALPHABITFIELDS, CMYK, CMYKRLE8, CMYKRLE4, None 
};

const BitmapReadDirection = enum(u8) { BottomUp=0, TopDown=1 };

const BitmapColorSpace = enum(u32) {
    CalibratedRGB = 0x0,
    ProfileLinked = 0x4c494e4b,
    ProfileEmbedded = 0x4d424544,
    WindowsCS = 0x57696e20,
    sRGB = 0x73524742,
    None = 0xffffffff,
};

const RLEAction = enum {
    EndRow,
    EndImage,
    Move,
    ReadPixels,
    RepeatPixels
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const BitmapColorTable = struct {
    buffer: [256]graphics.RGBA32 = undefined,
    length: usize = 0,

    pub inline fn slice(self: *const BitmapColorTable) []const graphics.RGBA32 {
        return self.buffer[0..self.length];
    }
};

const RLEReader = struct {
    img_col: u32 = 0,
    img_row_pos: u32 = 0,
    img_width: u32 = 0,
    img_height: u32 = 0,
    img_max: u32 = 0,
    byte_pos: u32 = 0,
    byte_row_inc: i32 = 0,
    buffer_max: u32 = 0,
    action_bytes: [2]u8 = undefined,

    pub fn new(info: *const BitmapInfo, image_width: u32, image_height: u32, row_sz: u32) !RLEReader {
        const write_direction = @intToEnum(BitmapReadDirection, @intCast(u8, @boolToInt(info.height < 0)));
        const byte_pos_signed = (@intCast(i32, image_height) - 1) * @intCast(i32, row_sz);
        if (byte_pos_signed < 0) {
            return ImageError.BmpInvalidRLEData;
        }
        if (write_direction == .BottomUp) {
            return RLEReader{
                .img_width=image_width, 
                .img_height=image_height, 
                .img_max=image_width * image_height,
                .byte_pos=@intCast(u32, byte_pos_signed),
                .byte_row_inc=-@intCast(i32, row_sz),
                .buffer_max=row_sz * image_height,
            };
        }
        else {
            return RLEReader{
                .img_width=image_width, 
                .img_height=image_height, 
                .img_max=image_width * image_height,
                .byte_pos=0,
                .byte_row_inc=@intCast(i32, row_sz),
                .buffer_max=row_sz * image_height
            };
        }
    }

    pub fn readAction(self: *RLEReader, buffer: []const u8) !RLEAction {
        if (self.byte_pos + 1 >= buffer.len) {
            return ImageError.UnexpectedEOF;
        }
        self.action_bytes[0] = buffer[self.byte_pos];
        self.action_bytes[1] = buffer[self.byte_pos+1];

        if (self.action_bytes[0] > 0) {
            return RLEAction.RepeatPixels;
        }
        else if (self.action_bytes[1] == 0) {
            return RLEAction.EndRow;
        }
        else if (self.action_bytes[1] == 1) {
            return RLEAction.EndImage;
        }
        else if (self.action_bytes[1] == 2) {
            return RLEAction.Move;
        }
        else {
            return RLEAction.ReadPixels;
        }

        self.byte_pos += 2;
    }

    pub fn repeatPixel(self: *RLEReader, color_table: *const BitmapColorTable, image: *Image) !void {
        const repeat_ct = self.action_bytes[0];
        const color_idx = self.action_bytes[1];
        const col_write_end = self.img_col + repeat_ct;

        if (color_idx >= color_table.length) {
            return ImageError.BmpInvalidColorTableIndex;
        }
        if (self.img_row_pos + col_write_end > image.pixels.?.len) {
            return ImageError.UnexpectedEOF;
        }

        const color = color_table.buffer[color_idx];
        while (self.img_col < col_write_end) : (self.img_col += 1) {
            image.pixels.?[self.imageIndex()] = color;
        }

        // ?
        while (self.img_col > self.img_width) : (self.img_col -= self.img_width) {
            self.img_row_pos += self.img_width;
        }
    }

    pub fn readPixels(
        self: *RLEReader, buffer: []const u8, color_table: *const BitmapColorTable, image: *Image
    ) !void {
        const read_ct = self.action_bytes[1];
        const byte_read_end = self.byte_pos + read_ct; 
        const col_write_end = self.img_col + read_ct;

        if (byte_read_end >= self.buffer_max) {
            return ImageError.UnexpectedEOF;
        }
        if (self.img_row_pos + col_write_end > image.pixels.?.len) {
            return ImageError.UnexpectedEOF;
        }

        while (self.img_col < col_write_end) : (self.img_col += 1) {
            const color_idx = buffer[self.byte_pos];
            if (color_idx >= color_table.length) {
                return ImageError.BmpInvalidColorTableIndex;
            }
            image.pixels.?[self.imageIndex()] = color_table.buffer[color_idx];
            self.byte_pos += 1;
        }

        if ((read_ct >> @as(u3, 1)) * 2 != read_ct) {
            self.byte_pos += 1;
        }
        
        // ?
        while (self.img_col > self.img_width) : (self.img_col -= self.img_width) {
            self.img_row_pos += self.img_width;
        }
    }

    pub inline fn imageIndex(self: *const RLEReader) u32 {
        return self.img_row_pos + self.img_col;
    }

    pub fn moveImagePosition(self: *RLEReader, buffer: []const u8) !void {
        if (self.byte_pos + 1 >= self.buffer_max) {
            return ImageError.UnexpectedEOF;
        }
        const dx = buffer[self.byte_pos];
        const dy = buffer[self.byte_pos + 1];
        self.byte_pos += 2;

        self.img_col += dx;
        self.img_row_pos = (self.img_row_pos / self.img_width + dy) * self.img_width;
    }

    pub fn incrementRow(self: *RLEReader) !void {
        self.img_col = 0;
        self.img_row_pos += self.img_width;

        const align_4byte_check = (self.byte_pos >> @as(u6, 2)) * 4;
        if (align_4byte_check != self.byte_pos) {
            self.byte_pos += 4 - (self.byte_pos - align_4byte_check);
        }

        const new_byte_pos_signed = @intCast(i32, self.byte_pos) + self.byte_row_inc;
        if (new_byte_pos_signed < 0) {
            return ImageError.BmpInvalidRLEData;
        }
        self.byte_pos = @intCast(u32, new_byte_pos_signed);
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
    inline fn new(info: *const BitmapInfo, width: u32, height: u32) BitmapDirectionInfo {
        const write_direction = @intToEnum(BitmapReadDirection, @intCast(u8, @boolToInt(info.height < 0)));
        if (write_direction == .BottomUp) {
            return BitmapDirectionInfo {
                .begin = (@intCast(i32, height) - 1) * @intCast(i32, width),
                .increment = -@intCast(i32, width),
            };
        }
        else {
            return BitmapDirectionInfo {
                .begin = 0,
                .increment = @intCast(i32, width),
            };
        }
    }
};

fn BitmapColorMask(comptime IntType: type) type {

    const ShiftType = switch(IntType) {
        u16 => u4,
        u24 => u5,
        u32 => u5,
        else => undefined
    };

    return struct {
        const MaskType = @This();

        mask: IntType = 0,
        rshift: ShiftType = 0,
        lshift: ShiftType = 0,

        fn new(in_mask: u32) !MaskType {
            const type_bit_sz = @sizeOf(IntType) * 8;
            const target_leading_zero_ct = type_bit_sz - 8;
            const shr: i32 = @as(i32, target_leading_zero_ct) - @intCast(i32, @clz(@intCast(IntType, in_mask)));
            if (shr > 0) {
                return MaskType{ .mask=@intCast(IntType, in_mask), .rshift=@intCast(ShiftType, shr) };
            }
            else {
                return MaskType{ .mask=@intCast(IntType, in_mask), .lshift=@intCast(ShiftType, try std.math.absInt(shr)) };
            }
        }

        inline fn extractColor(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, ((pixel & self.mask) >> self.rshift) << self.lshift);
        }
    };
}

fn BitmapColorMaskSet(comptime IntType: type) type {

    return struct {
        const SetType = @This();

        r_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        g_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        b_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        a_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},

        inline fn standard(info: *const BitmapInfo) !SetType {
            return SetType {
                .r_mask=switch(IntType) {
                    u16 => try BitmapColorMask(IntType).new(0x7c00),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x00ff0000),
                    else => unreachable,
                },
                .g_mask=switch(IntType) {
                    u16 => try BitmapColorMask(IntType).new(0x03e0),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x0000ff00),
                    else => unreachable,
                },
                .b_mask=switch(IntType) {
                    u16 => try BitmapColorMask(IntType).new(0x001f),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x000000ff),
                    else => unreachable,
                },
                .a_mask=switch(IntType) {
                    u16 => try BitmapColorMask(IntType).new(info.alpha_mask),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(info.alpha_mask),
                    else => unreachable,
                },
            };
        }

        inline fn fromInfo(info: *const BitmapInfo) !SetType {
            return SetType{
                .r_mask=try BitmapColorMask(IntType).new(info.red_mask),
                .b_mask=try BitmapColorMask(IntType).new(info.blue_mask),
                .g_mask=try BitmapColorMask(IntType).new(info.green_mask),
                .a_mask=try BitmapColorMask(IntType).new(info.alpha_mask),
            };
        }

        inline fn extractRGBA(self: *const SetType, pixel: IntType) RGBA32 {
            return RGBA32 {
                .r=self.r_mask.extractColor(pixel),
                .g=self.g_mask.extractColor(pixel),
                .b=self.b_mask.extractColor(pixel),
                .a=self.a_mask.extractColor(pixel)
            };
        }

        inline fn extractRGB(self: *const SetType, pixel: IntType) RGBA32 {
            return RGBA32 {
                .r=self.r_mask.extractColor(pixel),
                .g=self.g_mask.extractColor(pixel),
                .b=self.b_mask.extractColor(pixel),
                .a=255
            };
        }

        inline fn extractRow(self: *const SetType, image_row: []RGBA32, pixel_row: []const u8, mask_alpha: bool) void {
            if (mask_alpha) {
                self.extractRowRGBA(image_row, pixel_row);
            }
            else {
                self.extractRowRGB(image_row, pixel_row);
            }
        }

        inline fn extractRowRGB(self: *const SetType, image_row: []RGBA32, pixel_row: []const u8) void {
            switch(IntType) {
                u16, u32 => {
                    var pixels = @ptrCast([*]const IntType, @alignCast(@alignOf(IntType), &pixel_row[0]))[0..image_row.len];
                    for (0..image_row.len) |j| {
                        image_row[j] = self.extractRGB(pixels[j]);
                    }
                },
                u24 => {
                    var byte: usize = 0;
                    for (0..image_row.len) |j| {
                        const image_pixel: *RGBA32 = &image_row[j];
                        image_pixel.a = 255;
                        image_pixel.b = pixel_row[byte];
                        image_pixel.g = pixel_row[byte+1];
                        image_pixel.r = pixel_row[byte+2];
                        byte += 3;
                    }
                },
                else => unreachable,
            }
        }

        inline fn extractRowRGBA(self: *const SetType, image_row: []RGBA32, pixel_row: []const u8) void {
            var pixels = @ptrCast([*]const IntType, @alignCast(@alignOf(IntType), &pixel_row[0]))[0..image_row.len];
            for (0..image_row.len) |j| {
                image_row[j] = self.extractRGBA(pixels[j]);
            }
        }
    };
}

const BitmapInfo = extern struct {
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
