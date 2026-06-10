# Lex changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.1.1

### Fixed

- Wrong handling for _QU_, this is a consonant, but the program allows putting _horn_ for _U_. The
  correct behavior is appending _W_ literally and change to literal input when typing _W_ right
  after _QU_.
- Wrong auto-fill handling in _QU_ case. Current, the program will auto-fill _horn_ for _U_ when
  typing _N_ (or any auto-fill triggers) after _QUƠ_, resulting _QƯƠN_ which is wrong. The corect
  behavior is treating _QU_ as a consonant, should not add _horn_ to them.

## 0.1.0

### Added

- Only display program icon on MenuBar.
- Opinionated Telex input:
  - Old tone placement: _òa_, _úy_, e.g. _hòa_, _thúy_.
  - Treat word starts with the following characters as non-Vietnamese: _f_, _j_, _w_, _z_.
  - Must place diaritic right after vowels, `d`.
  - Can place tone at the end of the word.
- Toggle Telex input: `Ctrl + Opt + Space`.
- Open at Login.
