#ifndef LEX_H
#define LEX_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Required allocation size of the engine state, in bytes.
extern const size_t lex_state_size;

// Required allocation alignment of the engine state, in bytes.
extern const size_t lex_state_alignment;

// Initialize a state buffer. The buffer must be at least `lex_state_size`
// bytes and aligned to `lex_state_alignment`.
void lex_init(void *state);

// Feed one ASCII alphabetic character (a-zA-Z) into the engine.
void lex_add(void *state, uint8_t c);

// Apply a single backspace to the engine state.
void lex_backspace(void *state);

uint8_t lex_calculate_synthetic_backspaces(void *state);

bool lex_buffer_effective_full(void *state);

// Indicate the buffer_length is at the maximum limit.
bool lex_buffer_full(void *state);

// Indicate the buffer_length is zero.
bool lex_buffer_empty(void *state);

extern const size_t lex_replacement_buffer_length;

// `replacement_buffer` capacity must be exactly `lex_replacement_buffer_length`.
void lex_compose_utf16_string_replacement(
    void *state,
    uint16_t *replacement_buffer,
    uint8_t *replacement_count);

#ifdef __cplusplus
}
#endif

#endif // LEX_H
