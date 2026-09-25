const std = @import("std");

const vaxis = @import("vaxis");
const print_clock = @import("font.zig").print_clock;

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

    var frame_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer frame_arena.deinit();

    while (true) {
        _ = frame_arena.reset(.retain_capacity);
        const frame_allocator = frame_arena.allocator();

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

        try draw(frame_allocator, win);

        try vx.render(tty.writer());
        try init.io.sleep(.fromMilliseconds(SLEEP_DELTA), .real);
    }
}

fn draw(allocator: std.mem.Allocator, win: vaxis.Window) !void {
    const color: vaxis.Color = .{ .rgb = DEFAULT_COLOR };
    const style = vaxis.Style{ .fg = color, .bold = true };

    const formatted_time = try get_formatted_time(allocator);
    defer allocator.free(formatted_time);

    const clock_win = win.child(.{ .x_off = @intCast(@max(0, win.width / 2 - 16)), .y_off = @intCast(@max(0, win.height / 2 - 3)) });

    try print_clock(allocator, clock_win, style, formatted_time);
}

fn get_formatted_time(allocator: std.mem.Allocator) ![]const u8 {
    const t = time.time(null);
    const localtime = time.localtime(&t).*;

    const hours = @as(u32, @intCast(localtime.tm_hour));
    const minutes = @as(u32, @intCast(localtime.tm_min));
    const seconds = @as(u32, @intCast(localtime.tm_sec));

    return std.fmt.allocPrint(allocator, "{0d:0>2}:{1d:0>2}:{2d:0>2}", .{ hours, minutes, seconds });
}
