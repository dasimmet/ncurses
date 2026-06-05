const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const cwd = std.Io.Dir.cwd();

    std.debug.assert(args.len >= 3);
    const outpath = args[1];
    const inpaths = args[2..];

    const outfile = try cwd.createFile(io, outpath, .{});
    defer outfile.close(io);

    var outbuf: [4096]u8 = undefined;
    var output = outfile.writer(io, &outbuf);
    defer output.interface.flush() catch unreachable;
    const writer = &output.interface;

    for (inpaths) |ip| {
        if (std.mem.startsWith(u8, ip, "file://")) {
            const infile = try cwd.readFileAlloc(io, ip["file://".len..], gpa, .unlimited);
            defer gpa.free(infile);
            try writer.writeAll(infile);
        } else if (std.mem.startsWith(u8, ip, "string://")) {
            try writer.writeAll(ip["string://".len..]);
        }
    }
}
