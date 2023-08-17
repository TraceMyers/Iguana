// TODO: vector intrinsics

pub fn LocalStringBuffer(comptime sz: comptime_int) type {

    return struct {
        const LSBufType = @This();

        bytes: [sz]u8 = undefined,
        len: usize = 0,
        prev_len: usize = 0,

        pub inline fn new() LSBufType {
            return LSBufType{};
        }

        pub fn append(self: *LSBufType, append_str: []const u8) StringError!void {
            const new_len = self.len + append_str.len;
            if (new_len > sz) {
                return StringError.BufferTooShort;
            }
            @memcpy(self.bytes[self.len..new_len], append_str[0..append_str.len]);
            self.prev_len = self.len;
            self.len = new_len;
        }

        pub fn setToPreviousLength(self: *LSBufType) void {
            self.len = self.prev_len;
        }

        pub inline fn string(self: *const LSBufType) []const u8 {
            return self.bytes[0..self.len];
        }

    };
}

pub fn equal(a: []const u8, b: []const u8) bool {
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
pub fn equalCount(a: []const u8, b: []const u8) usize {
    var eql_ct: usize = 0;
    for (0..@min(a.len, b.len)) |i| {
        if (a[i] != b[i]) { 
            break;
        }
        eql_ct += 1;
    }
    return eql_ct;
}

pub inline fn substrR(str: []const u8, idx: usize) []const u8 {
    return str[idx..];
}

pub inline fn substrL(str: []const u8, idx: usize) []const u8 {
    return str[0..idx];
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
pub inline fn copy(str: []const u8, allocator: *mem6.Allocator) ![]u8 {
    var new_str: []u8 = try allocator.alloc(u8, str.len);
    @memcpy(new_str[0..str.len], str[0..str.len]);
    return new_str;
}

pub fn copyLower(str: []const u8, allocator: *mem6.Allocator) ![]u8 {
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
    else @memcpy(buffer[0..str.len], str[0..str.len]);
}

pub fn copyLowerToBuffer(str: []const u8, buffer: []u8) StringError!void {
    if (buffer.len < str.len) {
        return StringError.BufferTooShort;
    }
    for (0..str.len) |i| {
        if (str[i] >= 'A' and str[i] <= 'Z') {
            buffer[i] = str[i] + to_lower_diff;
        }
        else {
            buffer[i] = str[i];
        }
    }
}

pub inline fn free(str: []u8, allocator: *mem6.Allocator) void {
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

const to_lower_diff: u8 = 'a' - 'A';
const std = @import("std");
const mem6 = @import("mem6.zig");
