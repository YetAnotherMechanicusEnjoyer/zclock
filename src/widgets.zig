const std = @import("std");

const vaxis = @import("vaxis");
const String = @import("string").String;

const ui = @import("ui.zig");
const print_clock = @import("font.zig").print_clock;

const time = @cImport(@cInclude("time.h"));

pub fn clock(allocator: std.mem.Allocator, win: *vaxis.Window, err_ctx: *String) !void {
    const color: vaxis.Color = .{ .rgb = ui.DEFAULT_COLOR };
    const style = vaxis.Style{ .fg = color, .bold = true };

    const formatted_time = get_formatted_localtime(allocator) catch |e| {
        try err_ctx.push("getting formatted time, ");
        return e;
    };
    defer allocator.free(formatted_time);

    const clock_win = win.child(.{ .x_off = @intCast(@max(0, win.width / 2 - ui.TEXT_WIDTH / 2)), .y_off = @intCast(@max(0, win.height / 2 - ui.TEXT_HEIGHT / 2)) });

    print_clock(allocator, clock_win, style, formatted_time) catch |e| {
        try err_ctx.push("while printing clock, ");
        return e;
    };
}

fn get_formatted_localtime(allocator: std.mem.Allocator) ![]const u8 {
    const t = time.time(null);
    const localtime = time.localtime(&t).*;

    const hours = @as(u32, @intCast(localtime.tm_hour));
    const minutes = @as(u32, @intCast(localtime.tm_min));
    const seconds = @as(u32, @intCast(localtime.tm_sec));

    return std.fmt.allocPrint(allocator, "{0d:0>2}:{1d:0>2}:{2d:0>2}", .{ hours, minutes, seconds });
}
