// ::::::::::: For loading two-dimensional images from disk, into a basic standardized format.
// :: Image ::
// :::::::::::

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- load
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// load an image from disk. format is optionally inferrable via the file extension.
// !! Warning !! calling this function may require up to 1.5KB free stack memory.
// !! Warning !! some OS/2 BMPs are compatible, except their width and height entries are interpreted as signed integers
// (rather than the OS/2 standard for core headers, unsigned), which may lead to a failed read or row-inverted image.
pub fn loadImage(file_path: []const u8, format: ImageFormat, allocator: kMem.Allocator) !Image {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    if (format == ImageFormat.Infer) {
        var extension_idx: ?usize = str.findR(file_path, '.');
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

        if (str.same(extension_lower, "bmp") or str.same(extension_lower, "dib")) {
            return try loadBmp(&file, allocator);
        }
        else if (str.same(extension_lower, "jpg") or str.same(extension_lower, "jpeg")) {
            return try loadJpg(&file, allocator);
        }
        else if (str.same(extension_lower, "png")) {
            return try loadPng(&file, allocator);
        }
        else {
            return ImageError.InvalidFileExtension;
        }
    }
    else return switch (format) {
        .Bmp => try loadBmp(&file, allocator),
        .Jpg => try loadJpg(&file, allocator),
        .Png => try loadPng(&file, allocator),
        else => unreachable,
    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------- load by encoding
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn loadBmp(file: *std.fs.File, allocator: kMem.Allocator) !Image {
    var buffer: []u8 = try bmpLoadFileAndCoreHeaders(file, allocator, bmp_min_sz);
    // var buffer: []u8 = try loadImageFromDisk(file, allocator, bmp_min_sz);
    defer allocator.free(buffer);

    const identity = buffer[0..2];
    try bmpValidateIdentity(identity); 

    var info = BitmapInfo{};
    if (!bmpReadInitial(buffer, &info)) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }

    if (buffer.len <= info.header_sz + bmp_file_header_sz or buffer.len <= info.data_offset) {
        return ImageError.UnexpectedEOF;
    }

    try bmpLoadFileRemainder(file, buffer, &info);

    var color_table = BitmapColorTable{};
    var buffer_pos: usize = undefined;
    switch (info.header_sz) {
        bmp_info_header_sz_core => buffer_pos = try bmpGetCoreInfo(buffer, &info, &color_table),
        bmp_info_header_sz_v1 => buffer_pos = try bmpGetV1Info(buffer, &info, &color_table),
        bmp_info_header_sz_v4 => buffer_pos = try bmpGetV4Info(buffer, &info, &color_table),
        bmp_info_header_sz_v5 => buffer_pos = try bmpGetV5Info(buffer, &info, &color_table),
        else => return ImageError.BmpInvalidHeaderSizeOrVersionUnsupported, 
    }

    if (!bmpColorSpaceSupported(&info)) {
        return ImageError.BmpColorSpaceUnsupported;
    }

    if (!bmpCompressionSupported(&info)) {
        return ImageError.BmpCompressionUnsupported;
    }

    var image = Image{
        .width=@intCast(u32, try std.math.absInt(info.width)), 
        .height=@intCast(u32, try std.math.absInt(info.height)), 
        .allocator=allocator
    };
    try bmpCreateImage(buffer, &image, &info, &color_table);

    return image;
}

pub fn loadJpg(file: *std.fs.File, enclave: kMem.Allocator) !Image {
    _ = file;
    _ = enclave;
    print("loading jpg\n", .{});
    return Image{};
}

pub fn loadPng(file: *std.fs.File, enclave: kMem.Allocator) !Image {
    _ = file;
    _ = enclave;
    print("loading png\n", .{});
    return Image{};
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------- load helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadImageFromDisk(file: *std.fs.File, allocator: anytype, min_sz: usize) ![]u8 {
    const stat = try file.stat();
    if (stat.size > kMem.MAX_SZ) {
        return ImageError.TooLarge;
    }

    if (stat.size < min_sz) {
        return ImageError.InvalidSizeForFormat;
    }

    var buffer: []u8 = try allocator.allocExplicitAlign(u8, stat.size, 4);
    const bytes_read: usize = try file.reader().readAll(buffer);

    if (bytes_read != stat.size) {
        // the reader reached the end of the file before reading all of the file's bytes according to file.stat()
        return ImageError.PartialRead;
    }

    return buffer;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------ bitmap helpers
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn bmpLoadFileAndCoreHeaders(file: *std.fs.File, allocator: anytype, min_sz: usize) ![]u8 {
    const stat = try file.stat();
    if (stat.size + 4 > kMem.MAX_SZ) {
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

fn bmpLoadFileRemainder(file: *std.fs.File, buffer: []u8, info: *BitmapInfo) !void {
    const cur_offset = bmp_file_header_sz + bmp_info_header_sz_core;

    for (cur_offset..info.data_offset) |i| {
        buffer[i] = try file.reader().readByte();
    }

    // aligning data to a 4 byte boundary (requirement)
    const offset_mod_4 = info.data_offset % 4;
    const offset_mod_4_neq_0 = @intCast(u32, @boolToInt(offset_mod_4 != 0));
    info.data_offset = info.data_offset + offset_mod_4_neq_0 * (4 - offset_mod_4);
    var data_buf: []u8 = buffer[info.data_offset..];

    _ = try file.reader().read(data_buf);
}

inline fn bmpReadInitial(buffer: []const u8, info: *BitmapInfo) bool {
    // OG file header
    info.file_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return false;
    }
    info.data_offset = std.mem.readIntNative(u32, buffer[10..14]);
    // begin info headers
    info.header_sz = std.mem.readIntNative(u32, buffer[14..18]);
    return true;
}


fn bmpValidateIdentity(identity: []const u8) !void {
    if (!str.same(identity, "BM")) {
        // identity strings acceptable for forms of OS/2 bitmaps. microsoft shouldered-out IBM and started taking over
        // the format during windows 3.1 times.
        if (str.same(identity, "BA")
            or str.same(identity, "CI")
            or str.same(identity, "CP")
            or str.same(identity, "IC")
            or str.same(identity, "PT")
        ) {
            return ImageError.BmpFlavorUnsupported;
        }
        else {
            return ImageError.BmpInvalidBytesInFileHeader;
        }
    }
}

fn bmpGetCoreInfo(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    info.data_size = info.file_sz - info.data_offset;
    info.compression = BitmapCompression.RGB;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB24);
    return table_offset + color_table.length * @sizeOf(gfx.RGB24);
}

fn bmpGetV1Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V1;
    bmpFillV1HeaderPart(buffer, info);
    var mask_offset: usize = 0;
    if (info.compression == BitmapCompression.BITFIELDS) {
        bmpGetColorMasks(buffer, info, false);
        mask_offset = 12;
    }
    else if (info.compression == BitmapCompression.ALPHABITFIELDS) {
        bmpGetColorMasks(buffer, info, true);
        mask_offset = 16;
    }
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v1 + mask_offset;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB32);
    return table_offset + color_table.length * @sizeOf(gfx.RGB32);
}

fn bmpGetV4Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V4;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v4;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB32);
    return table_offset + color_table.length * @sizeOf(gfx.RGB32);
}

fn bmpGetV5Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V5;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    bmpFillV5HeaderPart(buffer, info);
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v5;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB32);
    return table_offset + color_table.length * @sizeOf(gfx.RGB32);
}

inline fn bmpFillV1HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.width = std.mem.readIntNative(i32, buffer[18..22]);
    info.height = std.mem.readIntNative(i32, buffer[22..26]);
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[28..30]));
    info.compression = @intToEnum(BitmapCompression, std.mem.readIntNative(u32, buffer[30..34]));
    info.data_size = std.mem.readIntNative(u32, buffer[34..38]);
    info.color_ct = std.mem.readIntNative(u32, buffer[46..50]);
}

fn bmpFillV4HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    bmpGetColorMasks(buffer, info, true);
    info.color_space = @intToEnum(BitmapColorSpace, std.mem.readIntNative(u32, buffer[70..74]));
    if (info.color_space == BitmapColorSpace.sRGB or info.color_space == BitmapColorSpace.WindowsCS) {
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

inline fn bmpFillV5HeaderPart(buffer: []u8, info: *BitmapInfo) void {
    info.profile_data = std.mem.readIntNative(u32, buffer[126..130]);
    info.profile_size = std.mem.readIntNative(u32, buffer[130..134]);
}

inline fn bmpGetColorMasks(buffer: []u8, info: *BitmapInfo, alpha: bool) void {
    info.red_mask = std.mem.readIntNative(u32, buffer[54..58]);
    info.green_mask = std.mem.readIntNative(u32, buffer[58..62]);
    info.blue_mask = std.mem.readIntNative(u32, buffer[62..66]);
    if (alpha) {
        info.alpha_mask = std.mem.readIntNative(u32, buffer[66..70]);
    }
}

fn bmpGetColorTable(
    buffer: []u8, info: *const BitmapInfo, color_table: *BitmapColorTable, comptime ColorType: type
) !void {
    var data_casted = @ptrCast([*]ColorType, @alignCast(@alignOf(ColorType), &buffer[0]));

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
            // convert format's bgr to standard rgb
            table_color.a = 255;
            table_color.b = buffer_color.r;
            table_color.g = buffer_color.g;
            table_color.r = buffer_color.b;
        }
    }
}

inline fn bmpColorSpaceSupported(info: *const BitmapInfo) bool {
    return switch(info.color_space) {
        .CalibratedRGB => false,
        .ProfileLinked => false,
        .ProfileEmbedded => false,
        .WindowsCS => true,
        .sRGB => true,
        .None => true,
    };
}

inline fn bmpCompressionSupported(info: *const BitmapInfo) bool {
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

inline fn bmpBufferLongEnough(pixel_buf: []const u8, image: *const Image, row_length: usize) bool {
    return pixel_buf.len >= row_length * image.height;
}

fn bmpCreateImage(
    buffer: []const u8, image: *Image, info: *const BitmapInfo, color_table: *const BitmapColorTable
) !void {
    // get row length in bytes as a multiple of 4 (rows are padded to 4 byte increments)
    const row_length = ((image.width * info.color_depth + 31) & ~@as(u32, 31)) >> 3;    
    const pixel_buf = buffer[info.data_offset..];

    image.pixels = try image.allocator.?.alloc(gfx.RGBA32, image.width * image.height);
    errdefer image.clear();

    try switch(info.compression) {
        .RGB => switch(info.color_depth) {
            1 => try bmpLoadColorTableImage(u1, pixel_buf, info, color_table, image, row_length),
            4 => try bmpLoadColorTableImage(u4, pixel_buf, info, color_table, image, row_length),
            8 => try bmpLoadColorTableImage(u8, pixel_buf, info, color_table, image, row_length),
            16 => try bmpLoadInlinePixelImage(u16, pixel_buf, info, image, row_length, true),
            24 => try bmpLoadInlinePixelImage(u24, pixel_buf, info, image, row_length, true),
            32 => try bmpLoadInlinePixelImage(u32, pixel_buf, info, image, row_length, true),
            else => ImageError.BmpInvalidColorDepth,
        },
        .RLE8 => {
            if (info.color_depth != 8) {
                return ImageError.BmpInvalidCompression;
            }
            return ImageError.BmpCompressionUnsupported;
        },
        .RLE4 => {
            if (info.color_depth != 4) {
                return ImageError.BmpInvalidCompression;
            }
            return ImageError.BmpCompressionUnsupported;
        },
        .BITFIELDS, .ALPHABITFIELDS => switch(info.color_depth) {
            16 => try bmpLoadInlinePixelImage(u16, pixel_buf, info, image, row_length, false),
            24 => try bmpLoadInlinePixelImage(u24, pixel_buf, info, image, row_length, false),
            32 => try bmpLoadInlinePixelImage(u32, pixel_buf, info, image, row_length, false),
            else => return ImageError.BmpInvalidCompression,
        },
        else => return ImageError.BmpCompressionUnsupported,
    };
}

// bitmaps are stored bottom to top, meaning the top-left corner of the image is idx 0 of the last row, unless the
// height param is negative. we always read top to bottom and write up or down depending.
inline fn bmpInitWrite(info: *const BitmapInfo, image: *const Image) BmpWriteInfo {
    const write_direction = @intToEnum(BitmapReadDirection, @intCast(u8, @boolToInt(info.height < 0)));
    if (write_direction == .BottomUp) {
        return BmpWriteInfo {
            .begin = (@intCast(i32, image.height) - 1) * @intCast(i32, image.width),
            .increment = -@intCast(i32, image.width),
        };
    }
    else {
        return BmpWriteInfo {
            .begin = 0,
            .increment = @intCast(i32, image.width),
        };
    }
}

fn bmpLoadColorTableImage(
    comptime PixelType: type, 
    pixel_buf: []const u8, 
    info: *const BitmapInfo,
    color_table: *const BitmapColorTable, 
    image: *Image, 
    row_len_bytes: usize
) !void {
    if (color_table.length < 2) {
        return ImageError.BmpInvalidColorTable;
    }
    if (!bmpBufferLongEnough(pixel_buf, image, row_len_bytes)) {
        return ImageError.UnexpectedEOF;
    }
    
    const write_info = bmpInitWrite(info, image);

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
        const row_start = @intCast(usize, write_info.begin + write_info.increment * @intCast(i32, i));
        const row_end = row_start + image.width;

        // 'pixels' in a color table-based image are indices to the color table
        var index_row = pixel_buf[px_row_start..px_row_start + row_len_bytes];
        var image_row = image.pixels.?[row_start..row_end];

        switch(PixelType) {
            u1 => {
                var img_idx: usize = 0;
                for (0..byte_iter_ct) |byte| {
                    const idx_byte = index_row[byte];
                    inline for (0..8) |j| {
                        const col_idx: u8 = (idx_byte & (@as(u8, 0x80) >> @intCast(u3, j))) >> @intCast(u3, 7-j);
                        if (col_idx >= colors.len) {
                            return ImageError.BmpInvalidColorTableIndex;
                        }
                        image_row[img_idx+j] = colors[col_idx];
                    }
                    img_idx += 8;
                }
                if (row_remainder > 0) {
                    const idx_byte = index_row[byte_iter_ct];
                    for (0..row_remainder) |j| {
                        const col_idx: u8 = (idx_byte & (@as(u8, 0x80) >> @intCast(u3, j))) >> @intCast(u3, 7-j);
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
                    inline for(0..2) |j| {
                        const col_idx: u8 = (index_row[byte] & (@as(u8, 0xf0) >> (j*4))) >> (4-(j*4));
                        if (col_idx >= colors.len) {
                            return ImageError.BmpInvalidColorTableIndex;
                        }
                        image_row[img_idx+j] = colors[col_idx];
                    }
                    img_idx += 2;
                }
                if (row_remainder > 0) {
                    const col_idx: u8 = (index_row[byte_iter_ct] & @as(u8, 0xf0)) >> 4;
                    if (col_idx >= colors.len) {
                        return ImageError.BmpInvalidColorTableIndex;
                    }
                    image_row[img_idx] = colors[col_idx];
                }
            },
            u8 => {
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
        px_row_start += row_len_bytes;
    }
}

fn bmpLoadInlinePixelImage(
    comptime PixelType: type,
    pixel_buf: []const u8,
    info: *const BitmapInfo,
    image: *Image,
    row_len_bytes: usize,
    standard_masks: bool
) !void {
    if (!bmpBufferLongEnough(pixel_buf, image, row_len_bytes)) {
        return ImageError.UnexpectedEOF;
    }

    const mask = if (standard_masks) BitmapColorMask(PixelType){} else BitmapColorMask(PixelType).fromInfo(info);

    const write_info = bmpInitWrite(info, image);

    var px_row_start: usize = 0;
    for (0..image.height) |i| {
        const row_start = @intCast(usize, write_info.begin + write_info.increment * @intCast(i32, i));
        const row_end = row_start + image.width;

        var pixels = @ptrCast(
            [*]const PixelType, @alignCast(@alignOf(PixelType), &pixel_buf[px_row_start])
        )[0..image.width];
        var image_row = image.pixels.?[row_start..row_end];

        switch(PixelType) {
            u16, u24 => {
                for (0..image.width) |j| {
                    image_row[i].r = mask.red(pixels[j]);
                    image_row[i].g = mask.green(pixels[j]);
                    image_row[i].b = mask.blue(pixels[j]);
                    image_row[i].a = 255;
                }
            },
            u32 => {
                if (info.compression == .ALPHABITFIELDS) {
                    for (0..image.width) |j| {
                        image_row[i].r = mask.red(pixels[j]);
                        image_row[i].g = mask.green(pixels[j]);
                        image_row[i].b = mask.blue(pixels[j]);
                        image_row[i].a = mask.alpha(pixels[j]);
                    }
                }
                else {
                    for (0..image.width) |j| {
                        image_row[i].r = mask.red(pixels[j]);
                        image_row[i].g = mask.green(pixels[j]);
                        image_row[i].b = mask.blue(pixels[j]);
                        image_row[i].a = 255;
                    }
                }
            },
            else => unreachable,
        }
        px_row_start += row_len_bytes;
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
pub const bmp_min_sz = bmp_file_header_sz + bmp_info_header_sz_core + 2 * bmp_rgb24_sz + bmp_row_align;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- pub enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const ImageFormat = enum { Infer, Bmp, Jpg, Png };

pub const ImageType = enum { None, RGB, RGBA };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- enums
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const BitmapColorTableType = enum { None, RGB24, RGB32 };

const BitmapHeaderType = enum(u32) { None, Core, V1, V4, V5 };

const BitmapCompression = enum(u32) { 
    RGB, RLE8, RLE4, BITFIELDS, JPEG, PNG, ALPHABITFIELDS, CMYK, CMYKRLE8, CMYKRLE4, None 
};

const BitmapColorSpace = enum(u32) {
    CalibratedRGB = 0x0,
    ProfileLinked = 0x4c494e4b,
    ProfileEmbedded = 0x4d424544,
    WindowsCS = 0x57696e20,
    sRGB = 0x73524742,
    None = 0xffffffff,
};

const BitmapReadDirection = enum(u8) { BottomUp=0, TopDown=1 };

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- pub types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]gfx.RGBA32 = null,
    allocator: ?kMem.Allocator = null,

    pub inline fn clear(self: *Image) void {
        std.debug.assert(self.allocator != null and self.pixels != null);
        self.allocator.?.free(self.pixels.?);
        self.* = Image{};
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const ImageError = error{
    NoFileExtension,
    InvalidFileExtension,
    TooLarge,
    InvalidSizeForFormat,
    PartialRead,
    UnexpectedEOF,
    BmpFlavorUnsupported,
    BmpInvalidBytesInFileHeader,
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
    BmpInvalidCompression,
};

const BitmapColorTable = struct {
    buffer: [256]gfx.RGBA32 = undefined,
    length: usize = 0,

    pub inline fn slice(self: *const BitmapColorTable) []const gfx.RGBA32 {
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

const BmpWriteInfo = struct {
    begin: i32,
    increment: i32,
};

fn BitmapColorMask(comptime IntType: type) type {
    return struct {
        const MaskType = @This();
        m_red: IntType = switch(IntType) {
            u16 => 0x7c00,
            u24 => 0xff0000,
            u32 => 0x00ff0000,
            else => unreachable,
        },
        m_green: IntType = switch(IntType) {
            u16 => 0x03e0,
            u24 => 0x00ff00,
            u32 => 0x0000ff00,
            else => unreachable,
        },
        m_blue: IntType = switch(IntType) {
            u16 => 0x001f,
            u24 => 0x0000ff,
            u32 => 0x000000ff,
            else => unreachable,
        },
        m_alpha: IntType = switch(IntType) {
            u32 => 0xff000000,
            else => 0x0
        },
        red_shift: u8 = switch(IntType) {
            u16 => 10,
            u24, u32 => 16,
            else => unreachable,
        },
        green_shift: u8 = switch(IntType) {
            u16 => 5,
            u24, u32 => 8,
            else => unreachable,
        },
        blue_shift: u8 = 0,
        alpha_shift: u8 = switch(IntType) {
            u32 => 24,
            else => 0,
        },

        inline fn fromInfo(info: *const BitmapInfo) MaskType {
            return MaskType {
                .m_red = @intCast(IntType, info.red_mask),
                .m_green = @intCast(IntType, info.green_mask),
                .m_blue = @intCast(IntType, info.blue_mask),
                .m_alpha = @intCast(IntType, info.alpha_mask),
                .red_shift = @ctz(info.red_mask),
                .green_shift = @ctz(info.green_mask),
                .blue_shift = @ctz(info.blue_mask),
                .alpha_shift = @ctz(info.alpha_mask),
            };
        }

        inline fn red(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, (pixel & self.m_red) >> @intCast(u4, self.red_shift));
        }

        inline fn green(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, (pixel & self.m_green) >> @intCast(u4, self.green_shift));
        }

        inline fn blue(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, (pixel & self.m_blue) >> @intCast(u4, self.blue_shift));
        }

        inline fn alpha(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, (pixel & self.m_alpha) >> @intCast(u4, self.alpha_shift));
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
    // pixel data size
    data_size: u32 = 0,
    // how many colors in image. mandatory for color depths of 1,2,8. if 0, using full color depth.
    color_ct: u32 = 0,
    // masks to pull color data from pixels
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

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- tests
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// pub fn LoadImageTest() !void {
test "Load Bitmap image" {
    try kMem.autoStartup();
    defer kMem.shutdown();

    const allocator = kMem.Allocator.new(kMem.Enclave.Game);

    print("\n", .{});

    // try loadImage("test/images/puppy.bmp", ImageType.Infer, &test_img, allocator);

    var path_buf = LocalStringBuffer(128).new();

    // 2.7 has coverage over core, v1, v4, and v5
    try path_buf.append("d:/projects/zig/core/test/nocommit/bmpsuite-2.7/g/");

    // 0.9 is V1 only
    // try path_buf.append("d:/projects/zig/core/test/nocommit/bmptestsuite-0.9/valid/");

    var test_dir = try std.fs.openIterableDirAbsolute(path_buf.string(), .{ .access_sub_paths = false });
    var dir_it = test_dir.iterate();

    var filename_lower = LocalStringBuffer(128).new();
    var passed_all: bool = true;

    while (try dir_it.next()) |entry| {
        try filename_lower.appendLower(entry.name);
        defer filename_lower.setToPrevLen();
        if (!str.sameTail(filename_lower.string(), "bmp") and !str.sameTail(filename_lower.string(), "dib")) {
            continue;
        }

        try path_buf.append(entry.name);
        defer path_buf.setToPrevLen();

        print("loading {s}\n", .{filename_lower.string()});

        var image = loadImage(path_buf.string(), ImageFormat.Infer, allocator) 
            catch |e| blk: {print("load error {any}\n", .{e}); break :blk Image{};};

        if (image.pixels != null) {
            print("*** processed ***\n", .{});
            image.clear();
        }
        else {
            passed_all = false;
        }

        print("\n// ------------------ //\n\n", .{});
    }

    // try std.testing.expect(passed_all);
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const gfx = @import("graphics.zig");
const RGBA32 = gfx.RGBA32;
const RGB24 = gfx.RGB24;
const std = @import("std");
const str = @import("string.zig");
const print = std.debug.print;
const kMem = @import("mem.zig");
const LocalStringBuffer = str.LocalStringBuffer;
