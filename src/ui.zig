const std = @import("std");

const vaxis = @import("vaxis");

const time = @cImport(@cInclude("time.h"));

const DEFAULT_COLOR = [_]u8{ 50, 255, 50 };
const SLEEP_DELTA = 16;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub fn render(init: std.process.Init, allocator: std.mem.Allocator) !void {
    var buffer: [1024]u8 = undefined;
    var tty: vaxis.Tty = try .init(init.io, &buffer);
    defer tty.deinit();

    var vx = try vaxis.init(init.io, allocator, init.environ_map, .{});
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .init(init.io, &tty, &vx);

    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    try vx.queryColor(tty.writer(), .fg);
    try vx.queryColor(tty.writer(), .bg);

    while (true) {
        while (try loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) return,
                .winsize => |ws| {
                    try vx.resize(allocator, tty.writer(), ws);
                    break;
                },
            }
        }

        const win = vx.window();
        win.clear();

        const color: vaxis.Color = .{ .rgb = DEFAULT_COLOR };

        const text = try get_formatted_time(allocator);
        defer allocator.free(text);

        const segment: vaxis.Segment = .{
            .text = text,
            .style = .{ .fg = color, .bold = true },
        };

        const center = vaxis.widgets.alignment.center(win, @intCast(text.len - 1), 1);
        _ = center.printSegment(segment, .{ .wrap = .word });
        try vx.render(tty.writer());
        try init.io.sleep(.fromMilliseconds(SLEEP_DELTA), .real);
    }
}

fn get_formatted_time(allocator: std.mem.Allocator) ![]const u8 {
    const t = time.time(null);
    const localtime = time.localtime(&t).*;

    const hours = @as(u32, @intCast(localtime.tm_hour));
    const minutes = @as(u32, @intCast(localtime.tm_min));
    const seconds = @as(u32, @intCast(localtime.tm_sec));

    return std.fmt.allocPrint(allocator, "{0d:0>2}:{1d:0>2}:{2d:0>2}\n", .{ hours, minutes, seconds });
}
