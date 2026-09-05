// -*-C++-*-
#ifndef _font_metrics_h_
# define _font_metrics_h_

/*
 FontMetrics — platform-neutral font measurement interface (issue #195 step5).

 The core's font path used to leak Win32 GDI through `FontObject::get_metrics()` and
 `FontObject::dpi()` call `GetDC`/`GetDeviceCaps`/`GetTextMetricsW`/
 `GetTextExtentPoint32W` directly (implemented in `src/frontend/win32/font.cc`,
 which is a Win32-only source). `FontMetrics` projects the measurement those
 use onto a neutral interface so the frontend supplies the implementation:
 Win32FontMetrics wraps GDI, NcursesFontMetrics returns cell=1 dummy values.

 Current state: step 5 is done in full (5a-5e).  FontSet::create measures
 through FontMetrics, and the inline GDI (GetDC/GetDeviceCaps/MulDiv) is gone
 from font.h.  Implementations: Win32FontMetrics in src/frontend/win32/font.cc,
 NcursesFontMetrics (cell=1) in the ncurses frontend.

 **Do not keep a step list here** — see the note in painter.h.  The tracking
 issue is #195.

 Note: LOGFONTW stays as the measurement *input* — it is the logical font
 description, not a device handle, so it does not couple core to a device
 context. Only the GDI *calls* are what this interface hides.
*/

# include "cdecl.h"       // fixed-width int types
# include "platform.h"    // LOGFONTW, SIZE

// Result of measuring one logical font, mirroring what
// FontObject::get_metrics() computes today.
struct FontMetricsResult
{
  int ave_char_width;   // TEXTMETRIC::tmAveCharWidth
  int ascent;           // TEXTMETRIC::tmAscent
  int descent;          // TEXTMETRIC::tmDescent
  int ascii_width;      // advance width of an ASCII glyph ("A")
  int fullwidth;        // advance width of a fullwidth glyph (U+3042)
};

struct FontMetrics
{
  virtual ~FontMetrics () {}

  // Measure the given logical font. The implementation acquires/releases any
  // device context it needs internally; callers stay device-context-free.
  virtual FontMetricsResult measure (const LOGFONTW &lf) = 0;

  // Vertical DPI (GetDeviceCaps(LOGPIXELSY) equivalent), for the
  // pixel<->point conversions font.h currently does inline via GetDC.
  virtual int dpi_y () const = 0;
};

#endif /* _font_metrics_h_ */
