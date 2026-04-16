#ifndef LIBLEX_H
#define LIBLEX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Returns the size of the engine state struct.
size_t state_size(void);

// Initializes a state buffer (must be at least state_size() bytes).
void init_state(void *state);

// Processes one character input. Returns disposition:
// 0 = passthrough (host should not swallow the event)
// 1 = consumed (host should swallow and apply diff)
uint8_t add(void *state, uint16_t char_code);

// Removes the last composed character. Returns disposition:
// 0 = nothing to remove
// 1 = consumed
uint8_t backspace(void *state);

// Resets engine state (clears all spans).
void reset(void *state);

// Serializes current composed text to UTF-16.
// Writes into buf (up to buf_len code units).
// Returns number of code units written, or 0xFF on overflow.
uint16_t get_composed_utf16(void *state, uint16_t *buf, uint16_t buf_len);

#endif
