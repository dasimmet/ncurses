const std = @import("std");

const MyInit = struct {
    init: std.process.Init,
    arg0: []const u8,
    cmdargs: []const []const u8,
};

const subcommands = .{
    .{ "make-hashsize", @import("ncurses_util/make_hashsize.zig").main },
    .{ "make-key-defs", @import("ncurses_util/make_key_defs.zig").main },
    .{ "make-keys-list", @import("ncurses_util/make_keys_list.zig").main },
    .{ "make-ncurses-def", @import("ncurses_util/make_ncurses_def.zig").main },
    .{ "make-parametrized", @import("ncurses_util/make_parametrized.zig").main },
    .{ "make-fallback-c", @import("ncurses_util/make_fallback_c.zig").main },
    .{ "make-lib-gen-c", @import("ncurses_util/make_lib_gen_c.zig").main },
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) {
        std.log.err("expected subcommand arg", .{});
        std.process.exit(1);
    }

    inline for (subcommands) |sc| {
        if (std.mem.eql(u8, args[1], sc[0])) {
            return sc[1](init, args[0], args[2..]);
        }
    }

    std.log.err("unknown subcommand: {s}. available commands:", .{args[1]});
    var writer = std.Io.File.stdout().writer(init.io, &.{});
    inline for (subcommands) |sc| {
        try writer.interface.print("{s}\n", .{sc[0]});
    }
    try writer.flush();
    std.process.exit(1);
}
