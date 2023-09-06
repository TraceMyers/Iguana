// TODO: delete this file and switch to std implementation

const std = @import("std");

const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn LocalArray(comptime ItemType: type, comptime buflen: usize) type {

    assert(buflen > 0);

    return struct {
        const Self = @This();

        buffer: [buflen]ItemType = undefined,
        items: []ItemType = undefined,

        pub inline fn new() Self {
            var self = Self{};
            self.items = self.buffer[0..0];
            return self;
        }

        // get a c-style pointer to many @ this array's items.
        pub fn cptr(self: *Self) [*c]ItemType {
            return &self.buffer[0];
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ------------------------------------------------------------------------------------------ general operations
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        
        pub inline fn zeroItems(self: *Self) void {
            @memset(self.items, std.mem.zeroes(ItemType));
        }

        // set any non-default values within all structs in the array to 0 and set the count to the
        pub fn zeroDefaultItems(self: *Self) void {
            for (self.items) |*item| {
                item.* = std.mem.zeroInit(ItemType, .{});
            }
        }

        pub inline fn setItems(self: *Self, item: ItemType) void {
            @memset(self.items, item);
        }

        pub inline fn zeroFill(self: *Self) void {
            self.items.len = buflen;
            self.zeroItems();
        }

        pub inline fn zeroDefaultFill(self: *Self) void {
            self.items.len = buflen;
            self.zeroDefaultItems();
        }

        // // fill the array with this value and set the count to the size (max count)
        pub inline fn fill(self: *Self, fill_item: ItemType) void {
            self.items.len = buflen;
            @memset(self.buffer[0..buflen], fill_item);
        }

        // // get the number of items on the array
        pub inline fn len(self: *const Self) usize {
            return self.items.len;
        }

        pub inline fn capacity() usize {
            return buflen;
        }

        // // set the count to new_ct
        pub inline fn resize(self: *Self, new_len: usize) void {
            assert(new_len <= buflen);
            self.items.len = new_len;
        }

        pub inline fn expandToCapacity(self: *Self) void {
            self.items.len = buflen;
        }

        // // set the count to 0
        pub inline fn clear(self: *Self) void {
            self.items.len = 0;
        }

        // // push an item onto the array and increase the count.
        pub inline fn append(self: *Self, new_item: ItemType) void {
            assert(self.items.len < buflen);
            self.buffer[self.items.len] = new_item;
            self.items.len += 1;
        }

        // // get the last item on the array and decrease the count.
        pub inline fn pop(self: *Self) ItemType {
            assert(self.items.len > 0);
            self.items.len -= 1;
            return self.buffer[self.items.len];
        }

        pub fn popOrNull(self: *Self) ?ItemType {
            if (self.items.len == 0) {
                return null;
            }
            return self.pop();
        }

        pub inline fn getLast(self: *Self) ItemType {
            assert(self.ct > 0);
            return self.items[self.ct - 1];
        }

        pub fn getLastOrNull(self: *Self) ?ItemType {
            if (self.items.len == 0) {
                return null;
            }
            return self.getLast();
        }

        // // remove the item at this index (order is not retained).
        pub inline fn swapRemove(self: *Self, idx: usize) void {
            assert(idx < self.items.len);
            self.items.len -= 1;
            self.buffer[idx] = self.buffer[self.items.len];
        }

        // // remove the item at this index while retaining order.
        pub fn orderedRemove(self: *Self, idx: usize) void {
            assert(idx < self.items.len);
            self.items.len -= 1;
            for (idx..self.items.len) |i| {
                self.buffer[i] = self.buffer[i + 1];
            }
        }

        // // given a pointer to an item, remove the item from the array (order is not retained).
        pub inline fn itemRemove(self: *Self, item: *const ItemType) void {
            const idx = self.indexOf(item);
            self.swapRemove(idx);
        }

        // // given a pointer to an item, remove the item from the array while retaining order.
        pub inline fn orderedItemRemove(self: *Self, item: *const ItemType) void {
            const idx = self.indexOf(item);
            self.orderedRemove(idx);
        }

        // // get the index of this item within the array. if you have a pointer to a value in the array, using this is
        // // preferable to find...() functions, since the index can be derived from the item's address.
        pub fn indexOf(self: *const Self, array_item: *const ItemType) usize {
            const array_address = @intCast(i64, @ptrToInt(&self.buffer[0]));
            const item_address = @intCast(i64, @ptrToInt(array_item));
            const item_diff = item_address - array_address;
            const idx = @divExact(item_diff, @intCast(i64, @sizeOf(ItemType)));
            assert(idx >= 0 and idx < self.ct);
            return @intCast(usize, idx);
        }

        // // for types comparable with ==. find the index of an equal value.
        pub fn find(self: *const Self, item: ItemType) ?usize {
            for (0..self.items.len) |idx| {
                if (std.meta.eql(self.items[idx], item)) {
                    return idx;
                }
            }
            return null;
        }

        // // for types comparable with ==. find the index of an equal value, starting from the end.
        pub fn findReverse(self: *const Self, item: ItemType) ?usize {
            var idx = self.items.len - 1;
            while (idx >= 0) : (idx -= 1) {
                if (std.meta.eql(self.items[idx], item)) {
                    return idx;
                }
            }
            return null;
        }
    };
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- test
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const TestStruct = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    someval: u32 = 0,

    pub fn new() TestStruct {
        return TestStruct{};
    }

    pub inline fn _id(self: *const TestStruct) u32 {
        return self.someval;
    }

    pub inline fn _matches(self: *const TestStruct, other: *const TestStruct) bool {
        return self.x == other.x and self.y == other.y and self.someval == other.someval;
    }
};

test "new structure [array]" {
    var arr = LocalArray(u32, 10).new();
    arr.expandToCapacity();
    arr.items[1] = 8;
    arr.zeroItems();
    arr.setItems(18);
    // arr.zeroFill();
    // arr.fill(8);
    print("{any}\n", .{arr});
    print("{*}, {*}\n", .{&arr.buffer[0], arr.items.ptr});
}

// test "remove all by id" {
//     var array = LocalArray(TestStruct, 128).new();

//     array.push(TestStruct{ .someval = 1 }); // 0
//     array.push(TestStruct{ .someval = 1 });
//     array.push(TestStruct{ .someval = 1 });
//     array.push(TestStruct{ .someval = 1 });
//     array.push(TestStruct{ .someval = 1 });
//     array.push(TestStruct{ .someval = 1 });
//     array.push(TestStruct{ .someval = 1 }); // .. 6

//     array.push(TestStruct{ .someval = 2 }); // 7
//     array.push(TestStruct{ .someval = 2 });
//     array.push(TestStruct{ .someval = 2 });
//     array.push(TestStruct{ .someval = 2 });
//     array.push(TestStruct{ .someval = 2 });
//     array.push(TestStruct{ .someval = 2 }); // ..12

//     array.push(TestStruct{ .someval = 3 }); // 13
//     array.push(TestStruct{ .someval = 3 });
//     array.push(TestStruct{ .someval = 3 });
//     array.push(TestStruct{ .someval = 3 });
//     array.push(TestStruct{ .someval = 3 }); // ..17

//     array.push(TestStruct{ .someval = 4 }); // 18
//     array.push(TestStruct{ .someval = 4 });
//     array.push(TestStruct{ .someval = 4 });
//     array.push(TestStruct{ .someval = 4 }); // ..21

//     array.push(TestStruct{ .someval = 5 }); // 22
//     array.push(TestStruct{ .someval = 5 });
//     array.push(TestStruct{ .someval = 5 }); // .. 24

//     array.push(TestStruct{ .someval = 4 }); // 25
//     array.push(TestStruct{ .someval = 4 });
//     array.push(TestStruct{ .someval = 4 });
//     array.push(TestStruct{ .someval = 4 }); // ..28

//     var removed_item_ct = array.idRemoveAnyOrdered(4);

//     try expect(removed_item_ct == 8);
//     try expect(array.count() == 7 + 6 + 5 + 3);

//     var i: usize = 0;
//     while (i < array.count()) : (i += 1) {
//         if (i < 7) {
//             try expect(array.items[i]._id() == 1);
//         } else if (i < 13) {
//             try expect(array.items[i]._id() == 2);
//         } else if (i < 18) {
//             try expect(array.items[i]._id() == 3);
//         } else {
//             try expect(array.items[i]._id() == 5);
//         }
//     }
// }

// test "fill with struct" {
//     const t = TestStruct {.x = 1.5, .y = 3.999};

//     var array = LocalArray(TestStruct, 32).new();
//     array.fill(t);

//     try expect(array.count() == 32);
//     for (array.items) |item| {
//         try expect(item.x == 1.5);
//         try expect(item.y == 3.999);
//     }
// }

// test "remove at" {
//     var array = LocalArray(i64, 32).new();

//     for (0..array.size()) |i| {
//         array.push(@intCast(i64, i));
//     }

//     array.removeAtOrdered(0); // removing 0
//     array.removeAtOrdered(30); // removing 31
//     array.removeAtOrdered(14); // removing 15
//     array.removeAtOrdered(13); // removing 14

//     try expect(array.count() == 28);

//     for (0..array.count()) |i| {
//         if (i < array.count() - 1) {
//             try expect(array.items[i] < array.items[i + 1]);
//         }
//         try expect(array.items[i] != 0);
//         try expect(array.items[i] != 31);
//         try expect(array.items[i] != 15);
//         try expect(array.items[i] != 14);
//     }

//     array.removeAt(array.count() - 1); // removing 30
//     array.removeAt(0); // removing 1
//     array.removeAt(3); // removing 4

//     try expect(array.count() == 25);

//     for (0..array.count()) |i| {
//         try expect(array.items[i] != 0);
//         try expect(array.items[i] != 31);
//         try expect(array.items[i] != 15);
//         try expect(array.items[i] != 14);
//         try expect(array.items[i] != 1);
//         try expect(array.items[i] != 4);
//         try expect(array.items[i] != 30);
//     }

//     var i: usize = 0;
//     while (i < 25) : (i += 1) {
//         array.removeAt(0);
//     }

//     try expect(array.count() == 0);
// }
