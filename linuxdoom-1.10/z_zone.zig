const std = @import("std");
const c = @cImport({
    @cInclude("z_zone.h");
    @cInclude("i_system.h");
});

//
// ZONE MEMORY ALLOCATION
//
// There is never any space between memblocks,
//  and there will never be two contiguous free memblocks.
// The rover can be left pointing at a non-empty block.
//
// It is of no value to free a cachable block,
//  because it will get overwritten automatically if needed.
//

const zone_id = 0x1d4a11;

const MemBlock = extern struct {
    size: c_int,
    user: ?*anyopaque,
    tag: c_int,
    id: c_int,
    next: ?*@This(),
    prev: ?*@This(),
};

const MemZone = extern struct {
    size: c_int,
    blocklist: MemBlock,
    rover: ?*MemBlock,
};

export var mainzone: *MemZone = undefined;

extern var mb_used: c_int;

fn zone_base(size: *c_int) *anyopaque {
    size.* = mb_used * 1024 * 1024;
    const result = std.heap.c_allocator.allocWithOptions(
        u8,
        @intCast(usize, size.*),
        @alignOf(MemBlock),
        null,
    ) catch unreachable;
    return result.ptr;
}

export fn Z_Init() void {
    var size: c_int = undefined;
    mainzone = @ptrCast(
        *MemZone,
        @alignCast(@alignOf(MemBlock), zone_base(&size)),
    );
    mainzone.size = size;

    var block = @intToPtr(
        *MemBlock,
        @ptrToInt(mainzone) + @sizeOf(MemZone),
    );
    mainzone.blocklist.next = block;
    mainzone.blocklist.prev = block;
    mainzone.blocklist.user = @ptrCast(*anyopaque, mainzone);
    mainzone.rover = block;
    block.prev = &mainzone.blocklist;
    block.next = &mainzone.blocklist;
    block.user = null;
    block.size = mainzone.size - @sizeOf(MemZone);
}

export fn Z_ClearZone(zone_in: [*c]MemZone) void {
    const zone = @ptrCast(*MemZone, zone_in);
    var block = @intToPtr(
        *MemBlock,
        @ptrToInt(zone) + @sizeOf(MemZone),
    );
    zone.blocklist.next = block;
    zone.blocklist.prev = block;
    zone.blocklist.user = @ptrCast(*anyopaque, zone);
    zone.blocklist.tag = c.PU_STATIC;
    zone.rover = block;
    block.prev = &zone.blocklist;
    block.next = block.prev;
    block.user = null;
    block.size = zone.size - @sizeOf(MemZone);
}

export fn Z_Free(ptr: ?*anyopaque) void {
    var block = @intToPtr(
        *MemBlock,
        @ptrToInt(ptr) - @sizeOf(MemBlock),
    );

    if (block.id != zone_id)
        c.I_Error("Z_Free: freed a pointer without ZONEID");

    if (@ptrToInt(block.user) > 0x100)
        @ptrCast(
            [*c]?*anyopaque,
            @alignCast(@alignOf(*anyopaque), block.user),
        ).* = null;

    block.user = null;
    block.tag = 0;
    block.id = 0;

    var other = block.prev.?;

    if (other.user == null) {
        other.size += block.size;
        other.next = block.next;
        other.next.?.prev = other;

        if (block == mainzone.rover)
            mainzone.rover = other;

        block = other;
    }

    other = block.next.?;

    if (other.user == null) {
        block.size += other.size;
        block.next = other.next;
        block.next.?.prev = block;

        if (other == mainzone.rover)
            mainzone.rover = block;
    }
}

const min_fragment = 64;

export fn Z_Malloc(
    size_in: c_int,
    tag: c_int,
    user: ?*anyopaque,
) ?*anyopaque {
    var size = (size_in + 3) & ~@as(c_int, 3);
    size += @sizeOf(MemBlock);
    var base = mainzone.rover.?;

    if (base.prev.?.user == null)
        base = base.prev.?;

    var rover = base;
    var start = base.prev;

    var first = true;
    while (first or base.user != null or base.size < size) {
        first = false;
        if (rover == start)
            c.I_Error("Z_Malloc: failed on allocation of %i bytes", size);

        if (rover.user != null) {
            if (rover.tag < c.PU_PURGELEVEL) {
                base = rover.next.?;
                rover = rover.next.?;
            } else {
                base = base.prev.?;
                Z_Free(@intToPtr(
                    ?*anyopaque,
                    @ptrToInt(rover) + @sizeOf(MemBlock),
                ));
                base = base.next.?;
                rover = base.next.?;
            }
        } else rover = rover.next.?;
    }

    const extra = base.size - size;

    if (extra > min_fragment) {
        const newblock = @intToPtr(
            *MemBlock,
            @ptrToInt(base) + std.mem.alignForward(
                @intCast(usize, size),
                @alignOf(MemBlock),
            ),
        );
        newblock.size = extra;

        newblock.user = null;
        newblock.tag = 0;
        newblock.prev = base;
        newblock.next = base.next;
        newblock.next.?.prev = newblock;

        base.next = newblock;
        base.size = size;
    }

    if (user != null) {
        base.user = user;
        @ptrCast(
            [*c]?*anyopaque,
            @alignCast(@alignOf(*anyopaque), user),
        ).* = @intToPtr(
            *anyopaque,
            @ptrToInt(base) + @sizeOf(MemBlock),
        );
    } else {
        if (tag >= c.PU_PURGELEVEL)
            c.I_Error("Z_Malloc: an owner is required for purgable blocks");

        base.user = @intToPtr(*anyopaque, 2);
    }
    base.tag = tag;

    mainzone.rover = base.next;
    base.id = zone_id;
    return @intToPtr(*anyopaque, @ptrToInt(base) + @sizeOf(MemBlock));
}
