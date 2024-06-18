const std = @import("std");
const agent_info = @import("../Training/agent_info.zig");
const pendulum = @import("../Physics/pendulum.zig");
const network = @import("../NEAT/network.zig");
const config = @import("../Physics/config.zig");
const r = @cImport(@cInclude("raylib.h"));
const scene = @import("../Training/scene.zig");
const state = @import("../Training/state.zig");

pub const Demo = struct {
    s: scene.Scene = undefined,
    ai: *agent_info.AgentInfo = undefined,
    allocator: std.mem.Allocator = undefined,
    enable_ai: bool = true,
    time_multiplier: u32 = 5,

    pub fn init(self: *Demo, allocator: std.mem.Allocator, ai: *agent_info.AgentInfo) void {
        self.ai = ai;
        self.allocator = allocator;
        self.s = scene.Scene.create(0);
        self.s.init(allocator, state.TrainingState{}, ai);
    }

    pub fn deinit(self: *Demo) void {
        self.s.deinit(self.allocator);
    }

    pub fn reset(self: *Demo) void {
        self.s.deinit(self.allocator);
        self.s.init(self.allocator, state.TrainingState{}, self.ai);
    }

    pub fn update(self: *Demo, dt: f32) !void {
        self.s.enable_ai = self.enable_ai;
        if (!self.enable_ai) {
            self.time_multiplier = 1;
            if (r.IsKeyDown(r.KEY_A)) {
                self.s.current_velocity = -300;
            } else if (r.IsKeyDown(r.KEY_D)) {
                self.s.current_velocity = 300;
            } else {
                self.s.current_velocity = 0;
            }
        } else {
            self.time_multiplier = 5;
        }
        if (r.IsKeyPressed(r.KEY_R)) {
            self.reset();
        }
        for (0..self.time_multiplier) |_| {
            try self.s.update(dt);
        }
    }

    pub fn render(self: *Demo) void {
        var buf: [20]u8 = undefined;
        const time: []const u8 = std.fmt.bufPrintZ(&buf, "Time: {d:.2} s", .{self.s.current_time}) catch unreachable;
        var scoreBuf: [20]u8 = undefined;
        const score = std.fmt.bufPrintZ(&scoreBuf, "Score: {d:.2}", .{self.s.ai.score}) catch unreachable;
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.DrawText(time.ptr, 10, 10, 20, r.DARKGRAY);
        r.DrawText(score.ptr, 10, 330, 20, r.DARKGRAY);
        // r.DrawLineV(r.Vector2{ .x = 0, .y = self.threshold }, r.Vector2{ .x = config.world_size, .y = self.threshold }, r.DARKGRAY);
        self.s.agent.draw(1.0);
        r.EndDrawing();
    }
};
