const std = @import("std");
const r = @import("../raylib.zig");
const config = @import("config.zig");

pub const Pendulum = struct {
    gravity: f32 = config.gravity,
    drag_coefficient: f32 = config.drag_coefficient,
    length: f32 = config.length,
    angle: f32 = std.math.pi,
    angular_velocity: f32 = 0.0,
    base_position: r.Vector2 = r.Vector2{ .x = 0.0, .y = 0.0 },
    base_velocity: f32 = 0.0,
    m: f32 = config.m,
    M: f32 = config.M,
    u: f32 = 0.0,

    pub fn applyForce(self: *Pendulum, force: f32) void {
        self.u = force;
    }

    pub fn update(self: *Pendulum, dt: f32) void {
        const cos_angle = std.math.cos(self.angle);
        const sin_angle = std.math.sin(self.angle);
        const D = self.m * self.length * self.length * (self.M + self.m * (1 - cos_angle * cos_angle));
        const param = self.m * self.length * self.angular_velocity * self.angular_velocity * sin_angle - self.drag_coefficient * self.base_velocity;

        const base_acceleration = (1 / D) * (-self.m * self.m * self.length * self.length * self.gravity * cos_angle * sin_angle + self.m * self.length * self.length * param) + self.m * self.length * self.length * (1 / D) * self.u;
        self.base_velocity += base_acceleration * dt;
        self.base_position.x += self.base_velocity * dt;

        self.base_position.x = std.math.clamp(self.base_position.x, -config.slider_size / 2.0, config.slider_size / 2.0);

        const angular_acceleration = (1 / D) * ((self.m + self.M) * self.m * self.gravity * self.length * sin_angle - self.m * self.length * cos_angle * param) - self.m * self.length * cos_angle * (1 / D) * self.u;
        self.angular_velocity += angular_acceleration * dt;
        self.angle += self.angular_velocity * dt;
    }

    pub fn getEndPos(self: *const Pendulum) r.Vector2 {
        const l = self.length * config.world_size / 4.0;
        const base = toScreenCoords(self.base_position);
        return r.Vector2{
            .x = base.x + l * std.math.sin(self.angle),
            .y = base.y - l * std.math.cos(self.angle),
        };
    }

    pub fn toScreenCoords(pos: r.Vector2) r.Vector2 {
        return r.Vector2{
            .x = pos.x * config.world_size / 4.0 + config.world_size / 2.0,
            .y = pos.y * config.world_height / 4.0 + config.world_height / 2.0,
        };
    }

    pub fn draw(self: *const Pendulum, alpha: f32) void {
        const origin = toScreenCoords(self.base_position);
        const end = self.getEndPos();
        r.DrawLineV(origin, end, r.ColorAlpha(r.BLACK, alpha));
        r.DrawCircleV(end, 10, r.ColorAlpha(r.RED, alpha));
        r.DrawRectangleV(r.Vector2{ .x = origin.x - 20, .y = origin.y - 10 }, r.Vector2{ .x = 40, .y = 20 }, r.ColorAlpha(r.BLUE, alpha));
    }
};
