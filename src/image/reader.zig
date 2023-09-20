const std = @import("std");
const BitmapInfo = @import("bmp.zig").BitmapInfo;
const BitmapColorTable = @import("bmp.zig").BitmapColorTable;
const RGBA32 = @import("../graphics.zig").RGBA32;
const Image = @import("image.zig").Image;
const ImageError = @import("image.zig").ImageError;

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

pub fn RLEReader(comptime IntType: type) type {
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

        pub fn new(image_width: u32, image_height: u32) !RLEReaderType {
            return RLEReaderType{
                .img_row = image_height - 1,
                .img_width = image_width,
                .img_height = image_height,
                .byte_pos = 0,
            };
        }

        pub fn readAction(self: *RLEReaderType, buffer: []const u8) !RLEAction {
            if (self.byte_pos + 1 >= buffer.len) {
                return ImageError.UnexpectedEOF;
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
                        return ImageError.BmpInvalidColorTableIndex;
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
                        return ImageError.BmpInvalidColorTableIndex;
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
                return ImageError.UnexpectedEOF;
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
                            return ImageError.BmpInvalidColorTableIndex;
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
                            return ImageError.BmpInvalidColorTableIndex;
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
                return ImageError.UnexpectedEOF;
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