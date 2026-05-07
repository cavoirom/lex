# Lex - Vietnamese Telex input method

The specification of the Lex program, a Vietnamese Telex input method.

## Vietnamese Telex Rules

### Diacritics

Diacritics let a letter have many variant. We only focus on letter diacritics in this section. Tones
have seperated section.

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

#### Bar

- Valid for: `D` (Đ) and its lower case.

#### Apply rules

- Only apply diacritic when the immediate previous character doesn't have any diacritic (empty).
- _Circumflex_, _bar_ are triggered when user inputs the same character (ignore case) with the
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
- Only `A`, `O` have override rules because they have more than one possible letter diacritic.
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
  - Bar: `Đd` -> `Dd`, `đD` -> `dD`.
- The new character is literal, keeps its case, no tone.
- Switch to literal from the new character position and the following characters. Literal input
  remains until the process is reset (usually when starting new word).
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

_(the tones specification is not ready)_

#### Level

#### Rising

#### Falling

#### Dipping-rising

#### Rising-glottalized

#### Falling-glottalized

#### Apply rules

#### Override rules

#### Reposition rules
