const std = @import("std");
const agent_info = @import("../Training/agent_info.zig");
const pendulum = @import("../Physics/pendulum.zig");
const network = @import("../NEAT/network.zig");
const config = @import("../Physics/config.zig");
const r = @cImport(@cInclude("raylib.h"));

pub const Demo = struct {
    agent: pendulum.Pendulum = undefined,
    net: network.Network = undefined,
    enable_ai: bool = true,
    threshold: f32 = config.world_height * 0.5 - 0.9 * config.length * 100.0,

    pub fn init(self: *Demo, allocator: std.mem.Allocator, ai: *agent_info.AgentInfo) void {
        self.agent = pendulum.Pendulum.create();
        self.net = ai.generateNetwork(allocator);
    }

    pub fn reset(self: *Demo) void {
        self.agent.base_position.x = config.world_size * 0.5;
        self.agent.angle = 0.0;
        self.agent.angular_velocity = 0.0;
        self.agent.angular_acceleration = 0.0;
        self.agent.base_velocity = 0.0;
    }

    pub fn deinit(self: *Demo) void {
        self.net.deinit();
    }

    pub fn update(self: *Demo, dt: f32) !void {
        if (r.IsKeyPressed(r.KEY_R)) {
            self.reset();
        }
        if (self.enable_ai) {
            try self.updateAi(dt);
        } else {
            if (r.IsKeyDown(r.KEY_A)) {
                self.agent.base_velocity = -300;
            } else if (r.IsKeyDown(r.KEY_D)) {
                self.agent.base_velocity = 300;
            } else {
                self.agent.base_velocity = 0;
            }
            self.updateCartPos(dt);
        }

        self.agent.update(dt);
    }

    fn updateAi(self: *Demo, dt: f32) !void {
        const pos_x: f32 = (self.agent.base_position.x - config.world_size * 0.5) / config.slider_size * 0.5;
        const angle_x: f32 = std.math.cos(self.agent.angle);
        const angle_y: f32 = std.math.sin(self.agent.angle);
        const angular_vel: f32 = self.agent.angular_velocity;

        var inputs = [_]f32{ pos_x, angle_x, angle_y, angular_vel * dt };

        try self.net.execute(inputs[0..]);
        const output = self.net.getResult()[0];
        self.agent.base_velocity = output * 1000;
        self.updateCartPos(dt);
    }

    fn updateCartPos(self: *Demo, dt: f32) void {
        const new_pos = self.agent.base_position.x + self.agent.base_velocity * dt;
        const min_pos = config.world_size * 0.5 - config.slider_size * 0.5;
        const max_pos = config.world_size * 0.5 + config.slider_size * 0.5;

        if (new_pos < min_pos) {
            self.agent.base_position.x = min_pos;
            self.agent.base_velocity = 0.0;
        } else if (new_pos > max_pos) {
            self.agent.base_position.x = max_pos;
            self.agent.base_velocity = 0.0;
        } else {
            self.agent.base_position.x = new_pos;
        }
    }

    pub fn render(self: *Demo) void {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.DrawLineV(r.Vector2{ .x = 0, .y = self.threshold }, r.Vector2{ .x = config.world_size, .y = self.threshold }, r.DARKGRAY);
        self.agent.draw();
        r.EndDrawing();
    }
};
