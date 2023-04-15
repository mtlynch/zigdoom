const std = @import("std");

const ConcatStep = struct {
    step: std.Build.Step,
    name: []const u8,
    path: []const u8,
    actions: std.ArrayList(Action),

    pub const Action = union(enum) {
        file: std.Build.FileSource,
        bytes: []const u8,
        delete_bytes: usize,
    };

    pub fn create(owner: *std.Build, name: []const u8, path: []const u8) *ConcatStep {
        const self = owner.allocator.create(ConcatStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = name,
                .owner = owner,
                .makeFn = make,
            }),
            .actions = std.ArrayList(Action).init(owner.allocator),
            .name = name,
            .path = path,
        };
        return self;
    }

    pub fn addFileArg(self: *ConcatStep, file: std.Build.FileSource) void {
        self.actions.append(.{ .file = file }) catch @panic("OOM");
        file.addStepDependencies(&self.step);
    }

    pub fn addBytes(self: *ConcatStep, bytes: []const u8) void {
        self.actions.append(.{ .bytes = bytes }) catch @panic("OOM");
    }

    pub fn deleteBytes(self: *ConcatStep, count: usize) void {
        self.actions.append(.{ .delete_bytes = count }) catch @panic("OOM");
    }

    fn make(step: *std.Build.Step, prog_node: *std.Progress.Node) !void {
        const b = step.owner;
        const self = @fieldParentPtr(ConcatStep, "step", step);

        var subnode = prog_node.start(self.name, self.actions.items.len);
        defer subnode.end();

        const outf = try b.build_root.handle.createFile(self.path, .{});
        defer outf.close();

        subnode.activate();
        for (self.actions.items) |f| {
            switch (f) {
                .bytes => |bytes| {
                    try outf.writeAll(bytes);
                },
                .file => |file| {
                    const file_path = file.getPath(b);
                    const contents = try b.build_root.handle.readFileAlloc(b.allocator, file_path, std.math.maxInt(usize));
                    defer b.allocator.free(contents);
                    try outf.writeAll(contents);
                },
                .delete_bytes => |count| {
                    try outf.seekBy(-@intCast(i64, count));
                },
            }
            subnode.completeOne();
        }
    }
};

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
    };
    const jsondir = "build/";
    std.fs.cwd().makeDir(jsondir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    const concat = ConcatStep.create(b, "create compile_commands.json", jsondir ++ "compile_commands.json");
    concat.step.dependOn(&exe.step);
    concat.addBytes("[");
    inline for (c_src) |src| {
        const file_stem = comptime std.fs.path.stem(src);
        const jsonfrag = jsondir ++ file_stem ++ ".o.jsonfrag";
        exe.addCSourceFile(src, &common_cflags ++ &[_][]const u8{ "-MJ", jsonfrag });
        concat.addFileArg(.{ .path = jsonfrag });
    }
    concat.deleteBytes(2);
    concat.addBytes("]");
    b.default_step.dependOn(&concat.step);
    const zone = b.addObject(.{
        .name = "zone",
        .root_source_file = .{ .path = srcdir ++ "z_zone.zig" },
        .target = target,
        .optimize = optimize,
    });
    zone.linkLibC();
    zone.addIncludePath(srcdir);
    exe.addObject(zone);
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xext");

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    const run_step = b.step("run", "Run Doom");
    run_step.dependOn(&run_exe.step);
}
