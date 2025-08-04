const std = @import("std");

const ascii_gradient = ".,-~:;=!*#$@";

const screen_width = 80;
const screen_height = 80;

const R1 = 1.0;
const R2 = 2.0;
const K2 = 5.0;
const K1 = screen_width * K2 * 3.0 / (8.0 * (R1 + R2));

const delta_theta = 0.07;
const delta_phi = 0.02;

var should_exit = std.atomic.Value(bool).init(false);

fn waitForEnter() !void {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    _ = try reader.readByte();

    should_exit.store(true, .seq_cst);
}

fn draw_donut(buffer: []u8, z_buffer: []f32, A: f32, B: f32) void {
    const cosA: f32 = std.math.cos(A);
    const sinA: f32 = std.math.sin(A);
    const cosB: f32 = std.math.cos(B);
    const sinB: f32 = std.math.sin(B);

    // Clean the buffer
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
    const allocator = std.heap.c_allocator;

    const buffer = try allocator.alloc(u8, screen_width * screen_height);
    defer allocator.free(buffer);

    const z_buffer = try allocator.alloc(f32, screen_width * screen_height);
    defer allocator.free(z_buffer);

    _ = try std.Thread.spawn(.{}, waitForEnter, .{});

    var A: f32 = 0.0;
    var B: f32 = 0.0;
    const stdout = std.io.getStdOut().writer();

    while (!should_exit.load(.seq_cst)) {
        // clear screen and move cursor to top-left
        _ = stdout.print("\x1B[2J\x1B[H", .{}) catch {};

        draw_donut(buffer, z_buffer, A, B);
        try print_buffer(buffer, stdout);

        A += 0.04;
        B += 0.02;

        std.time.sleep(50 * std.time.ns_per_ms);
    }
    // clear screen and move cursor to top-left
    _ = stdout.print("\x1B[2J\x1B[H", .{}) catch {};
}
