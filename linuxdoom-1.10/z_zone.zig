const std = @import("std");
const c = @cImport({
    @cInclude("z_zone.h");
    @cInclude("i_system.h");
});

// #define PU_STATIC		1	// static entire execution time
// #define PU_SOUND		2	// static while playing
// #define PU_MUSIC		3	// static while playing
// #define PU_DAVE		4	// anything else Dave wants static
// #define PU_LEVEL		50	// static until level exited
// #define PU_LEVSPEC		51      // a special thinker in a level
// // Tags >= 100 are purgable whenever needed.
// #define PU_PURGELEVEL	100
// #define PU_CACHE		101

const PurgeTag = enum(c_int) {
    static = 1,
    sound = 2,
    music = 3,
    dave = 4,
    level = 50,
    levspec = 51,
    purgelevel = 100,
    cache = 101,
};
const purge_count = std.meta.fields(PurgeTag).len;

var zones: [purge_count]std.heap.GeneralPurposeAllocator(.{}) = undefined;

export fn Z_Init() void {
    for (zones) |*z| {
        z.* = std.heap.GeneralPurposeAllocator(.{}){};
    }
}

fn mapTag(tag: c_int) !usize {
    inline for (std.meta.fields(PurgeTag)) |t, i| {
        if (tag == t.value)
            return i;
    }
    return error.Invalid;
}

const magic = 0x1d4a11;
const Header = packed struct {
    magic: c_uint = magic,
    size: c_int,
    tag: c_int,
};

const hsize = @sizeOf(Header);

export fn Z_Malloc(size: c_int, tag: c_int) *anyopaque {
    const zone = &zones[mapTag(tag) catch unreachable];
    const result = zone.allocator().allocWithOptions(
        u8,
        @intCast(usize, size + hsize),
        @alignOf(Header),
        null,
    ) catch unreachable;
    std.mem.copy(u8, result[0..hsize], @ptrCast(
        [*]const u8,
        &Header{ .size = size, .tag = tag },
    )[0..hsize]);
    return result[hsize..].ptr;
}

export fn Z_Free(ptr: ?*anyopaque) void {
    if (ptr == null) return;

    const base = @intToPtr([*]u8, @ptrToInt(ptr) - hsize);
    const header = @ptrCast(*Header, @alignCast(@alignOf(Header), base));
    if (header.magic != magic) {
        std.debug.print("Z_Free: freed a pointer without ZONEID\n", .{});
        std.debug.print("mem of header: {{ ", .{});
        for (base[0..hsize]) |b| {
            std.debug.print("{d}, ", .{b});
        }
        std.debug.print("}}\n", .{});
        unreachable;
    }

    const zone = &zones[mapTag(header.tag) catch unreachable];
    zone.allocator().free(
        base[0 .. @intCast(usize, header.size) + hsize],
    );
}

export fn Z_FreeTags(low: c_int, high: c_int) void {
    var i: c_int = low;
    while (i <= high) : (i += 1) {
        const id = mapTag(i) catch continue;
        _ = zones[id].deinit();
    }
}

export fn Z_CheckHeap() void {}

export fn Z_ChangeTag2(ptr: *anyopaque, tag: c_int) void {
    const base = @intToPtr([*]u8, @ptrToInt(ptr) - hsize);
    const header = @ptrCast(*Header, @alignCast(@alignOf(Header), base));
    header.tag = tag;
}
