const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ncurses = b.dependency("ncurses", .{});
    const modncurses = b.addModule("ncurses", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    modncurses.addCSourceFiles(.{
        .root = ncurses.path("ncurses/base"),
        .flags = &.{
            "-Qunused-arguments",
            "-Wno-error=implicit-function-declaration",
        },
        .files = &.{
            "lib_slkatrof.c",
            "lib_scanw.c",
            "lib_move.c",
            "lib_touch.c",
            "lib_isendwin.c",
            "lib_slktouch.c",
            "lib_slkatrset.c",
            "lib_scrreg.c",
            "lib_erase.c",
            "lib_clearok.c",
            "lib_clear.c",
            "lib_endwin.c",
            "lib_delwin.c",
            "lib_slkatr_set.c",
            "lib_set_term.c",
            "lib_initscr.c",
            "lib_delch.c",
            "lib_chgat.c",
            "lib_slkcolor.c",
            "lib_color.c",
            "lib_slkset.c",
            "lib_pad.c",
            "lib_insdel.c",
            "lib_insnstr.c",
            "lib_hline.c",
            "lib_slkinit.c",
            "lib_addstr.c",
            "lib_slk.c",
            "lib_refresh.c",
            "lib_printw.c",
            "lib_beep.c",
            "lib_getstr.c",
            "lib_slklab.c",
            "lib_scrollok.c",
            "lib_mouse.c",
            "lib_ungetch.c",
            "lib_clrbot.c",
            "lib_freeall.c",
            "lib_box.c",
            "lib_winch.c",
            "lib_overlay.c",
            "lib_redrawln.c",
            "lib_slkclear.c",
            "lib_slkrefr.c",
            "lib_nl.c",
            "lib_echo.c",
            "lib_immedok.c",
            "lib_flash.c",
            "lib_colorset.c",
            "lib_insch.c",
            "lib_wattroff.c",
            "lib_vline.c",
            "lib_leaveok.c",
            "lib_window.c",
            "lib_newwin.c",
            "lib_dft_fgbg.c",
            "lib_screen.c",
            "lib_slkattr.c",
            "lib_mvwin.c",
            "lib_slkatron.c",
            "lib_getch.c",
            "lib_driver.c",
            "lib_newterm.c",
            "lib_scroll.c",
            "lib_inchstr.c",
            "lib_instr.c",
            "lib_restart.c",
            "lib_wattron.c",
            "lib_clreol.c",
            "lib_addch.c",
            "lib_bkgd.c",
        },
    });

    const dll_h = b.addConfigHeader(.{
        .include_path = "ncurses_dll.h",
        .style = .{ .autoconf_at = ncurses.path("include/ncurses_dll.h.in") },
    }, .{
        .NCURSES_WRAP_PREFIX = "_nc_",
    });
    modncurses.addIncludePath(dll_h.getOutputDir());

    const config_h = b.addConfigHeader(.{
        .include_path = "ncurses_cfg.h",
        .style = .{ .autoconf_at = ncurses.path("include/ncurses_cfg.hin") },
    }, .{
        .DEFS = "/* NO DEFS YET */",
    });
    modncurses.addIncludePath(config_h.getOutputDir());

    const defs_h = runMkdefs(b, ncurses.path("include/ncurses_defs"), "ncurses_def.h");
    modncurses.addIncludePath(defs_h.dirname());

    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addIncludePath(ncurses.path("ncurses"));
    modncurses.addIncludePath(ncurses.path("ncurses/base"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addCMacro("_DEFAULT_SOURCE", "");
    modncurses.addCMacro("_XOPEN_SOURCE", "600");
    modncurses.addCMacro("NDEBUG", "");
    modncurses.addCMacro("TRACE", "");
    modncurses.addCMacro("NCURSES_STATIC", "");
    // -DHAVE_CONFIG_H -DBUILDING_NCURSES -I../ncurses -I. -I../include -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -DNDEBUG -O2 -Qunused-arguments -Wno-error=implicit-function-declaration  -DNCURSES_STATIC -g -DTRACE

    const libncurses = b.addLibrary(.{
        .name = "ncurses",
        .root_module = modncurses,
    });
    b.installArtifact(libncurses);
}

pub fn runMkdefs(b: *std.Build, src: std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const mkncurses_def = b.addExecutable(.{
        .name = "mkncurses_def",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mkncurses_def.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(mkncurses_def);
    run.addFileArg(src);
    return run.addOutputFileArg(basename);
}