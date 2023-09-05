
const std = @import("std");
const memory = @import("memory.zig");

const FileError = error{
    TooLarge,
    PartialRead
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadBytes(file: *std.fs.File, allocator: std.mem.Allocator, alignment: anytype) ![]u8 {
    const stat = try file.stat();
    if (stat.size > memory.MAX_SZ) {
        return FileError.TooLarge;
    }

    var buffer: []u8 = undefined;
    if (alignment.len > 0) {
        buffer = allocator.alignedAlloc(u8, alignment[0], stat.size);
    }
    else {
        buffer = allocator.alloc(u8, stat.size);
    }

    const bytes_read: usize = try file.reader().readAll(buffer);

    if (bytes_read != stat.size) {
        return FileError.PartialRead;
    }

    return buffer;
}

