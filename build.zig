const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const srcdir = "linuxdoom-1.10/";

    const exe = b.addExecutable(.{
        .name = "doom",
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    b.installArtifact(exe);

    const c_src = [_][]const u8{
        srcdir ++ "am_map.c",
        srcdir ++ "d_items.c",
        srcdir ++ "d_main.c",
        srcdir ++ "d_net.c",
        srcdir ++ "doomdef.c",
        srcdir ++ "doomstat.c",
        srcdir ++ "dstrings.c",
        srcdir ++ "f_finale.c",
        srcdir ++ "f_wipe.c",
        srcdir ++ "g_game.c",
        srcdir ++ "hu_lib.c",
        srcdir ++ "hu_stuff.c",
        srcdir ++ "i_main.c",
        srcdir ++ "i_net.c",
        srcdir ++ "i_sound.c",
        srcdir ++ "i_system.c",
        srcdir ++ "i_video.c",
        srcdir ++ "info.c",
        srcdir ++ "m_argv.c",
        srcdir ++ "m_bbox.c",
        srcdir ++ "m_cheat.c",
        srcdir ++ "m_fixed.c",
        srcdir ++ "m_menu.c",
        srcdir ++ "m_misc.c",
        srcdir ++ "m_random.c",
        srcdir ++ "m_swap.c",
        srcdir ++ "p_ceilng.c",
        srcdir ++ "p_doors.c",
        srcdir ++ "p_enemy.c",
        srcdir ++ "p_floor.c",
        srcdir ++ "p_inter.c",
        srcdir ++ "p_lights.c",
        srcdir ++ "p_map.c",
        srcdir ++ "p_maputl.c",
        srcdir ++ "p_mobj.c",
        srcdir ++ "p_plats.c",
        srcdir ++ "p_pspr.c",
        srcdir ++ "p_saveg.c",
        srcdir ++ "p_setup.c",
        srcdir ++ "p_sight.c",
        srcdir ++ "p_spec.c",
        srcdir ++ "p_switch.c",
        srcdir ++ "p_telept.c",
        srcdir ++ "p_tick.c",
        srcdir ++ "p_user.c",
        srcdir ++ "r_bsp.c",
        srcdir ++ "r_data.c",
        srcdir ++ "r_draw.c",
        srcdir ++ "r_main.c",
        srcdir ++ "r_plane.c",
        srcdir ++ "r_segs.c",
        srcdir ++ "r_sky.c",
        srcdir ++ "r_things.c",
        srcdir ++ "s_sound.c",
        srcdir ++ "sounds.c",
        srcdir ++ "st_lib.c",
        srcdir ++ "st_stuff.c",
        srcdir ++ "tables.c",
        srcdir ++ "v_video.c",
        srcdir ++ "w_wad.c",
        srcdir ++ "wi_stuff.c",
    };
    const common_cflags = [_][]const u8{
        "-std=gnu89",
        "-DNORMALUNIX",
        "-DLINUX",
        "-ggdb3",
        "-fsanitize=address",
        "-fno-sanitize-trap=undefined",
        "-fno-sanitize-recover=undefined",
    };
    const jsondir = "build/";
    std.fs.cwd().makeDir(jsondir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    inline for (c_src) |src| {
        const file_stem = comptime std.fs.path.stem(src);
        exe.addCSourceFile(src, &common_cflags ++ &[_][]const u8{
            "-MJ",
            jsondir ++ file_stem ++ ".o.jsonfrag",
        });
    }
    const zone = b.addObject(.{
        .name = "zone",
        .root_source_file = .{ .path = srcdir ++ "z_zone.zig" },
        .target = target,
        .optimize = optimize,
    });
    zone.linkLibC();
    zone.addIncludePath(srcdir);
    exe.addObject(zone);
    exe.addLibraryPath("/usr/lib/gcc/x86_64-linux-gnu/12");
    exe.linkSystemLibrary("ubsan");
    exe.linkSystemLibrary("unwind");
    exe.linkSystemLibrary("asan");
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xext");
}
