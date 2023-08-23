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
    var buffer: []u8 = try loadImageFromDisk(file, allocator, bmp_min_sz);
    defer allocator.free(buffer);

    const identity = buffer[0..2];
    if (!str.same(identity, "BM")) {
        // identity strings acceptable for (very old) OS/2 bitmaps. microsoft shouldered-out IBM and started taking over
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

    // -- OG file header
    const file_sz = std.mem.readIntNative(u32, buffer[2..6]);
    const reserved_verify_zero = std.mem.readIntNative(u32, buffer[6..10]);
    if (reserved_verify_zero != 0) {
        return ImageError.BmpInvalidBytesInFileHeader;
    }

    var info = BitmapInfo{};
    info.data_offset = std.mem.readIntNative(u32, buffer[10..14]);

    // -- a forest of info headers beyond this point. we capture the headers you'd expect to see these days.
    info.header_sz = std.mem.readIntNative(u32, buffer[14..18]);

    if (buffer.len <= info.header_sz + bmp_file_header_sz or buffer.len <= info.data_offset) {
        return ImageError.UnexpectedEOF;
    }

    var color_table = BitmapColorTable{};
    var buffer_pos: usize = undefined;
    switch (info.header_sz) {
        bmp_info_header_sz_core => buffer_pos = try bmpGetCoreInfo(buffer, &info, file_sz, &color_table),
        bmp_info_header_sz_v1 => buffer_pos = try bmpGetV1Info(buffer, &info, &color_table),
        bmp_info_header_sz_v4 => buffer_pos = try bmpGetV4Info(buffer, &info, &color_table),
        bmp_info_header_sz_v5 => buffer_pos = try bmpGetV5Info(buffer, &info, &color_table),
        else => return ImageError.BmpInvalidHeaderSizeOrVersionUnsupported, 
    }
    // -- end headers and color table data

    if (!bmpCompressionSupported(&info)) {
        return ImageError.BmpCompressionUnsupported;
    }

    if (info.color_space == BitmapColorSpace.ProfileEmbedded or info.color_space == BitmapColorSpace.ProfileLinked) {
        // TODO: support color profiles? (and note the next block would change, too)
        return ImageError.BmpColorProfilesUnsupported;
    }

    if (info.data_offset + info.data_size != buffer.len) {
        if (info.data_size != 0) {
            return ImageError.BmpInvalidSizeInfo;
        }
        else {
            info.data_size = @intCast(u32, buffer.len) - info.data_offset;
        }
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

    var buffer: []u8 = try allocator.alloc(u8, stat.size);
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

fn bmpGetCoreInfo(buffer: []u8, info: *BitmapInfo, file_sz: u32, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.Core;
    info.width = @intCast(i32, std.mem.readIntNative(i16, buffer[18..20]));
    info.height = @intCast(i32, std.mem.readIntNative(i16, buffer[20..22]));
    info.color_depth = @intCast(u32, std.mem.readIntNative(u16, buffer[24..26]));
    info.data_size = file_sz - info.data_offset;
    info.compression = BitmapCompression.RGB;
    color_table._type = BitmapColorTableType.RGB24;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_core;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB24);
    return table_offset + color_table.length * @sizeOf(gfx.RGB24);
}

fn bmpGetV1Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V1;
    bmpFillV1HeaderPart(buffer, info);
    color_table._type = BitmapColorTableType.RGB32;
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
    color_table._type = BitmapColorTableType.RGB32;
    const table_offset = bmp_file_header_sz + bmp_info_header_sz_v4;
    try bmpGetColorTable(buffer[table_offset..], info, color_table, gfx.RGB32);
    return table_offset + color_table.length * @sizeOf(gfx.RGB32);
}

fn bmpGetV5Info(buffer: []u8, info: *BitmapInfo, color_table: *BitmapColorTable) !usize {
    info.header_type = BitmapHeaderType.V5;
    bmpFillV1HeaderPart(buffer, info);
    bmpFillV4HeaderPart(buffer, info);
    bmpFillV5HeaderPart(buffer, info);
    color_table._type = BitmapColorTableType.RGB32;
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
    var table_buffer = @ptrCast([*]ColorType, @alignCast(@alignOf(ColorType), &color_table.buffer[0]));

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
            const table_color: *ColorType = &table_buffer[i];
            const buffer_color: *const ColorType = &data_casted[i];
            // convert format's bgr to standard rgb
            table_color.b = buffer_color.r;
            table_color.g = buffer_color.g;
            table_color.r = buffer_color.b;
        }
    }
}

inline fn bmpCompressionSupported(info: *const BitmapInfo) bool {
    return switch(info.compression) {
        .RGB => true,
        .RLE8 => false,
        .RLE4 => false,
        .BITFIELDS => false,
        .JPEG => false,
        .PNG => false,
        .ALPHABITFIELDS => false,
        .CMYK => false,
        .CMYKRLE8 => false,
        .CMYKRLE4 => false,
        .None => false,
    };
}

fn bmpCreateImage(buffer: []u8, image: *Image, info: *const BitmapInfo, color_table: *const BitmapColorTable) !void {
    // get row length in bytes as a multiple of 4 (rows are padded to 4 byte increments)
    const row_length = ((image.width * info.color_depth + 31) & ~@as(u32, 31)) >> 3;    
    if (buffer.len < info.data_offset + row_length * image.height) {
        if (info.compression == .RLE8 
            or info.compression == .RLE4 
            or info.compression == .CMYKRLE8 
            or info.compression == .CMYKRLE4
        ) {
            return;
        }
        else {
            return ImageError.UnexpectedEOF;
        }
    }

    const pixel_buf = buffer[info.data_offset..];
    image.pixels = try image.allocator.?.alloc(gfx.RGBA32, image.width * image.height);

    if (info.color_depth <= 8) {
        if (color_table._type == .None or color_table.length < 2) {
            return ImageError.BmpInvalidColorTable;
        }
        switch(info.color_depth) {
            1 => {
                if (color_table._type == .RGB24) {
                    try bmpProcessColorTableImage(u1, gfx.RGB24, pixel_buf, info, color_table, image, row_length);
                }
                else {
                    try bmpProcessColorTableImage(u1, gfx.RGB32, pixel_buf, info, color_table, image, row_length);
                }
            },
            4 => {
                if (color_table._type == .RGB24) {
                    try bmpProcessColorTableImage(u4, gfx.RGB24, pixel_buf, info, color_table, image, row_length);
                }
                else {
                    try bmpProcessColorTableImage(u4, gfx.RGB32, pixel_buf, info, color_table, image, row_length);
                }
            },
            8 => {
                if (color_table._type == .RGB24) {
                    try bmpProcessColorTableImage(u8, gfx.RGB24, pixel_buf, info, color_table, image, row_length);
                }
                else {
                    try bmpProcessColorTableImage(u8, gfx.RGB32, pixel_buf, info, color_table, image, row_length);
                }
            },
            else => unreachable,
        }
    }
    else switch(info.color_depth) {
        1 => try bmpProcessInlinePixelImage(u1, pixel_buf, info, image, row_length),
        4 => try bmpProcessInlinePixelImage(u4, pixel_buf, info, image, row_length),
        8 => try bmpProcessInlinePixelImage(u8, pixel_buf, info, image, row_length),
        16 => try bmpProcessInlinePixelImage(u16, pixel_buf, info, image, row_length),
        24 => try bmpProcessInlinePixelImage(u24, pixel_buf, info, image, row_length),
        32 => try bmpProcessInlinePixelImage(u32, pixel_buf, info, image, row_length),
        else => unreachable,
    }
}

fn bmpSetColorTablePixel(
    comptime ColorType: type, image_pixel: *RGBA32, idx: u8, idx_top: usize, colors: []const ColorType
) !void {
    if (idx >= idx_top) {
        return ImageError.BmpInvalidColorTableIndex;
    }
    const color = colors[idx];
    image_pixel.r = color.r;
    image_pixel.g = color.g;
    image_pixel.b = color.b;
    image_pixel.a = std.math.maxInt(u8);
}

fn bmpProcessColorTableImage(
    comptime PixelType: type, 
    comptime ColorType: type,
    pixel_buf: []const u8, 
    info: *const BitmapInfo,
    color_table: *const BitmapColorTable, 
    image: *Image, 
    row_len_bytes: usize
) !void {
    // bitmaps are stored bottom to top, meaning the top-left corner of the image is idx 0 of the last row, unless the
    // height param is negative. we always read top to bottom and write up or down depending.
    const write_direction = @intToEnum(BitmapReadDirection, @intCast(u8, @boolToInt(info.height < 0)));
    var out_row_begin: i32 = undefined;
    var out_row_increment: i32 = undefined;
    if (write_direction == .BottomUp) {
        out_row_begin = (@intCast(i32, image.height) - 1) * @intCast(i32, image.width);
        out_row_increment = -@intCast(i32, image.width);
    }
    else {
        out_row_begin = 0;
        out_row_increment = @intCast(i32, image.width);
    }

    const colors = @ptrCast(
        [*]const ColorType, @alignCast(@alignOf(ColorType), &color_table.buffer[0])
    )[0..color_table.length];

    var px_row_start: usize = 0;
    for (0..image.height) |i| {
        const row_start = @intCast(usize, out_row_begin + out_row_increment * @intCast(i32, i));
        const row_end = row_start + image.width;

        // 'pixels' in a color table-based image are indices to the color table
        var index_row = pixel_buf[px_row_start..px_row_start + row_len_bytes];
        var image_row = image.pixels.?[row_start..row_end];

        switch(PixelType) {
            u1 => {
                var byte: usize = 0;
                var img_idx: usize = 0;
                while (true) : (byte += 1) {
                    const idx_byte = index_row[byte];
                    const remainder = image.width - img_idx;
                    const last_iter = remainder <= 8;
                    const iter_ct = if (last_iter) remainder else 8;
                    for (0..iter_ct) |j| {
                        const idx: u8 = (idx_byte & (@as(u8, 0x80) >> @intCast(u3, j))) >> @intCast(u3, 7-j);
                        try bmpSetColorTablePixel(ColorType, &image_row[img_idx+j], idx, color_table.length, colors);
                    }
                    if (last_iter) {
                        break;
                    }
                    img_idx += 8;
                }
            },
            u4 => {
                const iter_ct = image.width >> 1;
                var img_idx: usize = 0;
                for (0..iter_ct) |byte| {
                    inline for(0..2) |k| {
                        const idx: u8 = (index_row[byte] & (@as(u8, 0xf0) >> (k*4))) >> (4-(k*4));
                        try bmpSetColorTablePixel(ColorType, &image_row[img_idx], idx, color_table.length, colors);
                        img_idx += 1;
                    }
                }
                if (iter_ct < row_len_bytes) {
                    const idx: u8 = (index_row[iter_ct] & @as(u8, 0xf0)) >> 4;
                    try bmpSetColorTablePixel(ColorType, &image_row[img_idx], idx, color_table.length, colors);
                }
            },
            u8 => {
                for (0..image.width) |j| {
                    const idx: u8 = index_row[j];
                    try bmpSetColorTablePixel(ColorType, &image_row[j], idx, color_table.length, colors);
                }
            },
            else => unreachable,
        }
        px_row_start += row_len_bytes;
    }
}

fn bmpProcessInlinePixelImage(
    comptime PixelType: type,
    pixel_buf: []const u8,
    info: *const BitmapInfo,
    image: *Image,
    row_len_bytes: usize
) !void {
    _ = PixelType;
    _ = pixel_buf;
    _ = info;
    _ = image;
    _ = row_len_bytes;
    return ImageError.BmpFlavorUnsupported;
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
// the smallest bmp is a core header type, full color () bmp with a single 6-byte pixel.
pub const bmp_min_sz = bmp_file_header_sz + bmp_info_header_sz_core + bmp_row_align * 2;

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
    BmpColorProfilesUnsupported,
    BmpCompressionUnsupported,
};

const BitmapColorTable = struct {
    buffer: [256 * @sizeOf(gfx.RGBA32)]u8 = undefined,
    length: usize = 0,
    _type: BitmapColorTableType = .None,

    pub fn colorSize(self: *const BitmapColorTable) usize {
        return switch(self._type) {
            .RGB24 => 3,
            .RGB32 => 4,
            else => @panic("bitmap color table's type not set!"),
        };
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

const BitmapInfo = extern struct {
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
