// liblex.zig — Vietnamese Telex input engine (prototype)
// Span-based composition engine. No diff/backspace logic — Swift handles diffing.

const std = @import("std");

// ── Data Structures ──────────────────────────────────────────────────

pub const Span = extern struct {
    base: u8, // ASCII base letter (a-z, A-Z)
    modifier: u8, // 0=none, 'w'=ư/ơ/ă, 'd'=đ, 'a'=â, 'e'=ê, 'o'=ô
    tone: u8, // 0=none, 's'=sắc, 'f'=huyền, 'r'=hỏi, 'x'=ngã, 'j'=nặng
    flags: u8, // bit 0: is_uppercase, bit 1: is_literal
};

pub const State = extern struct {
    spans: [24]Span,
    len: u8,
    mode: u8, // 0=NORMAL, 1=LITERAL
    _pad: [2]u8 = .{ 0, 0 },
};

// ── Unicode Lookup Tables ────────────────────────────────────────────

// Tone indices: 0=none, 1=s(sắc), 2=f(huyền), 3=r(hỏi), 4=x(ngã), 5=j(nặng)

// Lowercase: [no_tone, s, f, r, x, j]
const lut_a = [6]u16{ 0x0061, 0x00E1, 0x00E0, 0x1EA3, 0x00E3, 0x1EA1 };
const lut_aw = [6]u16{ 0x0103, 0x1EAF, 0x1EB1, 0x1EB3, 0x1EB5, 0x1EB7 }; // ă
const lut_aa = [6]u16{ 0x00E2, 0x1EA5, 0x1EA7, 0x1EA9, 0x1EAB, 0x1EAD }; // â
const lut_e = [6]u16{ 0x0065, 0x00E9, 0x00E8, 0x1EBB, 0x1EBD, 0x1EB9 };
const lut_ee = [6]u16{ 0x00EA, 0x1EBF, 0x1EC1, 0x1EC3, 0x1EC5, 0x1EC7 }; // ê
const lut_i = [6]u16{ 0x0069, 0x00ED, 0x00EC, 0x1EC9, 0x0129, 0x1ECB };
const lut_o = [6]u16{ 0x006F, 0x00F3, 0x00F2, 0x1ECF, 0x00F5, 0x1ECD };
const lut_oo = [6]u16{ 0x00F4, 0x1ED1, 0x1ED3, 0x1ED5, 0x1ED7, 0x1ED9 }; // ô
const lut_ow = [6]u16{ 0x01A1, 0x1EDB, 0x1EDD, 0x1EDF, 0x1EE1, 0x1EE3 }; // ơ
const lut_u = [6]u16{ 0x0075, 0x00FA, 0x00F9, 0x1EE7, 0x0169, 0x1EE5 };
const lut_uw = [6]u16{ 0x01B0, 0x1EE9, 0x1EEB, 0x1EED, 0x1EEF, 0x1EF1 }; // ư
const lut_y = [6]u16{ 0x0079, 0x00FD, 0x1EF3, 0x1EF7, 0x1EF9, 0x1EF5 };

// Uppercase
const lut_A = [6]u16{ 0x0041, 0x00C1, 0x00C0, 0x1EA2, 0x00C3, 0x1EA0 };
const lut_Aw = [6]u16{ 0x0102, 0x1EAE, 0x1EB0, 0x1EB2, 0x1EB4, 0x1EB6 };
const lut_Aa = [6]u16{ 0x00C2, 0x1EA4, 0x1EA6, 0x1EA8, 0x1EAA, 0x1EAC };
const lut_E = [6]u16{ 0x0045, 0x00C9, 0x00C8, 0x1EBA, 0x1EBC, 0x1EB8 };
const lut_Ee = [6]u16{ 0x00CA, 0x1EBE, 0x1EC0, 0x1EC2, 0x1EC4, 0x1EC6 };
const lut_I = [6]u16{ 0x0049, 0x00CD, 0x00CC, 0x1EC8, 0x0128, 0x1ECA };
const lut_O = [6]u16{ 0x004F, 0x00D3, 0x00D2, 0x1ECE, 0x00D5, 0x1ECC };
const lut_Oo = [6]u16{ 0x00D4, 0x1ED0, 0x1ED2, 0x1ED4, 0x1ED6, 0x1ED8 };
const lut_Ow = [6]u16{ 0x01A0, 0x1EDA, 0x1EDC, 0x1EDE, 0x1EE0, 0x1EE2 };
const lut_U = [6]u16{ 0x0055, 0x00DA, 0x00D9, 0x1EE6, 0x0168, 0x1EE4 };
const lut_Uw = [6]u16{ 0x01AF, 0x1EE8, 0x1EEA, 0x1EEC, 0x1EEE, 0x1EF0 };
const lut_Y = [6]u16{ 0x0059, 0x00DD, 0x1EF2, 0x1EF6, 0x1EF8, 0x1EF4 };

// ── Helpers ──────────────────────────────────────────────────────────

fn toLower(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c | 0x20;
    return c;
}

fn isVowel(c: u8) bool {
    return switch (toLower(c)) {
        'a', 'e', 'i', 'o', 'u', 'y' => true,
        else => false,
    };
}

fn isAlpha(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
}

fn toneIndex(t: u8) u8 {
    return switch (t) {
        0 => 0,
        's' => 1,
        'f' => 2,
        'r' => 3,
        'x' => 4,
        'j' => 5,
        else => 0,
    };
}

fn spanIsVowel(sp: Span) bool {
    return isVowel(sp.base);
}

fn spanIsOnsetBound(s: *State, idx: usize) bool {
    // Check if this vowel is onset-bound (i in gi, u in qu followed by another vowel)
    if (idx == 0) return false;
    const lo = toLower(s.spans[idx].base);
    const prev_lo = toLower(s.spans[idx - 1].base);

    // Must be a vowel to be onset-bound
    if (!isVowel(lo)) return false;

    // Check if there's a vowel after this one in the word
    var has_vowel_after = false;
    var k = idx + 1;
    while (k < s.len) : (k += 1) {
        if (spanIsVowel(s.spans[k])) {
            has_vowel_after = true;
            break;
        }
    }
    if (!has_vowel_after) return false;

    // gi: i after g is onset-bound
    if (lo == 'i' and prev_lo == 'g' and idx == 1) return true;
    // qu: u after q is onset-bound
    if (lo == 'u' and prev_lo == 'q' and idx == 1) return true;

    return false;
}

fn hasModifiedVowel(sp: Span) bool {
    return spanIsVowel(sp) and sp.modifier != 0;
}

// Region computation
const Regions = struct {
    nucleus_start: u8, // index of first nucleus vowel
    nucleus_end: u8, // index of last nucleus vowel (inclusive)
    coda_start: u8, // index of first coda consonant (== len if no coda)
    has_nucleus: bool,
};

fn computeRegions(s: *State) Regions {
    var r = Regions{
        .nucleus_start = s.len,
        .nucleus_end = 0,
        .coda_start = s.len,
        .has_nucleus = false,
    };

    // Find nucleus vowels (vowels that are not onset-bound)
    var i: u8 = 0;
    while (i < s.len) : (i += 1) {
        if (spanIsVowel(s.spans[i]) and !spanIsOnsetBound(s, i)) {
            if (!r.has_nucleus) {
                r.nucleus_start = i;
                r.has_nucleus = true;
            }
            r.nucleus_end = i;
        }
    }

    // Coda: consonants after last nucleus vowel
    if (r.has_nucleus) {
        r.coda_start = r.nucleus_end + 1;
        // Verify coda has consonants
        var found_coda = false;
        var k = r.coda_start;
        while (k < s.len) : (k += 1) {
            if (!spanIsVowel(s.spans[k])) {
                found_coda = true;
                break;
            }
        }
        if (!found_coda) {
            // Check for semi-vowel coda: trailing i/y/u/o in a multi-vowel nucleus
            const nv = nucleusVowelCount(s, r);
            if (nv >= 2) {
                const last_lo = toLower(s.spans[r.nucleus_end].base);
                if (last_lo == 'i' or last_lo == 'y' or last_lo == 'u' or last_lo == 'o') {
                    r.coda_start = r.nucleus_end;
                    r.nucleus_end -= 1;
                }
            }
            if (r.coda_start >= s.len) {
                r.coda_start = s.len;
            }
        }
    }

    return r;
}

fn nucleusVowelCount(s: *State, r: Regions) u8 {
    if (!r.has_nucleus) return 0;
    var count: u8 = 0;
    var i = r.nucleus_start;
    while (i <= r.nucleus_end) : (i += 1) {
        if (spanIsVowel(s.spans[i])) count += 1;
    }
    return count;
}

// Find the span index where a tone mark should be placed
fn findToneTarget(s: *State) ?u8 {
    const r = computeRegions(s);
    if (!r.has_nucleus) return null;

    // Rule 1: If a modified vowel exists, tone goes on the last one
    {
        var last_modified: ?u8 = null;
        var i = r.nucleus_start;
        while (i <= r.nucleus_end) : (i += 1) {
            if (hasModifiedVowel(s.spans[i])) {
                last_modified = i;
            }
        }
        if (last_modified) |idx| return idx;
    }

    const nv = nucleusVowelCount(s, r);
    const has_coda = r.coda_start < s.len;

    // Rule 4: Single vowel → tone on that vowel
    if (nv == 1) return r.nucleus_start;

    // Rule 2: No modified vowel, no coda → tone on 1st nucleus vowel
    if (!has_coda) return r.nucleus_start;

    // Rule 3: No modified vowel, has coda → tone on 2nd nucleus vowel (if exists)
    if (nv >= 2) {
        var count: u8 = 0;
        var i = r.nucleus_start;
        while (i <= r.nucleus_end) : (i += 1) {
            if (spanIsVowel(s.spans[i])) {
                count += 1;
                if (count == 2) return i;
            }
        }
    }

    return r.nucleus_start;
}

// Apply tone to correct vowel, clearing any existing tone on other vowels
fn applyTone(s: *State, tone: u8) void {
    const target = findToneTarget(s) orelse return;

    // Clear tone from all nucleus vowels
    var i: u8 = 0;
    while (i < s.len) : (i += 1) {
        if (spanIsVowel(s.spans[i])) {
            s.spans[i].tone = 0;
        }
    }

    // Set tone on target
    s.spans[target].tone = tone;
}

// Check if any nucleus vowel currently has a tone
fn currentTone(s: *State) u8 {
    var i: u8 = 0;
    while (i < s.len) : (i += 1) {
        if (spanIsVowel(s.spans[i]) and s.spans[i].tone != 0) {
            return s.spans[i].tone;
        }
    }
    return 0;
}

// ươ auto-fill: if coda added and nucleus has uo/uô, auto-fill w modifier
fn autoFillUO(s: *State) void {
    const r = computeRegions(s);
    if (!r.has_nucleus) return;
    if (r.coda_start >= s.len) return; // no coda

    // Look for u and o adjacent in nucleus
    var i = r.nucleus_start;
    while (i < r.nucleus_end) : (i += 1) {
        const cur_lo = toLower(s.spans[i].base);
        const next_lo = toLower(s.spans[i + 1].base);

        if (cur_lo == 'u' and next_lo == 'o') {
            // If one has 'w' modifier and the other doesn't, auto-fill
            const u_has_w = s.spans[i].modifier == 'w';
            const o_has_w = s.spans[i + 1].modifier == 'w';
            // Also check for ô (modifier 'o')
            const o_has_hat = s.spans[i + 1].modifier == 'o';

            if (u_has_w and !o_has_w and !o_has_hat) {
                s.spans[i + 1].modifier = 'w';
            } else if (o_has_w and !u_has_w) {
                s.spans[i].modifier = 'w';
            } else if (o_has_hat and !u_has_w) {
                // uô → ươ: set w on u, keep ô as is... actually ươ
                // If o has hat (ô), and we want ươ, we need w on both? No.
                // Actually: ươ = u+w, o+w. The hat form uô is separate.
                // Only auto-fill when modifier is 'w'.
            }
        }
    }
}

fn enterLiteral(s: *State) void {
    s.mode = 1;
    // Mark all existing spans as literal
    var i: u8 = 0;
    while (i < s.len) : (i += 1) {
        s.spans[i].modifier = 0;
        s.spans[i].tone = 0;
        s.spans[i].flags |= 0x02; // is_literal
    }
}

fn overflowReset(s: *State) u8 {
    s.* = std.mem.zeroes(State);
    s.mode = 1;
    return 0;
}

fn appendSpan(s: *State, base: u8, modifier: u8, tone: u8, flags: u8) bool {
    if (s.len >= s.spans.len) return false;
    s.spans[s.len] = Span{
        .base = base,
        .modifier = modifier,
        .tone = tone,
        .flags = flags,
    };
    s.len += 1;
    return true;
}

fn lookupCodepoint(base_char: u8, modifier: u8, tone: u8) u16 {
    const ti = toneIndex(tone);
    const lo = toLower(base_char);
    const is_upper = base_char >= 'A' and base_char <= 'Z';

    // đ/Đ special case
    if (lo == 'd' and modifier == 'd') {
        return if (is_upper) 0x0110 else 0x0111;
    }

    // Non-vowels: just return ASCII
    if (!isVowel(lo)) return @intCast(base_char);

    const table: *const [6]u16 = switch (lo) {
        'a' => switch (modifier) {
            'w' => if (is_upper) &lut_Aw else &lut_aw,
            'a' => if (is_upper) &lut_Aa else &lut_aa,
            else => if (is_upper) &lut_A else &lut_a,
        },
        'e' => switch (modifier) {
            'e' => if (is_upper) &lut_Ee else &lut_ee,
            else => if (is_upper) &lut_E else &lut_e,
        },
        'i' => if (is_upper) &lut_I else &lut_i,
        'o' => switch (modifier) {
            'o' => if (is_upper) &lut_Oo else &lut_oo,
            'w' => if (is_upper) &lut_Ow else &lut_ow,
            else => if (is_upper) &lut_O else &lut_o,
        },
        'u' => switch (modifier) {
            'w' => if (is_upper) &lut_Uw else &lut_uw,
            else => if (is_upper) &lut_U else &lut_u,
        },
        'y' => if (is_upper) &lut_Y else &lut_y,
        else => if (is_upper) &lut_A else &lut_a, // unreachable for vowels
    };

    return table[ti];
}

// ── Exported API ─────────────────────────────────────────────────────

export fn state_size() usize {
    return @sizeOf(State);
}

export fn init_state(state: *anyopaque) void {
    const s: *State = @ptrCast(@alignCast(state));
    s.* = std.mem.zeroes(State);
}

export fn reset(state: *anyopaque) void {
    const s: *State = @ptrCast(@alignCast(state));
    s.* = std.mem.zeroes(State);
}

export fn backspace(state: *anyopaque) u8 {
    const s: *State = @ptrCast(@alignCast(state));
    if (s.len == 0) return 0;
    s.len -= 1;
    // Clear the removed span
    s.spans[s.len] = std.mem.zeroes(Span);
    // If all spans removed, reset mode
    if (s.len == 0) s.mode = 0;
    return 1;
}

export fn add(state: *anyopaque, char_code: u16) u8 {
    const s: *State = @ptrCast(@alignCast(state));

    // Only handle ASCII range
    if (char_code > 127) {
        reset(state);
        return 0;
    }
    const ch: u8 = @intCast(char_code);

    // Non-alphanumeric → reset and passthrough
    if (!isAlpha(ch)) {
        reset(state);
        return 0;
    }

    const lo = toLower(ch);
    const is_upper = ch >= 'A' and ch <= 'Z';
    const flags: u8 = if (is_upper) 0x01 else 0x00;

    // ── LITERAL mode: just append ──
    if (s.mode == 1) {
        if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
        return 1;
    }

    // ── Check if first char triggers LITERAL mode ──
    if (s.len == 0) {
        if (lo == 'f' or lo == 'j' or lo == 'w' or lo == 'z') {
            enterLiteral(s);
            if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
            return 1;
        }
        // First char: just append as a regular span
        if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
        return 1;
    }

    // ── dd → đ ──
    if (lo == 'd') {
        // Look for last 'd' span without modifier
        if (s.len > 0) {
            const last_idx = s.len - 1;
            const last = &s.spans[last_idx];
            if (toLower(last.base) == 'd' and last.modifier == 0) {
                // Cancellation: if already đ, undo
                if (last.modifier == 'd') {
                    // Already handled above: modifier is 0 here
                    unreachable;
                }
                last.modifier = 'd';
                return 1;
            }
        }
        // Regular d consonant
        if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
        autoFillUO(s);
        return 1;
    }

    // ── Doubled vowel modifier: aa→â, ee→ê, oo→ô ──
    if (lo == 'a' or lo == 'e' or lo == 'o') {
        if (s.len > 0) {
            const last_idx = s.len - 1;
            const last = &s.spans[last_idx];
            if (toLower(last.base) == lo and spanIsVowel(last.*)) {
                if (last.modifier == lo) {
                    // Cancellation: modifier already applied → strip it, append plain vowel
                    last.modifier = 0;
                    last.tone = 0;
                    if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
                    return 1;
                }
                if (last.modifier == 0) {
                    last.modifier = lo;
                    return 1;
                }
            }
        }
    }

    // ── w modifier ──
    if (lo == 'w') {
        // Look for target vowel: last a/o/u in the word
        var target: ?u8 = null;
        var i: u8 = 0;
        while (i < s.len) : (i += 1) {
            const b = toLower(s.spans[i].base);
            if (b == 'a' or b == 'o' or b == 'u') {
                target = i;
            }
        }
        if (target) |ti| {
            const sp = &s.spans[ti];
            if (sp.modifier == 'w') {
                // Cancellation: same modifier pressed again → enter literal
                enterLiteral(s);
                if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
                return 1;
            }
            if (sp.modifier != 0) {
                // Already has a different modifier, can't apply w
                // Treat w as a regular character → literal
                enterLiteral(s);
                if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
                return 1;
            }
            sp.modifier = 'w';
            autoFillUO(s);
            // Re-apply tone placement since modified vowel changed
            const ct = currentTone(s);
            if (ct != 0) applyTone(s, ct);
            return 1;
        }
        // No target vowel: if at start or no vowels, enter literal
        enterLiteral(s);
        if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
        return 1;
    }

    // ── Tone marks: s, f, r, x, j ──
    if (lo == 's' or lo == 'f' or lo == 'r' or lo == 'x' or lo == 'j') {
        const r = computeRegions(s);
        if (r.has_nucleus) {
            const ct = currentTone(s);
            if (ct == lo) {
                // Cancellation: same tone pressed again → strip tone, enter literal
                enterLiteral(s);
                if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
                return 1;
            }
            applyTone(s, lo);
            return 1;
        }
        // No nucleus vowels: treat as consonant
        if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
        return 1;
    }

    // ── z: tone reset or literal ──
    if (lo == 'z') {
        const ct = currentTone(s);
        if (ct != 0) {
            // Remove tone from all vowels
            var i: u8 = 0;
            while (i < s.len) : (i += 1) {
                if (spanIsVowel(s.spans[i])) {
                    s.spans[i].tone = 0;
                }
            }
            return 1;
        }
        // No tone to reset → enter literal
        enterLiteral(s);
        if (!appendSpan(s, ch, 0, 0, flags | 0x02)) return overflowReset(s);
        return 1;
    }

    // ── Vowels ──
    if (isVowel(lo)) {
        if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
        autoFillUO(s);
        // Re-apply tone placement after adding a vowel
        const ct = currentTone(s);
        if (ct != 0) applyTone(s, ct);
        return 1;
    }

    // ── Consonants ──
    if (!appendSpan(s, ch, 0, 0, flags)) return overflowReset(s);
    autoFillUO(s);
    return 1;
}

export fn get_composed_utf16(state: *anyopaque, buf: [*]u16, buf_len: u16) u16 {
    const s: *State = @ptrCast(@alignCast(state));
    var pos: u16 = 0;

    var i: u8 = 0;
    while (i < s.len) : (i += 1) {
        if (pos >= buf_len) return 0xFF; // buffer overflow

        const sp = s.spans[i];

        // Literal spans: emit raw base character
        if (sp.flags & 0x02 != 0) {
            buf[pos] = @intCast(sp.base);
            pos += 1;
            continue;
        }

        const cp = lookupCodepoint(sp.base, sp.modifier, sp.tone);
        buf[pos] = cp;
        pos += 1;
    }

    return pos;
}
