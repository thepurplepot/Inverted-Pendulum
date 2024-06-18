const std = @import("std");
const r = @import("../raylib.zig");
const config = @import("config.zig");

pub const Pendulum = struct {
    gravity: f32,
    drag_coefficient: f32,
    length: f32,
    angle: f32,
    angular_velocity: f32,
    angular_acceleration: f32,
    base_position: r.Vector2,
    base_velocity: f32,

    pub fn create() Pendulum {
        r.SetTargetFPS(60);
        return Pendulum{
            .gravity = config.gravity,
            .drag_coefficient = config.drag_coefficient,
            .length = config.length,
            .angle = 0.0,
            .angular_velocity = 0,
            .angular_acceleration = 0,
            .base_position = r.Vector2{ .x = config.world_size / 2, .y = config.world_height / 2 },
            .base_velocity = 0,
        };
    }

    pub fn update(self: *Pendulum, dt: f32) void {
        const angular_acceleration = -(self.gravity / self.length) * std.math.sin(self.angle) - self.drag_coefficient * self.angular_velocity - (self.base_velocity / (self.length * 50)) * std.math.cos(self.angle);
        self.angular_velocity += angular_acceleration * dt;
        self.angle += self.angular_velocity * dt;
    }

    pub fn getEndPos(self: *const Pendulum) r.Vector2 {
        return r.Vector2{
            .x = self.base_position.x + self.length * 100 * std.math.sin(self.angle),
            .y = self.base_position.y + self.length * 100 * std.math.cos(self.angle),
        };
    }

    pub fn draw(self: *const Pendulum, alpha: f32) void {
        const origin = self.base_position;
        const end = r.Vector2{
            .x = origin.x + self.length * 100 * std.math.sin(self.angle),
            .y = origin.y + self.length * 100 * std.math.cos(self.angle),
        };
        r.DrawLineV(origin, end, r.ColorAlpha(r.BLACK, alpha));
        r.DrawCircleV(end, 10, r.ColorAlpha(r.RED, alpha));
        r.DrawRectangleV(r.Vector2{ .x = self.base_position.x - 20, .y = self.base_position.y - 10 }, r.Vector2{ .x = 40, .y = 20 }, r.ColorAlpha(r.BLUE, alpha));
    }
};

// test "Pendulum" {
//     var pendulum = Pendulum.create();
//     pendulum.update(1.0 / 60.0);
// }
