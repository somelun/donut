const std = @import("std");

const ascii_gradient = ".,-~:;=!*#$@";

const screen_width = 90;
const screen_height = 90;

const R1 = 1.0;
const R2 = 2.0;
const K2 = 5.0;
const K1 = screen_width * K2 * 3.0 / (8.0 * (R1 + R2));

const delta_theta = 0.07;
const delta_phi = 0.02;

var should_exit = std.atomic.Value(bool).init(false);

fn wait_for_enter() !void {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    _ = try reader.readByte();

    should_exit.store(true, .seq_cst);
}

inline fn rotate_and_normalize(t: f32, x: *f32, y: *f32) void {
    const f_temp = x.*;
    x.* -= t * y.*;
    y.* += t * f_temp;
    const f = (3.0 - x.* * x.* - y.* * y.*) * 0.5;
    x.* *= f;
    y.* *= f;
}

fn draw_donut(buffer: []u8, z_buffer: []f32, cosA: f32, sinA: f32, cosB: f32, sinB: f32) void {
    // Clean the buffers
    @memset(buffer, ' ');
    @memset(z_buffer, 0.0);

    var theta: f32 = 0;
    while (theta < 2 * std.math.pi) : (theta += delta_theta) {
        const cosTheta = std.math.cos(theta);
        const sinTheta = std.math.sin(theta);
        const circle_x: f32 = R2 + R1 * cosTheta;
        const circle_y: f32 = R1 * sinTheta;

        var phi: f32 = 0;
        while (phi < 2 * std.math.pi) : (phi += delta_phi) {
            const cosPhi = std.math.cos(phi);
            const sinPhi = std.math.sin(phi);

            const x: f32 = circle_x * (cosB * cosPhi + sinA * sinB * sinPhi) - circle_y * cosA * sinB;
            const y: f32 = circle_x * (sinB * cosPhi - sinA * cosB * sinPhi) + circle_y * cosA * cosB;
            const z: f32 = K2 + cosA * circle_x * sinPhi + circle_y * sinA;
            const ooz: f32 = 1 / z;

            const xp: i32 = @intFromFloat(screen_width / 2 + K1 * ooz * x);
            const yp: i32 = @intFromFloat(screen_height / 2 - K1 * ooz * y);

            // bounds checking
            if (xp >= 0 and xp < screen_width and yp >= 0 and yp < screen_height) {
                const xp_u: usize = @intCast(xp);
                const yp_u: usize = @intCast(yp);
                const buffer_index = yp_u * screen_width + xp_u;

                const L = cosPhi * cosTheta * sinB - cosA * cosTheta * sinPhi - sinA * sinTheta + cosB * (cosA * sinTheta - cosTheta * sinA * sinPhi);

                if (L > 0) {
                    if (ooz > z_buffer[buffer_index]) {
                        z_buffer[buffer_index] = ooz;
                        // clamp luminance index to valid range
                        const luminance_index: usize = @min(@as(usize, @intFromFloat(L * 8)), ascii_gradient.len - 1);
                        buffer[buffer_index] = ascii_gradient[luminance_index];
                    }
                }
            }
        }
    }
}

fn print_buffer(buffer: []const u8, writer: anytype) !void {
    var i: usize = 0;
    while (i < screen_height) : (i += 1) {
        const row_start = i * screen_width;
        const row_end = row_start + screen_width;
        const row = buffer[row_start..row_end];
        try writer.print("{s}\n", .{row});
    }
}

pub fn main() !void {
    var buffer: [screen_width * screen_height]u8 = undefined;
    var z_buffer: [screen_width * screen_height]f32 = undefined;

    _ = try std.Thread.spawn(.{}, wait_for_enter, .{});

    var cosA: f32 = 1.0;
    var sinA: f32 = 0.0;
    var cosB: f32 = 1.0;
    var sinB: f32 = 0.0;
    const stdout = std.io.getStdOut().writer();

    while (!should_exit.load(.seq_cst)) {
        // clear screen and move cursor to top-left
        _ = stdout.print("\x1B[2J\x1B[H", .{}) catch {};

        draw_donut(&buffer, &z_buffer, cosA, sinA, cosB, sinB);
        try print_buffer(&buffer, stdout);

        rotate_and_normalize(0.04, &cosA, &sinA);
        rotate_and_normalize(0.02, &cosB, &sinB);

        std.time.sleep(50 * std.time.ns_per_ms);
    }
    // clear screen and move cursor to top-left
    _ = stdout.print("\x1B[2J\x1B[H", .{}) catch {};
}
