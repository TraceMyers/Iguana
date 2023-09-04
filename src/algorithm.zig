const std = @import("std");
const print = std.debug.print;
const memory = @import("memory.zig");
const Prng = std.rand.DefaultPrng;

// hashing requires string lengths to be <= 38 chars
pub fn ctHash(comptime str: []const u8) AlgorithmError!u64 {
    if (str.len == 0) {
        return AlgorithmError.StrSizeZeroUnhashable;
    }
    if (str.len > 38) {
        return AlgorithmError.StrSizeGreaterThan38UnsafeToHash;
    }

    var remainder_start: usize = 0;
    var remainder_ct: usize = 0;
    var code: u64 = 13;
    const base: u64 = 11;

    if (str.len > 4) {
        const block_ct: usize = str.len >> 2;
        remainder_start = block_ct << 2;
        const blocks: []const u32 = @ptrCast([*]const u32, @alignCast(@alignOf(u32), &str[0]))[0..block_ct];

        for (blocks) |block| {
            code = (code * base) + @as(u64, block);
        }
        remainder_ct = str.len - remainder_start;
    }
    else {
        remainder_ct = str.len;
    }

    const remainder: []const u8 = str[remainder_start..remainder_start + remainder_ct];
    var block: u32 = 0;
    var shift: u5 = 24;
    for (0..remainder_ct) |i| {
        block |= @intCast(u32, remainder[i]) << shift;
        shift -= 8;
    }
    
    return (code * base) + block;
}

pub fn rtHash(str: []const u8) AlgorithmError!u64 {
    if (str.len == 0) {
        return AlgorithmError.StrSizeZeroUnhashable;
    }
    if (str.len > 38) {
        return AlgorithmError.StrSizeGreaterThan38UnsafeToHash;
    }

    var remainder_start: usize = 0;
    var remainder_ct: usize = 0;
    var code: u64 = 13;
    const base: u64 = 11;

    if (str.len > 4) {
        const block_ct: usize = str.len >> 2;
        remainder_start = block_ct << 2;
        const blocks: []const u32 = @ptrCast([*]const u32, @alignCast(@alignOf(u32), &str[0]))[0..block_ct];

        for (blocks) |block| {
            code = (code * base) + @as(u64, block);
        }
        remainder_ct = str.len - remainder_start;
    }
    else {
        remainder_ct = str.len;
    }

    const remainder: []const u8 = str[remainder_start..remainder_start + remainder_ct];
    var block: u32 = 0;
    var shift: u5 = 24;
    for (0..remainder_ct) |i| {
        block |= @intCast(u32, remainder[i]) << shift;
        if (i < 3) {
            shift -= 8;
        }
    }
    
    return (code * base) + block;
}

pub const HashTableNode = struct {
    hash: u64,
    left: u32,
    right: u32
};

const HashTable = struct {
    nodes: []HashTableNode,
    allocator: memory.Allocator,
    root: u32,
    node_ct: u32,
    
    pub fn new(comptime e: memory.Enclave, start_ct: u32) !HashTable {
        std.debug.assert(start_ct > 0);
        var in_alloc = memory.Allocator.new(e);
        return HashTable {
            .nodes = try in_alloc.alloc(HashTableNode, start_ct),
            .allocator = in_alloc,
            .root = 0,
            .node_ct = 0,
        };
    }

    pub fn add(self: *HashTable, hash: u64) !void {
        if (self.node_ct == self.nodes.len) {
            // TODO: realloc
            // var new_nodes = allocator.
        }
        _ = hash;
    }

};

const AlgorithmError = error {
    StrSizeZeroUnhashable,
    StrSizeGreaterThan38UnsafeToHash,
};

test "not a total failure [algorithm]" {
    const hash0 = try ctHash("hello");
    const hash1 = try ctHash("hello world");
    const hash2 = try ctHash("hello sailor");
    const hash3 = try ctHash("hello");
    const hash4 = try ctHash("\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");
    // _ = hash4; // doesn't cause integer overflow
    print("hash 4: {}\n", .{hash4});

    try std.testing.expect(hash0 != hash1 and hash2 != hash1 and hash2 != hash3 and hash0 == hash3);
}

// test "small str collision [algorithm]" {
//     try memory.autoStartup();
//     defer memory.shutdown();
//     const allocator = memory.Allocator.new(memory.Enclave.Game);
//     var rand = Prng.init(0);

//     const test_set_ct: u32 = 8192;
//     var test_set: []u64 = try allocator.alloc(u64, test_set_ct);
//     var buf: [32]u8 = undefined;

//     for (0..test_set_ct) |i| {
//         const strlen: u32 = rand.random().intRangeLessThan(u32, 1, 33);
//         var str = buf[0..strlen];
//         for (0..strlen) |j| {
//             str[j] = rand.random().intRangeLessThan(u8, '0', 'z' + 1);
            
//         }
//         test_set[i] = try rtHash(str);
//     }

//     var same_ct: i64 = 0;
//     for (1..4) |strlen| {
//         var str = buf[0..strlen];
//         for (0..strlen) |i| {
//             str[i] = '0';
//         }
//         var rollover_ct: u32 = 0;
//         while (rollover_ct < str.len) {
//             const hash = try rtHash(str);
//             for (0..test_set_ct) |i| {
//                 if (hash == test_set[i]) {
//                     same_ct += 1;
//                 }
//             }

//             rollover_ct = 0;
//             for (0..strlen) |i| {
//                 if (str[i] < 'z') {
//                     str[i] += 1;
//                     break;
//                 }
//                 str[i] = '0';
//                 rollover_ct += 1;
//             }
//         }
//     }
//     print("same ct: {}, est collision ct: {}\n", .{same_ct, same_ct - (@intCast(i64, test_set_ct) / 32 * 3)});
// }

test "hashtable [algorithm]" {
    try memory.autoStartup();
    defer memory.shutdown();

    var k = try HashTable.new(memory.Enclave.Game, 32);
    _ = k;
}
