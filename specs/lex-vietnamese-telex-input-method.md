# Lex - Vietnamese Telex input method

The specification of the Lex program, a Vietnamese Telex input method.

## Vietnamese Telex Rules

### Literal input characters

- When any of the following characters start the word (when the word is empty), change to literal
  input from the new character position: `F`, `J`, `W`, `Z` (ignore cases), because these characters
  don't start a Vietnamese word. This rule is higher priority than diacritics and tones rules.
- When any of the following characters are added to the word, change to literal input from the new
  character position: `F`, `J`, `W` (ignore cases), because these characters don't appear in formal
  Vietnamese spelling. `Z` exists in Vietnamese word such as _Dzũng_, _Hồ Dzếnh_... This rule is
  lower priority than diacritics and tones rules.
- Literal input remains until the new word.
- When the user backspaces pass before the literal point, we switch to Vietnamese input again.

### Diacritics

Diacritics let a character have many variant. We only focus on character diacritics in this section.
Tones have a separate section.

#### Empty

- Any literal alphabet character has empty diacritic by default.
- Only a specific number of characters have other diacritic and it must follow the rules for those
  characters.

#### Circumflex

- Valid for: `A` (Â), `E` (Ê), `O` (Ô) and their lower cases.

#### Breve

- Valid for: `A` (Ă) and its lower case.

#### Horn

- Valid for: `O` (Ơ), `U` (Ư) and their lower cases.

#### Stroke

- Valid for: `D` (Đ) and its lower case.

#### Apply rules

- Only apply diacritic when the immediate previous character doesn't have any diacritic (empty).
- _Circumflex_, _stroke_ are triggered when user inputs the same character (ignore case) with the
  existing character when that character is valid for the applying diacritic.
  - `Aa` -> `Â`, `Ee` -> `Ê`, `Oo` -> `Ô`.
  - `Dd` -> `Đ`.
- _Breve_, _horn_ are triggered when user input `W`, `w` after the character when that character is
  valid for the applying diacritic. Otherwise, treat `W`, `w` literally.
  - `Aw` -> `Ă`.
  - `Ow` -> `Ơ`, `Uw` -> `Ư`.
- The existing character keep its case, tone.
- Treat out of scope characters as literal.

#### Override rules

- New valid diacritic can override existing valid diacritic of the same base character.
  - `Ăa` -> `Â`, `Âw` -> `Ă`.
  - `Ôw` -> `Ơ`, `Ơo` -> `Ô`.
- Only `A`, `O` have override rules because they have more than one possible character diacritic.
- Keep tone untouched.
- The existing character keep its case, tone.
- Treat out of scope characters as literal.

#### Cancel rules

- The cancellation is triggered if and only if user inputs the character (ignore case) that would
  produce the existing diacritic for the same base character of the immediate previous character.
- The existing character keeps its case, tone, but the diacritic is removed.
  - Circumflex: `Âa` -> `Aa`, `Ốo` -> `Óo`... and so on for other cases of the same kind.
  - Breve: `Ăw` -> `Aw`.
  - Horn: `Ưw` -> `Uw`... and so on for other cases of the same kind.
  - Stroke: `Đd` -> `Dd`, `đD` -> `dD`.
- The new character is literal, keeps its case, no tone.
- Switch to literal from the new character position and the following characters. Literal input
  remains until the new word.
  - Existing `Â`, input `aa`, result `Aaa`.
- When the user backspaces pass before the literal point, we switch to Vietnamese input again.

#### Auto-fill rules

- The auto-fill is only applied for `ươ` syllable immediately before the user input, when one of the
  character in the syllable is missing horn: `uơ` and `ưo`.
- Fill the missing _horn_ when the input is one of these character (ignore case): `C`, `I`, `M`,
  `N`, `P`, `T`, `U` and their lower cases.
  - Fill missing horn on `U`: `uơn` -> `ươn`.
  - Fill missing horn on `O`: `ưóp` -> `ướp`.
- The new input character is appended literally.
- Tone and case of existing characters are preserved on the original characters.

### Tones

Tones let a word have many variants, each variant has different meaning. Only the following
Vietnamese vowel could have tones: `A`, `E`, `I`, `O`, `U`, `Y` and their corresponding variants.
These vowel could take any tone.

#### Level (ngang)

- The default tone, it's the vowel without any tone mark, e.g. `A`, `Ê`, `Ơ`...and all other
  corresponding variants.
- If a vowel has tone mark other than level, use `Z`, `z` to reset the tone to level.

#### Rising (sắc)

- Example of rising tone: `Á`, `Ế`, `Ớ`...and all other corresponding variants.
- Use `S`, `s` to put the rising tone to the Vietnamese vowels, e.g. `As` -> `Á`, `Ês` -> `Ế`, `Ơs`
  -> `Ớ`.

#### Falling (huyền)

- Example of falling tone: `À`, `Ề`, `Ờ`...and all other corresponding variants.
- Use `F`, `f` to put the falling tone to the Vietnamese vowels, e.g. `Af` -> `À`, `Êf` -> `Ề`, `Ơf`
  -> `Ờ`.

#### Dipping-rising (hỏi)

- Example of dipping-rising tone: `Ả`, `Ể`, `Ở`...and all other corresponding variants.
- Use `R`, `r` to put the dipping-rising tone to the Vietnamese vowels, e.g. `Ar` -> `Ả`, `Êr` ->
  `Ể`, `Ơr` -> `Ở`.

#### Rising-glottalized (ngã)

- Example of rising-glottalized tone: `Ã`, `Ễ`, `Ỡ`...and all other corresponding variants.
- Use `X`, `x` to put the rising-glottalized tone to the Vietnamese vowels, e.g. `Ax` -> `Ã`, `Êx`
  -> `Ễ`, `Ơx` -> `Ỡ`.

#### Falling-glottalized (nặng)

- Example of falling-glottalized tone: `Ạ`, `Ệ`, `Ợ`...and all other corresponding variants.
- Use `J`, `j` to put the falling-glottalized tone to the Vietnamese vowels, e.g. `Aj` -> `Ạ`, `Êj`
  -> `Ệ`, `Ơj` -> `Ợ`.

#### Apply rules

- Only trigger apply tone when the buffer has existing characters. Otherwise, append the new
  character literally.
- Trigger apply tone when user inputs the trigger character for tones: `S`, `F`, `R`, `X`, `J` and
  their lower cases.
- _Scan pseudo-word_ to have the information for later steps.
- If the pseudo-word doesn't have any vowels, append new character literally.
- If the pseudo-word has at least one vowel and all of them don't have any tone (level), use _tone
  position rules_ to apply the tone for the word.
- If _tone position rules_ could not put tone to the pseudo-word, append new character literally.

#### Cancel rules

- Only trigger apply tone when the buffer has existing characters. Otherwise, append the new
  character literally.
- Trigger apply tone when user inputs the trigger character for tones: `S`, `F`, `R`, `X`, `J` and
  their lower cases.
- _Scan pseudo-word_ to have the information for later steps.
- If the pseudo-word doesn't have any vowels, handle by _apply rules_.
- If the pseudo-word has at least one vowel and has the tone (other than level) on vowels match with
  the triggered tone. Reset that tone to level. Append new character literally.
- If the new character has been appended literally, switch to literal from the new character
  position and the following characters. Literal input remains until the new word.
- When the user backspaces pass before the literal point, we switch to Vietnamese input again.

#### Reset rules

- Only trigger reset tone when the buffer has existing characters. Otherwise, append the new
  character literally.
- Trigger reset tone when user inputs the trigger character for reset: `Z`, `z`.
- _Scan pseudo-word_ to have the information for later steps.
- If the pseudo-word has at least one vowel and has tone (other than level) in one of the vowels,
  change that tone to level, keep case and diacritic.
- If the pseudo-word doesn't have any vowels, append the new character literally and remain
  Vietnamese input to continue process Vietnamese input such as `dzu + x` -> `dzũ`.
- If the pseudo-word has at least one vowel and all of them don't have any tone (level), append the
  new character literally and switch to literal from the new character position and the following
  characters. Literal input remains until the new word.
- When the user backspaces pass before the literal point, we switch to Vietnamese input again.

#### Override rules

- Only trigger override tone when the buffer has existing characters. Otherwise, append the new
  character literally.
- Trigger apply tone when user inputs the trigger character for tones: `S`, `F`, `R`, `X`, `J` and
  their lower cases.
- _Scan pseudo-word_ to have the information for later steps.
- If the pseudo-word doesn't have any vowels, handle by _apply rules_.
- If the pseudo-word has at least one vowel and has the tone (other than level) on vowels different
  from the triggered tone, reset that tone to level, use _tone position rules_ to apply new tone for
  the word. The override tone is always successful.

#### Scan pseudo-word

- Scan pseudo-word is a process to get the information needed from the existing characters to put
  the tone in the correct position.
- The existing characters must not be empty.
- Iterate backward from the last existing character (the new input is the tone trigger character).
- If a vowel is found first, continue go backward until scanned the first consonant (singular) or no
  character to scan, then stop.
- If a consonant is found first, continue go backward until found the first vowel, then continue go
  backward until scanned the first consonant (singular) or no character to scan, then stop.
- After iterated, a context have been formed either (in the left to right order, not the reverse)
  `<consonants>`, `<vowels><consonants>`, `<consonant><vowels><consonants>`, `<vowels>` or
  `<consonant><vowels>`.

#### Tone position rules

The process of applying tone to a word go through many steps:

- Focus on the `<vowels>` in peusdo-word, it could be one vowel but could be multiple vowels, the
  tone will be applied on one of these vowels.
- Exceptions:
  - Word exactly `QU` (and their lower cases), could not put tone, this is a consonant only.
- If one vowel, put the tone on that vowel.
- If multiple vowels, follow these rules, priority from top down:
  - Vowels has `Ơ` (and its lower case), put on the rightmost `Ơ`.
  - Vowels has one any of `Ê`, `Â`, `Ô`, `Ă`, `Ư` (and their lower cases), put on the rightmost
    listed vowel found by the reverse scan.
  - Word start with `GI`, `QU` (and their lower cases) and has more vowels, put on next vowel, `I` /
    `U` count as part of the consonant.
  - Vowels exactly `OA`, `OE`, `OO`, `UY` (and their lower cases), put on first vowel.
  - Vowels start with `OA`, `OE`, `OO`, `UY` (and their lower cases) and has more vowels or
    consonants, put on second vowel.
  - Otherwise, put on first vowel.
- Preserve case and diacritic on existing vowels.
- Could not put tone for other cases.
