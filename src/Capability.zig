const std = @import("std");
const Capability = @This();

pub const List = struct {
    pub const empty: List = .{ .array = .empty };
    array: std.ArrayList(Capability),
    pub fn deinit(self: *List, gpa: std.mem.Allocator) void {
        self.array.deinit(gpa);
    }

    pub fn parseFile(self: *List, gpa: std.mem.Allocator, file: []const u8) !void {
        var line_iter = std.mem.splitScalar(
            u8,
            file,
            '\n',
        );
        while (line_iter.next()) |line| {
            if (line.len == 0) continue;
            if (Capability.parse(line)) |cap| {
                try self.array.append(gpa, cap);
            }
        }
    }

    pub fn sortBy_termcap_value(self: *List) void {
        const ctx = struct {
            pub fn lessThan(_: void, a: Capability, b: Capability) bool {
                if (a.termcap_value == null) {
                    return b.termcap_value != null;
                } else if (b.termcap_value == null) {
                    return false;
                } else {
                    return a.termcap_value.? < b.termcap_value.?;
                }
            }
        };
        std.mem.sort(
            Capability,
            self.array.items,
            {},
            ctx.lessThan,
        );
    }

    pub fn sortBy_termcap_name(self: *List) void {
        const ctx = struct {
            pub fn lessThan(_: void, a: Capability, b: Capability) bool {
                return std.mem.order(u8, a.termcap_name, b.termcap_name) == .lt;
            }
        };
        std.mem.sort(
            Capability,
            self.array.items,
            {},
            ctx.lessThan,
        );
    }
};

terminfo_var: []const u8,
terminfo_cap: []const u8,
type: enum {
    boolean,
    numeric,
    string,
},
termcap_name: []const u8,
termcap_value: ?u32,
termcap_emit: bool,
description: []const u8,
// Column 1: terminfo variable name
// Column 2: terminfo capability name
// Column 3: capability type (boolean, numeric, or string)
// Column 4: termcap capability name
// Column 5: KEY_xxx name, if any, `-' otherwise
// Column 6: value for KEY_xxx name, if any, `-' otherwise
// Column 7: Lead with `Y' if capability should be emitted in termcap
//           translations, `-' otherwise
// Column 8: capability description
pub fn parse(line: []const u8) ?Capability {
    inline for (&.{
        "#",
        "capalias",
        "infoalias",
        "used_by",
        "userdef",
    }) |prefix| {
        if (std.mem.startsWith(u8, line, prefix)) {
            return null;
        }
    }
    var field_iter = std.mem.tokenizeAny(
        u8,
        line,
        "\t ",
    );
    var cap: Capability = .{
        .terminfo_var = undefined,
        .terminfo_cap = undefined,
        .type = undefined,
        .termcap_name = undefined,
        .termcap_value = undefined,
        .termcap_emit = undefined,
        .description = undefined,
    };
    var field_num: usize = 1;
    var last_index: usize = 0;

    while (field_iter.next()) |field| : ({
        field_num += 1;
        last_index = field_iter.index;
    }) {
        switch (field_num) {
            1 => cap.terminfo_var = field,
            2 => cap.terminfo_cap = field,
            3 => {
                if (std.mem.eql(u8, field, "bool")) {
                    cap.type = .boolean;
                } else if (std.mem.eql(u8, field, "num")) {
                    cap.type = .numeric;
                } else if (std.mem.eql(u8, field, "str")) {
                    cap.type = .string;
                } else {
                    std.log.err(
                        "unknown type: {s}\nline: {s}",
                        .{ field, line },
                    );
                    return null;
                }
            },
            4 => {},
            5 => cap.termcap_name = field,
            6 => {
                if (std.mem.eql(u8, field, "-")) {
                    cap.termcap_value = null;
                } else {
                    cap.termcap_value = std.fmt.parseInt(u32, field, 10) catch |err| {
                        std.log.err(
                            "termcap_value: {s} {}",
                            .{ field, err },
                        );
                        return null;
                    };
                }
            },
            7 => {
                if (std.mem.startsWith(u8, field, "Y")) {
                    cap.termcap_emit = true;
                } else if (std.mem.startsWith(u8, field, "-")) {
                    cap.termcap_emit = false;
                } else {
                    std.log.err(
                        "unknown emit field: {s}\ntype: {}\ntermcap_name: {s}\ntermcap_value: {?}\nline: {s}\n",
                        .{
                            field,
                            cap.type,
                            cap.termcap_name,
                            cap.termcap_value,
                            line,
                        },
                    );
                    return null;
                }
            },
            8 => {
                cap.description = std.mem.trim(
                    u8,
                    line[last_index..],
                    &std.ascii.whitespace,
                );
                break;
            },
            else => unreachable,
        }
    }

    if (field_num < 8) {
        std.log.err("not enough fields: {s}", .{line});
        return null;
    }
    return cap;
}

pub fn format(self: Capability, w: *std.Io.Writer) !void {
    if (std.mem.eql(u8, self.termcap_name, "KEY_F(0)")) {
        try w.print(
            "#define KEY_F0\t\t{:0>4}\t\t/* Function keys.  Space for 64 */",
            .{self.termcap_value orelse return},
        );
        try w.writeAll("\n#define KEY_F(n)\t(KEY_F0+(n))\t/* Value of function key n */");
    } else {
        try w.print(
            "#define {s}{s}\t{:0>4}\t\t/* {s} */",
            .{
                self.termcap_name,
                if (self.termcap_name.len < 8) "\t" else "",
                self.termcap_value orelse return,
                self.description,
            },
        );
    }
}
