#include "stdafx.h"
#include "ed.h"
#include "ldialog.h"
#include "ColorDialog.h"
#include "privctrl.h"

dlgctrl *
Dialog::get_item (int id) const
{
  for (lisp p = d_item; consp (p); p = xcdr (p))
    if (((dlgctrl *)xcar (p))->id () == id)
      return (dlgctrl *)xcar (p);
  return 0;
}

dlgctrl *
Dialog::get_item (lisp symid) const
{
  for (lisp p = d_item; consp (p); p = xcdr (p))
    if (((dlgctrl *)xcar (p))->symid () == symid)
      return (dlgctrl *)xcar (p);
  return 0;
}

lisp
Dialog::warn (lisp msg)
{
  if (stringp (msg))
    warn_msgbox (msg);
  return 0;
}

void
Dialog::enable_windows (dlgctrl *c, int status)
{
  lisp kwd = c->keyword ();
  for (lisp grp = safe_find_keyword (Kenable, kwd); consp (grp); grp = xcdr (grp))
    {
      dlgctrl *x = get_item (xcar (grp));
      if (x)
        {
          HWND hwnd = GetDlgItem (d_hwnd, x->id ());
          EnableWindow (hwnd, status);
          InvalidateRect (hwnd, 0, 0);
        }
    }

  for (lisp grp = safe_find_keyword (Kdisable, kwd); consp (grp); grp = xcdr (grp))
    {
      dlgctrl *x = get_item (xcar (grp));
      if (x)
        {
          HWND hwnd = GetDlgItem (d_hwnd, x->id ());
          EnableWindow (hwnd, !status);
          InvalidateRect (hwnd, 0, 0);
        }
    }
}

void
Dialog::invalidate_ctrls (dlgctrl *c)
{
  for (lisp grp = safe_find_keyword (Kinvalidate, c->keyword ()); consp (grp); grp = xcdr (grp))
    {
      dlgctrl *x = get_item (xcar (grp));
      if (x)
        {
          lisp wclass = x->wclass ();
          with_ctl (wclass, invalidate (x), (void));
        }
    }
}

int
Dialog::send_ltext (int id, int msg, WPARAM wparam, lisp init, dlg_txtwidth *dt) const
{
  if (init != Qnil && symbolp (init))
    init = xsymbol_name (init);
  if (char_encoding_p (init))
    init = xchar_encoding_display_name (init);
  if (stringp (init))
    {
      /* Phase 2: Lisp string は UTF-16。w2s→cp932→wchar の roundtrip は
         dialog listbox items / ラベル等で mojibake の原因になる。
         xstring_contents を直接 SendDlgItemMessageW に渡す。 */
      int wl = xstring_length (init);
      wchar_t *wb = (wchar_t *)alloca ((wl + 1) * sizeof (wchar_t));
      memcpy (wb, xstring_contents (init), wl * sizeof (wchar_t));
      wb[wl] = 0;
      if (dt)
        {
          SIZE sz;
          if (GetTextExtentPoint32W (dt->hdc, wb, wl, &sz)
              && sz.cx > dt->l)
            dt->l = sz.cx;
        }
      return SendDlgItemMessageW (d_hwnd, id, msg, wparam, LPARAM (wb));
    }
  else
    return SendDlgItemMessageW (d_hwnd, id, msg, wparam, LPARAM (L""));
}

void
Dialog::button_pre_init (dlgctrl *c)
{
  switch (c->style () & 0xf)
    {
    case BS_AUTOCHECKBOX:
    case BS_AUTORADIOBUTTON:
      SendDlgItemMessage (d_hwnd, c->id (), BM_SETCHECK, 0, 0);
      break;

    case BS_AUTO3STATE:
      SendDlgItemMessage (d_hwnd, c->id (), BM_SETCHECK, 2, 0);
      break;
    }
}

void
Dialog::button_init (dlgctrl *c, lisp init)
{
  switch (c->style () & 0xf)
    {
    case BS_AUTOCHECKBOX:
    case BS_AUTORADIOBUTTON:
      SendDlgItemMessage (d_hwnd, c->id (), BM_SETCHECK, init != Qnil, 0);
      break;

    case BS_AUTO3STATE:
      SendDlgItemMessage (d_hwnd, c->id (), BM_SETCHECK,
                          (init == Kdisable ? 2 : init != Qnil), 0);
      break;

    case BS_PUSHBUTTON:
    case BS_DEFPUSHBUTTON:
    case BS_GROUPBOX:
      send_ltext (c->id (), WM_SETTEXT, 0, init);
      break;
    }
}

static lisp
get_window_text (HWND dlg, int id)
{
  HWND hwnd = GetDlgItem (dlg, id);
  int l = max (0L, SendMessageW (hwnd, WM_GETTEXTLENGTH, 0, 0)) + 2;
  wchar_t *wb = (wchar_t *)alloca (l * sizeof (wchar_t));
  *wb = 0;
  GetWindowTextW (hwnd, wb, l);
  if (*wb)
    {
      int al = WideCharToMultiByte (932, 0, wb, -1, 0, 0, 0, 0);
      char *b = (char *)alloca (al);
      WideCharToMultiByte (932, 0, wb, -1, b, al, 0, 0);
      return make_string (b);
    }
  return Qnil;
}

int
Dialog::button_push (dlgctrl *c)
{
  lisp kwd = c->keyword ();
  lisp (LISP_CALL *fn)(lisp);
  lisp args = safe_find_keyword (Kfile_name_dialog, kwd);
  if (args != Qnil)
    fn = Ffile_name_dialog;
  else
    {
      args = safe_find_keyword (Kdirectory_name_dialog, kwd);
      if (args != Qnil)
        fn = Fdirectory_name_dialog;
      else
        return 0;
    }

  try
    {
      dlgctrl *r = get_item (safe_find_keyword (Krelated, kwd));
      if (r)
        {
          lisp s = get_window_text (d_hwnd, r->id ());
          if (s != Qnil)
            args = xcons (Kdefault, xcons (s, args));
        }
      protect_gc gcpro1 (args);
      lisp result = (*fn)(args);
      if (result != Qnil && r)
        {
          send_ltext (r->id (), WM_SETTEXT, 0, result);
          enable_windows (r, 1);
          invalidate_ctrls (r);
        }
    }
  catch (nonlocal_jump &)
    {
      print_condition (nonlocal_jump::data ());
    }
  return 1;
}

void
Dialog::button_command (dlgctrl *c, UINT msg)
{
  switch (c->style () & 0xf)
    {
    case BS_PUSHBUTTON:
    case BS_DEFPUSHBUTTON:
      if (msg == BN_CLICKED && !button_push (c)
          && d_can_close && get_result (c))
        EndDialog (d_hwnd, IDOK);
      break;

    case BS_AUTORADIOBUTTON:
      if (SendDlgItemMessage (d_hwnd, c->id (), BM_GETCHECK, 0, 0) == 1)
        {
          enable_windows (c, 1);
          invalidate_ctrls (c);
        }
      break;

    case BS_AUTOCHECKBOX:
    case BS_AUTO3STATE:
      {
        int checked = SendDlgItemMessage (d_hwnd, c->id (), BM_GETCHECK, 0, 0) == 1;
        enable_windows (c, checked);
        if (checked)
          invalidate_ctrls (c);
        break;
      }
    }
}

lisp
Dialog::button_result (dlgctrl *c)
{
  switch (c->style () & 0xf)
    {
    case BS_AUTOCHECKBOX:
    case BS_AUTORADIOBUTTON:
      return boole (SendDlgItemMessage (d_hwnd, c->id (), BM_GETCHECK, 0, 0) == 1);

    case BS_AUTO3STATE:
      switch (SendDlgItemMessage (d_hwnd, c->id (), BM_GETCHECK, 0, 0))
        {
        case 2:
          return Kdisable;
        case 1:
          return Qt;
        default:
          return Qnil;
        }
      break;

    default:
      return Qnil;
    }
}

inline void
Dialog::button_invalidate (class dlgctrl *)
{
}

void
Dialog::edit_pre_init (dlgctrl *c)
{
  int id = c->id ();
  lisp kwd = c->keyword ();

  long n;
  if (safe_fixnum_value (safe_find_keyword (Klimit, kwd), &n) && n > 0)
    SendDlgItemMessage (d_hwnd, id, EM_LIMITTEXT, n, 0);

  lisp x = safe_find_keyword (Kpassword_char, kwd);
  if (charp (x))
    SendDlgItemMessage (d_hwnd, id, EM_SETPASSWORDCHAR, xchar_code (x), 0);
}

void
Dialog::edit_init (dlgctrl *c, lisp init)
{
  send_ltext (c->id (), WM_SETTEXT, 0, init);
}

void
Dialog::edit_command (dlgctrl *c, UINT msg)
{
  switch (msg)
    {
    case -1:
    case EN_KILLFOCUS:
    case EN_CHANGE:
      {
        wchar_t buf[10];
        *buf = 0;
        GetDlgItemTextW (d_hwnd, c->id (), buf, 10);
        if (safe_find_keyword (Knon_null, c->keyword ()) != Qnil)
          enable_windows (c, *buf);
        if (*buf)
          invalidate_ctrls (c);
      }
      break;
    }
}

lisp
Dialog::check_result_type (dlgctrl *c, const char *s)
{
  lisp kwd = c->keyword ();
  lisp type = safe_find_keyword (Ktype, kwd);
  if (type != Qinteger)
    return make_string (s);

  int n;
  if (check_integer_format (s, &n))
    {
      long t;
      if ((!safe_fixnum_value (safe_find_keyword (Kmin, kwd), &t) || n >= t)
          && (!safe_fixnum_value (safe_find_keyword (Kmax, kwd), &t) || n <= t))
        return make_fixnum (n);
      return warn (safe_find_keyword (Krange_error, kwd));
    }

  return warn (safe_find_keyword (Ktype_error, kwd));
}

lisp
Dialog::edit_result (dlgctrl *c)
{
  HWND hwnd = GetDlgItem (d_hwnd, c->id ());
  int l = max (0L, SendMessageW (hwnd, WM_GETTEXTLENGTH, 0, 0)) + 2;
  wchar_t *wb = (wchar_t *)alloca (l * sizeof (wchar_t));
  GetWindowTextW (hwnd, wb, l);
  int al = WideCharToMultiByte (932, 0, wb, -1, 0, 0, 0, 0);
  char *b = (char *)alloca (al);
  WideCharToMultiByte (932, 0, wb, -1, b, al, 0, 0);
  lisp kwd = c->keyword ();
  lisp non_null = safe_find_keyword (Knon_null, kwd);
  if (!*b && non_null != Qnil)
    return warn (non_null);
  return check_result_type (c, b);
}

inline void
Dialog::edit_invalidate (class dlgctrl *c)
{
  SetDlgItemTextW (d_hwnd, c->id (), L"");
}

inline void
Dialog::static_pre_init (dlgctrl *)
{
}

void
Dialog::static_init (dlgctrl *c, lisp init)
{
  send_ltext (c->id (), WM_SETTEXT, 0, init);
}

inline void
Dialog::static_command (dlgctrl *, UINT)
{
}

inline lisp
Dialog::static_result (dlgctrl *)
{
  return Qnil;
}

inline void
Dialog::static_invalidate (class dlgctrl *)
{
}

inline void
Dialog::link_pre_init (dlgctrl *)
{
}

void
Dialog::link_init (dlgctrl *c, lisp init)
{
  send_ltext (c->id (), WM_SETTEXT, 0, init);
}

void
Dialog::link_command (dlgctrl *c, UINT msg)
{
  if (msg != URLN_CLICKED)
    return;
  lisp lurl = safe_find_keyword (Kurl, c->keyword ());
  if (!stringp (lurl))
    return;
  /* Phase 2: Lisp URL は UTF-16。ShellExecuteW に直接渡す。 */
  int ulen = xstring_length (lurl);
  if (ulen >= MAX_PATH) ulen = MAX_PATH - 1;
  wchar_t wurl[MAX_PATH];
  memcpy (wurl, xstring_contents (lurl), ulen * sizeof (wchar_t));
  wurl[ulen] = 0;
  Fbegin_wait_cursor ();
  ShellExecuteW (get_active_window (), L"open", wurl, 0, 0, SW_SHOWNORMAL);
  Fend_wait_cursor ();
}

inline lisp
Dialog::link_result (dlgctrl *)
{
  return Qnil;
}

inline void
Dialog::link_invalidate (class dlgctrl *)
{
}

void
Dialog::listbox_pre_init (dlgctrl *c)
{
  if (!(c->style () & LBS_OWNERDRAWFIXED))
    return;

  int width = 0;
  lisp columns = safe_find_keyword (Kcolumn, c->keyword ());
  for (; consp (columns); columns = xcdr (columns))
    {
      QUIT;
      long x;
      if (!safe_fixnum_value (xcar (columns), &x))
        return;
      if (x < 0)
        x = -x;
      width += x + 1;
    }
  if (!width)
    return;

  HDC hdc = GetDC (d_hwnd);
  HFONT hfont = HFONT (SendMessage (d_hwnd, WM_GETFONT, 0, 0));
  HGDIOBJ ofont = SelectObject (hdc, hfont);
  TEXTMETRIC tm;
  GetTextMetrics (hdc, &tm);
  SelectObject (hdc, ofont);
  ReleaseDC (d_hwnd, hdc);

  SendDlgItemMessage (d_hwnd, c->id (), LB_SETHORIZONTALEXTENT,
                      width * tm.tmAveCharWidth, 0);
}

void
Dialog::listbox_init (dlgctrl *c, lisp init)
{
  int id = c->id ();
  DWORD style = c->style ();
  if (style & LBS_OWNERDRAWFIXED)
    {
      if (init == Qnil || (consp (init) && consp (xcar (init))))
        for (; consp (init); init = xcdr (init))
          SendDlgItemMessage (d_hwnd, id, LB_ADDSTRING, 0, LPARAM (xcar (init)));
      else
        {
          int nitems = SendDlgItemMessage (d_hwnd, id, LB_GETCOUNT, 0, 0);
          for (int i = 0; i < nitems; i++)
            if (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0) == LONG (init))
              {
                if (style & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL))
                  SendDlgItemMessage (d_hwnd, id, LB_SETSEL, 1, i);
                else
                  SendDlgItemMessage (d_hwnd, id, LB_SETCURSEL, i, 0);
                break;
              }
        }
    }
  else
    {
      if (consp (init) || init == Qnil)
        {
          dlg_txtwidth dt, *dtp = 0;
          HGDIOBJ of = 0;
          if (style & WS_HSCROLL)
            {
              dt.hdc = GetDC (d_hwnd);
              HFONT hf = HFONT (SendMessage (d_hwnd, WM_GETFONT, 0, 0));
              if (hf)
                of = SelectObject (dt.hdc, hf);
              dt.l = 0;
              dtp = &dt;
            }
          for (int i = 0; consp (init); init = xcdr (init), i++)
            {
              int idx = send_ltext (id, LB_ADDSTRING, 0, xcar (init), dtp);
              if (idx != LB_ERR)
                SendDlgItemMessage (d_hwnd, id, LB_SETITEMDATA, idx, i);
            }
          if (style & WS_HSCROLL)
            {
              if (of)
                SelectObject (dt.hdc, of);
              ReleaseDC (d_hwnd, dt.hdc);
              SendDlgItemMessage (d_hwnd, id, LB_SETHORIZONTALEXTENT, dt.l + 4, 0);
            }
        }
      else
        {
          long n;
          if (safe_fixnum_value (init, &n) && n >= 0)
            {
              int nitems = SendDlgItemMessage (d_hwnd, id, LB_GETCOUNT, 0, 0);
              for (int i = 0; i < nitems; i++)
                if (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0) == n)
                  {
                    if (style & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL))
                      SendDlgItemMessage (d_hwnd, id, LB_SETSEL, 1, i);
                    else
                      SendDlgItemMessage (d_hwnd, id, LB_SETCURSEL, i, 0);
                    break;
                  }
            }
        }
    }
}

void
Dialog::listbox_command (dlgctrl *c, UINT msg)
{
  switch (msg)
    {
    case -1:
    case LBN_KILLFOCUS:
    case LBN_SELCHANGE:
      {
        int selected = (c->style () & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL)
                        ? SendDlgItemMessage (d_hwnd, c->id (), LB_GETSELCOUNT, 0, 0) > 0
                        : SendDlgItemMessage (d_hwnd, c->id (), LB_GETCURSEL, 0, 0) != LB_ERR);
        if (safe_find_keyword (Kmust_match, c->keyword ()) != Qnil)
          enable_windows (c, selected);
        if (selected)
          invalidate_ctrls (c);
        break;
      }

    case LBN_DBLCLK:
      {
        DWORD def = SendMessage (d_hwnd, DM_GETDEFID, 0, 0);
        if (HIWORD (def) == DC_HASDEFID)
          PostMessage (d_hwnd, WM_COMMAND, MAKELONG (LOWORD (def), 0),
                       LPARAM (GetDlgItem (d_hwnd, LOWORD (def))));
        break;
      }
    }
}

lisp
Dialog::make_lb_string (int id, int getlen, int gettext, int idx)
{
  int l = max (0L, SendDlgItemMessageW (d_hwnd, id, getlen, idx, 0)) + 2;
  wchar_t *wb = (wchar_t *)alloca (l * sizeof (wchar_t));
  if (SendDlgItemMessageW (d_hwnd, id, gettext, idx, LPARAM (wb)) == LB_ERR)
    *wb = 0;
  int al = WideCharToMultiByte (932, 0, wb, -1, 0, 0, 0, 0);
  char *b = (char *)alloca (al);
  WideCharToMultiByte (932, 0, wb, -1, b, al, 0, 0);
  return make_string (b);
}

lisp
Dialog::listbox_result (dlgctrl *c)
{
  int id = c->id ();
  lisp kwd = c->keyword ();
  lisp must_match = safe_find_keyword (Kmust_match, kwd);
  int idx = safe_find_keyword (Kindex, kwd) != Qnil;
  DWORD style = c->style ();
  if (style & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL))
    {
      if (must_match != Qnil
          && SendDlgItemMessage (d_hwnd, id, LB_GETSELCOUNT, 0, 0) <= 0)
        return warn (must_match);

      int nitems = SendDlgItemMessage (d_hwnd, id, LB_GETCOUNT, 0, 0);
      if (nitems == LB_ERR)
        return Qnil;

      lisp r = Qnil;
      for (int i = 0; i < nitems; i++)
        if (SendDlgItemMessage (d_hwnd, id, LB_GETSEL, i, 0) > 0)
          r = xcons ((style & LBS_OWNERDRAWFIXED
                      ? lisp (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0))
                      : (idx
                         ? make_fixnum (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0))
                         : make_lb_string (id, LB_GETTEXTLEN, LB_GETTEXT, i))),
                     r);
      return r;
    }
  else
    {
      int i = SendDlgItemMessage (d_hwnd, id, LB_GETCURSEL, 0, 0);
      if (i == LB_ERR)
        return must_match == Qnil ? Qnil : warn (must_match);
      if (style & LBS_OWNERDRAWFIXED)
        return lisp (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0));
      if (idx)
        return make_fixnum (SendDlgItemMessage (d_hwnd, id, LB_GETITEMDATA, i, 0));
      return make_lb_string (id, LB_GETTEXTLEN, LB_GETTEXT, i);
    }
}

void
Dialog::listbox_invalidate (class dlgctrl *c)
{
  int id = c->id ();
  if (c->style () & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL))
    {
      int nitems = SendDlgItemMessage (d_hwnd, id, LB_GETCOUNT, 0, 0);
      for (int i = 0; i < nitems; i++)
        SendDlgItemMessage (d_hwnd, id, LB_SETSEL, 0, i);
    }
  else
    SendDlgItemMessage (d_hwnd, id, LB_SETCURSEL, WPARAM (-1), 0);
}

void
Dialog::combobox_pre_init (dlgctrl *c)
{
  long n;
  if (safe_fixnum_value (safe_find_keyword (Klimit, c->keyword ()), &n)
      && n > 0)
    SendDlgItemMessage (d_hwnd, c->id (), CB_LIMITTEXT, n, 0);
//  if (c->style () & CBS_OWNERDRAWFIXED)
//    ;
}

void
Dialog::combobox_init (dlgctrl *c, lisp init)
{
  int id = c->id ();
  if (c->style () & CBS_OWNERDRAWFIXED)
    {
      if (init == Qnil || (consp (init) && consp (xcar (init))))
        for (; consp (init); init = xcdr (init))
          SendDlgItemMessage (d_hwnd, id, CB_ADDSTRING, 0, LPARAM (xcar (init)));
      else
        {
          int nitems = SendDlgItemMessage (d_hwnd, id, CB_GETCOUNT, 0, 0);
          for (int i = 0; i < nitems; i++)
            if (SendDlgItemMessage (d_hwnd, id, CB_GETITEMDATA, i, 0) == LONG (init))
              {
                SendDlgItemMessage (d_hwnd, id, CB_SETCURSEL, i, 0);
                break;
              }
        }
    }
  else
    {
      if (consp (init) || init == Qnil)
        for (int i = 0; consp (init); init = xcdr (init), i++)
          {
            int idx = send_ltext (id, CB_ADDSTRING, 0, xcar (init));
            if (idx != CB_ERR)
              SendDlgItemMessage (d_hwnd, id, CB_SETITEMDATA, idx, i);
          }
      else
        {
          long n;
          if (safe_fixnum_value (init, &n) && n >= 0)
            {
              int nitems = SendDlgItemMessage (d_hwnd, id, CB_GETCOUNT, 0, 0);
              for (int i = 0; i < nitems; i++)
                if (SendDlgItemMessage (d_hwnd, id, CB_GETITEMDATA, i, 0) == n)
                  {
                    SendDlgItemMessage (d_hwnd, id, CB_SETCURSEL, i, 0);
                    break;
                  }
            }
          else
            send_ltext (id, WM_SETTEXT, 0, init);
        }
    }
}

void
Dialog::combobox_command (dlgctrl *c, UINT msg)
{
  switch (msg)
    {
    case -1:
    case CBN_KILLFOCUS:
    case CBN_EDITCHANGE:
      {
        wchar_t buf[10];
        if (SendDlgItemMessageW (d_hwnd, c->id (), WM_GETTEXT, 10, LPARAM (buf)) >= 0)
          {
            if (safe_find_keyword (Knon_null, c->keyword ()) != Qnil)
              enable_windows (c, *buf);
            if (*buf)
              invalidate_ctrls (c);
            break;
          }
      }
      /* fall thru... */
    case CBN_SELENDOK:
      {
        lisp kwd = c->keyword ();
        int selected = SendDlgItemMessage (d_hwnd, c->id (), CB_GETCURSEL, 0, 0) != CB_ERR;
        if (safe_find_keyword (Knon_null, kwd) != Qnil
            || safe_find_keyword (Kmust_match, kwd) != Qnil)
          enable_windows (c, selected);
        if (selected)
          invalidate_ctrls (c);
        break;
      }

    case CBN_DBLCLK:
      {
        DWORD def = SendMessage (d_hwnd, DM_GETDEFID, 0, 0);
        if (HIWORD (def) == DC_HASDEFID)
          PostMessage (d_hwnd, WM_COMMAND, MAKELONG (LOWORD (def), 0),
                       LPARAM (GetDlgItem (d_hwnd, LOWORD (def))));
        break;
      }
    }
}

lisp
Dialog::combobox_result (dlgctrl *c)
{
  int id = c->id ();
  lisp kwd = c->keyword ();
  int idx = safe_find_keyword (Kindex, kwd) != Qnil;
  lisp must_match = safe_find_keyword (Kmust_match, kwd);
  lisp non_null = safe_find_keyword (Knon_null, kwd);

  if (idx)
    {
      int i = SendDlgItemMessage (d_hwnd, id, CB_GETCURSEL, 0, 0);
      if (i == CB_ERR)
        return must_match == Qnil ? Qnil : warn (must_match);
      return make_fixnum (SendDlgItemMessage (d_hwnd, id, CB_GETITEMDATA, i, 0));
    }

  if (c->style () & CBS_OWNERDRAWFIXED)
    {
      int i = SendDlgItemMessage (d_hwnd, id, CB_GETCURSEL, 0, 0);
      if (i == CB_ERR)
        return must_match == Qnil ? Qnil : warn (must_match);
      return lisp (SendDlgItemMessage (d_hwnd, id, CB_GETITEMDATA, i, 0));
    }
  else
    {
      int l = max (0L, SendDlgItemMessageW (d_hwnd, id, WM_GETTEXTLENGTH, 0, 0)) + 2;
      wchar_t *wb = (wchar_t *)alloca (l * sizeof (wchar_t));
      *wb = 0;

      if (SendDlgItemMessageW (d_hwnd, id, WM_GETTEXT, l, LPARAM (wb)) >= 0)
        {
          int al = WideCharToMultiByte (932, 0, wb, -1, 0, 0, 0, 0);
          char *b = (char *)alloca (al);
          WideCharToMultiByte (932, 0, wb, -1, b, al, 0, 0);
          if (!*b && non_null != Qnil)
            return warn (non_null);
          if (must_match != Qnil && SendDlgItemMessageW (d_hwnd, id, CB_FINDSTRINGEXACT,
                                                         WPARAM (-1), LPARAM (wb)) == CB_ERR)
            return warn (must_match);
          return check_result_type (c, b);
        }
      else
        {
          int i = SendDlgItemMessage (d_hwnd, id, CB_GETCURSEL, 0, 0);
          if (i == CB_ERR)
            return must_match == Qnil ? Qnil : warn (must_match);
          return make_lb_string (id, CB_GETLBTEXTLEN, CB_GETLBTEXT, i);
        }
    }
}

void
Dialog::combobox_invalidate (class dlgctrl *c)
{
  int id = c->id ();
  if ((c->style () & 3) != CBS_DROPDOWNLIST)
    SetDlgItemTextW (d_hwnd, id, L"");
  SendDlgItemMessage (d_hwnd, id, CB_SETCURSEL, WPARAM (-1), 0);
}

void
Dialog::spin_pre_init (dlgctrl *c)
{
  int id = c->id ();
  lisp kwd = c->keyword ();
  long mn, mx;
  if (safe_fixnum_value (safe_find_keyword (Kmin, kwd), &mn)
      && safe_fixnum_value (safe_find_keyword (Kmax, kwd), &mx))
    SendDlgItemMessage (d_hwnd, id, UDM_SETRANGE, 0,
                        MAKELONG (short (mx), short (mn)));
}

void
Dialog::spin_init (dlgctrl *c, lisp init)
{
  long val;
  if (safe_fixnum_value (init, &val))
    {
      int id = c->id ();
      SendDlgItemMessage (d_hwnd, id, UDM_SETPOS, 0, MAKELONG (short (val), 0));
      if (c->style () & UDS_SETBUDDYINT)
        {
          HWND hwnd = HWND (SendDlgItemMessage (d_hwnd, id, UDM_GETBUDDY, 0, 0));
          if (hwnd)
            {
              char b[32];
              sprintf (b, "%d", val);
              {
                WideStr wb (b);
                SetWindowTextW (hwnd, wb);
              }
            }
        }
    }
}

void
Dialog::spin_command (dlgctrl *, NMHDR *)
{
}

lisp
Dialog::spin_result (dlgctrl *c)
{
  if (c->style () & UDS_SETBUDDYINT)
    return Qnil;
  return make_fixnum (SendDlgItemMessage (d_hwnd, c->id (), UDM_GETPOS, 0, 0));
}

inline void
Dialog::spin_invalidate (class dlgctrl *)
{
}

void
Dialog::init_items ()
{
  for (lisp p = d_item; consp (p); p = xcdr (p))
    {
      dlgctrl *c = (dlgctrl *)xcar (p);
      lisp wclass = c->wclass ();
      with_ctl (wclass, pre_init (c), (void));
      lisp kwd = c->keyword ();
      if (safe_find_keyword (Khide, kwd) == Khide)
        ShowWindow (GetDlgItem (d_hwnd, c->id ()), SW_HIDE);
      if (safe_find_keyword (Kdisable, kwd) == Kdisable)
        EnableWindow (GetDlgItem (d_hwnd, c->id ()), 0);
    }

  for (lisp p = d_init; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (consp (x))
        {
          dlgctrl *c = get_item (xcar (x));
          if (c)
            {
              lisp wclass = c->wclass ();
              with_ctl (wclass, init (c, xcdr (x)), (void));
            }
        }
    }

  for (lisp p = d_item; consp (p); p = xcdr (p))
    {
      dlgctrl *c = (dlgctrl *)xcar (p);
      lisp wclass = c->wclass ();
      with_wctl (wclass, command (c, UINT (-1)), (void));
      with_cctl (wclass, command (c, 0), (void));
    }
}

int
Dialog::get_result (dlgctrl *button)
{
  d_result = Qnil;
  if (!button || safe_find_keyword (Kno_result, button->keyword ()) == Qnil)
    {
      try
        {
          for (lisp p = d_item; consp (p); p = xcdr (p))
            {
              dlgctrl *c = (dlgctrl *)xcar (p);
              HWND hwnd = GetDlgItem (d_hwnd, c->id ());
              if (!IsWindowVisible (hwnd) || !IsWindowEnabled (hwnd))
                continue;
              lisp wclass = c->wclass ();
              lisp result = Qnil;
              with_ctl (wclass, result (c), result = );
              if (!result)
                {
                  SetFocus (hwnd);
                  if (wclass == Kedit)
                    SendMessage (hwnd, EM_SETSEL, 0, -1);
                  else if (wclass == Kcombobox)
                    SendMessage (hwnd, CB_SETEDITSEL, 0, MAKELPARAM (-1, -1));
                  return 0;
                }
              if (result != Qnil)
                d_result = xcons (xcons (c->symid (), result), d_result);
            }
        }
      catch (nonlocal_jump &)
        {
          print_condition (nonlocal_jump::data ());
          return 0;
        }
    }

  d_retval = button ? button->symid () : Qt;
  return 1;
}

void
Dialog::process_command (int id, UINT msg)
{
  dlgctrl *c = get_item (id);
  if (c)
    {
      lisp wclass = c->wclass ();
      with_wctl (wclass, command (c, msg), (void));
    }
}

void
Dialog::process_notify (NMHDR *nm)
{
  dlgctrl *c = get_item (nm->idFrom);
  if (c)
    {
      lisp wclass = c->wclass ();
      with_cctl (wclass, command (c, nm), (void));
    }
}

void
Dialog::center_window () const
{
  if (!d_tmpl->x && !d_tmpl->y)
    ::center_window (d_hwnd);
}

static int
column_valid_p (lisp columns)
{
  int ncolumns = 0;
  for (long tem; consp (columns); columns = xcdr (columns), ncolumns++)
    if (!safe_fixnum_value (xcar (columns), &tem))
      return 0;
  return ncolumns;
}

static int
item_string (lisp item, Char *buf, int size)
{
  /* Phase 2: item 表示は UTF-16 Char 列で組み立てる。旧実装は DBCP 分岐で
     Char を cp932 2-byte split していたが、Phase 2 では Char = UTF-16 code
     unit なので単に書き込むだけで済む。Returns written length. */
  if (symbolp (item))
    item = xsymbol_name (item);
  if (stringp (item))
    {
      Char *b0 = buf, *b = buf, *be = buf + size - 2;
      const Char *p = xstring_contents (item), *pe = p + xstring_length (item);
      for (; p < pe && b < be; p++)
        {
          Char c = *p;
          if (c == '\n')
            {
              *b++ = '\\';
              if (b < be) *b++ = 'n';
              b0 = b;
            }
          else if (c == '\t')
            {
              int col = (int)(b - b0);
              int goal = ((col + app.default_tab_columns) / app.default_tab_columns
                          * app.default_tab_columns);
              for (int n = min (goal - col, (int)(be - b)); n > 0; n--)
                *b++ = ' ';
            }
          else if (c == CC_DEL)
            {
              *b++ = '^';
              if (b < be) *b++ = '?';
            }
          else if (c < ' ')
            {
              *b++ = '^';
              if (b < be) *b++ = c + '@';
            }
          else
            *b++ = c;
        }
      *b = 0;
      return (int)(b - buf);
    }
  else if (bufferp (item))
    {
      Buffer *bp = xbuffer_bp (item);
      if (!bp)
        {
          static const Char dm[] = { '#', '<', 'd', 'e', 'l', 'e', 't', 'e', 'd',
                                     ' ', 'b', 'u', 'f', 'f', 'e', 'r', '>', 0 };
          int i = 0;
          for (; dm[i] && i < size - 1; i++) buf[i] = dm[i];
          buf[i] = 0;
          return i;
        }
      else
        {
          Char *end = bp->buffer_name (buf, buf + size - 2);
          *end = 0;
          return (int)(end - buf);
        }
    }
  else
    {
      long v;
      if (safe_fixnum_value (item, &v))
        {
          char tmp[32];
          int n = sprintf (tmp, "%ld", v);
          for (int i = 0; i < n && i < size - 1; i++) buf[i] = (Char)(u_char)tmp[i];
          buf[n < size ? n : size - 1] = 0;
          return n;
        }
      else
        {
          *buf = 0;
          return 0;
        }
    }
}

static void
draw_item (HDC hdc, const RECT &r, int x, lisp item, int right)
{
  /* Phase 2: Char buffer (UTF-16) を直接 ExtTextOutW へ。 */
  Char buf[2048];
  int wl = item_string (item, buf, numberof (buf));
  if (right)
    {
      SIZE size;
      GetTextExtentPoint32W (hdc, (LPCWSTR) buf, wl, &size);
      ExtTextOutW (hdc, r.right - size.cx, r.top,
                   ETO_OPAQUE | ETO_CLIPPED, &r, (LPCWSTR) buf, wl, 0);
    }
  else
    ExtTextOutW (hdc, x, r.top, ETO_OPAQUE | ETO_CLIPPED, &r,
                 (LPCWSTR) buf, wl, 0);
}

void
Dialog::draw_item (int id, DRAWITEMSTRUCT *dis)
{
  dlgctrl *c = get_item (id);
  if (!c)
    return;

  COLORREF ofg, obg;
  if (dis->itemState & ODS_SELECTED && dis->itemID != UINT (-1))
    {
      ofg = SetTextColor (dis->hDC, sysdep.highlight_text);
      obg = SetBkColor (dis->hDC, sysdep.highlight);
    }
  else
    {
      obg = SetBkColor (dis->hDC, sysdep.window);
      ofg = SetTextColor (dis->hDC, sysdep.window_text);
    }

  const RECT &r = dis->rcItem;
  if (dis->itemID != UINT (-1))
    {
      lisp item = lisp (dis->itemData);
      lisp columns = safe_find_keyword (Kcolumn, c->keyword ());
      if (column_valid_p (columns))
        {
          TEXTMETRIC tm;
          GetTextMetrics (dis->hDC, &tm);
          RECT cr = r;
          int off = tm.tmAveCharWidth / 2;
          for (; consp (item) && consp (columns);
               item = xcdr (item), columns = xcdr (columns))
            {
              int w = fixnum_value (xcar (columns));
              LONG cx = cr.left + (1 + (w < 0 ? -w : w)) * tm.tmAveCharWidth;
              if (!consp (xcdr (item)) || !consp (xcdr (columns)))
                cr.right = max (cx, r.right);
              else
                cr.right = min (cx, r.right);
              ::draw_item (dis->hDC, cr, cr.left + off, xcar (item), w < 0);
              cr.left = cr.right;
              off = tm.tmAveCharWidth;
            }
          if (cr.right < r.right)
            {
              cr.right = r.right;
              ExtTextOutW (dis->hDC, cr.left, cr.top, ETO_OPAQUE, &cr, L"", 0, 0);
            }
        }
      else
        ::draw_item (dis->hDC, r, r.left, consp (item) ? xcar (item) : item, 0);
    }
  else
    ExtTextOutW (dis->hDC, r.left, r.top, ETO_OPAQUE, &r, L"", 0, 0);

  if (dis->itemState & ODS_FOCUS)
    DrawFocusRect (dis->hDC, &r);
  SetBkColor (dis->hDC, obg);
  SetBkColor (dis->hDC, ofg);
}

static int
lb_match_p (int ch, const u_char *b)
{
  for (; *b; b++)
    {
      if (ch == char_upcase (*b))
        return 1;
      if (alphanumericp (*b) || !ascii_char_p (*b))
        return -1;
    }
  return 0;
}

static int
lb_match_p (int ch, const Char *b)
{
  for (; *b; b++)
    {
      if (ch == char_upcase (*b))
        return 1;
      if (alphanumericp (*b) || !ascii_char_p (*b))
        return -1;
    }
  return 0;
}

static int
lb_match_p (int ch, lisp item)
{
  Char buf[2048];
  item_string (item, buf, numberof (buf));
  return lb_match_p (ch, (const Char *) buf);
}

static int
lb_match_p (HWND hwnd, int index, lisp columns, int ch, int lindex)
{
  int data = SendMessageW (hwnd, LB_GETITEMDATA, index, 0);
  if (!data || data == LB_ERR)
    return 0;
  lisp item = lisp (data);
  if (columns)
    {
      for (int col = 0; consp (item) && consp (columns);
           item = xcdr (item), columns = xcdr (columns), col++)
        if (lindex < 0 || col == lindex)
          {
            int w = fixnum_value (xcar (columns));
            if (w)
              {
                w = lb_match_p (ch, xcar (item));
                if (w)
                  return w;
              }
          }
      return 0;
    }
  else
    return lb_match_p (ch, consp (item) ? xcar (item) : item);
}

static int
lb_match_p (HWND hwnd, int index, int ch)
{
  int l = max (0L, SendMessageW (hwnd, LB_GETTEXTLEN, index, 0)) + 2;
  wchar_t *wb = (wchar_t *)alloca (l * sizeof (wchar_t));
  if (SendMessageW (hwnd, LB_GETTEXT, index, LPARAM (wb)) == LB_ERR)
    return 0;
  int al = WideCharToMultiByte (932, 0, wb, -1, 0, 0, 0, 0);
  u_char *b = (u_char *)alloca (al);
  WideCharToMultiByte (932, 0, wb, -1, (char *)b, al, 0, 0);
  return lb_match_p (ch, b);
}

void
Dialog::listbox_char (int id, int ch)
{
  HWND hwnd = GetDlgItem (d_hwnd, id);
  if (!hwnd)
    return;
  dlgctrl *c = get_item (id);
  if (!c)
    return;
  DWORD style = c->style ();
  int cursel = SendMessageW (hwnd,
                             style & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL) ? LB_GETCARETINDEX : LB_GETCURSEL,
                             0, 0);
  if (cursel < 0)
    cursel = -1;
  int ncount = SendMessageW (hwnd, LB_GETCOUNT, 0, 0);
  int goal;

  ch = char_upcase (ch);
  if (style & LBS_OWNERDRAWFIXED)
    {
      lisp columns = safe_find_keyword (Kcolumn, c->keyword ());
      long ncolumns = column_valid_p (columns);
      if (!ncolumns)
        columns = 0;
      long lindex;
      if (!safe_fixnum_value (safe_find_keyword (Klabel, c->keyword ()), &lindex)
          || lindex < 0 || lindex >= ncolumns)
        lindex = -1;
      for (goal = cursel + 1; goal < ncount; goal++)
        if (lb_match_p (hwnd, goal, columns, ch, lindex) > 0)
          goto found;
      for (goal = 0; goal < cursel; goal++)
        if (lb_match_p (hwnd, goal, columns, ch, lindex) > 0)
          goto found;
      return;
    }
  else
    {
      for (goal = cursel + 1; goal < ncount; goal++)
        if (lb_match_p (hwnd, goal, ch) > 0)
          goto found;
      for (goal = 0; goal < cursel; goal++)
        if (lb_match_p (hwnd, goal, ch) > 0)
          goto found;
      return;
    }

found:
  if (style & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL))
    SendMessageW (hwnd, LB_SETCARETINDEX, goal, MAKELPARAM (0, 0));
  else
    SendMessageW (hwnd, LB_SETCURSEL, goal, 0);
  if (style & LBS_NOTIFY)
    PostMessage (d_hwnd, WM_COMMAND, MAKEWPARAM (id, LBN_SELCHANGE), LPARAM (hwnd));
}

int
Dialog::measure_item (HWND hwnd, MEASUREITEMSTRUCT *mis)
{
  switch (mis->CtlType)
    {
    case ODT_COMBOBOX:
    case ODT_LISTBOX:
      {
        mis->itemHeight = get_font_height (hwnd);
        return 1;
      }

    default:
      return 0;
    }
}

INT_PTR CALLBACK
ldialog_proc (HWND dlg, UINT msg, WPARAM wparam, LPARAM lparam)
{
  switch (msg)
    {
    case WM_INITDIALOG:
      {
        Dialog *d = (Dialog *)lparam;
        d->d_hwnd = dlg;
        SetWindowLongPtr (dlg, DWL_USER, lparam);
        set_window_icon (dlg);
        d->center_window ();
        d->init_items ();
      }
      return 1;

    case WM_NOTIFY:
      {
        Dialog *d = (Dialog *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->process_notify ((NMHDR *)lparam);
        return 1;
      }

    case WM_COMMAND:
      switch (LOWORD (wparam))
        {
        case IDCANCEL:
          EndDialog (dlg, IDCANCEL);
          return 1;

        default:
          {
            Dialog *d = (Dialog *)GetWindowLongPtr (dlg, DWL_USER);
            if (!d)
              return 0;
            d->process_command (LOWORD (wparam), HIWORD (wparam));
            return 1;
          }
        }
      return 0;

    case WM_DRAWITEM:
      {
        Dialog *d = (Dialog *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->draw_item (wparam, (DRAWITEMSTRUCT *)lparam);
        return 1;
      }

    case WM_PRIVATE_LISTBOX_CHAR:
      {
        Dialog *d = (Dialog *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->listbox_char (wparam, lparam);
        return 1;
      }

    case WM_MEASUREITEM:
      return Dialog::measure_item (dlg, (MEASUREITEMSTRUCT *)lparam);

    case WM_PRIVATE_QUIT:
      EndDialog (dlg, IDCANCEL);
      return 1;

    case WM_ACTIVATEAPP:
      PostThreadMessage (app.quit_thread_id, WM_PRIVATE_ACTIVATEAPP,
                         wparam, lparam);
      return 0;

    default:
      return 0;
    }
}

inline WORD *
Dialog::store_unicode (WORD *w, lisp string)
{
  /* Phase 2: Lisp string Char is UTF-16; memcpy + null. */
  int n = xstring_length (string);
  memcpy (w, xstring_contents (string), n * sizeof (WORD));
  w[n] = 0;
  return w + n + 1;
}

lisp
Dialog::find_handler (lisp symid, lisp handlers)
{
  for (lisp p = handlers; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (consp (x) && xcar (x) == symid)
        return xcdr (x);
    }
  return Qnil;
}

WCHAR PropSheetFont::face[LF_FACESIZE + 1];
int PropSheetFont::point;
int PropSheetFont::face_len;

void
PropSheetFont::find_font (const DLGTEMPLATE *tmpl)
{
  if (!(tmpl->style & DS_SETFONT))
    return;
  const WORD *w = (const WORD *)(tmpl + 1);
  w += *w == 0xffff ? 2 : 1 + wcslen ((const wchar_t *)w);
  w += *w == 0xffff ? 2 : 1 + wcslen ((const wchar_t *)w);
  w += 1 + wcslen ((const wchar_t *)w);
  point = short (*w++);
  int l = wcslen ((const wchar_t *)w);
  if (l < LF_FACESIZE)
    {
      wcscpy (face, (const wchar_t *)w);
      face_len = l;
    }
}

int
PropSheetFont::load ()
{
  if (!face_len)
    {
      face_len = -1;
      HINSTANCE hinst = GetModuleHandleW (L"COMCTL32.DLL");
      if (hinst)
        {
          const DLGTEMPLATE *tmpl = (DLGTEMPLATE *)
            LoadResource (hinst, FindResource (hinst,
                                               MAKEINTRESOURCE (IDD_PROPSHEET),
                                               RT_DIALOG));
          if (tmpl)
            find_font (tmpl);
        }
    }
  return face_len > 0;
}

HGLOBAL
PropSheetFont::change_font (const DLGTEMPLATE *rtmpl, DWORD size)
{
  size_t face_padding = (PropSheetFont::face_len % sizeof (WORD));
  HGLOBAL h = GlobalAlloc (GMEM_MOVEABLE | GMEM_ZEROINIT,
                           size + sizeof (WCHAR) * (PropSheetFont::face_len + 1 + face_padding));
  if (!h)
    return 0;
  DLGTEMPLATE *tmpl = (DLGTEMPLATE *)GlobalLock (h);
  if (!tmpl)
    {
      GlobalFree (h);
      return 0;
    }

  *tmpl = *rtmpl;
  tmpl->style |= DS_SETFONT;

  WORD *w = (WORD *)(tmpl + 1);
  const WORD *r0 = (const WORD *)(rtmpl + 1);
  const WORD *r = r0;
  r += *r == 0xffff ? 2 : 1 + wcslen ((const wchar_t *)r);
  r += *r == 0xffff ? 2 : 1 + wcslen ((const wchar_t *)r);
  r += 1 + wcslen ((const wchar_t *)r);
  memcpy (w, r0, sizeof (WORD) * (r - r0));
  w += r - r0;
  if (rtmpl->style & DS_SETFONT)
    r += 2 + wcslen ((const wchar_t *)(r + 1));
  *w++ = PropSheetFont::point;
  memcpy (w, PropSheetFont::face, sizeof (WCHAR) * (PropSheetFont::face_len + 1));
  w += PropSheetFont::face_len + 1;

  // DWORD alignment
#define ALIGN_DWORD(ptr) (reinterpret_cast <WORD *> (reinterpret_cast <uintptr_t> (ptr) + 3 & ~3))
  w = ALIGN_DWORD (w);
  r = ALIGN_DWORD (r);
#undef ALIGN_DWORD

  memcpy (w, r, (const char *)rtmpl + size - (const char *)r);
  GlobalUnlock (h);
  return h;
}

HGLOBAL
PropSheetFont::change_font (const wchar_t *id)
{
  if (!PropSheetFont::load ())
    return 0;

  HGLOBAL result = 0;
  HRSRC hrsrc = FindResourceW (app.hinst, id, MAKEINTRESOURCEW(5));
  const DLGTEMPLATE *tmpl = (DLGTEMPLATE *)LoadResource (app.hinst, hrsrc);
  if (tmpl)
    {
      DWORD size = SizeofResource (app.hinst, hrsrc);
      result = change_font (tmpl, size);
    }
  return result;
}

void
Dialog::create_dialog_template (lisp dialog, lisp handlers,
                                DWORD style, int propsheet)
{
  style |= WS_CAPTION;
  lisp d = dialog;
  if (xlist_length (d) < 5)
    FEprogram_error (Einvalid_dialog_format, d);
  if (xcar (d) != Qdialog)
    FEtype_error (xcar (d), Qdialog);
  d = xcdr (d);
  for (int i = 0; i < 4; i++, d = xcdr (d))
    fixnum_value (xcar (d));

  int size = (sizeof (DLGTEMPLATE)
              + sizeof (WCHAR)    // Caption[1]
              + sizeof (WCHAR)    // MenuName[1]
              + sizeof (WCHAR));  // ClassName[1]

  lisp caption = 0, font = 0;
  int point_size;

  if (propsheet && PropSheetFont::load ())
    {
      font = Qt;
      point_size = PropSheetFont::point;
      size += sizeof (WCHAR) * (PropSheetFont::face_len + 1) + sizeof (WORD);
    }

  int nitems;
  for (nitems = 0; consp (d); d = xcdr (d))
    {
      lisp x = xcar (d);
      check_cons (x);
      if (xcar (x) == Kcaption)
        {
          if (xlist_length (x) != 2)
            FEprogram_error (Einvalid_dialog_caption, x);
          x = xcar (xcdr (x));
          check_string (x);
          if (!caption)
            {
              caption = x;
              size += sizeof (WCHAR) * (xstring_length (caption) + 1);
            }
        }
      else if (xcar (x) == Kfont)
        {
          if (xlist_length (x) != 3)
            FEprogram_error (Einvalid_dialog_font, x);
          x = xcdr (x);
          int sz = fixnum_value (xcar (x));
          x = xcar (xcdr (x));
          check_string (x);
          if (!font)
            {
              font = x;
              point_size = sz;
              size += sizeof (WCHAR) * (xstring_length (font) + 1) + sizeof (WORD);
            }
        }
      else if (xcar (x) == Kcontrol)
        {
          for (x = xcdr (x); consp (x); x = xcdr (x))
            {
              lisp item = xcar (x);
              if (xlist_length (item) != 8)
                FEprogram_error (Einvalid_dialog_item, item);
              if (xcar (item) == Kbutton
                  || xcar (item) == Kedit
                  || xcar (item) == Kstatic
                  || xcar (item) == Klistbox
                  || xcar (item) == Kscrollbar
                  || xcar (item) == Kcombobox)
                size += sizeof (WORD) * 2; // 0xffff + class
              else if (xcar (item) == Kspin)
                size += sizeof UPDOWN_CLASSW;
              else if (xcar (item) == Klink)
                size += sizeof WC_URLCLASSW;
              else
                FEprogram_error (Einvalid_dialog_item, item);

              int staticp = xcar (item) == Kstatic;

              item = xcdr (xcdr (item));
              if (xcar (item) == Qnil)
                size += sizeof (WCHAR);
              else
                {
                  check_string (xcar (item));
                  size += sizeof (WCHAR) * (xstring_length (xcar (item)) + 1);
                }
              size += (sizeof (DLGITEMTEMPLATE)
                       + sizeof (WORD)   // CreateInfo
                       + sizeof (WORD)); // padding
              item = xcdr (item);
              int style = fixnum_value (xcar (item));
              if (staticp && (style & SS_TYPEMASK) == SS_ICON)
                size += sizeof (WORD) * 2;
              for (int i = 0; i < 4; i++)
                {
                  item = xcdr (item);
                  fixnum_value (xcar (item));
                }
              nitems++;
            }
        }
      else
        FEprogram_error (Eunknown_dialog_option, xcar (x));
    }

  d_h = GlobalAlloc (GMEM_MOVEABLE, size + 256);
  if (!d_h)
    FEstorage_error ();
  WORD *w = (WORD *)GlobalLock (d_h);
  if (!w)
    {
      GlobalFree (d_h);
      FEstorage_error ();
    }

  d = dialog;

  if (font)
    style |= DS_SETFONT;
  else
    style &= ~DS_SETFONT;

  d_tmpl = (DLGTEMPLATE *)w;
  d_tmpl->style = style;
  d_tmpl->dwExtendedStyle = 0;
  d_tmpl->cdit = nitems;
  w = (WORD *)&d_tmpl->x;
  d = xcdr (d);
  for (int i = 0; i < 4; i++, d = xcdr (d))
    *w++ = WORD (fixnum_value (xcar (d)));

  *w++ = 0; // menu
  *w++ = 0; // class

  if (caption)
    w = store_unicode (w, caption);
  else
    *w++ = 0;

  if (font)
    {
      *w++ = WORD (point_size);
      if (font == Qt)
        {
          memcpy (w, PropSheetFont::face,
                  sizeof (WCHAR) * (PropSheetFont::face_len + 1));
          w += PropSheetFont::face_len + 1;
        }
      else
        w = store_unicode (w, font);
    }

  for (nitems = 1000; consp (d); d = xcdr (d))
    {
      lisp x = xcar (d);
      if (xcar (x) != Kcontrol)
        continue;
      for (x = xcdr (x); consp (x); x = xcdr (x))
        {
          lisp item = xcar (x);
          lisp wclass = xcar (item);
          item = xcdr (item);
          lisp symid = xcar (item);
          item = xcdr (item);
          lisp text = xcar (item);
          item = xcdr (item);
          lisp lstyle = xcar (item);
          item = xcdr (item);
          if (DWORD (w) & (sizeof (DWORD) - 1))
            *w++ = 0;
          DLGITEMTEMPLATE *tmpl = (DLGITEMTEMPLATE *)w;
          tmpl->style = fixnum_value (lstyle);
          tmpl->dwExtendedStyle = 0;
          w = (WORD *)&tmpl->x;
          for (int i = 0; i < 4; i++)
            {
              *w++ = WORD (fixnum_value (xcar (item)));
              item = xcdr (item);
            }
          int id;
          if (symid == Qidok)
            id = IDOK;
          else if (symid == Qidcancel)
            id = IDCANCEL;
          else
            id = nitems++;
          *w++ = WORD (id);

          tmpl->style |= WS_CHILD;
          if (wclass == Kbutton)
            {
              switch (tmpl->style & 0xf)
                {
                case BS_3STATE:
                  tmpl->style = (tmpl->style & ~0xf) | BS_AUTO3STATE;
                  break;

                case BS_CHECKBOX:
                  tmpl->style = (tmpl->style & ~0xf) | BS_AUTOCHECKBOX;
                  break;

                case BS_RADIOBUTTON:
                  tmpl->style = (tmpl->style & ~0xf) | BS_AUTORADIOBUTTON;
                  break;

                case BS_OWNERDRAW:
                  tmpl->style = (tmpl->style & ~0xf) | BS_PUSHBUTTON;
                  break;
                }
            }
          else if (wclass == Klistbox)
            {
              if (tmpl->style & (LBS_OWNERDRAWFIXED | LBS_OWNERDRAWVARIABLE))
                {
                  tmpl->style &= ~(LBS_OWNERDRAWVARIABLE | LBS_HASSTRINGS);
                  tmpl->style |= LBS_OWNERDRAWFIXED;
                }
              else
                tmpl->style |= LBS_HASSTRINGS;
            }
          else if (wclass == Kcombobox)
            {
              if (tmpl->style & (CBS_OWNERDRAWFIXED | CBS_OWNERDRAWVARIABLE))
                {
                  tmpl->style &= ~(CBS_HASSTRINGS | CBS_OWNERDRAWVARIABLE);
                  tmpl->style |= CBS_OWNERDRAWFIXED;
                }
              else
                tmpl->style |= CBS_HASSTRINGS;
            }

#define store_class(id) (*w++ = 0xffff, *w++ = (id))
          if (wclass == Kbutton)
            store_class (0x80);
          else if (wclass == Kedit)
            store_class (0x81);
          else if (wclass == Kstatic)
            store_class (0x82);
          else if (wclass == Klistbox)
            store_class (0x83);
          else if (wclass == Kscrollbar)
            store_class (0x84);
          else if (wclass == Kcombobox)
            store_class (0x85);
          else if (wclass == Kspin)
            {
              memcpy (w, UPDOWN_CLASSW, sizeof UPDOWN_CLASSW);
              w += sizeof UPDOWN_CLASSW / sizeof (WCHAR);
            }
          else if (wclass == Klink)
            {
              memcpy (w, WC_URLCLASSW, sizeof WC_URLCLASSW);
              w += sizeof WC_URLCLASSW / sizeof (WCHAR);
            }

          if (wclass == Kstatic && (tmpl->style & SS_TYPEMASK) == SS_ICON)
            {
              *w++ = 0xffff;
              *w++ = IDI_XYZZY;
            }
          else if (stringp (text))
            w = store_unicode (w, text);
          else
            *w++ = 0;
          *w++ = 0;

          d_item = xcons (xcons (make_short_int (id),
                                 xcons (symid,
                                        xcons (wclass,
                                               xcons (lstyle,
                                                      find_handler (symid, handlers))))),
                          d_item);
        }
    }
}

Dialog::Dialog (lisp init)
     : d_h (0), d_tmpl (0), d_item (Qnil), d_result (Qnil), d_retval (Qnil),
       d_init (init), d_can_close (1),
       d_gcpro1 (d_item), d_gcpro2 (d_init), d_gcpro3 (d_result)
{
}

Dialog::~Dialog ()
{
  if (d_h)
    {
      if (d_tmpl)
        GlobalUnlock (d_h);
      GlobalFree (d_h);
    }
}

lisp
Fdialog_box (lisp dialog, lisp init, lisp handlers)
{
  Dialog d (init);
  d.create_dialog_template (dialog, handlers,
                            (DS_MODALFRAME | WS_POPUP | WS_VISIBLE
                             | WS_CAPTION | WS_SYSMENU),
                            0);

  int result = DialogBoxIndirectParam (app.hinst,
                                       d.get_template (),
                                       get_active_window (), ldialog_proc,
                                       LPARAM (&d));
  Fdo_events ();
  if (result != IDOK)
    {
      QUIT;
      return Qnil;
    }
  multiple_value::count () = 2;
  multiple_value::value (1) = d.d_result;
  return d.d_retval;
}

INT_PTR CALLBACK
lprop_page_proc (HWND dlg, UINT msg, WPARAM wparam, LPARAM lparam)
{
  switch (msg)
    {
    case WM_INITDIALOG:
      {
        PropPage *d = (PropPage *)((PROPSHEETPAGEW *)lparam)->lParam;
        d->d_hwnd = dlg;
        if (!d->p_parent->ps_moved)
          {
            d->p_parent->ps_moved = 1;
            center_window (GetParent (dlg));
            set_window_icon (GetParent (dlg));
          }
        SetWindowLongPtr (dlg, DWL_USER, (LONG_PTR)d);
        d->init_items ();
      }
      return 1;

    case WM_NOTIFY:
      {
        PropPage *d = (PropPage *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        switch (((NMHDR *)lparam)->code)
          {
          case PSN_KILLACTIVE:
            d->kill_active ();
            break;

          case PSN_RESET:
            d->reset ();
            break;

          case PSN_SETACTIVE:
            d->set_active ();
            break;

          default:
            d->process_notify ((NMHDR *)lparam);
            break;
          }
        return 1;
      }

    case WM_COMMAND:
      {
        PropPage *d = (PropPage *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->process_command (LOWORD (wparam), HIWORD (wparam));
        return 1;
      }

    case WM_DRAWITEM:
      {
        PropPage *d = (PropPage *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->draw_item (wparam, (DRAWITEMSTRUCT *)lparam);
        return 1;
      }

    case WM_PRIVATE_LISTBOX_CHAR:
      {
        PropPage *d = (PropPage *)GetWindowLongPtr (dlg, DWL_USER);
        if (!d)
          return 0;
        d->listbox_char (wparam, lparam);
        return 1;
      }

    case WM_MEASUREITEM:
      return PropPage::measure_item (dlg, (MEASUREITEMSTRUCT *)lparam);

#if 0
    case WM_ACTIVATEAPP:
      PostThreadMessage (app.quit_thread_id, WM_PRIVATE_ACTIVATEAPP,
                         wparam, lparam);
      return 0;
#endif
    default:
      return 0;
    }
}

PropPage::PropPage ()
     : Dialog (Qnil)
{
  d_can_close = 0;
}

PropPage::~PropPage ()
{
}

void
PropPage::create_template (lisp page, lisp handlers)
{
  create_dialog_template (page, handlers, WS_CHILD | WS_CAPTION, 1);
}

void
PropPage::init_page (PropSheet *parent, int page_no, PROPSHEETPAGEW *psp, lisp init)
{
  p_parent = parent;
  d_init = init;
  p_page_no = page_no;
  psp->dwSize = sizeof *psp;
  psp->dwFlags = PSP_DLGINDIRECT;
  psp->hInstance = app.hinst;
  psp->pResource = get_template (),
  psp->pszIcon = 0;
  psp->pfnDlgProc = lprop_page_proc;
  psp->pszTitle = 0;
  psp->lParam = LPARAM (this);
  psp->pfnCallback = 0;
}

int
PropPage::get_result ()
{
  if (!Dialog::get_result (0))
    return 0;
  *p_result = d_result;
  return 1;
}

void
PropPage::kill_active ()
{
  SetWindowLongPtr (d_hwnd, DWL_MSGRESULT, !get_result ());
}

void
PropPage::reset () const
{
  p_parent->ps_result = IDCANCEL;
}

void
PropPage::set_active () const
{
  p_parent->ps_curpage = p_page_no;
}

PropSheet::PropSheet ()
     : ps_pages (0), ps_result (IDOK), ps_moved (0)
{
}

PropSheet::~PropSheet ()
{
  if (ps_pages)
    delete [] ps_pages;
}

static int CALLBACK
prop_sheet_callback (HWND hwnd, UINT msg, LPARAM)
{
  switch (msg)
    {
    case PSCB_INITIALIZED:
      SetWindowLongPtr (hwnd, GWL_EXSTYLE,
                        GetWindowLongPtr (hwnd, GWL_EXSTYLE) & ~WS_EX_CONTEXTHELP);
      break;

    default:
      break;
    }
  return 0;
}

lisp
Fproperty_sheet (lisp pages, lisp caption, lisp lstart_page)
{
  if (caption && caption != Qnil)
    check_string (caption);

  int start_page = (lstart_page && lstart_page != Qnil
                    ? fixnum_value (lstart_page) : 0);

  if (!consp (pages))
    return Qnil;

  protect_gc gcpro (pages);

  int total_pages = 0, lpages = 0;
  for (lisp p = pages; consp (p); p = xcdr (p), total_pages++)
    {
      QUIT;
      lisp x = xcar (p);
      if (x != Qfont_page && x != Qcolor_page)
        {
          if (xlist_length (x) != 4)
            FEtype_error (x, Qproperty_page);
          lpages++;
        }
    }

  ChangeColorsDialog ccd;
  ccd.ccp_modified = 0;
  ccd.ccd_dir = xsymbol_value (Vcolor_page_enable_dir_p) != Qnil;
  ccd.ccd_subdir = xsymbol_value (Vcolor_page_enable_subdir_p) != Qnil;

  ChooseFontPage cf;
  cf.ccp_modified = 0;

  PropSheet sheet;
  sheet.ps_pages = new PropPage[lpages];

  lisp *gcprov = (lisp *)alloca (sizeof (lisp) * lpages);

  PROPSHEETPAGEW *psp = (PROPSHEETPAGEW *)alloca (sizeof *psp * total_pages);
  int i = 0, j = 0;
  for (lisp p = pages; consp (p); p = xcdr (p), i++)
    {
      lisp x = xcar (p);
      if (x == Qfont_page)
        cf.init_page (&sheet, i, &psp[i]);
      else if (x == Qcolor_page)
        ccd.init_page (&sheet, i, &psp[i]);
      else
        {
          sheet.ps_pages[j].p_ident = xcar (x);
          sheet.ps_pages[j].create_template (Fcadr (x), Fcadddr (x));
          sheet.ps_pages[j].init_page (&sheet, i, &psp[i], Fcaddr (x));
          sheet.ps_pages[j].p_result = &gcprov[j];
          gcprov[j] = Qunbound;
          j++;
        }
    }

  protect_gc gcpro2 (gcprov, lpages);

  wchar_t *wb;
  if (!caption || caption == Qnil)
    wb = (wchar_t *)L"";
  else
    {
      int wl = xstring_length (caption);
      wb = (wchar_t *)alloca ((wl + 1) * sizeof (wchar_t));
      memcpy (wb, xstring_contents (caption), wl * sizeof (wchar_t));
      wb[wl] = 0;
    }

  PROPSHEETHEADERW psh;
  psh.dwSize = sizeof psh;
  psh.dwFlags = PSH_PROPSHEETPAGE | PSH_USECALLBACK | PSH_NOAPPLYNOW;
  psh.hwndParent = get_active_window ();
  psh.hInstance = app.hinst;
  psh.pszIcon = 0;
  psh.pszCaption = wb;
  psh.nPages = total_pages;
  psh.nStartPage = min (max (start_page, 0), total_pages - 1);
  psh.ppsp = psp;
  psh.pfnCallback = prop_sheet_callback;

  sheet.ps_curpage = psh.nStartPage;

  int result = PropertySheetW (&psh);

  Fdo_events ();

  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (sheet.ps_curpage);

  if (result <= 0 || sheet.ps_result != IDOK)
    {
      if (cf.cfp_restore)
        {
          Window::change_parameters (cf.cfp_org_param,
                                     cf.colors (cf.cfp_org_cc),
                                     cf.ml_colors (cf.cfp_org_cc),
                                     cf.fg_colors (cf.cfp_org_cc),
                                     cf.bg_colors (cf.cfp_org_cc));
          modify_misc_colors (cf.misc_colors (cf.cfp_org_cc), 0);
        }
      return Qnil;
    }

  if (cf.ccp_modified)
    {
      Window::change_parameters (cf.cfp_param, cf.colors (), cf.ml_colors (),
                                 cf.fg_colors (), cf.bg_colors ());
      modify_misc_colors (cf.misc_colors (), 1);
    }

  if (ccd.ccp_modified)
    change_local_colors (ccd.ccd_default ? 0 : ccd.ccp_cc, ccd.ccd_dir, ccd.ccd_subdir);

  lisp values = Qnil;
  for (i = 0; i < lpages; i++)
    if (*sheet.ps_pages[i].p_result != Qunbound)
      values = xcons (xcons (sheet.ps_pages[i].p_ident,
                             *sheet.ps_pages[i].p_result),
                      values);

  return values;
}
