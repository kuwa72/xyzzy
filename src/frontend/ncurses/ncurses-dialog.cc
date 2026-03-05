// ncurses-dialog.cc — dialog-box implementation for ncurses frontend
#include "stdafx.h"
#include "ed.h"

#include <ncurses.h>
#include <wchar.h>
#include <string.h>

extern volatile int g_need_resize;
void refresh_screen (int);

// Button subtypes (style & 0xf)
enum
{
  BTN_PUSH = 0, BTN_DEFPUSH = 1,
  BTN_CHECKBOX = 2, BTN_AUTOCHECKBOX = 3,
  BTN_RADIO = 4, BTN_3STATE = 5, BTN_AUTO3STATE = 6,
  BTN_GROUPBOX = 7, BTN_AUTORADIO = 9,
};

enum { EDIT_MAX = 512, CTL_MAX = 64 };

struct NcCtl
{
  lisp wclass;
  lisp symid;
  lisp text;
  int style;
  int dx, dy, dw, dh;
  lisp kwd;

  int row, col, width;

  int enabled;
  int visible;
  int checked;       // 0, 1, 2(indeterminate)

  Char ebuf[EDIT_MAX];
  int elen;
  int epos;

  lisp items;
  int nitem;
  int isel;
};

static int
is_push_button (NcCtl *c)
{
  if (c->wclass != Kbutton) return 0;
  int b = c->style & 0xf;
  return b == BTN_PUSH || b == BTN_DEFPUSH;
}

static int
is_checkbox (NcCtl *c)
{
  if (c->wclass != Kbutton) return 0;
  int b = c->style & 0xf;
  return b == BTN_CHECKBOX || b == BTN_AUTOCHECKBOX
    || b == BTN_RADIO || b == BTN_AUTORADIO
    || b == BTN_3STATE || b == BTN_AUTO3STATE;
}

static int
is_focusable (NcCtl *c)
{
  if (!c->enabled || !c->visible) return 0;
  if (c->wclass == Kstatic) return 0;
  if (c->wclass == Kbutton && (c->style & 0xf) == BTN_GROUPBOX) return 0;
  return 1;
}

static int
is_editable (NcCtl *c)
{
  return c->wclass == Kedit || c->wclass == Kcombobox;
}

// Strip '&' accelerator from text for display, return display width
static int
render_text (WINDOW *win, lisp text, int max_w)
{
  if (!stringp (text)) return 0;
  const Char *s = xstring_contents (text);
  int len = xstring_length (text);
  int col = 0;
  for (int i = 0; i < len && col < max_w; i++)
    {
      Char c = s[i];
      if (c == '&' && i + 1 < len)
        {
          i++;
          c = s[i];
        }
      if (c < 0x20) continue;
      if (c < 0x80)
        {
          waddch (win, (chtype)c);
          col++;
        }
      else
        {
          ucs2_t wc = i2w (c);
          int cw = wcwidth ((wchar_t)wc);
          if (cw <= 0) cw = 1;
          if (col + cw > max_w) break;
          wchar_t ws[2] = {(wchar_t)wc, 0};
          waddnwstr (win, ws, 1);
          col += cw;
        }
    }
  return col;
}

// Render Char buffer to ncurses, return display width
static int
render_chars (WINDOW *win, const Char *buf, int len, int max_w)
{
  int col = 0;
  for (int i = 0; i < len && col < max_w; i++)
    {
      Char c = buf[i];
      if (c < 0x20) continue;
      if (c < 0x80)
        {
          waddch (win, (chtype)c);
          col++;
        }
      else
        {
          ucs2_t wc = i2w (c);
          int cw = wcwidth ((wchar_t)wc);
          if (cw <= 0) cw = 1;
          if (col + cw > max_w) break;
          wchar_t ws[2] = {(wchar_t)wc, 0};
          waddnwstr (win, ws, 1);
          col += cw;
        }
    }
  return col;
}

// Compute display width of Char buffer
static int
chars_display_width (const Char *buf, int len)
{
  int w = 0;
  for (int i = 0; i < len; i++)
    {
      Char c = buf[i];
      if (c < 0x20) continue;
      if (c < 0x80)
        w++;
      else
        {
          ucs2_t wc = i2w (c);
          int cw = wcwidth ((wchar_t)wc);
          w += (cw > 0) ? cw : 1;
        }
    }
  return w;
}

// Display width of lisp string (stripping &)
static int
text_display_width (lisp text)
{
  if (!stringp (text)) return 0;
  const Char *s = xstring_contents (text);
  int len = xstring_length (text);
  int w = 0;
  for (int i = 0; i < len; i++)
    {
      Char c = s[i];
      if (c == '&' && i + 1 < len) { i++; c = s[i]; }
      if (c < 0x20) continue;
      if (c < 0x80) w++;
      else
        {
          ucs2_t wc = i2w (c);
          int cw = wcwidth ((wchar_t)wc);
          w += (cw > 0) ? cw : 1;
        }
    }
  return w;
}

// Copy lisp string to Char buffer
static int
copy_to_edit (NcCtl *c, lisp str)
{
  if (stringp (str))
    {
      int len = xstring_length (str);
      if (len > EDIT_MAX - 1) len = EDIT_MAX - 1;
      memcpy (c->ebuf, xstring_contents (str), len * sizeof (Char));
      c->elen = len;
      c->epos = len;
    }
  else if (fixnump (str))
    {
      char buf[32];
      sprintf (buf, "%ld", (long)fixnum_value (str));
      int len = strlen (buf);
      for (int i = 0; i < len && i < EDIT_MAX - 1; i++)
        c->ebuf[i] = buf[i];
      c->elen = len;
      c->epos = len;
    }
  return c->elen;
}

static void
draw_control (WINDOW *win, NcCtl *c, int focused, int win_row_off)
{
  if (!c->visible) return;

  int r = c->row + win_row_off;
  int col = c->col + 1;

  if (c->wclass == Kstatic)
    {
      wmove (win, r, col);
      render_text (win, c->text, c->width);
    }
  else if (c->wclass == Kbutton)
    {
      if (is_checkbox (c))
        {
          wmove (win, r, col);
          if (!c->enabled)
            wattron (win, A_DIM);
          if (focused)
            wattron (win, A_REVERSE);
          char mark = c->checked == 1 ? 'x' : (c->checked == 2 ? '-' : ' ');
          wprintw (win, "[%c] ", mark);
          render_text (win, c->text, c->width - 4);
          if (focused)
            wattroff (win, A_REVERSE);
          if (!c->enabled)
            wattroff (win, A_DIM);
        }
      else if (is_push_button (c))
        {
          wmove (win, r, col);
          if (!c->enabled)
            wattron (win, A_DIM);
          if (focused)
            wattron (win, A_REVERSE);
          waddch (win, '<');
          int tw = render_text (win, c->text, c->width - 2);
          (void)tw;
          waddch (win, '>');
          if (focused)
            wattroff (win, A_REVERSE);
          if (!c->enabled)
            wattroff (win, A_DIM);
        }
      else if ((c->style & 0xf) == BTN_GROUPBOX)
        {
          wmove (win, r, col);
          render_text (win, c->text, c->width);
        }
    }
  else if (is_editable (c))
    {
      wmove (win, r, col);
      if (!c->enabled)
        wattron (win, A_DIM);

      // Compute field width
      int fw = c->width;
      if (fw < 4) fw = 4;

      waddch (win, '[');
      int inner = fw - 2;

      if (focused)
        wattron (win, A_UNDERLINE);

      // Compute scroll offset for display
      int disp_w = chars_display_width (c->ebuf, c->epos);
      int scroll = 0;
      if (disp_w > inner - 1)
        {
          // Find character offset to start display
          int w = 0;
          for (scroll = 0; scroll < c->epos; scroll++)
            {
              Char ch = c->ebuf[scroll];
              int cw = 1;
              if (ch >= 0x80)
                {
                  ucs2_t wc = i2w (ch);
                  cw = wcwidth ((wchar_t)wc);
                  if (cw <= 0) cw = 1;
                }
              w += cw;
              if (w > disp_w - inner + 1) break;
            }
        }

      int rendered = render_chars (win, c->ebuf + scroll, c->elen - scroll, inner);
      for (int j = rendered; j < inner; j++)
        waddch (win, ' ');

      if (focused)
        wattroff (win, A_UNDERLINE);

      waddch (win, ']');
      if (!c->enabled)
        wattroff (win, A_DIM);
    }
  else if (c->wclass == Klistbox)
    {
      wmove (win, r, col);
      if (!c->enabled)
        wattron (win, A_DIM);

      int fw = c->width;
      // Show selected item or "(none)"
      waddch (win, '[');
      int inner = fw - 2;
      if (inner < 2) inner = 2;

      if (focused)
        wattron (win, A_REVERSE);

      if (c->isel >= 0 && c->isel < c->nitem)
        {
          lisp item = c->items;
          for (int i = 0; i < c->isel && consp (item); i++)
            item = xcdr (item);
          if (consp (item))
            {
              lisp val = xcar (item);
              if (consp (val))
                val = xcar (val);
              if (stringp (val))
                render_chars (win, xstring_contents (val),
                              xstring_length (val), inner);
            }
        }
      int x, y;
      getyx (win, y, x);
      (void)y;
      int used = x - (col + 1);
      for (int j = used; j < inner; j++)
        waddch (win, ' ');

      if (focused)
        wattroff (win, A_REVERSE);

      waddch (win, ']');
      if (!c->enabled)
        wattroff (win, A_DIM);
    }
}

// Apply enable/disable logic based on a control's value
static void
apply_enable (NcCtl *ctls, int nctl, NcCtl *src, int has_value)
{
  lisp kwd = src->kwd;

  for (lisp grp = safe_find_keyword (Kenable, kwd); consp (grp); grp = xcdr (grp))
    {
      lisp sym = xcar (grp);
      for (int i = 0; i < nctl; i++)
        if (ctls[i].symid == sym)
          ctls[i].enabled = has_value;
    }

  for (lisp grp = safe_find_keyword (Kdisable, kwd); consp (grp); grp = xcdr (grp))
    {
      lisp sym = xcar (grp);
      for (int i = 0; i < nctl; i++)
        if (ctls[i].symid == sym)
          ctls[i].enabled = !has_value;
    }
}

// Collect dialog results into an alist
// Returns 1 on success (result stored in *out), 0 on validation failure
static int
collect_results (NcCtl *ctls, int nctl, NcCtl *button, lisp *out)
{
  lisp result = Qnil;
  protect_gc gcpro (result);

  if (button && safe_find_keyword (Kno_result, button->kwd) != Qnil)
    {
      *out = result;
      return 1;
    }

  for (int i = nctl - 1; i >= 0; i--)
    {
      NcCtl *c = &ctls[i];
      if (!c->visible || !c->enabled) continue;
      if (c->symid == Qnil) continue;

      lisp val = Qnil;

      if (c->wclass == Kstatic)
        continue;
      else if (c->wclass == Kbutton)
        {
          if (is_checkbox (c))
            {
              int b = c->style & 0xf;
              if (b == BTN_AUTO3STATE || b == BTN_3STATE)
                val = c->checked == 2 ? Kdisable : boole (c->checked == 1);
              else
                val = boole (c->checked == 1);
            }
          else
            continue;
        }
      else if (is_editable (c))
        {
          // Check non-null
          lisp non_null = safe_find_keyword (Knon_null, c->kwd);
          if (c->elen == 0 && non_null != Qnil)
            {
              if (stringp (non_null))
                warn_msgbox (non_null);
              return 0; // validation failed
            }

          // Check type
          lisp type = safe_find_keyword (Ktype, c->kwd);
          if (type == Qinteger)
            {
              // Convert to C string for parsing
              char buf[64];
              int j = 0;
              for (int k = 0; k < c->elen && j < 62; k++)
                {
                  Char ch = c->ebuf[k];
                  if (ch < 0x80) buf[j++] = (char)ch;
                }
              buf[j] = 0;

              int n;
              if (check_integer_format (buf, &n))
                {
                  long t;
                  if (safe_fixnum_value (safe_find_keyword (Kmin, c->kwd), &t) && n < t)
                    {
                      lisp err = safe_find_keyword (Krange_error, c->kwd);
                      if (stringp (err)) warn_msgbox (err);
                      return 0;
                    }
                  if (safe_fixnum_value (safe_find_keyword (Kmax, c->kwd), &t) && n > t)
                    {
                      lisp err = safe_find_keyword (Krange_error, c->kwd);
                      if (stringp (err)) warn_msgbox (err);
                      return 0;
                    }
                  val = make_fixnum (n);
                }
              else
                {
                  lisp err = safe_find_keyword (Ktype_error, c->kwd);
                  if (stringp (err)) warn_msgbox (err);
                  return 0;
                }
            }
          else
            val = make_string (c->ebuf, c->elen);
        }
      else if (c->wclass == Klistbox)
        {
          lisp must_match = safe_find_keyword (Kmust_match, c->kwd);
          if (c->isel < 0 && must_match != Qnil)
            {
              if (stringp (must_match)) warn_msgbox (must_match);
              return 0;
            }
          if (c->isel >= 0 && c->isel < c->nitem)
            {
              lisp item = c->items;
              for (int k = 0; k < c->isel && consp (item); k++)
                item = xcdr (item);
              if (consp (item))
                {
                  lisp v = xcar (item);
                  if (safe_find_keyword (Kindex, c->kwd) != Qnil)
                    val = make_fixnum (c->isel);
                  else if (consp (v))
                    val = xcar (v);
                  else
                    val = v;
                }
            }
        }

      if (val != Qnil || is_editable (c) || is_checkbox (c))
        result = xcons (xcons (c->symid, val), result);
    }

  *out = result;
  return 1;
}

lisp
Fdialog_box (lisp dialog, lisp init, lisp handlers)
{
  // Parse template: (dialog X Y W H options...)
  lisp d = dialog;
  if (xlist_length (d) < 5)
    FEprogram_error (Einvalid_dialog_format, d);
  if (xcar (d) != Qdialog)
    FEtype_error (xcar (d), Qdialog);
  d = xcdr (d);

  int dlg_x = fixnum_value (xcar (d)); d = xcdr (d);
  int dlg_y = fixnum_value (xcar (d)); d = xcdr (d);
  int dlg_w = fixnum_value (xcar (d)); d = xcdr (d);
  int dlg_h = fixnum_value (xcar (d)); d = xcdr (d);
  (void)dlg_x; (void)dlg_y;
  lisp caption = Qnil;
  static NcCtl ctls[CTL_MAX];
  int nctl = 0;

  // Parse options: :caption, :font, :control
  for (; consp (d); d = xcdr (d))
    {
      lisp x = xcar (d);
      check_cons (x);
      if (xcar (x) == Kcaption)
        {
          if (xlist_length (x) == 2)
            {
              lisp s = xcar (xcdr (x));
              if (stringp (s)) caption = s;
            }
        }
      else if (xcar (x) == Kfont)
        {
          // Ignore font specification
        }
      else if (xcar (x) == Kcontrol)
        {
          for (x = xcdr (x); consp (x) && nctl < CTL_MAX; x = xcdr (x))
            {
              lisp item = xcar (x);
              if (xlist_length (item) != 8)
                FEprogram_error (Einvalid_dialog_item, item);

              NcCtl *c = &ctls[nctl];
              memset (c, 0, sizeof (NcCtl));

              c->wclass = xcar (item); item = xcdr (item);
              c->symid = xcar (item); item = xcdr (item);
              c->text = xcar (item); item = xcdr (item);
              c->style = fixnum_value (xcar (item)); item = xcdr (item);
              c->dx = fixnum_value (xcar (item)); item = xcdr (item);
              c->dy = fixnum_value (xcar (item)); item = xcdr (item);
              c->dw = fixnum_value (xcar (item)); item = xcdr (item);
              c->dh = fixnum_value (xcar (item));

              // Find handler keywords
              c->kwd = Qnil;
              if (c->symid != Qnil)
                {
                  for (lisp p = handlers; consp (p); p = xcdr (p))
                    {
                      lisp h = xcar (p);
                      if (consp (h) && xcar (h) == c->symid)
                        {
                          c->kwd = xcdr (h);
                          break;
                        }
                    }
                }

              c->visible = 1; // WS_VISIBLE (0x10000000) is almost always set
              c->enabled = (c->style & 0x08000000) ? 0 : 1; // WS_DISABLED
              c->items = Qnil;
              c->nitem = 0;
              c->isel = -1;

              // Apply handler :hide/:disable
              if (safe_find_keyword (Khide, c->kwd) == Khide)
                c->visible = 0;
              if (safe_find_keyword (Kdisable, c->kwd) == Kdisable)
                c->enabled = 0;

              // Button initial state
              if (c->wclass == Kbutton && is_checkbox (c))
                {
                  int b = c->style & 0xf;
                  if (b == BTN_AUTO3STATE || b == BTN_3STATE)
                    c->checked = 2; // indeterminate default
                  else
                    c->checked = 0;
                }

              nctl++;
            }
        }
    }

  if (nctl == 0)
    return Qnil;

  // Protect GC
  protect_gc gcpro_caption (caption);
  protect_gc gcpro_init (init);
  protect_gc gcpro_handlers (handlers);
  protect_gc gcpro_dialog (dialog);

  // Convert DLU to character coordinates
  // Approximate: 4 DLU = 1 char width, 8 DLU = 1 char height
  int char_w = (dlg_w + 3) / 4;
  int char_h = (dlg_h + 7) / 8;
  if (char_w < 20) char_w = 20;
  if (char_h < 4) char_h = 4;

  for (int i = 0; i < nctl; i++)
    {
      NcCtl *c = &ctls[i];
      c->col = c->dx / 4;
      c->row = c->dy / 8;
      c->width = c->dw / 4;
      if (c->width < 1) c->width = 1;

      // Ensure push buttons have reasonable width
      if (is_push_button (c))
        {
          int tw = text_display_width (c->text) + 2; // < text >
          if (c->width < tw) c->width = tw;
        }
      // Ensure checkboxes have reasonable width
      if (is_checkbox (c))
        {
          int tw = text_display_width (c->text) + 4; // [x] text
          if (c->width < tw) c->width = tw;
        }
    }

  // Compute actual needed size
  int max_right = 0, max_bottom = 0;
  for (int i = 0; i < nctl; i++)
    {
      int r = ctls[i].col + ctls[i].width;
      int b = ctls[i].row + 1;
      if (r > max_right) max_right = r;
      if (b > max_bottom) max_bottom = b;
    }
  if (char_w < max_right + 1) char_w = max_right + 1;
  if (char_h < max_bottom) char_h = max_bottom;

  // Initialize controls from init-data
  // init is an alist: ((sym . value) ...)
  // Multiple entries for same sym are processed in order
  for (lisp p = init; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (!consp (x)) continue;
      lisp sym = xcar (x);
      lisp val = xcdr (x);

      for (int i = 0; i < nctl; i++)
        {
          NcCtl *c = &ctls[i];
          if (c->symid != sym) continue;

          if (c->wclass == Kbutton)
            {
              if (is_checkbox (c))
                {
                  int b = c->style & 0xf;
                  if (b == BTN_AUTO3STATE || b == BTN_3STATE)
                    c->checked = (val == Kdisable ? 2 : val != Qnil ? 1 : 0);
                  else
                    c->checked = (val != Qnil ? 1 : 0);
                }
              else if (is_push_button (c) && stringp (val))
                {
                  c->text = val;
                }
            }
          else if (is_editable (c))
            {
              if (consp (val) || val == Qnil)
                {
                  // List of items for combobox dropdown
                  c->items = val;
                  c->nitem = 0;
                  for (lisp q = val; consp (q); q = xcdr (q))
                    c->nitem++;
                }
              else if (stringp (val))
                {
                  copy_to_edit (c, val);
                }
              else if (fixnump (val))
                {
                  copy_to_edit (c, val);
                }
            }
          else if (c->wclass == Klistbox)
            {
              if (consp (val) || val == Qnil)
                {
                  c->items = val;
                  c->nitem = 0;
                  for (lisp q = val; consp (q); q = xcdr (q))
                    c->nitem++;
                }
            }
          else if (c->wclass == Kstatic)
            {
              if (stringp (val))
                c->text = val;
            }
        }
    }

  // Apply initial enable/disable from non-null checks
  for (int i = 0; i < nctl; i++)
    {
      NcCtl *c = &ctls[i];
      if (safe_find_keyword (Knon_null, c->kwd) != Qnil)
        {
          int has_value = 0;
          if (is_editable (c))
            has_value = c->elen > 0;
          else if (is_checkbox (c))
            has_value = c->checked == 1;
          apply_enable (ctls, nctl, c, has_value);
        }
      // Checkboxes with :disable keyword affect other controls
      if (is_checkbox (c) && safe_find_keyword (Kdisable, c->kwd) != Qnil)
        apply_enable (ctls, nctl, c, c->checked == 1);
      if (is_checkbox (c) && safe_find_keyword (Kenable, c->kwd) != Qnil)
        apply_enable (ctls, nctl, c, c->checked == 1);
    }

  // Create ncurses window
  int term_rows, term_cols;
  getmaxyx (stdscr, term_rows, term_cols);

  int win_w = char_w + 2;  // +2 for box borders
  int win_h = char_h + 3;  // +2 for box + 1 for title
  if (win_w > term_cols) win_w = term_cols;
  if (win_h > term_rows) win_h = term_rows;

  int win_row = (term_rows - win_h) / 2;
  int win_col = (term_cols - win_w) / 2;
  if (win_row < 0) win_row = 0;
  if (win_col < 0) win_col = 0;

  int content_off = 2;      // controls start at row 2 inside window (0=border, 1=title area)

  WINDOW *win = newwin (win_h, win_w, win_row, win_col);
  if (!win) return Qnil;

  keypad (win, TRUE);

  // Find initial focus
  int focus = -1;
  // Prefer first editable control, then first focusable
  for (int i = 0; i < nctl; i++)
    if (is_focusable (&ctls[i]) && is_editable (&ctls[i]))
      { focus = i; break; }
  if (focus < 0)
    for (int i = 0; i < nctl; i++)
      if (is_focusable (&ctls[i]))
        { focus = i; break; }

  // Draw function
  auto draw_all = [&]() {
    werase (win);
    box (win, 0, 0);

    // Title bar
    if (stringp (caption))
      {
        wmove (win, 0, 2);
        waddch (win, ' ');
        wattron (win, A_BOLD);
        render_text (win, caption, win_w - 6);
        wattroff (win, A_BOLD);
        waddch (win, ' ');
      }

    // Draw controls
    for (int i = 0; i < nctl; i++)
      draw_control (win, &ctls[i], i == focus, content_off);

    // Position cursor for edit fields
    if (focus >= 0 && is_editable (&ctls[focus]))
      {
        NcCtl *c = &ctls[focus];
        // Compute cursor column within field
        int cpos_w = chars_display_width (c->ebuf, c->epos);
        int field_inner = c->width - 2;
        if (cpos_w > field_inner)
          cpos_w = field_inner;
        wmove (win, c->row + content_off, c->col + 2 + cpos_w);
        curs_set (1);
      }
    else
      curs_set (0);

    wrefresh (win);
  };

  // Modal input loop
  lisp retval = Qnil;
  lisp result_data = Qnil;
  protect_gc gcpro_retval (retval);
  protect_gc gcpro_result (result_data);
  int done = 0;

  draw_all ();

  while (!done)
    {
      wint_t wch;
      int ret = wget_wch (win, &wch);

      if (ret == KEY_CODE_YES)
        {
          switch (wch)
            {
            case KEY_BTAB: // Shift-Tab: previous control
              if (focus >= 0)
                {
                  int start = focus;
                  do {
                    focus--;
                    if (focus < 0) focus = nctl - 1;
                  } while (!is_focusable (&ctls[focus]) && focus != start);
                }
              break;

            case KEY_UP:
              if (focus >= 0 && ctls[focus].wclass == Klistbox)
                {
                  NcCtl *c = &ctls[focus];
                  if (c->isel > 0) c->isel--;
                }
              else
                {
                  // Navigate to previous control
                  int start = focus;
                  do {
                    focus--;
                    if (focus < 0) focus = nctl - 1;
                  } while (!is_focusable (&ctls[focus]) && focus != start);
                }
              break;

            case KEY_DOWN:
              if (focus >= 0 && ctls[focus].wclass == Klistbox)
                {
                  NcCtl *c = &ctls[focus];
                  if (c->isel < c->nitem - 1) c->isel++;
                }
              else
                {
                  int start = focus;
                  do {
                    focus++;
                    if (focus >= nctl) focus = 0;
                  } while (!is_focusable (&ctls[focus]) && focus != start);
                }
              break;

            case KEY_LEFT:
              if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  if (c->epos > 0) c->epos--;
                }
              break;

            case KEY_RIGHT:
              if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  if (c->epos < c->elen) c->epos++;
                }
              break;

            case KEY_HOME:
              if (focus >= 0 && is_editable (&ctls[focus]))
                ctls[focus].epos = 0;
              break;

            case KEY_END:
              if (focus >= 0 && is_editable (&ctls[focus]))
                ctls[focus].epos = ctls[focus].elen;
              break;

            case KEY_BACKSPACE:
            case KEY_DC:
              if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  if (wch == KEY_BACKSPACE && c->epos > 0)
                    {
                      memmove (c->ebuf + c->epos - 1, c->ebuf + c->epos,
                               (c->elen - c->epos) * sizeof (Char));
                      c->epos--;
                      c->elen--;
                      apply_enable (ctls, nctl, c, c->elen > 0);
                    }
                  else if (wch == KEY_DC && c->epos < c->elen)
                    {
                      memmove (c->ebuf + c->epos, c->ebuf + c->epos + 1,
                               (c->elen - c->epos - 1) * sizeof (Char));
                      c->elen--;
                      apply_enable (ctls, nctl, c, c->elen > 0);
                    }
                }
              break;

            case KEY_MOUSE:
              {
                MEVENT mev;
                if (getmouse (&mev) == OK
                    && (mev.bstate & (BUTTON1_PRESSED | BUTTON1_CLICKED)))
                  {
                    // Convert screen coords to window-relative
                    int my = mev.y - win_row;
                    int mx = mev.x - win_col;

                    // Find which control was clicked
                    int clicked_ctl = -1;
                    for (int i = 0; i < nctl; i++)
                      {
                        NcCtl *c = &ctls[i];
                        if (!c->visible) continue;
                        int cr = c->row + content_off;
                        int cc = c->col + 1;
                        int cw = c->width;
                        if (is_push_button (c))
                          cw = text_display_width (c->text) + 2;
                        if (my == cr && mx >= cc && mx < cc + cw)
                          { clicked_ctl = i; break; }
                      }

                    if (clicked_ctl >= 0 && is_focusable (&ctls[clicked_ctl]))
                      {
                        NcCtl *c = &ctls[clicked_ctl];
                        focus = clicked_ctl;

                        if (is_push_button (c))
                          {
                            if (c->symid == Qidcancel)
                              { done = 1; break; }
                            if (collect_results (ctls, nctl, c, &result_data))
                              { retval = c->symid; done = 1; }
                          }
                        else if (is_checkbox (c))
                          {
                            int b = c->style & 0xf;
                            if (b == BTN_AUTO3STATE || b == BTN_3STATE)
                              c->checked = (c->checked + 1) % 3;
                            else
                              c->checked = !c->checked;
                            apply_enable (ctls, nctl, c, c->checked == 1);
                          }
                        else if (is_editable (c))
                          {
                            // Position cursor at click point
                            int field_start = c->col + 2; // after '[' border
                            int click_col = mx - field_start;
                            if (click_col < 0) click_col = 0;
                            // Map display column to character position
                            int pos = 0, dcol = 0;
                            for (pos = 0; pos < c->elen; pos++)
                              {
                                Char ch = c->ebuf[pos];
                                int cw2 = 1;
                                if (ch >= 0x80)
                                  {
                                    ucs2_t wc = i2w (ch);
                                    cw2 = wcwidth ((wchar_t)wc);
                                    if (cw2 <= 0) cw2 = 1;
                                  }
                                if (dcol + cw2 > click_col) break;
                                dcol += cw2;
                              }
                            c->epos = pos;
                          }
                        else if (c->wclass == Klistbox)
                          {
                            // Cycle through items on click
                            if (c->nitem > 0)
                              c->isel = (c->isel + 1) % c->nitem;
                          }
                      }
                  }
              }
              break;

            case KEY_RESIZE:
              g_need_resize = 1;
              done = 1;
              break;

            default:
              break;
            }
        }
      else if (ret == OK)
        {
          switch (wch)
            {
            case '\t': // Tab: next control
              if (focus >= 0)
                {
                  int start = focus;
                  do {
                    focus++;
                    if (focus >= nctl) focus = 0;
                  } while (!is_focusable (&ctls[focus]) && focus != start);
                }
              break;

            case '\r':
            case '\n':
              {
                // Enter: activate focused button, or find default button
                NcCtl *btn = 0;

                if (focus >= 0 && is_push_button (&ctls[focus]))
                  btn = &ctls[focus];
                else
                  {
                    // Find default push button (BS_DEFPUSHBUTTON)
                    for (int i = 0; i < nctl; i++)
                      if (is_push_button (&ctls[i]) && ctls[i].enabled
                          && (ctls[i].style & 0xf) == BTN_DEFPUSH)
                        { btn = &ctls[i]; break; }
                    // If no default, find first enabled push button that isn't IDCANCEL
                    if (!btn)
                      for (int i = 0; i < nctl; i++)
                        if (is_push_button (&ctls[i]) && ctls[i].enabled
                            && ctls[i].symid != Qidcancel)
                          { btn = &ctls[i]; break; }
                  }

                if (btn)
                  {
                    if (btn->symid == Qidcancel)
                      {
                        done = 1;
                        break;
                      }

                    // Collect results
                    if (collect_results (ctls, nctl, btn, &result_data))
                      {
                        retval = btn->symid;
                        done = 1;
                      }
                    // else validation failed, stay in dialog
                  }
              }
              break;

            case 0x1b: // Escape
              done = 1;
              break;

            case 0x07: // C-g
              done = 1;
              break;

            case ' ': // Space: toggle checkbox
              if (focus >= 0 && is_checkbox (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  int b = c->style & 0xf;
                  if (b == BTN_AUTO3STATE || b == BTN_3STATE)
                    c->checked = (c->checked + 1) % 3;
                  else
                    c->checked = !c->checked;
                  apply_enable (ctls, nctl, c, c->checked == 1);
                }
              else if (focus >= 0 && is_push_button (&ctls[focus]))
                {
                  NcCtl *btn = &ctls[focus];
                  if (btn->symid == Qidcancel)
                    {
                      done = 1;
                      break;
                    }
                  if (collect_results (ctls, nctl, btn, &result_data))
                    {
                      retval = btn->symid;
                      done = 1;
                    }
                }
              else if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  if (c->elen < EDIT_MAX - 1)
                    {
                      memmove (c->ebuf + c->epos + 1, c->ebuf + c->epos,
                               (c->elen - c->epos) * sizeof (Char));
                      c->ebuf[c->epos] = ' ';
                      c->epos++;
                      c->elen++;
                      apply_enable (ctls, nctl, c, c->elen > 0);
                    }
                }
              break;

            case 0x7f: // DEL (backspace on many terminals)
              if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  if (c->epos > 0)
                    {
                      memmove (c->ebuf + c->epos - 1, c->ebuf + c->epos,
                               (c->elen - c->epos) * sizeof (Char));
                      c->epos--;
                      c->elen--;
                      apply_enable (ctls, nctl, c, c->elen > 0);
                    }
                }
              break;

            case 0x15: // C-u: clear edit field
              if (focus >= 0 && is_editable (&ctls[focus]))
                {
                  NcCtl *c = &ctls[focus];
                  c->elen = 0;
                  c->epos = 0;
                  apply_enable (ctls, nctl, c, 0);
                }
              break;

            case 0x01: // C-a: beginning of line
              if (focus >= 0 && is_editable (&ctls[focus]))
                ctls[focus].epos = 0;
              break;

            case 0x05: // C-e: end of line
              if (focus >= 0 && is_editable (&ctls[focus]))
                ctls[focus].epos = ctls[focus].elen;
              break;

            default:
              // Printable character → insert into edit field
              if (focus >= 0 && is_editable (&ctls[focus]) && wch >= 0x20)
                {
                  NcCtl *c = &ctls[focus];
                  if (c->elen < EDIT_MAX - 1)
                    {
                      Char ch;
                      if (wch < 0x80)
                        ch = (Char)wch;
                      else
                        ch = w2i ((ucs2_t)wch);

                      memmove (c->ebuf + c->epos + 1, c->ebuf + c->epos,
                               (c->elen - c->epos) * sizeof (Char));
                      c->ebuf[c->epos] = ch;
                      c->epos++;
                      c->elen++;
                      apply_enable (ctls, nctl, c, c->elen > 0);
                    }
                }
              break;
            }
        }

      if (!done)
        draw_all ();
    }

  delwin (win);
  curs_set (1);
  touchwin (stdscr);
  refresh_screen (1);

  QUIT;

  if (retval == Qnil)
    return Qnil;

  multiple_value::count () = 2;
  multiple_value::value (1) = result_data;
  return retval;
}
