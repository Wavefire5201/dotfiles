# Jisho

Launcher provider for [jisho.org](https://jisho.org), modelled on the Raycast Jisho extension.

- `>jisho <word>` searches in kanji, kana, romaji or English. The side preview shows every sense,
  parts of speech, Common/JLPT tags and other forms.
- Enter opens the word on jisho.org. Row buttons copy the word or its reading (`wl-copy`).
- `>jisho` alone lists recent words (opened or copied, newest first, max 50). Delete removes one.

## IPC

```bash
qs -c noctalia-shell ipc call plugin:jisho lookupSelection  # >jisho <primary selection>
qs -c noctalia-shell ipc call plugin:jisho lookup 食べる
qs -c noctalia-shell ipc call plugin:jisho toggle
```

Bound to Super+Alt+J (toggle) and Super+Alt+Shift+J (selection) in `hypr/keybinds.lua`.

## Tests

`bash tests/run.sh` runs the node unit tests, then two headless (`QT_QPA_PLATFORM=offscreen`)
quickshell harnesses against a local fixture server, with fake `xdg-open`/`wl-copy`/`wl-paste`.
The render harness writes preview PNGs to `$JISHO_RENDER_OUT`.
