#ifndef LIBLEX_H
#define LIBLEX_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint8_t num_backspaces;
    uint8_t num_chars;
    bool swallow_event;
    const uint16_t *chars;
} ProcessKeyEventResult;

ProcessKeyEventResult process_key_event(uint16_t char_code);
ProcessKeyEventResult process_backspace(void);
void reset_state(void);

#endif
