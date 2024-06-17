const std = @import("std");
const config = @import("config.zig");

pub const Activation = enum { Linear, Sigmoid, ReLU, Tanh };
pub const ActivationFn = *const fn (config.Scalar) config.Scalar;

pub fn getActivationFn(activation: Activation) ActivationFn {
    switch (activation) {
        Activation.Linear => return linear,
        Activation.Sigmoid => return sigmoid,
        Activation.ReLU => return relu,
        Activation.Tanh => return tanh,
    }
}

pub fn linear(x: config.Scalar) config.Scalar {
    return x;
}

pub fn sigmoid(x: config.Scalar) config.Scalar {
    return 1.0 / (1.0 + std.math.exp(-4.9 * x));
}

pub fn relu(x: config.Scalar) config.Scalar {
    return (x + @abs(x)) * 0.5;
}

pub fn tanh(x: config.Scalar) config.Scalar {
    return std.math.tanh(x);
}
