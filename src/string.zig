// TODO: vector intrinsics

const std = @import("std");
const memory = @import("memory.zig");

pub fn LocalStringBuffer(comptime sz: comptime_int) type {

    return struct {
        const LSBufType = @This();

        bytes: [sz]u8 = undefined,
        len: usize = 0,
        prev_len: usize = 0,

        pub inline fn new() LSBufType {
            return LSBufType{};
        }

        pub inline fn append(self: *LSBufType, append_str: []const u8) StringError!void {
            const new_len = self.len + append_str.len;
            try copyToBuffer(append_str, self.bytes[self.len..]);
            self.prev_len = self.len;
            self.len = new_len;
        }

        pub inline fn appendLower(self: *LSBufType, append_str: []const u8) StringError!void {
            const new_len = self.len + append_str.len;
            try copyLowerToBuffer(append_str, self.bytes[self.len..]);
            self.prev_len = self.len;
            self.len = new_len;
        }

        pub inline fn replace(self: *LSBufType, replace_str: []const u8) StringError!void {
            const new_len = replace_str.len;
            try copyToBuffer(replace_str, self.bytes[0..new_len]);
            self.prev_len = self.len;
            self.len = new_len;
        }

        pub inline fn setToPrevLen(self: *LSBufType) void {
            self.len = self.prev_len;
        }

        pub inline fn string(self: *const LSBufType) []const u8 {
            return self.bytes[0..self.len];
        }

    };
}

pub fn same(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    for (0..a.len) |i| {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

// returns how many characters are equal, starting from the beginning
pub fn sameCount(a: []const u8, b: []const u8) usize {
    var eql_ct: usize = 0;
    for (0..@min(a.len, b.len)) |i| {
        if (a[i] != b[i]) { 
            break;
        }
        eql_ct += 1;
    }
    return eql_ct;
}

pub fn sameTail(a: []const u8, b: []const u8) bool {
    if (a.len < b.len) {
        const b_start = b.len - a.len;
        const b_end = b[b_start..];
        for (0..a.len) |i| {
            if (a[i] != b_end[i]) {
                return false;
            }
        }
        return true;
    }
    else {
        const a_start = a.len - b.len;
        const a_end = a[a_start..];
        for (0..b.len) |i| {
            if (a_end[i] != b[i]) {
                return false;
            }
        }
        return true;
    }
}

pub inline fn sameHead(a: []const u8, b: []const u8) bool {
    for (0..@min(a.len, b.len)) |i| {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

pub inline fn findL(str: []const u8, token: u8) ?usize {
    for (0..str.len) |i| {
        if (str[i] == token) {
            return i;
        }
    }
    return null;
}

pub inline fn findR(str: []const u8, token: u8) ?usize {
    var i: usize = str.len - 1;
    while (i >= 0) : (i -= 1) {
        if (str[i] == token) {
            return i;
        }
    }
    return null;
}

// TODO: generalized copy
pub inline fn copy(str: []const u8, allocator: *memory.Allocator) ![]u8 {
    var new_str: []u8 = try allocator.alloc(u8, str.len);
    @memcpy(new_str[0..str.len], str[0..str.len]);
    return new_str;
}

pub fn copyLower(str: []const u8, allocator: *memory.Allocator) ![]u8 {
    var new_str: []u8 = try allocator.alloc(u8, str.len);
    for (0..str.len) |i| {
        if (str[i] >= 'A' and str[i] <= 'Z') {
            new_str[i] = str[i] + to_lower_diff;
        }
        else {
            new_str[i] = str[i];
        }
    }
    return new_str;
}

pub inline fn copyToBuffer(str: []const u8, buffer: []u8) StringError!void {
    if (buffer.len < str.len) {
        return StringError.BufferTooShort;
    }
    @memcpy(buffer[0..str.len], str[0..str.len]);
}

pub fn copyLowerToBuffer(str: []const u8, buffer: []u8) StringError!void {
    if (buffer.len < str.len) {
        return StringError.BufferTooShort;
    }
    for (0..str.len) |i| {
        const char = str[i];
        if (char >= 'A' and char <= 'Z') {
            buffer[i] = char + to_lower_diff;
        }
        else {
            buffer[i] = char;
        }
    }
}

pub inline fn free(str: []u8, allocator: *memory.Allocator) void {
    allocator.free(str);
}

pub fn toLower(str: []u8) void {
    for (str) |*char| {
        if (char.* >= 'A' and char.* <= 'Z') {
            char.* += to_lower_diff;
        }
    }
}

const StringError = error{
    BufferTooShort,
};

const to_lower_diff: comptime_int = 'a' - 'A';
