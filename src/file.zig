
const std = @import("std");
const memory = @import("memory.zig");

const FileError = error{
    TooLarge,
    PartialRead
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn loadBytes(file: *std.fs.File, allocator: memory.Allocator, alignment: anytype) ![]u8 {
    const stat = try file.stat();
    if (stat.size > memory.MAX_SZ) {
        return FileError.TooLarge;
    }

    var buffer: []u8 = undefined;
    if (alignment.len > 0) {
        buffer = try allocator.allocExplicitAlign(u8, stat.size, alignment[0]);
    }
    else {
        buffer = try allocator.allocExplicitAlign(u8, stat.size, 1);
    }

    const bytes_read: usize = try file.reader().readAll(buffer);

    if (bytes_read != stat.size) {
        return FileError.PartialRead;
    }

    return buffer;
}

