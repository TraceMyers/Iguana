const std = @import("std");
const imagef = @import("image.zig");
const Image = imagef.Image;
const memory = @import("../memory.zig");
const ImageError = imagef.ImageError;
const print = std.debug.print;
const string = @import("../string.zig");
const LocalBuffer = @import("../array.zig").LocalBuffer;
const ARGB64 = imagef.ARGB64;

// TODO: test images for color correction table

/// - Color Types
///     - PsuedoColor: pixels are indices to a color table/map
///     - TrueColor: pixels are subdivided into rgb fields
///     - DirectColor: pixels are subdivided into r, g, and b indices to independent color tables defining intensity
/// - TGA files are little-endian

pub fn load(
    file: *std.fs.File, image: *Image, allocator: std.mem.Allocator, options: *const imagef.ImageLoadOptions
) !void {
    errdefer image.clear();

    var info = TgaInfo{};
    defer freeAllocations(&info, allocator);

    var extents = ExtentBuffer.new();

    try readFooter(file, &info, &extents);
    try readHeader(file, &info, &extents);

    if (!typeSupported(info.header.info.image_type)) {
        return ImageError.TgaImageTypeUnsupported;
    }

    try readExtensionData(file, &info, allocator, &extents);
    try readImageId(file, &info, &extents);

    _ = options;
}

fn readFooter(file: *std.fs.File, info: *TgaInfo, extents: *ExtentBuffer) !void {
    const stat = try file.stat();
    if (stat.size > memory.MAX_SZ) {
        return ImageError.TooLarge;
    }

    info.file_sz = @intCast(u32, stat.size);
    if (info.file_sz < tga_min_sz) {
        return ImageError.InvalidSizeForFormat;
    }

    const footer_loc: u32 = info.file_sz - footer_end_offset;
    try file.seekTo(footer_loc);
    info.footer = try file.reader().readStruct(TgaFooter);

    if (string.same(info.footer.?.signature[0..], tga_signature)) {
        info.file_type = TgaFileType.V2;
        extents.append(BlockExtent{ .begin=footer_loc, .end=info.file_sz });
    }
    else {
        info.file_type = TgaFileType.V1;
        info.footer = null;
    }
}

fn readHeader(file: *std.fs.File, info: *TgaInfo, extents: *ExtentBuffer) !void {
    if (extentOverlap(extents, 0, tga_header_sz)) {
        return ImageError.OverlappingData;
    }
    extents.append(BlockExtent{ .begin=0, .end=tga_header_sz});

    // reading three structs rather than one so we're not straddling boundaries on any of the data.
    try file.seekTo(0);
    info.header.info = try file.reader().readStruct(TgaHeaderInfo);
    info.header.colormap_spec = try file.reader().readStruct(TgaColorMapSpec);
    // colormap_spec has 1 byte padding
    try file.seekTo(tga_image_spec_offset);
    info.header.image_spec = try file.reader().readStruct(TgaImageSpec);
}

fn readExtensionData(file: *std.fs.File, info: *TgaInfo, allocator: std.mem.Allocator, extents: *ExtentBuffer) !void {
    if (info.footer == null) {
        return;
    }

    const extension_area_loc = info.footer.?.extension_area_offset;
    const extension_area_end = extension_area_loc + extension_area_file_sz;
    if (extension_area_loc == 0 or extension_area_end > info.file_sz) {
        return;
    }

    try file.seekTo(extension_area_loc);
    info.extension_area = ExtensionArea{};
    info.extension_area.?.extension_sz = try file.reader().readIntNative(u16);

    if (extension_area_loc + info.extension_area.?.extension_sz > info.file_sz
        or info.extension_area.?.extension_sz != extension_area_file_sz
    ) {
        info.extension_area = null;
        return;
    }

    if (extentOverlap(extents, extension_area_loc, extension_area_end)) {
        return ImageError.OverlappingData;
    }
    extents.append(BlockExtent{ .begin=extension_area_loc, .end=extension_area_end });

    try readExtensionArea(file, info);

    if (info.extension_area.?.scanline_offset != 0) {
        info.scanline_table = try loadTable(
            file, info, allocator, extents, info.extension_area.?.scanline_offset, u32, info.header.image_spec.image_height
        );
    }
    if (info.extension_area.?.postage_stamp_offset != 0) {
        // TODO: read postage stamp. uses safe format as image
    }
    if (info.extension_area.?.color_correction_offset != 0) {
        info.color_correction_table = try loadTable(
            file, info, allocator, extents, info.extension_area.?.color_correction_offset, ARGB64, 256
        );
    }
}

fn readExtensionArea(file: *std.fs.File, info: *TgaInfo) !void {
    const extbuf: [493]u8 = try file.reader().readBytesNoEof(493);
    info.extension_area.?.author_name = extbuf[0..41].*;
    info.extension_area.?.author_comments = extbuf[41..365].*;
    const timestamp_slice = @ptrCast([*]const u16, @alignCast(@alignOf(u16), &extbuf[365]))[0..6];
    info.extension_area.?.timestamp = timestamp_slice.*;
    info.extension_area.?.job_name = extbuf[377..418].*;
    inline for(0..3) |i| {
        info.extension_area.?.job_time[i] = std.mem.readIntNative(u16, extbuf[418+(i*2)..420+(i*2)]);
    }
    info.extension_area.?.software_id = extbuf[424..465].*;
    info.extension_area.?.software_version = extbuf[465..468].*;
    info.extension_area.?.key_color = std.mem.readIntNative(u32, extbuf[468..472]);
    inline for(0..2) |i| {
        info.extension_area.?.pixel_aspect_ratio[i] = std.mem.readIntNative(u16, extbuf[472+(i*2)..474+(i*2)]);
    }
    inline for(0..2) |i| {
        info.extension_area.?.gamma[i] = std.mem.readIntNative(u16, extbuf[476+(i*2)..478+(i*2)]);
    }
    info.extension_area.?.color_correction_offset = std.mem.readIntNative(u32, extbuf[480..484]);
    info.extension_area.?.postage_stamp_offset = std.mem.readIntNative(u32, extbuf[484..488]);
    info.extension_area.?.scanline_offset = std.mem.readIntNative(u32, extbuf[488..492]);
    info.extension_area.?.attributes_type = extbuf[492];
}

fn loadTable(
    file: *std.fs.File, 
    info: *TgaInfo, 
    allocator: std.mem.Allocator, 
    extents: *ExtentBuffer, 
    offset: u32, 
    comptime TableType: type,
    table_ct: u32
) ![]TableType {
    const sz = @sizeOf(TableType) * table_ct;
    const end = offset + sz;

    if (end > info.file_sz) {
        return ImageError.TgaInvalidTableSize;
    }
    if (extentOverlap(extents, offset, end)) {
        return ImageError.OverlappingData;
    }
    extents.append(BlockExtent{ .begin=offset, .end=end });

    var table: []TableType = try allocator.alloc(TableType, table_ct);
    var bytes_ptr = @ptrCast([*]u8, @alignCast(@alignOf(u8), &table[0]));

    try file.seekTo(offset);
    try file.reader().readNoEof(bytes_ptr[0..sz]);
    
    return table;
}

fn readImageId(file: *std.fs.File, info: *TgaInfo, extents: *ExtentBuffer) !void {
    try file.seekTo(tga_header_sz);

    if (info.header.info.id_length == 0) {
        return;
    }

    const id_start = tga_header_sz;
    const id_end = id_start + info.header.info.id_length;
    if (id_end > info.file_sz) {
        return ImageError.UnexpectedEOF;
    }
    if (extentOverlap(extents, id_start, id_end)) {
        return ImageError.OverlappingData;
    }
    extents.append(BlockExtent{ .begin=id_start, .end=id_end });

    try file.reader().readNoEof(info.id[0..info.header.info.id_length]);
}

pub fn typeSupported(image_type: TgaImageType) bool {
    return switch(image_type) {
        .NoData => false,
        .ColorMap => true,
        .TrueColor => true,
        .Greyscale => true,
        .RleColorMap => true,
        .RleTrueColor => true,
        .RleGreyscale => true,
        .HuffmanDeltaRleColorMap => false,
        .HuffmanDeltaRleQuadtreeColorMap => false,
    };
}

fn readColorMapData(file: *std.fs.File, info: *TgaInfo, extents: *ExtentBuffer) !void {
    _ = file;
    _ = extents;

    switch(info.header.info.image_type) {
        .NoData, .TrueColor, .Greyscale, .RleTrueColor, .RleGreyscale => {
            if (info.header.colormap_spec.entry_bit_ct != 0
                or info.header.colormap_spec.first_idx != 0
                or info.header.colormap_spec.len != 0
            ) {
                return ImageError.TgaColorMapDataInNonColorMapImage;
            }
        },
        .ColorMap, .RleColorMap => {

        },
        else => unreachable,
    }
}

fn freeAllocations(info: *TgaInfo, allocator: std.mem.Allocator) void {
    if (info.scanline_table != null) {
        allocator.free(info.scanline_table.?);
    }
    if (info.postage_stamp_table != null) {
        allocator.free(info.postage_stamp_table.?);
    }
    if (info.color_correction_table != null) {
        allocator.free(info.color_correction_table.?);
    }
}

fn extentOverlap(extents: *const ExtentBuffer, begin: u32, end: u32) bool {
    for (extents.*.constItems()) |extent| {
        if ((begin >= extent.begin and begin < extent.end)
            or (end > extent.begin and end <= extent.end)
        ) {
            return true;
        }
    }
    return false;
}

pub const TgaImageType = enum(u8) {
    NoData = 0,
    ColorMap = 1,
    TrueColor = 2,
    Greyscale = 3,
    RleColorMap = 9,
    RleTrueColor = 10,
    RleGreyscale = 11,
    HuffmanDeltaRleColorMap = 32,
    HuffmanDeltaRleQuadtreeColorMap = 33,
};

const TgaColorMapSpec = extern struct {
    first_idx: u16,
    len: u16,
    entry_bit_ct: u8,
};

const TgaImageSpec = extern struct {
    origin_x: u16,
    origin_y: u16,
    image_width: u16,
    image_height: u16,
    color_depth: u8,
    descriptor: u8
};

const TgaHeaderInfo = extern struct {
    id_length: u8,
    color_map_type: u8,
    image_type: TgaImageType,
};

const TgaHeader = extern struct {
    info: TgaHeaderInfo,
    colormap_spec: TgaColorMapSpec,
    image_spec: TgaImageSpec,
};

const ExtensionArea = extern struct {
    extension_sz: u16 = 0,
    author_name: [41]u8 = undefined,
    author_comments: [324]u8 = undefined,
    timestamp: [6]u16 = undefined,
    job_name: [41]u8 = undefined,
    job_time: [3]u16 = undefined,
    software_id: [41]u8 = undefined,
    software_version: [3]u8 = undefined,
    key_color: u32 = undefined,
    pixel_aspect_ratio: [2]u16 = undefined,
    gamma: [2]u16 = undefined,
    color_correction_offset: u32 = undefined,
    postage_stamp_offset: u32 = undefined,
    scanline_offset: u32 = undefined,
    attributes_type: u8 = undefined,
};

const TgaFooter = extern struct {
    extension_area_offset: u32,
    developer_directory_offset: u32,
    signature: [16]u8
};

const TgaInfo = struct {
    id: [256]u8 = std.mem.zeroes([256]u8),
    file_type: TgaFileType = .None,
    file_sz: u32 = 0,
    header: TgaHeader = undefined,
    extension_area: ?ExtensionArea = null,
    footer: ?TgaFooter = null,
    scanline_table: ?[]u32 = null,
    postage_stamp_table: ?[]u8 = null,
    color_correction_table: ?[]ARGB64 = null,
};

const BlockExtent = struct {
    begin: u32,
    end: u32,
};

const TgaFileType = enum(u8) { None, V1, V2 };
const ExtentBuffer = LocalBuffer(BlockExtent, 10);

const tga_header_sz = 18;
const tga_image_spec_offset = 8;
const tga_min_sz = @sizeOf(TgaHeader);
const footer_end_offset = @sizeOf(TgaFooter) + 2;
const tga_signature = "TRUEVISION-XFILE";
const extension_area_file_sz = 495;
const color_correction_table_sz = @sizeOf(ARGB64) * 256;