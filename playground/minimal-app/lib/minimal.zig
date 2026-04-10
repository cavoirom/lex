const State = enum(u8) {
    idle,
    one_e,
    circumflex,
    literal,
};

const ProcessKeyEventResult = extern struct {
    num_backspaces: u8,
    num_chars: u8,
    swallow_event: bool,
    chars: [*]const u16,
};

// --- Internal variables ---

var state: State = .idle;
var first_e_upper: bool = false;
var gap: u8 = 0;
var bufs: [2][2]u16 = .{ .{ 0, 0 }, .{ 0, 0 } };
var active: u1 = 0;

const passthrough: ProcessKeyEventResult = .{
    .num_backspaces = 0,
    .num_chars = 0,
    .swallow_event = false,
    .chars = @ptrCast(&bufs[0]),
};

// --- Internal functions ---

fn emit(num_backspaces: u8, chars: []const u16) ProcessKeyEventResult {
    const buf = @as([*]u16, @ptrCast(&bufs[active]));
    for (chars, 0..) |c, i| buf[i] = c;
    active ^= 1;
    return .{
        .num_backspaces = num_backspaces,
        .num_chars = @intCast(chars.len),
        .swallow_event = true,
        .chars = buf,
    };
}

fn is_e(c: u16) bool {
    return c == 'e' or c == 'E';
}

fn is_alphanumeric(c: u16) bool {
    return (c >= '0' and c <= '9') or
        (c >= 'A' and c <= 'Z') or
        (c >= 'a' and c <= 'z');
}

fn handle_e(char_code: u16) ProcessKeyEventResult {
    const upper = char_code == 'E';
    switch (state) {
        .idle => {
            state = .one_e;
            first_e_upper = upper;
            return passthrough;
        },
        .one_e => {
            state = .circumflex;
            const c: u16 = if (first_e_upper) 0x00CA else 0x00EA;
            return emit(1, &.{c});
        },
        .circumflex => {
            state = .literal;
            const c0: u16 = if (first_e_upper) 'E' else 'e';
            const c1: u16 = if (upper) 'E' else 'e';
            return emit(1, &.{ c0, c1 });
        },
        .literal => unreachable,
    }
}

// --- Public functions ---

export fn reset_state() void {
    state = .idle;
    first_e_upper = false;
    gap = 0;
}

export fn process_backspace() ProcessKeyEventResult {
    if (gap > 0) {
        gap -= 1;
    } else switch (state) {
        .literal => state = .one_e,
        .idle => {},
        else => reset_state(),
    }
    return passthrough;
}

export fn process_key_event(char_code: u16) ProcessKeyEventResult {
    if (is_e(char_code)) {
        if (gap == 0 and state != .literal) return handle_e(char_code);
    } else if (!is_alphanumeric(char_code)) {
        reset_state();
        return passthrough;
    } else if (state == .idle) {
        return passthrough;
    }

    if (gap == 255) {
        reset_state();
        return passthrough;
    }
    gap += 1;
    return passthrough;
}
