const std = @import("std");

const vaxis = @import("vaxis");

const FONT = [_][5]u8{
    .{ 0b111, 0b101, 0b101, 0b101, 0b111 }, // 0
    .{ 0b010, 0b110, 0b010, 0b010, 0b111 }, // 1
    .{ 0b111, 0b001, 0b111, 0b100, 0b111 }, // 2
    .{ 0b111, 0b001, 0b111, 0b001, 0b111 }, // 3
    .{ 0b101, 0b101, 0b111, 0b001, 0b001 }, // 4
    .{ 0b111, 0b100, 0b111, 0b001, 0b111 }, // 5
    .{ 0b111, 0b100, 0b111, 0b101, 0b111 }, // 6
    .{ 0b111, 0b001, 0b010, 0b010, 0b010 }, // 7
    .{ 0b111, 0b101, 0b111, 0b101, 0b111 }, // 8
    .{ 0b111, 0b101, 0b111, 0b001, 0b111 }, // 9
    .{ 0b000, 0b010, 0b000, 0b010, 0b000 }, // :
};

const PIXEL_ON = "█";
const PIXEL_OFF = " ";
const SPACING = "  ";

pub fn print_clock(allocator: std.mem.Allocator, win: vaxis.Window, style: vaxis.Style, text: []const u8) !void {
    for (0..5) |row| {
        var line_buf: std.ArrayList(u8) = .empty;
        defer line_buf.deinit(allocator);

        for (text, 0..) |char, i| {
            const font_idx: usize = switch (char) {
                '0'...'9' => char - '0',
                ':' => 10,
                else => return error.InvalidCharacter,
            };

            const bits = FONT[font_idx][row];
            const masks = [_]u8{ 0b100, 0b010, 0b001 };

            for (masks) |mask| {
                if ((bits & mask) != 0) {
                    try line_buf.appendSlice(allocator, PIXEL_ON);
                } else {
                    try line_buf.appendSlice(allocator, PIXEL_OFF);
                }
            }

            if (i < text.len - 1) {
                try line_buf.appendSlice(allocator, SPACING);
            }
        }

        const row_win = win.child(.{ .y_off = @intCast(row), .height = 1 });

        const line_text = try line_buf.toOwnedSlice(allocator);

        const segment = vaxis.Segment{
            .text = line_text,
            .style = style,
        };

        _ = row_win.print(&.{segment}, .{});
    }
}
