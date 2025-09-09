const std = @import("std");
const compat = @import("compat.zig");

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    std.debug.assert(args.len >= 3);
    const outpath = args[1];
    const inpaths = args[2..];

    const outfile = try std.fs.cwd().createFile(outpath, .{});
    defer outfile.close();

    var outbuf: [4096]u8 = undefined;
    var output = outfile.writer(&outbuf);
    defer output.interface.flush() catch unreachable;
    const writer = &output.interface;

    for (inpaths) |ip| {
        const infile = try compat.cwdReadFileAlloc(ip, gpa, std.math.maxInt(usize));
        defer gpa.free(infile);
        try writer.writeAll(infile);
    }
}
