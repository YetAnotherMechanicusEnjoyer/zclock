const std = @import("std");
const eql = std.mem.eql;

const String = @import("string").String;

const ui = @import("ui.zig");

const APP_NAME: []const u8 = "zclock";

const Error = error{
    BadUsage,
};

pub fn main(init: std.process.Init) !u8 {
    const io = init.io;
    const allocator = init.arena.allocator();

    var args = try init.minimal.args.iterateAllocator(allocator);
    _ = args.skip();

    var err_ctx = String.init(allocator);
    defer err_ctx.deinit();

    cli(init, allocator, &args, &err_ctx) catch |err| {
        if (err == Error.BadUsage) print_usage(io);
        if (err_ctx.len() > 0) {
            std.log.err("Exited with error: {}: {s}.", .{ err, err_ctx.content });
        } else std.log.err("Exited with error: {}", .{err});
        return 1;
    };
    return 0;
}

fn cli(init: std.process.Init, allocator: std.mem.Allocator, args: *std.process.Args.Iterator, err_ctx: *String) !void {
    _ = err_ctx;
    while (args.next()) |arg| {
        if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            print_usage(init.io);
            return;
        } else return Error.BadUsage;
    }

    try ui.render(init, allocator);
}

fn print_usage(io: std.Io) void {
    var buffer: [1024]u8 = undefined;
    const stdout = std.Io.File.stdout();
    var writer = stdout.writer(io, &buffer);

    const dim = "\x1b[0;90m";
    const blue = "\x1b[1;94m";
    const green = "\x1b[0;1;92m";
    const bold = "\x1b[0;1m";
    const reset = "\x1b[0m";

    const to_print = .{
        .{ "{s}:: {s}Usage{s}:{s}\n", .{ dim, blue, dim, reset } },
        .{ "   {s}{s}{s} [OPTIONS]\n\n", .{ green, APP_NAME, reset } },
        .{ "{s}:: {s}Options{s}:{s}\n", .{ dim, blue, dim, reset } },
        .{ "   {s}-h, --help{s}                  Display this help message \n", .{ bold, reset } },
    };

    inline for (to_print) |item| {
        writer.interface.print(item[0], item[1]) catch |e| {
            std.log.err("writing usage: {any}", .{e});
        };
    }

    writer.flush() catch |e| {
        std.log.err("flushing stdout: {any}", .{e});
    };
}
