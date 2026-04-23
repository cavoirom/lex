const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

const Diacritic = enum(u8) {
    empty, // nguyên âm, không dấu.
    circumflex, // dấu nón: â, ô, ê.
    horn, // dấu móc: ư, ơ.
    breve, // dấu ă.
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
    diacritic: Diacritic = Diacritic.empty,
    // By default, no tone is placed.
    tone: Tone = Tone.level,

    pub fn init(base: u8) Span {
        // Only allow a-zA-Z.
        assert(std.ascii.isAlphabetic(base));
        return .{ .base = base };
    }
};

test "expect Span.init allows alphabet characters" {
    inline for ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz") |c| {
        // Act
        const sp = Span.init(c);

        // Assert
        try expectEqual(c, sp.base);
        try expectEqual(Diacritic.empty, sp.diacritic);
        try expectEqual(Tone.level, sp.tone);
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
    // value (256), we will reset the effective buffer and this value.
    buffer_length: u8,
    // Mark the position (inclusive) in buffer where we will switch to literal mode (due to manually
    // switch, input cancellation, exceed effective buffer). This value is independent from mode and
    // has higher priority, e.g. if the mode is `telex` but the engine is working on position on or
    // after literal index, the engine will skip Vietnamese input processing (we only count positive
    // value, -1 mean no literal index).
    literal_start_index: i8,
    // Determine if we will process input in the specified mode (Telex) or append the character as is.
    mode: InputMode = InputMode.literal,
};
