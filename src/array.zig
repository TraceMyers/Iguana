// TODO: finish Array types

pub const ArrayType = enum {
    Local,
    Heap,
    Resize
};

pub fn LocalArray(comptime ItemType: type, comptime length: usize) type {
    return Array(ArrayType.Local, ItemType, length);
}

pub fn HeapArray(comptime ItemType: type) type {
    return Array(ArrayType.Heap, ItemType, 0);
}

pub fn ResizeArray(comptime ItemType: type) type {
    return Array(ArrayType.Resize, ItemType, 0);
}

pub fn Array(comptime array_type: ArrayType, comptime ItemType: type, comptime length: usize) type {

    const is_local = array_type == ArrayType.Local;
    if (is_local) {
        assert(length > 0);
    }

    return struct {
        const Self = @This();

        items: if (is_local) [length]ItemType else []ItemType = undefined,
        allocator: if (is_local) void else *mem6.Allocator = undefined, 
        ct: usize = 0,

        inline fn newLocal() Self {
            return Self{};
        }

        inline fn newHeap(allocator: *mem6.Allocator, init_length: usize) !Self {
            assert(init_length > 0);
            return Self{
                .items = try allocator.alloc(ItemType, init_length),
                .allocator = allocator
            };
        }

        inline fn newResize(allocator: *mem6.Allocator, init_length: usize) !Self {
            if (init_length > 0) {
                return Self{
                    .items = try allocator.alloc(ItemType, init_length),
                    .allocator = allocator
                };
            }
            else {
                return Self{.allocator=allocator};
            }
        }

        pub const new = switch(array_type) {
            ArrayType.Local => newLocal,
            ArrayType.Heap=> newHeap,
            ArrayType.Resize => newResize,
        };

        // get a c-style pointer to many @ this array's items.
        pub inline fn cptr(self: *Self) [*c]ItemType {
            return &self.items[0];
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ------------------------------------------------------------------------------------------ general operations
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        
        inline fn freeHeapResize(self: *Self) void {
            self.allocator.free(self.items);
        }

        pub const free = switch(array_type) {
            ArrayType.Local => undefined,
            ArrayType.Heap, ArrayType.Resize => freeHeapResize,
        };

        // fill the array with zeroes and set the count to the size (max count)
        pub inline fn zero(self: *Self) void {
            @memset(&self.items, 0);
            self.ct = self.items.len;
        }

        // for structs. set all values within all structs in the array to 0, ignoring default values, and set the count
        // to the size (max count)
        pub inline fn sZero(self: *Self) void {
            for (0..self.items.len) |idx| {
                self.items[idx] = std.mem.zeroes(ItemType);
            }
            self.ct = self.items.len;
        }

        // for structs. set any non-default values within all structs in the array to 0 and set the count to the
        // size (max count)
        pub inline fn sZeroDefault(self: *Self) void {
            for (0..self.items.len) |idx| {
                self.items[idx] = std.mem.zeroInit(ItemType, .{});
            }
            self.ct = self.items.len;
        }

        // fill the array with this value and set the count to the size (max count)
        pub inline fn fill(self: *Self, fill_item: ItemType) void {
            @memset(&self.items, fill_item);
            self.ct = self.items.len;
        }

        // get the number of items on the array
        pub inline fn count(self: *const Self) usize {
            return self.ct;
        }

        // get the size (max count) of the array as a usize
        pub inline fn size(self: *const Self) usize {
            return self.items.len;
        }

        // set the count to new_ct
        pub inline fn setCount(self: *Self, new_ct: usize) void {
            assert(new_ct <= self.items.len);
            self.ct = new_ct;
        }

        // set the count to 0
        pub inline fn resetCount(self: *Self) void {
            self.ct = 0;
        }

        // push an item onto the array and increase the count.
        pub inline fn push(self: *Self, new_item: ItemType) void {
            assert(self.ct < self.items.len);
            self.items[self.ct] = new_item;
            self.ct += 1;
        }

        // get the last item on the array and decrease the count.
        pub inline fn pop(self: *Self) ItemType {
            assert(self.ct > 0);
            self.ct -= 1;
            return self.items[self.ct];
        }

        pub inline fn top(self: *Self) *ItemType {
            assert(self.ct > 0);
            return &self.items[self.ct - 1];
        }

        // swap items at these indices.
        pub inline fn swap(self: *Self, idx_a: usize, idx_b: usize) void {
            assert(idx_a < self.ct and idx_b < self.ct);
            const temp: ItemType = self.items[idx_a];
            self.items[idx_a] = self.items[idx_b];
            self.items[idx_b] = temp;
        }

        // remove the item at this index (order is not retained).
        pub inline fn removeAt(self: *Self, idx: usize) void {
            assert(idx < self.ct);
            self.ct -= 1;
            if (idx < self.ct) {
                self.items[idx] = self.items[self.ct];
            }
        }

        // remove the item at this index while retaining order.
        pub inline fn removeAtOrdered(self: *Self, idx: usize) void {
            assert(idx < self.ct);
            self.ct -= 1;
            for (idx..self.ct) |array_idx| {
                self.items[array_idx] = self.items[array_idx + 1];
            }
        }

        // for types comparable with ==. remove all items with equal value (order is not retained).
        pub fn removeAny(self: *Self, item: ItemType) usize {
            var new_ct = self.ct;
            var idx: usize = 0;

            while (idx < new_ct) {
                if (self.items[idx] == item) {
                    new_ct -= 1;
                    self.items[idx] = self.items[new_ct];
                } else {
                    idx += 1;
                }
            }

            const items_removed = self.ct - new_ct;
            self.ct = new_ct;
            return items_removed;
        }

        // for types comparable with ==. remove all items with equal value and retain order.
        pub fn removeAnyOrdered(self: *Self, item: ItemType) usize {
            var to_idx: usize = 0;
            var from_idx: usize = 0;

            while (to_idx < self.ct) : (to_idx += 1) {
                if (self.items[to_idx] == item) {
                    from_idx = to_idx + 1;
                    while (from_idx < self.ct) : (from_idx += 1) {
                        if (self.items[from_idx] != item) {
                            break;
                        }
                    }
                    break;
                }
            }

            if (to_idx < self.ct) {
                if (from_idx != self.ct) {
                    while (from_idx < self.ct) {
                        self.items[to_idx] = self.items[from_idx];
                        from_idx += 1;
                        to_idx += 1;
                        while (self.items[from_idx] == item) {
                            from_idx += 1;
                        }
                    }
                }

                const items_removed = from_idx - to_idx;
                self.ct = to_idx;
                return items_removed;
            }

            return 0;
        }

        // for types comparable with ==. find and item with equal value and remove it once (order is not retained).
        pub fn removeOnce(self: *Self, item: ItemType) bool {
            var idx: usize = 0;
            while (idx < self.ct) : (idx += 1) {
                if (self.items[idx] == item) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        self.items[idx] = self.items[self.ct];
                    }
                    return true;
                }
            }
            return false;
        }

        // for types comparable with ==. find and item with equal value and remove it once while retaining order.
        pub fn removeOnceOrdered(self: *Self, item: ItemType) bool {
            for (0..self.ct) |idx| {
                if (self.items[idx] == item) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        for (idx..self.ct) |cpy_idx| {
                            self.items[cpy_idx] = self.items[cpy_idx + 1];
                        }
                    }
                    return true;
                }
            }
            return false;
        }

        // given a pointer to an item, remove the item from the array (order is not retained).
        pub inline fn removeItem(self: *Self, item: *const ItemType) void {
            const idx = self.indexOf(item);
            self.removeAt(idx);
        }

        // given a pointer to an item, remove the item from the array while retaining order.
        pub inline fn removeItemOrdered(self: *Self, item: *const ItemType) void {
            const idx = self.indexOf(item);
            self.removeAtOrdered(idx);
        }

        // get the index of this item within the array. if you have a pointer to a value in the array, using this is
        // preferable to find...() functions, since the index can be derived from the item's address.
        pub fn indexOf(self: *const Self, array_item: *const ItemType) usize {
            const array_address = @intCast(i64, @ptrToInt(&self.items[0]));
            const item_address = @intCast(i64, @ptrToInt(array_item));
            const item_diff = item_address - array_address;
            const idx = @divTrunc(item_diff, @intCast(i64, @sizeOf(ItemType)));
            assert(idx >= 0 and idx < self.ct);
            return @intCast(usize, idx);
        }

        // for types comparable with ==. find the index of an equal value.
        pub inline fn find(self: *const Self, item: ItemType) ?usize {
            for (0..self.ct) |idx| {
                if (self.items[idx] == item) {
                    return idx;
                }
            }
            return null;
        }

        // for types comparable with ==. find the index of an equal value, starting from the end.
        pub inline fn findReverse(self: *const Self, item: ItemType) ?usize {
            var idx = self.ct;
            while (idx >= 0) : (idx -= 1) {
                if (self.data[idx] == item) {
                    return idx;
                }
            }
            return null;
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // -------------------------------------------------------------------------------------------- by-id operations
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // for structs with an id member function. remove one all structs with a matching id (order is not retained).
        pub fn idRemoveAny(self: *Self, find_id: u32) usize {
            var new_ct = self.ct;
            var idx: usize = 0;

            while (idx < new_ct) {
                if (self.items[idx]._id() == find_id) {
                    new_ct -= 1;
                    self.items[idx] = self.items[new_ct];
                } else {
                    idx += 1;
                }
            }

            const items_removed = self.ct - new_ct;
            self.ct = new_ct;
            return items_removed;
        }

        // for structs with an id member function. remove all structs with a matching id whie retaining order.
        pub fn idRemoveAnyOrdered(self: *Self, find_id: u32) usize {
            var to_idx: usize = 0;
            var from_idx: usize = 0;

            while (to_idx < self.ct) : (to_idx += 1) {
                if (self.items[to_idx]._id() == find_id) {
                    from_idx = to_idx + 1;
                    while (from_idx < self.ct) : (from_idx += 1) {
                        if (self.items[from_idx]._id() != find_id) {
                            break;
                        }
                    }
                    break;
                }
            }

            if (to_idx < self.ct) {
                if (from_idx != self.ct) {
                    while (from_idx < self.ct) {
                        self.items[to_idx] = self.items[from_idx];
                        from_idx += 1;
                        to_idx += 1;
                        while (self.items[from_idx]._id() == find_id) {
                            from_idx += 1;
                        }
                    }
                }

                const items_removed = from_idx - to_idx;
                self.ct = to_idx;
                return items_removed;
            }

            return 0;
        }

        // for structs with an id member function. remove one struct with a matching id (order is not retained).
        pub fn idRemoveOnce(self: *Self, find_id: u32) bool {
            var idx: usize = 0;
            while (idx < self.ct) : (idx += 1) {
                if (self.items[idx]._id() == find_id) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        self.items[idx] = self.items[self.ct];
                    }
                    return true;
                }
            }
            return false;
        }

        // for structs with an id member function. remove one struct with a matching id while retaining order.
        pub fn idRemoveOnceOrdered(self: *Self, find_id: u32) bool {
            for (0..self.ct) |idx| {
                if (self.items[idx]._id() == find_id) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        for (idx..self.ct) |cpy_idx| {
                            self.items[cpy_idx] = self.items[cpy_idx + 1];
                        }
                    }
                    return true;
                }
            }
            return false;
        }

        // for structs with an id member function. find the index of a struct with a matching id.
        pub inline fn idFind(self: *const Self, find_id: u32) ?usize {
            for (0..self.ct) |idx| {
                if (self.items[idx]._id() == find_id) {
                    return idx;
                }
            }
            return null;
        }

        // for structs with an id member function. find the index of a struct with a matching id, starting from the
        // end.
        pub inline fn idFindReverse(self: *const Self, find_id: u32) ?usize {
            var idx = self.ct;
            while (idx >= 0) : (idx -= 1) {
                if (self.items[idx]._id() == find_id) {
                    return idx;
                }
            }
            return null;
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // -------------------------------------------------------------------------------------- struct-only operations
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // remove all structs with equal data (order is not retained).
        // returns true if at least one struct was removed.
        pub fn sRemoveAny(self: *Self, item: *const ItemType) usize {
            var new_ct = self.ct;
            var idx: usize = 0;

            // copying the item because the item might be an item in the array passed implicitly by reference.
            var item_copy: ItemType = item.*;

            while (idx < new_ct) {
                if (self.items[idx]._matches(&item_copy)) {
                    new_ct -= 1;
                    self.items[idx] = self.items[new_ct];
                } else {
                    idx += 1;
                }
            }

            const items_removed = self.ct - new_ct;
            self.ct = new_ct;
            return items_removed;
        }

        // remove all structs with equal data while retaining order.
        // returns true if at least one struct was removed.
        pub fn sRemoveAnyOrdered(self: *Self, item: *const ItemType) usize {
            var to_idx: usize = 0;
            var from_idx: usize = 0;

            // copying the item because the item might be an item in the array passed implicitly by reference.
            var item_copy: ItemType = item.*;

            while (to_idx < self.ct) : (to_idx += 1) {
                if (self.items[to_idx]._matches(&item_copy)) {
                    from_idx = to_idx + 1;
                    while (from_idx < self.ct) : (from_idx += 1) {
                        if (!self.items[from_idx]._matches(&item_copy)) {
                            break;
                        }
                    }
                    break;
                }
            }

            if (to_idx < self.ct) {
                if (from_idx != self.ct) {
                    while (from_idx < self.ct) {
                        self.items[to_idx] = self.items[from_idx];
                        from_idx += 1;
                        to_idx += 1;
                        while (self.items[from_idx]._matches(&item_copy)) {
                            from_idx += 1;
                        }
                    }
                }

                const items_removed = from_idx - to_idx;
                self.ct = to_idx;
                return items_removed;
            }

            return 0;
        }

        // find a struct with equal data within the array, remove once (order not retained).
        // returns true if a struct was removed.
        pub fn sRemoveOnce(self: *Self, item: *const ItemType) bool {
            var idx: usize = 0;
            while (idx < self.ct) : (idx += 1) {
                if (self.items[idx]._matches(&item)) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        self.items[idx] = self.items[self.ct];
                    }
                    return true;
                }
            }
            return false;
        }

        // find a struct with equal data within the array, remove once while retaining order.
        // returns true if a struct was removed.
        pub fn sRemoveOnceOrdered(self: *Self, item: *const ItemType) bool {
            for (0..self.ct) |idx| {
                if (self.items[idx]._matches(&item)) {
                    self.ct -= 1;
                    if (idx != self.ct) {
                        for (idx..self.ct) |cpy_idx| {
                            self.items[cpy_idx] = self.items[cpy_idx + 1];
                        }
                    }
                    return true;
                }
            }
            return false;
        }

        // find the index of a struct with equal data
        pub inline fn sFind(self: *const Self, find_item: *const ItemType) ?usize {
            for (0..self.ct) |idx| {
                if (self.items[idx]._matches(&find_item)) {
                    return idx;
                }
            }
            return null;
        }

        // find the index of a struct with equal data, starting from the end
        pub inline fn sFindReverse(self: *const Self, find_item: *const ItemType) ?usize {
            var idx: usize = self.ct;
            while (idx >= 0) : (idx -= 1) {
                if (self.data[idx]._matches(&find_item)) {
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

test "remove all by id" {
    var array = LocalArray(TestStruct, 128).new();

    array.push(TestStruct{ .someval = 1 }); // 0
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 }); // .. 6

    array.push(TestStruct{ .someval = 2 }); // 7
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 }); // ..12

    array.push(TestStruct{ .someval = 3 }); // 13
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 }); // ..17

    array.push(TestStruct{ .someval = 4 }); // 18
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 }); // ..21

    array.push(TestStruct{ .someval = 5 }); // 22
    array.push(TestStruct{ .someval = 5 });
    array.push(TestStruct{ .someval = 5 }); // .. 24

    array.push(TestStruct{ .someval = 4 }); // 25
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 }); // ..28

    var removed_item_ct = array.idRemoveAnyOrdered(4);

    try expect(removed_item_ct == 8);
    try expect(array.count() == 7 + 6 + 5 + 3);

    var i: usize = 0;
    while (i < array.count()) : (i += 1) {
        if (i < 7) {
            try expect(array.items[i]._id() == 1);
        } else if (i < 13) {
            try expect(array.items[i]._id() == 2);
        } else if (i < 18) {
            try expect(array.items[i]._id() == 3);
        } else {
            try expect(array.items[i]._id() == 5);
        }
    }
}

test "remove all by struct match" {
    var array = LocalArray(TestStruct, 128).new();

    array.push(TestStruct{ .someval = 1 }); // 0
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 });
    array.push(TestStruct{ .someval = 1 }); // .. 6

    array.push(TestStruct{ .someval = 2 }); // 7
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 });
    array.push(TestStruct{ .someval = 2 }); // ..12

    array.push(TestStruct{ .someval = 3 }); // 13
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 });
    array.push(TestStruct{ .someval = 3 }); // ..17

    array.push(TestStruct{ .someval = 4 }); // 18
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 }); // ..21

    array.push(TestStruct{ .someval = 5 }); // 22
    array.push(TestStruct{ .someval = 5 });
    array.push(TestStruct{ .someval = 5 }); // .. 24

    array.push(TestStruct{ .someval = 4 }); // 25
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 });
    array.push(TestStruct{ .someval = 4 }); // ..28
    // 29 values

    var removed_item_ct = array.sRemoveAnyOrdered(&array.items[18]);
    // 21 values

    try expect(removed_item_ct == 8);
    try expect(array.count() == 7 + 6 + 5 + 3);

    var i: usize = 0;
    while (i < array.count()) : (i += 1) {
        if (i < 7) {
            try expect(array.items[i]._id() == 1);
        } else if (i < 13) {
            try expect(array.items[i]._id() == 2);
        } else if (i < 18) {
            try expect(array.items[i]._id() == 3);
        } else {
            try expect(array.items[i]._id() == 5);
        }
    }

    array.push(TestStruct{ .someval = 3 });
    // 22 values

    removed_item_ct = array.sRemoveAny(&array.items[13]);
    // 16 values

    try expect(removed_item_ct == 6);
    try expect(array.count() == 7 + 6 + 3);

    for (array.items[0..array.count()]) |item| {
        try expect(item._id() != 3);
    }

    while (array.count() > 0) {
        _ = array.sRemoveAny(&array.items[0]);
    }
}

test "fill with struct" {
    const t = TestStruct {.x = 1.5, .y = 3.999};

    var array = LocalArray(TestStruct, 32).new();
    array.fill(t);

    try expect(array.count() == 32);
    for (array.items) |item| {
        try expect(item.x == 1.5);
        try expect(item.y == 3.999);
    }
}

test "remove at" {
    var array = LocalArray(i64, 32).new();

    for (0..array.size()) |i| {
        array.push(@intCast(i64, i));
    }

    array.removeAtOrdered(0); // removing 0
    array.removeAtOrdered(30); // removing 31
    array.removeAtOrdered(14); // removing 15
    array.removeAtOrdered(13); // removing 14

    try expect(array.count() == 28);

    for (0..array.count()) |i| {
        if (i < array.count() - 1) {
            try expect(array.items[i] < array.items[i + 1]);
        }
        try expect(array.items[i] != 0);
        try expect(array.items[i] != 31);
        try expect(array.items[i] != 15);
        try expect(array.items[i] != 14);
    }

    array.removeAt(array.count() - 1); // removing 30
    array.removeAt(0); // removing 1
    array.removeAt(3); // removing 4

    try expect(array.count() == 25);

    for (0..array.count()) |i| {
        try expect(array.items[i] != 0);
        try expect(array.items[i] != 31);
        try expect(array.items[i] != 15);
        try expect(array.items[i] != 14);
        try expect(array.items[i] != 1);
        try expect(array.items[i] != 4);
        try expect(array.items[i] != 30);
    }

    var i: usize = 0;
    while (i < 25) : (i += 1) {
        array.removeAt(0);
    }

    try expect(array.count() == 0);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const mem6 = @import("mem6.zig");
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

