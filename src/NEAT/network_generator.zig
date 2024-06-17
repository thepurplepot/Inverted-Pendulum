const genome = @import("genome.zig");
const network = @import("network.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn generate(allocator: Allocator, g: *genome.Genome) !network.Network {
    var idx_to_order = try allocator.alloc(usize, g.info.getNodesCount());
    defer allocator.free(idx_to_order);
    var n = network.Network{};
    n.init(g.info, g.connections.items.len, allocator);

    const order = g.getOrder();
    defer allocator.free(order);
    for (0..order.len) |i| {
        idx_to_order[order[i]] = i;
    }

    var connection_id: usize = 0;
    var max_node_id: usize = 0;
    for (order, 0..) |o, node_id| {
        const node = g.nodes.items[o];
        n.setNode(node_id, node.activation, node.bias, g.graph.nodes.items[o].getOutgoingCount());
        n.setNodeDepth(node_id, node.depth);

        for (g.connections.items) |c| {
            if (c.from == o) {
                const to = idx_to_order[c.to];
                // std.debug.assert(to > node_id);
                n.setConnection(connection_id, to, c.weight);
                connection_id += 1;
            }
        }
        max_node_id = node_id;
    }

    return n;
}

test "generate" {
    const activation = @import("activation.zig");
    const config = @import("config.zig");
    const allocator = std.testing.allocator;
    var g = genome.Genome.create(allocator, 2, 1);
    defer g.deinit();
    _ = g.createNode(activation.Activation.Sigmoid, true);

    try g.createConnection(0, 2, 1.0);
    try g.createConnection(1, 3, 1.0);
    try g.createConnection(3, 2, 1.0);
    g.computeDepth();

    var n = try generate(allocator, &g);
    defer n.deinit(allocator);
    try std.testing.expectEqual(4, n.info.getNodesCount());
    try std.testing.expectEqual(3, n.connection_count);
    try std.testing.expectEqual(2, n.max_depth);

    var inputs = [2]config.Scalar{
        0.5,
        0.7,
    };

    try n.execute(inputs[0..]);

    const result = n.getResult();
    try std.testing.expectEqual(0.8993156, result[0]);
}
