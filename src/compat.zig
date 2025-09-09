const std = @import("std");
const builtin = @import("builtin");

const zig_0_16_205_or_newer = builtin.zig_version.order(std.SemanticVersion.parse("0.16.0-dev.204") catch unreachable) == .gt;

pub fn cwdReadFileAlloc(path: []const u8, gpa: std.mem.Allocator, max_bytes: usize) ![]const u8 {
    if (zig_0_16_205_or_newer) {
        return std.fs.cwd().readFileAlloc(path, gpa, .limited(max_bytes));
    } else {
        return std.fs.cwd().readFileAlloc(gpa, path, max_bytes);
    }
}
