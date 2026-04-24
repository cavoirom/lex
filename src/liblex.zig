const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

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
    // Mark the position (inclusive) in buffer where we will switch to literal mode (due to manually
    // switch, input cancellation, exceed effective buffer). This value is independent from mode and
    // has higher priority, e.g. if the mode is `telex` but the engine is working on position on or
    // after literal index, the engine will skip Vietnamese input processing (we only count positive
    // value, -1 mean no literal index).
    literal_start_index: i8 = -1,
    // Determine if we will process input in the specified mode (Telex) or append the character as is.
    mode: InputMode = .literal,

    // Initialize the State on allocated memory.
    pub fn init(state_pointer: *State) void {
        state_pointer.* = .{
            .buffer_effective = undefined,
        };
    }
};

// Simple ABI wrapper for initialize allocated memory.
export fn lex_state_init(state_pointer: *State) void {
    State.init(state_pointer);
}

// Needed for the caller to allocate memory for our State.
export const lex_state_size: usize = @sizeOf(State);

// Needed for the caller to allocate memory for our State.
export const lex_state_alignment: usize = @alignOf(State);
