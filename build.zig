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
    inline for (Sources.all) |source| {
        modncurses.addCSourceFiles(.{
            .root = ncurses.path(source.dir),
            .flags = Sources.flags,
            .files = source.files,
        });
        modncurses.addIncludePath(ncurses.path(source.dir));
    }
    modncurses.addCSourceFiles(.{
        .root = ncurses.path("ncurses/tinfo"),
        .flags = Sources.flags,
        .files = Sources.tinfo,
    });
    modncurses.addCSourceFiles(.{
        .root = ncurses.path("panel"),
        .flags = Sources.flags,
        .files = Sources.panel,
    });
    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addIncludePath(ncurses.path("ncurses"));
    modncurses.addIncludePath(ncurses.path("menu"));
    modncurses.addIncludePath(ncurses.path("panel"));
    modncurses.addIncludePath(ncurses.path("ncurses/base"));
    modncurses.addIncludePath(ncurses.path("ncurses"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addCMacro("_DEFAULT_SOURCE", "");
    modncurses.addCMacro("_XOPEN_SOURCE", "600");
    modncurses.addCMacro("NDEBUG", "");
    modncurses.addCMacro("TRACE", "");
    modncurses.addCMacro("NCURSES_STATIC", "");
    modncurses.addCMacro("SIG_ATOMIC_T", "volatile sig_atomic_t");

    const libncurses = b.addLibrary(.{
        .name = "ncurses",
        .root_module = modncurses,
    });
    libncurses.installLibraryHeaders(libncurses);
    inline for (&.{
        "include",
        "menu",
        "panel",
        "form",
    }) |dir| {
        libncurses.installHeadersDirectory(ncurses.path(dir), "", .{});
    }
    b.installArtifact(libncurses);

    const dll_h = b.addConfigHeader(.{
        .include_path = "ncurses_dll.h",
        .style = .{ .autoconf_at = ncurses.path("include/ncurses_dll.h.in") },
    }, .{
        .NCURSES_WRAP_PREFIX = "_nc_",
    });
    modncurses.addIncludePath(dll_h.getOutputDir());
    libncurses.installConfigHeader(dll_h);

    modncurses.addIncludePath(b.path("src"));

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

    {
        const unctrl_h = b.addConfigHeader(.{
            .include_path = "unctrl.h",
            .style = .{ .autoconf_at = ncurses.path("include/unctrl.h.in") },
        }, .{
            .NCURSES_MAJOR = ncurses_version.major,
            .NCURSES_MINOR = ncurses_version.minor,
            .NCURSES_SP_FUNCS = 20230311,
        });
        modncurses.addIncludePath(unctrl_h.getOutputDir());
        libncurses.installConfigHeader(unctrl_h);

        b.step("unctrl_h", "").dependOn(
            &b.addInstallFile(unctrl_h.getOutput(), "unctrl_h.h").step,
        );
    }

    {
        const termcap_h = b.addConfigHeader(.{
            .include_path = "termcap.h",
            .style = .{ .autoconf_at = ncurses.path("include/termcap.h.in") },
        }, .{
            .NCURSES_MAJOR = ncurses_version.major,
            .NCURSES_MINOR = ncurses_version.minor,
            .NCURSES_OSPEED = "short",
        });
        modncurses.addIncludePath(termcap_h.getOutputDir());
        libncurses.installConfigHeader(termcap_h);

        b.step("termcap_h", "").dependOn(
            &b.addInstallFile(termcap_h.getOutput(), "termcap.h").step,
        );
    }

    const defs_h = run_mkncurses_def(b, ncurses.path("include/ncurses_defs"), "ncurses_def.h");
    modncurses.addIncludePath(defs_h.dirname());
    b.step("ncdefs", "install ncurses_def.h").dependOn(&b.addInstallFile(defs_h, "ncurses_def.h").step);
    libncurses.installHeader(defs_h, "ncurses_def.h");

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
        .NCURSES_SP_FUNCS = 20230311,
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
    libncurses.installHeader(curses_h, "curses.h");

    b.step("curses_h", "").dependOn(
        &b.addInstallFile(curses_h, "curses.h").step,
    );

    // -DHAVE_CONFIG_H -DBUILDING_NCURSES -I../ncurses -I. -I../include -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -DNDEBUG -O2 -Qunused-arguments -Wno-error=implicit-function-declaration  -DNCURSES_STATIC -g -DTRACE

    {
        const demo = b.addExecutable(.{
            .name = "demo",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });
        demo.addCSourceFiles(.{
            .root = ncurses.path("c++"),
            .files = &.{
                "cursesapp.cc",
                "cursesf.cc",
                // "cursesmain.cc",
                "cursesm.cc",
                "cursespad.cc",
                "cursesp.cc",
                "cursesw.cc",
                "cursslk.cc",
                "demo.cc",
            },
            .flags = Sources.flags,
        });
        demo.addCSourceFiles(.{
            .root = ncurses.path("test"),
            .files = &.{
                // "demo_altkeys.c",
                // "demo_defkey.c",
                // "demo_forms.c",
                // "demo_keyok.c",
                // "demo_menus.c",
                // "demo_new_pair.c",
                // "demo_panels.c",
                // "demo_tabs.c",
                // "demo_termcap.c",
                // "demo_terminfo.c",
            },
            .flags = Sources.flags,
        });
        demo.linkLibCpp();
        demo.linkLibrary(libncurses);
        demo.addIncludePath(ncurses.path("test"));
        demo.addIncludePath(ncurses.path("c++"));
        demo.addIncludePath(ncurses_cfg_h.getOutputDir());
        demo.addIncludePath(b.path("src"));
        const etip_h = b.addConfigHeader(
            .{ .style = .{ .autoconf_at = ncurses.path("c++/etip.h.in") } },
            .{},
        );
        demo.addIncludePath(etip_h.getOutputDir());

        const demo_run = b.addRunArtifact(demo);
        b.step("demo", "run demo").dependOn(&demo_run.step);
    }

    {
        const mkterm_h = b.addConfigHeader(.{
            .style = .{
                .autoconf_at = ncurses.path("include/MKterm.h.awk.in"),
            },
            .include_path = "MKterm.h.awk",
        }, .{
            .NCURSES_MAJOR = ncurses_version.major,
            .NCURSES_MINOR = ncurses_version.minor,
            .HAVE_TERMIO_H = 1,
            .HAVE_TERMIOS_H = 1,
            .NCURSES_TPARM_VARARGS = 1,
            .BROKEN_LINKER = 0,
            .cf_cv_enable_reentrant = 0,
            .HAVE_TCGETATTR = 1,
            .NCURSES_SBOOL = "char",
            .NCURSES_EXT_COLORS = 0,
            .EXP_WIN32_DRIVER = 0,
            .NCURSES_XNAMES = 1,
            .NCURSES_USE_TERMCAP = 0,
            .NCURSES_USE_DATABASE = 1,
            .NCURSES_CONST = "const",
            .NCURSES_PATCH = ncurses_version.patch_str,
            .NCURSES_SP_FUNCS = 20230311,
        });
        const term_h = b.addSystemCommand(&.{
            "awk", "-f",
        });
        term_h.addFileArg(mkterm_h.getOutput());
        term_h.addFileArg(ncurses.path("include/Caps"));
        term_h.addFileArg(ncurses.path("include/Caps-ncurses"));
        const update_term_h = b.addUpdateSourceFiles();
        update_term_h.addCopyFileToSource(term_h.captureStdOut(), "src/term.h");
        b.step("update_term_h", "update term_h").dependOn(&update_term_h.step);
    }

    {
        const names_c = b.addSystemCommand(&.{
            "awk", "-f",
        });
        names_c.addFileArg(ncurses.path("ncurses/tinfo/MKnames.awk"));
        names_c.addArg("bigstrings=1");
        names_c.addFileArg(ncurses.path("include/Caps"));
        names_c.addFileArg(ncurses.path("include/Caps-ncurses"));
        const update_cames_c = b.addUpdateSourceFiles();
        update_cames_c.addCopyFileToSource(names_c.captureStdOut(), "src/term.h");
        b.step("update_names_c", "update src/names.c").dependOn(&update_cames_c.step);
    }
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

pub const Sources = struct {
    dir: []const u8,
    files: []const []const u8,
    pub const all: []const Sources = &.{
        menu,
        base,
        progs,
        form,
        trace,
    };
    pub const flags = &.{
        "-Qunused-arguments",
        "-Wno-error=implicit-function-declaration",
    };
    pub const menu: Sources = .{
        .dir = "menu",
        .files = &.{
            "m_attribs.c",
            "m_cursor.c",
            "m_driver.c",
            "m_format.c",
            "m_global.c",
            "m_hook.c",
            "m_item_cur.c",
            "m_item_nam.c",
            "m_item_new.c",
            "m_item_opt.c",
            "m_items.c",
            "m_item_top.c",
            "m_item_use.c",
            "m_item_val.c",
            "m_item_vis.c",
            "m_new.c",
            "m_opts.c",
            "m_pad.c",
            "m_pattern.c",
            "m_post.c",
            "m_req_name.c",
            "m_scale.c",
            "m_spacing.c",
            "m_sub.c",
            "m_trace.c",
            "m_userptr.c",
            "m_win.c",
        },
    };
    pub const panel = &.{
        "p_above.c",
        "panel.c",
        "p_below.c",
        "p_bottom.c",
        "p_delete.c",
        "p_hidden.c",
        "p_hide.c",
        "p_move.c",
        "p_new.c",
        "p_replace.c",
        "p_show.c",
        "p_top.c",
        "p_update.c",
        "p_user.c",
        "p_win.c",
    };
    pub const base: Sources = .{
        .dir = "ncurses/base",
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
    };
    pub const progs: Sources = .{
        .dir = "progs",
        .files = &.{
            // "clear.c",
            // "clear_cmd.c",
            // "dump_entry.c",
            // "infocmp.c",
            // "reset_cmd.c",
            // "tabs.c",
            // "tic.c",
            // "toe.c",
            // "tparm_type.c",
            // "tput.c",
            // "transform.c",
            // "tset.c",
            // "tty_settings.c",
        },
    };

    pub const form: Sources = .{
        .dir = "form",
        .files = &.{
            "fld_arg.c",
            "fld_attr.c",
            "fld_current.c",
            "fld_def.c",
            "fld_dup.c",
            "fld_ftchoice.c",
            "fld_ftlink.c",
            "fld_info.c",
            "fld_just.c",
            "fld_link.c",
            "fld_max.c",
            "fld_move.c",
            "fld_newftyp.c",
            "fld_opts.c",
            "fld_pad.c",
            "fld_page.c",
            "fld_stat.c",
            "fld_type.c",
            "fld_user.c",
            "frm_cursor.c",
            "frm_data.c",
            "frm_def.c",
            "frm_driver.c",
            "frm_hook.c",
            "frm_opts.c",
            "frm_page.c",
            "frm_post.c",
            "frm_req_name.c",
            "frm_scale.c",
            "frm_sub.c",
            "frm_user.c",
            "frm_win.c",
            "f_trace.c",
            "fty_alnum.c",
            "fty_alpha.c",
            "fty_enum.c",
            "fty_generic.c",
            "fty_int.c",
            "fty_ipv4.c",
            "fty_num.c",
            "fty_regex.c",
        },
    };
    pub const trace: Sources = .{
        .dir = "ncurses/trace",
        .files = &.{
            "lib_traceatr.c",
            "lib_tracebits.c",
            "lib_trace.c",
            "lib_tracechr.c",
            "lib_tracedmp.c",
            "lib_tracemse.c",
            "trace_buf.c",
            "trace_tries.c",
            "trace_xnames.c",
            "varargs.c",
            "visbuf.c",
        },
    };

    pub const tinfo = &.{
        "access.c",
        "add_tries.c",
        "alloc_entry.c",
        "alloc_ttype.c",
        "captoinfo.c",
        "comp_error.c",
        "comp_expand.c",
        "comp_hash.c",
        "comp_parse.c",
        "comp_scan.c",
        "db_iterator.c",
        "doalloc.c",
        "entries.c",
        "free_ttype.c",
        "getenv_num.c",
        "hashed_db.c",
        "home_terminfo.c",
        "init_keytry.c",
        "lib_acs.c",
        "lib_baudrate.c",
        "lib_cur_term.c",
        "lib_data.c",
        "lib_has_cap.c",
        "lib_kernel.c",
        "lib_longname.c",
        "lib_napms.c",
        "lib_options.c",
        "lib_print.c",
        "lib_raw.c",
        "lib_setup.c",
        "lib_termcap.c",
        "lib_termname.c",
        "lib_tgoto.c",
        "lib_ti.c",
        "lib_tparm.c",
        "lib_tputs.c",
        "lib_ttyflags.c",
        "lib_win32con.c",
        "lib_win32util.c",
        // "make_hash.c",
        // "make_keys.c",
        "name_match.c",
        "obsolete.c",
        "parse_entry.c",
        "read_entry.c",
        "read_termcap.c",
        "strings.c",
        "tinfo_driver.c",
        "trim_sgr0.c",
        "use_screen.c",
        "write_entry.c",
    };
    pub const tty = &.{
        "hardscroll.c",
        "hashmap.c",
        "lib_mvcur.c",
        "lib_tstp.c",
        "lib_twait.c",
        "lib_vidattr.c",
        "tty_update.c",
    };
};
