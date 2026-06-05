const std = @import("std");

// usage:
// template_file_contents <template_filepath> <output_filepath> [<key_name> <value_filepath>]
//
// reads a <template_filename> and a list of pairs of
// <key_name> and <value_filepath>,
// then replaces every occurrence of <key_name> in the template
// with the contents of <value_filepath>

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const cwd = std.Io.Dir.cwd();

    std.debug.assert(args.len > 3);
    std.debug.assert(args.len % 2 == 1); // we need args in pairs after arg 3
    const inpath = args[1];
    const outpath = args[2];
    const tpl_args = args[3..];

    const infile = try cwd.readFileAlloc(io, inpath, gpa, .unlimited);
    defer gpa.free(infile);

    const outfile = try cwd.createFile(io, outpath, .{});
    defer outfile.close(io);

    var outbuf: [4096]u8 = undefined;
    var output = outfile.writer(io, &outbuf);
    defer output.interface.flush() catch unreachable;
    const writer = &output.interface;

    var files = std.ArrayList([]const u8).empty;
    var files_used = std.ArrayList(usize).empty;
    defer {
        for (files.items) |it| gpa.free(it);
        files.deinit(gpa);
        files_used.deinit(gpa);
    }
    {
        var arg_pos: usize = 0;
        while (arg_pos < tpl_args.len) : (arg_pos += 2) {
            const value = tpl_args[arg_pos + 1];
            const v_file = try cwd.readFileAlloc(io, value, gpa, .unlimited);
            try files.append(gpa, v_file);
            try files_used.append(gpa, 0);
        }
    }

    var in_pos: usize = 0;
    while (in_pos < infile.len) {
        const infile_rest = infile[in_pos..];
        var arg_pos: usize = 0;
        var key_pos: usize = infile.len;
        var next_key: ?usize = null;
        while (arg_pos < tpl_args.len) : (arg_pos += 2) {
            const key = tpl_args[arg_pos];
            const key_idx = std.mem.indexOf(u8, infile_rest, key);
            if (key_idx) |kx| {
                if (kx < key_pos) {
                    key_pos = kx;
                    next_key = arg_pos;
                }
            }
        }

        if (next_key) |nk| {
            const key = tpl_args[nk];
            try writer.writeAll(infile_rest[0..key_pos]);
            try writer.writeAll(files.items[nk / 2]);
            in_pos += key_pos + key.len;
            files_used.items[nk / 2] += 1;
        } else {
            try writer.writeAll(infile_rest);
            in_pos = infile.len;
        }
    }
    var found_unused: bool = false;
    for (files_used.items, 0..) |fu, i| {
        if (fu == 0) {
            found_unused = true;
            const key = tpl_args[2 * i];
            const value = tpl_args[2 * i + 1];
            std.log.err("unused template arg:  '{s}'", .{key});
            std.log.err("unused template file: '{s}'", .{value});
        }
    }
    if (found_unused) std.process.exit(1);
}
