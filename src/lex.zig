const std = @import("std");

const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const indexOfScalar = std.mem.indexOfScalar;
const isAlphabetic = std.ascii.isAlphabetic;
const maxInt = std.math.maxInt;
const toUpper = std.ascii.toUpper;

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
        assert(isAlphabetic(base));

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

    // Compare only base character, ignore case and other aspects.
    fn equals_ignore_case_diacritic_tone(self: *const Span, base: u8) bool {
        // Base must be alphabet letters.
        assert(isAlphabetic(base));

        return toUpper(self.base) == toUpper(base);
    }

    // Compare the span with a base character (ignore case) and diacritic, tone is ignored.
    fn equals_ignore_case_tone(self: *const Span, base: u8, diacritic: Diacritic) bool {
        // Base must be alphabet letters.
        assert(isAlphabetic(base));

        return toUpper(self.base) == toUpper(base) and self.diacritic == diacritic;
    }

    // Compare the Span base (ignore case), diacritic, tone.
    fn equals_ignore_case(self: *const Span, base: u8, diacritic: Diacritic, tone: Tone) bool {
        // Base must be alphabet letters.
        assert(isAlphabetic(base));

        return toUpper(self.base) == toUpper(base) and self.diacritic == diacritic and self.tone == tone;
    }

    // Check if the Span.base is vowel or not.
    fn is_vowel(self: *const Span) bool {
        return switch (toUpper(self.base)) {
            'A', 'E', 'I', 'O', 'U', 'Y' => true,
            else => false,
        };
    }

    // Check if the Span.base is consonant or not.
    fn is_consonant(self: *const Span) bool {
        return !self.is_vowel();
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

// Information about a range of character for tone positioning.
const Pseudoword = struct {
    // The start position of the word on State.buffer_effective.
    start: u8,
    // The end position of the word on State.buffer_effective.
    end: u8,
    // The start position of the vowels on State.buffer_effective.
    vowels_start: ?u8,
    // The end position of the vowels on State.buffer_effective.
    vowels_end: ?u8,
    // The length of the word.
    length: u8,

    fn has_vowels(self: *const Pseudoword) bool {
        return self.vowels_start != null and self.vowels_end != null;
    }
};

const State = struct {
    // The effective buffer to process Vietnamese input. we will skip processing if the buffer
    // longer than 15. The last input is always literal.
    buffer_effective: [16]Span,
    // The maximum buffer length that the engine still keeps the effective buffer, after the maximum
    // value (255), we will reset the effective buffer and this value.
    buffer_length: u8 = 0,
    // The previous buffer length before State.add is called, used to calculate synthetic backspaces.
    buffer_length_previous: u8 = 0,
    // Mark the earliest position (inclusive) in buffer where we modified the span, will be used to
    // calculate backspaces and replacement characters.
    buffer_modification_index: ?u8 = null,
    // Mark the position (inclusive) in buffer_effective where the engine stops Telex processing
    // and appends the remaining composition literally. Positions before literal_index were
    // processed as Telex, positions on or after literal_index form the "literal tail". null means
    // the whole current buffer_effective remains Telex-processable.
    literal_index: ?u8 = null,

    // Initialize the State on allocated memory.
    fn init(self: *State) void {
        self.* = .{
            .buffer_effective = undefined,
        };
    }

    fn add(self: *State, c: u8) void {
        // Only allow a-zA-Z.
        assert(isAlphabetic(c));

        if (self.literal_index) |literal_index| {
            // The literal_index value must be in range null or 0 -> 15 (within buffer_effective)
            // because we won't process Vietnamese input outside the buffer_effective and need the
            // literal character for replacement composition.
            assert(literal_index < self.buffer_effective.len);
            // The literal_index value must be less than buffer length.
            assert(literal_index < self.buffer_length);
        }

        // buffer_length conditions
        // 1. must be within buffer_effective length while the whole buffer is Telex-processable.
        // 2. could be equal or more than buffer_effective after literal_index starts the literal
        //    tail.
        assert(self.buffer_length < self.buffer_effective.len or self.literal_index != null);

        // Reset buffer_modification_index to start the new action.
        self.buffer_modification_index = null;

        // Keep the buffer_length in buffer_length_previous.
        // self.buffer_length_previous = self.buffer_length;

        switch (c) {
            'A', 'a' => {
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .empty)) {
                    // 3. Previous span is 'A' or 'a', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .breve)) {
                    // 4. Previous span is 'Ă' or 'ă', override to circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .circumflex)) {
                    // 5. Previous span is 'Â' or 'â', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'A' or 'a'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_ignore_case_diacritic_tone(c)) {
                    // 6. Append literal when previous span is not 'A', 'a' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'C', 'c' => { // fill missing diacritic, e.g. cước.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .empty)) {
                    // 3. Previous span is 'D' or 'd', apply stroke.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .stroke, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .stroke)) {
                    // 4. Previous span is 'Đ' or 'đ', cancel stroke for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'D' or 'd'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_ignore_case_diacritic_tone(c)) {
                    // 5. Append literal when previous span is not 'D', 'd' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'E', 'e' => {
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .empty)) {
                    // 3. Previous span is 'E' or 'e', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .circumflex)) {
                    // 4. Previous span is 'Ê' or 'ê', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'E' or 'e'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_ignore_case_diacritic_tone(c)) {
                    // 5. Append literal when previous span is not 'E', 'e' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'F', 'f' => input_f: { // falling.
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'F' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_f;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'F' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_f;
                }

                // From here, the word has vowels, but doesn't mean appliceable for all cases.
                if (word.has_vowels() and word.length == 2 and self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case('U', .empty, .level)) {
                    // 5. Exact 'QU', 'U' is a part of the consonant, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'F' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_f;
                }

                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index == null) {
                    // No tone, apply tone directly.
                    self.apply_tone(word, .falling);
                } else if (self.buffer_effective[tone_index.?].tone != .falling) {
                    // Override other tone to falling.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Apply tone.
                    self.apply_tone(word, .falling);
                } else if (self.buffer_effective[tone_index.?].tone == .falling) {
                    // Cancel tone.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'F', 'f'.
                    self.append_literal(c);
                } else {
                    unreachable;
                }
            },
            'I', 'i' => {
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
            'J', 'j' => input_j: {
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'J' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_j;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'J' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_j;
                }

                // From here, the word has vowels, but doesn't mean appliceable for all cases.
                if (word.has_vowels() and word.length == 2 and self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case_diacritic_tone('U')) {
                    // 5. Exact 'QU', 'U' is a part of the consonant, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'J' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                    break :input_j;
                }

                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index == null) {
                    // No tone, apply tone directly.
                    self.apply_tone(word, .falling_glottalized);
                } else if (self.buffer_effective[tone_index.?].tone != .falling_glottalized) {
                    // Override other tone to falling_glottalized.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Apply tone.
                    self.apply_tone(word, .falling_glottalized);
                } else if (self.buffer_effective[tone_index.?].tone == .falling_glottalized) {
                    // Cancel tone.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'J', 'j'.
                    self.append_literal(c);
                } else {
                    unreachable;
                }
            }, // falling_glottalized.
            'M', 'm' => {
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .empty)) {
                    // 3. Previous span is 'O' or 'o', apply circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .horn)) {
                    // 4. Previous span is 'Ơ' or 'ơ', override to circumflex.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .circumflex, span_previous.tone);
                    // Set modification index for calculating synthetic backspace
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone(c, .circumflex)) {
                    // 5. Previous span is 'Ô' or 'ô', cancel circumflex for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'O' or 'o'.
                    self.append_literal(c);
                } else if (!self.buffer_effective_last().equals_ignore_case_diacritic_tone(c)) {
                    // 6. Append literal when previous span is not 'O', 'o' and its variants.
                    self.append_literal(c);
                    // No modification.
                    self.buffer_modification_index = null;
                } else {
                    unreachable;
                }
            },
            'P', 'p' => {
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
            'R', 'r' => input_r: { // dipping_rising.
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_r;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    self.buffer_modification_index = null;
                    break :input_r;
                }

                // From here, the word has vowels, but doesn't mean appliceable for all cases.
                if (word.length == 2 and self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case('U', .empty, .level)) {
                    // 5. Exact 'QU', 'U' is a part of the consonant, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_r;
                }

                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index == null) {
                    // No tone, apply tone directly.
                    self.apply_tone(word, .dipping_rising);
                } else if (self.buffer_effective[tone_index.?].tone != .dipping_rising) {
                    // Override other tone to dipping_rising.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Apply tone.
                    self.apply_tone(word, .dipping_rising);
                } else if (self.buffer_effective[tone_index.?].tone == .dipping_rising) {
                    // Cancel tone.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'R', 'r'.
                    self.append_literal(c);
                } else {
                    unreachable;
                }
            },
            'S', 's' => input_s: { // rising.
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_s;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_s;
                }

                // From here, the word has vowels, but doesn't mean appliceable for all cases.
                if (word.length == 2 and self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case('U', .empty, .level)) {
                    // 5. Exact 'QU', 'U' is a part of the consonant, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_s;
                }

                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index == null) {
                    // No tone, apply tone directly.
                    self.apply_tone(word, .rising);
                } else if (self.buffer_effective[tone_index.?].tone != .rising) {
                    // Override other tone to rising.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Apply tone.
                    self.apply_tone(word, .rising);
                } else if (self.buffer_effective[tone_index.?].tone == .rising) {
                    // Cancel tone.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'S', 's'.
                    self.append_literal(c);
                } else {
                    unreachable;
                }
            },
            'T', 't' => {
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    // 4. Pattern: 'UƠ', fill missing horn on 'U'.
                    const span_previous2 = self.buffer_effective[self.buffer_length - 2];
                    self.buffer_effective[self.buffer_length - 2] = Span.init_diacritic_tone(span_previous2.base, .horn, span_previous2.tone);
                    self.buffer_modification_index = self.buffer_length - 2;
                    // Append the new character literally.
                    self.append_literal(c);
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .horn) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .empty)) {
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
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Literal index is set, stop process Vietnamese input.
                    // 2. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'W' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                } else if (self.buffer_effective_last().equals_ignore_case_tone('A', .empty)) {
                    // 4. Previous span is 'A', 'a', apply breve.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .breve, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone('A', .circumflex)) {
                    // 5. Previous span is 'Â', 'â', override to breve.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .breve, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone('A', .breve)) {
                    // 6. Previous span is 'Ă', 'ă', cancel breve for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (self.buffer_effective_last().equals_ignore_case_tone('O', .empty)) {
                    // 7. Previous span is 'O', 'o', apply horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone('O', .circumflex)) {
                    // 8. Previous span is 'Ô', 'ô', override to horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone('O', .horn)) {
                    // 9. Previous span is 'Ơ', 'ơ', cancel horn for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (self.buffer_effective_last().equals_ignore_case_tone('U', .empty)) {
                    // 10. Previous span is 'U', 'u', apply horn.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .horn, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                } else if (self.buffer_effective_last().equals_ignore_case_tone('U', .horn)) {
                    // 11. Previous span is 'Ư', 'ư', cancel horn for previous span and append new literal span.
                    const span_previous = self.buffer_effective[self.buffer_length - 1];
                    self.buffer_effective[self.buffer_length - 1] = Span.init_diacritic_tone(span_previous.base, .empty, span_previous.tone);
                    // Set modification index for calculating synthetic backspace.
                    self.buffer_modification_index = self.buffer_length - 1;
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'W', 'w'.
                    self.append_literal(c);
                } else if (indexOfScalar(u8, "AOU", toUpper(self.buffer_effective[self.buffer_length - 1].base)) == null) {
                    // 12. Previous base character is not 'A', 'O', 'U'.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Set literal_index because 'W' doesn't appear in formal Vietnamese spelling.
                    if (self.literal_index == null) {
                        self.literal_index = self.buffer_length - 1;
                    }
                } else {
                    unreachable;
                }
            },
            'X', 'x' => input_x: { // rising_glottalized.
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because no previous span existed. Continue Vietnamese
                    // processing on next input.
                    // 3. No previous character, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_x;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_x;
                }

                // From here, the word has vowels, but doesn't mean appliceable for all cases.
                if (word.length == 2 and self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case('U', .empty, .level)) {
                    // 5. Exact 'QU', 'U' is a part of the consonant, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_x;
                }

                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index == null) {
                    // No tone, apply tone directly.
                    self.apply_tone(word, .rising_glottalized);
                } else if (self.buffer_effective[tone_index.?].tone != .rising_glottalized) {
                    // Override other tone to rising_glottalized.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Apply tone.
                    self.apply_tone(word, .rising_glottalized);
                } else if (self.buffer_effective[tone_index.?].tone == .rising_glottalized) {
                    // Cancel tone.
                    // Reset tone.
                    self.reset_tone(word, tone_index.?);
                    // Start literal input from this position.
                    self.literal_index = self.buffer_length;
                    // Append literal 'X', 'x'.
                    self.append_literal(c);
                } else {
                    unreachable;
                }
            },
            'Z', 'z' => input_z: {
                if (self.buffer_length == 0) {
                    assert(self.literal_index == null);

                    // 1. Empty word, append literally, start the literal tail.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    // Start the literal tail.
                    self.literal_index = self.buffer_length - 1;
                    break :input_z;
                } else if (self.literal_index != null) {
                    // 2. Literal index is set, stop process Vietnamese input.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_z;
                }

                const word = self.pseudoword();

                if (!word.has_vowels()) {
                    // 4. Pseudoword doesn't have any vowels, append literally.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                    break :input_z;
                }

                // From here, the word has vowels.
                // Find tone position.
                const vowels_start = word.vowels_start.?;
                const vowels_end = word.vowels_end.?;
                var tone_index: ?u8 = null;
                for (vowels_start..(vowels_end + 1)) |index| {
                    if (self.buffer_effective[index].tone != .level) {
                        // Expect maximum 1 tone (other than level) in the vowels.
                        assert(tone_index == null);
                        tone_index = @intCast(index);
                    }
                }

                if (tone_index) |i| {
                    // 5. Reset tone.
                    self.reset_tone(word, i);
                    break :input_z;
                } else {
                    // 6. No tone to reset, append literally, start the literal tail.
                    self.append_literal(c);
                    // Start the literal tail.
                    self.literal_index = self.buffer_length - 1;
                    break :input_z;
                }
            }, // level / reset.
            else => { // literal.
                // These characters will be added to state literally.
                self.append_literal(c);
                // Set modification index to null because we didn't modify any existing span.
                self.buffer_modification_index = null;
            },
        }

        // The buffer_modification index must be inbound of the buffer_effective.
        assert(self.buffer_modification_index == null or (self.buffer_modification_index.? < self.buffer_effective.len and self.buffer_modification_index.? < self.buffer_length));

        // The buffer_length_previous must not larger than buffer_length.
        assert(self.buffer_length_previous <= self.buffer_length);
    }

    // Append literal character when possible. Then increase the buffer_length.
    fn append_literal(self: *State, c: u8) void {
        // Only allow a-zA-Z.
        assert(isAlphabetic(c));
        // Could not append if the buffer_length is full.
        assert(self.buffer_length < maxInt(@TypeOf(self.buffer_length)));

        // Check if we can add new span for input character.
        if (self.buffer_length < self.buffer_effective.len) {
            // Add character to span.
            self.buffer_effective[self.buffer_length] = Span.init(c);
        }
        // Increase the buffer length for tracking, we will need it when handling backspace.
        self.buffer_length += 1;

        // After increase, the new buffer_length may equal the buffer_effective, set literal_index if needed.
        if (self.literal_index == null and self.buffer_length == self.buffer_effective.len) {
            self.literal_index = self.buffer_length - 1;
        }
    }

    // Return the last item in buffer_effective, not valid if the buffer_length is out of range.
    fn buffer_effective_last(self: *State) Span {
        // 1. Should not work if buffer_length exceed buffer_effective.
        // 2. Buffer must have at least 1 character.
        assert(self.buffer_length > 0 and self.buffer_length <= self.buffer_effective.len);

        return self.buffer_effective[self.buffer_length - 1];
    }

    // Return the pseudoword when scan backward the buffer_effective.
    fn pseudoword(self: *State) Pseudoword {
        // Only scan when buffer has characters and doesn't exceed buffer_effective length.
        assert(self.buffer_length > 0 and self.buffer_length <= self.buffer_effective.len);

        // Scan the buffer_effective backward.
        var word_start: ?u8 = null;
        var vowels_start: ?u8 = null;
        var vowels_end: ?u8 = null;
        var index: u8 = self.buffer_length;
        while (index > 0) {
            index -= 1;
            const sp = self.buffer_effective[index];
            const is_vowel = sp.is_vowel();
            const is_consonant = !is_vowel;

            // Found vowel for the first time, mark end of vowels.
            if (is_vowel and vowels_end == null) {
                vowels_end = index;

                if (index == 0) {
                    vowels_start = index;
                    word_start = index;
                    break;
                }
            } else if (is_consonant and vowels_end != null and vowels_start == null) {
                // Found consonant after the vowels (reverse).
                // 1. Set the previous index to vowels_start.
                vowels_start = index + 1;
                // 2. Set the current index to word_start.
                word_start = index;
                break;
            } else if (index == 0 and is_vowel and vowels_end != null and vowels_start == null) {
                // Vowel found, but could not find consonant until the beginning of the buffer.
                // Set the current index to both vowels_start and word_start.
                vowels_start = index;
                word_start = index;
                break;
            } else if (index == 0 and is_consonant and vowels_end == null and vowels_start == null) {
                // No vowels found, only consonants.
                word_start = index;
                break;
            }
        }
        const word_end: u8 = self.buffer_length - 1;

        // word_start must always have valid values.
        assert(word_start != null);
        assert(word_start.? <= word_end);

        // vowels_start and vowels_end must be coupled.
        if (vowels_start) |v_start| {
            assert(vowels_end != null);
            const v_end = vowels_end.?;

            // The order of the vowels start / end must be correct.
            assert(v_start <= v_end);

            // The vowels must be within the word start / end boundary.
            assert(word_start.? <= v_start);
            assert(v_end <= word_end);
        } else {
            assert(vowels_end == null);
        }

        return .{
            .start = word_start.?,
            .end = word_end,
            .vowels_start = vowels_start,
            .vowels_end = vowels_end,
            .length = word_end - word_start.? + 1,
        };
    }

    fn apply_tone(self: *State, word: Pseudoword, tone: Tone) void {
        // The word must have vowels.
        assert(word.has_vowels());

        // Exclude 'QU' because we treat them as consonant.
        if (word.length == 2) {
            assert(!(self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case_diacritic_tone('U')));
        }

        // Existing vowels have level tone.
        // Note: the end is exclusive.
        for (word.vowels_start.?..(word.vowels_end.? + 1)) |i| {
            assert(self.buffer_effective[i].tone == .level);
        }

        // Tone must not be level.
        assert(tone != .level);

        const vowels_start = word.vowels_start.?;
        const vowels_end = word.vowels_end.?;

        // One vowel, put tone on this vowel.
        if (vowels_start == vowels_end) {
            const vowel = self.buffer_effective[vowels_start];
            self.buffer_effective[vowels_start] = Span.init_diacritic_tone(vowel.base, vowel.diacritic, tone);
            self.buffer_modification_index = vowels_start;
            return;
        }

        // Indicator for 'Ơ', highest priority.
        var o_horn_index: ?u8 = null;
        // Special group 'Ê', 'Â', 'Ô', 'Ă', 'Ư'
        // Multiple vowels, scan the vowels to determine the cases.
        var vowel_special_index: ?u8 = null;

        // Special consonant: `GI`, `QU`.
        var consonant_special_start_exists: bool = false;
        if (self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('G') and self.buffer_effective[word.start + 1].equals_ignore_case_diacritic_tone('I')) {
            consonant_special_start_exists = true;
        } else if (self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.start + 1].equals_ignore_case_tone('U', .empty)) {
            consonant_special_start_exists = true;
        }

        var index: u8 = vowels_end + 1;
        while (index > vowels_start) {
            index -= 1;

            const sp = self.buffer_effective[index];
            if (sp.equals_ignore_case_tone('O', .horn)) {
                o_horn_index = index;
                // Because 'Ơ' has highest priority, we can stop processing.
                break;
            }

            // Special group.
            if (vowel_special_index == null and sp.equals_ignore_case_tone('E', .circumflex)) {
                vowel_special_index = index;
            } else if (vowel_special_index == null and sp.equals_ignore_case_tone('A', .circumflex)) {
                vowel_special_index = index;
            } else if (vowel_special_index == null and sp.equals_ignore_case_tone('O', .circumflex)) {
                vowel_special_index = index;
            } else if (vowel_special_index == null and sp.equals_ignore_case_tone('A', .breve)) {
                vowel_special_index = index;
            } else if (vowel_special_index == null and sp.equals_ignore_case_tone('U', .horn)) {
                vowel_special_index = index;
            }
        }

        // Tone position for multiple vowels.
        var tone_index = vowels_start;
        if (o_horn_index) |i| {
            // 'Ơ', highest priority.
            tone_index = i;
        } else if (vowel_special_index) |i| {
            // Special group.
            tone_index = i;
        } else if (consonant_special_start_exists) {
            // 'GI', 'QU', skip the first vowel because it's 'I', 'U', put tone on next vowel.
            tone_index = vowels_start + 1;
        } else if ((vowels_end - vowels_start) == 1 and vowels_end == word.end and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_end].equals_ignore_case_tone('A', .empty)) {
            // Exact 'OA', put tone on first vowel.
            tone_index = vowels_start;
        } else if ((vowels_end - vowels_start) == 1 and vowels_end == word.end and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_end].equals_ignore_case_tone('E', .empty)) {
            // Exact 'OE', put tone on first vowel.
            tone_index = vowels_start;
        } else if ((vowels_end - vowels_start) == 1 and vowels_end == word.end and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_end].equals_ignore_case_tone('O', .empty)) {
            // Exact 'OO', put tone on first vowel.
            tone_index = vowels_start;
        } else if ((vowels_end - vowels_start) == 1 and vowels_end == word.end and self.buffer_effective[vowels_start].equals_ignore_case_tone('U', .empty) and self.buffer_effective[vowels_end].equals_ignore_case_tone('Y', .empty)) {
            // Exact 'UY', put tone on first vowel.
            tone_index = vowels_start;
        } else if ((vowels_end - vowels_start) >= 1 and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_start + 1].equals_ignore_case_tone('A', .empty)) {
            // 'OA' with ending characters, put tone on second vowel.
            tone_index = vowels_start + 1;
        } else if ((vowels_end - vowels_start) >= 1 and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_start + 1].equals_ignore_case_tone('E', .empty)) {
            // 'OE' with ending characters, put tone on second vowel.
            tone_index = vowels_start + 1;
        } else if ((vowels_end - vowels_start) >= 1 and self.buffer_effective[vowels_start].equals_ignore_case_tone('O', .empty) and self.buffer_effective[vowels_start + 1].equals_ignore_case_tone('O', .empty)) {
            // 'OO' with ending characters, put tone on second vowel.
            tone_index = vowels_start + 1;
        } else if ((vowels_end - vowels_start) >= 1 and self.buffer_effective[vowels_start].equals_ignore_case_tone('U', .empty) and self.buffer_effective[vowels_start + 1].equals_ignore_case_tone('Y', .empty)) {
            // 'UY' with ending characters, put tone on second vowel.
            tone_index = vowels_start + 1;
        } else {
            // Other cases, put on first vowel.
            tone_index = vowels_start;
        }

        const sp = self.buffer_effective[tone_index];
        self.buffer_effective[tone_index] = Span.init_diacritic_tone(sp.base, sp.diacritic, tone);

        // Set buffer_modification_index to the earliest modification.
        if (self.buffer_modification_index == null or tone_index < self.buffer_modification_index.?) {
            self.buffer_modification_index = tone_index;
        }

        assert(self.buffer_modification_index != null);
    }

    // Reset all tone in vowels to level. If word has no tone, this function is no-op.
    fn reset_tone(self: *State, word: Pseudoword, tone_index: u8) void {
        // The word must have vowels.
        assert(word.has_vowels());
        // tone_index on vowels.
        assert(tone_index >= word.vowels_start.? and tone_index <= word.vowels_end.?);

        // Reset tone.
        const sp = self.buffer_effective[tone_index];
        self.buffer_effective[tone_index] = Span.init_diacritic_tone(sp.base, sp.diacritic, .level);
        // Set buffer_modification_index to the earliest modification.
        if (self.buffer_modification_index == null or tone_index < self.buffer_modification_index.?) {
            self.buffer_modification_index = tone_index;
        }
    }

    fn backspace(self: *State) void {
        // buffer_length must be positive for backspace.
        assert(self.buffer_length > 0);

        if (self.literal_index) |literal_index| {
            // literal_index must be within buffer_effective range when set.
            assert(literal_index < self.buffer_effective.len);
            // literal_index must be less than buffer_length.
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

    // Calculate how many backspaces are needed to completely replace the existing characters to
    // make them match with the new state.
    fn calculate_synthetic_backspaces(self: *State) u8 {
        assert(self.buffer_modification_index == null or (self.buffer_modification_index.? < self.buffer_length_previous));

        if (self.buffer_modification_index) |buffer_modification_index| {
            return self.buffer_length_previous - buffer_modification_index;
        } else {
            return 0;
        }
    }

    // Compose UTF-16 string replacement for the synthetic events. It could be multiple characters
    // or one literal character.
    // fn compose_utf16_string_replacement(self: *State) []u8 {
    //     unreachable;
    // }

    // Indicate if the buffer_effective is full.
    fn buffer_effective_full(self: *State) bool {
        if (self.buffer_length < self.buffer_effective.len) {
            return false;
        } else {
            assert(self.literal_index != null and self.literal_index.? < self.buffer_effective.len);
            return true;
        }
    }
};

test "expect State.add handles non-Telex characters less than 1 character of the buffer_effective length" {
    // Arrange
    var state: State = undefined;
    state.init();

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
    // Because we didn't exceed the buffer_effective, don't set literal_index.
    try expectEqual(null, state.literal_index);
    // Verify every the spans, must exactly the same with the input.
    for (input_sequence, 0..) |c, i| {
        const sp = state.buffer_effective[i];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect State.add handles non-Telex characters fill the last slot" {
    // Arrange
    var state: State = undefined;
    state.init();

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
    // Because we fill the last slot, start literal input from the last slot.
    try expectEqual(15, state.literal_index);
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
    // Because the input exceed the buffer_effective, keep literal_index at the last slot.
    try expectEqual(15, state.literal_index);
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

    // Act
    state.add('a');

    // Assert
    try expectEqual(1, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);

    const sp = state.buffer_effective[0];
    try expectEqual('a', sp.base);
    try expectEqual(.empty, sp.diacritic);
    try expectEqual(.level, sp.tone);
}

test "expect State.add start literal input when the new input fills the last slot" {
    // Arrange
    var state: State = undefined;
    state.init();

    // input 15 characters.
    for ("bbbbbqqqqqbbbbb") |c| {
        state.add(c);
    }

    // Act
    state.add('a');

    // Assert
    try expectEqual(16, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);

    const sp = state.buffer_effective[15];
    try expectEqual(@as(u8, 'a'), sp.base);
    try expectEqual(.empty, sp.diacritic);
    try expectEqual(.level, sp.tone);
}

test "expect State.add does not process Telex after filling the last slot" {
    // Arrange
    var state: State = undefined;
    state.init();

    for (0..15) |i| {
        state.buffer_effective[i] = Span.init('b');
    }
    state.buffer_effective[15] = Span.init('a');
    state.buffer_length = 16;
    state.literal_index = 15;

    // Act
    state.add('a');

    // Assert
    try expectEqual(17, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);

    for (0..15) |i| {
        const sp = state.buffer_effective[i];
        try expectEqual(@as(u8, 'b'), sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }

    const sp = state.buffer_effective[15];
    try expectEqual(@as(u8, 'a'), sp.base);
    try expectEqual(.empty, sp.diacritic);
    try expectEqual(.level, sp.tone);
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
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

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
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

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
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, .empty, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

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
        state.buffer_effective[0] = Span.init_diacritic_tone(c.consonant, .empty, .level);
        state.buffer_length = 1;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(1, state.buffer_length);
        try expectEqual(0, state.buffer_modification_index);
        try expectEqual(null, state.literal_index);

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
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, c.start_diacritic, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(1, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

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
            state.buffer_effective[0] = Span.init_diacritic_tone(c.vowel, c.start_diacritic, t);
            state.buffer_length = 1;

            // Act
            state.add(c.new_input);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(0, state.buffer_modification_index);
            try expectEqual(1, state.literal_index);

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
        state.buffer_effective[0] = Span.init_diacritic_tone(c.consonant, .stroke, .level);
        state.buffer_length = 1;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(2, state.buffer_length);
        try expectEqual(0, state.buffer_modification_index);
        try expectEqual(1, state.literal_index);

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

test "expect State.add cancel existing diacritic at the last slot boundary" {
    // Arrange
    var state: State = undefined;
    state.init();

    for (0..14) |i| {
        state.buffer_effective[i] = Span.init('b');
    }
    state.buffer_effective[14] = Span.init_diacritic_tone('a', .circumflex, .level);
    state.buffer_length = 15;

    // Act
    state.add('a');

    // Assert
    try expectEqual(16, state.buffer_length);
    try expectEqual(14, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);

    for (0..14) |i| {
        const sp = state.buffer_effective[i];
        try expectEqual(@as(u8, 'b'), sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }

    const sp_previous = state.buffer_effective[14];
    try expectEqual(@as(u8, 'a'), sp_previous.base);
    try expectEqual(.empty, sp_previous.diacritic);
    try expectEqual(.level, sp_previous.tone);

    const sp_new = state.buffer_effective[15];
    try expectEqual(@as(u8, 'a'), sp_new.base);
    try expectEqual(.empty, sp_new.diacritic);
    try expectEqual(.level, sp_new.tone);
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
        state.buffer_effective[0] = Span.init_diacritic_tone(c.first_base, c.first_diacritic, .level);
        state.buffer_effective[1] = Span.init_diacritic_tone(c.second_base, c.second_diacritic, .level);
        state.buffer_length = 2;

        // Act
        state.add(c.new_input);

        // Assert
        try expectEqual(3, state.buffer_length);
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(null, state.literal_index);

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

test "expect State.add auto-fill missing horn at the last slot boundary" {
    // Arrange: place the incomplete pair at indices 13..14 so a trigger fills
    // the last slot. The implementation must both mutate the existing vowel
    // and start literal input from the last slot.
    const Case = struct {
        first_base: u8,
        first_diacritic: Diacritic,
        second_base: u8,
        second_diacritic: Diacritic,
        receiving_offset: u8,
    };
    const cases = [_]Case{
        // uơ pattern: first vowel at index 13 receives horn.
        .{ .first_base = 'u', .first_diacritic = .empty, .second_base = 'o', .second_diacritic = .horn, .receiving_offset = 0 },
        // ưo pattern: second vowel at index 14 receives horn.
        .{ .first_base = 'u', .first_diacritic = .horn, .second_base = 'o', .second_diacritic = .empty, .receiving_offset = 1 },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();

        // Fill indices 0..12 with literal 'b'.
        for (0..13) |i| {
            state.buffer_effective[i] = Span.init('b');
        }
        state.buffer_effective[13] = Span.init_diacritic_tone(c.first_base, c.first_diacritic, .level);
        state.buffer_effective[14] = Span.init_diacritic_tone(c.second_base, c.second_diacritic, .level);
        state.buffer_length = 15;

        // Act
        state.add('n');

        // Assert
        const receiving_index = 13 + c.receiving_offset;
        try expectEqual(16, state.buffer_length);
        try expectEqual(receiving_index, state.buffer_modification_index);
        // Trigger append fills the last slot, switch to literal from the last slot.
        try expectEqual(15, state.literal_index);

        // Prefix spans 0..12 unchanged.
        for (0..13) |i| {
            const sp = state.buffer_effective[i];
            try expectEqual(@as(u8, 'b'), sp.base);
            try expectEqual(.empty, sp.diacritic);
            try expectEqual(.level, sp.tone);
        }

        // Both vowel spans must end with horn; case and tone preserved.
        const sp_first = state.buffer_effective[13];
        try expectEqual(c.first_base, sp_first.base);
        try expectEqual(.horn, sp_first.diacritic);
        try expectEqual(.level, sp_first.tone);

        const sp_second = state.buffer_effective[14];
        try expectEqual(c.second_base, sp_second.base);
        try expectEqual(.horn, sp_second.diacritic);
        try expectEqual(.level, sp_second.tone);

        // The trigger character is appended literally at the last slot.
        const sp_new = state.buffer_effective[15];
        try expectEqual(@as(u8, 'n'), sp_new.base);
        try expectEqual(.empty, sp_new.diacritic);
        try expectEqual(.level, sp_new.tone);
    }
}

test "expect State.add switch to literal input when append F, J, W, Z (ignore cases) on empty buffer" {
    // Arrange
    const inputs = [_]u8{ 'F', 'f', 'J', 'j', 'W', 'w', 'Z', 'z' };

    for (inputs) |c| {
        var state: State = undefined;
        state.init();

        // Act
        state.add(c);

        // Assert
        try expectEqual(1, state.buffer_length);
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(0, state.literal_index);

        const sp = state.buffer_effective[0];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect State.add switch to literal input when append W (ignore cases) on character outside diacritic scope" {
    // Arrange
    const Case = struct { base: u8, diacritic: Diacritic };
    const cases = [_]Case{
        .{ .base = 'b', .diacritic = .empty },
        .{ .base = 'B', .diacritic = .empty },
        .{ .base = 'e', .diacritic = .empty },
        .{ .base = 'E', .diacritic = .empty },
        .{ .base = 'i', .diacritic = .empty },
        .{ .base = 'I', .diacritic = .empty },
        .{ .base = 'y', .diacritic = .empty },
        .{ .base = 'Y', .diacritic = .empty },
        .{ .base = 'e', .diacritic = .circumflex },
        .{ .base = 'E', .diacritic = .circumflex },
        .{ .base = 'd', .diacritic = .stroke },
        .{ .base = 'D', .diacritic = .stroke },
    };

    const inputs = [_]u8{ 'W', 'w' };

    for (cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init_diacritic(c.base, c.diacritic);
            state.buffer_length = 1;

            // Act
            state.add(input);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            try expectEqual(1, state.literal_index);

            const sp_previous = state.buffer_effective[0];
            try expectEqual(c.base, sp_previous.base);
            try expectEqual(c.diacritic, sp_previous.diacritic);
            try expectEqual(.level, sp_previous.tone);

            const sp_new = state.buffer_effective[1];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }
}

test "expect State.add switch to literal input when append F, J (ignore cases) on word without placeable tone" {
    const inputs = [_]u8{ 'F', 'f', 'J', 'j' };

    // Sub-block A: single-consonant pseudo-word (no vowel).
    const SingleCase = struct { base: u8 };
    const single_cases = [_]SingleCase{
        .{ .base = 'b' },
        .{ .base = 'B' },
    };

    for (single_cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init(c.base);
            state.buffer_length = 1;

            // Act
            state.add(input);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            try expectEqual(1, state.literal_index);

            const sp_previous = state.buffer_effective[0];
            try expectEqual(c.base, sp_previous.base);
            try expectEqual(.empty, sp_previous.diacritic);
            try expectEqual(.level, sp_previous.tone);

            const sp_new = state.buffer_effective[1];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }

    // Sub-block B: multi-consonant pseudo-word (no vowel) and QU exception.
    const PairCase = struct { base0: u8, base1: u8 };
    const pair_cases = [_]PairCase{
        // Multi-consonant clusters.
        .{ .base0 = 'n', .base1 = 'g' },
        .{ .base0 = 't', .base1 = 'r' },
        .{ .base0 = 'p', .base1 = 'h' },
        .{ .base0 = 'k', .base1 = 'h' },
        .{ .base0 = 'g', .base1 = 'h' },
        // QU exception (mixed cases).
        .{ .base0 = 'q', .base1 = 'u' },
        .{ .base0 = 'q', .base1 = 'U' },
        .{ .base0 = 'Q', .base1 = 'u' },
        .{ .base0 = 'Q', .base1 = 'U' },
    };

    for (pair_cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init(c.base0);
            state.buffer_effective[1] = Span.init(c.base1);
            state.buffer_length = 2;

            // Act
            state.add(input);

            // Assert
            try expectEqual(3, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            try expectEqual(2, state.literal_index);

            const sp_previous0 = state.buffer_effective[0];
            try expectEqual(c.base0, sp_previous0.base);
            try expectEqual(.empty, sp_previous0.diacritic);
            try expectEqual(.level, sp_previous0.tone);

            const sp_previous1 = state.buffer_effective[1];
            try expectEqual(c.base1, sp_previous1.base);
            try expectEqual(.empty, sp_previous1.diacritic);
            try expectEqual(.level, sp_previous1.tone);

            const sp_new = state.buffer_effective[2];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }
}

test "expect State.add appends Z literally when pseudo-word has no vowel" {
    const inputs = [_]u8{ 'Z', 'z' };

    // Sub-block A: single-consonant pseudo-word (no vowel).
    const SingleCase = struct { base: u8 };
    const single_cases = [_]SingleCase{
        .{ .base = 'd' },
        .{ .base = 'D' },
    };

    for (single_cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init(c.base);
            state.buffer_length = 1;

            // Act
            state.add(input);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

            const sp_previous = state.buffer_effective[0];
            try expectEqual(c.base, sp_previous.base);
            try expectEqual(.empty, sp_previous.diacritic);
            try expectEqual(.level, sp_previous.tone);

            const sp_new = state.buffer_effective[1];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }

    // Sub-block B: multi-consonant pseudo-word (no vowel).
    const PairCase = struct { base0: u8, base1: u8 };
    const pair_cases = [_]PairCase{
        .{ .base0 = 'n', .base1 = 'g' },
        .{ .base0 = 'N', .base1 = 'g' },
    };

    for (pair_cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init(c.base0);
            state.buffer_effective[1] = Span.init(c.base1);
            state.buffer_length = 2;

            // Act
            state.add(input);

            // Assert
            try expectEqual(3, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

            const sp_previous0 = state.buffer_effective[0];
            try expectEqual(c.base0, sp_previous0.base);
            try expectEqual(.empty, sp_previous0.diacritic);
            try expectEqual(.level, sp_previous0.tone);

            const sp_previous1 = state.buffer_effective[1];
            try expectEqual(c.base1, sp_previous1.base);
            try expectEqual(.empty, sp_previous1.diacritic);
            try expectEqual(.level, sp_previous1.tone);

            const sp_new = state.buffer_effective[2];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }
}

test "expect State.apply_tone places tone at the correct vowel for every non-level tone" {
    // Arrange. Each case seeds buffer_effective directly with .level vowels,
    // builds a Pseudoword by hand (so this test stays independent from the
    // pseudo-word scanner and the State.add dispatch), and calls apply_tone.
    // Every case is iterated across all non-level tones to verify the tone
    // value is preserved on the targeted vowel and no other span is touched.
    const SeedSpan = struct { base: u8, diacritic: Diacritic = .empty };
    const Case = struct {
        seeds: []const SeedSpan,
        word_start: u8,
        word_end: u8,
        vowels_start: u8,
        vowels_end: u8,
        expected_index: u8,
    };
    const cases = [_]Case{
        // Single vowel placement (vowels only).
        .{ .seeds = &.{.{ .base = 'a' }}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        .{ .seeds = &.{.{ .base = 'A' }}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        // Single vowel with leading consonant.
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 1, .vowels_start = 1, .vowels_end = 1, .expected_index = 1 },
        // Single vowel with trailing consonant.
        .{ .seeds = &.{ .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        // Single vowel with leading and trailing consonant.
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 1, .expected_index = 1 },

        // Exact OA / OE / OO / UY -> first vowel.
        .{ .seeds = &.{ .{ .base = 'o' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ .{ .base = 'o' }, .{ .base = 'e' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ .{ .base = 'o' }, .{ .base = 'o' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        // Exact OA / OE / OO / UY with leading consonant -> first vowel.
        .{ .seeds = &.{ .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },
        .{ .seeds = &.{ .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },

        // Extended OA / OE / OO / UY (trailing consonant) -> second vowel.
        .{ .seeds = &.{ .{ .base = 'o' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        .{ .seeds = &.{ .{ .base = 'u' }, .{ .base = 'y' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        .{ .seeds = &.{ .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' }, .{ .base = 'n' }, .{ .base = 'h' } }, .word_start = 0, .word_end = 4, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'x' }, .{ .base = 'o' }, .{ .base = 'o' }, .{ .base = 'n' }, .{ .base = 'g' } }, .word_start = 0, .word_end = 4, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        // Extended OA / OE / UY (more vowels) -> second vowel.
        .{ .seeds = &.{ .{ .base = 'x' }, .{ .base = 'o' }, .{ .base = 'a' }, .{ .base = 'y' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 3, .expected_index = 2 },

        // GI / QU consonant-vowel special: tone on next vowel.
        .{ .seeds = &.{ .{ .base = 'g' }, .{ .base = 'i' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'q' }, .{ .base = 'u' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'g' }, .{ .base = 'i' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'q' }, .{ .base = 'u' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },

        // Ơ has the highest priority among the special vowels.
        .{ .seeds = &.{ .{ .base = 'u' }, .{ .base = 'o', .diacritic = .horn }, .{ .base = 'p' } }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        // Special diacritic priority Ê / Â / Ô / Ă / Ư -- the rightmost listed
        // vowel wins per the right-to-left scan.
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'i' }, .{ .base = 'e', .diacritic = .circumflex }, .{ .base = 'n' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'd' }, .{ .base = 'a', .diacritic = .circumflex }, .{ .base = 'u' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'u' }, .{ .base = 'o', .diacritic = .circumflex }, .{ .base = 'n' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 'l' }, .{ .base = 'o' }, .{ .base = 'a', .diacritic = .breve }, .{ .base = 't' } }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'u', .diacritic = .horn }, .{ .base = 'u' } }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },

        // Default multi-vowel fallback (no special, no GI/QU, no OA/OE/OO/UY) -> first vowel.
        .{ .seeds = &.{ .{ .base = 'i' }, .{ .base = 'a' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
    };

    const tones = [_]Tone{ .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |tone| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                state.buffer_effective[i] = Span.init_diacritic_tone(s.base, s.diacritic, .level);
            }
            state.buffer_length = @intCast(c.seeds.len);

            const word: Pseudoword = .{
                .start = c.word_start,
                .end = c.word_end,
                .vowels_start = c.vowels_start,
                .vowels_end = c.vowels_end,
                .length = c.word_end - c.word_start + 1,
            };

            // Act
            state.apply_tone(word, tone);

            // Assert: tone is applied in place; buffer length, literal_index, and
            // buffer_modification_index points at the modified
            // vowel.
            try expectEqual(@as(u8, @intCast(c.seeds.len)), state.buffer_length);
            try expectEqual(@as(?u8, c.expected_index), state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

            // The targeted vowel takes the tone; every other span keeps base,
            // diacritic, and stays at .level.
            for (c.seeds, 0..) |s, i| {
                const sp = state.buffer_effective[i];
                try expectEqual(s.base, sp.base);
                try expectEqual(s.diacritic, sp.diacritic);
                const expected_tone: Tone = if (i == @as(usize, c.expected_index)) tone else .level;
                try expectEqual(expected_tone, sp.tone);
            }
        }
    }
}

test "expect State.apply_tone updates buffer_modification_index to the earliest position" {
    // Arrange. Cover the three bookkeeping branches for buffer_modification_index:
    //   - initially null -> set to the tone position.
    //   - existing index later than the tone position -> updated to tone position.
    //   - existing index earlier than the tone position -> kept unchanged.
    // The seeded word is `tien` (t, i, ê, n) so the tone lands at index 2 (Ê).
    const Case = struct {
        initial_modification_index: ?u8,
        expected_modification_index: u8,
    };
    const cases = [_]Case{
        .{ .initial_modification_index = null, .expected_modification_index = 2 },
        .{ .initial_modification_index = 3, .expected_modification_index = 2 },
        .{ .initial_modification_index = 1, .expected_modification_index = 1 },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        state.buffer_effective[0] = Span.init('t');
        state.buffer_effective[1] = Span.init('i');
        state.buffer_effective[2] = Span.init_diacritic('e', .circumflex);
        state.buffer_effective[3] = Span.init('n');
        state.buffer_length = 4;
        state.buffer_modification_index = c.initial_modification_index;

        const word: Pseudoword = .{
            .start = 0,
            .end = 3,
            .vowels_start = 1,
            .vowels_end = 2,
            .length = 4,
        };

        // Act
        state.apply_tone(word, .rising);

        // Assert
        try expectEqual(@as(?u8, c.expected_modification_index), state.buffer_modification_index);
        try expectEqual(.rising, state.buffer_effective[2].tone);
        try expectEqual(.level, state.buffer_effective[1].tone);
    }
}

test "expect State.add applies non-level tones for representative cases" {
    // Arrange. This test only proves State.add triggers the pseudo-word scanner and applies the
    // requested non-level tone. Exhaustive positioning rules live in the State.apply_tone tests.
    const TriggerCase = enum { lower, upper };
    const ToneCase = struct {
        tone: Tone,
        lower_trigger: u8,
        upper_trigger: u8,
    };
    const SeedSpan = struct { base: u8, diacritic: Diacritic = .empty };
    const Case = struct {
        seeds: []const SeedSpan,
        trigger_case: TriggerCase,
        expected_index: u8,
    };
    const tone_cases = [_]ToneCase{
        .{ .tone = .rising, .lower_trigger = 's', .upper_trigger = 'S' },
        .{ .tone = .falling, .lower_trigger = 'f', .upper_trigger = 'F' },
        .{ .tone = .dipping_rising, .lower_trigger = 'r', .upper_trigger = 'R' },
        .{ .tone = .rising_glottalized, .lower_trigger = 'x', .upper_trigger = 'X' },
        .{ .tone = .falling_glottalized, .lower_trigger = 'j', .upper_trigger = 'J' },
    };
    const cases = [_]Case{
        // Lowercase trigger, single vowel.
        .{ .seeds = &.{.{ .base = 'a' }}, .trigger_case = .lower, .expected_index = 0 },
        // Uppercase trigger, single vowel.
        .{ .seeds = &.{.{ .base = 'A' }}, .trigger_case = .upper, .expected_index = 0 },
        // Simple consonant + single vowel.
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' } }, .trigger_case = .lower, .expected_index = 1 },
        // Multi-vowel run (exact OA -> first vowel).
        .{ .seeds = &.{ .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } }, .trigger_case = .lower, .expected_index = 1 },
        // Trailing-suffix pseudo-word (only the last syllable receives the tone).
        .{ .seeds = &.{ .{ .base = 'v' }, .{ .base = 'a' }, .{ .base = 'n' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } }, .trigger_case = .lower, .expected_index = 4 },
    };

    for (tone_cases) |tone_case| {
        for (cases) |c| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                state.buffer_effective[i] = Span.init_diacritic_tone(s.base, s.diacritic, .level);
            }
            state.buffer_length = @intCast(c.seeds.len);

            const trigger = switch (c.trigger_case) {
                .lower => tone_case.lower_trigger,
                .upper => tone_case.upper_trigger,
            };

            // Act
            state.add(trigger);

            // Assert: the trigger character is NOT appended; the requested tone lands on the
            // expected vowel and bookkeeping fields stay clean.
            try expectEqual(@as(u8, @intCast(c.seeds.len)), state.buffer_length);
            try expectEqual(@as(?u8, c.expected_index), state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

            for (c.seeds, 0..) |s, i| {
                const sp = state.buffer_effective[i];
                try expectEqual(s.base, sp.base);
                try expectEqual(s.diacritic, sp.diacritic);
                const expected_tone: Tone = if (i == @as(usize, c.expected_index))
                    tone_case.tone
                else
                    .level;
                try expectEqual(expected_tone, sp.tone);
            }
        }
    }
}

test "expect State.add overrides an existing different non-level tone" {
    // Arrange. Seed `t?ê` (t, i with an existing non-level tone, ê). The existing tone sits on `i`
    // (index 1); the override path must reset it and place the requested tone on `ê` (index 2,
    // the special vowel). This proves State.add orchestrates reset_tone followed by apply_tone.
    const ToneCase = struct {
        tone: Tone,
        trigger: u8,
        existing_tone: Tone,
    };
    const tone_cases = [_]ToneCase{
        .{ .tone = .rising, .trigger = 's', .existing_tone = .falling },
        .{ .tone = .falling, .trigger = 'f', .existing_tone = .rising },
        .{ .tone = .dipping_rising, .trigger = 'r', .existing_tone = .rising },
        .{ .tone = .rising_glottalized, .trigger = 'x', .existing_tone = .rising },
        .{ .tone = .falling_glottalized, .trigger = 'j', .existing_tone = .rising },
    };

    for (tone_cases) |tone_case| {
        var state: State = undefined;
        state.init();
        state.buffer_effective[0] = Span.init('t');
        state.buffer_effective[1] = Span.init_diacritic_tone('i', .empty, tone_case.existing_tone);
        state.buffer_effective[2] = Span.init_diacritic('e', .circumflex);
        state.buffer_length = 3;

        // Act
        state.add(tone_case.trigger);

        // Assert. Trigger character must not be appended; the existing non-level tone becomes
        // level; the requested tone lands on `ê`. buffer_modification_index tracks the earliest
        // modified span (index 1, where the existing tone was reset).
        try expectEqual(@as(u8, 3), state.buffer_length);
        try expectEqual(@as(?u8, 1), state.buffer_modification_index);
        try expectEqual(null, state.literal_index);

        try expectEqual(@as(u8, 't'), state.buffer_effective[0].base);
        try expectEqual(.empty, state.buffer_effective[0].diacritic);
        try expectEqual(.level, state.buffer_effective[0].tone);

        try expectEqual(@as(u8, 'i'), state.buffer_effective[1].base);
        try expectEqual(.empty, state.buffer_effective[1].diacritic);
        try expectEqual(.level, state.buffer_effective[1].tone);

        try expectEqual(@as(u8, 'e'), state.buffer_effective[2].base);
        try expectEqual(.circumflex, state.buffer_effective[2].diacritic);
        try expectEqual(tone_case.tone, state.buffer_effective[2].tone);
    }
}

test "expect State.add cancels an existing matching non-level tone for representative cases and switches to literal input" {
    // Arrange. This test proves State.add takes the cancellation arm for each non-level tone:
    // reset the existing matching tone to level (preserving base case + diacritic), append the
    // trigger literally, and set literal_index to the pre-append buffer_length.
    // Tone-position rules are NOT re-evaluated here; they are covered by State.apply_tone tests.
    const TriggerCase = enum { lower, upper };
    const ToneCase = struct {
        tone: Tone,
        lower_trigger: u8,
        upper_trigger: u8,
    };
    const SeedSpan = struct { base: u8, diacritic: Diacritic = .empty };
    const Case = struct {
        seeds: []const SeedSpan,
        trigger_case: TriggerCase,
        // Absolute buffer index of the seeded vowel that carries the existing matching tone, which
        // is also the expected buffer_modification_index after cancellation.
        expected_modification_index: u8,
    };
    const tone_cases = [_]ToneCase{
        .{ .tone = .rising, .lower_trigger = 's', .upper_trigger = 'S' },
        .{ .tone = .falling, .lower_trigger = 'f', .upper_trigger = 'F' },
        .{ .tone = .dipping_rising, .lower_trigger = 'r', .upper_trigger = 'R' },
        .{ .tone = .rising_glottalized, .lower_trigger = 'x', .upper_trigger = 'X' },
        .{ .tone = .falling_glottalized, .lower_trigger = 'j', .upper_trigger = 'J' },
    };
    const cases = [_]Case{
        // Lowercase trigger, single plain vowel.
        .{
            .seeds = &.{.{ .base = 'a' }},
            .trigger_case = .lower,
            .expected_modification_index = 0,
        },
        // Uppercase trigger, single plain vowel.
        .{
            .seeds = &.{.{ .base = 'A' }},
            .trigger_case = .upper,
            .expected_modification_index = 0,
        },
        // Consonant + plain vowel (open syllable).
        .{
            .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' } },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Trailing consonant (closed syllable). The trailing 'n' must remain untouched.
        .{
            .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' }, .{ .base = 'n' } },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Trailing consonant cluster. The trailing 'nh' cluster must remain untouched.
        .{
            .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' }, .{ .base = 'n' }, .{ .base = 'h' } },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Diacritic-bearing vowel with trailing consonant. Cancellation must keep the circumflex.
        .{
            .seeds = &.{ .{ .base = 't' }, .{ .base = 'i' }, .{ .base = 'e', .diacritic = .circumflex }, .{ .base = 'n' } },
            .trigger_case = .lower,
            .expected_modification_index = 2,
        },
        // Multi-vowel representative shape. This does not assert OA tone-placement rules.
        .{
            .seeds = &.{ .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Longer buffer trailing-suffix. Only the last syllable's vowel carries the matching tone,
        // so cancellation lands at index 4 and earlier spans remain exactly as seeded.
        .{
            .seeds = &.{ .{ .base = 'v' }, .{ .base = 'a' }, .{ .base = 'n' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } },
            .trigger_case = .lower,
            .expected_modification_index = 4,
        },
    };

    for (tone_cases) |tone_case| {
        for (cases) |c| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                const tone: Tone = if (i == @as(usize, c.expected_modification_index))
                    tone_case.tone
                else
                    .level;
                state.buffer_effective[i] = Span.init_diacritic_tone(s.base, s.diacritic, tone);
            }
            state.buffer_length = @intCast(c.seeds.len);

            const trigger = switch (c.trigger_case) {
                .lower => tone_case.lower_trigger,
                .upper => tone_case.upper_trigger,
            };

            // Setup guard: prevent expected_modification_index from drifting away from seed data.
            try expectEqual(
                tone_case.tone,
                state.buffer_effective[c.expected_modification_index].tone,
            );

            // Act
            state.add(trigger);

            // Assert: the trigger character is appended literally, the matching tone on the seeded
            // vowel is reset to level, and literal_index marks the new literal span.
            try expectEqual(@as(u8, @intCast(c.seeds.len + 1)), state.buffer_length);
            try expectEqual(@as(?u8, c.expected_modification_index), state.buffer_modification_index);
            try expectEqual(@as(?u8, @intCast(c.seeds.len)), state.literal_index);

            // Every preexisting span keeps its base + diacritic; the cancelled vowel drops to level
            // (others were already level and remain so).
            for (c.seeds, 0..) |s, i| {
                const sp = state.buffer_effective[i];
                try expectEqual(s.base, sp.base);
                try expectEqual(s.diacritic, sp.diacritic);
                try expectEqual(.level, sp.tone);
            }

            // The appended trigger span is plain literal: same base char, no diacritic, no tone.
            const appended = state.buffer_effective[c.seeds.len];
            try expectEqual(trigger, appended.base);
            try expectEqual(.empty, appended.diacritic);
            try expectEqual(.level, appended.tone);
        }
    }
}

test "expect State.add cancels an existing matching non-level tone at the last slot boundary" {
    // Arrange
    var state: State = undefined;
    state.init();

    for (0..14) |i| {
        state.buffer_effective[i] = Span.init('b');
    }
    state.buffer_effective[14] = Span.init_diacritic_tone('a', .empty, .rising);
    state.buffer_length = 15;

    // Act
    state.add('s');

    // Assert
    try expectEqual(16, state.buffer_length);
    try expectEqual(14, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);

    for (0..14) |i| {
        const sp = state.buffer_effective[i];
        try expectEqual(@as(u8, 'b'), sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }

    const sp_previous = state.buffer_effective[14];
    try expectEqual(@as(u8, 'a'), sp_previous.base);
    try expectEqual(.empty, sp_previous.diacritic);
    try expectEqual(.level, sp_previous.tone);

    const sp_new = state.buffer_effective[15];
    try expectEqual(@as(u8, 's'), sp_new.base);
    try expectEqual(.empty, sp_new.diacritic);
    try expectEqual(.level, sp_new.tone);
}

test "expect State.pseudoword will scan and provide pseudoword correctly" {
    // Arrange. Each case seeds buffer_effective directly, then asks the
    // pseudo-word scanner for structural indexes only. Cases with a leading
    // consonant include multiple consonant characters to verify that the scan
    // includes only the consonant immediately before the vowel run.
    const Case = struct {
        seeds: []const Span,
        word_start: u8,
        word_end: u8,
        vowels_start: ?u8,
        vowels_end: ?u8,
        length: u8,
        literal_index: ?u8 = null,
    };
    const cases = [_]Case{
        // Vowels only.
        .{ .seeds = &.{.{ .base = 'a' }}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .length = 1 },
        .{ .seeds = &.{ .{ .base = 'O' }, .{ .base = 'A' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .length = 2 },
        .{ .seeds = &.{ .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .length = 2 },

        // Multiple consonants before vowels.
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' }, .{ .base = 'a' } }, .word_start = 1, .word_end = 2, .vowels_start = 2, .vowels_end = 2, .length = 2 },
        .{ .seeds = &.{ .{ .base = 'k' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'n' }, .{ .base = 'g' }, .{ .base = 'i' }, .{ .base = 'a' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ .{ .base = 's' }, .{ .base = 'q' }, .{ .base = 'u' }, .{ .base = 'a' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },

        // Vowels with trailing consonants.
        .{ .seeds = &.{ .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 0, .length = 2 },
        .{ .seeds = &.{ .{ .base = 'o' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'u' }, .{ .base = 'y' }, .{ .base = 'n' }, .{ .base = 'h' } }, .word_start = 0, .word_end = 3, .vowels_start = 0, .vowels_end = 1, .length = 4 },

        // Multiple consonants before vowels and trailing consonants.
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 2, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'k' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 's' }, .{ .base = 'q' }, .{ .base = 'u' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 'n' }, .{ .base = 'g' }, .{ .base = 'i' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' }, .{ .base = 'n' }, .{ .base = 'h' } }, .word_start = 1, .word_end = 5, .vowels_start = 2, .vowels_end = 3, .length = 5 },

        // Vowels with diacritics are still classified by their base letters.
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' }, .{ .base = 'u' }, .{ .base = 'o', .diacritic = .horn }, .{ .base = 'p' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'i' }, .{ .base = 'e', .diacritic = .circumflex }, .{ .base = 'n' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' }, .{ .base = 'a', .diacritic = .circumflex }, .{ .base = 'u' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'c' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a', .diacritic = .breve }, .{ .base = 't' } }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' }, .{ .base = 'u', .diacritic = .horn }, .{ .base = 'u' } }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },

        // Only the trailing pseudo-word is returned.
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'e' }, .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 4, .word_end = 6, .vowels_start = 5, .vowels_end = 6, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'v' }, .{ .base = 'a' }, .{ .base = 'n' }, .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'o' }, .{ .base = 'a' } }, .word_start = 4, .word_end = 6, .vowels_start = 5, .vowels_end = 6, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'a' }, .{ .base = 'o' }, .{ .base = 's' }, .{ .base = 'q' }, .{ .base = 'u' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 4, .word_end = 7, .vowels_start = 5, .vowels_end = 6, .length = 4 },
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'o' }, .{ .base = 'n' }, .{ .base = 'g' }, .{ .base = 'i' }, .{ .base = 'a' }, .{ .base = 'n' } }, .word_start = 3, .word_end = 6, .vowels_start = 4, .vowels_end = 5, .length = 4 },

        // No-vowel suffixes return null vowel bounds.
        .{ .seeds = &.{.{ .base = 'b' }}, .word_start = 0, .word_end = 0, .vowels_start = null, .vowels_end = null, .length = 1 },
        .{ .seeds = &.{ .{ .base = 't' }, .{ .base = 'r' } }, .word_start = 0, .word_end = 1, .vowels_start = null, .vowels_end = null, .length = 2 },
        .{ .seeds = &.{ .{ .base = 'S' }, .{ .base = 'T' }, .{ .base = 'R' } }, .word_start = 0, .word_end = 2, .vowels_start = null, .vowels_end = null, .length = 3 },
        .{ .seeds = &.{ .{ .base = 'd', .diacritic = .stroke }, .{ .base = 'r' } }, .word_start = 0, .word_end = 1, .vowels_start = null, .vowels_end = null, .length = 2 },

        // Full effective buffer boundary.
        .{ .seeds = &.{ .{ .base = 'b' }, .{ .base = 'c' }, .{ .base = 'd' }, .{ .base = 'f' }, .{ .base = 'g' }, .{ .base = 'h' }, .{ .base = 'j' }, .{ .base = 'k' }, .{ .base = 'l' }, .{ .base = 'm' }, .{ .base = 'n' }, .{ .base = 'p' }, .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 13, .word_end = 15, .vowels_start = 14, .vowels_end = 15, .length = 3, .literal_index = 15 },

        // Near effective buffer boundary.
        // 15 characters.
        .{ .seeds = &.{ .{ .base = 'c' }, .{ .base = 'd' }, .{ .base = 'f' }, .{ .base = 'g' }, .{ .base = 'h' }, .{ .base = 'j' }, .{ .base = 'k' }, .{ .base = 'l' }, .{ .base = 'm' }, .{ .base = 'n' }, .{ .base = 'p' }, .{ .base = 't' }, .{ .base = 'h' }, .{ .base = 'u' }, .{ .base = 'y' } }, .word_start = 12, .word_end = 14, .vowels_start = 13, .vowels_end = 14, .length = 3 },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        for (c.seeds, 0..) |s, i| {
            state.buffer_effective[i] = Span.init_diacritic_tone(s.base, s.diacritic, s.tone);
        }
        state.buffer_length = @intCast(c.seeds.len);
        state.literal_index = c.literal_index;

        // Act
        const pseudoword = state.pseudoword();

        // Assert
        try expectEqual(c.word_start, pseudoword.start);
        try expectEqual(c.word_end, pseudoword.end);
        try expectEqual(c.vowels_start, pseudoword.vowels_start);
        try expectEqual(c.vowels_end, pseudoword.vowels_end);
        try expectEqual(c.length, pseudoword.length);
        try expectEqual(c.word_end - c.word_start + 1, pseudoword.length);

        try expectEqual(@as(u8, @intCast(c.seeds.len)), state.buffer_length);
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(c.literal_index, state.literal_index);

        for (c.seeds, 0..) |s, i| {
            const sp = state.buffer_effective[i];
            try expectEqual(s.base, sp.base);
            try expectEqual(s.diacritic, sp.diacritic);
            try expectEqual(s.tone, sp.tone);
        }
    }
}

test "expect State.backspace will reduce buffer_length by 1 and won't touch literal_index" {
    // Arrange
    var state: State = undefined;
    state.init();

    // input 18 characters.
    for ("bbbbbqqqqqbbbbbqqq") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(17, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);
}

test "expect State.backspace will reduce buffer_length by 1 and unset literal_index" {
    // Arrange
    var state: State = undefined;
    state.init();

    // input 16 characters so that the literal_index is set at the last slot.
    for ("bbbbbqqqqqbbbbbq") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(15, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);
}

test "expect State.backspace will reduce buffer_length by 1 when literal_index is not set" {
    // Arrange
    var state: State = undefined;
    state.init();

    // input 5 characters so that literal_index is not set.
    for ("bbbbb") |c| {
        state.add(c);
    }

    // Act
    state.backspace();

    // Assert
    try expectEqual(4, state.buffer_length);
    try expectEqual(null, state.buffer_modification_index);
    try expectEqual(null, state.literal_index);
}

// Simple ABI wrapper for initialize allocated memory.
export fn lex_init(state: *anyopaque) void {
    // Pointer must not be null.
    assert(@intFromPtr(state) != 0);
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
    lex_init(raw_pointer);
    const state: *align(lex_state_alignment) State = @ptrCast(@alignCast(raw_pointer));

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
    // Because we didn't exceed the buffer_effective, don't set literal_index.
    try expectEqual(null, state.literal_index);
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
    // Pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    s.add(c);
}

export fn lex_backspace(state: *anyopaque) void {
    // Pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    s.backspace();
}

export fn lex_calculate_synthetic_backspaces(state: *anyopaque) u8 {
    // Pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    return s.calculate_synthetic_backspaces();
}

export fn lex_buffer_effective_full(state: *anyopaque) bool {
    // Pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    return s.buffer_effective_full();
}
