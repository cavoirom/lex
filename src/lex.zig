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

    fn to_utf16(self: *const Span) u16 {
        assert(isAlphabetic(self.base));

        // fast path, plain alphabet.
        if (self.diacritic == .empty and self.tone == .level) {
            return self.base;
        }

        switch (self.base) {
            'a' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00E1, // á.
                            .falling => return 0x00E0, // à.
                            .dipping_rising => return 0x1EA3, // ả.
                            .rising_glottalized => return 0x00E3, // ã.
                            .falling_glottalized => return 0x1EA1, // ạ.
                        }
                    },
                    .breve => {
                        switch (self.tone) {
                            .level => return 0x0103, // ă.
                            .rising => return 0x1EAF, // ắ.
                            .falling => return 0x1EB1, // ằ.
                            .dipping_rising => return 0x1EB3, // ẳ.
                            .rising_glottalized => return 0x1EB5, // ẵ.
                            .falling_glottalized => return 0x1EB7, // ặ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00E2, // â.
                            .rising => return 0x1EA5, // ấ.
                            .falling => return 0x1EA7, // ầ.
                            .dipping_rising => return 0x1EA9, // ẩ.
                            .rising_glottalized => return 0x1EAB, // ẫ.
                            .falling_glottalized => return 0x1EAD, // ậ.
                        }
                    },
                    .horn, .stroke => unreachable,
                }
            },
            'A' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00C1, // Á.
                            .falling => return 0x00C0, // À.
                            .dipping_rising => return 0x1EA2, // Ả.
                            .rising_glottalized => return 0x00C3, // Ã.
                            .falling_glottalized => return 0x1EA0, // Ạ.
                        }
                    },
                    .breve => {
                        switch (self.tone) {
                            .level => return 0x0102, // Ă.
                            .rising => return 0x1EAE, // Ắ.
                            .falling => return 0x1EB0, // Ằ.
                            .dipping_rising => return 0x1EB2, // Ẳ.
                            .rising_glottalized => return 0x1EB4, // Ẵ.
                            .falling_glottalized => return 0x1EB6, // Ặ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00C2, // Â.
                            .rising => return 0x1EA4, // Ấ.
                            .falling => return 0x1EA6, // Ầ.
                            .dipping_rising => return 0x1EA8, // Ẩ.
                            .rising_glottalized => return 0x1EAA, // Ẫ.
                            .falling_glottalized => return 0x1EAC, // Ậ.
                        }
                    },
                    .horn, .stroke => unreachable,
                }
            },
            'd' => {
                assert(self.diacritic == .stroke);
                assert(self.tone == .level);
                return 0x0111; // đ.
            },
            'D' => {
                assert(self.diacritic == .stroke);
                assert(self.tone == .level);
                return 0x0110; // Đ.
            },
            'e' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00E9, // é.
                            .falling => return 0x00E8, // è.
                            .dipping_rising => return 0x1EBB, // ẻ.
                            .rising_glottalized => return 0x1EBD, // ẽ.
                            .falling_glottalized => return 0x1EB9, // ẹ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00EA, // ê.
                            .rising => return 0x1EBF, // ế.
                            .falling => return 0x1EC1, // ề.
                            .dipping_rising => return 0x1EC3, // ể.
                            .rising_glottalized => return 0x1EC5, // ễ.
                            .falling_glottalized => return 0x1EC7, // ệ.
                        }
                    },
                    .horn, .breve, .stroke => unreachable,
                }
            },
            'E' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00C9, // É.
                            .falling => return 0x00C8, // È.
                            .dipping_rising => return 0x1EBA, // Ẻ.
                            .rising_glottalized => return 0x1EBC, // Ẽ.
                            .falling_glottalized => return 0x1EB8, // Ẹ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00CA, // Ê.
                            .rising => return 0x1EBE, // Ế.
                            .falling => return 0x1EC0, // Ề.
                            .dipping_rising => return 0x1EC2, // Ể.
                            .rising_glottalized => return 0x1EC4, // Ễ.
                            .falling_glottalized => return 0x1EC6, // Ệ.
                        }
                    },
                    .horn, .breve, .stroke => unreachable,
                }
            },
            'i' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00ED, // í.
                            .falling => return 0x00EC, // ì.
                            .dipping_rising => return 0x1EC9, // ỉ.
                            .rising_glottalized => return 0x0129, // ĩ.
                            .falling_glottalized => return 0x1ECB, // ị.
                        }
                    },
                    .circumflex, .horn, .breve, .stroke => unreachable,
                }
            },
            'I' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00CD, // Í.
                            .falling => return 0x00CC, // Ì.
                            .dipping_rising => return 0x1EC8, // Ỉ.
                            .rising_glottalized => return 0x0128, // Ĩ.
                            .falling_glottalized => return 0x1ECA, // Ị.
                        }
                    },
                    .circumflex, .horn, .breve, .stroke => unreachable,
                }
            },
            'o' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00F3, // ó.
                            .falling => return 0x00F2, // ò.
                            .dipping_rising => return 0x1ECF, // ỏ.
                            .rising_glottalized => return 0x00F5, // õ.
                            .falling_glottalized => return 0x1ECD, // ọ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00F4, // ô.
                            .rising => return 0x1ED1, // ố.
                            .falling => return 0x1ED3, // ồ.
                            .dipping_rising => return 0x1ED5, // ổ.
                            .rising_glottalized => return 0x1ED7, // ỗ.
                            .falling_glottalized => return 0x1ED9, // ộ.
                        }
                    },
                    .horn => {
                        switch (self.tone) {
                            .level => return 0x01A1, // ơ.
                            .rising => return 0x1EDB, // ớ.
                            .falling => return 0x1EDD, // ờ.
                            .dipping_rising => return 0x1EDF, // ở.
                            .rising_glottalized => return 0x1EE1, // ỡ.
                            .falling_glottalized => return 0x1EE3, // ợ.
                        }
                    },
                    .breve, .stroke => unreachable,
                }
            },
            'O' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00D3, // Ó.
                            .falling => return 0x00D2, // Ò.
                            .dipping_rising => return 0x1ECE, // Ỏ.
                            .rising_glottalized => return 0x00D5, // Õ.
                            .falling_glottalized => return 0x1ECC, // Ọ.
                        }
                    },
                    .circumflex => {
                        switch (self.tone) {
                            .level => return 0x00D4, // Ô.
                            .rising => return 0x1ED0, // Ố.
                            .falling => return 0x1ED2, // Ồ.
                            .dipping_rising => return 0x1ED4, // Ổ.
                            .rising_glottalized => return 0x1ED6, // Ỗ.
                            .falling_glottalized => return 0x1ED8, // Ộ.
                        }
                    },
                    .horn => {
                        switch (self.tone) {
                            .level => return 0x01A0, // Ơ.
                            .rising => return 0x1EDA, // Ớ.
                            .falling => return 0x1EDC, // Ờ.
                            .dipping_rising => return 0x1EDE, // Ở.
                            .rising_glottalized => return 0x1EE0, // Ỡ.
                            .falling_glottalized => return 0x1EE2, // Ợ.
                        }
                    },
                    .breve, .stroke => unreachable,
                }
            },
            'u' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00FA, // ú.
                            .falling => return 0x00F9, // ù.
                            .dipping_rising => return 0x1EE7, // ủ.
                            .rising_glottalized => return 0x0169, // ũ.
                            .falling_glottalized => return 0x1EE5, // ụ.
                        }
                    },
                    .horn => {
                        switch (self.tone) {
                            .level => return 0x01B0, // ư.
                            .rising => return 0x1EE9, // ứ.
                            .falling => return 0x1EEB, // ừ.
                            .dipping_rising => return 0x1EED, // ử.
                            .rising_glottalized => return 0x1EEF, // ữ.
                            .falling_glottalized => return 0x1EF1, // ự.
                        }
                    },
                    .circumflex, .breve, .stroke => unreachable,
                }
            },
            'U' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00DA, // Ú.
                            .falling => return 0x00D9, // Ù.
                            .dipping_rising => return 0x1EE6, // Ủ.
                            .rising_glottalized => return 0x0168, // Ũ.
                            .falling_glottalized => return 0x1EE4, // Ụ.
                        }
                    },
                    .horn => {
                        switch (self.tone) {
                            .level => return 0x01AF, // Ư.
                            .rising => return 0x1EE8, // Ứ.
                            .falling => return 0x1EEA, // Ừ.
                            .dipping_rising => return 0x1EEC, // Ử.
                            .rising_glottalized => return 0x1EEE, // Ữ.
                            .falling_glottalized => return 0x1EF0, // Ự.
                        }
                    },
                    .circumflex, .breve, .stroke => unreachable,
                }
            },
            'y' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00FD, // ý.
                            .falling => return 0x1EF3, // ỳ.
                            .dipping_rising => return 0x1EF7, // ỷ.
                            .rising_glottalized => return 0x1EF9, // ỹ.
                            .falling_glottalized => return 0x1EF5, // ỵ.
                        }
                    },
                    .circumflex, .horn, .breve, .stroke => unreachable,
                }
            },
            'Y' => {
                switch (self.diacritic) {
                    .empty => {
                        switch (self.tone) {
                            .level => unreachable,
                            .rising => return 0x00DD, // Ý.
                            .falling => return 0x1EF2, // Ỳ.
                            .dipping_rising => return 0x1EF6, // Ỷ.
                            .rising_glottalized => return 0x1EF8, // Ỹ.
                            .falling_glottalized => return 0x1EF4, // Ỵ.
                        }
                    },
                    .circumflex, .horn, .breve, .stroke => unreachable,
                }
            },
            else => unreachable,
        }
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

test "expect Span.to_utf16 produces correct UTF-16 code point" {
    // Arrange
    const Case = struct { base: u8, diacritic: Diacritic, tone: Tone, expected: u16 };
    const cases = [_]Case{
        .{ .base = 'a', .diacritic = .empty, .tone = .level, .expected = 0x0061 }, // a.
        .{ .base = 'Z', .diacritic = .empty, .tone = .level, .expected = 0x005A }, // Z.
        .{ .base = 'a', .diacritic = .empty, .tone = .rising, .expected = 0x00E1 }, // á.
        .{ .base = 'i', .diacritic = .empty, .tone = .rising_glottalized, .expected = 0x0129 }, // ĩ.
        .{ .base = 'y', .diacritic = .empty, .tone = .falling_glottalized, .expected = 0x1EF5 }, // ỵ.
        .{ .base = 'a', .diacritic = .breve, .tone = .falling, .expected = 0x1EB1 }, // ằ.
        .{ .base = 'a', .diacritic = .circumflex, .tone = .dipping_rising, .expected = 0x1EA9 }, // ẩ.
        .{ .base = 'e', .diacritic = .circumflex, .tone = .falling_glottalized, .expected = 0x1EC7 }, // ệ.
        .{ .base = 'o', .diacritic = .circumflex, .tone = .rising, .expected = 0x1ED1 }, // ố.
        .{ .base = 'o', .diacritic = .horn, .tone = .rising_glottalized, .expected = 0x1EE1 }, // ỡ.
        .{ .base = 'u', .diacritic = .horn, .tone = .falling, .expected = 0x1EEB }, // ừ.
        .{ .base = 'A', .diacritic = .breve, .tone = .rising, .expected = 0x1EAE }, // Ắ.
        .{ .base = 'E', .diacritic = .circumflex, .tone = .falling, .expected = 0x1EC0 }, // Ề.
        .{ .base = 'O', .diacritic = .horn, .tone = .falling_glottalized, .expected = 0x1EE2 }, // Ợ.
        .{ .base = 'U', .diacritic = .horn, .tone = .dipping_rising, .expected = 0x1EEC }, // Ử.
        .{ .base = 'Y', .diacritic = .empty, .tone = .rising_glottalized, .expected = 0x1EF8 }, // Ỹ.
        .{ .base = 'd', .diacritic = .stroke, .tone = .level, .expected = 0x0111 }, // đ.
        .{ .base = 'D', .diacritic = .stroke, .tone = .level, .expected = 0x0110 }, // Đ.
    };

    for (cases) |c| {
        // Act
        const sp = Span.init_diacritic_tone(c.base, c.diacritic, c.tone);

        // Assert
        try expectEqual(c.expected, sp.to_utf16());
    }
}

// Information about a range of characters for tone positioning.
const Pseudoword = struct {
    // The start position of the word on State.buffer_effective.
    start: u8,
    // The end position of the word on State.buffer_effective.
    end: u8,
    // The start position of the toneable vowels on State.buffer_effective.
    vowels_start: ?u8,
    // The end position of the toneable vowels on State.buffer_effective.
    vowels_end: ?u8,
    // The length of the word.
    length: u8,

    fn has_vowels(self: *const Pseudoword) bool {
        return self.vowels_start != null and self.vowels_end != null;
    }
};

const buffer_effective_length: u8 = 16;

const State = struct {
    // The effective buffer to process Vietnamese input. We will skip processing if the buffer
    // is longer than 15. The last input is always literal.
    buffer_effective: [buffer_effective_length]Span,
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
            // The literal_index value must be in the range null or 0 -> 15 (within buffer_effective)
            // because we won't process Vietnamese input outside the buffer_effective and need the
            // literal character for replacement composition.
            assert(literal_index < self.buffer_effective.len);
            // The literal_index value must be less than buffer length.
            assert(literal_index < self.buffer_length);
        }

        // buffer_length conditions
        // 1. must be within buffer_effective length while the whole buffer is Telex-processable.
        // 2. could be equal to or greater than buffer_effective after literal_index starts the literal
        //    tail.
        assert(self.buffer_length < self.buffer_effective.len or self.literal_index != null);

        // Reset buffer_modification_index to start the new action.
        self.buffer_modification_index = null;

        // Keep the buffer_length in buffer_length_previous for synthetic backspace calculation.
        self.buffer_length_previous = self.buffer_length;

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
            'C', 'c' => input_c: { // fill missing diacritic, e.g. cước.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_c;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'I', 'i' => input_i: { // fill missing diacritic, e.g. người.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_i;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'M', 'm' => input_m: { // fill missing diacritic, e.g. cườm.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_m;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'N', 'n' => input_n: { // fill missing diacritic, e.g. cường.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_n;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'P', 'p' => input_p: { // fill missing diacritic, e.g. cướp.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_p;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'T', 't' => input_t: { // fill missing diacritic, e.g. trượt.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_t;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'U', 'u' => input_u: { // fill missing diacritic, e.g. hươu.
                if (self.literal_index != null or self.buffer_length < 2) {
                    // 1. Append literally when literal_index is set.
                    // 2. Append literal because less than 2 spans existed. Continue Vietnamese
                    // processing on next input.
                    // 3. Buffer is less than 2 characters to start with.
                    self.append_literal(c);
                    // Set modification index to null because we didn't modify any existing span.
                    self.buffer_modification_index = null;
                } else if (self.buffer_effective[self.buffer_length - 2].equals_ignore_case_tone('U', .empty) and self.buffer_effective[self.buffer_length - 1].equals_ignore_case_tone('O', .horn)) {
                    if (self.buffer_length > 2 and self.buffer_effective[self.buffer_length - 3].equals_ignore_case_diacritic_tone('Q')) {
                        // 4a. The 'U' in this case belongs to 'QU', a consonant, append literally.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_u;
                    }
                    // 4b. Pattern: 'UƠ', fill missing horn on 'U'.
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
            'W', 'w' => input_w: { // breve, horn
                if (self.literal_index != null or self.buffer_length == 0) {
                    // 1. Literal index is set, stop processing Vietnamese input.
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
                    if (self.buffer_length > 1 and self.buffer_effective[self.buffer_length - 2].equals_ignore_case_diacritic_tone('Q')) {
                        // 10a. Previous spans are QU, a consonant, append literally.
                        // Start literal input from this position.
                        self.literal_index = self.buffer_length;
                        // Append literal 'W', 'w'.
                        self.append_literal(c);
                        self.buffer_modification_index = null;
                        break :input_w;
                    }
                    // 10b. Previous span is 'U', 'u', apply horn.
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
                    // 2. Literal index is set, stop processing Vietnamese input.
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

        // The buffer_modification_index must point to a pre-existing span before add action.
        assert(self.buffer_modification_index == null or self.buffer_modification_index.? < self.buffer_length_previous);
        // The buffer_modification index must be within the bounds of buffer_effective.
        assert(self.buffer_modification_index == null or (self.buffer_modification_index.? < self.buffer_effective.len and self.buffer_modification_index.? < self.buffer_length));

        // The buffer_length_previous must not be larger than buffer_length.
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
        // 1. Should not work if buffer_length exceeds buffer_effective.
        // 2. Buffer must have at least 1 character.
        assert(self.buffer_length > 0 and self.buffer_length <= self.buffer_effective.len);

        return self.buffer_effective[self.buffer_length - 1];
    }

    // Return the pseudoword when scanning buffer_effective backward.
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
                // 3. Handle 'QU' case, in this case, U is a part of the consonant 'QU'.
                const starts_with_qu = sp.equals_ignore_case_diacritic_tone('Q') and
                    self.buffer_effective[vowels_start.?].equals_ignore_case('U', .empty, .level);
                if (starts_with_qu and vowels_start.? < vowels_end.?) {
                    // Has another vowel next to 'U', exclude 'U' from the vowel range.
                    vowels_start = vowels_start.? + 1;
                } else if (starts_with_qu and vowels_start.? == vowels_end.?) {
                    // No other vowels, reset the range to null.
                    vowels_start = null;
                    vowels_end = null;
                }
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

        // word_start must always have a valid value.
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

        // Exclude exact 'QU' (unadorned 'U') because the pseudo-word scan treats it as a
        // consonant cluster and never provides it as a toneable vowel.
        if (word.length == 2) {
            assert(!(self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[word.end].equals_ignore_case('U', .empty, .level)));
        }

        // Existing vowels must have a level tone.
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
            // The tone must never land on the 'U' of a 'QU' consonant cluster.
            if (vowels_start > 0) {
                assert(!(self.buffer_effective[vowels_start - 1].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[vowels_start].equals_ignore_case_diacritic_tone('U')));
            }
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

        // Special consonant: `GI`.
        var gi_special_start_exists: bool = false;
        if (self.buffer_effective[word.start].equals_ignore_case_diacritic_tone('G') and self.buffer_effective[word.start + 1].equals_ignore_case_diacritic_tone('I')) {
            gi_special_start_exists = true;
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
        } else if (gi_special_start_exists) {
            // 'GI', skip the first vowel because it's 'I', put tone on next vowel.
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

        // The tone must never land on the 'U' of a 'QU' consonant cluster.
        if (tone_index > 0) {
            assert(!(self.buffer_effective[tone_index - 1].equals_ignore_case_diacritic_tone('Q') and self.buffer_effective[tone_index].equals_ignore_case_diacritic_tone('U')));
        }

        const sp = self.buffer_effective[tone_index];
        self.buffer_effective[tone_index] = Span.init_diacritic_tone(sp.base, sp.diacritic, tone);

        // Set buffer_modification_index to the earliest modification.
        if (self.buffer_modification_index == null or tone_index < self.buffer_modification_index.?) {
            self.buffer_modification_index = tone_index;
        }

        assert(self.buffer_modification_index != null);
    }

    // Reset all tones in vowels to level. If word has no tone, this function is no-op.
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
        // The previous length must have valid value.
        assert(self.buffer_length_previous <= self.buffer_length);
        assert(self.buffer_modification_index == null or (self.buffer_modification_index.? < self.buffer_length_previous));

        if (self.buffer_modification_index) |buffer_modification_index| {
            return self.buffer_length_previous - buffer_modification_index;
        } else {
            return 0;
        }
    }

    // Compose UTF-16 string replacement for the synthetic events. It could be multiple characters
    // or one literal character.
    fn compose_utf16_string_replacement(self: *State, replacement_buffer: *[buffer_effective_length]u16, replacement_count: *u8) void {
        // The buffer must have character.
        assert(self.buffer_length > 0);
        // The buffer_length must be within buffer_effective.
        assert(self.buffer_length <= self.buffer_effective.len);

        if (self.buffer_modification_index) |buffer_modification_index| {
            // The previous action has modified buffer_effective.
            // Iterate from the buffer_modification_index to compose the replacement.
            for (buffer_modification_index..self.buffer_length) |i| {
                replacement_buffer[i - buffer_modification_index] = self.buffer_effective[i].to_utf16();
            }
            // Calculate replacement_count.
            replacement_count.* = self.buffer_length - buffer_modification_index;
        } else {
            // The previous action only added one character literally, no retrospect editing.
            assert((self.buffer_length - self.buffer_length_previous) == 1);

            replacement_buffer[0] = self.buffer_effective[self.buffer_length - 1].to_utf16();
            replacement_count.* = 1;
        }
    }

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

test "expect State.add handles non-Telex characters one character less than buffer_effective length" {
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
    // Verify every span is exactly the same as the input.
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
    // Verify every span is exactly the same as the input.
    for (input_sequence, 0..) |c, i| {
        const sp = state.buffer_effective[i];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect State.add handles non-Telex characters just exceeds the buffer_effective length" {
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
    // Because the input exceeds the buffer_effective, keep literal_index at the last slot.
    try expectEqual(15, state.literal_index);
    // Verify every span is exactly the same as the input.
    for (input_sequence[0..16], 0..) |c, i| {
        const sp = state.buffer_effective[i];
        try expectEqual(c, sp.base);
        try expectEqual(.empty, sp.diacritic);
        try expectEqual(.level, sp.tone);
    }
}

test "expect State.add adds a character literally because it's the start of the buffer" {
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

test "expect State.add starts literal input when the new input fills the last slot" {
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

test "expect State.add applies circumflex for valid cases" {
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

test "expect State.add applies breve for valid cases" {
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

test "expect State.add applies horn for valid cases" {
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

test "expect State.add does not apply horn for 'U' in 'QU' because 'QU' is a consonant" {
    // Arrange
    const Case = struct { seeds: []const Span, new_input: u8 };
    const cases = [_]Case{
        .{ .seeds = &.{ Span.init('q'), Span.init('u') }, .new_input = 'w' },
        .{ .seeds = &.{ Span.init('q'), Span.init('u') }, .new_input = 'W' },
        .{ .seeds = &.{ Span.init('q'), Span.init('U') }, .new_input = 'w' },
        .{ .seeds = &.{ Span.init('q'), Span.init('U') }, .new_input = 'W' },
        .{ .seeds = &.{ Span.init('Q'), Span.init('u') }, .new_input = 'w' },
        .{ .seeds = &.{ Span.init('Q'), Span.init('u') }, .new_input = 'W' },
        .{ .seeds = &.{ Span.init('Q'), Span.init('U') }, .new_input = 'w' },
        .{ .seeds = &.{ Span.init('Q'), Span.init('U') }, .new_input = 'W' },
        .{ .seeds = &.{ Span.init('a'), Span.init('b'), Span.init('c'), Span.init('q'), Span.init('u') }, .new_input = 'w' },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        for (c.seeds, 0..) |s, i| {
            state.buffer_effective[i] = s;
        }
        state.buffer_length = @intCast(c.seeds.len);

        // Act
        state.add(c.new_input);

        // Assert
        const expected_buffer_length: u8 = @intCast(c.seeds.len + 1);
        const expected_literal_index: u8 = @intCast(c.seeds.len);
        try expectEqual(expected_buffer_length, state.buffer_length);
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(@as(?u8, expected_literal_index), state.literal_index);

        for (c.seeds, 0..) |s, i| {
            const sp = state.buffer_effective[i];
            try expectEqual(s.base, sp.base);
            try expectEqual(s.diacritic, sp.diacritic);
            try expectEqual(s.tone, sp.tone);
        }

        const sp_previous = state.buffer_effective[c.seeds.len - 1];
        try expectEqual(.empty, sp_previous.diacritic);
        try expectEqual(.level, sp_previous.tone);

        const sp_new = state.buffer_effective[c.seeds.len];
        try expectEqual(c.new_input, sp_new.base);
        try expectEqual(.empty, sp_new.diacritic);
        try expectEqual(.level, sp_new.tone);
    }
}

test "expect State.add applies stroke for valid cases" {
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

test "expect State.add overrides existing diacritic with the new diacritic for valid cases" {
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

test "expect State.add cancels existing diacritic for valid cases" {
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

test "expect State.add cancelling an existing diacritic switches to literal for the next characters" {
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

test "expect State.add cancels existing diacritic at the last slot boundary" {
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

test "expect State.add auto-fills missing horn in valid cases" {
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

test "expect State.add does not auto-fill missing horn in 'QUƠ' because 'QU' is a consonant" {
    // Arrange
    const q_cases = [_]u8{ 'q', 'Q' };
    const u_cases = [_]u8{ 'u', 'U' };
    const o_cases = [_]u8{ 'o', 'O' };
    const triggers = [_]u8{ 'C', 'c', 'I', 'i', 'M', 'm', 'N', 'n', 'P', 'p', 'T', 't', 'U', 'u' };

    for (q_cases) |q| {
        for (u_cases) |u| {
            for (o_cases) |o| {
                for (triggers) |trigger| {
                    var state: State = undefined;
                    state.init();
                    state.buffer_effective[0] = Span.init(q);
                    state.buffer_effective[1] = Span.init(u);
                    state.buffer_effective[2] = Span.init_diacritic(o, .horn);
                    state.buffer_length = 3;

                    // Act
                    state.add(trigger);

                    // Assert
                    try expectEqual(4, state.buffer_length);
                    try expectEqual(null, state.buffer_modification_index);
                    try expectEqual(null, state.literal_index);

                    const sp_q = state.buffer_effective[0];
                    try expectEqual(q, sp_q.base);
                    try expectEqual(.empty, sp_q.diacritic);
                    try expectEqual(.level, sp_q.tone);

                    const sp_u = state.buffer_effective[1];
                    try expectEqual(u, sp_u.base);
                    try expectEqual(.empty, sp_u.diacritic);
                    try expectEqual(.level, sp_u.tone);

                    const sp_o = state.buffer_effective[2];
                    try expectEqual(o, sp_o.base);
                    try expectEqual(.horn, sp_o.diacritic);
                    try expectEqual(.level, sp_o.tone);

                    const sp_new = state.buffer_effective[3];
                    try expectEqual(trigger, sp_new.base);
                    try expectEqual(.empty, sp_new.diacritic);
                    try expectEqual(.level, sp_new.tone);
                }
            }
        }
    }
}

test "expect State.add auto-fills missing horn at the last slot boundary" {
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

test "expect State.add switches to literal input when appending F or J, W, Z (ignore cases) on empty buffer" {
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

test "expect State.add switches to literal input when appending W (ignore cases) on character outside diacritic scope" {
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

test "expect State.add appends tone triggers literally on word without placeable tone" {
    const Input = struct { trigger: u8, starts_literal_tail: bool };
    const inputs = [_]Input{
        .{ .trigger = 'F', .starts_literal_tail = true },
        .{ .trigger = 'f', .starts_literal_tail = true },
        .{ .trigger = 'J', .starts_literal_tail = true },
        .{ .trigger = 'j', .starts_literal_tail = true },
        .{ .trigger = 'R', .starts_literal_tail = false },
        .{ .trigger = 'r', .starts_literal_tail = false },
        .{ .trigger = 'S', .starts_literal_tail = false },
        .{ .trigger = 's', .starts_literal_tail = false },
        .{ .trigger = 'X', .starts_literal_tail = false },
        .{ .trigger = 'x', .starts_literal_tail = false },
    };

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
            state.add(input.trigger);

            // Assert
            try expectEqual(2, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            const expected_literal_index: ?u8 = if (input.starts_literal_tail) 1 else null;
            try expectEqual(expected_literal_index, state.literal_index);

            const sp_previous = state.buffer_effective[0];
            try expectEqual(c.base, sp_previous.base);
            try expectEqual(.empty, sp_previous.diacritic);
            try expectEqual(.level, sp_previous.tone);

            const sp_new = state.buffer_effective[1];
            try expectEqual(input.trigger, sp_new.base);
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
            state.add(input.trigger);

            // Assert
            try expectEqual(3, state.buffer_length);
            try expectEqual(null, state.buffer_modification_index);
            const expected_literal_index: ?u8 = if (input.starts_literal_tail) 2 else null;
            try expectEqual(expected_literal_index, state.literal_index);

            const sp_previous0 = state.buffer_effective[0];
            try expectEqual(c.base0, sp_previous0.base);
            try expectEqual(.empty, sp_previous0.diacritic);
            try expectEqual(.level, sp_previous0.tone);

            const sp_previous1 = state.buffer_effective[1];
            try expectEqual(c.base1, sp_previous1.base);
            try expectEqual(.empty, sp_previous1.diacritic);
            try expectEqual(.level, sp_previous1.tone);

            const sp_new = state.buffer_effective[2];
            try expectEqual(input.trigger, sp_new.base);
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
        .{ .base0 = 'q', .base1 = 'u' },
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

    // Sub-block C: QU with trailing consonant is still a pseudo-word without a toneable vowel.
    const TripleCase = struct { base0: u8, base1: u8, base2: u8 };
    const triple_cases = [_]TripleCase{
        .{ .base0 = 'q', .base1 = 'u', .base2 = 'n' },
        .{ .base0 = 'Q', .base1 = 'U', .base2 = 'N' },
    };

    for (triple_cases) |c| {
        for (inputs) |input| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init(c.base0);
            state.buffer_effective[1] = Span.init(c.base1);
            state.buffer_effective[2] = Span.init(c.base2);
            state.buffer_length = 3;

            // Act
            state.add(input);

            // Assert
            try expectEqual(4, state.buffer_length);
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

            const sp_previous2 = state.buffer_effective[2];
            try expectEqual(c.base2, sp_previous2.base);
            try expectEqual(.empty, sp_previous2.diacritic);
            try expectEqual(.level, sp_previous2.tone);

            const sp_new = state.buffer_effective[3];
            try expectEqual(input, sp_new.base);
            try expectEqual(.empty, sp_new.diacritic);
            try expectEqual(.level, sp_new.tone);
        }
    }
}

test "expect State.add resets non-level tone with Z on the real vowel after 'QU'" {
    const InputCase = struct { input: u8 };
    const input_cases = [_]InputCase{
        .{ .input = 'Z' },
        .{ .input = 'z' },
    };
    const tones = [_]Tone{ .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (input_cases) |input_case| {
        for (tones) |tone| {
            var state: State = undefined;
            state.init();
            state.buffer_effective[0] = Span.init('q');
            state.buffer_effective[1] = Span.init('u');
            state.buffer_effective[2] = Span.init_diacritic_tone('a', .empty, tone);
            state.buffer_length = 3;

            // Act
            state.add(input_case.input);

            // Assert
            try expectEqual(3, state.buffer_length);
            try expectEqual(2, state.buffer_modification_index);
            try expectEqual(null, state.literal_index);

            const sp_q = state.buffer_effective[0];
            try expectEqual(@as(u8, 'q'), sp_q.base);
            try expectEqual(.empty, sp_q.diacritic);
            try expectEqual(.level, sp_q.tone);

            const sp_u = state.buffer_effective[1];
            try expectEqual(@as(u8, 'u'), sp_u.base);
            try expectEqual(.empty, sp_u.diacritic);
            try expectEqual(.level, sp_u.tone);

            const sp_a = state.buffer_effective[2];
            try expectEqual(@as(u8, 'a'), sp_a.base);
            try expectEqual(.empty, sp_a.diacritic);
            try expectEqual(.level, sp_a.tone);
        }
    }
}

test "expect State.apply_tone places tone at the correct vowel for every non-level tone" {
    // Arrange. Each case seeds buffer_effective directly with .level vowels,
    // builds a Pseudoword by hand (so this test stays independent from the
    // pseudo-word scanner and the State.add dispatch), and calls apply_tone.
    // Every case is iterated across all non-level tones to verify the tone
    // value is preserved on the targeted vowel and no other span is touched.
    const Case = struct {
        seeds: []const Span,
        word_start: u8,
        word_end: u8,
        vowels_start: u8,
        vowels_end: u8,
        expected_index: u8,
    };
    const cases = [_]Case{
        // Single vowel placement (vowels only).
        .{ .seeds = &.{Span.init('a')}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        .{ .seeds = &.{Span.init('A')}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        // Single vowel with leading consonant.
        .{ .seeds = &.{ Span.init('b'), Span.init('a') }, .word_start = 0, .word_end = 1, .vowels_start = 1, .vowels_end = 1, .expected_index = 1 },
        // Single vowel with trailing consonant.
        .{ .seeds = &.{ Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 0, .expected_index = 0 },
        // Single vowel with leading and trailing consonant.
        .{ .seeds = &.{ Span.init('b'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 1, .expected_index = 1 },

        // Exact OA / OE / OO / UY -> first vowel.
        .{ .seeds = &.{ Span.init('o'), Span.init('a') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ Span.init('o'), Span.init('e') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ Span.init('o'), Span.init('o') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        .{ .seeds = &.{ Span.init('u'), Span.init('y') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
        // Exact OA / OE / OO / UY with leading consonant -> first vowel.
        .{ .seeds = &.{ Span.init('h'), Span.init('o'), Span.init('a') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },
        .{ .seeds = &.{ Span.init('h'), Span.init('u'), Span.init('y') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },

        // Extended OA / OE / OO / UY (trailing consonant) -> second vowel.
        .{ .seeds = &.{ Span.init('o'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        .{ .seeds = &.{ Span.init('u'), Span.init('y'), Span.init('n') }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        .{ .seeds = &.{ Span.init('h'), Span.init('o'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('h'), Span.init('u'), Span.init('y'), Span.init('n'), Span.init('h') }, .word_start = 0, .word_end = 4, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('x'), Span.init('o'), Span.init('o'), Span.init('n'), Span.init('g') }, .word_start = 0, .word_end = 4, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        // Extended OA / OE / UY (more vowels) -> second vowel.
        .{ .seeds = &.{ Span.init('x'), Span.init('o'), Span.init('a'), Span.init('y') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 3, .expected_index = 2 },

        // GI consonant-vowel special: tone on next vowel.
        .{ .seeds = &.{ Span.init('g'), Span.init('i'), Span.init('a') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('g'), Span.init('i'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },

        // QU consonant-vowel words: the U in QU is not part of the toneable vowel range.
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a') }, .word_start = 0, .word_end = 2, .vowels_start = 2, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 3, .vowels_start = 2, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a'), Span.init('y') }, .word_start = 0, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('y'), Span.init_diacritic('e', .circumflex), Span.init('n') }, .word_start = 0, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .expected_index = 3 },

        // Ơ has the highest priority among the special vowels.
        .{ .seeds = &.{ Span.init('u'), Span.init_diacritic('o', .horn), Span.init('p') }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .expected_index = 1 },
        // Special diacritic priority Ê / Â / Ô / Ă / Ư -- the rightmost listed
        // vowel wins per the right-to-left scan.
        .{ .seeds = &.{ Span.init('t'), Span.init('i'), Span.init_diacritic('e', .circumflex), Span.init('n') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('d'), Span.init_diacritic('a', .circumflex), Span.init('u') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },
        .{ .seeds = &.{ Span.init('t'), Span.init('u'), Span.init_diacritic('o', .circumflex), Span.init('n') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('l'), Span.init('o'), Span.init_diacritic('a', .breve), Span.init('t') }, .word_start = 0, .word_end = 3, .vowels_start = 1, .vowels_end = 2, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('t'), Span.init_diacritic('u', .horn), Span.init('u') }, .word_start = 0, .word_end = 2, .vowels_start = 1, .vowels_end = 2, .expected_index = 1 },

        // Default multi-vowel fallback (no special, no GI/QU, no OA/OE/OO/UY) -> first vowel.
        .{ .seeds = &.{ Span.init('i'), Span.init('a') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .expected_index = 0 },
    };

    const tones = [_]Tone{ .rising, .falling, .dipping_rising, .rising_glottalized, .falling_glottalized };

    for (cases) |c| {
        for (tones) |tone| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                state.buffer_effective[i] = s;
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
    const Case = struct {
        seeds: []const Span,
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
        .{ .seeds = &.{Span.init('a')}, .trigger_case = .lower, .expected_index = 0 },
        // Uppercase trigger, single vowel.
        .{ .seeds = &.{Span.init('A')}, .trigger_case = .upper, .expected_index = 0 },
        // Simple consonant + single vowel.
        .{ .seeds = &.{ Span.init('b'), Span.init('a') }, .trigger_case = .lower, .expected_index = 1 },
        // Multi-vowel run (exact OA -> first vowel).
        .{ .seeds = &.{ Span.init('h'), Span.init('o'), Span.init('a') }, .trigger_case = .lower, .expected_index = 1 },
        // Trailing-suffix pseudo-word (only the last syllable receives the tone).
        .{ .seeds = &.{ Span.init('v'), Span.init('a'), Span.init('n'), Span.init('h'), Span.init('o'), Span.init('a') }, .trigger_case = .lower, .expected_index = 4 },
    };

    for (tone_cases) |tone_case| {
        for (cases) |c| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                state.buffer_effective[i] = s;
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

test "expect State.add applies non-level tones to the real vowel after 'QU'" {
    const ToneCase = struct { tone: Tone, trigger: u8 };
    const Case = struct { seeds: []const Span, expected_index: u8 };

    const tone_cases = [_]ToneCase{
        .{ .tone = .rising, .trigger = 's' },
        .{ .tone = .falling, .trigger = 'f' },
        .{ .tone = .dipping_rising, .trigger = 'r' },
        .{ .tone = .rising_glottalized, .trigger = 'x' },
        .{ .tone = .falling_glottalized, .trigger = 'j' },
    };
    const cases = [_]Case{
        // Single real vowel after QU.
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a') }, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('e') }, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('i') }, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('o') }, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('y') }, .expected_index = 2 },

        // Multi-vowel valid Vietnamese word starts.
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a'), Span.init('y') }, .expected_index = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init_diacritic('o', .horn), Span.init('i') }, .expected_index = 2 },
        .{
            .seeds = &.{
                Span.init('q'),
                Span.init('u'),
                Span.init('y'),
                Span.init_diacritic('e', .circumflex),
                Span.init('n'),
            },
            .expected_index = 3,
        },
    };

    for (tone_cases) |tone_case| {
        for (cases) |c| {
            var state: State = undefined;
            state.init();
            for (c.seeds, 0..) |s, i| {
                state.buffer_effective[i] = s;
            }
            state.buffer_length = @intCast(c.seeds.len);

            // Act
            state.add(tone_case.trigger);

            // Assert: the trigger character is NOT appended; QU remains a consonant cluster and the
            // requested tone lands on the real vowel after QU.
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
    const Case = struct {
        seeds: []const Span,
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
            .seeds = &.{Span.init('a')},
            .trigger_case = .lower,
            .expected_modification_index = 0,
        },
        // Uppercase trigger, single plain vowel.
        .{
            .seeds = &.{Span.init('A')},
            .trigger_case = .upper,
            .expected_modification_index = 0,
        },
        // Consonant + plain vowel (open syllable).
        .{
            .seeds = &.{ Span.init('b'), Span.init('a') },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Trailing consonant (closed syllable). The trailing 'n' must remain untouched.
        .{
            .seeds = &.{ Span.init('b'), Span.init('a'), Span.init('n') },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Trailing consonant cluster. The trailing 'nh' cluster must remain untouched.
        .{
            .seeds = &.{ Span.init('b'), Span.init('a'), Span.init('n'), Span.init('h') },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Diacritic-bearing vowel with trailing consonant. Cancellation must keep the circumflex.
        .{
            .seeds = &.{ Span.init('t'), Span.init('i'), Span.init_diacritic('e', .circumflex), Span.init('n') },
            .trigger_case = .lower,
            .expected_modification_index = 2,
        },
        // Multi-vowel representative shape. This does not assert OA tone-placement rules.
        .{
            .seeds = &.{ Span.init('h'), Span.init('o'), Span.init('a') },
            .trigger_case = .lower,
            .expected_modification_index = 1,
        },
        // Longer buffer trailing-suffix. Only the last syllable's vowel carries the matching tone,
        // so cancellation lands at index 4 and earlier spans remain exactly as seeded.
        .{
            .seeds = &.{ Span.init('v'), Span.init('a'), Span.init('n'), Span.init('h'), Span.init('o'), Span.init('a') },
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

test "expect State.pseudoword scans and provides a pseudoword correctly" {
    // Arrange. Each case seeds buffer_effective directly, then asks the
    // pseudo-word scanner for word boundaries and toneable vowel indexes. Cases with a leading
    // consonant include multiple consonant characters to verify that the scan includes only the
    // consonant immediately before the vowel run.
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
        .{ .seeds = &.{Span.init('a')}, .word_start = 0, .word_end = 0, .vowels_start = 0, .vowels_end = 0, .length = 1 },
        .{ .seeds = &.{ Span.init('O'), Span.init('A') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .length = 2 },
        .{ .seeds = &.{ Span.init('u'), Span.init('y') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 1, .length = 2 },

        // Multiple consonants before vowels.
        .{ .seeds = &.{ Span.init('t'), Span.init('r'), Span.init('a') }, .word_start = 1, .word_end = 2, .vowels_start = 2, .vowels_end = 2, .length = 2 },
        .{ .seeds = &.{ Span.init('k'), Span.init('h'), Span.init('o'), Span.init('a') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ Span.init('t'), Span.init('h'), Span.init('u'), Span.init('y') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ Span.init('n'), Span.init('g'), Span.init('i'), Span.init('a') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ Span.init('s'), Span.init('q'), Span.init('u'), Span.init('a') }, .word_start = 1, .word_end = 3, .vowels_start = 3, .vowels_end = 3, .length = 3 },

        // Vowels with trailing consonants.
        .{ .seeds = &.{ Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 1, .vowels_start = 0, .vowels_end = 0, .length = 2 },
        .{ .seeds = &.{ Span.init('o'), Span.init('a'), Span.init('n') }, .word_start = 0, .word_end = 2, .vowels_start = 0, .vowels_end = 1, .length = 3 },
        .{ .seeds = &.{ Span.init('u'), Span.init('y'), Span.init('n'), Span.init('h') }, .word_start = 0, .word_end = 3, .vowels_start = 0, .vowels_end = 1, .length = 4 },

        // Multiple consonants before vowels and trailing consonants.
        .{ .seeds = &.{ Span.init('t'), Span.init('r'), Span.init('a'), Span.init('n') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 2, .length = 3 },
        .{ .seeds = &.{ Span.init('k'), Span.init('h'), Span.init('o'), Span.init('a'), Span.init('n') }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('s'), Span.init('q'), Span.init('u'), Span.init('a'), Span.init('n') }, .word_start = 1, .word_end = 4, .vowels_start = 3, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('n'), Span.init('g'), Span.init('i'), Span.init('a'), Span.init('n') }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('t'), Span.init('h'), Span.init('u'), Span.init('y'), Span.init('n'), Span.init('h') }, .word_start = 1, .word_end = 5, .vowels_start = 2, .vowels_end = 3, .length = 5 },

        // The U in leading QU is part of the consonant cluster, not a toneable vowel.
        .{ .seeds = &.{ Span.init('q'), Span.init('u') }, .word_start = 0, .word_end = 1, .vowels_start = null, .vowels_end = null, .length = 2 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('n') }, .word_start = 0, .word_end = 2, .vowels_start = null, .vowels_end = null, .length = 3 },
        .{ .seeds = &.{ Span.init('Q'), Span.init('U'), Span.init('N') }, .word_start = 0, .word_end = 2, .vowels_start = null, .vowels_end = null, .length = 3 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('a'), Span.init('y') }, .word_start = 0, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init_diacritic('o', .horn), Span.init('i') }, .word_start = 0, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('q'), Span.init('u'), Span.init('y'), Span.init_diacritic('e', .circumflex), Span.init('n') }, .word_start = 0, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 5 },

        // Vowels with diacritics are still classified by their base letters.
        .{ .seeds = &.{ Span.init('t'), Span.init('r'), Span.init('u'), Span.init_diacritic('o', .horn), Span.init('p') }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('t'), Span.init('h'), Span.init('i'), Span.init_diacritic('e', .circumflex), Span.init('n') }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('t'), Span.init('r'), Span.init_diacritic('a', .circumflex), Span.init('u') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },
        .{ .seeds = &.{ Span.init('c'), Span.init('h'), Span.init('o'), Span.init_diacritic('a', .breve), Span.init('t') }, .word_start = 1, .word_end = 4, .vowels_start = 2, .vowels_end = 3, .length = 4 },
        .{ .seeds = &.{ Span.init('t'), Span.init('r'), Span.init_diacritic('u', .horn), Span.init('u') }, .word_start = 1, .word_end = 3, .vowels_start = 2, .vowels_end = 3, .length = 3 },

        // Only the trailing pseudo-word is returned.
        .{ .seeds = &.{ Span.init('t'), Span.init('h'), Span.init('e'), Span.init('t'), Span.init('h'), Span.init('u'), Span.init('y') }, .word_start = 4, .word_end = 6, .vowels_start = 5, .vowels_end = 6, .length = 3 },
        .{ .seeds = &.{ Span.init('v'), Span.init('a'), Span.init('n'), Span.init('t'), Span.init('h'), Span.init('o'), Span.init('a') }, .word_start = 4, .word_end = 6, .vowels_start = 5, .vowels_end = 6, .length = 3 },
        .{ .seeds = &.{ Span.init('b'), Span.init('a'), Span.init('o'), Span.init('s'), Span.init('q'), Span.init('u'), Span.init('a'), Span.init('n') }, .word_start = 4, .word_end = 7, .vowels_start = 6, .vowels_end = 6, .length = 4 },
        .{ .seeds = &.{ Span.init('b'), Span.init('o'), Span.init('n'), Span.init('g'), Span.init('i'), Span.init('a'), Span.init('n') }, .word_start = 3, .word_end = 6, .vowels_start = 4, .vowels_end = 5, .length = 4 },

        // No-vowel suffixes return null vowel bounds.
        .{ .seeds = &.{Span.init('b')}, .word_start = 0, .word_end = 0, .vowels_start = null, .vowels_end = null, .length = 1 },
        .{ .seeds = &.{ Span.init('t'), Span.init('r') }, .word_start = 0, .word_end = 1, .vowels_start = null, .vowels_end = null, .length = 2 },
        .{ .seeds = &.{ Span.init('S'), Span.init('T'), Span.init('R') }, .word_start = 0, .word_end = 2, .vowels_start = null, .vowels_end = null, .length = 3 },
        .{ .seeds = &.{ Span.init_diacritic('d', .stroke), Span.init('r') }, .word_start = 0, .word_end = 1, .vowels_start = null, .vowels_end = null, .length = 2 },

        // Full effective buffer boundary.
        .{ .seeds = &.{ Span.init('b'), Span.init('c'), Span.init('d'), Span.init('f'), Span.init('g'), Span.init('h'), Span.init('j'), Span.init('k'), Span.init('l'), Span.init('m'), Span.init('n'), Span.init('p'), Span.init('t'), Span.init('h'), Span.init('u'), Span.init('y') }, .word_start = 13, .word_end = 15, .vowels_start = 14, .vowels_end = 15, .length = 3, .literal_index = 15 },

        // Near effective buffer boundary.
        // 15 characters.
        .{ .seeds = &.{ Span.init('c'), Span.init('d'), Span.init('f'), Span.init('g'), Span.init('h'), Span.init('j'), Span.init('k'), Span.init('l'), Span.init('m'), Span.init('n'), Span.init('p'), Span.init('t'), Span.init('h'), Span.init('u'), Span.init('y') }, .word_start = 12, .word_end = 14, .vowels_start = 13, .vowels_end = 14, .length = 3 },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();
        for (c.seeds, 0..) |s, i| {
            state.buffer_effective[i] = s;
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

test "expect State.backspace reduces buffer_length by 1 and won't touch literal_index" {
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

test "expect State.backspace reduces buffer_length by 1 and unset literal_index" {
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

test "expect State.backspace reduces buffer_length by 1 when literal_index is not set" {
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

test "expect State.calculate_synthetic_backspaces produces correct calculations" {
    const Case = struct {
        live_text: []const u8,
        buffer_length_previous: u8,
        buffer_modification_index: ?u8,
        literal_index: ?u8 = null,
        expected_backspaces: u8,
    };

    const cases = [_]Case{
        .{
            .live_text = "abc",
            .buffer_length_previous = 3,
            .buffer_modification_index = null,
            .expected_backspaces = 0,
        },
        .{
            .live_text = "abcd",
            .buffer_length_previous = 3,
            .buffer_modification_index = null,
            .expected_backspaces = 0,
        },
        .{
            .live_text = "abc",
            .buffer_length_previous = 3,
            .buffer_modification_index = 2,
            .expected_backspaces = 1,
        },
        .{
            .live_text = "abcd",
            .buffer_length_previous = 4,
            .buffer_modification_index = 1,
            .expected_backspaces = 3,
        },
        .{
            .live_text = "abcdefghijklmnop",
            .buffer_length_previous = 16,
            .buffer_modification_index = 14,
            .literal_index = 15,
            .expected_backspaces = 2,
        },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();

        for (c.live_text, 0..) |base, index| {
            state.buffer_effective[index] = Span.init(base);
        }
        state.buffer_length = @intCast(c.live_text.len);
        state.buffer_length_previous = c.buffer_length_previous;
        state.buffer_modification_index = c.buffer_modification_index;
        state.literal_index = c.literal_index;

        try expectEqual(c.expected_backspaces, state.calculate_synthetic_backspaces());
    }
}

test "expect State.calculate_synthetic_backspaces produces correct calculations in length-preserving retroactive edits" {
    const Case = struct {
        input: []const u8,
        expected_buffer_length_previous: u8,
        expected_buffer_length: u8,
        expected_buffer_modification_index: ?u8,
        expected_literal_index: ?u8 = null,
        expected_backspaces: u8,
    };

    const cases = [_]Case{
        .{
            .input = "aa",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 1,
            .expected_buffer_modification_index = 0,
            .expected_backspaces = 1,
        },
        .{
            .input = "aw",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 1,
            .expected_buffer_modification_index = 0,
            .expected_backspaces = 1,
        },
        .{
            .input = "dd",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 1,
            .expected_buffer_modification_index = 0,
            .expected_backspaces = 1,
        },
        .{
            .input = "bans",
            .expected_buffer_length_previous = 3,
            .expected_buffer_length = 3,
            .expected_buffer_modification_index = 1,
            .expected_backspaces = 2,
        },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();

        for (c.input) |input| {
            state.add(input);
        }

        try expectEqual(c.expected_buffer_length_previous, state.buffer_length_previous);
        try expectEqual(c.expected_buffer_length, state.buffer_length);
        try expectEqual(c.expected_buffer_modification_index, state.buffer_modification_index);
        try expectEqual(c.expected_literal_index, state.literal_index);
        try expectEqual(c.expected_backspaces, state.calculate_synthetic_backspaces());
    }
}

test "expect State.calculate_synthetic_backspaces produces correct calculations when modifying and appending in one action" {
    const Case = struct {
        input: []const u8,
        expected_buffer_length_previous: u8,
        expected_buffer_length: u8,
        expected_buffer_modification_index: ?u8,
        expected_literal_index: ?u8,
        expected_backspaces: u8,
    };

    const cases = [_]Case{
        .{
            .input = "aaa",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 2,
            .expected_buffer_modification_index = 0,
            .expected_literal_index = 1,
            .expected_backspaces = 1,
        },
        .{
            .input = "aww",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 2,
            .expected_buffer_modification_index = 0,
            .expected_literal_index = 1,
            .expected_backspaces = 1,
        },
        .{
            .input = "ddd",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 2,
            .expected_buffer_modification_index = 0,
            .expected_literal_index = 1,
            .expected_backspaces = 1,
        },
        .{
            .input = "ass",
            .expected_buffer_length_previous = 1,
            .expected_buffer_length = 2,
            .expected_buffer_modification_index = 0,
            .expected_literal_index = 1,
            .expected_backspaces = 1,
        },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();

        for (c.input) |input| {
            state.add(input);
        }

        try expectEqual(c.expected_buffer_length_previous, state.buffer_length_previous);
        try expectEqual(c.expected_buffer_length, state.buffer_length);
        try expectEqual(c.expected_buffer_modification_index, state.buffer_modification_index);
        try expectEqual(c.expected_literal_index, state.literal_index);
        try expectEqual(c.expected_backspaces, state.calculate_synthetic_backspaces());
    }
}

test "expect State.compose_utf16_string_replacement composes replacement in retrospective modification" {
    // Arrange
    const InputCase = struct {
        input: []const u8,
        expected_buffer_modification_index: u8,
        expected_literal_index: ?u8 = null,
        expected_replacement: []const u16,
    };
    const input_cases = [_]InputCase{
        .{
            .input = "aa",
            .expected_buffer_modification_index = 0,
            .expected_replacement = &.{0x00E2}, // â.
        },
        .{
            .input = "bans",
            .expected_buffer_modification_index = 1,
            .expected_replacement = &.{ 0x00E1, 'n' }, // án.
        },
        .{
            .input = "aaa",
            .expected_buffer_modification_index = 0,
            .expected_literal_index = 1,
            .expected_replacement = &.{ 'a', 'a' },
        },
        .{
            .input = "nuowc",
            .expected_buffer_modification_index = 1,
            .expected_replacement = &.{ 0x01B0, 0x01A1, 'c' }, // ươc.
        },
    };

    for (input_cases) |c| {
        var state: State = undefined;
        state.init();

        for (c.input) |input| {
            state.add(input);
        }

        var replacement_buffer: [buffer_effective_length]u16 = undefined;
        @memset(&replacement_buffer, 0xFFFF);
        var replacement_count: u8 = 0;

        // Act
        state.compose_utf16_string_replacement(&replacement_buffer, &replacement_count);

        // Assert
        try expectEqual(c.expected_buffer_modification_index, state.buffer_modification_index);
        try expectEqual(c.expected_literal_index, state.literal_index);
        try expectEqual(c.expected_replacement.len, replacement_count);
        for (c.expected_replacement, 0..) |expected_character, i| {
            try expectEqual(expected_character, replacement_buffer[i]);
        }
        for (replacement_buffer[replacement_count..]) |replacement_character| {
            try expectEqual(0xFFFF, replacement_character);
        }
    }

    const BoundaryCase = struct {
        first_base: u8,
        first_diacritic: Diacritic,
        second_base: u8,
        second_diacritic: Diacritic,
        expected_buffer_modification_index: u8,
        expected_replacement: []const u16,
    };
    const boundary_cases = [_]BoundaryCase{
        .{
            .first_base = 'u',
            .first_diacritic = .empty,
            .second_base = 'o',
            .second_diacritic = .horn,
            .expected_buffer_modification_index = 13,
            .expected_replacement = &.{ 0x01B0, 0x01A1, 'n' }, // ươn.
        },
        .{
            .first_base = 'u',
            .first_diacritic = .horn,
            .second_base = 'o',
            .second_diacritic = .empty,
            .expected_buffer_modification_index = 14,
            .expected_replacement = &.{ 0x01A1, 'n' }, // ơn.
        },
    };

    for (boundary_cases) |c| {
        var state: State = undefined;
        state.init();

        for (0..13) |i| {
            state.buffer_effective[i] = Span.init('b');
        }
        state.buffer_effective[13] = Span.init_diacritic(c.first_base, c.first_diacritic);
        state.buffer_effective[14] = Span.init_diacritic(c.second_base, c.second_diacritic);
        state.buffer_length = 15;

        var replacement_buffer: [buffer_effective_length]u16 = undefined;
        @memset(&replacement_buffer, 0xFFFF);
        var replacement_count: u8 = 0;

        state.add('n');

        // Act
        state.compose_utf16_string_replacement(&replacement_buffer, &replacement_count);

        // Assert
        try expectEqual(@as(u8, 16), state.buffer_length);
        try expectEqual(c.expected_buffer_modification_index, state.buffer_modification_index);
        try expectEqual(15, state.literal_index);
        try expectEqual(c.expected_replacement.len, replacement_count);
        for (c.expected_replacement, 0..) |expected_character, i| {
            try expectEqual(expected_character, replacement_buffer[i]);
        }
        for (replacement_buffer[replacement_count..]) |replacement_character| {
            try expectEqual(0xFFFF, replacement_character);
        }
    }

    var state: State = undefined;
    state.init();

    for (0..14) |i| {
        state.buffer_effective[i] = Span.init('b');
    }
    state.buffer_effective[14] = Span.init_diacritic('a', .circumflex);
    state.buffer_length = 15;

    var replacement_buffer: [buffer_effective_length]u16 = undefined;
    @memset(&replacement_buffer, 0xFFFF);
    var replacement_count: u8 = 0;

    state.add('a');

    // Act
    state.compose_utf16_string_replacement(&replacement_buffer, &replacement_count);

    // Assert
    try expectEqual(@as(u8, 16), state.buffer_length);
    try expectEqual(14, state.buffer_modification_index);
    try expectEqual(15, state.literal_index);
    try expectEqual(2, replacement_count);
    try expectEqual(@as(u16, 'a'), replacement_buffer[0]);
    try expectEqual(@as(u16, 'a'), replacement_buffer[1]);
    for (replacement_buffer[replacement_count..]) |replacement_character| {
        try expectEqual(0xFFFF, replacement_character);
    }
}

test "expect State.compose_utf16_string_replacement composes replacement when appending literally" {
    // Arrange
    const Case = struct {
        input: []const u8,
        expected_literal_index: ?u8 = null,
        expected_replacement: u16,
    };
    const cases = [_]Case{
        .{
            .input = "a",
            .expected_replacement = 'a',
        },
        .{
            .input = "ab",
            .expected_replacement = 'b',
        },
        .{
            .input = "dz",
            .expected_replacement = 'z',
        },
        .{
            .input = "ngZ",
            .expected_replacement = 'Z',
        },
        .{
            .input = "bbbbbqqqqqbbbbba",
            .expected_literal_index = 15,
            .expected_replacement = 'a',
        },
    };

    for (cases) |c| {
        var state: State = undefined;
        state.init();

        for (c.input) |input| {
            state.add(input);
        }

        var replacement_buffer: [buffer_effective_length]u16 = undefined;
        @memset(&replacement_buffer, 0xFFFF);
        var replacement_count: u8 = 0;

        // Act
        state.compose_utf16_string_replacement(&replacement_buffer, &replacement_count);

        // Assert
        try expectEqual(null, state.buffer_modification_index);
        try expectEqual(c.expected_literal_index, state.literal_index);
        try expectEqual(1, replacement_count);
        try expectEqual(c.expected_replacement, replacement_buffer[0]);
        for (replacement_buffer[replacement_count..]) |replacement_character| {
            try expectEqual(0xFFFF, replacement_character);
        }
    }
}

// Simple ABI wrapper for initializing allocated memory.
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

    // Allocate memory, specified only in this test to simulate runtime allocation.
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
    // Verify every span is exactly the same as the input.
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

export const lex_replacement_buffer_length: usize = buffer_effective_length;

// replacement_buffer capacity must be exactly lex_replacement_buffer_length.
export fn lex_compose_utf16_string_replacement(state: *anyopaque, replacement_buffer: [*]u16, replacement_count: *u8) void {
    // State pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    // Replacement buffer pointer must not be null.
    assert(@intFromPtr(replacement_buffer) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(replacement_buffer) % @alignOf([buffer_effective_length]u16) == 0);

    // Replacement count pointer must not be null.
    assert(@intFromPtr(replacement_count) != 0);

    const s: *State = @ptrCast(@alignCast(state));
    const r_buffer: *[buffer_effective_length]u16 = @ptrCast(@alignCast(replacement_buffer));
    s.compose_utf16_string_replacement(r_buffer, replacement_count);
}

test "expect lex_compose_utf16_string_replacement accepts the provided allocations and writes the result to those allocations" {
    // Arrange

    // Allocate memory, specified only in this test to simulate runtime allocation.
    const raw_pointer = std.testing.allocator.rawAlloc(lex_state_size, .fromByteUnits(lex_state_alignment), @returnAddress()) orelse return error.OutOfMemory;
    defer std.testing.allocator.rawFree(raw_pointer[0..lex_state_size], .fromByteUnits(lex_state_alignment), @returnAddress());

    // Initialize state.
    lex_init(raw_pointer);

    const replacement_buffer = try std.testing.allocator.create([lex_replacement_buffer_length]u16);
    defer std.testing.allocator.destroy(replacement_buffer);
    @memset(replacement_buffer, 0xFFFF);

    var replacement_count: u8 = undefined;

    const input_sequence = "nuowc";
    for (input_sequence) |c| {
        lex_add(raw_pointer, c);
    }

    // Act
    lex_compose_utf16_string_replacement(raw_pointer, replacement_buffer, &replacement_count);

    // Assert
    try expectEqual(3, replacement_count);
    try expectEqual(0x01B0, replacement_buffer[0]);
    try expectEqual(0x01A1, replacement_buffer[1]);
    try expectEqual('c', replacement_buffer[2]);

    for (replacement_buffer[replacement_count..]) |replacement_character| {
        try expectEqual(0xFFFF, replacement_character);
    }
}

// Indicate the buffer_length is at the maximum limit.
export fn lex_buffer_full(state: *anyopaque) bool {
    // State pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    return s.buffer_length == maxInt(@TypeOf(s.buffer_length));
}

// Indicate the buffer_length is zero.
export fn lex_buffer_empty(state: *anyopaque) bool {
    // State pointer must not be null.
    assert(@intFromPtr(state) != 0);
    // Ensure the allocated memory is aligned.
    assert(@intFromPtr(state) % @alignOf(State) == 0);

    const s: *State = @ptrCast(@alignCast(state));
    return s.buffer_length == 0;
}

const FuzzHarness = struct {
    const visible_capacity = 1024;
    const replacement_sentinel = 0xFFFF;
    const Smith = std.testing.Smith;
    const Weight = Smith.Weight;

    // Operation-count limits shared between the fuzz bodies and the corpus encoders. A corpus
    // count above the fuzz body's limit would silently decode to 0 (see encode_draws), so the
    // encoders assert against these same constants.
    const app_flow_operation_count_max = 160;
    const metamorphic_operation_count_max = 80;
    const erase_add_count_min = 1;
    const erase_add_count_max = 24;

    const AppOperation = enum(u8) {
        add,
        backspace,
        reset,
        query,
        add_again,
    };

    const MutatingOperation = enum(u8) {
        add,
        backspace,
        reset,
    };

    const AddBackspaceOperation = enum(u8) {
        add,
        backspace,
    };

    // Keep plans fixed-shape so every fuzzed step consumes an operation draw followed by a
    // character draw. The character is used by add and is intentionally ignored by backspace and
    // reset, which also keeps metamorphic corpus encoding and decoding unconditional.
    const PlannedOperation = struct {
        operation: MutatingOperation,
        character: u8,
    };

    const AddBackspacePlan = struct {
        operation: AddBackspaceOperation,
        character: u8,
    };

    // One step of an app-flow corpus entry. The payload carries the character draw that the
    // app-flow fuzz body performs for add operations only.
    const CorpusAppStep = union(AppOperation) {
        add: u8,
        backspace: void,
        reset: void,
        query: void,
        add_again: u8,
    };

    // Encode Smith draws for corpus mode. When the test binary is not built for fuzzing, every
    // Smith weighted draw consumes exactly 8 bytes little-endian from the corpus entry. A value
    // outside the draw's weight ranges, or a truncated entry, silently falls back to the first
    // weight's minimum, so entries must encode one in-range u64 per draw, in draw order.
    fn encode_draws(comptime draws: []const u64) []const u8 {
        const Encoded = struct {
            const bytes: [draws.len * 8]u8 = build: {
                var buffer: [draws.len * 8]u8 = undefined;
                for (draws, 0..) |draw, index| {
                    std.mem.writeInt(u64, buffer[index * 8 ..][0..8], draw, .little);
                }
                break :build buffer;
            };
        };
        return &Encoded.bytes;
    }

    // Encode one corpus entry for "fuzz public ABI app-flow operation streams", mirroring its
    // draw order: the operation count, then per operation the AppOperation tag and, for add
    // operations only, the character.
    fn encode_app_flow_corpus(comptime steps: []const CorpusAppStep) []const u8 {
        const draws = comptime build: {
            assert(steps.len <= app_flow_operation_count_max);

            var draws: []const u64 = &.{steps.len};
            for (steps) |step| {
                draws = draws ++ &[_]u64{@intFromEnum(step)};
                switch (step) {
                    .add, .add_again => |character| {
                        assert(isAlphabetic(character));
                        draws = draws ++ &[_]u64{character};
                    },
                    .backspace, .reset, .query => {},
                }
            }
            break :build draws;
        };
        return encode_draws(draws);
    }

    // Encode one corpus entry for "fuzz public ABI metamorphic equivalences", mirroring its draw
    // order across the three properties: the query-insertion operations (operation and character
    // are both drawn for every step, the character is a dummy for backspace and reset), the reset
    // prefix and suffix counts then their operations, and finally the erase-property characters.
    fn encode_metamorphic_corpus(
        comptime query_insertion_operations: []const PlannedOperation,
        comptime reset_prefix_operations: []const AddBackspacePlan,
        comptime reset_suffix_operations: []const AddBackspacePlan,
        comptime erase_characters: []const u8,
        comptime erase_final_character: u8,
    ) []const u8 {
        const draws = comptime build: {
            assert(query_insertion_operations.len <= metamorphic_operation_count_max);
            assert(reset_prefix_operations.len <= metamorphic_operation_count_max);
            assert(reset_suffix_operations.len <= metamorphic_operation_count_max);
            assert(erase_characters.len >= erase_add_count_min);
            assert(erase_characters.len <= erase_add_count_max);
            assert(isAlphabetic(erase_final_character));

            var draws: []const u64 = &.{query_insertion_operations.len};
            for (query_insertion_operations) |operation| {
                assert(isAlphabetic(operation.character));
                draws = draws ++ &[_]u64{ @intFromEnum(operation.operation), operation.character };
            }

            draws = draws ++ &[_]u64{ reset_prefix_operations.len, reset_suffix_operations.len };
            for (reset_prefix_operations) |operation| {
                assert(isAlphabetic(operation.character));
                draws = draws ++ &[_]u64{ @intFromEnum(operation.operation), operation.character };
            }
            for (reset_suffix_operations) |operation| {
                assert(isAlphabetic(operation.character));
                draws = draws ++ &[_]u64{ @intFromEnum(operation.operation), operation.character };
            }

            draws = draws ++ &[_]u64{erase_characters.len};
            for (erase_characters) |character| {
                assert(isAlphabetic(character));
                draws = draws ++ &[_]u64{character};
            }
            draws = draws ++ &[_]u64{erase_final_character};

            break :build draws;
        };
        return encode_draws(draws);
    }

    const Engine = struct {
        raw_pointer: [*]u8,
        visible_buffer: [visible_capacity]u16 = undefined,
        visible_length: usize = 0,
        word_start: usize = 0,

        fn init() !Engine {
            const raw_pointer = std.testing.allocator.rawAlloc(lex_state_size, .fromByteUnits(lex_state_alignment), @returnAddress()) orelse return error.OutOfMemory;
            lex_init(raw_pointer);

            var engine = Engine{ .raw_pointer = raw_pointer };
            try engine.expect_reset_state();
            return engine;
        }

        fn deinit(self: *Engine) void {
            std.testing.allocator.rawFree(self.raw_pointer[0..lex_state_size], .fromByteUnits(lex_state_alignment), @returnAddress());
        }

        fn add_app_path(self: *Engine, c: u8) !void {
            if (lex_buffer_full(self.raw_pointer)) {
                try self.reset();
            }

            if (lex_buffer_effective_full(self.raw_pointer)) {
                lex_add(self.raw_pointer, c);
                try self.append_visible(c);
            } else {
                lex_add(self.raw_pointer, c);

                const synthetic_backspaces = lex_calculate_synthetic_backspaces(self.raw_pointer);
                try std.testing.expect(synthetic_backspaces <= self.visible_length - self.word_start);
                self.visible_length -= synthetic_backspaces;

                var replacement_buffer: [lex_replacement_buffer_length]u16 = undefined;
                @memset(&replacement_buffer, replacement_sentinel);
                var replacement_count: u8 = undefined;
                lex_compose_utf16_string_replacement(self.raw_pointer, &replacement_buffer, &replacement_count);

                try std.testing.expect(replacement_count > 0);
                try std.testing.expect(replacement_count <= lex_replacement_buffer_length);

                const replacement_length: usize = replacement_count;
                try expect_allowed_replacement(replacement_buffer[0..replacement_length]);
                try expect_replacement_tail_unchanged(replacement_buffer[replacement_length..]);
                try self.append_visible_slice(replacement_buffer[0..replacement_length]);
            }

            try std.testing.expect(!lex_buffer_empty(self.raw_pointer));
            try self.query_invariants();
        }

        fn backspace(self: *Engine) !void {
            if (!lex_buffer_empty(self.raw_pointer)) {
                try std.testing.expect(self.visible_length > self.word_start);
                lex_backspace(self.raw_pointer);
                self.visible_length -= 1;
                try self.query_invariants();
            }
        }

        fn reset(self: *Engine) !void {
            lex_init(self.raw_pointer);
            self.word_start = self.visible_length;
            try self.expect_reset_state();
        }

        fn apply_mutating(self: *Engine, operation: PlannedOperation) !void {
            switch (operation.operation) {
                .add => try self.add_app_path(operation.character),
                .backspace => try self.backspace(),
                .reset => try self.reset(),
            }
        }

        fn apply_add_backspace(self: *Engine, operation: AddBackspacePlan) !void {
            switch (operation.operation) {
                .add => try self.add_app_path(operation.character),
                .backspace => try self.backspace(),
            }
        }

        fn append_visible(self: *Engine, character: u16) !void {
            try std.testing.expect(self.visible_length < self.visible_buffer.len);
            self.visible_buffer[self.visible_length] = character;
            self.visible_length += 1;
        }

        fn append_visible_slice(self: *Engine, characters: []const u16) !void {
            try std.testing.expect(self.visible_length + characters.len <= self.visible_buffer.len);
            for (characters) |character| {
                self.visible_buffer[self.visible_length] = character;
                self.visible_length += 1;
            }
        }

        fn visible(self: *const Engine) []const u16 {
            return self.visible_buffer[0..self.visible_length];
        }

        fn visible_word(self: *const Engine) []const u16 {
            return self.visible_buffer[self.word_start..self.visible_length];
        }

        fn expect_reset_state(self: *Engine) !void {
            try expectEqual(true, lex_buffer_empty(self.raw_pointer));
            try expectEqual(false, lex_buffer_full(self.raw_pointer));
            try expectEqual(false, lex_buffer_effective_full(self.raw_pointer));
            try self.query_invariants();
        }

        fn query_invariants(self: *Engine) !void {
            const buffer_empty = lex_buffer_empty(self.raw_pointer);
            const buffer_full = lex_buffer_full(self.raw_pointer);
            const buffer_effective_full = lex_buffer_effective_full(self.raw_pointer);

            try expectEqual(buffer_empty, lex_buffer_empty(self.raw_pointer));
            try expectEqual(buffer_full, lex_buffer_full(self.raw_pointer));
            try expectEqual(buffer_effective_full, lex_buffer_effective_full(self.raw_pointer));

            if (buffer_empty) {
                try std.testing.expect(!buffer_full);
                try std.testing.expect(!buffer_effective_full);
            }

            if (buffer_full) {
                try std.testing.expect(buffer_effective_full);
            }
        }
    };

    fn choose_app_operation(smith: *Smith) AppOperation {
        return smith.valueWeighted(AppOperation, &.{
            .value(AppOperation, .add, 64),
            .value(AppOperation, .backspace, 12),
            .value(AppOperation, .reset, 4),
            .value(AppOperation, .query, 2),
            .value(AppOperation, .add_again, 18),
        });
    }

    fn choose_mutating_operation(smith: *Smith) MutatingOperation {
        return smith.valueWeighted(MutatingOperation, &.{
            .value(MutatingOperation, .add, 70),
            .value(MutatingOperation, .backspace, 20),
            .value(MutatingOperation, .reset, 10),
        });
    }

    fn choose_add_backspace_operation(smith: *Smith) AddBackspaceOperation {
        return smith.valueWeighted(AddBackspaceOperation, &.{
            .value(AddBackspaceOperation, .add, 75),
            .value(AddBackspaceOperation, .backspace, 25),
        });
    }

    fn choose_character(smith: *Smith) u8 {
        return smith.valueWeighted(u8, &.{
            .value(u8, 'A', 8),
            .value(u8, 'a', 8),
            .value(u8, 'E', 8),
            .value(u8, 'e', 8),
            .value(u8, 'O', 8),
            .value(u8, 'o', 8),
            .value(u8, 'U', 8),
            .value(u8, 'u', 8),
            .value(u8, 'I', 6),
            .value(u8, 'i', 6),
            .value(u8, 'Y', 6),
            .value(u8, 'y', 6),
            .value(u8, 'D', 8),
            .value(u8, 'd', 8),
            .value(u8, 'W', 10),
            .value(u8, 'w', 10),
            .value(u8, 'S', 8),
            .value(u8, 's', 8),
            .value(u8, 'F', 8),
            .value(u8, 'f', 8),
            .value(u8, 'R', 8),
            .value(u8, 'r', 8),
            .value(u8, 'X', 8),
            .value(u8, 'x', 8),
            .value(u8, 'J', 8),
            .value(u8, 'j', 8),
            .value(u8, 'Z', 8),
            .value(u8, 'z', 8),
            .value(u8, 'G', 5),
            .value(u8, 'g', 5),
            .value(u8, 'Q', 5),
            .value(u8, 'q', 5),
            .value(u8, 'C', 5),
            .value(u8, 'c', 5),
            .value(u8, 'M', 5),
            .value(u8, 'm', 5),
            .value(u8, 'N', 5),
            .value(u8, 'n', 5),
            .value(u8, 'P', 5),
            .value(u8, 'p', 5),
            .value(u8, 'T', 5),
            .value(u8, 't', 5),
            .rangeAtMost(u8, 'A', 'Z', 1),
            .rangeAtMost(u8, 'a', 'z', 1),
        });
    }

    fn expect_allowed_replacement(characters: []const u16) !void {
        for (characters) |character| {
            try std.testing.expect(is_allowed_replacement_character(character));
        }
    }

    fn expect_replacement_tail_unchanged(characters: []const u16) !void {
        for (characters) |character| {
            try expectEqual(@as(u16, replacement_sentinel), character);
        }
    }

    fn is_allowed_replacement_character(character: u16) bool {
        if ((character >= 'A' and character <= 'Z') or (character >= 'a' and character <= 'z')) {
            return true;
        }

        return switch (character) {
            0x00C0,
            0x00C1,
            0x00C2,
            0x00C3,
            0x00C8,
            0x00C9,
            0x00CA,
            0x00CC,
            0x00CD,
            0x00D2,
            0x00D3,
            0x00D4,
            0x00D5,
            0x00D9,
            0x00DA,
            0x00DD,
            0x00E0,
            0x00E1,
            0x00E2,
            0x00E3,
            0x00E8,
            0x00E9,
            0x00EA,
            0x00EC,
            0x00ED,
            0x00F2,
            0x00F3,
            0x00F4,
            0x00F5,
            0x00F9,
            0x00FA,
            0x00FD,
            0x0102,
            0x0103,
            0x0110,
            0x0111,
            0x0128,
            0x0129,
            0x0168,
            0x0169,
            0x01A0,
            0x01A1,
            0x01AF,
            0x01B0,
            0x1EA0,
            0x1EA1,
            0x1EA2,
            0x1EA3,
            0x1EA4,
            0x1EA5,
            0x1EA6,
            0x1EA7,
            0x1EA8,
            0x1EA9,
            0x1EAA,
            0x1EAB,
            0x1EAC,
            0x1EAD,
            0x1EAE,
            0x1EAF,
            0x1EB0,
            0x1EB1,
            0x1EB2,
            0x1EB3,
            0x1EB4,
            0x1EB5,
            0x1EB6,
            0x1EB7,
            0x1EB8,
            0x1EB9,
            0x1EBA,
            0x1EBB,
            0x1EBC,
            0x1EBD,
            0x1EBE,
            0x1EBF,
            0x1EC0,
            0x1EC1,
            0x1EC2,
            0x1EC3,
            0x1EC4,
            0x1EC5,
            0x1EC6,
            0x1EC7,
            0x1EC8,
            0x1EC9,
            0x1ECA,
            0x1ECB,
            0x1ECC,
            0x1ECD,
            0x1ECE,
            0x1ECF,
            0x1ED0,
            0x1ED1,
            0x1ED2,
            0x1ED3,
            0x1ED4,
            0x1ED5,
            0x1ED6,
            0x1ED7,
            0x1ED8,
            0x1ED9,
            0x1EDA,
            0x1EDB,
            0x1EDC,
            0x1EDD,
            0x1EDE,
            0x1EDF,
            0x1EE0,
            0x1EE1,
            0x1EE2,
            0x1EE3,
            0x1EE4,
            0x1EE5,
            0x1EE6,
            0x1EE7,
            0x1EE8,
            0x1EE9,
            0x1EEA,
            0x1EEB,
            0x1EEC,
            0x1EED,
            0x1EEE,
            0x1EEF,
            0x1EF0,
            0x1EF1,
            0x1EF2,
            0x1EF3,
            0x1EF4,
            0x1EF5,
            0x1EF6,
            0x1EF7,
            0x1EF8,
            0x1EF9,
            => true,
            else => false,
        };
    }
};

test "expect public ABI does not apply tone to 'QU' before trailing consonant" {
    var engine = try FuzzHarness.Engine.init();
    defer engine.deinit();

    // Regression for a fuzz-found crash: the old behavior toned U in `qun` on `f`; after
    // backspace exposed `qù`, the next tone trigger tried to retone exact `QU`.
    try engine.add_app_path('q');
    try engine.add_app_path('u');
    try engine.add_app_path('n');
    try engine.add_app_path('f');
    try engine.backspace();
    try engine.add_app_path('s');

    try std.testing.expectEqualSlices(u16, &.{ 'q', 'u', 'n', 's' }, engine.visible());
}

test "fuzz public ABI app-flow operation streams" {
    const Harness = struct {
        fn fuzz_one(_: void, smith: *std.testing.Smith) !void {
            var engine = try FuzzHarness.Engine.init();
            defer engine.deinit();

            const operation_count = smith.valueRangeAtMost(u8, 0, FuzzHarness.app_flow_operation_count_max);
            for (0..operation_count) |_| {
                const operation = FuzzHarness.choose_app_operation(smith);
                switch (operation) {
                    .add, .add_again => try engine.add_app_path(FuzzHarness.choose_character(smith)),
                    .backspace => try engine.backspace(),
                    .reset => try engine.reset(),
                    .query => try engine.query_invariants(),
                }
            }
        }
    };

    const corpus = [_][]const u8{
        // Empty smoke.
        FuzzHarness.encode_app_flow_corpus(&.{}),
        // Literal 'f' at word start.
        FuzzHarness.encode_app_flow_corpus(&.{.{ .add = 'f' }}),
        // Literal 'j' at word start.
        FuzzHarness.encode_app_flow_corpus(&.{.{ .add = 'j' }}),
        // Literal 'w' at word start.
        FuzzHarness.encode_app_flow_corpus(&.{.{ .add = 'w' }}),
        // Literal 'z' at word start.
        FuzzHarness.encode_app_flow_corpus(&.{.{ .add = 'z' }}),
        // Circumflex apply: 'aa' -> 'â'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .{ .add = 'a' } }),
        // Breve apply: 'aw' -> 'ă'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .{ .add = 'w' } }),
        // Horn apply: 'ow' -> 'ơ'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'o' }, .{ .add = 'w' } }),
        // Stroke apply: 'dd' -> 'đ'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'd' }, .{ .add = 'd' } }),
        // Circumflex cancel and literal tail: 'aaa' -> 'aaa'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .{ .add = 'a' }, .{ .add = 'a' } }),
        // Autofill family: 'nuowc' -> 'nươc'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'n' }, .{ .add = 'u' }, .{ .add = 'o' }, .{ .add = 'w' }, .{ .add = 'c' } }),
        // QU tone exception family, the fuzz-found crash sequence: 'qunf', backspace, 's'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'q' }, .{ .add = 'u' }, .{ .add = 'n' }, .{ .add = 'f' }, .backspace, .{ .add = 's' } }),
        // GI tone placement family: 'gias' -> 'giá'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'g' }, .{ .add = 'i' }, .{ .add = 'a' }, .{ .add = 's' } }),
        // OA tone placement family: 'oas' -> 'óa'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'o' }, .{ .add = 'a' }, .{ .add = 's' } }),
        // Reset before suffix: 'af' -> 'à', new word, 'as' -> 'á'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .{ .add = 'f' }, .reset, .{ .add = 'a' }, .{ .add = 's' } }),
        // Backspace past the literal point resumes Vietnamese input: 'aaa' -> 'aa' literal tail,
        // erase back to empty, then 'aa' -> 'â' again.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .{ .add = 'a' }, .{ .add = 'a' }, .backspace, .backspace, .{ .add = 'a' }, .{ .add = 'a' } }),
        // Query and add_again coverage: 'a', query invariants, 'a' again -> 'â'.
        FuzzHarness.encode_app_flow_corpus(&.{ .{ .add = 'a' }, .query, .{ .add_again = 'a' } }),
    };

    try std.testing.fuzz({}, Harness.fuzz_one, .{ .corpus = &corpus });
}

test "fuzz public ABI full-buffer boundaries" {
    const Harness = struct {
        fn fuzz_one(_: void, smith: *std.testing.Smith) !void {
            var engine = try FuzzHarness.Engine.init();
            defer engine.deinit();

            var header: [1]u8 = undefined;
            smith.bytes(&header);
            const target_count: usize = header[0];

            for (0..target_count) |i| {
                try engine.add_app_path('B');
                const count = i + 1;

                if (count == 15) {
                    try expectEqual(false, lex_buffer_effective_full(engine.raw_pointer));
                    try expectEqual(false, lex_buffer_full(engine.raw_pointer));
                } else if (count == 16) {
                    try expectEqual(true, lex_buffer_effective_full(engine.raw_pointer));
                    try expectEqual(false, lex_buffer_full(engine.raw_pointer));
                } else if (count == maxInt(u8)) {
                    try expectEqual(true, lex_buffer_effective_full(engine.raw_pointer));
                    try expectEqual(true, lex_buffer_full(engine.raw_pointer));
                    try engine.reset();
                }
            }
        }
    };

    const corpus = [_][]const u8{
        &.{0},
        &.{15},
        &.{16},
        &.{17},
        &.{254},
        &.{255},
    };

    try std.testing.fuzz({}, Harness.fuzz_one, .{ .corpus = &corpus });
}

test "fuzz public ABI metamorphic equivalences" {
    const Harness = struct {
        const max_operation_count = FuzzHarness.metamorphic_operation_count_max;

        fn fuzz_one(_: void, smith: *std.testing.Smith) !void {
            try query_insertion_equivalence(smith);
            try reset_suffix_equivalence(smith);
            try backspace_to_empty_equivalence(smith);
        }

        fn query_insertion_equivalence(smith: *std.testing.Smith) !void {
            var operations: [max_operation_count]FuzzHarness.PlannedOperation = undefined;
            const operation_count = smith.valueRangeAtMost(u8, 0, max_operation_count);
            for (operations[0..operation_count]) |*operation| {
                operation.* = .{
                    .operation = FuzzHarness.choose_mutating_operation(smith),
                    .character = FuzzHarness.choose_character(smith),
                };
            }

            var normal = try FuzzHarness.Engine.init();
            defer normal.deinit();
            var queried = try FuzzHarness.Engine.init();
            defer queried.deinit();

            for (operations[0..operation_count]) |operation| {
                try normal.apply_mutating(operation);

                try queried.query_invariants();
                try queried.apply_mutating(operation);
                try queried.query_invariants();
            }

            try std.testing.expectEqualSlices(u16, normal.visible(), queried.visible());
        }

        fn reset_suffix_equivalence(smith: *std.testing.Smith) !void {
            var prefix: [max_operation_count]FuzzHarness.AddBackspacePlan = undefined;
            var suffix: [max_operation_count]FuzzHarness.AddBackspacePlan = undefined;
            const prefix_count = smith.valueRangeAtMost(u8, 0, max_operation_count);
            const suffix_count = smith.valueRangeAtMost(u8, 0, max_operation_count);

            for (prefix[0..prefix_count]) |*operation| {
                operation.* = .{
                    .operation = FuzzHarness.choose_add_backspace_operation(smith),
                    .character = FuzzHarness.choose_character(smith),
                };
            }
            for (suffix[0..suffix_count]) |*operation| {
                operation.* = .{
                    .operation = FuzzHarness.choose_add_backspace_operation(smith),
                    .character = FuzzHarness.choose_character(smith),
                };
            }

            var prefixed = try FuzzHarness.Engine.init();
            defer prefixed.deinit();
            var fresh = try FuzzHarness.Engine.init();
            defer fresh.deinit();

            for (prefix[0..prefix_count]) |operation| {
                try prefixed.apply_add_backspace(operation);
            }
            try prefixed.reset();

            for (suffix[0..suffix_count]) |operation| {
                try prefixed.apply_add_backspace(operation);
                try fresh.apply_add_backspace(operation);
            }

            try std.testing.expectEqualSlices(u16, prefixed.visible_word(), fresh.visible());
        }

        fn backspace_to_empty_equivalence(smith: *std.testing.Smith) !void {
            var erased = try FuzzHarness.Engine.init();
            defer erased.deinit();
            var fresh = try FuzzHarness.Engine.init();
            defer fresh.deinit();

            const add_count = smith.valueRangeAtMost(u8, FuzzHarness.erase_add_count_min, FuzzHarness.erase_add_count_max);
            for (0..add_count) |_| {
                try erased.add_app_path(FuzzHarness.choose_character(smith));
            }
            while (!lex_buffer_empty(erased.raw_pointer)) {
                try erased.backspace();
            }

            const c = FuzzHarness.choose_character(smith);
            try erased.add_app_path(c);
            try fresh.add_app_path(c);

            try std.testing.expectEqualSlices(u16, erased.visible(), fresh.visible());
        }
    };

    const corpus = [_][]const u8{
        // Minimal smoke: no mutating operations, erase a single 'a'.
        FuzzHarness.encode_metamorphic_corpus(&.{}, &.{}, &.{}, "a", 'a'),
        // Circumflex and backspace family.
        FuzzHarness.encode_metamorphic_corpus(
            &.{
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .backspace, .character = 'a' },
            },
            &.{
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .add, .character = 'a' },
            },
            &.{
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .add, .character = 's' },
            },
            "aa",
            'b',
        ),
        // Autofill family: 'nuowc' -> 'nươc'.
        FuzzHarness.encode_metamorphic_corpus(
            &.{
                .{ .operation = .add, .character = 'n' },
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'o' },
                .{ .operation = .add, .character = 'w' },
                .{ .operation = .add, .character = 'c' },
            },
            &.{
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'w' },
            },
            &.{
                .{ .operation = .add, .character = 'n' },
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'o' },
                .{ .operation = .add, .character = 'w' },
                .{ .operation = .add, .character = 'c' },
            },
            "nuowc",
            'w',
        ),
        // QU tone exception family with the fuzz-found crash sequence and a reset in the
        // mutating stream.
        FuzzHarness.encode_metamorphic_corpus(
            &.{
                .{ .operation = .add, .character = 'q' },
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'n' },
                .{ .operation = .add, .character = 'f' },
                .{ .operation = .backspace, .character = 'a' },
                .{ .operation = .add, .character = 's' },
                .{ .operation = .reset, .character = 'a' },
                .{ .operation = .add, .character = 'q' },
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .add, .character = 'f' },
            },
            &.{
                .{ .operation = .add, .character = 'q' },
                .{ .operation = .add, .character = 'u' },
            },
            &.{
                .{ .operation = .add, .character = 'q' },
                .{ .operation = .add, .character = 'u' },
                .{ .operation = .add, .character = 'a' },
                .{ .operation = .add, .character = 'f' },
            },
            "qunf",
            'q',
        ),
    };

    try std.testing.fuzz({}, Harness.fuzz_one, .{ .corpus = &corpus });
}
