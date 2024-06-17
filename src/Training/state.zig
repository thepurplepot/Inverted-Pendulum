pub const TrainingState = struct {
    pub const IterationConfig = struct {
        gravity: f32 = 9.81,
        max_speed: f32 = 1000,

        task_sub_steps: u32 = 1,
    };

    iteration: u32 = 0,
    iteration_exploration: u32 = 0,
    iteration_best_score: f32 = 0,
    iteration_config: IterationConfig = IterationConfig{},

    pub fn addIteration(self: *TrainingState) void {
        self.iteration += 1;
    }

    pub fn newExploration(self: *TrainingState) void {
        self.iteration = 0;
        self.iteration_best_score = 0;
        self.iteration_exploration += 1;
    }
};
