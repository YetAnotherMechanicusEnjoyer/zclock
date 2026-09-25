const std = @import("std");

const vaxis = @import("vaxis");
const String = @import("string").String;
const print_clock = @import("font.zig").print_clock;

const time = @cImport(@cInclude("time.h"));

pub const TEXT_HEIGHT = 5;
pub const TEXT_WIDTH = 31;
const DEFAULT_COLOR = [_]u8{ 50, 255, 50 };
const SLEEP_DELTA = 16;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub fn render(init: std.process.Init, allocator: std.mem.Allocator, err_ctx: *String) !void {
    var buffer: [1024]u8 = undefined;
    var tty: vaxis.Tty = .init(init.io, &buffer) catch |e| {
        try err_ctx.push("initializing tty");
        return e;
    };
    defer tty.deinit();

    var vx = vaxis.init(init.io, allocator, init.environ_map, .{}) catch |e| {
        try err_ctx.push("initializing vaxis");
        return e;
    };
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .init(init.io, &tty, &vx);

    loop.start() catch |e| {
        try err_ctx.push("starting event loop");
        return e;
    };
    defer loop.stop();

    init_tui(&vx, &tty, err_ctx) catch |e| {
        try err_ctx.push("initializing tui");
        return e;
    };

    frame_loop(init.io, allocator, &vx, &tty, &loop, err_ctx) catch |e| {
        try err_ctx.push("during frame loop");
        return e;
    };
}

fn init_tui(vx: *vaxis.Vaxis, tty: *vaxis.tty.Tty, err_ctx: *String) !void {
    vx.enterAltScreen(tty.writer()) catch |e| {
        try err_ctx.push("entering alt screen, ");
        return e;
    };
    vx.queryTerminal(tty.writer(), .fromSeconds(1)) catch |e| {
        try err_ctx.push("fetching terminal, ");
        return e;
    };

    vx.queryColor(tty.writer(), .fg) catch |e| {
        try err_ctx.push("fetching foreground color, ");
        return e;
    };
    vx.queryColor(tty.writer(), .bg) catch |e| {
        try err_ctx.push("fetching background color, ");
        return e;
    };
}

fn frame_loop(io: std.Io, allocator: std.mem.Allocator, vx: *vaxis.Vaxis, tty: *vaxis.tty.Tty, loop: *vaxis.Loop(Event), err_ctx: *String) !void {
    var frame_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer frame_arena.deinit();

    while (true) {
        _ = frame_arena.reset(.retain_capacity);
        const frame_allocator = frame_arena.allocator();

        while (try loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) return,
                .winsize => |ws| {
                    vx.resize(allocator, tty.writer(), ws) catch |e| {
                        try err_ctx.push("resizing window, ");
                        return e;
                    };
                    break;
                },
            }
        }

        const win = vx.window();
        win.clear();

        draw(frame_allocator, win) catch |e| {
            try err_ctx.push("while drawing, ");
            return e;
        };

        vx.render(tty.writer()) catch |e| {
            try err_ctx.push("while rendering, ");
            return e;
        };
        io.sleep(.fromMilliseconds(SLEEP_DELTA), .real) catch |e| {
            try err_ctx.push("sleeping thread, ");
            return e;
        };
    }
}

fn draw(allocator: std.mem.Allocator, win: vaxis.Window, err_ctx: *String) !void {
    const color: vaxis.Color = .{ .rgb = DEFAULT_COLOR };
    const style = vaxis.Style{ .fg = color, .bold = true };

    const formatted_time = get_formatted_time(allocator) catch |e| {
        try err_ctx.push("getting formatted time, ");
        return e;
    };
    defer allocator.free(formatted_time);

    const clock_win = win.child(.{ .x_off = @intCast(@max(0, win.width / 2 - TEXT_WIDTH / 2)), .y_off = @intCast(@max(0, win.height / 2 - TEXT_HEIGHT / 2)) });

    print_clock(allocator, clock_win, style, formatted_time) catch |e| {
        try err_ctx.push("while printing clock, ");
        return e;
    };
}

fn get_formatted_time(allocator: std.mem.Allocator) ![]const u8 {
    const t = time.time(null);
    const localtime = time.localtime(&t).*;

    const hours = @as(u32, @intCast(localtime.tm_hour));
    const minutes = @as(u32, @intCast(localtime.tm_min));
    const seconds = @as(u32, @intCast(localtime.tm_sec));

    return std.fmt.allocPrint(allocator, "{0d:0>2}:{1d:0>2}:{2d:0>2}", .{ hours, minutes, seconds });
}
