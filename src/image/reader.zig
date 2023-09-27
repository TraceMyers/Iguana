const std = @import("std");
const BitmapInfo = @import("bmp.zig").BitmapInfo;
const BitmapColorTable = @import("bmp.zig").BitmapColorTable;
const RGBA32 = @import("../graphics.zig").RGBA32;
const imagef = @import("image.zig");
const Image = imagef.Image;
const ImageError = imagef.ImageError;
const ImageAlpha = imagef.ImageAlpha;
const tga = @import("tga.zig");
const TgaImageSpec = tga.TgaImageSpec;
const TgaInfo = tga.TgaInfo;
const iVec2 = @import("../math.zig").iVec2;

pub const RLEAction = enum {
    EndRow, // 0
    EndImage, // 1
    Move, // 2
    ReadPixels, // 3
    RepeatPixels, // 4
};

pub const ColorLayout = enum {
    ABGR,
    ARGB
};

fn BitmapColorMask(comptime IntType: type) type {

    const ShiftType = switch (IntType) {
        u8 => u4,
        u16 => u4,
        u24 => u5,
        u32 => u5,
        else => undefined,
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
                return MaskType{ .mask = @intCast(IntType, in_mask), .rshift = @intCast(ShiftType, shr) };
            } else {
                return MaskType{ .mask = @intCast(IntType, in_mask), .lshift = @intCast(ShiftType, try std.math.absInt(shr)) };
            }
        }

        inline fn extractColor(self: *const MaskType, pixel: IntType) u8 {
            return @intCast(u8, ((pixel & self.mask) >> self.rshift) << self.lshift);
        }

        inline fn shiftType() type {
            return ShiftType;
        }
    };
}

pub fn InlinePixelReader(comptime IntType: type, comptime layout: ColorLayout) type {

    const ShiftType = switch (IntType) {
        u8 => u4,
        u16 => u4,
        u24 => u5,
        u32 => u5,
        else => undefined,
    };

    const r_byte_offset: comptime_int = if (layout == .ABGR) 2 else 0;
    const g_byte_offset: comptime_int = if (layout == .ABGR) 1 else 1;
    const b_byte_offset: comptime_int = if (layout == .ABGR) 0 else 2;

    return struct {
        const SetType = @This();

        r_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        g_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        b_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},
        a_mask: BitmapColorMask(IntType) = BitmapColorMask(IntType){},

        pub fn standard(alpha_mask: u32) !SetType {
            return SetType{
                .r_mask = switch (IntType) {
                    u8 => try BitmapColorMask(IntType).new(0),
                    u16 => try BitmapColorMask(IntType).new(0x7c00),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x00ff0000),
                    else => unreachable,
                },
                .g_mask = switch (IntType) {
                    u8 => try BitmapColorMask(IntType).new(0),
                    u16 => try BitmapColorMask(IntType).new(0x03e0),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x0000ff00),
                    else => unreachable,
                },
                .b_mask = switch (IntType) {
                    u8 => try BitmapColorMask(IntType).new(0),
                    u16 => try BitmapColorMask(IntType).new(0x001f),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(0x000000ff),
                    else => unreachable,
                },
                .a_mask = switch (IntType) {
                    u8 => try BitmapColorMask(IntType).new(0),
                    u16 => try BitmapColorMask(IntType).new(alpha_mask),
                    u24 => try BitmapColorMask(IntType).new(0),
                    u32 => try BitmapColorMask(IntType).new(alpha_mask),
                    else => unreachable,
                },
            };
        }

        pub fn fromInfo(info: *const BitmapInfo) !SetType {
            return SetType{
                .r_mask = try BitmapColorMask(IntType).new(info.red_mask),
                .b_mask = try BitmapColorMask(IntType).new(info.blue_mask),
                .g_mask = try BitmapColorMask(IntType).new(info.green_mask),
                .a_mask = try BitmapColorMask(IntType).new(info.alpha_mask),
            };
        }

        inline fn extractRGBA(self: *const SetType, pixel: IntType) RGBA32 {
            return RGBA32{ 
                .r = self.r_mask.extractColor(pixel), 
                .g = self.g_mask.extractColor(pixel), 
                .b = self.b_mask.extractColor(pixel), 
                .a = self.a_mask.extractColor(pixel) 
            };
        }

        inline fn extractRGB(self: *const SetType, pixel: IntType) RGBA32 {
            return RGBA32{ 
                .r = self.r_mask.extractColor(pixel), 
                .g = self.g_mask.extractColor(pixel), 
                .b = self.b_mask.extractColor(pixel), 
                .a = 255
            };
        }

        pub inline fn extractRow(
            self: *const SetType, image_row: []RGBA32, pixel_row: []const u8, mask_alpha: bool, greyscale: bool
        ) void {
            if (greyscale) {
                extractRowGreyscale(image_row, pixel_row);
            } else if (mask_alpha) {
                self.extractRowRGBA(image_row, pixel_row);
            } else {
                self.extractRowRGB(image_row, pixel_row);
            }
        }

        fn extractRowGreyscale(image_row: []RGBA32, pixel_row: []const u8) void {
            const shift: comptime_int = switch(IntType) {
                u8 => 0,
                u16 => 1,
                u32 => 2,
                else => unreachable,
            };
            var pixels = @ptrCast([*]const IntType, @alignCast(@alignOf(IntType), &pixel_row[0]))[0..image_row.len];
            for (0..image_row.len) |j| {
                const read_pixel = @intCast(u8, pixels[j] >> @as(ShiftType, shift));
                var write_pixel: *RGBA32 = &image_row[j];
                write_pixel.r = read_pixel;
                write_pixel.g = read_pixel;
                write_pixel.b = read_pixel;
                write_pixel.a = 255;
            }
        }

        fn extractRowRGB(self: *const SetType, image_row: []RGBA32, pixel_row: []const u8) void {
            switch (IntType) {
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
                        image_pixel.b = pixel_row[byte + b_byte_offset];
                        image_pixel.g = pixel_row[byte + g_byte_offset];
                        image_pixel.r = pixel_row[byte + r_byte_offset];
                        byte += 3;
                    }
                },
                else => unreachable,
            }
        }

        fn extractRowRGBA(self: *const SetType, image_row: []RGBA32, pixel_row: []const u8) void {
            var pixels = @ptrCast([*]const IntType, @alignCast(@alignOf(IntType), &pixel_row[0]))[0..image_row.len];
            for (0..image_row.len) |j| {
                image_row[j] = self.extractRGBA(pixels[j]);
            }
        }
    };
}

pub fn TgaRLEReader(comptime IntType: type, comptime color_table_img: bool, comptime greyscale: bool) type {
    return struct {
        const RLEReaderType = @This();
        const ReadInfoType = TgaReadInfo(IntType);

        read_info: TgaReadInfo(IntType) = undefined,
        byte_pos: u32 = 0,
        action_ct: u32 = 0,
        cur_color: RGBA32 = RGBA32{},
        alpha_present: u8 = 0,

        pub fn new(info: *const TgaInfo, image: *const Image) !RLEReaderType {
            if (color_table_img and info.color_map.table == null) {
                return ImageError.ColorTableImageEmptyTable;
            }
            if (greyscale and IntType != u8) {
                return ImageError.TgaGreyscale8BitOnly;
            }
            return RLEReaderType {
                .read_info = try TgaReadInfo(IntType).new(info, image),
                .alpha_present = @intCast(u8, @boolToInt(info.alpha != ImageAlpha.None)),
            };
        }

        pub fn readAction(self: *RLEReaderType, image: *const Image, info: *const TgaInfo, buffer: []const u8) !RLEAction {
            const image_index = self.imageIndex(image);
            if (self.byte_pos >= buffer.len or image_index <= 0 or image_index >= image.pixels.?.len) {
                return RLEAction.EndImage;
            }

            const action_byte = buffer[self.byte_pos];
            self.byte_pos += 1;
            self.action_ct = (action_byte & 0x7f) + 1;
            const action_bit = action_byte & 0x80;

            if (action_bit > 0) {
                if (color_table_img) {
                    try self.readNextColorTableColor(info, buffer);
                } else {
                    try self.readNextInlineColor(buffer);
                }
                return RLEAction.RepeatPixels;
            }
            else {
                return RLEAction.ReadPixels;
            }
        }

        pub fn repeatPixel(self: *RLEReaderType, image: *Image) !void {
            for (0..@intCast(usize, self.action_ct)) |i| {
                _ = i;
                const image_idx: usize = try self.imageIndexChecked(image);
                image.pixels.?[image_idx] = self.cur_color;
                self.pixelStep(image);
            }
        }

        pub fn readPixels(self: *RLEReaderType, buffer: []const u8, info: *const TgaInfo, image: *Image) !void {
            for (0..@intCast(usize, self.action_ct)) |i| {
                _ = i;
                const image_idx: usize = try self.imageIndexChecked(image);
                if (color_table_img) {
                    try self.readNextColorTableColor(info, buffer);
                } else {
                    try self.readNextInlineColor(buffer);
                }
                image.pixels.?[image_idx] = self.cur_color;
                self.pixelStep(image);
            }
        }

        inline fn imageIndex(self: *const RLEReaderType, image: *const Image) i32 {
            return self.read_info.coords.y() * @intCast(i32, image.width) + self.read_info.coords.x();
        }

        fn imageIndexChecked(self: *const RLEReaderType, image: *const Image) !usize {
            const image_idx_signed: i32 = self.imageIndex(image);
            if (image_idx_signed < 0) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            const image_idx = @intCast(usize, image_idx_signed);
            if (image_idx >= self.read_info.pixel_ct) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            return image_idx;
        }

        inline fn pixelStep(self: *RLEReaderType, image: *const Image) void {
            self.read_info.coords.xAdd(1);
            if (self.read_info.coords.x() >= image.width) {
                self.read_info.coords.setX(0);
                self.read_info.coords.setY(self.read_info.coords.y() + self.read_info.write_dir);
            }
        }

        fn readNextInlineColor(self: *RLEReaderType, buffer: []const u8) !void {
            const new_byte_pos = self.byte_pos + ReadInfoType.pixelSz();
            if (new_byte_pos > buffer.len) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            switch (IntType) {
                u8 => {
                    const grey_color = buffer[self.byte_pos];
                    self.cur_color.r = grey_color;
                    self.cur_color.g = grey_color;
                    self.cur_color.b = grey_color;
                    self.cur_color.a = 255;
                },
                u16 => {
                    const pixel = std.mem.readIntSliceLittle(IntType, buffer[self.byte_pos..new_byte_pos]);
                    self.cur_color.r = @intCast(u8, (pixel & 0x7c00) >> 7);
                    self.cur_color.g = @intCast(u8, (pixel & 0x03e0) >> 2);
                    self.cur_color.b = @intCast(u8, (pixel & 0x001f) << 3);
                    self.cur_color.a = 255;
                },
                u24 => {
                    self.cur_color.b = buffer[self.byte_pos];
                    self.cur_color.g = buffer[self.byte_pos+1];
                    self.cur_color.r = buffer[self.byte_pos+2];
                    self.cur_color.a = 255;
                },
                u32 => {
                    self.cur_color.b = buffer[self.byte_pos];
                    self.cur_color.g = buffer[self.byte_pos+1];
                    self.cur_color.r = buffer[self.byte_pos+2];
                    self.cur_color.a = buffer[self.byte_pos+3];
                },
                else => unreachable,
            }
            self.byte_pos = new_byte_pos;
        }

        fn readNextColorTableColor(self: *RLEReaderType, info: *const TgaInfo, buffer: []const u8) !void {
            const new_byte_pos = self.byte_pos + ReadInfoType.pixelSz();
            if (new_byte_pos > buffer.len) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            const color_table = info.color_map.table.?;
            const pixel = std.mem.readIntSliceLittle(IntType, buffer[self.byte_pos..new_byte_pos]);
            if (pixel >= color_table.len) {
                return ImageError.InvalidColorTableIndex;
            }
            self.cur_color = info.color_map.table.?[pixel];
            self.byte_pos = new_byte_pos;
        }

    };
}

pub fn BmpRLEReader(comptime IntType: type) type {
    return struct {
        const RLEReaderType = @This();

        img_col: u32 = 0,
        img_row: u32 = 0,
        img_width: u32 = 0,
        img_height: u32 = 0,
        byte_pos: u32 = 0,
        img_write_end: bool = false,
        action_bytes: [2]u8 = undefined,

        const read_min_multiple: u8 = switch (IntType) {
            u4 => 4,
            u8 => 2,
            else => unreachable,
        };
        const read_min_shift: u8 = switch (IntType) {
            u4 => 2,
            u8 => 1,
            else => unreachable,
        };
        const byte_shift: u8 = switch (IntType) {
            u4 => 1,
            u8 => 0,
            else => unreachable,
        };

        pub fn new(image_width: u32, image_height: u32) RLEReaderType {
            return RLEReaderType{
                .img_row = image_height - 1,
                .img_width = image_width,
                .img_height = image_height,
                .byte_pos = 0,
            };
        }

        pub fn readAction(self: *RLEReaderType, buffer: []const u8) !RLEAction {
            if (self.byte_pos + 1 >= buffer.len) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            self.action_bytes[0] = buffer[self.byte_pos];
            self.action_bytes[1] = buffer[self.byte_pos + 1];
            self.byte_pos += 2;

            if (self.img_write_end) { // ended by writing to the final row
                return RLEAction.EndImage;
            } else if (self.action_bytes[0] > 0) {
                return RLEAction.RepeatPixels;
            } else if (self.action_bytes[1] > 2) {
                return RLEAction.ReadPixels;
            } else { // 0 = EndRow, 1 = EndImage, 2 = Move
                return @intToEnum(RLEAction, self.action_bytes[1]);
            }
        }

        pub fn repeatPixel(self: *RLEReaderType, color_table: *const BitmapColorTable, image: *Image) !void {
            const repeat_ct = self.action_bytes[0];
            const col_end = self.img_col + repeat_ct;
            const img_idx_end = self.img_row * self.img_width + col_end;

            if (img_idx_end > image.pixels.?.len) {
                return ImageError.BmpInvalidRLEData;
            }
            var img_idx = self.imageIndex();

            switch (IntType) {
                u4 => {
                    const color_indices: [2]u8 = .{ (self.action_bytes[1] & 0xf0) >> 4, self.action_bytes[1] & 0x0f };
                    if (color_indices[0] >= color_table.length or color_indices[1] >= color_table.length) {
                        return ImageError.InvalidColorTableIndex;
                    }

                    var color_idx: u8 = 0;
                    const colors: [2]RGBA32 = .{ color_table.buffer[color_indices[0]], color_table.buffer[color_indices[1]] };
                    while (img_idx < img_idx_end) : (img_idx += 1) {
                        image.pixels.?[img_idx] = colors[color_idx];
                        color_idx = 1 - color_idx;
                    }
                },
                u8 => {
                    const color_idx = self.action_bytes[1];
                    if (color_idx >= color_table.length) {
                        return ImageError.InvalidColorTableIndex;
                    }

                    const color = color_table.buffer[color_idx];
                    while (img_idx < img_idx_end) : (img_idx += 1) {
                        image.pixels.?[img_idx] = color;
                    }
                },
                else => unreachable,
            }
            self.img_col = col_end;
        }

        pub fn readPixels(
            self: *RLEReaderType, 
            buffer: []const u8, 
            color_table: *const BitmapColorTable, 
            image: *Image
        ) !void {
            const read_ct = self.action_bytes[1];
            const col_end = self.img_col + read_ct;
            const img_idx_end = self.img_row * self.img_width + col_end;

            if (img_idx_end > image.pixels.?.len) {
                return ImageError.BmpInvalidRLEData;
            }

            // read_ct = 3
            const word_read_ct = read_ct >> read_min_shift; // 3 / 4 = 0
            const word_leveled_read_ct = word_read_ct << read_min_shift; // 0 * 4 = 0
            const word_truncated = @intCast(u8, @boolToInt(word_leveled_read_ct != read_ct)); // true
            const word_aligned_read_ct = @intCast(u32, word_leveled_read_ct) + read_min_multiple * word_truncated; // 0 + 4
            const byte_read_end = self.byte_pos + (word_aligned_read_ct >> byte_shift); //  add 4

            if (byte_read_end >= buffer.len) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }

            var img_idx = self.imageIndex();
            var byte_idx: usize = self.byte_pos;
            switch (IntType) {
                u4 => {
                    var high_low: u1 = 0;
                    const masks: [2]u8 = .{ 0xf0, 0x0f };
                    const shifts: [2]u3 = .{ 4, 0 };
                    while (img_idx < img_idx_end) : (img_idx += 1) {
                        const color_idx = (buffer[byte_idx] & masks[high_low]) >> shifts[high_low];
                        if (color_idx >= color_table.length) {
                            return ImageError.InvalidColorTableIndex;
                        }
                        image.pixels.?[img_idx] = color_table.buffer[color_idx];
                        byte_idx += high_low;
                        high_low = 1 - high_low;
                    }
                },
                u8 => {
                    while (img_idx < img_idx_end) : (img_idx += 1) {
                        const color_idx: IntType = buffer[byte_idx];
                        if (color_idx >= color_table.length) {
                            return ImageError.InvalidColorTableIndex;
                        }
                        image.pixels.?[img_idx] = color_table.buffer[color_idx];
                        byte_idx += 1;
                    }
                },
                else => unreachable,
            }
            self.byte_pos = byte_read_end;
            self.img_col = col_end;
        }

        pub inline fn imageIndex(self: *const RLEReaderType) u32 {
            return self.img_row * self.img_width + self.img_col;
        }

        pub fn changeCoordinates(self: *RLEReaderType, buffer: []const u8) !void {
            if (self.byte_pos + 1 >= buffer.len) {
                return ImageError.UnexpectedEndOfImageBuffer;
            }
            self.img_col += buffer[self.byte_pos];
            const new_row = @intCast(i32, self.img_row) - @intCast(i32, buffer[self.byte_pos + 1]);

            if (new_row < 0) {
                self.img_write_end = true;
            } else {
                self.img_row = @intCast(u32, new_row);
            }
            self.byte_pos += 2;
        }

        pub fn incrementRow(self: *RLEReaderType) void {
            self.img_col = 0;
            const new_row = @intCast(i32, self.img_row) - 1;

            if (new_row < 0) {
                self.img_write_end = true;
            } else {
                self.img_row = @intCast(u32, new_row);
            }
        }
    };
}

pub fn readColorTableImageRow(
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
                return ImageError.InvalidColorTableIndex;
            }
            image_row[img_idx + j] = colors[col_idx];
        }
        img_idx += colors_per_byte;
    }
}


fn tgaImageOrigin(image_spec: *const TgaImageSpec) iVec2(i32) {
    const bit4: bool = (image_spec.descriptor & 0x10) != 0;
    const bit5: bool = (image_spec.descriptor & 0x20) != 0;
    // imagine the image buffer is invariably stored in in a 2d array of rows stacked upward, on an xy plane with the
    // first buffer pixel at (0, 0). This might take a little brain jiu-jitsu since we normally thing of arrays as 
    // top-down. If the origin (top left of output image) is also at (0, 0), we should read left-to-right, bottom-to-top.
    // In practice, we read the buffer from beginning to end and write depending on the origin.
    if (bit4) {
        if (bit5) {
            // top right
            return iVec2(i32).init(.{image_spec.image_width - 1, image_spec.image_height - 1});
        } else {
            // bottom right
            return iVec2(i32).init(.{image_spec.image_width - 1, 0});
        }
    } else {
        if (bit5) {
            // top left
            return iVec2(i32).init(.{0, image_spec.image_height - 1});
        } else {
            // bottom left
            return iVec2(i32).init(.{0, 0});
        }
    }
}

pub fn TgaReadInfo (comptime PixelType: type) type {

    const pixel_sz: comptime_int = switch(PixelType) { // sizeOf(u24) gives 4
        u8 => 1,
        u15, u16 => 2,
        u24 => 3,
        u32 => 4,
        else => unreachable,
    };

    return struct {
        const TRIType = @This();

        image_sz: i32 = undefined,
        pixel_ct: u32 = undefined,
        read_start: i32 = undefined,
        read_row_step: i32 = undefined,
        coords: iVec2(i32) = undefined,
        write_start: i32 = undefined,
        write_row_step: i32 = undefined,
        write_dir: i32 = 1,

        pub fn new(info: *const TgaInfo, image: *const Image) !TRIType {
            var read_info = TRIType{};
            
            const image_spec = info.header.image_spec;
            const width_sz = image.width * pixel_sz;
            read_info.image_sz = @intCast(i32, width_sz * image.height);
            read_info.pixel_ct = image.width * image.height;
            read_info.read_start = 0;
            read_info.read_row_step = @intCast(i32, width_sz);

            read_info.coords = tgaImageOrigin(&image_spec);

            if (read_info.coords.x() != 0) {
                return ImageError.TgaUnsupportedImageOrigin;
            } 

            if (read_info.coords.y() == 0) {
                // image rows stored bottom-to-top
                read_info.write_start = @intCast(i32, read_info.pixel_ct - image.width);
                read_info.write_row_step = -@intCast(i32, image.width);
                // if coordinates are used, they will be used for writing in the opposite direction
                read_info.coords.setY(@intCast(i32, image.height) - 1);
                read_info.write_dir = -1;
            }
            else {
                // image rows stored top-to-bottom
                read_info.write_start = 0;
                read_info.write_row_step = @intCast(i32, image.width);
                // if coordinates are used, they will be used for writing in the opposite direction
                read_info.coords.setY(0);
            }

            return read_info;
        }

        pub inline fn pixelSz() u32 {
            return @intCast(u32, pixel_sz);
        }
    };
}