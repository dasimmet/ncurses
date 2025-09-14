const std = @import("std");
const ConfigHeaderNoComment = @import("src/ConfigHeaderNoComment.zig");
const zon_version: []const u8 = @import("build.zig.zon").version;
const zon_parsed_version = std.SemanticVersion.parse(zon_version) catch unreachable;

pub const ncurses_version = struct {
    pub const major = @as(i64, zon_parsed_version.major);
    pub const minor = @as(i64, zon_parsed_version.minor);
    pub const patch = @as(i64, zon_parsed_version.patch);
    pub const mouse = 2;

    pub fn patch_str(b: *std.Build) []const u8 {
        return b.fmt("{}", .{patch});
    }
};

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    widechar: bool,
    @"opaque": bool,
    linkage: std.builtin.LinkMode,

    pub fn only_posix(self: @This()) u1 {
        return switch (self.target.result.os.tag) {
            .windows => 0,
            else => 1,
        };
    }

    pub fn only_posix_null(self: @This()) ?u1 {
        return switch (self.target.result.os.tag) {
            .windows => null,
            else => 1,
        };
    }

    pub fn nc_opaque(self: @This()) u1 {
        return if (self.@"opaque") 1 else 0;
    }

    pub fn only_windows_null(self: @This()) ?u1 {
        return switch (self.target.result.os.tag) {
            .windows => 1,
            else => null,
        };
    }
};

pub fn build(b: *std.Build) void {
    const options: Options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .widechar = !(b.option(bool, "no-opaque", "disable opaque support") orelse false),
        .@"opaque" = !(b.option(bool, "no-widechar", "disable widechar support") orelse false),
        .linkage = b.option(std.builtin.LinkMode, "linkage", "linkmode for the library") orelse .static,
    };

    const headers_step = b.step("headers", "install the zig generated headers");

    const ncurses = b.dependency("ncurses", .{});
    const modncurses = b.addModule("ncurses", .{
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    const libncurses = b.addLibrary(.{
        .name = "ncurses",
        .root_module = modncurses,
        .linkage = options.linkage,
    });
    b.installArtifact(libncurses);

    inline for (Sources.all) |source| {
        modncurses.addCSourceFiles(.{
            .root = ncurses.path(source.dir),
            .flags = Sources.flags(options.target),
            .files = source.files,
        });
        modncurses.addIncludePath(ncurses.path(source.dir));
        for (source.installheaders) |header| {
            libncurses.installHeader(ncurses.path(b.pathJoin(&.{ source.dir, header })), header);
        }
    }
    if (options.widechar) {
        modncurses.addCSourceFiles(.{
            .root = ncurses.path(Sources.widechar.dir),
            .flags = Sources.flags(options.target),
            .files = Sources.widechar.files,
        });
        modncurses.addIncludePath(ncurses.path(Sources.widechar.dir));
    }
    if (options.target.result.os.tag == .windows) {
        modncurses.addCSourceFiles(.{
            .root = ncurses.path("ncurses/win32con"),
            .flags = Sources.flags(options.target),
            .files = &.{
                // "win_driver.c",
                // "gettimeofday.c",
                "win32_driver.c",
                "wcwidth.c",
            },
        });
    }

    modncurses.addCSourceFiles(.{
        .root = b.path("src/c"),
        .flags = Sources.flags(options.target),
        .files = &.{
            "comp_userdefs.c",
            "comp_captab.c",
        },
    });

    modncurses.addCSourceFile(.{
        .file = runAwkTpl(
            b,
            ncurses.path("ncurses/base/MKkeyname.awk"),
            &.{b.path("src/c/keys.list")},
            "lib_keyname.c",
        ),
        .flags = Sources.flags(options.target),
    });

    modncurses.addCSourceFile(.{
        .file = runAwkTpl(
            b,
            ncurses.path("ncurses/base/MKunctrl.awk"),
            &.{},
            "unctrl.c",
        ),
        .flags = Sources.flags(options.target),
    });

    modncurses.addCSourceFile(.{
        .file = runAwkTpl(
            b,
            ncurses.path("ncurses/tinfo/MKcodes.awk"),
            &.{ ncurses.path("include/Caps"), ncurses.path("include/Caps-ncurses") },
            "codes.c",
        ),
        .flags = Sources.flags(options.target),
    });

    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addCMacro("_DEFAULT_SOURCE", "");
    modncurses.addCMacro("_XOPEN_SOURCE", "600");
    modncurses.addCMacro("HAVE_CONFIG_H", "1");
    modncurses.addCMacro("NCURSES_STATIC", "");

    libncurses.installHeadersDirectory(ncurses.path("include"), "", .{});

    const dll_h = b.addConfigHeader(.{
        .include_path = "ncurses_dll.h",
        .style = .{ .autoconf_at = ncurses.path("include/ncurses_dll.h.in") },
    }, .{
        .NCURSES_WRAP_PREFIX = "_nc_",
    });
    modncurses.addIncludePath(dll_h.getOutputDir());
    libncurses.installConfigHeader(dll_h);
    modncurses.addIncludePath(b.path("src/c"));

    const ncurses_zig_defs = ncurses_defs_header(b, options);

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
        &b.addInstallHeaderFile(ncurses_cfg_h, "ncurses_cfg.h").step,
    );

    const unctrl_h = b.addConfigHeader(.{
        .include_path = "unctrl.h",
        .style = .{ .autoconf_at = ncurses.path("include/unctrl.h.in") },
    }, .{
        .NCURSES_MAJOR = ncurses_version.major,
        .NCURSES_MINOR = ncurses_version.minor,
        .NCURSES_SP_FUNCS = 1,
    });
    modncurses.addIncludePath(unctrl_h.getOutputDir());
    libncurses.installConfigHeader(unctrl_h);

    headers_step.dependOn(
        &b.addInstallHeaderFile(unctrl_h.getOutput(), "unctrl.h").step,
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
            &b.addInstallHeaderFile(termcap_h.getOutput(), "termcap.h").step,
        );
    }

    const defs_h = runMakeNCursesDef(b, ncurses.path("include/ncurses_defs"), "ncurses_def.h");
    modncurses.addIncludePath(defs_h.dirname());
    headers_step.dependOn(&b.addInstallHeaderFile(defs_h, "ncurses_def.h").step);
    libncurses.installHeader(defs_h, "ncurses_def.h");

    const curses_tmp_h = b.addConfigHeader(.{
        .include_path = "curses_tmp.h",
        .style = .{ .autoconf_at = ncurses.path("include/curses.h.in") },
    }, .{
        .NCURSES_MAJOR = ncurses_version.major,
        .NCURSES_MINOR = ncurses_version.minor,
        .NCURSES_PATCH = ncurses_version.patch_str(b),
        .NCURSES_MOUSE_VERSION = ncurses_version.mouse,

        .HAVE_STDINT_H = 1,
        .HAVE_STDNORETURN_H = 0,
        .NCURSES_CONST = "const",
        .NCURSES_INLINE = "inline",
        .NCURSES_OPAQUE = options.nc_opaque(),
        .NCURSES_OPAQUE_FORM = options.nc_opaque(),
        .NCURSES_OPAQUE_MENU = options.nc_opaque(),
        .NCURSES_OPAQUE_PANEL = options.nc_opaque(),
        .NCURSES_WATTR_MACROS = 0,
        .cf_cv_enable_reentrant = 0,
        .BROKEN_LINKER = 0,
        .NCURSES_INTEROP_FUNCS = 1,
        .NCURSES_SIZE_T = "short",
        .NCURSES_TPARM_VARARGS = 1,
        .NCURSES_TPARM_ARG = "intptr_t",
        .NCURSES_WCWIDTH_GRAPHICS = 1,
        .NCURSES_CH_T = switch (options.widechar) {
            true => "cchar_t",
            false => "chtype",
        },
        .cf_cv_enable_lp64 = 1,
        .cf_cv_header_stdbool_h = 1,
        .cf_cv_typeof_chtype = switch (options.widechar) {
            true => "long",
            false => "uint32_t",
        },
        .cf_cv_typeof_mmask_t = "uint32_t",
        .cf_cv_type_of_bool = "unsigned char",
        .USE_CXX_BOOL = "defined(__cplusplus)",
        .NCURSES_EXT_FUNCS = 1,
        .NCURSES_LIBUTF8 = 0,
        .NEED_WCHAR_H = @as(u1, if (options.widechar) 1 else 0),
        .NCURSES_WCHAR_T = @as(u1, if (options.widechar) 1 else 0),
        .NCURSES_OK_WCHAR_T = "uint32_t",
        .NCURSES_WINT_T = 0,
        .NCURSES_EXT_COLORS = 1,
        .cf_cv_1UL = "1U",
        .GENERATED_EXT_FUNCS = "generated",
        .HAVE_VSSCANF = 1,
        .NCURSES_CCHARW_MAX = 5,
        .NCURSES_SP_FUNCS = 1,
    });

    const curses_h_parts: []const FileOrString = switch (options.widechar) {
        true => &.{
            .file(curses_tmp_h.getOutput()),
            .file(runMakeKeyDefs(b, &.{
                ncurses.path("include/Caps"),
                ncurses.path("include/Caps-ncurses"),
            }, "key_defs_tmp.h")),
            .file(ncurses.path("include/curses.wide")), //add in widechar headers
            .file(ncurses.path("include/curses.tail")),
        },
        false => &.{
            .file(curses_tmp_h.getOutput()),
            .file(runMakeKeyDefs(b, &.{
                ncurses.path("include/Caps"),
                ncurses.path("include/Caps-ncurses"),
            }, "key_defs_tmp.h")),
            .file(ncurses.path("include/curses.tail")),
        },
    };
    const curses_h = runConcatLazyPath(b, curses_h_parts, "curses.h");
    headers_step.dependOn(
        &b.addInstallHeaderFile(curses_h, "curses.h").step,
    );

    if (b.option(bool, "use_gen_libc", "") orelse false) {
        const awk_dep = b.dependency("awk", .{
            .target = b.graph.host,
            .optimize = .ReleaseSmall,
        });

        const lib_gen = runMakeLibGenC(b, curses_h, awk_dep.artifact("awk").getEmittedBin());
        modncurses.addCSourceFile(.{
            .file = lib_gen,
            .flags = Sources.flags(options.target),
        });
    } else {
        modncurses.addCSourceFiles(.{
            .root = b.path("src/c"),
            .flags = Sources.flags(options.target),
            .files = &.{
                "lib_gen.c",
            },
        });
    }

    const fallback_c = runMakeFallbackC(b, &.{});
    b.step("fallback", "").dependOn(&b.addInstallFile(
        fallback_c,
        "fallback.c",
    ).step);

    modncurses.addCSourceFile(.{
        .file = fallback_c,
        .flags = Sources.flags(options.target),
    });

    const makekeys = b.addExecutable(.{
        .name = "makekeys",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = .ReleaseSmall,
            .link_libc = true,
        }),
    });
    makekeys.addIncludePath(unctrl_h.getOutputDir());
    makekeys.addIncludePath(curses_h.dirname());
    makekeys.addIncludePath(defs_h.dirname());
    makekeys.addIncludePath(ncurses_cfg_h.dirname());
    makekeys.addIncludePath(dll_h.getOutputDir());
    makekeys.addIncludePath(ncurses.path("include"));
    makekeys.addIncludePath(ncurses.path("ncurses"));
    makekeys.addCSourceFile(.{
        .file = ncurses.path("ncurses/tinfo/make_keys.c"),
        .flags = Sources.flags(options.target),
    });
    const run_mkkeys = b.addRunArtifact(makekeys);
    run_mkkeys.addFileArg(b.path("src/c/keys.list"));
    const keytry_wf = b.addWriteFiles();
    const keytry_h = keytry_wf.addCopyFile(run_mkkeys.captureStdOut(), "init_keytry.h");
    modncurses.addIncludePath(keytry_h.dirname());

    modncurses.addIncludePath(ncurses.path("include"));
    modncurses.addCMacro("BUILDING_NCURSES", "");
    modncurses.addIncludePath(curses_h.dirname());
    libncurses.installHeader(curses_h, "curses.h");

    {
        const demo_step = b.step("demo", "build demos");
        for (Tests.all) |testf| {
            if (!testf.macos) {
                switch (options.target.result.os.tag) {
                    .macos => continue,
                    else => {},
                }
            }
            const demo = b.addExecutable(.{
                .name = testf.name,
                .root_module = b.createModule(.{
                    .target = options.target,
                    .optimize = options.optimize,
                }),
            });
            switch (options.linkage) {
                .static => demo.root_module.addCMacro("NCURSES_STATIC", ""),
                .dynamic => {},
            }

            demo.addCSourceFiles(.{
                .root = ncurses.path(testf.dir),
                .files = testf.files,
                .flags = Sources.flags(options.target),
            });
            demo.linkLibrary(libncurses);
            demo.addIncludePath(ncurses.path(testf.dir));
            demo_step.dependOn(&b.addInstallArtifact(demo, .{}).step);
            const demo_s = b.step(
                b.fmt("demo_{s}", .{testf.name}),
                b.fmt("run demo {s}", .{testf.name}),
            );
            demo_s.dependOn(&b.addRunArtifact(demo).step);
        }
    }

    {
        const mkterm_h = addConfigHeaderNoComment(b, .{
            .style = .{
                .autoconf_at = ncurses.path("include/MKterm.h.awk.in"),
            },
            .include_path = "MKterm.h.awk",
        }, .{
            .NCURSES_MAJOR = ncurses_version.major,
            .NCURSES_MINOR = ncurses_version.minor,
            .HAVE_TERMIO_H = options.only_posix(),
            .HAVE_TERMIOS_H = options.only_posix(),
            .NCURSES_TPARM_VARARGS = 1,
            .BROKEN_LINKER = 0,
            .cf_cv_enable_reentrant = 0,
            .HAVE_TCGETATTR = 1,
            .NCURSES_SBOOL = "char",
            .NCURSES_EXT_COLORS = 1,
            .EXP_WIN32_DRIVER = @as(u1, switch (options.target.result.os.tag) {
                .windows => 1,
                else => 0,
            }),
            .NCURSES_XNAMES = 1,
            .NCURSES_USE_TERMCAP = 0,
            .NCURSES_USE_DATABASE = 1,
            .NCURSES_CONST = "const",
            .NCURSES_PATCH = ncurses_version.patch_str(b),
            .NCURSES_SP_FUNCS = 1,
        });
        const term_h = runAwkTpl(
            b,
            mkterm_h.getOutput(),
            &.{ ncurses.path("include/Caps"), ncurses.path("include/Caps-ncurses") },
            "term.h",
        );
        modncurses.addIncludePath(term_h.dirname());
        libncurses.installHeader(term_h, "term.h");
        headers_step.dependOn(&b.addInstallHeaderFile(
            term_h,
            "term.h",
        ).step);

        const names_c = runAwkTpl(
            b,
            ncurses.path("ncurses/tinfo/MKnames.awk"),
            &.{ ncurses.path("include/Caps"), ncurses.path("include/Caps-ncurses") },
            "names.c",
        );
        makekeys.addIncludePath(names_c.dirname());
        modncurses.addCSourceFile(.{
            .file = names_c,
            .flags = Sources.flags(options.target),
        });
    }

    const fmt = b.addFmt(.{
        .paths = &.{
            "build.zig",
            "build.zig.zon",
            "src",
        },
    });
    b.step("fmt", "zig fmt").dependOn(&fmt.step);
}

pub const FileOrString = union(enum) {
    filepath: std.Build.LazyPath,
    string: []const u8,
    pub fn file(filepath: std.Build.LazyPath) @This() {
        return .{ .filepath = filepath };
    }
    pub fn str(string: []const u8) @This() {
        return .{ .string = string };
    }
    pub fn addRunArg(self: @This(), run: *std.Build.Step.Run) void {
        switch (self) {
            .filepath => |fp| run.addPrefixedFileArg("file://", fp),
            .string => |string| run.addArg(run.step.owner.fmt("string://{s}", .{string})),
        }
    }
};

/// runs awk prgram and captures stdout
pub fn runAwkTpl(b: *std.Build, prog: std.Build.LazyPath, defs: []const std.Build.LazyPath, basename: []const u8) std.Build.LazyPath {
    const awk_dep = b.dependency("awk", .{
        .target = b.graph.host,
        .optimize = .ReleaseSmall,
    });
    const awk = b.addRunArtifact(awk_dep.artifact("awk"));
    awk.addArg("-f");
    awk.addFileArg(prog);
    awk.addArg("bigstrings=1");
    for (defs) |def| {
        awk.addFileArg(def);
    }
    if (defs.len == 0) awk.setStdIn(.{ .bytes = "" });
    const wf = b.addWriteFiles();
    return wf.addCopyFile(awk.captureStdOut(), basename);
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

/// generates fallback.c
/// replaces "./ncurses/tinfo/MKfallback.sh $(TERMINFO) $(TERMINFO_SRC) "$(TIC_PATH)" "$(INFOCMP_PATH)" $(FALLBACK_LIST)"
pub fn runMakeFallbackC(b: *std.Build, src: []const std.Build.LazyPath) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "MakeFallbackC",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/MakeFallbackC.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    const out = run.addOutputFileArg("fallback.c");
    for (src) |s| {
        run.addFileArg(s);
    }
    return out;
}

/// generates lib_gen.c
/// replaces:
/// CC="zig 0.15.1 cc -E -DHAVE_CONFIG_H -DBUILDING_NCURSES -I../ncurses -I. -I../include -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -DNDEBUG"
/// ./base/MKlib_gen.sh "$CC" "mawk" generated <../include/curses.h
pub fn runMakeLibGenC(b: *std.Build, curses_h: std.Build.LazyPath, awk: std.Build.LazyPath) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = "MakeFallbackC",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/MakeLibGenC.zig"),
            .target = b.graph.host,
        }),
    });
    const run = b.addRunArtifact(exe);
    const out = run.addOutputFileArg("lib_gen.c");
    run.addFileArg(curses_h);
    run.addFileArg(awk);
    return out;
}

/// concatenates slices given in the form of a string or lazypath to a file
pub fn runConcatLazyPath(b: *std.Build, src: []const FileOrString, basename: []const u8) std.Build.LazyPath {
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
        s.addRunArg(run);
    }
    return out;
}

/// Replaces keys in a file like configheader, but accepts lazypaths to files as arguments
/// Keys for replacement have no particular syntax.
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
        if (@typeInfo(@TypeOf(value)) == .optional) {
            if (value) |v| {
                run.addArg(field.name);
                run.addFileArg(v);
            } else {
                run.addArg(field.name);
                run.addArg("");
            }
        } else {
            run.addArg(field.name);
            run.addFileArg(value);
        }
    }
    return out;
}

/// a copy of std.Build.Step.ConfigHeader
/// except not writing the comment about it
/// being generated. ncurses templates a `.awk` that does not
/// support c-style comments.
pub fn addConfigHeaderNoComment(
    b: *std.Build,
    options: ConfigHeaderNoComment.Options,
    values: anytype,
) *ConfigHeaderNoComment {
    var options_copy = options;
    if (options_copy.first_ret_addr == null)
        options_copy.first_ret_addr = @returnAddress();

    const config_header_step = ConfigHeaderNoComment.create(b, options_copy);
    config_header_step.addValues(values);
    return config_header_step;
}

pub const Tests = struct {
    dir: []const u8 = "test",
    name: []const u8,
    files: []const []const u8,
    macos: bool = true,

    pub const all: []const Tests = &.{
        .{
            .name = "knight",
            .files = &.{"knight.c"},
        },
        .{
            .name = "terminfo",
            .files = &.{"demo_terminfo.c"},
            .macos = false,
        },
        .{
            .name = "new_pair",
            .files = &.{ "demo_new_pair.c", "popup_msg.c" },
        },
        .{
            .name = "panels",
            .files = &.{"demo_panels.c"},
            .macos = false,
        },
        .{
            .name = "tabs",
            .files = &.{"demo_tabs.c"},
        },
        .{
            .name = "defkey",
            .files = &.{"demo_defkey.c"},
            .macos = false,
        },
        .{
            .name = "forms",
            .files = &.{ "demo_forms.c", "edit_field.c", "popup_msg.c" },
            .macos = false,
        },
        .{
            .name = "keyok",
            .files = &.{"demo_keyok.c"},
        },
        .{
            .name = "menus",
            .files = &.{"demo_menus.c"},
        },
        .{
            .name = "termcap",
            .files = &.{"demo_termcap.c"},
            .macos = false,
        },
        .{
            .name = "worm",
            .files = &.{"worm.c"},
        },
        .{
            .name = "bs",
            .files = &.{"bs.c"},
        },
        .{
            .name = "chgat",
            .files = &.{ "chgat.c", "popup_msg.c" },
        },
        .{
            .name = "combine",
            .files = &.{ "combine.c", "dump_window.c", "popup_msg.c" },
        },
        .{
            .name = "padview",
            .files = &.{ "padview.c", "popup_msg.c" },
            .macos = false,
        },
        .{
            .name = "extended_color",
            .files = &.{"extended_color.c"},
        },
        .{
            .name = "newdemo",
            .files = &.{"newdemo.c"},
        },
        .{
            .name = "tclock",
            .files = &.{"tclock.c"},
            .macos = false,
        },
    };
};

/// listings of c source code files
/// separated by directory
pub const Sources = struct {
    dir: []const u8,
    files: []const []const u8,
    installheaders: []const []const u8 = &.{},
    pub const all: []const Sources = &.{
        ncurses,
        base,
        menu,
        panel,
        form,
        trace,
        tinfo,
        tty,
    };
    pub fn flags(target: std.Build.ResolvedTarget) []const []const u8 {
        return switch (target.result.os.tag) {
            .windows => &(Flags.common ++ .{
                "-Wno-error=unused-parameter",
                "-Wno-error=dll-attribute-on-redeclaration",
                "-Wno-error=tautological-constant-compare",
                // "-Wno-error=ignored-attributes",
            }),
            else => &Flags.common,
        };
    }
    pub const Flags = struct {
        pub const common = .{
            "-Qunused-arguments",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-pedantic",
            "-Wno-error=unused-variable",
            "-Wno-error=unused-but-set-variable",
            "-fno-strict-overflow",
        };
    };

    pub const ncurses: Sources = .{
        .dir = "ncurses",
        .files = &.{},
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
        .installheaders = &.{ "eti.h", "menu.h" },
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
        .installheaders = &.{"panel.h"},
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

    pub const form: Sources = .{
        .dir = "form",
        .installheaders = &.{"form.h"},
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

pub fn ncurses_defs_header(
    b: *std.Build,
    options: Options,
) *std.Build.Step.ConfigHeader {
    return b.addConfigHeader(.{
        .style = .blank,
        .include_path = "ncurses_zig_defs.h",
    }, .{
        .@"GCC_PRINTFLIKE(fmt,var)" = .@"__attribute__((format(printf,fmt,var)))",
        .@"GCC_SCANFLIKE(fmt,var)" = .@"__attribute__((format(scanf,fmt,var)))",
        .CPP_HAS_OVERRIDE = 1,
        .CPP_HAS_STATIC_CAST = 1,
        .DECL_ENVIRON = 1,
        .GCC_NORETURN = .@"__attribute__((noreturn))",
        .GCC_PRINTF = 1,
        .GCC_SCANF = 1,
        .GCC_UNUSED = .@"__attribute__((unused))",
        .HAVE_ALLOC_PAIR = 1,
        .HAVE_ASSUME_DEFAULT_COLORS = 1,
        .HAVE_BIG_CORE = 1,
        .HAVE_CLOCK_GETTIME = 0,
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
        .HAVE_INIT_EXTENDED_COLOR = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_IOSTREAM = 1,
        .HAVE_ISASCII = 1,
        .HAVE_LANGINFO_CODESET = options.only_posix_null(),
        .HAVE_LIBFORM = 1,
        .HAVE_LIBMENU = 1,
        .HAVE_LIBPANEL = 1,
        .HAVE_LIMITS_H = 1,
        .HAVE_LINK = options.only_posix(),
        .HAVE_LOCALE_H = 1,
        .HAVE_LOCALECONV = 1,
        .HAVE_LONG_FILE_NAMES = 1,
        .HAVE_MATH_FUNCS = 1,
        .HAVE_MATH_H = 1,
        .HAVE_WCTOB = 1,
        .HAVE_MBTOWC = 1,
        .HAVE_MBLEN = 1,
        .HAVE_MBRTOWC = 1,
        .HAVE_MBRLEN = 1,
        .HAVE_MEMORY_H = 1,
        .HAVE_MENU_H = 1,
        .HAVE_MKSTEMP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_NAPMS = 1,
        .HAVE_NC_ALLOC_H = 1,
        .HAVE_PANEL_H = 1,
        .HAVE_POLL = options.only_posix_null(),
        .HAVE_POLL_H = options.only_posix_null(),
        .HAVE_PUTENV = 1,
        .HAVE_REGEX_H_FUNCS = options.only_posix_null(),
        .HAVE_REMOVE = 1,
        .HAVE_RESIZE_TERM = 1,
        .HAVE_RESIZETERM = 1,
        .HAVE_SELECT = options.only_posix_null(),
        .HAVE_SETBUF = 1,
        .HAVE_SETBUFFER = 1,
        .HAVE_SETENV = options.only_posix_null(),
        .HAVE_SETFSUID = 1,
        .HAVE_SETVBUF = 1,
        .HAVE_SIGACTION = options.only_posix_null(),
        .HAVE_SIZECHANGE = options.only_posix_null(),
        .HAVE_SLK_COLOR = 1,
        .HAVE_SNPRINTF = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRDUP = 1,
        .HAVE_STRING_H = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRSTR = 1,
        .HAVE_SYMLINK = 1,
        .HAVE_SYS_IOCTL_H = options.only_posix_null(),
        .HAVE_SYS_PARAM_H = 1,
        .HAVE_SYS_POLL_H = options.only_posix_null(),
        .HAVE_SYS_SELECT_H = options.only_posix_null(),
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
        .HAVE_TERMIOS_H = options.only_posix(),
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
        .HAVE_WMEMCHR = 1,
        .HAVE_WORKING_FORK = 1,
        .HAVE_WORKING_POLL = options.only_posix_null(),
        .HAVE_WORKING_VFORK = 1,
        .HAVE_WRESIZE = 1,
        .IOSTREAM_NAMESPACE = 1,
        .MIXEDCASE_FILENAMES = 1,
        .NCURSES_EXT_FUNCS = 1,
        .NCURSES_EXT_PUTWIN = 1,
        .NCURSES_NO_PADDING = 1,
        .NCURSES_OSPEED_COMPAT = @as(u1, switch (options.target.result.os.tag) {
            .macos => 0,
            else => 1,
        }),
        .NCURSES_PATCHDATE = ncurses_version.patch,
        .NCURSES_PATHSEP = @as(u8, switch (options.target.result.os.tag) {
            .windows => ';',
            else => ':',
        }),
        .NCURSES_SP_FUNCS = 1,
        .NCURSES_VERSION = zon_version,
        .NCURSES_VERSION_STRING = zon_version,
        .NCURSES_WIDECHAR = @as(u1, switch (options.widechar) {
            true => 1,
            false => 0,
        }),
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
        .USE_STRING_HACKS = 1,
        .USE_TERM_DRIVER = 1,
        .USE_WIDEC_SUPPORT = @as(u1, switch (options.widechar) {
            true => 1,
            false => 0,
        }),
        .USE_XTERM_PTY = options.only_posix_null(),
        .EXP_WIN32_DRIVER = options.only_windows_null(),
        .USE_WIN32CON_DRIVER = @as(?u1, switch (options.target.result.os.tag) {
            .windows => 1,
            else => null,
        }),
    });
}
