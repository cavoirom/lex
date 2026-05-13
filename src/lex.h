#ifndef LEX_H
#define LEX_H

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
void lex_state_init(void *state);

// Feed one ASCII alphabetic character (a-zA-Z) into the engine.
void lex_add(void *state, uint8_t c);

// Apply a single backspace to the engine state.
void lex_backspace(void *state);

#ifdef __cplusplus
}
#endif

#endif // LEX_H
