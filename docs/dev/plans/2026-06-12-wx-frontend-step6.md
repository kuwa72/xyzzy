# wx (wxWidgets) GUI frontend — issue #195 step6 implementation plan

Status: planned (not started). Toolkit decided = **wxWidgets** (see `poc/` and
commit `1c6668d`). This doc is the implementation plan; delete `poc/` once
`ime_hook.mm`'s knowledge is folded into the real frontend.

## Context (what's already in place)

- Steps 1–5 of issue #195 are done: core drawing flows through `Painter`
  (`src/core/painter.h`); font measurement through `FontMetrics`
  (`src/core/font-metrics.h`).
- **`NcursesPainter` (in `src/frontend/ncurses/ncurses-stubs.cc`, ~2331–2435)
  is the template** for `WxPainter`.
- **`Window::paint_region(Painter&)` / `paint_glyphs(Painter&)`
  (`src/frontend/win32/disp.cc:1227 / 590`) are already Painter-only** (no HDC)
  and platform-neutral — wx reuses them unchanged.
- IME proven: `poc/wx-ime/ime_hook.mm` swizzles `NSTextInputClient` onto the
  `GetHandle()` NSView and recovers preedit; clean `install_ime_hook(nsview,
  on_preedit, on_commit)` boundary in `poc/wx-ime/ime_hook.h`.
- wxWidgets 3.3.2 installed via brew (`/opt/homebrew/opt/wxwidgets`).

## Key architectural decisions

### Drawing path: **option B — reuse `redraw_window` + `paint_region(Painter&)`**
Not the ncurses-style hand-rolled `render_glyph_row` (option A). A is right for
a terminal (cell=1, no atlas, no dirty-tracking); a GUI needs all three, so A on
wx would mean hand-reimplementing `paint_glyphs`/`paint_line` (~650 lines — the
deferred "4g"). B reuses the tested core paint code; wx only implements the ~10
`WxPainter` primitives + `WxFontMetrics` + a minimal `wx-font.cc`.

**Cost of B:** `paint_region` reads `app.text_font.cell().cy`, so `app.text_font`
must be a *real* populated `FontSet` (not the ncurses zero-stub). Supply a small
`wx-font.cc` that implements `FontSet::create`/`FontObject` via `WxFontMetrics`
(exactly the step5d design) to populate `fs_cell`/`fs_ascent`/`fs_size`. No glyph
atlas (`fs_hbm`) needed if `WxPainter::blit_glyph_bitmap` draws substitute
chars/lines per FontSet slot (like ncurses `bitmap_slot_char`).

**Coordinate system:** core geometry stays in **cells**; pixel arithmetic
happens inside shared core paint code via `app.text_font.cell()`. `WxPainter`
receives already-pixel x/y and forwards to `wxDC`. `cell_width()/cell_height()`
return the real wx font cell (NOT 1, unlike ncurses).

### Pull-type `fetch` vs wx push-type event loop
Win32 already solves it (`src/frontend/win32/kbd.cc:175`): `fetch()` drains
`app.kbdq`; if empty, runs the native loop one message at a time; the key
handler pushes into `kbdq`; spin until satisfied. wx equivalent:
```cpp
lChar kbd_queue::fetch(int,int){
  if (pending!=EOF) return dequeue();
  if (head!=tail)   return dequeue();
  wxEventLoopBase *loop = wxEventLoop::GetActive();
  for(;;){ if(head!=tail||pending!=EOF) break; loop->Dispatch(); }
  return dequeue();
}
```
`EVT_CHAR`/`EVT_KEY_DOWN`/IME `on_commit` call `app.kbdq.putc()`. A `wxTimer`
drives `poll_processes()`/GC (replaces ncurses' 100ms select timeout).
**`WxFrontend::main_loop()` must NOT call `wxApp::MainLoop()`** — core owns
control flow (`command_loop()`); set up wxApp/top window in `init()`
(`wxEntryStart`, not `wxEntry`), keep a `wxEventLoop` active, let `fetch`'s
nested `Dispatch()` pump events. Mirrors ncurses-main blocking on `select`.

### IME
`on_commit(text)` → feed code points to `app.kbdq.putc()` (same path as
`EVT_CHAR`; same as ncurses-kbd passing the code point straight through).
`on_preedit(text,caret)` → store a **frontend overlay** (NOT inserted into the
buffer) + `canvas->Refresh()`; draw underlined at the caret in `refresh_screen`
via `WxPainter::draw_text_chars(... PAINT_UNDERLINE ...)`. Only commit touches
the buffer → no new core editing API. Refine `firstRectForCharacterRange` to the
real caret pixel so the candidate window sits under the cursor.

## Stub scope
`wx-stubs.cc` = fork of `ncurses-stubs.cc` (~7600 lines). **~75–80% copies
verbatim**: `buffer_info::*` formatting, minibuffer/completion family, `WINFS::*`
(POSIX, same on macOS), Win32 no-ops (`Fole_*`/`Fdde_*`/toolbar/filer/`Fsi_ts_*`),
window geometry (swap cell-units handling). **New work ~1000–1500 lines**:
`WxPainter` + `WxFontMetrics` + wx render loop + `wx-kbd.cc` + `wxClipboard` +
(later) native `wxMenuBar` + IME wiring.

**Geometry unit note:** keep core layout in cells; convert wx client pixel size
→ cols/rows = clientpx ÷ cell. Pixels appear only at the Painter boundary.

## Substeps (optimized so "empty window" and "first buffer" come early)

- **6a** — `xyzzy-wx` CMake target + `src/frontend/wx/wx-main.cc`: minimal wxApp,
  empty wxFrame + custom canvas. **No core link.** Verify: blank window opens.
- **6b** — Link core; fork `ncurses-main.cc`→`wx-main.cc` (reuse all
  `init_*`/`init_symbol_value*`); `WxFrontend:Frontend`; fork
  `ncurses-stubs.cc`→`wx-stubs.cc` with drawing stubbed no-op; features add
  `:wx`; `main_loop()` calls `command_loop()`. Verify: window opens, `startup.l`
  loads, no crash. Risk: linker whack-a-mole (diff vs ncurses symbol set);
  `-Wl,-stack_size,0x1000000`.
- **6c-1** — A-lite `WxPainter` (`draw_text` per glyph, one font, fixed cell,
  ignore color/bold/atlas) + `refresh_screen`/`render_window` calling core
  `redraw_window` then hand-rolled row blit into a `wxMemoryDC` backbuffer;
  `EVT_PAINT` blits. **Verify: buffer text appears in the wx window = headline.**
- **6c-2** — `src/frontend/wx/wx-font.cc` (`WxFontMetrics` + `FontSet::create`
  populating `fs_cell`); replace hand-rolled loop with
  `wp->paint_region(wxpainter, 0, wp->w_ch_max.cy)`; flesh out `WxPainter`
  (per-charset fonts, color, bold/underline, `blit_glyph_bitmap`,
  `draw_text_chars`). Verify: JP+ASCII, syntax colors, mode line, splits = Win32
  parity. Risk (main project risk): zero `fs_cell` → div-by-zero; HiDPI scale
  (`GetContentScaleFactor`); flicker → backbuffer.
- **6d** — `wx-kbd.cc`: `fetch/peek/listen/sit_for/sleep_for` via
  `wxEventLoop::Dispatch()`; `EVT_CHAR`/`EVT_KEY_DOWN` → lChar (special-key table
  like ncurses `map_ncurses_key`: WXK_UP→CCF_UP etc.); push to kbdq. Verify:
  typing, arrows, C-x C-f, C-x C-c. Risk: loop ownership; Cmd-vs-Ctrl→Meta.
- **6e** — add `poc/wx-ime/ime_hook.{mm,h}` to the target (Obj-C++); install on
  canvas; `on_commit`→kbdq, `on_preedit`→overlay+Refresh + underlined draw.
  Verify: JP inline IME (preedit at caret, commit inserts, candidate near caret).
- **6f** — native `wxMenuBar` from lisp menu model; `wxClipboard`;
  `EVT_LEFT_DOWN`/`EVT_MOTION`/`EVT_MOUSEWHEEL`→mouse lChar (like
  `ncurses_mouse_dispatch`); `EVT_SIZE`→geometry recompute+repaint (replaces
  SIGWINCH); caret blink `wxTimer`; scrollbars.
- **6g+** (optional) — glyph atlas, double-buffer opt, `wxFontDialog` for
  `Fset_text_fontset`, printing.

**Shortest path to demo:** 6a → 6b → 6c-1 → 6d.

## CMake (`xyzzy-wx`, add after the ncurses block ~CMakeLists.txt:973)
Additive, guarded `if(APPLE)` (later `NOT WIN32` once Linux/GTK validated):
- `find_package(wxWidgets COMPONENTS core base)` (Homebrew ships a CMake config),
  fallback to parsing `wx-config` (`/opt/homebrew/opt/wxwidgets/bin`).
- `WX_SOURCES` = `wx-main.cc wx-stubs.cc wx-kbd.cc wx-font.cc wx-painter.cc`
  (painter may fold into stubs) + `poc/wx-ime/ime_hook.mm` + reuse
  `cli-conf.cc`, `ncurses-process.cc`, `ncurses-symtable-ed.cc` if
  frontend-agnostic (verify; else `wx-process.cc`).
- `add_executable(xyzzy-wx MACOSX_BUNDLE ${WX_SOURCES})` (bundle for
  NSApplication/menu/IME correctness).
- `.mm` needs `-x objective-c++ -fobjc-arc` (PoC uses `__bridge` → ARC).
- `target_link_libraries(... xyzzy-core ${wxWidgets_LIBRARIES} pthread util
  "-framework Cocoa")`; `target_link_options(... -Wl,-stack_size,0x1000000)`.
- Keep `-iquote` include dirs like the ncurses target; `UNICODE`/`_UNICODE`.
- Purely additive — do not touch core/ncurses/win32 targets.

## Critical files
- `src/frontend/ncurses/ncurses-stubs.cc` — fork as `wx-stubs.cc` (Painter
  template 2331–2435; render loop 3158/3283; ~75% copies verbatim)
- `src/frontend/win32/disp.cc` — `paint_region(Painter&)` (1227) /
  `paint_glyphs(Painter&)` (590) reused unchanged; `Win32Painter` (425–560) =
  per-method reference for `WxPainter`
- `src/core/painter.h` + `src/core/font-metrics.h` — interfaces to implement
- `src/frontend/win32/kbd.cc:175` — pull-into-push `fetch` pattern to replicate
- `CMakeLists.txt` — add `xyzzy-wx` after ncurses block (~898–973)
- `poc/wx-ime/ime_hook.{mm,h}` — drop-in IME hook
