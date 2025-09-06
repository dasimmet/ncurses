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
    const headers_step = b.step("headers", "install the zig generated headers");

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
        .root = b.path("src"),
        .flags = Sources.flags,
        .files = &.{"comp_userdefs.c"},
    });

    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addCMacro("_DEFAULT_SOURCE", "");
    modncurses.addCMacro("_XOPEN_SOURCE", "600");
    modncurses.addCMacro("NDEBUG", "");
    // modncurses.addCMacro("TRACE", "");
    modncurses.addCMacro("NCURSES_STATIC", "");

    const libncurses = b.addLibrary(.{ .name = "ncurses", .root_module = modncurses });
    libncurses.installLibraryHeaders(libncurses);
    inline for (&.{
        "include",
        "menu",
        "panel",
        "form",
    }) |dir| {
        libncurses.installHeadersDirectory(ncurses.path(dir), "", .{});
    }

    inline for (&.{
        // .{ "menu/mf_common.h", "mf_common.h" },
        // .{ "menu/eti.h", "eti.h" },
        // .{ "menu/menu.h", "menu.h" },
        // .{ "panel/panel.h", "panel.h" },
    }) |header| {
        libncurses.installHeader(ncurses.path(header[0]), header[1]);
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
    libncurses.installHeadersDirectory(b.path("src"), "", .{});

    const ncurses_zig_defs = b.addConfigHeader(.{
        .style = .blank,
        .include_path = "ncurses_zig_defs.h",
    }, ZIG_DEFS);

    const ncurses_cfg_h = runConfigHeaderLazyPath(
        b,
        ncurses.path("include/ncurses_cfg.hin"),
        "ncurses_cfg.h",
        .{
            .@"@DEFS@" = ncurses_zig_defs.getOutputFile(),
        },
    );
    modncurses.addIncludePath(ncurses_cfg_h.dirname());
    libncurses.installHeader(ncurses_cfg_h, "ncurses_cfg.h");
    headers_step.dependOn(
        &b.addInstallFile(ncurses_cfg_h, "include/ncurses_cfg.h").step,
    );

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

    headers_step.dependOn(
        &b.addInstallFile(unctrl_h.getOutput(), "include/unctrl.h").step,
    );

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

        headers_step.dependOn(
            &b.addInstallFile(termcap_h.getOutput(), "include/termcap.h").step,
        );
    }

    const defs_h = runMakeNCursesDef(b, ncurses.path("include/ncurses_defs"), "ncurses_def.h");
    modncurses.addIncludePath(defs_h.dirname());
    headers_step.dependOn(&b.addInstallFile(defs_h, "include/ncurses_def.h").step);
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
        .NCURSES_EXT_COLORS = 20230311,
        .cf_cv_1UL = "1U",
        .GENERATED_EXT_FUNCS = "generated",
        .HAVE_VSSCANF = 1,
        .NCURSES_CCHARW_MAX = 5,
        .NCURSES_SP_FUNCS = 20230311,
    });

    const curses_h = runConcatLazyPath(b, &.{
        curses_tmp_h.getOutput(),
        runMakeKeyDefs(b, &.{
            ncurses.path("include/Caps"),
            ncurses.path("include/Caps-ncurses"),
        }, "key_defs_tmp.h"),
        ncurses.path("include/curses.tail"),
    }, "curses.h");
    headers_step.dependOn(
        &b.addInstallFile(curses_h, "include/curses.h").step,
    );
    modncurses.addIncludePath(curses_h.dirname());
    libncurses.installHeader(curses_h, "curses.h");

    const libwidechar = b.addLibrary(.{
        .name = "widechar",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    libwidechar.addCSourceFiles(.{
        .root = ncurses.path(Sources.widechar.dir),
        .files = Sources.widechar.files,
        .flags = Sources.flags,
    });
    libwidechar.linkLibC();
    libwidechar.addIncludePath(ncurses.path("ncurses"));
    libwidechar.addIncludePath(ncurses.path("include"));
    libwidechar.addIncludePath(b.path("src"));
    libwidechar.addIncludePath(ncurses.path("ncurses/term"));
    libwidechar.addIncludePath(dll_h.getOutputDir());
    libwidechar.addIncludePath(ncurses_cfg_h.dirname());
    libwidechar.addIncludePath(defs_h.dirname());
    libwidechar.addIncludePath(curses_h.dirname());
    libwidechar.addIncludePath(unctrl_h.getOutputDir());
    modncurses.linkLibrary(libwidechar);

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
                "cursesmain.cc",
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
        demo.addIncludePath(ncurses_cfg_h.dirname());
        const etip_h = b.addConfigHeader(
            .{
                .style = .{ .autoconf_at = ncurses.path("c++/etip.h.in") },
                .include_path = "etip.h",
            },
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
            .NCURSES_EXT_COLORS = 20230311,
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

/// generates ncurses_def.h from ncurses_defs text file
pub fn runMakeNCursesDef(b: *std.Build, src: std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "MakeNCursesDef",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/MakeNCursesDef.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    run.addFileArg(src);
    return run.addOutputFileArg(basename);
}

/// generates key def headers from ncurses Caps files
pub fn runMakeKeyDefs(b: *std.Build, src: []const std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "MakeKeyDefs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/MakeKeyDefs.zig"),
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

/// concatenates a slice of files given in the form of a lazypath
pub fn runConcatLazyPath(b: *std.Build, src: []const std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "ConcatLazyPath",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ConcatLazyPath.zig"),
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

/// replaces keys in a file like configheader, but accepts lazypaths to files as arguments
/// keys for replacement have no particular syntax
pub fn runConfigHeaderLazyPath(b: *std.Build, src: std.Build.LazyPath, basename: []const u8, args: anytype) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "ConfigHeaderLazyPath",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ConfigHeaderLazyPath.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    run.stdio = .inherit;
    run.addFileArg(src);
    const out = run.addOutputFileArg(basename);
    inline for (comptime std.meta.fields(@TypeOf(args))) |field| {
        const value = @field(args, field.name);
        std.debug.assert(@TypeOf(value) == std.Build.LazyPath);
        run.addArg(field.name);
        run.addFileArg(value);
    }
    return out;
}

pub const Sources = struct {
    dir: []const u8,
    files: []const []const u8,
    pub const all: []const Sources = &.{
        ncurses,
        base,
        menu,
        panel,
        progs,
        form,
        trace,
        tinfo,
        tty,
    };
    pub const flags = &.{
        "-Qunused-arguments",
        "-Wno-error=implicit-function-declaration",
    };

    pub const ncurses: Sources = .{
        .dir = "ncurses",
        .files = &.{
            // "codes.c",
            // "comp_captab.c",
            // "comp_userdefs.c",
            // "expanded.c",
            // "fallback.c",
            // "lib_gen.c",
            // "lib_keyname.c",
            // "link_test.c",
            // "names.c",
            // "report_hashing.c",
            // "report_offsets.c",
            // "unctrl.c",
        },
    };

    pub const base: Sources = .{
        .dir = "ncurses/base",
        .files = &.{
            "define_key.c",
            "key_defined.c",
            "keybound.c",
            "keyok.c",
            "legacy_coding.c",
            "lib_addch.c",
            "lib_addstr.c",
            "lib_beep.c",
            "lib_bkgd.c",
            "lib_box.c",
            "lib_chgat.c",
            "lib_clear.c",
            "lib_clearok.c",
            "lib_clrbot.c",
            "lib_clreol.c",
            "lib_color.c",
            "lib_colorset.c",
            "lib_delch.c",
            "lib_delwin.c",
            "lib_dft_fgbg.c",
            "lib_driver.c",
            "lib_echo.c",
            "lib_endwin.c",
            "lib_erase.c",
            "lib_flash.c",
            "lib_freeall.c",
            "lib_getch.c",
            "lib_getstr.c",
            "lib_hline.c",
            "lib_immedok.c",
            "lib_inchstr.c",
            "lib_initscr.c",
            "lib_insch.c",
            "lib_insdel.c",
            "lib_insnstr.c",
            "lib_instr.c",
            "lib_isendwin.c",
            "lib_leaveok.c",
            "lib_mouse.c",
            "lib_move.c",
            "lib_mvwin.c",
            "lib_newterm.c",
            "lib_newwin.c",
            "lib_nl.c",
            "lib_overlay.c",
            "lib_pad.c",
            "lib_printw.c",
            "lib_redrawln.c",
            "lib_refresh.c",
            "lib_restart.c",
            "lib_scanw.c",
            "lib_screen.c",
            "lib_scroll.c",
            "lib_scrollok.c",
            "lib_scrreg.c",
            "lib_set_term.c",
            "lib_slk.c",
            "lib_slkatr_set.c",
            "lib_slkatrof.c",
            "lib_slkatron.c",
            "lib_slkatrset.c",
            "lib_slkattr.c",
            "lib_slkclear.c",
            "lib_slkcolor.c",
            "lib_slkinit.c",
            "lib_slklab.c",
            "lib_slkrefr.c",
            "lib_slkset.c",
            "lib_slktouch.c",
            "lib_touch.c",
            "lib_ungetch.c",
            "lib_vline.c",
            "lib_wattroff.c",
            "lib_wattron.c",
            "lib_winch.c",
            "lib_window.c",
            "nc_panel.c",
            "new_pair.c",
            "resizeterm.c",
            "safe_sprintf.c",
            // "sigaction.c",
            "tries.c",
            "use_window.c",
            "version.c",
            "vsscanf.c",
            "wresize.c",
        },
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

    pub const panel: Sources = .{
        .dir = "panel",
        .files = &.{
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

    pub const widechar: Sources = .{
        .dir = "ncurses/widechar",
        .files = &.{
            "charable.c",
            "lib_add_wch.c",
            "lib_box_set.c",
            "lib_cchar.c",
            "lib_erasewchar.c",
            "lib_get_wch.c",
            "lib_get_wstr.c",
            "lib_hline_set.c",
            "lib_ins_wch.c",
            "lib_in_wch.c",
            "lib_in_wchnstr.c",
            "lib_inwstr.c",
            "lib_key_name.c",
            "lib_pecho_wchar.c",
            "lib_slk_wset.c",
            "lib_unget_wch.c",
            "lib_vid_attr.c",
            "lib_vline_set.c",
            "lib_wacs.c",
            "lib_wunctrl.c",
            "widechars.c",
        },
    };

    pub const tinfo: Sources = .{
        .dir = "ncurses/tinfo",
        .files = &.{
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
        },
    };
    pub const tty: Sources = .{
        .dir = "ncurses/tty",
        .files = &.{
            "hardscroll.c",
            "hashmap.c",
            "lib_mvcur.c",
            "lib_tstp.c",
            "lib_twait.c",
            "lib_vidattr.c",
            "tty_update.c",
        },
    };
};

pub const ZIG_DEFS = .{
    .@"GCC_PRINTFLIKE(fmt,var)" = .@"__attribute__((format(printf,fmt,var)))",
    .@"GCC_SCANFLIKE(fmt,var)" = .@"__attribute__((format(scanf,fmt,var)))",
    .CPP_HAS_OVERRIDE = 1,
    .CPP_HAS_STATIC_CAST = 1,
    .DECL_ENVIRON = 1,
    .GCC_NORETURN = .@"__attribute__((noreturn))",
    .GCC_PRINTF = 1,
    .GCC_SCANF = 1,
    .GCC_UNUSED = .@"__attribute__((unused))",
    .HAVE_ASSUME_DEFAULT_COLORS = 1,
    .HAVE_BIG_CORE = 1,
    .HAVE_CLOCK_GETTIME = 1,
    .HAVE_CURSES_DATA_BOOLNAMES = 1,
    .HAVE_CURSES_VERSION = 1,
    .HAVE_DIRENT_H = 1,
    .HAVE_ENVIRON = 1,
    .HAVE_ERRNO = 1,
    .HAVE_FCNTL_H = 1,
    .HAVE_FORK = 1,
    .HAVE_FORM_H = 1,
    .HAVE_FPATHCONF = 1,
    .HAVE_FSEEKO = 1,
    .HAVE_GETCWD = 1,
    .HAVE_GETEGID = 1,
    .HAVE_GETEUID = 1,
    .HAVE_GETOPT = 1,
    .HAVE_GETOPT_H = 1,
    .HAVE_GETOPT_HEADER = 1,
    .HAVE_HAS_KEY = 1,
    .HAVE_INTTYPES_H = 1,
    .HAVE_IOSTREAM = 1,
    .HAVE_ISASCII = 1,
    .HAVE_LANGINFO_CODESET = 1,
    .HAVE_LIBFORM = 1,
    .HAVE_LIBMENU = 1,
    .HAVE_LIBPANEL = 1,
    .HAVE_LIMITS_H = 1,
    .HAVE_LINK = 1,
    .HAVE_LOCALE_H = 1,
    .HAVE_LOCALECONV = 1,
    .HAVE_LONG_FILE_NAMES = 1,
    .HAVE_MATH_FUNCS = 1,
    .HAVE_MATH_H = 1,
    .HAVE_MEMORY_H = 1,
    .HAVE_MENU_H = 1,
    .HAVE_MKSTEMP = 1,
    .HAVE_NANOSLEEP = 1,
    .HAVE_NC_ALLOC_H = 1,
    .HAVE_PANEL_H = 1,
    .HAVE_POLL = 1,
    .HAVE_POLL_H = 1,
    .HAVE_PUTENV = 1,
    .HAVE_REGEX_H_FUNCS = 1,
    .HAVE_REMOVE = 1,
    .HAVE_RESIZE_TERM = 1,
    .HAVE_RESIZETERM = 1,
    .HAVE_SELECT = 1,
    .HAVE_SETBUF = 1,
    .HAVE_SETBUFFER = 1,
    .HAVE_SETENV = 1,
    .HAVE_SETFSUID = 1,
    .HAVE_SETVBUF = 1,
    .HAVE_SIGACTION = 1,
    .HAVE_SIZECHANGE = 1,
    .HAVE_SLK_COLOR = 1,
    .HAVE_SNPRINTF = 1,
    .HAVE_STDINT_H = 1,
    .HAVE_STDLIB_H = 1,
    .HAVE_STRDUP = 1,
    .HAVE_STRING_H = 1,
    .HAVE_STRINGS_H = 1,
    .HAVE_STRSTR = 1,
    .HAVE_SYMLINK = 1,
    .HAVE_SYS_IOCTL_H = 1,
    .HAVE_SYS_PARAM_H = 1,
    .HAVE_SYS_POLL_H = 1,
    .HAVE_SYS_SELECT_H = 1,
    .HAVE_SYS_STAT_H = 1,
    .HAVE_SYS_TIME_H = 1,
    .HAVE_SYS_TIME_SELECT = 1,
    .HAVE_SYS_TIMES_H = 1,
    .HAVE_SYS_TYPES_H = 1,
    .HAVE_SYSCONF = 1,
    .HAVE_TCGETATTR = 1,
    .HAVE_TCGETPGRP = 1,
    .HAVE_TERM_ENTRY_H = 1,
    .HAVE_TERMIO_H = 1,
    .HAVE_TERMIOS_H = 1,
    .HAVE_TIMES = 1,
    .HAVE_TPUTS_SP = 1,
    .HAVE_TSEARCH = 1,
    .HAVE_TYPEINFO = 1,
    .HAVE_UNISTD_H = 1,
    .HAVE_UNLINK = 1,
    .HAVE_USE_DEFAULT_COLORS = 1,
    .HAVE_USE_EXTENDED_NAMES = 1,
    .HAVE_USE_SCREEN = 1,
    .HAVE_USE_WINDOW = 1,
    .HAVE_VA_COPY = 1,
    .HAVE_VFORK = 1,
    .HAVE_VSNPRINTF = 1,
    .HAVE_VSSCANF = 1,
    .HAVE_WCTYPE_H = 1,
    .HAVE_WORKING_FORK = 1,
    .HAVE_WORKING_POLL = 1,
    .HAVE_WORKING_VFORK = 1,
    .HAVE_WRESIZE = 1,
    .IOSTREAM_NAMESPACE = 1,
    .MIXEDCASE_FILENAMES = 1,
    .NCURSES_EXT_FUNCS = 1,
    .NCURSES_EXT_PUTWIN = 1,
    .NCURSES_NO_PADDING = 1,
    .NCURSES_OSPEED_COMPAT = 1,
    .NCURSES_PATCHDATE = "20230311",
    .NCURSES_PATHSEP = ':',
    .NCURSES_SP_FUNCS = 1,
    .NCURSES_VERSION = "6.4",
    .NCURSES_VERSION_STRING = "6.4.20230311",
    .NCURSES_WRAP_PREFIX = "_nc_",
    .PACKAGE = "ncurses",
    .PURE_TERMINFO = 1,
    .RGB_PATH = "/usr/share/X11/rgb.txt",
    .SIG_ATOMIC_T = .@"volatile sig_atomic_t",
    .SIZEOF_BOOL = 1,
    .SIZEOF_SIGNED_CHAR = 1,
    .STDC_HEADERS = 1,
    .SYSTEM_NAME = "linux-gnu",
    .TERMINFO = "/usr/share/terminfo",
    .TERMINFO_DIRS = "/usr/share/terminfo",
    .TIME_WITH_SYS_TIME = 1,
    .USE_ASSUMED_COLOR = 1,
    .USE_FOPEN_BIN_R = 1,
    .USE_HASHMAP = 1,
    .USE_HOME_TERMINFO = 1,
    .USE_LINKS = 1,
    .USE_OPENPTY_HEADER = .@"<pty.h>",
    .USE_ROOT_ACCESS = 1,
    .USE_ROOT_ENVIRON = 1,
    .USE_SIGWINCH = 1,
    .USE_TERM_DRIVER = 1,
    .USE_XTERM_PTY = 1,
};
