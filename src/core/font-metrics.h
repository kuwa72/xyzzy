// -*-C++-*-
#ifndef _font_metrics_h_
# define _font_metrics_h_

/*
 FontMetrics — platform-neutral font measurement interface (issue #13 step5).

 The core's font path leaks Win32 GDI: `FontObject::get_metrics(HDC)` and
 `FontObject::dpi()` call `GetDC`/`GetDeviceCaps`/`GetTextMetricsW`/
 `GetTextExtentPoint32W` directly (implemented in `src/frontend/win32/font.cc`,
 which is a Win32-only source). `FontMetrics` projects the measurement those
 use onto a neutral interface so the frontend supplies the implementation:
 Win32FontMetrics wraps GDI, NcursesFontMetrics returns cell=1 dummy values.

 Phase (issue #13 step5):
   5a (this file) — interface only, unused, zero build impact.
   5b — NcursesFontMetrics (cell=1 dummy) added in the ncurses frontend.
   5c — Win32FontMetrics implementation (ports the font.cc GDI logic),
        alongside the existing get_metrics(HDC) path.
   5d — FontSet::create measures through FontMetrics instead of GDI directly.
   5e — strip the inline GDI (GetDC/GetDeviceCaps/MulDiv) from font.h.

 Note: LOGFONTW stays as the measurement *input* — it is the logical font
 description, not a device handle, so it does not couple core to a device
 context. Only the GDI *calls* are what this interface hides.
*/

# include "cdecl.h"       // fixed-width int types
# include "platform.h"    // LOGFONTW, SIZE

// Result of measuring one logical font, mirroring what
// FontObject::get_metrics(HDC, SIZE&, SIZE&) computes today.
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
