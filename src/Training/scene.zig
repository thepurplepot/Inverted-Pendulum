const state = @import("state.zig");
const std = @import("std");
const agent_info = @import("agent_info.zig");
const network = @import("../NEAT/network.zig");
const pendulum = @import("../Physics/pendulum.zig");
const cf = @import("../Physics/config.zig");
const neat_cf = @import("../NEAT/config.zig");
const r = @cImport(@cInclude("raylib.h"));

pub const Scene = struct {
    agent_id: ?usize = null,
    freeze_time: f32 = 0.0,
    current_time: f32 = 0.0,
    current_velocity: f32 = 0.0,
    output_sum: f32 = 0.0,
    last_output: f32 = 0.0,
    distance_sum: f32 = 0.0,
    config: state.TrainingState.IterationConfig = undefined,
    net: network.Network = undefined,
    agent: pendulum.Pendulum = undefined,
    ai: *agent_info.AgentInfo = undefined,
    enable_ai: bool = true,

    pub fn create(agent_id: usize) Scene {
        return Scene{ .agent_id = agent_id };
    }

    pub fn init(self: *Scene, allocator: std.mem.Allocator, s: state.TrainingState, ai: *agent_info.AgentInfo) void {
        self.current_time = 0.0;
        self.current_velocity = 0.0;
        self.output_sum = 0.0;
        self.last_output = 0.0;
        self.distance_sum = 0.0;

        self.config = s.iteration_config;

        self.agent = pendulum.Pendulum.create();
        self.ai = ai;

        ai.score = 0.0;
        self.net = ai.generateNetwork(allocator);
    }

    pub fn deinit(self: *Scene, allocator: std.mem.Allocator) void {
        self.net.deinit(allocator);
    }

    pub fn update(self: *Scene, dt: f32) !void {
        const sub_dt = dt / @as(f32, @floatFromInt(self.config.task_sub_steps));

        for (0..self.config.task_sub_steps) |_| {
            if (self.current_time >= self.freeze_time) {
                try self.updateAi(sub_dt);
                self.agent.update(sub_dt);
            }
            //TODO disturbances
            self.current_time += sub_dt;
        }
    }

    pub fn render(self: *Scene) void {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        self.agent.draw();
        r.EndDrawing();
    }

    pub fn updateAi(self: *Scene, dt: f32) !void {
        const pos_x: neat_cf.Scalar = (self.agent.base_position.x - cf.world_size * 0.5) / cf.slider_size * 2;
        const angle_x: neat_cf.Scalar = std.math.cos(self.agent.angle);
        const angle_y: neat_cf.Scalar = std.math.sin(self.agent.angle);
        const angular_vel: neat_cf.Scalar = self.agent.angular_velocity;

        var inputs = [_]neat_cf.Scalar{ pos_x, angle_x, angle_y, angular_vel * dt };
        var output: neat_cf.Scalar = 0.0;

        if (self.enable_ai) {
            try self.net.execute(inputs[0..]);
            output = self.net.getResult()[0];
            // std.debug.print("output: {}\n", .{output});
            self.current_velocity = output * self.config.max_speed;
            self.updateCartPos(dt);
        } else {
            output = self.net.getResult()[0];
        }

        const delta = @abs(output - self.last_output);

        self.last_output = output;
        self.output_sum += delta;
        self.distance_sum += @abs(output);
        self.ai.score += self.getScore(dt, pos_x, self.agent.getEndPos().y);
        // std.debug.print("Score: {}\n", .{self.ai.score});
    }

    fn getScore(self: *Scene, dt: f32, pos_x: f32, pos_y: f32) f32 {
        const threshold = cf.world_height * 0.5 - 0.9 * cf.length * 100.0;
        const dist_to_centre_penalty = @abs(1 - @abs(pos_x));
        if (pos_y < threshold) {
            return (dt * dist_to_centre_penalty / (1.0 + self.output_sum * 0.5));
        }
        return 0.0;
    }

    pub fn updateCartPos(self: *Scene, dt: f32) void {
        const new_pos = self.agent.base_position.x + self.current_velocity * dt;
        const min_pos = cf.world_size * 0.5 - cf.slider_size * 0.5;
        const max_pos = cf.world_size * 0.5 + cf.slider_size * 0.5;

        if (new_pos < min_pos) {
            self.agent.base_position.x = min_pos;
            self.current_velocity = 0.0;
            self.agent.base_velocity = 0.0;
        } else if (new_pos > max_pos) {
            self.agent.base_position.x = max_pos;
            self.current_velocity = 0.0;
            self.agent.base_velocity = 0.0;
        } else {
            self.agent.base_position.x = new_pos;
            self.agent.base_velocity = self.current_velocity;
        }
    }
};
