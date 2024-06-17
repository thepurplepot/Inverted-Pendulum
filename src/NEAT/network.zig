const std = @import("std");
const activation = @import("activation.zig");
const config = @import("config.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const Network = struct {
    pub const Info = struct {
        inputs_count: usize,
        outputs_count: usize,
        hidden_nodes_count: usize,

        pub fn getNodesCount(self: *const Info) usize {
            return self.inputs_count + self.outputs_count + self.hidden_nodes_count;
        }
    };

    const Node = struct {
        activation: activation.ActivationFn,
        sum: config.Scalar,
        bias: config.Scalar,
        connection_count: usize,
        depth: usize,

        pub fn getOutput(self: *Node) config.Scalar {
            return self.activation(self.sum + self.bias);
        }
    };

    const Connection = struct {
        to: usize,
        weight: config.Scalar,
        value: config.Scalar,
    };

    const Slot = union(enum) {
        node: Node,
        connection: Connection,
    };

    slots: []Slot = undefined,
    outputs: []config.Scalar = undefined,
    info: Info = undefined,
    max_depth: usize = undefined,
    connection_count: usize = undefined,

    const NetworkError = error{
        InvalidInputCount,
    };

    pub fn init(self: *Network, info: Info, connection_count: usize, allocator: Allocator) void {
        self.info = info;
        self.max_depth = 0;
        self.connection_count = connection_count;

        const slots_count = info.getNodesCount() + connection_count;
        self.slots = allocator.alloc(Slot, slots_count) catch unreachable;
        for (info.getNodesCount()..slots_count) |i| {
            self.slots[i] = .{ .connection = Connection{ .to = 0, .value = 0.0, .weight = 0.0 } };
        }
        self.outputs = allocator.alloc(config.Scalar, info.outputs_count) catch unreachable;
    }

    pub fn deinit(self: *Network, allocator: Allocator) void {
        allocator.free(self.slots);
        allocator.free(self.outputs);
    }

    pub fn getNode(self: *Network, index: usize) *Node {
        switch (self.slots[index]) {
            Slot.node => return &self.slots[index].node,
            else => unreachable,
        }
    }

    pub fn setNode(
        self: *Network,
        index: usize,
        activation_type: activation.Activation,
        bias: config.Scalar,
        connection_count: usize,
    ) void {
        const node = self.getNode(index);
        node.activation = activation.getActivationFn(activation_type);
        node.bias = bias;
        node.connection_count = connection_count;
    }

    pub fn setNodeDepth(self: *Network, index: usize, depth: usize) void {
        const node = self.getNode(index);
        node.depth = depth;
        if (depth > self.max_depth) {
            self.max_depth = depth;
        }
    }

    pub fn getConnection(self: *Network, index: usize) *Connection {
        switch (self.slots[self.info.getNodesCount() + index]) {
            Slot.connection => return &self.slots[self.info.getNodesCount() + index].connection,
            else => unreachable,
        }
    }

    pub fn setConnection(self: *Network, index: usize, to: usize, weight: config.Scalar) void {
        const connection = self.getConnection(index);
        connection.to = to;
        connection.value = 0.0;
        connection.weight = weight;
    }

    pub fn getOutput(self: *Network, index: usize) *Node {
        return self.getNode(self.info.inputs_count + self.info.hidden_nodes_count + index);
    }

    pub fn execute(self: *Network, inputs: []config.Scalar) NetworkError!void {
        if (inputs.len != self.info.inputs_count) {
            return NetworkError.InvalidInputCount;
        }

        const node_count = self.info.getNodesCount();

        for (0..node_count) |i| {
            const node = self.getNode(i);
            node.sum = 0.0;
        }

        for (0..self.info.inputs_count) |i| {
            const node = self.getNode(i);
            node.sum = inputs[i];
        }

        var current_connection_index: usize = 0;
        for (0..node_count) |i| {
            const node = self.getNode(i);
            const output = node.getOutput();
            for (0..node.connection_count) |_| {
                const connection = self.getConnection(current_connection_index);
                current_connection_index += 1;
                connection.value = output * connection.weight;
                const to = self.getNode(connection.to);
                to.sum += connection.value;
            }
        }

        for (0..self.info.outputs_count) |i| {
            self.outputs[i] = self.getOutput(i).getOutput();
        }
    }

    pub fn getResult(self: *Network) []config.Scalar {
        return self.outputs;
    }

    pub fn getMaxDepth(self: *Network) usize {
        return self.max_depth;
    }
};

test "network" {
    const allocator = std.testing.allocator;
    const output_count = 1;
    const input_count = 2;
    const hidden_count = 1;
    const connection_count = 3;
    const slots_count = input_count + output_count + hidden_count + connection_count;

    const info = Network.Info{ .inputs_count = input_count, .outputs_count = output_count, .hidden_nodes_count = hidden_count };
    var network = Network{};

    network.init(info, connection_count, allocator);
    defer network.deinit(allocator);
    try testing.expectEqual(slots_count, network.slots.len);
    try testing.expectEqual(output_count, network.outputs.len);

    network.setNode(0, activation.Activation.Linear, 0.0, 1);
    network.setNodeDepth(0, 0);
    network.setNode(1, activation.Activation.Linear, 0.0, 1);
    network.setNodeDepth(1, 0);
    network.setNode(2, activation.Activation.Sigmoid, 0.0, 1);
    network.setNodeDepth(2, 1);
    network.setNode(3, activation.Activation.Tanh, 0.0, 0);
    network.setNodeDepth(3, 2);

    network.setConnection(0, 3, 1.0);
    network.setConnection(1, 2, 1.0);
    network.setConnection(2, 3, 1.0);

    var inputs = [2]config.Scalar{
        0.5,
        0.7,
    };

    try network.execute(inputs[0..]);

    const result = network.getResult();
    try testing.expectEqual(0.8993156, result[0]);
}
