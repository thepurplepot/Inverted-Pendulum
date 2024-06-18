const state = @import("state.zig");
const evolver = @import("evolver.zig");
const std = @import("std");
const agent_info = @import("agent_info.zig");
const scene = @import("scene.zig");
const config = @import("config.zig");
const r = @cImport({
    @cInclude("raylib.h");
});

pub const Stadium = struct {
    s: state.TrainingState,
    e: evolver.Evolver,
    agents: std.ArrayList(*agent_info.AgentInfo),
    tasks: std.ArrayList(scene.Scene),
    target_score: f32 = 8.0,
    bypass_score_threshold: bool = false,

    pub fn create(allocator: std.mem.Allocator) Stadium {
        var agents = std.ArrayList(*agent_info.AgentInfo).init(allocator);
        var tasks = std.ArrayList(scene.Scene).init(allocator);
        var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        for (0..config.population_size) |i| {
            var agent = agent_info.AgentInfo.create(i, 0, allocator);
            agent.createRandomFullConnections(random.random());
            agents.append(agent) catch unreachable;
            tasks.append(scene.Scene.create(i)) catch unreachable;
        }
        const s = state.TrainingState{};
        var e = evolver.Evolver{};
        e.init(s, allocator, agents.items);

        const stadium = Stadium{
            .s = s,
            .e = e,
            .agents = agents,
            .tasks = tasks,
        };

        // stadium.restart_exploration();

        return stadium;
    }

    pub fn destroy(self: *Stadium, allocator: std.mem.Allocator) void {
        self.e.deinit(allocator);
        for (0..config.population_size) |i| {
            self.agents.items[i].destroy(allocator);
        }
        self.agents.deinit();
        for (0..config.population_size) |i| {
            self.tasks.items[i].deinit(allocator);
        }
        self.tasks.deinit();
    }

    pub fn update(self: *Stadium, allocator: std.mem.Allocator, dt: f32) !void {
        self.s.addIteration();
        try self.executeTasks(allocator, dt);
        self.e.evolve();
        self.agents.clearRetainingCapacity();
        self.agents.appendSlice(self.e.getGeneration()) catch unreachable;
        self.s.iteration_best_score = self.e.new_generation[0].score;
        if (self.s.iteration % config.best_save_period == 0) {
            try self.saveBest();
        }
        var buf: [40]u8 = undefined;
        const info: []const u8 = try std.fmt.bufPrintZ(&buf, "Iteration: {}, Best: {d:.2}", .{ self.s.iteration, self.s.iteration_best_score });
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.DrawText(info.ptr, 10, 10, 20, r.MAROON);
        for (0..config.population_size) |i| {
            const alpha = 0.2;
            self.tasks.items[i].agent.draw(alpha);
        }
        r.EndDrawing();
    }

    pub fn initIteration(self: *Stadium, allocator: std.mem.Allocator) void {
        for (0..config.population_size) |i| {
            self.tasks.items[i].deinit(allocator);
            self.tasks.items[i].init(allocator, self.s, self.agents.items[i]);
        }
    }

    pub fn executeTasks(self: *Stadium, allocator: std.mem.Allocator, dt: f32) !void {
        self.initIteration(allocator);

        var threads: [config.population_size]std.Thread = undefined;
        for (0..config.population_size) |i| {
            threads[i] = try std.Thread.spawn(.{}, updateTask, .{ self, i, dt });
            // try self.updateTask(i, dt);
        }

        for (0..config.population_size) |i| {
            threads[i].join();
        }
    }

    fn updateTask(self: *Stadium, i: usize, dt: f32) !void {
        var t: f32 = 0.0;
        while (t < config.max_iteration_time) {
            try self.tasks.items[i].update(dt);
            t += dt;
        }
    }

    fn saveBest(self: *Stadium) !void {
        std.debug.print("Saving best genome\n", .{});
        var buf: [30]u8 = undefined;
        const filename: []const u8 = try std.fmt.bufPrint(&buf, "best_{}.txt", .{self.s.iteration});
        try self.agents.items[0].genome.writeToFile(filename);
    }

    fn restartExploration(self: *Stadium) void {
        std.debug.print("Restarting exploration\n", .{});
        self.s.newExploration();
        var best_genome = self.agents.items[0].genome;
        for (self.agents.items) |agent| {
            agent.genome.deinit();
            agent.genome = best_genome.clone();
        }
    }
};

test "Stadium" {
    const allocator = std.testing.allocator;
    var stadium = Stadium.create(allocator);
    defer stadium.destroy(allocator);

    // r.InitWindow(800, 450, "Inverted Pendulum Simulation");
    // r.SetTargetFPS(60);
    for (0..1000) |_| try stadium.update(allocator, 1.0 / 60.0);
    // stadium.restartExploration();
    // for (0..10) |_| try stadium.update(allocator, 1.0 / 60.0);
    // r.CloseWindow();
}
