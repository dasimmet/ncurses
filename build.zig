const std = @import("std");

pub const ncurses_version = struct {
    pub const major = 6;
    pub const minor = 4;
    pub const patch_str = "20230311";
    pub const mouse = 2;
};

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
        .files = sources.base,
    });
    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addIncludePath(ncurses.path("ncurses"));
    modncurses.addIncludePath(ncurses.path("ncurses/base"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addCMacro("_DEFAULT_SOURCE", "");
    modncurses.addCMacro("_XOPEN_SOURCE", "600");
    modncurses.addCMacro("NDEBUG", "");
    modncurses.addCMacro("TRACE", "");
    modncurses.addCMacro("NCURSES_STATIC", "");
    modncurses.addCMacro("SIG_ATOMIC_T", "volatile sig_atomic_t");

    const dll_h = b.addConfigHeader(.{
        .include_path = "ncurses_dll.h",
        .style = .{ .autoconf_at = ncurses.path("include/ncurses_dll.h.in") },
    }, .{
        .NCURSES_WRAP_PREFIX = "_nc_",
    });
    modncurses.addIncludePath(dll_h.getOutputDir());
    modncurses.addIncludePath(b.path("src"));

    {
        const ncurses_cfg_h = b.addConfigHeader(.{
            .include_path = "ncurses_cfg.h",
            .style = .{ .autoconf_at = ncurses.path("include/ncurses_cfg.hin") },
        }, .{
            .DEFS = "#include <ncurses_zig_defs.h>",
        });
        modncurses.addIncludePath(ncurses_cfg_h.getOutputDir());

        b.step("ncurses_cfg", "").dependOn(
            &b.addInstallFile(ncurses_cfg_h.getOutput(), "ncurses_cfg.h").step,
        );
    }

    {
        const unctrl_h = b.addConfigHeader(.{
            .include_path = "unctrl.h",
            .style = .{ .autoconf_at = ncurses.path("include/unctrl.h.in") },
        }, .{
            .NCURSES_MAJOR = ncurses_version.major,
            .NCURSES_MINOR = ncurses_version.minor,
            .NCURSES_SP_FUNCS = 1,
        });
        modncurses.addIncludePath(unctrl_h.getOutputDir());

        b.step("unctrl_h", "").dependOn(
            &b.addInstallFile(unctrl_h.getOutput(), "unctrl_h.h").step,
        );
    }

    {
        const defs_h = run_mkncurses_def(b, ncurses.path("include/ncurses_defs"), "ncurses_def.h");
        modncurses.addIncludePath(defs_h.dirname());
        b.step("ncdefs", "install ncurses_def.h").dependOn(&b.addInstallFile(defs_h, "ncurses_def.h").step);
    }

    const curses_tmp_h = b.addConfigHeader(.{
        .include_path = "curses_tmp.h",
        .style = .{ .autoconf_at = ncurses.path("include/curses.h.in") },
    }, .{
        .NCURSES_MAJOR = ncurses_version.major,
        .NCURSES_MINOR = ncurses_version.minor,
        .NCURSES_PATCH = ncurses_version.patch_str,
        .NCURSES_MOUSE_VERSION = ncurses_version.mouse,

        .HAVE_STDINT_H = 1,
        .HAVE_STDNORETURN_H = 0,
        .NCURSES_CONST = "const",
        .NCURSES_INLINE = "inline",
        .NCURSES_OPAQUE = 0,
        .NCURSES_OPAQUE_FORM = 0,
        .NCURSES_OPAQUE_MENU = 0,
        .NCURSES_OPAQUE_PANEL = 0,
        .NCURSES_WATTR_MACROS = 0,
        .cf_cv_enable_reentrant = 0,
        .BROKEN_LINKER = 0,
        .NCURSES_INTEROP_FUNCS = 1,
        .NCURSES_SIZE_T = "short",
        .NCURSES_TPARM_VARARGS = 1,
        .NCURSES_TPARM_ARG = "intptr_t",
        .NCURSES_WCWIDTH_GRAPHICS = 1,
        .NCURSES_CH_T = "chtype",
        .cf_cv_enable_lp64 = 1,
        .cf_cv_header_stdbool_h = 1,
        .cf_cv_typeof_chtype = "uint32_t",
        .cf_cv_typeof_mmask_t = "uint32_t",
        .cf_cv_type_of_bool = "unsigned char",
        .USE_CXX_BOOL = "defined(__cplusplus)",
        .NCURSES_EXT_FUNCS = 1,
        .NCURSES_LIBUTF8 = 0,
        .NEED_WCHAR_H = 0,
        .NCURSES_WCHAR_T = 0,
        .NCURSES_OK_WCHAR_T = "",
        .NCURSES_WINT_T = 0,
        .NCURSES_EXT_COLORS = 0,
        .cf_cv_1UL = "1U",
        .GENERATED_EXT_FUNCS = "generated",
        .HAVE_VSSCANF = 1,
        .NCURSES_CCHARW_MAX = 5,
        .NCURSES_SP_FUNCS = 1,
    });

    const curses_h = run_concat_lp(b, &.{
        curses_tmp_h.getOutput(),
        run_mkkey_defs(b, &.{
            ncurses.path("include/Caps"),
            ncurses.path("include/Caps-ncurses"),
        }, "key_defs_tmp.h"),
        ncurses.path("include/curses.tail"),
    }, "curses.h");
    modncurses.addIncludePath(curses_h.dirname());

    b.step("curses_h", "").dependOn(
        &b.addInstallFile(curses_h, "curses.h").step,
    );

    // -DHAVE_CONFIG_H -DBUILDING_NCURSES -I../ncurses -I. -I../include -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -DNDEBUG -O2 -Qunused-arguments -Wno-error=implicit-function-declaration  -DNCURSES_STATIC -g -DTRACE

    const libncurses = b.addLibrary(.{
        .name = "ncurses",
        .root_module = modncurses,
    });
    b.installArtifact(libncurses);
}

pub fn run_mkncurses_def(b: *std.Build, src: std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "mkncurses_def",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mkncurses_def.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    run.addFileArg(src);
    return run.addOutputFileArg(basename);
}

pub fn run_mkkey_defs(b: *std.Build, src: []const std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "mkkey_defs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mkkey_defs.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    const out = run.addOutputFileArg(basename);
    for (src) |s| {
        run.addFileArg(s);
    }
    return out;
}

pub fn run_concat_lp(b: *std.Build, src: []const std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "concat_lp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/concat_lp.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    const out = run.addOutputFileArg(basename);
    for (src) |s| {
        run.addFileArg(s);
    }
    return out;
}

pub const sources = struct {
    pub const base = &.{
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
    };
};
