const std = @import("std");
const g = @import("../NEAT/genome.zig");
const config = @import("config.zig");
const network = @import("../NEAT/network.zig");
const network_generator = @import("../NEAT/network_generator.zig");
const mutator = @import("../NEAT/mutator.zig");

pub const AgentInfo = struct {
    id: usize,
    score: f32 = 0.0,
    genome: g.Genome = undefined,

    pub fn create(id: usize, score: f32, allocator: std.mem.Allocator) *AgentInfo {
        const a = allocator.create(AgentInfo) catch unreachable;
        a.id = id;
        a.score = score;
        a.resetGenome(allocator);
        return a;
    }

    pub fn clone(self: *AgentInfo, id: usize, allocator: std.mem.Allocator) *AgentInfo {
        const a = allocator.create(AgentInfo) catch unreachable;
        a.id = id;
        a.score = self.score;
        a.genome = self.genome.clone();
        return a;
    }

    pub fn resetGenome(self: *AgentInfo, allocator: std.mem.Allocator) void {
        self.genome = g.Genome.create(allocator, config.input_count, config.output_count);
    }

    pub fn destroy(self: *AgentInfo, allocator: std.mem.Allocator) void {
        self.genome.deinit();
        allocator.destroy(self);
    }

    pub fn generateNetwork(self: *AgentInfo, allocator: std.mem.Allocator) network.Network {
        return network_generator.generate(allocator, &self.genome) catch unreachable;
    }

    pub fn createRandomFullConnections(self: *AgentInfo, random: std.Random) void {
        for (config.input_count..config.input_count + config.output_count) |i| {
            for (0..config.input_count) |j| {
                self.genome.createConnection(j, i, mutator.randomWeight(random)) catch unreachable;
            }
        }
    }
};
