const std = @import("std");

pub fn main() !u8 {
    var arena_instance: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const arena = arena_instance.allocator();

    var out: ?[]const u8 = null;
    var width: i32 = 153;
    var square: bool = false;
    var fill: []const u8 = "#f7a41d";

    {
        const args = try std.process.argsAlloc(arena);
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                std.debug.print("Usage: generatesvg  [--out OUT] [--width WIDTH] [--square] [--fill STRING]\n", .{});
                return 0xff;
            } else if (std.mem.eql(u8, arg, "--out")) {
                i += 1;
                if (i >= args.len) fatal("--out missing argument", .{});
                out = args[i];
            } else if (std.mem.eql(u8, arg, "--width")) {
                i += 1;
                if (i >= args.len) fatal("--width missing argument", .{});
                width = std.fmt.parseInt(i32, args[i], 10) catch fatal(
                    "invalid width '{s}'",
                    .{args[i]},
                );
            } else if (std.mem.eql(u8, arg, "--square")) {
                square = true;
            } else if (std.mem.eql(u8, arg, "--fill")) {
                i += 1;
                if (i >= args.len) fatal("--fill missing argument", .{});
                fill = args[i];
            } else fatal("unknown cmdline option '{s}'", .{arg});
        }
    }
    // ensure height/2 is an integer so we are vertically cenetered
    const half_height: i32 = round(float(width) * 0.456);
    const height: i32 = half_height * 2;

    const stroke: i32 = round(float(width) * 0.144);
    const top0: i32 = stroke;
    const top1: i32 = top0 + stroke;
    const top2: i32 = reflectInt(height, top1);
    const top3: i32 = reflectInt(height, top0);

    const file: ?std.fs.File = if (out) |o| try std.fs.cwd().createFile(o, .{}) else null;
    defer if (file) |f| f.close();

    var bw = std.io.bufferedWriter(if (file) |f| f.writer() else std.io.getStdOut().writer());
    const writer = bw.writer();
    try writer.print(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {} {}\" fill=\"{s}\"",
        .{ width, if (square) width else height, fill },
    );
    if (square) {
        try writer.print(" transform=\"translate(0 {})\"", .{@divTrunc(width - height, 2)});
    }
    try writer.print("><g>\n", .{});

    // NOTE: we draw the SVG this way so that we can customize antialiasing behavior for
    //       orthogonal vs diagonal lines.

    // The Diagonal Part of the Z
    const slash_left0 = round(float(width) * 0.020);
    const slash_left1 = round(float(width) * 0.332);
    try writer.print(
        "\t<polygon points=\"{[left0]},{[height]} {[right1]},{[top0]} {[right0]},0 {[left1]},{[bottom1]}\"/>\n",
        .{
            .left0 = slash_left0,
            .left1 = slash_left1,
            .right0 = reflectInt(width, slash_left0),
            .right1 = reflectInt(width, slash_left1),
            .top0 = top0,
            .bottom1 = reflectInt(height, top0),
            .height = height,
        },
    );

    const dash_left0 = round(float(width) * 0.242);
    const dash_left1 = round(float(width) * 0.369);

    // The top/bottom bars of the Z
    inline for (&.{ false, true }) |bottom| {
        const transform: fn (i32, i32) i32 = if (bottom) reflectInt else passthruInt;
        const right = reflectInt(width, slash_left1);
        try writer.print(
            "" ++
                "\t<polygon points=\"{[x1]},{[y0]} {[x4]},{[y0]} {[x4]},{[y3]} {[x0]},{[y3]} {[x1]},{[y1]}\" shape-rendering=\"crispEdges\"/>\n" ++
                "\t<polygon points=\"{[x1]},{[y0]} {[x3]},{[y2]} {[x0]},{[y3]}\"/>\n",

            .{
                .x0 = transform(width, dash_left0),
                .x1 = transform(width, dash_left1),
                .x3 = transform(width, interp(dash_left1, right, 0.2)),
                .x4 = transform(width, right),
                .y0 = transform(height, top0),
                .y1 = transform(height, interp(top0, top1, 0.6)),
                .y2 = transform(height, interp(top0, top1, 0.75)),
                .y3 = transform(height, top1),
            },
        );
    }
    try writer.print("</g><g>\n", .{});

    // The Left/Right border pieces
    const cutout_width = float(width) * 0.061;
    const x1: f32 = findIntersectionX(.{
        .horizontal_line_y = top3,
        .line_x1 = slash_left0,
        .line_y1 = height,
        .line_x2 = reflectInt(width, slash_left1),
        .line_y2 = top0,
    }) - cutout_width;
    const x3: f32 = findIntersectionX(.{
        .horizontal_line_y = top2,
        .line_x1 = slash_left0,
        .line_y1 = height,
        .line_x2 = reflectInt(width, slash_left1),
        .line_y2 = top0,
    }) - cutout_width;

    inline for (&.{ false, true }) |right| {
        const transform: fn (i32, i32) i32 = if (right) reflectInt else passthruInt;
        const transformFloat: fn (i32, f32) f32 = if (right) reflectFloat else passthruFloat;
        try writer.print(
            "" ++
                "\t<polygon points=\"{[x0]},{[y0]} {[x5]},{[y0]} {[x4]},{[y1]} {[x4]},{[y2]} {[x2]},{[y2]} {[x2]},{[y3]} {[x3]d:.1},{[y3]} {[x1]d:.1},{[y4]} {[x1]d:.1},{[y5]} {[x0]},{[y5]}\" shape-rendering=\"crispEdges\"/>\n" ++
                "\t<polygon points=\"{[x5]},{[y0]} {[x4]},{[y2]} {[x1]d:.1},{[y1]}\"/>\n" ++
                "\t<polygon points=\"{[x3]d:.1},{[y3]} {[x1]d:.1},{[y5]} {[x0]},{[y4]}\"/>\n",
            .{
                .x0 = transform(width, 0),
                .x1 = transformFloat(width, x1),
                .x2 = transform(width, stroke),
                .x3 = transformFloat(width, x3),
                .x4 = transform(width, dash_left0 - round(cutout_width)),
                .x5 = transform(width, dash_left1 - round(cutout_width)),

                .y0 = transform(height, top0),
                .y1 = transform(height, interp(top0, top1, 0.4)),
                .y2 = transform(height, top1),
                .y3 = transform(height, top2),
                .y4 = transform(height, interp(top2, top3, 0.4)),
                .y5 = transform(height, top3),
            },
        );
        try writer.print("</g><g>\n", .{});
    }
    try writer.print("</g></svg>\n", .{});
    try bw.flush();
    return 0;
}

fn findIntersectionX(args: struct {
    horizontal_line_y: i32,
    line_x1: i32,
    line_y1: i32,
    line_x2: i32,
    line_y2: i32,
}) f32 {
    if (args.line_y1 == args.line_y2) return if (args.line_y1 == args.horizontal_line_y)
        float(args.line_x1)
    else
        float(@min(args.line_x1, args.line_x2) - 1);

    const slope = float(args.line_y2 - args.line_y1) / float(args.line_x2 - args.line_x1);
    const y_intercept = float(args.line_y1) - slope * float(args.line_x1);
    const intersection_x = (float(args.horizontal_line_y) - y_intercept) / slope;
    const min_x = @min(args.line_x1, args.line_x2);
    const max_x = @max(args.line_x1, args.line_x2);
    if (intersection_x >= float(min_x) and intersection_x <= float(max_x)) {
        return intersection_x;
    } else {
        return float(@min(args.line_x1, args.line_x2) - 1);
    }
}

fn float(i: i32) f32 {
    return @floatFromInt(i);
}
fn round(f: f32) i32 {
    return @intFromFloat(@round(f));
}
fn interp(a: i32, b: i32, ratio: f32) i32 {
    return a + round(float(b - a) * ratio);
}

fn passthruInt(size: i32, i: i32) i32 {
    _ = size;
    return i;
}
fn reflectInt(size: i32, i: i32) i32 {
    return size - i;
}

fn passthruFloat(size: i32, f: f32) f32 {
    _ = size;
    return f;
}
fn reflectFloat(size: i32, f: f32) f32 {
    return @as(f32, @floatFromInt(size)) - f;
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    std.process.exit(0xff);
}
