// TODO: decommitting solution will require dealing with the fact that free allocation tracking nodes can and will point
// in and out of individual pages at any frequency. So, decommitting a page means detangling the web. one set of 
// solutions requires regularly scheduled maintenance. one solution in that set might iterate over nodes and put
// 'next frees' in order, which would at the same time allow easier decommitting of any pages.
// Another possible solution is: the page list's 'free_block' just always takes the highest value. when the free block
// is the first block of a page, decommit.
// Another solution is to never decommit in small and medium allocations, which would probably work fine. combine this
// this the page list always taking the lowest block idx and it probably stays defragmented pretty well.
// Yet another solution is to keep track of the lowest and highest free block in a page list. the lowest is what is
// used for allocations, and the highest is used to tell which pages can be freed.
// TODO: large allocations work differently than small and medium, in that pages are simply comitted on demand.

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- public
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub fn startup(in_enclave_ct: usize) !void {
    std.debug.assert(in_enclave_ct <= MAX_ENCLAVE_CT);
    enclave_ct = in_enclave_ct;

    address_space = try windows.VirtualAlloc(
        null, 0xfffffffffff, windows.MEM_RESERVE, windows.PAGE_READWRITE
    );
    var address_bytes = @ptrCast([*]u8, address_space);

    var begin: usize = 0;
    for (0..enclave_ct) |i| {
        small_pools[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += SMALL_POOL_SZ;
        medium_pools[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += MEDIUM_POOL_SZ;
        large_pools[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += LARGE_POOL_SZ;
        giant_pools[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += GIANT_POOL_SZ;
        records[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += RECORDS_SZ;
        free_lists[i].bytes = @ptrCast([*]u8, &address_bytes[begin]);
        begin += FREE_LISTS_SZ;

        try initAllocators(i);
    }
}

pub inline fn shutdown() void {
    windows.VirtualFree(address_space, 0, windows.MEM_RELEASE);
}

pub const Allocator = struct {

    small_pool: *SmallPool = undefined,
    medium_pool: *MediumPool = undefined,
    large_pool: *LargePool = undefined,
    giant_pool: *GiantPool = undefined,
    records: *Records = undefined,
    free_lists: *FreeLists = undefined,

    pub inline fn newCopy (enclave_idx: usize) Allocator {
        return Allocator{
            .small_pool = &small_pools[enclave_idx],
            .medium_pool = &medium_pools[enclave_idx],
            .large_pool = &large_pools[enclave_idx],
            .giant_pool = &giant_pools[enclave_idx],
            .records = &records[enclave_idx],
            .free_lists = &free_lists[enclave_idx]
        };
    }

    pub inline fn enclave(self: *Allocator) usize {
        return (@ptrToInt(self.small_pool) - @ptrToInt(&small_pools[0])) / @sizeOf(*SmallPool);
    }

    pub fn alloc(self: *Allocator, comptime Type: type, ct: usize) Mem6Error![]Type {
        const alloc_sz: usize = ct * @sizeOf(Type);
        assert(alloc_sz > 0);

        var data: []u8 = undefined;
        if (alloc_sz <= SMALL_ALLOC_MAX_SZ) {
            const sm_idx = smallSizeBracket(alloc_sz);
            data = self.allocSmall(sm_idx) orelse return Mem6Error.OutOfMemory;
        }
        else if (alloc_sz <= MEDIUM_ALLOC_MAX_SZ) {
            const md_idx = mediumSizeBracket(alloc_sz);
            data = self.allocMedium(md_idx) orelse return Mem6Error.OutOfMemory;
        }
        else {
            return Mem6Error.OutOfMemory;
        }

        return mem.bytesAsSlice(Type, @alignCast(@alignOf(Type), data[0..alloc_sz]));
    }

    pub fn realloc(self: *Allocator, data_in: anytype, new_ct: usize) Mem6Error![]@typeInfo(@TypeOf(data_in)).Pointer.* {
        const slice = @typeInfo(@TypeOf(data_in)).Pointer;
        const bytes = mem.sliceAsBytes(data_in);
        const alloc_sz = bytes.len + if (slice.sentinel != null) @sizeOf(slice.child) else 0;
        assert(alloc_sz > 0);

        const type_sz = @sizeOf(@TypeOf(slice.*));
        const new_alloc_sz = type_sz * new_ct;
        const prev_sz_bracket = smallSizeBracket(alloc_sz);

        if (alloc_sz <= SMALL_ALLOC_MAX_SZ) {
            if (new_alloc_sz <= SMALL_ALLOC_MAX_SZ) {
                const new_sz_bracket = smallSizeBracket(new_alloc_sz);
                if (prev_sz_bracket == new_sz_bracket) {
                    return data_in;
                }
                else {
                    self.freeSmall(data_in, prev_sz_bracket);
                    return self.allocSmall(new_sz_bracket);
                }
            }
            else {
                self.freeSmall(data_in, prev_sz_bracket);
                return self.alloc(@TypeOf(slice.*), new_ct);
            }
        }
        else if (alloc_sz <= MEDIUM_ALLOC_MAX_SZ) {
            if (new_alloc_sz > SMALL_ALLOC_MAX_SZ and new_alloc_sz <= MEDIUM_ALLOC_MAX_SZ) {
                const new_sz_bracket = mediumSizeBracket(new_alloc_sz);
                if (prev_sz_bracket == new_sz_bracket) {
                    return data_in;
                }
                else {
                    self.freeMedium(data_in, prev_sz_bracket);
                    return self.allocMedium(new_sz_bracket);
                }
            }
            else {
                self.freeMedium(data_in, prev_sz_bracket);
                return self.alloc(@TypeOf(slice.*), new_ct);
            }
        }
    }

    pub fn free(self: *Allocator, data_in: anytype) void {
        const slice = @typeInfo(@TypeOf(data_in)).Pointer;
        const bytes = mem.sliceAsBytes(data_in);
        const alloc_sz = bytes.len + if (slice.sentinel != null) @sizeOf(slice.child) else 0;
        assert(alloc_sz > 0);

        if (alloc_sz <= SMALL_ALLOC_MAX_SZ) {
            const sm_idx = smallSizeBracket(alloc_sz);
            self.freeSmall(@ptrCast(*u8, bytes), sm_idx);
        }
        else if (alloc_sz <= MEDIUM_ALLOC_MAX_SZ) {
            const md_idx = mediumSizeBracket(alloc_sz);
            self.freeMedium(@ptrCast(*u8, bytes), md_idx);
        }
    }

    inline fn smallSizeBracket(alloc_sz: usize) usize {
        const sz_div_min = @intCast(usize, @divTrunc(alloc_sz, SMALL_ALLOC_MIN_SZ));
        const sz_is_multiple_of_min = @intCast(usize, @boolToInt(alloc_sz % SMALL_ALLOC_MIN_SZ == 0));
        return sz_div_min - sz_is_multiple_of_min; 
    }

    inline fn mediumSizeBracket(alloc_sz: usize) usize {
        return gm.ceilExp2(alloc_sz) - MEDIUM_MIN_EXP2;
    }

    inline fn largeSizeBracket(alloc_sz: usize) usize {
        return gm.ceilExp2(alloc_sz) - LARGE_MIN_EXP2;
    }

    fn allocSmall(self: *Allocator, sm_idx: usize) ?[]u8 {
        var page_list: *PageList = &self.small_pool.page_lists[sm_idx];
        if (page_list.free_block == null) {
            expandPageList(
                page_list, 
                SMALL_PAGE_SZ, 
                SMALL_NODE_SETS_PER_PAGE[sm_idx],
                SMALL_NODES_PER_PAGE,
                SMALL_BLOCK_COUNTS_PER_PAGE[sm_idx],
                SMALL_DIVISION_PAGE_CT
            ) catch return null;
        }

        const block_idx = page_list.free_block.?;
        const next_free_idx = page_list.blocks[block_idx].next_free;
        if (next_free_idx == NO_BLOCK) {
            page_list.free_block = null;
        }
        else {
            page_list.free_block = next_free_idx;
        }

        const page_idx = @divTrunc(block_idx, SMALL_BLOCK_COUNTS_PER_PAGE[sm_idx]);
        var page_record: *PageRecord = &page_list.pages[page_idx];
        page_record.free_block_ct -= 1;

        const block_start = block_idx * SMALL_BLOCK_SIZES[sm_idx];
        const block_end = block_start + SMALL_BLOCK_SIZES[sm_idx];
        return page_list.bytes[block_start..block_end];
    }

    fn freeSmall(self: *Allocator, data: *u8, sm_idx: usize) void {
        var page_list: *PageList = &self.small_pool.page_lists[sm_idx];
        const page_list_head_address = @ptrToInt(@ptrCast(*u8, page_list.bytes));
        const data_address = @ptrToInt(data);
        const block_idx = @intCast(u32, (data_address - page_list_head_address) / SMALL_BLOCK_SIZES[sm_idx]);

        if (page_list.free_block) |next_free| {
            page_list.blocks[@intCast(usize, block_idx)].next_free = @intCast(u32, next_free);
        }
        else {
            page_list.blocks[@intCast(usize, block_idx)].next_free = NO_BLOCK;
        }
        page_list.free_block = block_idx;

        var page_record: *PageRecord = &page_list.pages[block_idx / SMALL_BLOCK_COUNTS_PER_PAGE[sm_idx]];
        page_record.free_block_ct += 1;
    }

    fn allocMedium(self: *Allocator, md_idx: usize) ?[]u8 {
        var page_list: *PageList = &self.medium_pool.page_lists[md_idx];
        if (page_list.free_block == null) {
            expandPageList(
                page_list, 
                MEDIUM_PAGE_SZ, 
                MEDIUM_NODE_SETS_PER_PAGE[md_idx],
                MEDIUM_NODES_PER_PAGE,
                MEDIUM_BLOCK_COUNTS_PER_PAGE[md_idx],
                MEDIUM_DIVISION_PAGE_CT,
            ) catch return null;
        }

        const block_idx = page_list.free_block.?;
        const next_free_idx = page_list.blocks[block_idx].next_free;
        if (next_free_idx == NO_BLOCK) {
            page_list.free_block = null;
        }
        else {
            page_list.free_block = next_free_idx;
        }

        const page_idx = @divTrunc(block_idx, MEDIUM_BLOCK_COUNTS_PER_PAGE[md_idx]);
        var page_record: *PageRecord = &page_list.pages[page_idx];
        page_record.free_block_ct -= 1;

        const block_start = block_idx * MEDIUM_BLOCK_SIZES[md_idx];
        const block_end = block_start + MEDIUM_BLOCK_SIZES[md_idx];
        return page_list.bytes[block_start..block_end];
    }

    fn freeMedium(self: *Allocator, data: *u8, md_idx: usize) void {
        var page_list: *PageList = &self.medium_pool.page_lists[md_idx];
        const page_list_head_address = @ptrToInt(@ptrCast(*u8, page_list.bytes));
        const data_address = @ptrToInt(data);
        const block_idx = @intCast(u32, (data_address - page_list_head_address) / MEDIUM_BLOCK_SIZES[md_idx]);
        
        if (page_list.free_block) |next_free| {
            page_list.blocks[@intCast(usize, block_idx)].next_free = @intCast(u32, next_free);
        }
        else {
            page_list.blocks[@intCast(usize, block_idx)].next_free = NO_BLOCK;
        }
        page_list.free_block = block_idx;

        const blocks_per_page = MEDIUM_BLOCK_COUNTS_PER_PAGE[md_idx];
        var page_record: *PageRecord = &page_list.pages[block_idx / blocks_per_page];
        page_record.free_block_ct += 1;
    }

    fn allocLarge(self: *Allocator, lg_idx: usize) ?[]u8 {
        _ = self;
        _ = lg_idx;
    }

    fn freeLarge(self: *Allocator, data: *u8, lg_idx: usize) void {
        _ = self;
        _ = data;
        _ = lg_idx;
    }

    // TODO: OutOfPages error
    fn expandPageList(
        page_list: *PageList, 
        page_sz: usize, 
        node_sets_per_page: usize, 
        nodes_per_page: usize,
        block_cts_per_page: usize,
        division_page_ct: usize
    ) !void {
        const free_page_idx = page_list.free_page.?;
        var free_page: *PageRecord = &page_list.pages[free_page_idx]; 

        assert(free_page.free_block_ct == NO_BLOCK);
        
        page_list.free_page = free_page.next_free;

        const page_bytes = &page_list.bytes[free_page_idx * page_sz]; 
        _ = try windows.VirtualAlloc(
            page_bytes, page_sz, windows.MEM_COMMIT, windows.PAGE_READWRITE
        );

        // for every page of memory taken out for a given allocation size bracket, only a fraction of a page is required
        // to track individual allocations (with 'nodes'). So, we need to check if a page has already been committed for
        // tracking allocations within this range of allocation pages.
        const page_check_start = free_page_idx - @mod(free_page_idx, node_sets_per_page);
        var page_check_end = page_check_start + node_sets_per_page;
        if (page_check_end > division_page_ct) {
            page_check_end = division_page_ct;
        }

        for (page_check_start..page_check_end) |i| {
            if (page_list.pages[i].free_block_ct != NO_BLOCK) {
                break;
            }
        }
        else {
            const node_page_idx = page_check_start / node_sets_per_page;
            const nodes_bytes = &page_list.blocks[node_page_idx * nodes_per_page];
            _ = try windows.VirtualAlloc(
                nodes_bytes, page_sz, windows.MEM_COMMIT, windows.PAGE_READWRITE
            );
        }

        free_page.free_block_ct = @intCast(u32, block_cts_per_page);

        const start_idx = free_page_idx * block_cts_per_page;
        const end_idx = start_idx + block_cts_per_page - 1;
        for (start_idx..end_idx) |i| {
            page_list.blocks[i].next_free = @intCast(u32, i) + 1;
        }
        page_list.blocks[end_idx].next_free = NO_BLOCK;

        page_list.free_block = @intCast(u32, start_idx);
        page_list.page_ct += 1;
    }
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- init
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fn initPages(pages: []PageRecord, ct: usize) void {
    for (0..ct-1) |idx| {
        var page = &pages[idx];
        page.*.free_block_ct = NO_BLOCK;
        page.*.next_free = @intCast(u32, idx + 1);
    }
    pages[ct - 1].free_block_ct = NO_BLOCK;
    pages[ct - 1].next_free = NO_BLOCK;
}

fn initAllocators(enclave: usize) !void {
    // virtualloc committed memory is automatically zeroed
    _ = try windows.VirtualAlloc(
        records[enclave].bytes, RECORDS_SZ, windows.MEM_COMMIT, windows.PAGE_READWRITE
    );

    var page_records_casted = @ptrCast(
        [*]PageRecord, @alignCast(@alignOf(PageRecord), records[enclave].bytes)
    );
    var free_lists_casted = @ptrCast(
        [*]BlockNode, @alignCast(@alignOf(BlockNode), free_lists[enclave].bytes)
    );

    var block_sum: usize = 0;

    var i : usize = 0;
    while (i < SMALL_DIVISION_CT) : (i += 1) {
        const bytes_start = SMALL_DIVISION_SZ * i;
        const bytes_end = SMALL_DIVISION_SZ * (i + 1);
        const pages_start = SMALL_DIVISION_PAGE_CT * i;
        const pages_end = SMALL_DIVISION_PAGE_CT * (i + 1);
        const block_ct = SMALL_BLOCK_COUNTS_PER_DIVISION[i];

        var page_list = &small_pools[enclave].page_lists[i];
        page_list.bytes = @ptrCast([*]u8, small_pools[enclave].bytes[bytes_start..bytes_end]);
        page_list.pages = page_records_casted[pages_start..pages_end];
        page_list.free_page = 0;
        page_list.blocks = free_lists_casted[block_sum..(block_sum + block_ct)];
        page_list.free_block = null;
        page_list.page_ct = 0;
        page_list.free_page_ct = 0;

        initPages(page_list.pages, SMALL_DIVISION_PAGE_CT);
        
        block_sum += block_ct;
    }

    i = 0;
    const medium_bytes_start = SMALL_DIVISION_SZ * SMALL_DIVISION_CT;
    const medium_pages_start = SMALL_DIVISION_PAGE_CT * SMALL_DIVISION_CT;
    while (i < MEDIUM_DIVISION_CT) : (i += 1) {
        const bytes_start = medium_bytes_start + MEDIUM_DIVISION_SZ * i;
        const bytes_end = medium_bytes_start + MEDIUM_DIVISION_SZ * (i + 1);
        const pages_start = medium_pages_start + MEDIUM_DIVISION_PAGE_CT * i;
        const pages_end = medium_pages_start + MEDIUM_DIVISION_PAGE_CT * (i + 1);
        const block_ct = MEDIUM_BLOCK_COUNTS_PER_DIVISION[i];

        var page_list = &medium_pools[enclave].page_lists[i];
        page_list.bytes = @ptrCast([*]u8, medium_pools[enclave].bytes[bytes_start..bytes_end]);
        page_list.pages = page_records_casted[pages_start..pages_end];
        page_list.free_page = 0;
        page_list.blocks = free_lists_casted[block_sum..(block_sum + block_ct)];
        page_list.free_block = null;
        page_list.page_ct = 0;
        page_list.free_page_ct = 0;

        initPages(page_list.pages, MEDIUM_DIVISION_PAGE_CT);
        
        block_sum += block_ct;
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- data
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

var address_space: windows.LPVOID = undefined;
var small_pools: [MAX_ENCLAVE_CT]SmallPool = undefined;
var medium_pools: [MAX_ENCLAVE_CT]MediumPool = undefined;
var large_pools: [MAX_ENCLAVE_CT]LargePool = undefined;
var giant_pools: [MAX_ENCLAVE_CT]GiantPool = undefined;
var records: [MAX_ENCLAVE_CT]Records = undefined;
var free_lists: [MAX_ENCLAVE_CT]FreeLists = undefined;
var enclave_ct: usize = 0;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- types
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const SmallPage = struct {
    data: [SMALL_PAGE_SZ]u8 = undefined,
};

const PageRecord = struct {
    free_block_ct: u32 = undefined,
    next_free: u32 = undefined,
};

const BlockNode = struct { 
    next_free: u32 = undefined,
};

const FreeLists = struct {
    bytes: [*]u8 = undefined,
};

const Records = struct {
    bytes: [*]u8 = undefined,
};

const PageList = struct { 
    bytes: [*]u8 = undefined,
    pages: []PageRecord = undefined, 
    free_page: ?u32 = undefined, 
    blocks: []BlockNode = undefined, 
    free_block: ?u32 = undefined, 
    page_ct: u32 = undefined, 
    free_page_ct: u32 = undefined,
};

const SmallPool = struct {
    bytes: [*]u8 = undefined,
    page_lists: [SMALL_DIVISION_CT]PageList = undefined,
};

const MediumPool = struct {
    bytes: [*]u8 = undefined,
    page_lists: [MEDIUM_DIVISION_CT]PageList = undefined,
};

const LargePool = struct {
    bytes: [*]u8 = undefined,
};

const GiantPool = struct {
    bytes: [*]u8 = undefined,
};

const AllocatorData = struct {
    address_space: windows.LPVOID = undefined,
    small_pool: SmallPool = undefined,
    records: Records = undefined,
    free_lists: FreeLists = undefined,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const Mem6Error = error {
    OutOfMemory,
    BadSizeAtFree,
    NoExistingAllocationAtFree,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const MAX_ENCLAVE_CT: usize = 32;

// roughly correspond to actual page sizes. naming directly corresponds to which size-pool they're used for
const SMALL_PAGE_SZ: usize  = 16    * 1024; // 16KB
const MEDIUM_PAGE_SZ: usize = 64    * 1024; // 64KB

// address space sizes per enclave
const SMALL_POOL_SZ: usize  = 512   * 1024 * 1024; // 512 MB
const MEDIUM_POOL_SZ: usize = 8     * 1024 * 1024 * 1024; // 8 GB
const LARGE_POOL_SZ: usize  = 160   * 1024 * 1024 * 1024; // 160 GB
const GIANT_POOL_SZ: usize  = 256   * 1024 * 1024 * 1024; // 256 GB

//---------------------------------------------------------------------------------------------------------------- small

const SMALL_ALLOC_MIN_SZ: usize = 8;
const SMALL_ALLOC_MAX_SZ: usize = 64;
const SMALL_DIVISION_CT: usize  = 8;

const SMALL_DIVISION_SZ: usize                  = SMALL_POOL_SZ / SMALL_DIVISION_CT;
const SMALL_PAGE_RECORDS_SZ: usize              = SMALL_POOL_SZ / SMALL_PAGE_SZ; // must not have a remainder
const SMALL_PAGE_RECORDS_SZ_PER_DIVISION: usize = SMALL_PAGE_RECORDS_SZ / SMALL_DIVISION_CT;
const SMALL_DIVISION_PAGE_CT: usize             = SMALL_PAGE_RECORDS_SZ_PER_DIVISION / @sizeOf(PageRecord);
const SMALL_NODES_PER_PAGE: usize               = SMALL_PAGE_SZ / @sizeOf(BlockNode); 

const SMALL_BLOCK_SIZES: [8]usize = .{8, 16, 24, 32, 40, 48, 56, 64};

const SMALL_BLOCK_COUNTS_PER_DIVISION: [8]usize = .{
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[0],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[1],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[2],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[3],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[4],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[5],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[6],
    SMALL_DIVISION_SZ / SMALL_BLOCK_SIZES[7]
};

const SMALL_BLOCK_COUNTS_PER_PAGE: [8]usize = .{
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[0]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[1]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[2]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[3]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[4]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[5]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[6]),
    @divTrunc(SMALL_PAGE_SZ, SMALL_BLOCK_SIZES[7])
};

const SMALL_NODE_SETS_PER_PAGE: [8]usize = .{
    @divTrunc(SMALL_BLOCK_SIZES[0], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[1], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[2], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[3], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[4], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[5], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[6], @sizeOf(BlockNode)),
    @divTrunc(SMALL_BLOCK_SIZES[7], @sizeOf(BlockNode))
};

const SMALL_FREE_LIST_SZ_PER_DIVISION: [8]usize = .{
    SMALL_BLOCK_COUNTS_PER_DIVISION[0] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[1] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[2] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[3] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[4] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[5] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[6] * @sizeOf(BlockNode),
    SMALL_BLOCK_COUNTS_PER_DIVISION[7] * @sizeOf(BlockNode)
};

//--------------------------------------------------------------------------------------------------------------- medium

const MEDIUM_ALLOC_MIN_SZ: usize = MEDIUM_BLOCK_SIZES[0];
const MEDIUM_ALLOC_MAX_SZ: usize = MEDIUM_BLOCK_SIZES[MEDIUM_DIVISION_CT-1];
const MEDIUM_DIVISION_CT: usize = 8;
const MEDIUM_MIN_EXP2: usize = std.math.log(comptime_int, 2, @as(comptime_int, MEDIUM_ALLOC_MIN_SZ));

const MEDIUM_DIVISION_SZ: usize                     = MEDIUM_POOL_SZ / MEDIUM_DIVISION_CT;
const MEDIUM_PAGE_RECORDS_SZ: usize                 = MEDIUM_POOL_SZ / MEDIUM_PAGE_SZ;
const MEDIUM_PAGE_RECORDS_SZ_PER_DIVISION: usize    = MEDIUM_PAGE_RECORDS_SZ / MEDIUM_DIVISION_CT;
const MEDIUM_DIVISION_PAGE_CT: usize                = MEDIUM_PAGE_RECORDS_SZ_PER_DIVISION / @sizeOf(PageRecord);
const MEDIUM_NODES_PER_PAGE: usize                  = MEDIUM_PAGE_SZ / @sizeOf(BlockNode);

const MEDIUM_BLOCK_SIZES: [8]usize = .{128, 256, 512, 1024, 2048, 4096, 8192, 16_384};

const MEDIUM_BLOCK_COUNTS_PER_DIVISION: [8]usize = .{
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[0],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[1],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[2],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[3],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[4],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[5],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[6],
    MEDIUM_DIVISION_SZ / MEDIUM_BLOCK_SIZES[7]
};

const MEDIUM_BLOCK_COUNTS_PER_PAGE: [8]usize = .{
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[0]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[1]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[2]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[3]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[4]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[5]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[6]),
    @divTrunc(MEDIUM_PAGE_SZ, MEDIUM_BLOCK_SIZES[7])
};

const MEDIUM_NODE_SETS_PER_PAGE: [8]usize = .{
    @divTrunc(MEDIUM_BLOCK_SIZES[0], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[1], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[2], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[3], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[4], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[5], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[6], @sizeOf(BlockNode)),
    @divTrunc(MEDIUM_BLOCK_SIZES[7], @sizeOf(BlockNode))
};

const MEDIUM_FREE_LIST_SZ_PER_DIVISION: [8]usize = .{
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[0] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[1] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[2] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[3] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[4] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[5] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[6] * @sizeOf(BlockNode),
    MEDIUM_BLOCK_COUNTS_PER_DIVISION[7] * @sizeOf(BlockNode)
};

//---------------------------------------------------------------------------------------------------------------- large

const LARGE_ALLOC_MIN_SZ: usize = LARGE_BLOCK_SIZES[0];
const LARGE_ALLOC_MAX_SZ: usize = LARGE_BLOCK_SIZES[LARGE_DIVISION_CT-1];
const LARGE_DIVISION_CT: usize = 8;
const LARGE_MIN_EXP2: usize = std.math.log(comptime_int, 2, @as(comptime_int, LARGE_ALLOC_MIN_SZ));

const LARGE_DIVISION_SZ: usize                  = LARGE_POOL_SZ / LARGE_DIVISION_CT;
const LARGE_PAGE_RECORDS_SZ: usize              = LARGE_POOL_SZ / SMALL_PAGE_SZ;
const LARGE_PAGE_RECORDS_SZ_PER_DIVISION: usize = LARGE_PAGE_RECORDS_SZ / LARGE_DIVISION_CT;
const LARGE_DIVISION_PAGE_CT: usize             = LARGE_PAGE_RECORDS_SZ_PER_DIVISION / @sizeOf(PageRecord);
const LARGE_NODES_PER_PAGE: usize               = SMALL_PAGE_SZ / @sizeOf(BlockNode);

const LARGE_BLOCK_SIZES: [8]usize = .{32_768, 65_536, 131_072, 262_144, 524_288, 1_048_576, 2_097_152, 4_194_304};

//------------------------------------------------------------------------------------------------------------- the rest

const RECORDS_SZ: usize     = SMALL_PAGE_RECORDS_SZ + MEDIUM_PAGE_RECORDS_SZ;
const FREE_LISTS_SZ: usize  = 
    SMALL_FREE_LIST_SZ_PER_DIVISION[0]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[1]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[2]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[3]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[4]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[5]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[6]
    + SMALL_FREE_LIST_SZ_PER_DIVISION[7]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[0]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[1]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[2]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[3]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[4]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[5]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[6]
    + MEDIUM_FREE_LIST_SZ_PER_DIVISION[7];

const SMALL_POOL_BEGIN  = 0;
const MEDIUM_POOL_BEGIN = SMALL_POOL_SZ;
const LARGE_POOL_BEGIN  = MEDIUM_POOL_BEGIN + MEDIUM_POOL_SZ;
const GIANT_POOL_BEGIN  = LARGE_POOL_BEGIN  + LARGE_POOL_SZ;
const RECORDS_BEGIN     = GIANT_POOL_BEGIN  + GIANT_POOL_SZ;
const FREE_LISTS_BEGIN  = RECORDS_BEGIN     + RECORDS_SZ;
const FREE_LISTS_END    = FREE_LISTS_BEGIN  + FREE_LISTS_SZ;

const NO_BLOCK: u32 = 0xffffffff;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const windows = std.os.windows;
const mem = std.mem;
const expect = std.testing.expect;
const benchmark = @import("benchmark.zig");
const ScopeTimer = benchmark.ScopeTimer;
const getScopeTimerID = benchmark.getScopeTimerID;
const gm = @import("gmath.zig");

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- test
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

test "Single Allocation" {
    try startup(5);
    defer shutdown();
    var allocator = Allocator.newCopy(3);

    var sm1: []u8 = try allocator.alloc(u8, 54);
    for (0..sm1.len) |i| {
        sm1[i] = @intCast(u8, i);
    }

    for (0..sm1.len) |i| {
        try expect(sm1[i] == i);
    }

    allocator.free(sm1);
}

test "Small Allocation Aliasing" {
    try startup(6);
    defer shutdown();
    var allocator = Allocator.newCopy(5);

    var small_1: []u8 = try allocator.alloc(u8, 4);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 4);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 4);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 4);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 4);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 8);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 8);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 8);
    allocator.free(small_1);
    small_1 = try allocator.alloc(u8, 8);

    var small_1_address = @ptrToInt(@ptrCast(*u8, small_1));
    var small_pool_address = @ptrToInt(@ptrCast(*u8, allocator.small_pool.bytes));

    try expect(small_pool_address == small_1_address);

    var small_2: []u8 = try allocator.alloc(u8, 4);
    var small_3: []u8 = try allocator.alloc(u8, 8);

    const sm1_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_1)));
    const sm2_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_2)));
    const sm3_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_3)));

    const diff_2_3 = try std.math.absInt(sm2_address - sm3_address);
    const diff_2_1 = try std.math.absInt(sm2_address - sm1_address);
    const diff_1_3 = try std.math.absInt(sm1_address - sm3_address);

    try expect(diff_2_3 >= 8);
    try expect(diff_2_1 >= 8);
    try expect(diff_1_3 >= 8);

    allocator.free(small_3);

    var small_4: []u8 = try allocator.alloc(u8, 16);
    var small_5: []u8 = try allocator.alloc(u8, 32);
    var small_6: []u8 = try allocator.alloc(u8, 64);

    const sm4_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_4)));
    const sm5_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_5)));
    const sm6_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_6)));

    const diff_1_4 = try std.math.absInt(sm1_address - sm4_address);
    const diff_1_5 = try std.math.absInt(sm1_address - sm5_address);
    const diff_1_6 = try std.math.absInt(sm1_address - sm6_address);
    const diff_2_4 = try std.math.absInt(sm2_address - sm4_address);
    const diff_2_5 = try std.math.absInt(sm2_address - sm5_address);
    const diff_2_6 = try std.math.absInt(sm2_address - sm6_address);
    const diff_5_4 = try std.math.absInt(sm5_address - sm4_address);
    const diff_6_5 = try std.math.absInt(sm6_address - sm5_address);
    const diff_4_6 = try std.math.absInt(sm4_address - sm6_address);

    try expect((sm1_address < sm4_address and diff_1_4 >= 8) or (sm4_address < sm1_address and diff_1_4 >= 16));
    try expect((sm1_address < sm5_address and diff_1_5 >= 8) or (sm5_address < sm1_address and diff_1_5 >= 32));
    try expect((sm1_address < sm6_address and diff_1_6 >= 8) or (sm6_address < sm1_address and diff_1_6 >= 64));
    try expect((sm2_address < sm4_address and diff_2_4 >= 8) or (sm4_address < sm2_address and diff_2_4 >= 16));
    try expect((sm2_address < sm5_address and diff_2_5 >= 8) or (sm5_address < sm2_address and diff_2_5 >= 32));
    try expect((sm2_address < sm6_address and diff_2_6 >= 8) or (sm6_address < sm2_address and diff_2_6 >= 64));
    try expect((sm5_address < sm4_address and diff_5_4 >= 32) or (sm4_address < sm5_address and diff_5_4 >= 16));
    try expect((sm6_address < sm5_address and diff_6_5 >= 64) or (sm5_address < sm6_address and diff_6_5 >= 32));
    try expect((sm4_address < sm6_address and diff_4_6 >= 16) or (sm6_address < sm4_address and diff_4_6 >= 64));

    var small_7: []u8 = try allocator.alloc(u8, 15);
    var small_8: []u8 = try allocator.alloc(u8, 12);

    const sm7_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_7)));
    const sm8_address = @intCast(i64, @ptrToInt(@ptrCast(*u8, small_8)));

    const diff_4_7 = try std.math.absInt(sm4_address - sm7_address);
    const diff_4_8 = try std.math.absInt(sm4_address - sm8_address);
    const diff_7_8 = try std.math.absInt(sm7_address - sm8_address);

    try expect(diff_4_7 >= 16);
    try expect(diff_4_8 >= 16);
    try expect(diff_7_8 >= 16);

    allocator.free(small_1);
    allocator.free(small_2);
    allocator.free(small_4);
    allocator.free(small_5);
    allocator.free(small_6);
    allocator.free(small_7);
    allocator.free(small_8);
}

test "Small Allocation Multi-Page" {
    try startup(7);
    defer shutdown();
    var allocator = Allocator.newCopy(3);

    const alloc_ct: usize = 4097;
    var allocations: [alloc_ct][]u8 = undefined;
    
    for (0..alloc_ct)  |i| {
        allocations[i] = try allocator.alloc(u8, 16);
    }

    try expect(allocator.small_pool.page_lists[1].page_ct == 5);

    for (0..alloc_ct)  |i| {
        allocator.free(allocations[i]);
    }

    for (0..allocator.small_pool.page_lists[1].page_ct) |i| {
        try expect(allocator.small_pool.page_lists[1].pages[i].free_block_ct == SMALL_BLOCK_COUNTS_PER_PAGE[1]);
    }
}

test "Perf vs GPA" {
// pub fn perfMicroRun () !void {
    try startup(8);
    var allocator = Allocator.newCopy(0);

    for (0..100_000) |i| {
        var t = ScopeTimer.start("m6 SMALL alloc/free x5", getScopeTimerID());
        defer t.stop();
        _ = i;
        var testalloc = try allocator.alloc(u8, 4);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 8);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 16);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 32);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 64);
        allocator.free(testalloc);
    }

    var allocations: [100_000][]u8 = undefined;

    {
        var t = ScopeTimer.start("m6 SMALL alloc 100k", getScopeTimerID());
        defer t.stop();
        for (0..100_000) |i| {
            allocations[i] = try allocator.alloc(u8, 16);
        }
    }
    {
        var t = ScopeTimer.start("m6 SMALL free 100k", getScopeTimerID());
        defer t.stop();
        for (0..100_000) |i| {
            allocator.free(allocations[i]);
        }
    }

    for (0..100_000) |i| {
        var t = ScopeTimer.start("m6 MEDIUM alloc/free x5", getScopeTimerID());
        defer t.stop();
        _ = i;
        var testalloc = try allocator.alloc(u8, 100);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 255);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 512);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 1025);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 8192);
        allocator.free(testalloc);
        testalloc = try allocator.alloc(u8, 16384);
        allocator.free(testalloc);
    }

    {
        var t = ScopeTimer.start("m6 MEDIUM alloc 10k", getScopeTimerID());
        defer t.stop();
        for (0..10_000) |i| {
            allocations[i] = try allocator.alloc(u8, 2048);
        }
    }
    {
        var t = ScopeTimer.start("m6 MEDIUM free 10k", getScopeTimerID());
        defer t.stop();
        for (0..10_000) |i| {
            allocator.free(allocations[i]);
        }
    }
    shutdown();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        assert(deinit_status != .leak);
    }

    for (0..100_000) |i| {
        _ = i;
        var t = ScopeTimer.start("gpa SMALL alloc/free x5", getScopeTimerID()); defer t.stop();
        var testalloc = try gpa_allocator.alloc(u8, 4);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 8);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 16);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 32);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 64);
        gpa_allocator.free(testalloc);
    }

    {
        var t = ScopeTimer.start("gpa SMALL alloc 100k", getScopeTimerID()); defer t.stop();
        for (0..100_000) |i| {
            allocations[i] = try gpa_allocator.alloc(u8, 16);
        }
    }
    {
        var t = ScopeTimer.start("gpa SMALL free 100k", getScopeTimerID()); defer t.stop();
        for (0..100_000) |i| {
            gpa_allocator.free(allocations[i]);
        }
    }
    for (0..100_000) |i| {
        _ = i;
        var t = ScopeTimer.start("gpa MEDIUM alloc/free x5", getScopeTimerID()); defer t.stop();
        var testalloc = try gpa_allocator.alloc(u8, 100);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 255);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 512);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 1025);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 8192);
        gpa_allocator.free(testalloc);
        testalloc = try gpa_allocator.alloc(u8, 16384);
        gpa_allocator.free(testalloc);
    }

    {
        var t = ScopeTimer.start("gpa MEDIUM alloc 10k", getScopeTimerID()); defer t.stop();
        for (0..10_000) |i| {
            allocations[i] = try gpa_allocator.alloc(u8, 2048);
        }
    }
    {
        var t = ScopeTimer.start("gpa MEDIUM free 10k", getScopeTimerID()); defer t.stop();
        for (0..10_000) |i| {
            gpa_allocator.free(allocations[i]);
        }
    }
    benchmark.printAllScopeTimers();
}

test "Medium Alloc" {
// pub fn MediumAllocTest() !void {
    try startup(8);
    var allocator = Allocator.newCopy(0);
    defer shutdown();

    var testalloc = try allocator.alloc(u8, 100);
    allocator.free(testalloc);
    testalloc = try allocator.alloc(u8, 255);
    allocator.free(testalloc);
    testalloc = try allocator.alloc(u8, 512);
    allocator.free(testalloc);
    testalloc = try allocator.alloc(u8, 1025);
    allocator.free(testalloc);
    testalloc = try allocator.alloc(u8, 8192);
    allocator.free(testalloc);
    testalloc = try allocator.alloc(u8, 16384);
    allocator.free(testalloc);
}

test "Multiple Enclaves" {

}