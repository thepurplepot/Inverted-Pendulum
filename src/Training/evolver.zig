const std = @import("std");
const mutator = @import("../NEAT/mutator.zig");
const selector = @import("selector.zig");
const agent_info = @import("agent_info.zig");
const state = @import("state.zig");
const config = @import("config.zig");

pub const Evolver = struct {
    state: state.TrainingState = undefined,
    selector: selector.Selector = undefined,
    old_generation: []*agent_info.AgentInfo = undefined,
    new_generation: []*agent_info.AgentInfo = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(self: *Evolver, s: state.TrainingState, allocator: std.mem.Allocator, agents: []*agent_info.AgentInfo) void {
        self.state = s;
        self.allocator = allocator;
        self.selector = selector.Selector.create(allocator);
        self.old_generation = allocator.alloc(*agent_info.AgentInfo, config.population_size) catch unreachable;
        self.new_generation = allocator.alloc(*agent_info.AgentInfo, config.population_size) catch unreachable;
        self.setGeneration(agents);
        self.updatePopulation();
    }

    pub fn deinit(self: *Evolver, allocator: std.mem.Allocator) void {
        self.selector.clear();
        allocator.free(self.old_generation);
        allocator.free(self.new_generation);
    }

    fn cmpScores(context: void, a: *agent_info.AgentInfo, b: *agent_info.AgentInfo) bool {
        return std.sort.desc(f32)(context, a.score, b.score);
    }

    pub fn evolve(self: *Evolver) void {
        self.selector.clear();

        std.sort.insertion(*agent_info.AgentInfo, self.old_generation, {}, cmpScores);

        self.state.iteration_best_score = self.old_generation[0].score;
        self.state.iteration += 1;
        std.debug.print("Iteration {}: Best score: {d}\n", .{ self.state.iteration, self.state.iteration_best_score });

        // Elitism
        const elitism_count: usize = @intFromFloat(config.elite_ratio * @as(comptime_float, @floatFromInt(config.population_size)));
        for (0..elitism_count) |i| {
            self.new_generation[i] = self.old_generation[i];
        }

        // Mutate
        for (self.old_generation, 0..) |agent, i| {
            self.selector.add(i, agent.score);
        }
        self.selector.normaliseEntries();
        for (elitism_count..config.population_size) |i| {
            const agent_id = self.selector.pick() catch unreachable;
            self.new_generation[i] = self.old_generation[agent_id].clone(self.old_generation[i].id, self.allocator);
            var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
            mutator.mutateGenome(random.random(), &self.new_generation[i].genome);
        }
        for (elitism_count..config.population_size) |i| {
            self.old_generation[i].destroy(self.allocator);
        }

        self.updatePopulation();
    }

    pub fn setGeneration(self: *Evolver, agents: []*agent_info.AgentInfo) void {
        for (agents, 0..) |agent, i| {
            self.new_generation[i] = agent;
        }
    }

    pub fn getGeneration(self: *Evolver) []*agent_info.AgentInfo {
        return self.new_generation;
    }

    pub fn updatePopulation(self: *Evolver) void {
        std.mem.copyForwards(*agent_info.AgentInfo, self.old_generation, self.new_generation);
    }
};

test "Evolver" {
    const allocator = std.testing.allocator;
    const s = state.TrainingState{};

    const agents = try allocator.alloc(*agent_info.AgentInfo, config.population_size);
    defer allocator.free(agents);

    for (0..config.population_size) |i| {
        const agent = agent_info.AgentInfo.create(i, @as(f32, @floatFromInt(i)), allocator);
        agents[i] = agent;
    }

    var evolver = Evolver{};
    evolver.init(s, allocator, agents);
    defer evolver.deinit(allocator);

    evolver.evolve();
    evolver.evolve();

    const evolved_agents = evolver.getGeneration();
    defer for (evolved_agents) |agent| {
        agent.destroy(allocator);
    };
    // for (0..config.population_size) |i| {
    //     const agent = evolved_agents[i];
    //     std.debug.print("Agent ID: {} Score: {d}\n", .{ agent.id, agent.score });
    // }
}
