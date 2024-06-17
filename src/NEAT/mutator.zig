const genome = @import("genome.zig");
const config = @import("config.zig");
const std = @import("std");

fn randomProbability(random: std.Random, prob: f32) bool {
    return random.float(f32) < prob;
}

fn randomIndex(random: std.Random, max: usize) usize {
    return random.uintLessThan(usize, max);
}

fn pickRandom(random: std.Random, T: type, container: []T) *T {
    return &container[randomIndex(random, container.len)];
}

pub fn randomWeight(random: std.Random) f32 {
    return (random.float(f32) - 0.5) * 2.0 * config.weight_range;
}

pub fn mutateGenome(random: std.Random, g: *genome.Genome) void {
    for (0..config.mut_count) |_| {
        if (randomProbability(random, 0.25)) {
            if (randomProbability(random, 0.5)) {
                mutateBiases(random, g);
            } else {
                mutateWeights(random, g);
            }
        }
    }

    if (randomProbability(random, config.new_node_prob) and config.max_hidden_nodes > g.info.hidden_nodes_count) {
        newNode(random, g);
    }

    if (randomProbability(random, config.new_connection_prob)) {
        newConnection(random, g);
    }
}

fn mutateBiases(random: std.Random, g: *genome.Genome) void {
    var node = pickRandom(random, genome.Genome.Node, g.nodes.items);
    if (randomProbability(random, config.new_value_prob)) {
        node.bias = randomWeight(random);
    } else {
        if (randomProbability(random, 0.25)) {
            node.bias += randomWeight(random);
        } else {
            node.bias += config.small_weight_range * randomWeight(random);
        }
    }
}

fn mutateWeights(random: std.Random, g: *genome.Genome) void {
    if (g.connections.items.len == 0) {
        return;
    }

    const connection = pickRandom(random, genome.Genome.Connection, g.connections.items);
    if (randomProbability(random, config.new_value_prob)) {
        connection.weight = randomWeight(random);
    } else {
        if (randomProbability(random, 0.25)) {
            connection.weight += randomWeight(random);
        } else {
            connection.weight += config.small_weight_range * randomWeight(random);
        }
    }
}

fn newNode(random: std.Random, g: *genome.Genome) void {
    if (g.connections.items.len == 0) {
        return;
    }
    // std.debug.print("Added new node to genome", .{});

    const index = randomIndex(random, g.connections.items.len);
    g.splitConnection(index) catch unreachable; // No error expected
}

fn newConnection(random: std.Random, g: *genome.Genome) void {
    const count_without_outputs = g.info.inputs_count + g.info.hidden_nodes_count;
    const count_without_inputs = g.info.hidden_nodes_count + g.info.outputs_count;
    var attempts: usize = 0;
    while (attempts < 5) {
        var index_1 = randomIndex(random, count_without_outputs);

        if (index_1 >= g.info.inputs_count and index_1 < (g.info.inputs_count + g.info.outputs_count)) {
            index_1 += g.info.outputs_count;
        }

        var index_2 = index_1;
        while (index_2 == index_1) {
            index_2 = randomIndex(random, count_without_inputs) + g.info.inputs_count;
        }

        std.debug.assert(!g.isOutput(index_1));
        std.debug.assert(!g.isInput(index_2));

        // Sometimes a created connection already exists or is cyclic
        g.createConnection(index_1, index_2, randomWeight(random)) catch {
            attempts += 1;
            continue;
        };
        return;
    }
}

test "random_probability" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const prob = random.random().float(f32);
    var count: usize = 0;
    for (0..1000) |_| {
        if (randomProbability(random.random(), prob)) {
            count += 1;
        }
    }
    try std.testing.expectApproxEqAbs(prob * 1000, @as(f32, @floatFromInt(count)), 100); //10% error
}

test "random_index" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const result = randomIndex(random.random(), 100);
    try std.testing.expect(result > 0);
}

test "pick_random" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var container = [_]u32{ 1, 2, 3, 4, 5 };
    const result = pickRandom(random.random(), u32, container[0..]);
    try std.testing.expect(result == &container[0] or result == &container[1] or result == &container[2] or result == &container[3] or result == &container[4]);
}

test "random_weight" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const result = randomWeight(random.random());
    try std.testing.expect(result > -config.weight_range);
    try std.testing.expect(result < config.weight_range);
}

test "mutate_biases" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();
    for (0..100) |_| {
        mutateBiases(random.random(), &g);
    }
    try std.testing.expect(g.nodes.items[0].bias != 0.0);
    try std.testing.expect(g.nodes.items[1].bias != 0.0);
    try std.testing.expect(g.nodes.items[2].bias != 0.0);
}

test "mutate_weights" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();
    try g.createConnection(0, 2, 1.0);
    try g.createConnection(1, 2, -1.0);

    for (0..10) |_| {
        mutateWeights(random.random(), &g);
    }
    try std.testing.expect(g.connections.items[0].weight != 1.0);
    try std.testing.expect(g.connections.items[1].weight != -1.0);
}

test "new_node" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();
    try g.createConnection(0, 2, 1.0);
    try g.createConnection(1, 2, -1.0);

    newNode(random.random(), &g);
    try std.testing.expectEqual(1, g.info.hidden_nodes_count);
}

test "new_connection" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const activation = @import("activation.zig");
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();

    newConnection(random.random(), &g);
    try std.testing.expectEqual(1, g.connections.items.len);

    _ = g.createNode(activation.Activation.Sigmoid, true);
    _ = g.createNode(activation.Activation.Sigmoid, true);

    newConnection(random.random(), &g);
    try std.testing.expectEqual(2, g.connections.items.len);
}

test "mutate_genome" {
    var random = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();

    try g.createConnection(0, 2, 1.0);
    try g.createConnection(1, 2, -1.0);

    var g_copy = g.clone();
    defer g_copy.deinit();

    for (0..3) |_| mutateGenome(random.random(), &g);
    var diff: bool = false;
    if (g.connections.items.len != g_copy.connections.items.len) {
        diff = true;
        return;
    }
    for (g.connections.items, g_copy.connections.items) |after, before| {
        if (after.weight != before.weight) {
            diff = true;
            return;
        }
    }
    if (g.nodes.items.len != g_copy.nodes.items.len) {
        diff = true;
        return;
    }
    for (g.nodes.items, g_copy.nodes.items) |after, before| {
        if (after.bias != before.bias) {
            diff = true;
            return;
        }
    }
    try std.testing.expect(diff);
}
