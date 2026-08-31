# issue #195 step6 — GUI toolkit IME PoC (wx vs Qt)

Minimal, standalone PoCs to decide the GUI toolkit by measuring **Japanese
inline-IME quality on a self-drawn (custom) widget** — the exact shape xyzzy
needs (we draw the buffer ourselves via the Painter; the toolkit supplies the
window + input + IME). No xyzzy core code is touched.

## What each PoC does

A custom widget paints one line of text itself, places a caret, and tries to
host Japanese IME: preedit (composition) shown underlined at the caret, the
candidate window positioned at the caret, and commit inserting text.

- `qt-ime/`  — `QWidget` + `inputMethodEvent()`/`inputMethodQuery()`. Qt's
  documented, cross-platform path for a custom-drawn editor.
- `wx-ime/`  — custom `wxWindow` + `wxPaintDC`. wx custom drawing is fine; the
  open question is how much inline-IME machinery we must hand-wire (on macOS
  `wxNSView`'s NSTextInputClient hooks are stubs). The PoC logs which events
  actually arrive so we can see what's missing.

## Build & run

```sh
# Qt
cmake -S qt-ime -B qt-ime/build -DCMAKE_PREFIX_PATH=$(brew --prefix qt)
cmake --build qt-ime/build
./qt-ime/build/qt-ime

# wx
cmake -S wx-ime -B wx-ime/build -DCMAKE_PREFIX_PATH=$(brew --prefix wxwidgets)
cmake --build wx-ime/build
./wx-ime/build/wx-ime
```

## What to compare (the decision criteria)

1. **Inline preedit**: does the in-progress composition appear underlined at
   the caret inside the widget? (Qt: expected yes. wx: the thing under test.)
2. **Candidate window placement**: does the IME candidate popup appear at the
   caret, not at the window origin?
3. **Commit**: does the confirmed string arrive cleanly once?
4. **How much code it took** to get the above on a *custom-drawn* widget.

Trade-off going in (from research): Qt is stronger on IME + custom drawing;
wx wins on distribution (wxWindows License → static single binary). The PoC is
to see whether wx's IME gap is acceptable or a dealbreaker for xyzzy.
