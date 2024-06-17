const std = @import("std");
const graph = @import("graph.zig");
const network = @import("network.zig");
const activation = @import("activation.zig");
const config = @import("config.zig");
const Allocator = std.mem.Allocator;

pub const Genome = struct {
    pub const Node = struct {
        bias: config.Scalar = 0.0,
        activation: activation.Activation = activation.Activation.Sigmoid,
        depth: usize = 0,
    };

    pub const Connection = struct {
        from: usize = 0,
        to: usize = 0,
        weight: config.Scalar = 0.0,
    };

    info: network.Network.Info,
    nodes: std.ArrayList(Node),
    connections: std.ArrayList(Connection),
    graph: graph.Graph,

    const GenomeError = error{
        InvalidNode,
        InvalidConnection,
    };

    pub fn create(allocator: Allocator, inputs: usize, outputs: usize) Genome {
        const info = network.Network.Info{
            .inputs_count = inputs,
            .outputs_count = outputs,
            .hidden_nodes_count = 0,
        };

        var genome = Genome{
            .info = info,
            .nodes = std.ArrayList(Node).init(allocator),
            .connections = std.ArrayList(Connection).init(allocator),
            .graph = graph.Graph.init(allocator),
        };

        for (0..inputs) |_| {
            _ = genome.createNode(activation.Activation.Linear, false);
        }

        for (0..outputs) |_| {
            _ = genome.createNode(activation.Activation.Tanh, false);
        }

        return genome;
    }

    pub fn clone(self: *Genome) Genome {
        var genome = Genome{
            .info = self.info,
            .nodes = std.ArrayList(Node).init(self.nodes.allocator),
            .connections = std.ArrayList(Connection).init(self.connections.allocator),
            .graph = graph.Graph.init(self.nodes.allocator),
        };

        for (self.nodes.items) |node| {
            genome.nodes.append(node) catch unreachable;
            genome.graph.addNode();
        }

        for (self.connections.items) |connection| {
            genome.connections.append(connection) catch unreachable;
            genome.graph.addEdge(@intCast(connection.from), @intCast(connection.to)) catch unreachable;
        }

        return genome;
    }

    pub fn clear(self: *Genome) void {
        self.nodes.clearAndFree();
        self.connections.clearAndFree();
        self.graph.clear();
    }

    pub fn deinit(self: *Genome) void {
        self.nodes.deinit();
        self.connections.deinit();
        self.graph.deinit();
    }

    pub fn createNode(self: *Genome, activation_t: activation.Activation, hidden: bool) usize {
        self.nodes.append(Node{ .bias = 0.0, .activation = activation_t, .depth = 0 }) catch unreachable;
        self.graph.addNode();
        if (hidden) {
            self.info.hidden_nodes_count += 1;
        }
        return self.nodes.items.len - 1;
    }

    pub fn createConnection(self: *Genome, from: usize, to: usize, weight: config.Scalar) graph.GraphError!void {
        try self.graph.addEdge(@intCast(from), @intCast(to));
        self.connections.append(Connection{ .from = from, .to = to, .weight = weight }) catch unreachable;
    }

    pub fn splitConnection(self: *Genome, index: usize) anyerror!void {
        if (index >= self.connections.items.len) {
            return GenomeError.InvalidConnection;
        }

        const connection = self.connections.items[index];
        const from = connection.from;
        const to = connection.to;
        const weight = connection.weight;
        self.removeConnection(index);

        const node = self.createNode(activation.Activation.Sigmoid, true);
        try self.createConnection(from, node, weight);
        try self.createConnection(node, to, 1.0);
    }

    fn removeConnection(self: *Genome, index: usize) void {
        const connection = self.connections.items[index];
        self.graph.removeEdge(@intCast(connection.from), @intCast(connection.to)) catch unreachable;
        _ = self.connections.swapRemove(index);
    }

    fn cmpNodeDepths(context: *Genome, a: usize, b: usize) bool {
        return std.sort.asc(usize)({}, context.nodes.items[a].depth, context.nodes.items[b].depth);
    }

    pub fn getOrder(self: *Genome) []usize {
        self.computeDepth();
        var order = self.nodes.allocator.alloc(usize, self.nodes.items.len) catch unreachable;
        for (0..self.nodes.items.len) |i| {
            order[i] = i;
        }
        std.sort.insertion(usize, order, self, cmpNodeDepths);
        return order;
    }

    pub fn computeDepth(self: *Genome) void {
        const node_count = self.nodes.items.len;

        var max_depth: usize = 0;
        self.graph.computeDepths();
        for (0..node_count) |i| {
            self.nodes.items[i].depth = self.graph.nodes.items[i].depth;
            max_depth = @max(max_depth, self.nodes.items[i].depth);
        }

        const output_depth = @max(1, max_depth);
        for (0..self.info.outputs_count) |i| {
            self.nodes.items[self.info.inputs_count + i].depth = output_depth;
        }
    }

    pub fn isInput(self: *Genome, index: usize) bool {
        return index < self.info.inputs_count;
    }

    pub fn isOutput(self: *Genome, index: usize) bool {
        return index >= self.info.inputs_count and index < self.info.inputs_count + self.info.outputs_count;
    }

    pub fn writeToFile(self: *const Genome, filename: []const u8) anyerror!void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        var writer = file.writer();

        try writer.print("{}\n", .{self.info});

        for (self.nodes.items) |node| {
            try writer.print("{}\n", .{node});
        }

        for (self.connections.items) |connection| {
            try writer.print("{}\n", .{connection});
        }
    }

    fn parseInfo(line: []const u8) !network.Network.Info {
        var info = network.Network.Info{ .inputs_count = 0, .outputs_count = 0, .hidden_nodes_count = 0 };

        var parts = std.mem.split(u8, line, ",");
        var part: ?[]const u8 = parts.first();
        while (part != null) {
            var kv = std.mem.split(u8, part.?, " ");
            _ = kv.first();
            const key = kv.next().?;
            _ = kv.next();
            const value = kv.next().?;
            if (std.mem.eql(u8, key, ".inputs_count")) {
                info.inputs_count = try std.fmt.parseInt(u32, value, 10);
            } else if (std.mem.eql(u8, key, ".outputs_count")) {
                info.outputs_count = try std.fmt.parseInt(u32, value, 10);
            } else if (std.mem.eql(u8, key, ".hidden_nodes_count")) {
                info.hidden_nodes_count = try std.fmt.parseInt(u32, value, 10);
            } else {
                return error.UnknownKey;
            }
            part = parts.next();
        }

        return info;
    }

    fn parseNode(line: []const u8) !Node {
        var node = Node{ .bias = 0.0, .activation = activation.Activation.Sigmoid, .depth = 0 };

        var parts = std.mem.split(u8, line, ",");
        var part: ?[]const u8 = parts.first();
        while (part != null) {
            var kv = std.mem.split(u8, part.?, " ");
            _ = kv.first();
            const key = kv.next().?;
            _ = kv.next();
            const value = kv.next().?;
            if (std.mem.eql(u8, key, ".bias")) {
                node.bias = try std.fmt.parseFloat(f32, value);
            } else if (std.mem.eql(u8, key, ".depth")) {
                node.depth = try std.fmt.parseInt(u32, value, 10);
            } else if (std.mem.eql(u8, key, ".activation")) {
                var kvv = std.mem.split(u8, value, ".");
                _ = kvv.first();
                var act: []const u8 = kvv.next().?;
                while (kvv.next()) |v| {
                    act = v;
                }
                if (std.mem.eql(u8, act, "Sigmoid")) {
                    node.activation = activation.Activation.Sigmoid;
                } else if (std.mem.eql(u8, act, "Tanh")) {
                    node.activation = activation.Activation.Tanh;
                } else if (std.mem.eql(u8, act, "Linear")) {
                    node.activation = activation.Activation.Linear;
                } else if (std.mem.eql(u8, act, "ReLU")) {
                    node.activation = activation.Activation.ReLU;
                } else {
                    std.debug.print("Unknown activation: {s}\n", .{act});
                    return error.UnknownKey;
                }
            } else {
                return error.UnknownKey;
            }
            part = parts.next();
        }

        return node;
    }

    fn parseConnection(line: []const u8) !Connection {
        var connection = Connection{ .from = 0, .to = 0, .weight = 0.0 };

        var parts = std.mem.split(u8, line, ",");
        var part: ?[]const u8 = parts.first();
        while (part != null) {
            var kv = std.mem.split(u8, part.?, " ");
            _ = kv.first();
            const key = kv.next().?;
            _ = kv.next();
            const value = kv.next().?;
            if (std.mem.eql(u8, key, ".to")) {
                connection.to = try std.fmt.parseInt(u32, value, 10);
            } else if (std.mem.eql(u8, key, ".from")) {
                connection.from = try std.fmt.parseInt(u32, value, 10);
            } else if (std.mem.eql(u8, key, ".weight")) {
                connection.weight = try std.fmt.parseFloat(f32, value);
            } else {
                std.debug.print("Unknown key: {s}\n", .{key});
                return error.UnknownKey;
            }
            part = parts.next();
        }

        return connection;
    }

    pub fn createFromFile(allocator: Allocator, filename: []const u8) !Genome {
        var genome = Genome{
            .info = network.Network.Info{ .inputs_count = 0, .outputs_count = 0, .hidden_nodes_count = 0 },
            .nodes = std.ArrayList(Node){ .allocator = allocator, .capacity = 0, .items = &[_]Node{} },
            .connections = std.ArrayList(Connection){ .allocator = allocator, .capacity = 0, .items = &[_]Connection{} },
            .graph = graph.Graph.init(allocator),
        };

        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        var reader = file.reader();

        var line = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024);
        var line_count: usize = 0;
        while (line != null) {
            if (line_count == 0) {
                genome.info = try parseInfo(line.?);
            } else if (line_count <= genome.info.getNodesCount()) {
                const node = try parseNode(line.?);
                try genome.nodes.append(node);
                genome.graph.addNode();
            } else {
                const connection = try parseConnection(line.?);
                try genome.connections.append(connection);
                genome.graph.addEdge(@intCast(connection.from), @intCast(connection.to)) catch unreachable;
            }
            allocator.free(line.?);
            line = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024);
            line_count += 1;
        }

        return genome;
    }
};

test "save_load" {
    const allocator = std.testing.allocator;
    var genome = Genome.create(allocator, 2, 1);
    defer genome.deinit();
    _ = genome.createNode(activation.Activation.ReLU, true);
    _ = genome.createNode(activation.Activation.ReLU, true);
    try genome.createConnection(0, 3, 1.0);
    try genome.createConnection(1, 3, -1.0);
    try genome.createConnection(3, 4, 0.5);
    try genome.createConnection(4, 2, 1.0);
    try genome.createConnection(3, 2, 1.0);
    genome.computeDepth();
    try genome.writeToFile("genome.txt");

    var loaded_genome = try Genome.createFromFile(allocator, "genome.txt");
    defer loaded_genome.deinit();
    try loaded_genome.writeToFile("loaded_genome.txt");
    try std.testing.expect(std.meta.eql(genome.info, loaded_genome.info));
    for (0..genome.info.getNodesCount()) |i| {
        try std.testing.expect(std.meta.eql(genome.nodes.items[i], loaded_genome.nodes.items[i]));
    }
    for (0..genome.connections.items.len) |i| {
        try std.testing.expect(std.meta.eql(genome.connections.items[i], loaded_genome.connections.items[i]));
    }
    try std.fs.cwd().deleteFile("genome.txt");
    try std.fs.cwd().deleteFile("loaded_genome.txt");
}

test "split_connection" {
    const allocator = std.testing.allocator;
    var genome = Genome.create(allocator, 2, 1);
    defer genome.deinit();
    try genome.createConnection(0, 2, 1.0);
    try genome.createConnection(1, 2, -1.0);
    try genome.splitConnection(0);
    try genome.splitConnection(0);
    genome.computeDepth();

    try std.testing.expectEqual(2, genome.info.hidden_nodes_count);
    try std.testing.expectEqual(5, genome.nodes.items.len);
    try std.testing.expectEqual(4, genome.connections.items.len);
    try std.testing.expectEqual(activation.Activation.Sigmoid, genome.nodes.items[3].activation);
    try std.testing.expectEqual(activation.Activation.Sigmoid, genome.nodes.items[4].activation);
    try std.testing.expectEqual(2, genome.nodes.items[2].depth);
    try std.testing.expectEqual(1, genome.nodes.items[3].depth);
    try std.testing.expectEqual(1, genome.nodes.items[4].depth);
}

test "remove_connection" {
    const allocator = std.testing.allocator;
    var genome = Genome.create(allocator, 2, 1);
    defer genome.deinit();
    _ = genome.createNode(activation.Activation.ReLU, true);
    _ = genome.createNode(activation.Activation.ReLU, true);
    try genome.createConnection(0, 3, 1.0);
    try genome.createConnection(1, 3, -1.0);
    try genome.createConnection(3, 4, 0.5);
    try genome.createConnection(4, 2, 1.0);
    try genome.createConnection(3, 2, 1.0);
    genome.computeDepth();
    genome.removeConnection(3);
    try std.testing.expectEqual(4, genome.connections.items.len);
}

test "get_order" {
    const allocator = std.testing.allocator;
    var genome = Genome.create(allocator, 2, 1);
    defer genome.deinit();
    _ = genome.createNode(activation.Activation.ReLU, true);
    _ = genome.createNode(activation.Activation.ReLU, true);
    try genome.createConnection(0, 3, 1.0);
    try genome.createConnection(1, 3, -1.0);
    try genome.createConnection(3, 4, 0.5);
    try genome.createConnection(4, 2, 1.0);
    try genome.createConnection(3, 2, 1.0);
    genome.computeDepth();
    const order = genome.getOrder();
    defer allocator.free(order);
    var expected_order = [_]usize{ 0, 1, 3, 4, 2 };
    try std.testing.expectEqualDeep(order, expected_order[0..]);
}

test "compute_depth" {
    const allocator = std.testing.allocator;
    var genome = Genome.create(allocator, 2, 1);
    defer genome.deinit();
    _ = genome.createNode(activation.Activation.ReLU, true);
    _ = genome.createNode(activation.Activation.ReLU, true);
    try genome.createConnection(0, 3, 1.0);
    try genome.createConnection(1, 3, -1.0);
    try genome.createConnection(3, 4, 0.5);
    try genome.createConnection(4, 2, 1.0);
    try genome.createConnection(3, 2, 1.0);
    genome.computeDepth();
    try std.testing.expectEqual(0, genome.nodes.items[0].depth);
    try std.testing.expectEqual(0, genome.nodes.items[1].depth);
    try std.testing.expectEqual(3, genome.nodes.items[2].depth);
    try std.testing.expectEqual(1, genome.nodes.items[3].depth);
    try std.testing.expectEqual(2, genome.nodes.items[4].depth);
}
