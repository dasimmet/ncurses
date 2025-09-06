const std = @import("std");

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    std.debug.assert(args.len > 3);
    std.debug.assert(args.len % 2 == 1); // we need args in pairs after arg 3
    const inpath = args[1];
    const outpath = args[2];
    const tpl_args = args[3..];

    const infile = try std.fs.cwd().readFileAlloc(gpa, inpath, std.math.maxInt(usize));
    defer gpa.free(infile);

    const outfile = try std.fs.cwd().createFile(outpath, .{});
    defer outfile.close();

    var outbuf: [4096]u8 = undefined;
    var output = outfile.writer(&outbuf);
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
            const v_file = try std.fs.cwd().readFileAlloc(gpa, value, std.math.maxInt(usize));
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
    for (files_used.items, 0..) |fu,i| {
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
