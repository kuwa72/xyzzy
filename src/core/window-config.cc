// Window configurations: save and restore the whole window layout.
//
// This is what save-window-excursion is built on (src/core/eval.cc constructs a
// WindowConfiguration and destroys it), plus the two lisp entry points
// current-window-configuration / set-window-configuration.
//
// It lived in src/frontend/win32/Window.cc, and the POSIX frontend had it as
// empty stubs: the constructor and destructor did nothing and
// current-window-configuration returned nil, so **save-window-excursion did not
// restore anything in the terminal** and anything that split a window inside it
// left the split behind (issue #82).  Nothing in the code is Win32 specific --
// it moves w_prev/w_next, w_order and w_rect around and calls
// Window::compute_geometry, set_buffer_params and close, all of which both
// frontends implement -- so it belongs here rather than being written twice.
// (#16 Phase 4.)

#include "stdafx.h"
#include "ed.h"
#include "Window.h"

WindowConfiguration *WindowConfiguration::wc_chain;

WindowConfiguration::WindowConfiguration ()
{
  wc_nwindows = Window::count_windows ();
  wc_data = new Data[wc_nwindows];

  wc_selected = selected_window ();
  wc_size = app.active_frame.size;
  wc_prev = wc_chain;
  wc_chain = this;

  Data *d = wc_data;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next, d++)
    {
      d->wp = wp;
      d->bufp = wp->w_bufp;
      d->point = wp->w_point.p_point;
      d->disp = wp->w_disp;
      d->mark = wp->w_mark;
      d->selection_point = wp->w_selection_point;
      d->selection_marker = wp->w_selection_marker;
      d->selection_type = wp->w_selection_type;
      d->reverse_temp = wp->w_reverse_temp;
      d->reverse_region = wp->w_reverse_region;
      d->top_column = wp->w_top_column;
      d->flags_mask = wp->w_flags_mask;
      d->flags = wp->w_flags;
      d->order = wp->w_order;
      d->rect = wp->w_rect;
    }
}

WindowConfiguration::~WindowConfiguration ()
{
  wc_chain = wc_prev;

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->w_disp_flags &= ~(Window::WDF_WINDOW | Window::WDF_MODELINE);
  for (Window *wp = app.active_frame.reserved; wp; wp = wp->w_next)
    wp->w_disp_flags &= ~(Window::WDF_WINDOW | Window::WDF_MODELINE);

  for (int i = 0; i < wc_nwindows; i++)
    wc_data[i].wp->w_disp_flags |= Window::WDF_WINDOW | Window::WDF_MODELINE;

  Buffer *bp = Buffer::dlist_find ();

  Window *reserved = 0, *next;
  for (Window *wp = app.active_frame.windows; wp; wp = next)
    {
      next = wp->w_next;
      if (!(wp->w_disp_flags & Window::WDF_WINDOW))
        {
          wp->w_next = reserved;
          reserved = wp;
        }
    }
  for (Window *wp = app.active_frame.reserved; wp; wp = next)
    {
      next = wp->w_next;
      if (!(wp->w_disp_flags & Window::WDF_WINDOW))
        {
          wp->w_next = reserved;
          reserved = wp;
        }
    }

  app.active_frame.selected = wc_selected;
  app.active_frame.windows = wc_data[0].wp;
  for (int i = 0; i < wc_nwindows; i++)
    {
      Window *wp = wc_data[i].wp;
      wp->w_prev = i ? wc_data[i - 1].wp : 0;
      wp->w_next = i != wc_nwindows - 1 ? wc_data[i + 1].wp : 0;

      xwindow_wp (wp->lwp) = wp;
      if (wc_data[i].bufp)
        {
          wp->set_buffer_params (wc_data[i].bufp);
          wp->w_bufp->goto_char (wp->w_point, wc_data[i].point);
          wp->w_disp = wc_data[i].disp;
          wp->w_mark = wc_data[i].mark;
          wp->w_selection_point = wc_data[i].selection_point;
          wp->w_selection_marker = wc_data[i].selection_marker;
          wp->w_selection_type = wc_data[i].selection_type;
          wp->w_reverse_temp = wc_data[i].reverse_temp;
          wp->w_reverse_region = wc_data[i].reverse_region;
          wp->w_top_column = wc_data[i].top_column;
        }
      else
	{
          wp->w_bufp = 0;
          if (!wp->minibuffer_window_p ())
            wp->set_buffer_params (bp);
          else
            wp->change_color ();
	}
      wp->w_flags_mask = wc_data[i].flags_mask;
      wp->w_flags = wc_data[i].flags;
      wp->w_rect = wc_data[i].rect;
      wp->w_order = wc_data[i].order;
    }

  assert (xwindow_wp (selected_window ()->lwp));
  assert (xwindow_wp (selected_window ()->lwp) == selected_window ());

  Window::compute_geometry (wc_size);

  app.active_frame.reserved = 0;
  for (Window *wp = reserved; wp; wp = next)
    {
      next = wp->w_next;
      wp->close ();
    }

  delete [] wc_data;
}

static lisp
wc_point_marker (point_t point, Buffer *bp)
{
  if (point == NO_MARK_SET)
    return Qnil;
  lisp marker = Fmake_marker (bp->lbp);
  xmarker_point (marker) = point;
  return marker;
}

lisp
Fcurrent_window_configuration ()
{
  lisp ldefs = Qnil;
  for (Window *wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    {
      Buffer *bp = wp->w_bufp;
      ldefs = xcons (make_list (wp->lwp,
                                bp->lbp,
                                wc_point_marker (wp->w_point.p_point, bp),
                                wc_point_marker (wp->w_disp, bp),
                                wc_point_marker (wp->w_mark, bp),
                                wc_point_marker (wp->w_selection_point, bp),
                                wc_point_marker (wp->w_selection_marker, bp),
                                (wp->w_selection_type != Buffer::SELECTION_VOID
                                 ? make_fixnum (wp->w_selection_type) : Qnil),
                                boole (wp->w_reverse_temp != Buffer::SELECTION_VOID),
                                wc_point_marker (wp->w_reverse_region.p1, bp),
                                wc_point_marker (wp->w_reverse_region.p2, bp),
                                make_fixnum (wp->w_top_column),
                                make_fixnum (wp->w_flags_mask),
                                make_fixnum (wp->w_flags),
                                make_list (make_fixnum (wp->w_order.left),
                                           make_fixnum (wp->w_order.top),
                                           make_fixnum (wp->w_order.right),
                                           make_fixnum (wp->w_order.bottom),
                                           0),
                                make_list (make_fixnum (wp->w_rect.left),
                                           make_fixnum (wp->w_rect.top),
                                           make_fixnum (wp->w_rect.right),
                                           make_fixnum (wp->w_rect.bottom),
                                           0),
                                0),
                     ldefs);
    }

  return make_list (Qwindow_configuration,
                    Fselected_window (),
                    Fnreverse (ldefs),
                    make_list (make_fixnum (app.active_frame.size.cx),
                               make_fixnum (app.active_frame.size.cy),
                               0),
                    0);
}

struct winconf
{
  lisp lwp;
  Window *wp;
  Buffer *bufp;
  point_t point;
  point_t disp;
  point_t mark;
  point_t selection_point;
  point_t selection_marker;
  Buffer::selection_type selection_type;
  Buffer::selection_type reverse_temp;
  Region reverse_region;
  long top_column;
  int flags_mask;
  int flags;
  RECT order;
  RECT rect;
};

static point_t
wc_marker_point (lisp x, int def = NO_MARK_SET)
{
  if (x == Qnil)
    return def;
  if (short_int_p (x))
    return xshort_int_value (x);
  if (long_int_p (x))
    return xlong_int_value (x);
  if (!markerp (x) || !xmarker_buffer (x)
      || xmarker_point (x) == NO_MARK_SET)
    return def;
  return xmarker_point (x);
}

static void
wc_rect (RECT &r, lisp x)
{
  if (xlist_length (x) != 4)
    FEprogram_error (Einvalid_window_configuration);
  r.left = fixnum_value (xcar (x));
  x = xcdr (x);
  r.top = fixnum_value (xcar (x));
  x = xcdr (x);
  r.right = fixnum_value (xcar (x));
  x = xcdr (x);
  r.bottom = fixnum_value (xcar (x));
}

/* ウィンドウ領域の上端。**フロントエンドによって 0 ではない。** ncurses は
   0 行目をメニューバーに使うので上端は 1 になる (compute_geometry が全ての y を
   1 つ下へずらしている)。Win32 は 0。ここを 0 と決め打つと、端末で作った
   window-configuration が「不正」として弾かれる (issue #82 で実際に踏んだ)。
   今出ているウィンドウから取るので、どちらでも通る。 */
static LONG
wc_area_top ()
{
  LONG top = -1;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!wp->minibuffer_window_p () && (top < 0 || wp->w_rect.top < top))
      top = wp->w_rect.top;
  return top < 0 ? 0 : top;
}

static int
wc_calc_order (winconf *conf, int nwindows,
            LONG RECT::*edge1, LONG RECT::*edge2, int sz, LONG origin)
{
  int norders = -1;
  for (int i = 0; i < nwindows; i++)
    {
      if (conf[i].order.*edge1 >= conf[i].order.*edge2
          || conf[i].order.*edge1 < 0
          || conf[i].rect.*edge1 >= conf[i].rect.*edge2
          || conf[i].rect.*edge1 < 0)
        FEprogram_error (Einvalid_window_configuration);
      if (conf[i].order.*edge2 > norders)
        norders = conf[i].order.*edge2;
    }
  if (norders > nwindows * 2)
    FEprogram_error (Einvalid_window_configuration);

  int *pixels = (int *)alloca (sizeof *pixels * (norders + 1));

  for (int i = 0; i <= norders; i++)
    pixels[i] = -1;

  for (int i = 0; i < nwindows; i++)
    {
      if (pixels[conf[i].order.*edge1] == -1)
        pixels[conf[i].order.*edge1] = conf[i].rect.*edge1;
      else if (pixels[conf[i].order.*edge1] != conf[i].rect.*edge1)
        FEprogram_error (Einvalid_window_configuration);
      if (pixels[conf[i].order.*edge2] == -1)
        pixels[conf[i].order.*edge2] = conf[i].rect.*edge2;
      else if (pixels[conf[i].order.*edge2] != conf[i].rect.*edge2)
        FEprogram_error (Einvalid_window_configuration);
    }

  if (pixels[0] != origin || pixels[norders] > sz)
    FEprogram_error (Einvalid_window_configuration);

  for (int i = 1; i <= norders; i++)
    if (pixels[i] == -1 || pixels[i] < pixels[i - 1])
      FEprogram_error (Einvalid_window_configuration);

  return norders;
}

static void
wc_check_order (winconf *conf, int nwindows, const SIZE &sz)
{
  int nx = wc_calc_order (conf, nwindows, &RECT::left, &RECT::right, sz.cx, 0);
  int ny = wc_calc_order (conf, nwindows, &RECT::top, &RECT::bottom, sz.cy,
                          wc_area_top ());
  const int n = nx * ny;
  char *const f = (char *)alloca (n);
  memset (f, 0, n);
  for (int i = 0; i < nwindows; i++)
    for (int y = conf[i].order.top; y < conf[i].order.bottom; y++)
      for (int x = conf[i].order.left; x < conf[i].order.right; x++)
        if (f[y * nx + x]++)
          FEprogram_error (Einvalid_window_configuration);
  for (int i = 0; i < n; i++)
    if (!f[i])
      FEprogram_error (Einvalid_window_configuration);
}

static point_t
wc_range (Buffer *bp, point_t point)
{
  return min (max (point, bp->b_contents.p1), bp->b_contents.p2);
}

static void
wc_restore (winconf *conf, int nwindows, const SIZE &size,
            lisp lselected_window, int curw)
{
  Buffer *const bp = selected_buffer ();
  Window *cur_wp = 0;
  Window *odeleted = app.active_frame.deleted;
  for (int i = 0; i < nwindows; i++)
    {
      if (!conf[i].wp)
        {
          Window *wp = new Window ();
          wp->w_next = app.active_frame.deleted;
          app.active_frame.deleted = wp;
          conf[i].wp = wp;
        }
      if (conf[i].lwp == Qnil)
        conf[i].lwp = conf[i].wp->lwp;
      else
        conf[i].wp->lwp = conf[i].lwp;
      if (conf[i].lwp == lselected_window)
        cur_wp = conf[i].wp;
    }

  if (curw >= 0 && curw < nwindows)
    cur_wp = conf[curw].wp;

  app.active_frame.deleted = odeleted;

  Window *wp;
  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    wp->w_disp_flags &= ~(Window::WDF_WINDOW | Window::WDF_MODELINE);
  Window *const mini_wp = wp;
  for (wp = app.active_frame.reserved; wp; wp = wp->w_next)
    wp->w_disp_flags &= ~(Window::WDF_WINDOW | Window::WDF_MODELINE);

  for (int i = 0; i < nwindows; i++)
    conf[i].wp->w_disp_flags |= (Window::WDF_WINDOW
                                 | Window::WDF_MODELINE
                                 | Window::WDF_GOAL_COLUMN);
  mini_wp->w_disp_flags |= (Window::WDF_WINDOW
                            | Window::WDF_MODELINE
                            | Window::WDF_GOAL_COLUMN);

  Window *reserved = 0, *next;
  for (wp = app.active_frame.windows; wp->w_next; wp = next)
    {
      next = wp->w_next;
      if (!(wp->w_disp_flags & Window::WDF_WINDOW))
        {
          wp->w_next = reserved;
          reserved = wp;
        }
    }
  for (wp = app.active_frame.reserved; wp; wp = next)
    {
      next = wp->w_next;
      if (!(wp->w_disp_flags & Window::WDF_WINDOW))
        {
          wp->w_next = reserved;
          reserved = wp;
        }
    }

  long ymax = -1;
  app.active_frame.selected = cur_wp ? cur_wp : conf[0].wp;
  app.active_frame.windows = conf[0].wp;
  for (int i = 0; i < nwindows; i++)
    {
      wp = conf[i].wp;
      wp->w_prev = i ? conf[i - 1].wp : 0;
      wp->w_next = i != nwindows - 1 ? conf[i + 1].wp : mini_wp;

      xwindow_wp (wp->lwp) = wp;
      Buffer *bufp = conf[i].bufp;
      if (bufp)
        {
          wp->set_buffer_params (conf[i].bufp);
          wp->w_bufp->goto_char (wp->w_point, conf[i].point);
          wp->w_disp = wc_range (bufp, conf[i].disp);
          wp->w_last_disp = wp->w_disp;

          wp->w_mark = conf[i].mark;
          if (wp->w_mark != NO_MARK_SET)
            wp->w_mark = wc_range (bufp, wp->w_mark);

          wp->w_selection_point = conf[i].selection_point;
          wp->w_selection_marker = conf[i].selection_marker;
          wp->w_selection_type = conf[i].selection_type;
          if (wp->w_selection_type != Buffer::SELECTION_VOID)
            {
              wp->w_selection_type &=
                Buffer::SELECTION_TYPE_MASK | Buffer::PRE_SELECTION;
              switch (wp->w_selection_type & Buffer::SELECTION_TYPE_MASK)
                {
                case Buffer::SELECTION_LINEAR:
                case Buffer::SELECTION_REGION:
                case Buffer::SELECTION_RECTANGLE:
                  break;

                default:
                  wp->w_selection_type = Buffer::SELECTION_VOID;
                  break;
                }
            }
          if (wp->w_selection_point == NO_MARK_SET
              || wp->w_selection_marker == NO_MARK_SET
              || wp->w_selection_type == Buffer::SELECTION_VOID)
            {
              wp->w_selection_point = NO_MARK_SET;
              wp->w_selection_marker = NO_MARK_SET;
              wp->w_selection_type = Buffer::SELECTION_VOID;
            }
          else
            {
              wp->w_selection_point = wc_range (bufp, wp->w_selection_point);
              wp->w_selection_marker = wc_range (bufp, wp->w_selection_marker);
            }

          wp->w_reverse_temp = conf[i].reverse_temp;
          wp->w_reverse_region = conf[i].reverse_region;

          if (wp->w_reverse_temp != Buffer::SELECTION_VOID)
            wp->w_reverse_temp &= Buffer::PRE_SELECTION;
          if (wp->w_reverse_region.p1 == NO_MARK_SET
              || wp->w_reverse_region.p2 == NO_MARK_SET)
            {
              wp->w_reverse_temp = Buffer::SELECTION_VOID;
              wp->w_reverse_region.p1 = NO_MARK_SET;
              wp->w_reverse_region.p2 = NO_MARK_SET;
            }
          else
            {
              wp->w_reverse_region.p1 = wc_range (bufp, wp->w_reverse_region.p1);
              wp->w_reverse_region.p2 = wc_range (bufp, wp->w_reverse_region.p2);
              if (wp->w_reverse_region.p1 > wp->w_reverse_region.p2)
                swap (wp->w_reverse_region.p1, wp->w_reverse_region.p2);
            }

          wp->w_top_column = conf[i].top_column;
          if (wp->w_top_column < 0)
            wp->w_top_column = 0;
        }
      else
	{
          wp->w_bufp = 0;
          if (!wp->minibuffer_window_p ())
            wp->set_buffer_params (bp);
          else
            wp->change_color ();
	}
      wp->w_goal_column = 0;
      wp->w_flags_mask = conf[i].flags_mask;
      wp->w_flags = conf[i].flags;
      wp->w_rect = conf[i].rect;
      wp->w_order = conf[i].order;
      /* long と LONG (Win32 では long、Linux では int) を混ぜると
         std::max の型推論が通らない。片方に寄せる。 */
      ymax = max (ymax, long (wp->w_rect.bottom));
    }

  mini_wp->w_prev = conf[nwindows - 1].wp;
  mini_wp->w_rect.left = 0;
  mini_wp->w_rect.top = ymax;
  mini_wp->w_rect.right = size.cx;
  mini_wp->w_rect.bottom = size.cy;

  assert (xwindow_wp (selected_window ()->lwp));
  assert (xwindow_wp (selected_window ()->lwp) == selected_window ());

  Window::compute_geometry (size);

  app.active_frame.reserved = 0;
  for (wp = reserved; wp; wp = next)
    {
      next = wp->w_next;
      wp->close ();
    }
}

lisp
Fset_window_configuration (lisp lconf)
{
  lisp x = lconf;
  if (xlist_length (x) != 4 || xcar (x) != Qwindow_configuration)
    FEtype_error (lconf, Qwindow_configuration);

  x = xcdr (x);
  lisp lselected_window = xcar (x);
  long curw = -1;
  if (lselected_window != Qnil
      && !safe_fixnum_value (lselected_window, &curw))
    {
      curw = -1;
      check_window (lselected_window);
    }

  x = xcdr (x);
  lisp ldefs = xcar (x);
  if (!consp (ldefs))
    FEprogram_error (Einvalid_window_configuration);

  x = xcar (xcdr (x));
  if (xlist_length (x) != 2)
    FEprogram_error (Einvalid_window_configuration);

  SIZE size;
  size.cx = fixnum_value (xcar (x));
  size.cy = fixnum_value (xcar (xcdr (x)));
  if (size.cx < 0 || size.cy < 0)
    FEprogram_error (Einvalid_window_configuration);

  int nwindows = xlist_length (ldefs);
  if (nwindows < 1)
    FEprogram_error (Einvalid_window_configuration);

  int selected_window_ok = 0;
  winconf *conf = (winconf *)alloca (sizeof *conf * nwindows);
  for (int i = 0; i < nwindows; i++, ldefs = xcdr (ldefs))
    {
      x = xcar (ldefs);
      if (xlist_length (x) != 16)
        FEprogram_error (Einvalid_window_configuration);

      conf[i].lwp = xcar (x);
      if (conf[i].lwp == Qnil)
        conf[i].wp = 0;
      else
        {
          check_window (conf[i].lwp);
          if (lselected_window == conf[i].lwp)
            selected_window_ok = 1;
          conf[i].wp = xwindow_wp (conf[i].lwp);
          if (!conf[i].wp)
            {
              for (Window *wp = app.active_frame.reserved; wp; wp = wp->w_next)
                if (wp->lwp == conf[i].lwp)
                  {
                    conf[i].wp = wp;
                    break;
                  }
            }
          else if (conf[i].wp->minibuffer_window_p ())
            FEprogram_error (Einvalid_window_configuration);
        }
      x = xcdr (x);
      if (xcar (x) == Qnil)
        conf[i].bufp = 0;
      else
        {
          check_buffer (xcar (x));
          conf[i].bufp = xbuffer_bp (xcar (x));
        }
      x = xcdr (x);
      conf[i].point = wc_marker_point (xcar (x), 0);
      x = xcdr (x);
      conf[i].disp = wc_marker_point (xcar (x), 0);
      x = xcdr (x);
      conf[i].mark = wc_marker_point (xcar (x));
      x = xcdr (x);
      conf[i].selection_point = wc_marker_point (xcar (x));
      x = xcdr (x);
      conf[i].selection_marker = wc_marker_point (xcar (x));
      x = xcdr (x);
      conf[i].selection_type = (xcar (x) == Qnil
                                ? Buffer::SELECTION_VOID
                                : Buffer::selection_type (fixnum_value (xcar (x))));
      x = xcdr (x);
      conf[i].reverse_temp = (xcar (x) == Qnil
                              ? Buffer::SELECTION_VOID
                              : Buffer::selection_type (Buffer::PRE_SELECTION
                                                        | Buffer::CONTINUE_PRE_SELECTION));
      x = xcdr (x);
      conf[i].reverse_region.p1 = wc_marker_point (xcar (x));
      x = xcdr (x);
      conf[i].reverse_region.p2 = wc_marker_point (xcar (x));
      x = xcdr (x);
      conf[i].top_column = fixnum_value (xcar (x));
      x = xcdr (x);
      conf[i].flags_mask = fixnum_value (xcar (x));
      x = xcdr (x);
      conf[i].flags = fixnum_value (xcar (x));
      x = xcdr (x);
      wc_rect (conf[i].order, xcar (x));
      x = xcdr (x);
      wc_rect (conf[i].rect, xcar (x));
    }

  if (lselected_window != Qnil && curw < 0 && !selected_window_ok)
    FEprogram_error (Einvalid_window_configuration);

  wc_check_order (conf, nwindows, size);
  wc_restore (conf, nwindows, size, lselected_window, curw);

  return Qnil;
}

/* w_order の番号を詰める。**ウィンドウを消した後に呼ぶ。**

   compute_geometry は各ウィンドウの w_order を添字にして境界の配列を埋める
   ので、**誰も使っていない番号が残ると、その境界は未初期化のまま**になる
   (alloca のごみ)。ウィンドウを消すと隣が w_order を吸うので、消えた側の
   境界番号だけが宙に浮く。

   1 枚だけ残っている間は両端の 2 本しか要らないので害が出ない。**次に
   split したときに、その穴のところへ新しい境界が挿し込まれて壊れる。**
   ゼロ高のウィンドウができ、しかもそれが選択されたままになるので、以降
   打鍵しても画面が変わらないように見える (issue #83: プレフィックスキー
   待ちの間に一時ウィンドウを出して消すと画面が更新されなくなる、の正体)。

   **両フロントエンドで起きる。** Lisp から
   `(split-window) (delete-window) (split-window)` と続けるだけで、Win32 でも
   ウィンドウが 2 枚とも 1 行になる。端末では画面が固まる。ここに置いてある
   のはそのため。 */
static int
order_add (long *v, int &n, int max, long x)
{
  for (int i = 0; i < n; i++)
    if (v[i] == x)
      return 1;
  if (n >= max)
    return 0;
  v[n++] = x;
  return 1;
}

static void
order_sort (long *v, int n)
{
  // 数個しか無いので挿入ソートで足りる。
  for (int i = 1; i < n; i++)
    {
      long x = v[i];
      int j = i - 1;
      for (; j >= 0 && v[j] > x; j--)
        v[j + 1] = v[j];
      v[j + 1] = x;
    }
}

static long
order_index (const long *v, int n, long x)
{
  for (int i = 0; i < n; i++)
    if (v[i] == x)
      return i;
  return 0;
}

void
Window::compact_orders ()
{
  enum {ORDER_MAX = 64};
  long xs[ORDER_MAX], ys[ORDER_MAX];
  int nxs = 0, nys = 0;
  Window *mini = Window::minibuffer_window ();

  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    if (!order_add (xs, nxs, ORDER_MAX, wp->w_order.left)
        || !order_add (xs, nxs, ORDER_MAX, wp->w_order.right)
        || !order_add (ys, nys, ORDER_MAX, wp->w_order.top)
        || !order_add (ys, nys, ORDER_MAX, wp->w_order.bottom))
      return;                   // 詰めきれないほど多い: 触らない

  order_sort (xs, nxs);
  order_sort (ys, nys);

  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      wp->w_order.left = order_index (xs, nxs, wp->w_order.left);
      wp->w_order.right = order_index (xs, nxs, wp->w_order.right);
      wp->w_order.top = order_index (ys, nys, wp->w_order.top);
      wp->w_order.bottom = order_index (ys, nys, wp->w_order.bottom);
    }
}

/* 点がウィンドウの表示範囲の外にあるか。-1 = 上、1 = 下、nil = 中。

   **中身は Win32 に依っていない。** 表示の先頭 (`w_disp`) と高さ
   (`w_ech.cy`) から行番号を比べるだけで、どちらのフロントエンドも両方を
   埋めている (端末側は src/frontend/ncurses/ncurses-stubs.cc の
   `compute_geometry`)。それでも src/frontend/win32/Window.cc に居たため、
   **端末では `ncurses-stubs.cc` の「常に nil を返す」スタブだった** —
   つまり**どこにあっても「見えている」と答えていた。**

   影響を受けるのは `pos-visible-in-window-p` (公開されている述語) と、
   それを使う `lisp/ispell.l` (見えない位置なら画面を送る) と
   `lisp/mouse.l`。**嘘をつく述語なので、呼ぶ側は間違った方に分岐する。**
   (#16 Phase 4、issue #50。) */
lisp
Fpos_not_visible_in_window_p (lisp point, lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  Buffer *bp = wp->w_bufp;
  if (!bp)
    return Qnil;
  Point cur (wp->w_point);
  bp->goto_char (cur, bp->coerce_to_point (point));
  long top, linenum;
  if (bp->b_fold_columns == Buffer::FOLD_NONE)
    {
      linenum = bp->point_linenum (cur);
      top = bp->point_linenum (wp->w_disp);
    }
  else
    {
      linenum = bp->folded_point_linenum (cur);
      top = bp->folded_point_linenum (wp->w_disp);
    }
  return (linenum < top
          ? make_fixnum (-1)
          : (linenum >= top + wp->w_ech.cy
             ? make_fixnum (1)
             : Qnil));
}



/* 表示フラグ (`get/set-window-flags`、`get/set-local-window-flags`)。

   **`Window::flags ()` は 3 段の重ね合わせである:**

     ウィンドウ局所  w_flags / w_flags_mask
     バッファ局所    b_wflags / b_wflags_mask
     全体の既定      Window::w_default_flags

   `flags ()` が `w_flags | (w_default_flags & w_flags_mask)` を計算し、
   さらにバッファの分を被せる。**mask は「そのビットについては上位に従う」**
   という意味で、`modify_wflags` の 3 つ目の枝 (t でも nil でもない値を
   渡したとき) がそこへ戻す操作である。

   **ここが core に居るべき理由。** これは `Window::flags ()` の性質であって
   フロントエンドの性質ではない。src/frontend/win32/Window.cc にあったので、
   **端末では 4 つとも中身の無いスタブだった** (issue #50):

     get-window-flags        0 を返す
     set-window-flags        nil を返す
     get-local-window-flags  0 を返す
     set-local-window-flags  nil を返す

   `lisp/window.l` の `toggle-window-flag` はこの 4 つしか使わないので、
   **`toggle-line-number` / `toggle-ruler` / `toggle-newline` / `toggle-tab` /
   `toggle-eof` / `toggle-fold-mark` / `toggle-cursor-line` など 14 個の
   コマンドが何もしていなかった。** 描く側 (src/core/glyph.cc) は最初から
   フラグを見ている。全体の 2 つは #166 で端末側に書いたが、**それは
   「写す」直しだった**ので、ここでは core へ移して 1 つにしている
   (#16 Phase 4)。

   フロントエンドに残したのは 2 つだけで、宣言は src/core/fns.h にある
   (`window_update_scroll_bars` / `window_default_flags_changed`)。 */

lisp
Fget_window_flags ()
{
  return make_fixnum (Window::w_default_flags);
}

/* DF のビットが変わったとき、ウィンドウの幾何を計算し直す必要があるか。

   モード行・ルーラ・行番号・折り畳みの印は**どちらのフロントエンドでも**
   テキストの領域の大きさを変えるので core で見る。スクロールバーだけが
   フロントエンドの話。 */
static int
check_modified_flags (Window *wp, int df)
{
  int recompute = window_update_scroll_bars (wp, df);
  if (df & (Window::WF_MODE_LINE | Window::WF_RULER
            | Window::WF_LINE_NUMBER | Window::WF_FOLD_MARK))
    recompute = 1;
  return recompute;
}

lisp
Fset_window_flags (lisp flags)
{
  int f = fixnum_value (flags);
  int recompute = 0;
  int dflags = Window::w_default_flags;
  for (Window *w = app.active_frame.windows; w; w = w->w_next)
    {
      /* **既定を入れ替えて `flags ()` を 2 回聞く。** ウィンドウごとの
         mask の掛かり方が違うので、変わったビットはウィンドウごとに違う。 */
      Window::w_default_flags = dflags;
      int of = w->flags ();
      Window::w_default_flags = f;
      int df = of ^ w->flags ();
      if (check_modified_flags (w, df))
        recompute = 1;
      w->w_disp_flags |= Window::WDF_WINDOW;
      if (df & (Window::WF_BGCOLOR_MODE | Window::WF_LINE_NUMBER))
        w->invalidate_glyphs ();
    }
  Window::w_default_flags = f;
  if (window_default_flags_changed (f ^ dflags))
    return Qt;
  if (recompute)
    Window::compute_geometry ();
  return Qt;
}

lisp
Fget_local_window_flags (lisp lobj)
{
  int flag, mask;
  if (bufferp (lobj))
    {
      Buffer *bp = Buffer::coerce_to_buffer (lobj);
      flag = bp->b_wflags;
      mask = bp->b_wflags_mask;
    }
  else
    {
      Window *wp = Window::coerce_to_window (lobj);
      flag = wp->w_flags;
      mask = wp->w_flags_mask;
    }
  /* 2 つ目の値は「明示的に切ってあるビット」。mask が立っていない
     (= 上位に従わない) 上に flag も立っていないもの。 */
  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (~mask & ~flag);
  return make_fixnum (flag);
}

/* LON が t なら立てる、nil なら倒す、**それ以外なら「上位に従う」に戻す。** */
static void
modify_wflags (int &flags, int &mask, int val, lisp lon)
{
  if (lon == Qt)
    {
      flags |= val;
      mask &= ~val;
    }
  else if (lon == Qnil)
    {
      flags &= ~val;
      mask &= ~val;
    }
  else
    {
      flags &= ~val;
      mask |= val;
    }
}

lisp
Fset_local_window_flags (lisp lobj, lisp lflags, lisp lon)
{
  int flags = fixnum_value (lflags);
  int recompute = 0;
  if (bufferp (lobj))
    {
      Buffer *bp = Buffer::coerce_to_buffer (lobj);
      int old_flags = bp->b_wflags;
      int old_flags_mask = bp->b_wflags_mask;
      int new_flags = old_flags;
      int new_flags_mask = old_flags_mask;
      modify_wflags (new_flags, new_flags_mask, flags, lon);
      /* **ミニバッファにモード行とルーラは付けない。** 付けると
         ミニバッファの高さが変わって、エコー領域が消える。 */
      if (Window::minibuffer_window ()->w_bufp == bp)
        {
          new_flags &= ~(Window::WF_MODE_LINE | Window::WF_RULER);
          new_flags_mask &= ~(Window::WF_MODE_LINE | Window::WF_RULER);
        }
      for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
        if (wp->w_bufp == bp)
          {
            bp->b_wflags = old_flags;
            bp->b_wflags_mask = old_flags_mask;
            int oflags = wp->flags ();
            bp->b_wflags = new_flags;
            bp->b_wflags_mask = new_flags_mask;
            int df = oflags ^ wp->flags ();
            wp->w_disp_flags |= Window::WDF_WINDOW;
            if (check_modified_flags (wp, df))
              recompute = 1;
          }
      bp->b_wflags = new_flags;
      bp->b_wflags_mask = new_flags_mask;
    }
  else
    {
      Window *wp = Window::coerce_to_window (lobj);
      int oflags = wp->flags ();
      modify_wflags (wp->w_flags, wp->w_flags_mask, flags, lon);
      if (wp->minibuffer_window_p ())
        {
          wp->w_flags &= ~(Window::WF_MODE_LINE | Window::WF_RULER);
          wp->w_flags_mask &= ~(Window::WF_MODE_LINE | Window::WF_RULER);
        }
      wp->w_disp_flags |= Window::WDF_WINDOW;
      int df = oflags ^ wp->flags ();
      if (check_modified_flags (wp, df))
        recompute = 1;
    }
  if (recompute)
    Window::compute_geometry ();
  return Qt;
}
