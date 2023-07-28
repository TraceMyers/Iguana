// TODO: vector intrinsics

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

const to_lower_diff: u8 = 'a' - 'A';
const std = @import("std");
const mem6 = @import("mem6.zig");
