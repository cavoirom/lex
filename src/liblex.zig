const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;

const Diacritic = enum(u8) {
    empty, // nguyên âm, không dấu.
    circumflex, // dấu nón: â, ô, ê.
    horn, // dấu móc: ư, ơ.
    breve, // dấu ă.
    bar, // dấu gạch: đ.
};

const Tone = enum(u8) {
    level, // thanh ngang, không dấu.
    rising, // sắc.
    falling, // huyền.
    dipping_rising, // hỏi.
    rising_glottalized, // ngã.
    falling_glottalized, // nặng.
};

const Span = extern struct {
    // Alphabet ASCII character, could be lowercase or uppercase.
    base: u8,
    // By default, it's plain alphabet character.
    diacritic: Diacritic = .empty,
    // By default, no tone is placed.
    tone: Tone = .level,

    // Create a Span with plain alphabet character, no diacritic, no tone.
    pub fn init(base: u8) Span {
        return Span.init_diacritic_tone(base, .empty, .level);
    }

    // Create a Span with diacritic, no tone.
    pub fn init_diacritic(base: u8, diacritic: Diacritic) Span {
        return Span.init_diacritic_tone(base, diacritic, .level);
    }

    pub fn init_diacritic_tone(base: u8, diacritic: Diacritic, tone: Tone) Span {
        // Only allow a-zA-Z.
        assert(std.ascii.isAlphabetic(base));

        // Only allow a valid Vietnamese alphabet combinations.
        switch (diacritic) {
            // All alphabet is allowed without diacritic.
            .empty => {},
            // Only a, o, e are valid with circumflex.
            .circumflex => switch (base) {
                'A', 'E', 'O', 'a', 'e', 'o' => {},
                else => unreachable,
            },
            // Only u, o are valid with horn.
            .horn => switch (base) {
                'O', 'U', 'o', 'u' => {},
                else => unreachable,
            },
            // Only a is valid with breve.
            .breve => switch (base) {
                'A', 'a' => {},
                else => unreachable,
            },
            // Only d is valid with bar.
            .bar => switch (base) {
                'D', 'd' => {},
                else => unreachable,
            },
        }

        // Only allow tone on valid Vietnamese vowels based on Vietnamese rules.
        switch (tone) {
            // All alphabet is allowed with level.
            .level => {},
            // All vowels is allowed with remaining tones.
            .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized => switch (base) {
                'A', 'E', 'I', 'O', 'U', 'Y', 'a', 'e', 'i', 'o', 'u', 'y' => {},
                else => unreachable,
            },
        }

        return .{ .base = base, .diacritic = diacritic, .tone = tone };
    }
};

test "expect Span.init allows alphabet characters" {
    // Arrange
    for ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz") |c| {
        // Act
        const sp = Span.init(c);

        // Assert
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect Span.init_diacritic can construct any alphabet characters" {
    // Arrange
    for ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz") |c| {
        // Act
        const sp = Span.init_diacritic(c, .empty);

        // Assert
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect Span.init_diacritic can construct any Vietnamese characters" {
    // Arrange
    const chars = .{
        .{ .base = 'A', .diacritic = .breve }, // Ă.
        .{ .base = 'a', .diacritic = .breve }, // ă.
        .{ .base = 'A', .diacritic = .circumflex }, // Â.
        .{ .base = 'a', .diacritic = .circumflex }, // â.
        .{ .base = 'E', .diacritic = .circumflex }, // Ê.
        .{ .base = 'e', .diacritic = .circumflex }, // ê.
        .{ .base = 'O', .diacritic = .circumflex }, // Ô.
        .{ .base = 'o', .diacritic = .circumflex }, // ô.
        .{ .base = 'O', .diacritic = .horn }, // Ơ.
        .{ .base = 'o', .diacritic = .horn }, // ơ.
        .{ .base = 'U', .diacritic = .horn }, // Ư.
        .{ .base = 'u', .diacritic = .horn }, // ư.
        .{ .base = 'D', .diacritic = .bar }, // Đ.
        .{ .base = 'd', .diacritic = .bar }, // đ.
    };

    // Need `inline for` to know the tuple at comptime.
    inline for (chars) |c| {
        // Act
        const sp = Span.init_diacritic(c.base, c.diacritic);

        // Assert
        try expectEqual(c.base, sp.base);
        try expectEqual(c.diacritic, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect Span.init_diacritic_tone can construct all vowels with all tones" {
    // Arrange
    const chars = .{
        .{ .base = 'A', .diacritic = .empty }, // A.
        .{ .base = 'A', .diacritic = .breve }, // Ă.
        .{ .base = 'A', .diacritic = .circumflex }, // Â.
        .{ .base = 'E', .diacritic = .empty }, // E.
        .{ .base = 'E', .diacritic = .circumflex }, // Ê.
        .{ .base = 'I', .diacritic = .empty }, // I.
        .{ .base = 'O', .diacritic = .empty }, // O.
        .{ .base = 'O', .diacritic = .circumflex }, // Ô.
        .{ .base = 'O', .diacritic = .horn }, // Ơ.
        .{ .base = 'U', .diacritic = .empty }, // U.
        .{ .base = 'U', .diacritic = .horn }, // Ư.
        .{ .base = 'Y', .diacritic = .empty }, // Y.
        .{ .base = 'a', .diacritic = .empty }, // a.
        .{ .base = 'a', .diacritic = .breve }, // ă.
        .{ .base = 'a', .diacritic = .circumflex }, // â.
        .{ .base = 'e', .diacritic = .empty }, // e.
        .{ .base = 'e', .diacritic = .circumflex }, // ê.
        .{ .base = 'i', .diacritic = .empty }, // i.
        .{ .base = 'o', .diacritic = .empty }, // o.
        .{ .base = 'o', .diacritic = .circumflex }, // ô.
        .{ .base = 'o', .diacritic = .horn }, // ơ.
        .{ .base = 'u', .diacritic = .empty }, // u.
        .{ .base = 'u', .diacritic = .horn }, // ư.
        .{ .base = 'y', .diacritic = .empty }, // y.
    };

    const tones = .{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    inline for (chars) |c| {
        inline for (tones) |t| {
            // Act
            const sp = Span.init_diacritic_tone(c.base, c.diacritic, t);

            // Assert
            try expectEqual(c.base, sp.base);
            try expectEqual(c.diacritic, sp.diacritic);
            try expectEqual(t, sp.tone);
        }
    }
}

const InputMode = enum(u8) {
    // By pass Vietnamese input processing and append the character as is.
    literal,
    // Process Vietnamese input in Telex input method.
    telex,
};

const State = extern struct {
    // The effective buffer to process Vietnamese input. we will skip processing if the buffer
    // longer than 16.
    buffer_effective: [16]Span,
    // The maximum buffer length that the engine still keeps the effective buffer, after the maximum
    // value (255), we will reset the effective buffer and this value.
    buffer_length: u8 = 0,
    // Mark the earliest position (inclusive) in buffer where we modified the span, will be used to
    // calculate backspaces and replacement characters.
    buffer_modification_index: i8 = -1,
    // Mark the position (inclusive) in buffer where we will switch to literal mode (due to manually
    // switch, input cancellation, exceed effective buffer). This value is independent from mode and
    // has higher priority, e.g. if the mode is `telex` but the engine is working on position on or
    // after literal index, the engine will skip Vietnamese input processing (we only count positive
    // value, -1 mean no literal index).
    literal_index: i8 = -1,
    // Determine if we will process input in the specified mode (Telex) or append the character as is.
    mode: InputMode = .literal,

    // Initialize the State on allocated memory.
    pub fn init(self: *State) void {
        self.* = .{
            .buffer_effective = undefined,
        };
    }

    pub fn add(self: *State, c: u8) void {
        // Only allow a-zA-Z.
        assert(std.ascii.isAlphabetic(c));

        // The buffer_modification index must be inbound of the buffer_effective.
        assert(self.buffer_modification_index >= -1 and self.buffer_modification_index < self.buffer_effective.len);

        // The literal_index value must be in range -1 -> 16 (buffer_effective length) because we won't
        // process Vietnamese input outside the buffer_effective.
        assert(self.literal_index >= -1 and self.literal_index <= self.buffer_effective.len);
        // The literal_index value must be less than buffer length.
        assert(self.literal_index < self.buffer_length);

        // Input mode must be either .literal or .telex.
        assert(self.mode == .literal or self.mode == .telex);

        switch (c) {
            'A', 'a' => { // circumflex.
                if (self.literal_index > -1 or self.mode == .literal) {
                    // Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.

                    // Check if we can add new span for input character.
                    if (self.buffer_length < self.buffer_effective.len) {
                        // Add character to span.
                        self.buffer_effective[self.buffer_length] = Span.init(c);
                    }
                    // Increase the buffer length for tracking, we will need it went handling backspace.
                    self.buffer_length = self.buffer_length + 1;

                    // Set modification index to -1 because we didn't modify any existing span.
                    self.buffer_modification_index = -1;
                } else {
                    // buffer_length must inbound of buffer_effective.
                    assert(self.buffer_length < self.buffer_effective.len);

                    // literal_index must not be set in order to process Vietnamese input.
                    assert(self.literal_index == -1);

                    // Vietnamese input.
                    // Possible cases:
                    // - circumplex.
                    // - cancel circumflex.
                    // - plain append.

                    if (self.buffer_length == 0 or (self.buffer_effective[self.buffer_length - 1].base != std.ascii.toUpper(c) and self.buffer_effective[self.buffer_length - 1].base != std.ascii.toLower(c))) {
                        // Plain append when start of the buffer or the previous character don't match
                        // circumflex rules.

                        // Check if we can add new span for input character.
                        if (self.buffer_length < self.buffer_effective.len) {
                            // Add character to span.
                            self.buffer_effective[self.buffer_length] = Span.init(c);
                        }
                        // Increase the buffer length for tracking, we will need it went handling
                        // backspace.
                        self.buffer_length = self.buffer_length + 1;

                        // Set modification index to -1 because we didn't modify any existing span.
                        self.buffer_modification_index = -1;
                    } else if ((self.buffer_effective[self.buffer_length - 1].base == std.ascii.toUpper(c) or self.buffer_effective[self.buffer_length - 1].base == std.ascii.toLower(c)) and self.buffer_effective[self.buffer_length - 1].diacritic == .empty) {
                        // Circumflex.

                        // Add circumflex to previous plan 'A' or 'a'.
                        self.buffer_effective[self.buffer_length - 1].diacritic = .circumflex;
                        // Mark modification index.
                        self.buffer_modification_index = @intCast(self.buffer_length - 1);
                    } else if ((self.buffer_effective[self.buffer_length - 1].base == std.ascii.toUpper(c) or self.buffer_effective[self.buffer_length - 1].base == std.ascii.toLower(c)) and self.buffer_effective[self.buffer_length - 1].diacritic == .circumflex) {
                        // Cancel circumflex.

                        // Reset diacritic to empty.
                        self.buffer_effective[self.buffer_length - 1].diacritic = .empty;
                        // Mark modification index.
                        self.buffer_modification_index = @intCast(self.buffer_length - 1);

                        // Add plan character to buffer_effective.
                        // Check if we can add new span for input character.
                        if (self.buffer_length < self.buffer_effective.len) {
                            // Add character to span.
                            self.buffer_effective[self.buffer_length] = Span.init(c);
                        }
                        // Mark the start of literal input because of the cancelling.
                        self.literal_index = @intCast(self.buffer_length);

                        // Increase the buffer length for tracking, we will need it went handling
                        // backspace.
                        self.buffer_length = self.buffer_length + 1;
                    } else {
                        unreachable;
                    }
                }
            },
            'C', 'c' => {}, // fill missing diacritic, e.g. cước.
            'D', 'd' => {}, // bar.
            'E', 'e' => {}, // circumflex.
            'F', 'f' => {}, // falling.
            'I', 'i' => {}, // fill missing diacritic, e.g. người.
            'J', 'j' => {}, // falling_glottalized.
            'M', 'm' => {}, // fill missing diacritic, e.g. cườm.
            'N', 'n' => {}, // fill missing diacritic, e.g. cường.
            'O', 'o' => {}, // circumflex.
            'P', 'p' => {}, // fill missing diacritic, e.g. cướp.
            'R', 'r' => {}, // dipping_rising.
            'S', 's' => {}, // rising.
            'T', 't' => {}, // fill missing diacritic, e.g. trượt.
            'U', 'u' => {}, // fill missing diacritic, e.g. hươu.
            'W', 'w' => {}, // breve.
            'X', 'x' => {}, // rising_glottalized.
            'Z', 'z' => {}, // level / reset.
            else => { // literal.
                // These characters will be added to state literally.

                // Check if we can add new span for input character.
                if (self.buffer_length < self.buffer_effective.len) {
                    // Add character to span.
                    self.buffer_effective[self.buffer_length] = Span.init(c);
                }
                // Increase the buffer length for tracking, we will need it went handling backspace.
                self.buffer_length = self.buffer_length + 1;

                // Set modification index to -1 because we didn't modify any existing span.
                self.buffer_modification_index = -1;
                // Set literal index if it's not set and the length exceed the buffer_effective.
                if (self.literal_index == -1 and self.buffer_length > self.buffer_effective.len) {
                    // Set literal mode since buffer index 16 (just after the last buffer_effective
                    // item) because we don't have span for these position, we stop processing Telex
                    // rules but we will continue processing if user use backspaces to move back to the
                    // buffer_effective range, all existing spans must work as expected.
                    self.literal_index = self.buffer_effective.len;
                }
            },
        }
    }
};

// Simple ABI wrapper for initialize allocated memory.
export fn lex_state_init(state: *State) void {
    state.init();
}

// Needed for the caller to allocate memory for our State.
export const lex_state_size: usize = @sizeOf(State);

// Needed for the caller to allocate memory for our State.
export const lex_state_alignment: usize = @alignOf(State);

// Add operations to the given state based on Telex rules, operations are determined by the input
// character.
export fn lex_add(state: *State, c: u8) void {
    state.add(c);
}

test "expect lex_add handles non-Telex characters less than buffer_effective range" {
    // Arrange

    // Allocate memory, only specify on this test to simulate runtime allocation.
    const raw_pointer = std.testing.allocator.rawAlloc(lex_state_size, .fromByteUnits(lex_state_alignment), @returnAddress()) orelse return error.OutOfMemory;
    defer std.testing.allocator.rawFree(raw_pointer[0..lex_state_size], .fromByteUnits(lex_state_alignment), @returnAddress());
    const state: *align(lex_state_alignment) State = @ptrCast(@alignCast(raw_pointer));

    // Initialize state.
    lex_state_init(state);
    state.mode = .telex;

    const input_sequence = "bbbbbqqqqq";

    // Act
    for (input_sequence) |c| {
        lex_add(state, c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(10, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect -1.
    try expectEqual(-1, state.buffer_modification_index);
    // Because we didn't exceed the buffer_affective, don't set literal_index.
    try expectEqual(-1, state.literal_index);
    // Don't touch on input mode.
    try expectEqual(.telex, state.mode);
    // Verify every the spans, must exactly the same with the input.
    for (input_sequence, 0..) |c, i| {
        const sp = state.buffer_effective[i];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect lex_add handles non-Telex characters exceed the buffer_effective range" {
    // Arrange
    var state: State = undefined;
    lex_state_init(&state);
    state.mode = .telex;

    const input_sequence = "bbbbbbbbbbqqqqqqqqqq";

    // Act
    for (input_sequence) |c| {
        lex_add(&state, c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(20, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect -1.
    try expectEqual(-1, state.buffer_modification_index);
    // Because the input exceed the buffer_effective, we set literal_index after the last effective spans (16).
    try expectEqual(16, state.literal_index);
    // Don't touch on input mode.
    try expectEqual(.telex, state.mode);
    // Verify every the spans, must exactly the same with the input.
    for (input_sequence[0..16], 0..) |c, i| {
        const sp = state.buffer_effective[i];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect lex_add adds a literally because it's the start of the buffer" {
    // Arrange
    var state: State = undefined;
    lex_state_init(&state);
    state.mode = .telex;

    // Act
    lex_add(&state, 'a');

    // Assert
    try expectEqual(1, state.buffer_length);
    try expectEqual(-1, state.buffer_modification_index);
    try expectEqual(-1, state.literal_index);
    try expectEqual(.telex, state.mode);

    const sp = state.buffer_effective[0];
    try expectEqual('a', sp.base);
    try expectEqual(.empty, sp.diacritic);
    try expectEqual(.level, sp.tone);
}

test "expect lex_add results â when input aa" {
    // Arrange
    var state: State = undefined;
    lex_state_init(&state);
    state.mode = .telex;

    // Act
    lex_add(&state, 'a');
    lex_add(&state, 'a');

    // Assert
    try expectEqual(1, state.buffer_length);
    try expectEqual(0, state.buffer_modification_index);
    try expectEqual(-1, state.literal_index);
    try expectEqual(.telex, state.mode);

    const sp = state.buffer_effective[0];
    try expectEqual('a', sp.base);
    try expectEqual(.circumflex, sp.diacritic);
    try expectEqual(.level, sp.tone);
}

test "expect lex_add results aA when input aaA" {
    // Arrange
    var state: State = undefined;
    lex_state_init(&state);
    state.mode = .telex;

    // Act
    lex_add(&state, 'a');
    lex_add(&state, 'a');
    lex_add(&state, 'A');

    // Assert
    try expectEqual(2, state.buffer_length);
    try expectEqual(0, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    const sp1 = state.buffer_effective[0];
    try expectEqual('a', sp1.base);
    try expectEqual(.empty, sp1.diacritic);
    try expectEqual(.level, sp1.tone);

    const sp2 = state.buffer_effective[1];
    try expectEqual('A', sp2.base);
    try expectEqual(.empty, sp2.diacritic);
    try expectEqual(.level, sp2.tone);
}
