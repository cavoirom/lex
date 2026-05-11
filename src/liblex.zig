const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;

const Diacritic = enum(u8) {
    empty, // nguyên âm, không dấu.
    circumflex, // dấu nón: â, ô, ê.
    horn, // dấu móc: ư, ơ.
    breve, // dấu ă.
    stroke, // dấu gạch: đ.
};

const Tone = enum(u8) {
    level, // thanh ngang, không dấu.
    rising, // sắc.
    falling, // huyền.
    dipping_rising, // hỏi.
    rising_glottalized, // ngã.
    falling_glottalized, // nặng.
};

const Span = struct {
    // Alphabet ASCII character, could be lowercase or uppercase.
    base: u8,
    // By default, it's plain alphabet character.
    diacritic: Diacritic = .empty,
    // By default, no tone is placed.
    tone: Tone = .level,

    // Create a Span with plain alphabet character, no diacritic, no tone.
    fn init(base: u8) Span {
        return Span.init_diacritic_tone(base, .empty, .level);
    }

    // Create a Span with diacritic, no tone.
    fn init_diacritic(base: u8, diacritic: Diacritic) Span {
        return Span.init_diacritic_tone(base, diacritic, .level);
    }

    fn init_diacritic_tone(base: u8, diacritic: Diacritic, tone: Tone) Span {
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
            // Only d is valid with stroke.
            .stroke => switch (base) {
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

    // Compare the span with a base character (ignore case) and diacritic, tone is ignored.
    fn equals_ignore_case_and_tone(self: Span, base: u8, diacritic: Diacritic) bool {
        // Base must be alphabet letters.
        assert(std.ascii.isAlphabetic(base));

        return std.ascii.toUpper(self.base) == std.ascii.toUpper(base) and self.diacritic == diacritic;
    }

    // Compare only base character, ignore other aspects.
    fn equals_base(self: Span, base: u8) bool {
        // Base must be alphabet letters.

        return std.ascii.toUpper(self.base) == std.ascii.toUpper(base);
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
    const Case = struct { base: u8, diacritic: Diacritic };
    const chars = [_]Case{
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
        .{ .base = 'D', .diacritic = .stroke }, // Đ.
        .{ .base = 'd', .diacritic = .stroke }, // đ.
    };

    for (chars) |c| {
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
    const Case = struct { base: u8, diacritic: Diacritic };
    const chars = [_]Case{
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

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (chars) |c| {
        for (tones) |t| {
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

const State = struct {
    // The effective buffer to process Vietnamese input. we will skip processing if the buffer
    // longer than 16.
    buffer_effective: [16]Span,
    // The maximum buffer length that the engine still keeps the effective buffer, after the maximum
    // value (255), we will reset the effective buffer and this value.
    buffer_length: u8 = 0,
    // Mark the earliest position (inclusive) in buffer where we modified the span, will be used to
    // calculate backspaces and replacement characters.
    buffer_modification_index: ?u8 = null,
    // Mark the position (inclusive) in buffer where we will switch to literal mode (due to manually
    // switch, input cancellation, exceed effective buffer). This value is only used in .telex mode
    // and the engine is working on position on or after literal index, the engine will skip
    // Vietnamese input processing (we only count valid numbers, null mean no literal index).
    literal_index: ?u8 = null,
    // Determine if we will process input in the specified mode (Telex) or append the character as is.
    mode: InputMode = .literal,

    // Initialize the State on allocated memory.
    fn init(self: *State) void {
        self.* = .{
            .buffer_effective = undefined,
        };
    }

    fn add(self: *State, c: u8) void {
        // Only allow a-zA-Z.
        assert(std.ascii.isAlphabetic(c));

        // The buffer_modification index must be inbound of the buffer_effective.
        assert(self.buffer_modification_index == null or self.buffer_modification_index.? < self.buffer_effective.len);

        // Input mode must be either .literal or .telex.
        assert(self.mode == .literal or self.mode == .telex);

        // Should never set literal_index in .literal mode.
        if (self.mode == .literal) {
            assert(self.literal_index == null);
        }

        if (self.literal_index) |literal_index| {
            // When literal_index is set, mode must be .telex.
            assert(self.mode == .telex);
            // The literal_index value must be in range null or 0 -> 16 (buffer_effective length)
            // because we won't process Vietnamese input outside the buffer_effective.
            assert(literal_index <= self.buffer_effective.len);
            // The literal_index value must be less than buffer length.
            assert(literal_index < self.buffer_length);
        }

        switch (c) {
            'A', 'a' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length == 0) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .empty)) {
                    // 3. Previous span is 'A' or 'a', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .breve)) {
                    // 4. Previous span is 'Ă' or 'ă', override to circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .circumflex)) {
                    // 5. Previous span is 'Â' or 'â', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'A' or 'a'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_base(c)) {
                    // 6. Append literal when previous span is not 'A', 'a' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'C', 'c' => { // fill missing diacritic, e.g. cước.
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            },
            'D', 'd' => { // stroke.
                if (self.literal_index != null or self.mode == .literal or self.buffer_length == 0) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .empty)) {
                    // 3. Previous span is 'D' or 'd', apply stroke.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .stroke, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .stroke)) {
                    // 4. Previous span is 'Đ' or 'đ', cancel stroke for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'D' or 'd'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_base(c)) {
                    // 5. Append literal when previous span is not 'D', 'd' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'E', 'e' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length == 0) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .empty)) {
                    // 3. Previous span is 'E' or 'e', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .circumflex)) {
                    // 4. Previous span is 'Ê' or 'ê', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'E' or 'e'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_base(c)) {
                    // 5. Append literal when previous span is not 'E', 'e' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'F', 'f' => {}, // falling.
            'I', 'i' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. người.
            'J', 'j' => {}, // falling_glottalized.
            'M', 'm' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. cườm.
            'N', 'n' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. cường.
            'O', 'o' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length == 0) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .empty)) {
                    // 3. Previous span is 'O' or 'o', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .horn)) {
                    // 4. Previous span is 'Ơ' or 'ơ', override to circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone(c, .circumflex)) {
                    // 5. Previous span is 'Ô' or 'ô', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'O' or 'o'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_base(c)) {
                    // 6. Append literal when previous span is not 'O', 'o' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'P', 'p' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. cướp.
            'R', 'r' => {}, // dipping_rising.
            'S', 's' => {}, // rising.
            'T', 't' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. trượt.
            'U', 'u' => {
                if (self.literal_index != null or self.mode == .literal or self.buffer_length < 2) {
                    // 1. Enable literal input when literal_index is set or on literal mode. The
                    // literal_index is also set when the word starts with non-Vietnamese onsets.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_and_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_and_tone('O', .empty)) {
                    // 5. Pattern: 'ƯO', fill missing horn on 'O'.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Append the new character literally.
                    self.append_literal(c);
                } else {
                    // 6. No pattern matched, append literally.
                    self.append_literal(c);
                    self.buffer_modification_index = null;
                }
            }, // fill missing diacritic, e.g. hươu.
            'W', 'w' => { // breve, horn
                if (self.literal_index != null or self.mode == .literal or self.buffer_length == 0) {
                    // 1. Literal index is set, stop process Vietnamese input.
                    // 2. Literal mode.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('A', .empty)) {
                    // 4. Previous span is 'A', 'a', apply breve.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .breve, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('A', .circumflex)) {
                    // 5. Previous span is 'Â', 'â', override to breve.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .breve, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('A', .breve)) {
                    // 6. Previous span is 'Ă', 'ă', cancel breve for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('O', .empty)) {
                    // 7. Previous span is 'O', 'o', apply horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('O', .circumflex)) {
                    // 8. Previous span is 'Ô', 'ô', override to horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('O', .horn)) {
                    // 9. Previous span is 'Ơ', 'ơ', cancel horn for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('U', .empty)) {
                    // 10. Previous span is 'U', 'u', apply horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_and_tone('U', .horn)) {
                    // 11. Previous span is 'Ư', 'ư', cancel horn for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (std.mem.indexOfScalar(u8, "AOU", std.ascii.toUpper(self.buffer_effective[self.buffer_length - 1].base)) == null) {
                    // 12. Previous base character is not 'A', 'O', 'U'.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'X', 'x' => {}, // rising_glottalized.
            'Z', 'z' => {}, // level / reset.
            else => { // literal.
                // These characters will be added to state literally.
                self.append_literal(c);
                // Set modification index to null because we didn't modify any existing span.
                self.buffer_modification_index = null;
            },
        }

        // Ensure the literal_index in valid state.
        if (self.mode == .literal) {
            assert(self.literal_index == null);
        }
    }

    // Append literal character when possible. Then inclease the buffer_length.
    fn append_literal(self: *State, c: u8) void {
        // Only allow a-zA-Z.
        assert(std.ascii.isAlphabetic(c));

        // Check if we can add new span for input character.
        if (self.buffer_length < self.buffer_effective.len) {
            // Add character to span.
            self.buffer_effective[self.buffer_length] = Span.init(c);
        }
        // Increase the buffer length for tracking, we will need it went handling backspace.
        self.buffer_length += 1;

        // After increase, the new buffer_length may exceed the buffer_effective, set literal_index if needed.
        if (self.mode == .telex and self.literal_index == null and self.buffer_length == self.buffer_effective.len + 1) {
            self.literal_index = self.buffer_length - 1;
        }
    }

    // Return the last item in buffer_effective, not valid if the buffer_length is out of range.
    fn buffer_effective_last(self: *State) Span {
        // Should not work if buffer_length exceed buffer_effective.
        assert(self.buffer_length <= self.buffer_effective.len);

        return self.buffer_effective[self.buffer_length - 1];
    }

    fn backspace(self: *State) void {
        // buffer_length must be positive for backspace.
        assert(self.buffer_length > 0);

        // Input mode must be either .literal or .telex.
        assert(self.mode == .literal or self.mode == .telex);

        if (self.literal_index) |literal_index| {
            // Input mode must be .telex when literal_index is set.
            assert(self.mode == .telex);
            // literal_index must be within buffer range when set.
            assert(literal_index < self.buffer_length);
        }

        // decrease the buffer_length to match the backspace.
        self.buffer_length -= 1;
        // because backspace doesn't retro-modify the buffer, unset the buffer_modification_index.
        self.buffer_modification_index = null;
        // if the literal_index is out of buffer range, unset it.
        if (self.literal_index != null and self.literal_index.? == self.buffer_length) {
            self.literal_index = null;
        }
    }
};

test "expect State.add handles non-Telex characters less than 1 character of the buffer_effective length" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // 15 characters.
    const input_sequence = "bbbbbqqqqqbbbbb";

    // Act
    for (input_sequence) |c| {
        state.add(c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(15, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect null.
    try expectEqual(null, state.buffer_modification_index);
    // Because we didn't exceed the buffer_affective, don't set literal_index.
    try expectEqual(null, state.literal_index);
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

test "expect State.add handles non-Telex characters fit the buffer_effective length" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // 16 characters.
    const input_sequence = "bbbbbqqqqqbbbbbq";

    // Act
    for (input_sequence) |c| {
        state.add(c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(16, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect null.
    try expectEqual(null, state.buffer_modification_index);
    // Because we didn't exceed the buffer_affective, don't set literal_index.
    try expectEqual(null, state.literal_index);
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

test "expect State.add handles non-Telex characters just exceed the buffer_effective length" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // 17.
    const input_sequence = "bbbbbqqqqqbbbbbqq";

    // Act
    for (input_sequence) |c| {
        state.add(c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(17, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect null.
    try expectEqual(null, state.buffer_modification_index);
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

test "expect State.add adds a literally because it's the start of the buffer" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // Act
    state.add('a');

    // Assert
    try expectEqual(1, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);
    try expectEqual(.telex, state.mode);

    const sp = state.buffer_effective[0];
    try expectEqual('a', sp.base);
    try expectEqual(.empty, sp.diacritic);
    try expectEqual(.level, sp.tone);
}

test "expect State.add start literal input when the new input just exceeds buffer_effective" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // input 16 characters.
    for ("bbbbbqqqqqbbbbbq") |c| {
        state.add(c);
    }

    // Act
    state.add('a');

    // Assert
    try expectEqual(17, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(16, state.literal_index);
    try expectEqual(.telex, state.mode);
}

test "expect State.add apply circumflex for valid cases" {
    // Arrange
    const Case = struct { vowel: u8, new_input: u8 };
    const cases = [_]Case{
        .{ .vowel = 'a', .new_input = 'a' },
        .{ .vowel = 'a', .new_input = 'A' },
        .{ .vowel = 'A', .new_input = 'a' },
        .{ .vowel = 'A', .new_input = 'A' },
        .{ .vowel = 'e', .new_input = 'e' },
        .{ .vowel = 'e', .new_input = 'E' },
        .{ .vowel = 'E', .new_input = 'e' },
        .{ .vowel = 'E', .new_input = 'E' },
        .{ .vowel = 'o', .new_input = 'o' },
        .{ .vowel = 'o', .new_input = 'O' },
        .{ .vowel = 'O', .new_input = 'o' },
        .{ .vowel = 'O', .new_input = 'O' },
    };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |t| {
            var state: State = undefined;
            state.init();
            state.mode = .telex;
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);
            try expectEqual(.telex, state.mode);

            const sp = state.buffer_effective[0];
            try expectEqual(c.vowel, sp.base);
            try expectEqual(.circumflex, sp.diacritic);
            try expectEqual(t, sp.tone);
        }
    }
}

test "expect State.add apply breve for valid cases" {
    // Arrange
    const Case = struct { vowel: u8, new_input: u8 };
    const cases = [_]Case{
        .{ .vowel = 'a', .new_input = 'w' },
        .{ .vowel = 'a', .new_input = 'W' },
        .{ .vowel = 'A', .new_input = 'w' },
        .{ .vowel = 'A', .new_input = 'W' },
    };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |t| {
            var state: State = undefined;
            state.init();
            state.mode = .telex;
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);
            try expectEqual(.telex, state.mode);

            const sp = state.buffer_effective[0];
            try expectEqual(c.vowel, sp.base);
            try expectEqual(.breve, sp.diacritic);
            try expectEqual(t, sp.tone);
        }
    }
}

test "expect State.add apply horn for valid cases" {
    // Arrange
    const Case = struct { vowel: u8, new_input: u8 };
    const cases = [_]Case{
        .{ .vowel = 'o', .new_input = 'w' },
        .{ .vowel = 'o', .new_input = 'W' },
        .{ .vowel = 'O', .new_input = 'w' },
        .{ .vowel = 'O', .new_input = 'W' },
        .{ .vowel = 'u', .new_input = 'w' },
        .{ .vowel = 'u', .new_input = 'W' },
        .{ .vowel = 'U', .new_input = 'w' },
        .{ .vowel = 'U', .new_input = 'W' },
    };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |t| {
            var state: State = undefined;
            state.init();
            state.mode = .telex;
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);
            try expectEqual(.telex, state.mode);

            const sp = state.buffer_effective[0];
            try expectEqual(c.vowel, sp.base);
            try expectEqual(.horn, sp.diacritic);
            try expectEqual(t, sp.tone);
        }
    }
}

test "expect State.add apply stroke for valid cases" {
    // Arrange
    const Case = struct { consonant: u8, new_input: u8 };
    const cases = [_]Case{
        .{ .consonant = 'd', .new_input = 'd' },
        .{ .consonant = 'd', .new_input = 'D' },
        .{ .consonant = 'D', .new_input = 'd' },
        .{ .consonant = 'D', .new_input = 'D' },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        state.mode = .telex;
        state.buffer_effective[0] = Span.init_diacritic_tone(c.consonant, .empty, .level);
        state.buffer_length = 1;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(1, state.buffer_length);
        try expectEqual(0, state.buffer_modification_index);
        try expectEqual(null, state.literal_index);
        try expectEqual(.telex, state.mode);

        const sp = state.buffer_effective[0];
        try expectEqual(c.consonant, sp.base);
        try expectEqual(.stroke, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect State.add override existing diacritic with the new diacritic for valid cases" {
    // Arrange
    const Case = struct { vowel: u8, start_diacritic: Diacritic, new_input: u8, expected_diacritic: Diacritic };
    const cases = [_]Case{
        // breve on A overridden by circumflex via 'a'/'A'.
        .{ .vowel = 'a', .start_diacritic = .breve, .new_input = 'a', .expected_diacritic = .circumflex },
        .{ .vowel = 'a', .start_diacritic = .breve, .new_input = 'A', .expected_diacritic = .circumflex },
        .{ .vowel = 'A', .start_diacritic = .breve, .new_input = 'a', .expected_diacritic = .circumflex },
        .{ .vowel = 'A', .start_diacritic = .breve, .new_input = 'A', .expected_diacritic = .circumflex },
        // circumflex on A overridden by breve via 'w'/'W'.
        .{ .vowel = 'a', .start_diacritic = .circumflex, .new_input = 'w', .expected_diacritic = .breve },
        .{ .vowel = 'a', .start_diacritic = .circumflex, .new_input = 'W', .expected_diacritic = .breve },
        .{ .vowel = 'A', .start_diacritic = .circumflex, .new_input = 'w', .expected_diacritic = .breve },
        .{ .vowel = 'A', .start_diacritic = .circumflex, .new_input = 'W', .expected_diacritic = .breve },
        // circumflex on O overridden by horn via 'w'/'W'.
        .{ .vowel = 'o', .start_diacritic = .circumflex, .new_input = 'w', .expected_diacritic = .horn },
        .{ .vowel = 'o', .start_diacritic = .circumflex, .new_input = 'W', .expected_diacritic = .horn },
        .{ .vowel = 'O', .start_diacritic = .circumflex, .new_input = 'w', .expected_diacritic = .horn },
        .{ .vowel = 'O', .start_diacritic = .circumflex, .new_input = 'W', .expected_diacritic = .horn },
        // horn on O overridden by circumflex via 'o'/'O'.
        .{ .vowel = 'o', .start_diacritic = .horn, .new_input = 'o', .expected_diacritic = .circumflex },
        .{ .vowel = 'o', .start_diacritic = .horn, .new_input = 'O', .expected_diacritic = .circumflex },
        .{ .vowel = 'O', .start_diacritic = .horn, .new_input = 'o', .expected_diacritic = .circumflex },
        .{ .vowel = 'O', .start_diacritic = .horn, .new_input = 'O', .expected_diacritic = .circumflex },
    };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |t| {
            var state: State = undefined;
            state.init();
            state.mode = .telex;
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, c.start_diacritic, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);
            try expectEqual(.telex, state.mode);

            const sp = state.buffer_effective[0];
            try expectEqual(c.vowel, sp.base);
            try expectEqual(c.expected_diacritic, sp.diacritic);
            try expectEqual(t, sp.tone);
        }
    }
}

test "expect State.add cancel existing diacritic for valid cases" {
    // Arrange
    const VowelCase = struct { vowel: u8, start_diacritic: Diacritic, new_input: u8 };
    const vowel_cases = [_]VowelCase{
        // Circumflex on A cancelled by 'a'/'A'.
        .{ .vowel = 'a', .start_diacritic = .circumflex, .new_input = 'a' },
        .{ .vowel = 'a', .start_diacritic = .circumflex, .new_input = 'A' },
        .{ .vowel = 'A', .start_diacritic = .circumflex, .new_input = 'a' },
        .{ .vowel = 'A', .start_diacritic = .circumflex, .new_input = 'A' },
        // Circumflex on E cancelled by 'e'/'E'.
        .{ .vowel = 'e', .start_diacritic = .circumflex, .new_input = 'e' },
        .{ .vowel = 'e', .start_diacritic = .circumflex, .new_input = 'E' },
        .{ .vowel = 'E', .start_diacritic = .circumflex, .new_input = 'e' },
        .{ .vowel = 'E', .start_diacritic = .circumflex, .new_input = 'E' },
        // Circumflex on O cancelled by 'o'/'O'.
        .{ .vowel = 'o', .start_diacritic = .circumflex, .new_input = 'o' },
        .{ .vowel = 'o', .start_diacritic = .circumflex, .new_input = 'O' },
        .{ .vowel = 'O', .start_diacritic = .circumflex, .new_input = 'o' },
        .{ .vowel = 'O', .start_diacritic = .circumflex, .new_input = 'O' },
        // Breve on A cancelled by 'w'/'W'.
        .{ .vowel = 'a', .start_diacritic = .breve, .new_input = 'w' },
        .{ .vowel = 'a', .start_diacritic = .breve, .new_input = 'W' },
        .{ .vowel = 'A', .start_diacritic = .breve, .new_input = 'w' },
        .{ .vowel = 'A', .start_diacritic = .breve, .new_input = 'W' },
        // Horn on O cancelled by 'w'/'W'.
        .{ .vowel = 'o', .start_diacritic = .horn, .new_input = 'w' },
        .{ .vowel = 'o', .start_diacritic = .horn, .new_input = 'W' },
        .{ .vowel = 'O', .start_diacritic = .horn, .new_input = 'w' },
        .{ .vowel = 'O', .start_diacritic = .horn, .new_input = 'W' },
        // Horn on U cancelled by 'w'/'W'.
        .{ .vowel = 'u', .start_diacritic = .horn, .new_input = 'w' },
        .{ .vowel = 'u', .start_diacritic = .horn, .new_input = 'W' },
        .{ .vowel = 'U', .start_diacritic = .horn, .new_input = 'w' },
        .{ .vowel = 'U', .start_diacritic = .horn, .new_input = 'W' },
    };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (vowel_cases) |c| {
        for (tones) |t| {
            var state: State = undefined;
            state.init();
            state.mode = .telex;
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, c.start_diacritic, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(1, state.literal_index);
            try expectEqual(.telex, state.mode);

            const sp_previous = state.buffer_effective[0];
            try expectEqual(c.vowel, sp_previous.base);
            try expectEqual(.empty, sp_previous.diacritic);
            try expectEqual(t, sp_previous.tone);

            const sp_new = state.buffer_effective[1];
            try expectEqual(c.new_input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }

    // Stroke on D cancelled by 'd'/'D'. Tone is not applicable to consonants.
    const StrokeCase = struct { consonant: u8, new_input: u8 };
    const stroke_cases = [_]StrokeCase{
        .{ .consonant = 'd', .new_input = 'd' },
        .{ .consonant = 'd', .new_input = 'D' },
        .{ .consonant = 'D', .new_input = 'd' },
        .{ .consonant = 'D', .new_input = 'D' },
    };

    for (stroke_cases) |c| {
        var state: State = undefined;
        state.init();
        state.mode = .telex;
        state.buffer_effective[0] = Span.init_diacritic_tone(c.consonant, .stroke, .level);
        state.buffer_length = 1;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(2, state.buffer_length);
        try expectEqual(0, state.buffer_modification_index);
        try expectEqual(1, state.literal_index);
        try expectEqual(.telex, state.mode);

        const sp_previous = state.buffer_effective[0];
        try expectEqual(c.consonant, sp_previous.base);
        try expectEqual(.empty, sp_previous.diacritic);
        try expectEqual(.level, sp_previous.tone);

        const sp_new = state.buffer_effective[1];
        try expectEqual(c.new_input, sp_new.base);
        try expectEqual(.empty, sp_new.diacritic);
        try expectEqual(.level, sp_new.tone);
    }
}

test "expect State.add cancel existing diacritic will switch to literal for the next charaters" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;
    state.buffer_effective[0] = Span.init_diacritic_tone('A', .circumflex, .level);
    state.buffer_length = 1;

    // Act: fire the cancel rule. Existing 'Â' + 'a' -> 'A' + literal 'a'.
    state.add('a');

    // Assert: post-cancel checkpoint. Mirrors the existing cancel test for one
    // representative case to disambiguate later persistence failures from a
    // broken cancel transition.
    try expectEqual(2, state.buffer_length);
    try expectEqual(0, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    try expectEqual(@as(u8, 'A'), state.buffer_effective[0].base);
    try expectEqual(.empty, state.buffer_effective[0].diacritic);
    try expectEqual(.level, state.buffer_effective[0].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[1].base);
    try expectEqual(.empty, state.buffer_effective[1].diacritic);
    try expectEqual(.level, state.buffer_effective[1].tone);

    // Act: would-be circumflex via duplicate 'a'. Spec example: existing 'Â',
    // input 'aa' -> 'Aaa'. The previous 'a' must NOT gain circumflex.
    state.add('a');

    // Assert: literal append, earlier spans untouched.
    try expectEqual(3, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    try expectEqual(@as(u8, 'A'), state.buffer_effective[0].base);
    try expectEqual(.empty, state.buffer_effective[0].diacritic);
    try expectEqual(.level, state.buffer_effective[0].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[1].base);
    try expectEqual(.empty, state.buffer_effective[1].diacritic);
    try expectEqual(.level, state.buffer_effective[1].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[2].base);
    try expectEqual(.empty, state.buffer_effective[2].diacritic);
    try expectEqual(.level, state.buffer_effective[2].tone);

    // Act: would-be breve via 'w' on the preceding 'a'. The previous 'a' must
    // NOT change to 'ă'.
    state.add('w');

    // Assert: literal append, earlier spans untouched.
    try expectEqual(4, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    try expectEqual(@as(u8, 'A'), state.buffer_effective[0].base);
    try expectEqual(.empty, state.buffer_effective[0].diacritic);
    try expectEqual(.level, state.buffer_effective[0].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[1].base);
    try expectEqual(.empty, state.buffer_effective[1].diacritic);
    try expectEqual(.level, state.buffer_effective[1].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[2].base);
    try expectEqual(.empty, state.buffer_effective[2].diacritic);
    try expectEqual(.level, state.buffer_effective[2].tone);

    try expectEqual(@as(u8, 'w'), state.buffer_effective[3].base);
    try expectEqual(.empty, state.buffer_effective[3].diacritic);
    try expectEqual(.level, state.buffer_effective[3].tone);

    // Act: literal seed for the upcoming stroke trigger.
    state.add('d');

    // Assert: literal append, earlier spans untouched.
    try expectEqual(5, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    try expectEqual(@as(u8, 'A'), state.buffer_effective[0].base);
    try expectEqual(.empty, state.buffer_effective[0].diacritic);
    try expectEqual(.level, state.buffer_effective[0].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[1].base);
    try expectEqual(.empty, state.buffer_effective[1].diacritic);
    try expectEqual(.level, state.buffer_effective[1].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[2].base);
    try expectEqual(.empty, state.buffer_effective[2].diacritic);
    try expectEqual(.level, state.buffer_effective[2].tone);

    try expectEqual(@as(u8, 'w'), state.buffer_effective[3].base);
    try expectEqual(.empty, state.buffer_effective[3].diacritic);
    try expectEqual(.level, state.buffer_effective[3].tone);

    try expectEqual(@as(u8, 'd'), state.buffer_effective[4].base);
    try expectEqual(.empty, state.buffer_effective[4].diacritic);
    try expectEqual(.level, state.buffer_effective[4].tone);

    // Act: would-be stroke via duplicate 'd'. The previous 'd' must NOT change
    // to 'Đ'.
    state.add('d');

    // Assert: literal append, earlier spans untouched.
    try expectEqual(6, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(1, state.literal_index);
    try expectEqual(.telex, state.mode);

    try expectEqual(@as(u8, 'A'), state.buffer_effective[0].base);
    try expectEqual(.empty, state.buffer_effective[0].diacritic);
    try expectEqual(.level, state.buffer_effective[0].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[1].base);
    try expectEqual(.empty, state.buffer_effective[1].diacritic);
    try expectEqual(.level, state.buffer_effective[1].tone);

    try expectEqual(@as(u8, 'a'), state.buffer_effective[2].base);
    try expectEqual(.empty, state.buffer_effective[2].diacritic);
    try expectEqual(.level, state.buffer_effective[2].tone);

    try expectEqual(@as(u8, 'w'), state.buffer_effective[3].base);
    try expectEqual(.empty, state.buffer_effective[3].diacritic);
    try expectEqual(.level, state.buffer_effective[3].tone);

    try expectEqual(@as(u8, 'd'), state.buffer_effective[4].base);
    try expectEqual(.empty, state.buffer_effective[4].diacritic);
    try expectEqual(.level, state.buffer_effective[4].tone);

    try expectEqual(@as(u8, 'd'), state.buffer_effective[5].base);
    try expectEqual(.empty, state.buffer_effective[5].diacritic);
    try expectEqual(.level, state.buffer_effective[5].tone);
}

test "expect State.add auto-fill missing horn in valid cases" {
    // Arrange: starting pair shapes covering both auto-fill targets and all
    // case combinations. `receiving_offset` marks which vowel in the pair
    // gains horn (0 = first, 1 = second).
    const PairCase = struct {
        first_base: u8,
        first_diacritic: Diacritic,
        second_base: u8,
        second_diacritic: Diacritic,
        receiving_offset: u8,
    };
    const pair_cases = [_]PairCase{
        // uơ pattern: first vowel is missing horn.
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .receiving_offset = 0 },
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'O', .second_diacritic = .horn, .receiving_offset = 0 },
        .{ .first_base = 'U', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .receiving_offset = 0 },
        .{ .first_base = 'U', .first_diacritic = .empty, .second_base = 'O', .second_diacritic = .horn, .receiving_offset = 0 },
        // ưo pattern: second vowel is missing horn.
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .receiving_offset = 1 },
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'O', .second_diacritic = .empty, .receiving_offset = 1 },
        .{ .first_base = 'U', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .receiving_offset = 1 },
        .{ .first_base = 'U', .first_diacritic = .horn, .second_base = 'O', .second_diacritic = .empty, .receiving_offset = 1 },
    };

    const triggers = [_]u8{ 'C', 'c', 'I', 'i', 'M', 'm', 'N', 'n', 'P', 'p', 'T', 't', 'U', 'u' };

    const tones = [_]Tone{ .level, .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    // Linguistically valid one-tone syllables: a tone may sit on either vowel.
    // Sweep both positions while the other vowel stays at .level. We do not
    // fabricate double-toned syllables that the spec would not consider valid.
    const tone_positions = [_]u8{ 0, 1 };

    // Cover both pair-at-start (no prefix) and pair-after-consonant variants
    // to prove the rule looks at the last two spans regardless of buffer_length.
    const prefix_lengths = [_]u8{ 0, 1 };

    for (pair_cases) |pc| {
        for (triggers) |trig| {
            for (tones) |tn| {
                for (tone_positions) |tpos| {
                    for (prefix_lengths) |plen| {
                        var state: State = undefined;
                        state.init();
                        state.mode = .telex;

                        // Optional 'b' prefix to place the pair at index 1..2.
                        if (plen == 1) {
                            state.buffer_effective[0] = Span.init('b');
                        }

                        const first_tone: Tone = if (tpos == 0) tn else .level;
                        const second_tone: Tone = if (tpos == 1) tn else .level;

                        state.buffer_effective[plen] = Span.init_diacritic_tone(pc.first_base, pc.first_diacritic, first_tone);
                        state.buffer_effective[plen + 1] = Span.init_diacritic_tone(pc.second_base, pc.second_diacritic, second_tone);
                        state.buffer_length = plen + 2;

                        // Act
                        state.add(trig);

                        // Assert
                        const receiving_index = plen + pc.receiving_offset;
                        try expectEqual(plen + 3, state.buffer_length);
                        try expectEqual(receiving_index, state.buffer_modification_index);
                        try expectEqual(null, state.literal_index);
                        try expectEqual(.telex, state.mode);

                        // Prefix, when present, must be unchanged.
                        if (plen == 1) {
                            const sp_prefix = state.buffer_effective[0];
                            try expectEqual(@as(u8, 'b'), sp_prefix.base);
                            try expectEqual(.empty, sp_prefix.diacritic);
                            try expectEqual(.level, sp_prefix.tone);
                        }

                        // Both vowel spans must end with horn; case and tone preserved.
                        const sp_first = state.buffer_effective[plen];
                        try expectEqual(pc.first_base, sp_first.base);
                        try expectEqual(.horn, sp_first.diacritic);
                        try expectEqual(first_tone, sp_first.tone);

                        const sp_second = state.buffer_effective[plen + 1];
                        try expectEqual(pc.second_base, sp_second.base);
                        try expectEqual(.horn, sp_second.diacritic);
                        try expectEqual(second_tone, sp_second.tone);

                        // The trigger character is appended literally.
                        const sp_new = state.buffer_effective[plen + 2];
                        try expectEqual(trig, sp_new.base);
                        try expectEqual(.empty, sp_new.diacritic);
                        try expectEqual(.level, sp_new.tone);
                    }
                }
            }
        }
    }
}

test "expect State.add does not auto-fill horn in invalid cases" {
    // Arrange: pairs that look related but do not match the uơ / ưo shape, plus
    // valid pairs combined with non-trigger inputs. Each case asserts a literal
    // append with both seed spans untouched. Non-trigger inputs are picked so
    // they also do not fire any other Telex rule against the preceding span.
    const Case = struct {
        first_base: u8,
        first_diacritic: Diacritic,
        second_base: u8,
        second_diacritic: Diacritic,
        new_input: u8,
    };
    const cases = [_]Case{
        // Pair shape mismatches: trigger character is in the auto-fill list, but
        // no horn is missing or the diacritic shape is wrong.
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .empty, .new_input = 'n' },
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .horn, .new_input = 'n' },
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .circumflex, .new_input = 'n' },
        // Valid incomplete pair, but the new input is not in the trigger list.
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .new_input = 'b' },
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .new_input = 'k' },
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .new_input = 'b' },
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .new_input = 'k' },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        state.mode = .telex;
        state.buffer_effective[0] = Span.init_diacritic_tone(c.first_base, c.first_diacritic, .level);
        state.buffer_effective[1] = Span.init_diacritic_tone(c.second_base, c.second_diacritic, .level);
        state.buffer_length = 2;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(3, state.buffer_length);
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(null, state.literal_index);
        try expectEqual(.telex, state.mode);

        // Both seed spans must be untouched.
        const sp_first = state.buffer_effective[0];
        try expectEqual(c.first_base, sp_first.base);
        try expectEqual(c.first_diacritic, sp_first.diacritic);
        try expectEqual(.level, sp_first.tone);

        const sp_second = state.buffer_effective[1];
        try expectEqual(c.second_base, sp_second.base);
        try expectEqual(c.second_diacritic, sp_second.diacritic);
        try expectEqual(.level, sp_second.tone);

        // The new character is appended literally.
        const sp_new = state.buffer_effective[2];
        try expectEqual(c.new_input, sp_new.base);
        try expectEqual(.empty, sp_new.diacritic);
        try expectEqual(.level, sp_new.tone);
    }
}

test "expect State.add auto-fill missing horn at buffer_effective boundary" {
    // Arrange: place the incomplete pair at indices 14..15 so a trigger pushes
    // total length to 17, exceeding buffer_effective. The implementation must
    // both mutate the existing vowel and follow the overflow convention from
    // the literal `else` arm (set literal_index to buffer_effective.len).
    const Case = struct {
        first_base: u8,
        first_diacritic: Diacritic,
        second_base: u8,
        second_diacritic: Diacritic,
        receiving_offset: u8,
    };
    const cases = [_]Case{
        // uơ pattern: first vowel at index 14 receives horn.
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .receiving_offset = 0 },
        // ưo pattern: second vowel at index 15 receives horn.
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .receiving_offset = 1 },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        state.mode = .telex;

        // Fill indices 0..13 with literal 'b'.
        for (0..14) |i| {
            state.buffer_effective[i] = Span.init('b');
        }
        state.buffer_effective[14] = Span.init_diacritic_tone(c.first_base, c.first_diacritic, .level);
        state.buffer_effective[15] = Span.init_diacritic_tone(c.second_base, c.second_diacritic, .level);
        state.buffer_length = 16;

        // Act
        state.add('n');

        // Assert
        const receiving_index = 14 + c.receiving_offset;
        try expectEqual(17, state.buffer_length);
        try expectEqual(receiving_index, state.buffer_modification_index);
        // Trigger append exceeds buffer_effective, switch to literal from the
        // first out-of-range position (buffer_effective.len = 16).
        try expectEqual(16, state.literal_index);
        try expectEqual(.telex, state.mode);

        // Prefix spans 0..13 unchanged.
        for (0..14) |i| {
            const sp = state.buffer_effective[i];
            try expectEqual(@as(u8, 'b'), sp.base);
            try expectEqual(.empty, sp.diacritic);
            try expectEqual(.level, sp.tone);
        }

        // Both vowel spans must end with horn; case and tone preserved.
        const sp_first = state.buffer_effective[14];
        try expectEqual(c.first_base, sp_first.base);
        try expectEqual(.horn, sp_first.diacritic);
        try expectEqual(.level, sp_first.tone);

        const sp_second = state.buffer_effective[15];
        try expectEqual(c.second_base, sp_second.base);
        try expectEqual(.horn, sp_second.diacritic);
        try expectEqual(.level, sp_second.tone);

        // The trigger character at index 16 is out of buffer_effective range,
        // so append_literal does not write a span there. We only assert the
        // bookkeeping fields above.
    }
}

test "expect State.backspace will reduce buffer_length by 1 and won't touch literal_index" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // input 18 characters.
    for ("bbbbbqqqqqbbbbbqqq") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(17, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(16, state.literal_index);
    try expectEqual(.telex, state.mode);
}

test "expect State.backspace will reduce buffer_length by 1 and unset literal_index" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // input 17 characters so that the literal_index is set at the 17th character.
    for ("bbbbbqqqqqbbbbbqq") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(16, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);
    try expectEqual(.telex, state.mode);
}

test "expect State.backspace will reduce buffer_length by 1 when literal_index is not set" {
    // Arrange
    var state: State = undefined;
    state.init();
    state.mode = .telex;

    // input 17 characters so that the literal_index is set at the 17th character.
    for ("bbbbb") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(4, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);
    try expectEqual(.telex, state.mode);
}

// Simple ABI wrapper for initialize allocated memory.
export fn lex_state_init(state: *anyopaque) void {
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    s.init();
}

// Needed for the caller to allocate memory for our State.
export const lex_state_size: usize = @sizeOf(State);

// Needed for the caller to allocate memory for our State.
export const lex_state_alignment: usize = @alignOf(State);

test "expect State can be initialized by raw allocation" {
    // Arrange

    // Allocate memory, only specify on this test to simulate runtime allocation.
    const raw_pointer = std.testing.allocator.rawAlloc(lex_state_size, .fromByteUnits(lex_state_alignment), @returnAddress()) orelse return error.OutOfMemory;
    defer std.testing.allocator.rawFree(raw_pointer[0..lex_state_size], .fromByteUnits(lex_state_alignment), @returnAddress());

    // Initialize state.
    lex_state_init(raw_pointer);
    const state: *align(lex_state_alignment) State = @ptrCast(@alignCast(raw_pointer));
    state.mode = .telex;

    const input_sequence = "bbbbbqqqqq";

    // Act
    for (input_sequence) |c| {
        lex_add(raw_pointer, c);
    }

    // Assert
    // We only fill and increase the buffer_length based on input.
    try expectEqual(10, state.buffer_length);
    // Because we don't modify any existing character since the last input, expect null.
    try expectEqual(null, state.buffer_modification_index);
    // Because we didn't exceed the buffer_affective, don't set literal_index.
    try expectEqual(null, state.literal_index);
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

// Add operations to the given state based on Telex rules, operations are determined by the input
// character.
export fn lex_add(state: *anyopaque, c: u8) void {
    const s: *State = @ptrCast(@alignCast(state));
    s.add(c);
}

export fn lex_backspace(state: *anyopaque) void {
    const s: *State = @ptrCast(@alignCast(state));
    s.backspace();
}
