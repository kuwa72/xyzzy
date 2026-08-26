// VT100/xterm terminal emulator — platform-independent core
// Parses escape sequences from pty output and maintains a virtual screen.

#ifndef TERM_H
#define TERM_H

#include <stdint.h>
#include <time.h>

// SGR attributes
enum {
  TATTR_BOLD      = 0x01,
  TATTR_DIM       = 0x02,
  TATTR_UNDERLINE = 0x04,
  TATTR_REVERSE   = 0x08,
  TATTR_INVISIBLE = 0x10,
  TATTR_ITALIC    = 0x20,
  TATTR_STRIKE    = 0x40,
};

/* 色の表現 (term_color_t)。

   以前は uint8_t に「0=default, 1-16=basic, 17+=extended」を詰めていた。
   これだと 24bit 色 (SGR 38;2;r;g;b) が入らないうえ、256 色の index が
   239 以上で uint8_t を溢れて別の色になっていた。tag 付きにする。

     0                            = 端末の既定色
     TCOLOR_INDEXED | n (n=0..255) = xterm の palette index
     TCOLOR_RGB     | 0xRRGGBB     = 24bit 直接指定                        */
typedef uint32_t term_color_t;
#define TCOLOR_DEFAULT   0u
#define TCOLOR_INDEXED   0x01000000u
#define TCOLOR_RGB       0x02000000u
#define TCOLOR_TAG_MASK  0xff000000u
#define TCOLOR_VALUE(c)  ((c) & 0x00ffffffu)

struct TermCell
{
  ucs4_t ch;           // Unicode code point (0 = empty)
  term_color_t fg;     // foreground (TCOLOR_*)
  term_color_t bg;     // background (TCOLOR_*)
  uint8_t attrs;       // TATTR_*
  uint8_t wide;        // 1 = wide char first cell, 2 = wide char continuation
};

class Terminal
{
  // Screen
  int t_rows, t_cols;
  TermCell *t_screen;
  TermCell *t_alt_screen;
  int t_cur_row, t_cur_col;
  int t_scroll_top, t_scroll_bottom;

  // Saved cursor
  int t_saved_row, t_saved_col;
  term_color_t t_saved_fg, t_saved_bg;
  uint8_t t_saved_attrs;

  // Current SGR
  term_color_t t_fg, t_bg;
  uint8_t t_attrs;

  // Parser
  enum { TS_NORMAL, TS_ESC, TS_CSI, TS_CSI_PRIV, TS_OSC, TS_OSC_ESC,
         TS_ESC_HASH, TS_CHARSET, TS_UTF8_2, TS_UTF8_3, TS_UTF8_4 };
  int t_state;
  enum { TERM_MAX_PARAMS = 32 };
  int t_params[TERM_MAX_PARAMS];
  /* その param が ':' で区切られたか (T.416 の sub-parameter)。
     SGR 38 の `38;2;r;g;b` と `38:2::r:g:b` を取り違えないために持つ。 */
  uint8_t t_param_colon[TERM_MAX_PARAMS];
  int t_nparam;
  int t_intermediate;
  uint32_t t_utf8_acc;
  int t_utf8_remain;

  // Modes
  int t_alt_active;
  int t_cursor_visible;
  int t_app_cursor_keys;
  int t_origin_mode;
  int t_wraparound;
  int t_insert_mode;
  int t_pending_wrap;

  /* REP (CSI Pn b) が繰り返す「直前に置いた文字」。put_char で更新する。
     0 = まだ何も置いていない (REP は無視)。 */
  uint32_t t_last_char;

  /* Synchronized output (DECSET/DECRST 2026)。kitty/iTerm2 発祥で
     WezTerm/foot/Windows Terminal 等も追随した、フレーム単位の再描画を
     一括で見せるためのモード。詳細は dirty() のコメント。
     t_sync_update_since はアプリが 2026l を送り忘れて固まったときの
     強制解除に使う (仕様が推奨する安全策。無いと再描画が永久に止まる)。 */
  int t_sync_update;
  time_t t_sync_update_since;

  // Tab stops
  uint8_t *t_tabs;

  // Scrollback buffer (ring buffer of rows)
  enum { SCROLLBACK_MAX = 1000 };
  TermCell *t_scrollback;       // SCROLLBACK_MAX * t_cols cells
  int t_scrollback_cols;        // cols at allocation time
  int t_scrollback_count;       // number of saved lines (0..SCROLLBACK_MAX)
  int t_scrollback_head;        // ring buffer write position
  int t_scrollback_offset;      // view offset (0=live, >0=scrolled back)

  void scrollback_push (const TermCell *row);
  void scrollback_realloc ();

  // Dirty tracking
  int t_dirty;

  // Internal
  TermCell *cell (int row, int col) { return &t_screen[row * t_cols + col]; }
  void clear_cell (TermCell *c);
  void clear_cell_default (TermCell *c);
  void clear_region (int r1, int c1, int r2, int c2);
  void scroll_up (int top, int bottom, int n);
  void scroll_down (int top, int bottom, int n);
  void put_char (uint32_t ucs);
  void new_line ();
  void carriage_return ();
  void backspace ();
  void tab ();
  void reverse_index ();
  void handle_csi (int final_ch);
  void handle_esc (int ch);
  void handle_sgr ();
  int parse_sgr_color (int i, term_color_t *out);
  void handle_dec_private (int final_ch);
  void handle_osc ();

  /* OSC 4 / 10 / 11 で上書きされた palette。-1 = 未指定 (組み込みの色を
     使う)。index 0-255 が palette、256 が前景、257 が背景。 */
  enum { TPALETTE_SIZE = 258 };
  int32_t *t_palette;
  int t_osc_len;
  /* OSC 52 (クリップボード書き込み) の payload を持てるだけの大きさ。
     元は色指定用の 256 バイトだったが、それだと数行コピーしただけの
     base64 がすぐ切り詰められる。64KiB あれば普段のコピペには十分で、
     xterm 等の既定の上限とも近い桁。 */
  enum { OSC_MAX = 65536 };
  char t_osc[OSC_MAX];

  /* OSC 52 (クリップボード書き込み)。読み出し (Pd == "?") は、盗聴に
     使われうるので実装しない — 最近の端末の多く (kitty/WezTerm/foot 等)
     も既定で書き込みのみ・読み出しは無効という判断をしている。
     書き込みは "Pc;Pd" (Pd は base64 のまま) を t_osc に残し、フラグを
     立てるだけにする。base64 decode も実際のクリップボード API 呼び出し
     もプラットフォーム依存なのでフロントエンド側でやる。ncurses は
     クリップボード API を持たないので、OSC をそのまま外側の (本物の)
     端末へ中継する — tmux の allow-passthrough と同じ発想。 */
  int t_clip_pending;

  /* 端末からアプリへ返す応答 (DSR のカーソル位置、DA の機種応答)。
     feed() の中で積み、フロントエンドが feed() 後に pty へ書き出す。
     応答を返さないと、位置を問い合わせてから描画するタイプの TUI が
     待たされたり既定値で誤ったレイアウトを組んだりする。 */
  enum { REPLY_MAX = 64 };
  char t_reply[REPLY_MAX];
  int t_reply_len;
  void reply (const char *s);

  /* マウス報告 (DECSET 1000 / 1002 / 1003) と座標の符号化 (1006 = SGR)。 */
  int t_mouse_mode;      /* 0 = 無効、1000 / 1002 / 1003 */
  int t_mouse_sgr;       /* 1 = SGR 拡張 (CSI < b ; x ; y M/m) */
  int t_bracketed_paste; /* DECSET 2004 */
  int t_focus_events;    /* DECSET 1004 */
  void ensure_cursor_bounds ();
  void init_tabs ();

public:
  Terminal (int rows, int cols);
  ~Terminal ();

  void resize (int new_rows, int new_cols);
  void feed (const u_char *data, int len);
  void sync_to_buffer (Buffer *bp, Window *wp);

  // Accessors for frontend rendering
  int rows () const { return t_rows; }
  int cols () const { return t_cols; }
  int cursor_row () const { return t_cur_row; }
  int cursor_col () const { return t_cur_col; }
  int cursor_visible () const { return t_cursor_visible; }
  int app_cursor_keys () const { return t_app_cursor_keys; }
  /* Synchronized output (CSI ?2026h) が立っている間は、内部状態は普通に
     更新しつつ dirty() だけ隠す。フロントエンドは dirty() を見て再描画
     するので、これでフレームの途中経過が画面に出ず、CSI ?2026l が来た
     時点の完成形だけが一度に出る (ちらつき防止)。t_dirty 自体は消さない
     — 2026l で t_sync_update が下りた次の dirty() 呼び出しで、隠れていた
     分がまとめて反映される。 */
  int dirty () const { return t_dirty && !t_sync_update; }
  void clear_dirty () { t_dirty = 0; }
  const TermCell *screen () const { return t_screen; }
  const TermCell *cell_at (int row, int col) const
    { return &t_screen[row * t_cols + col]; }

  // Scrollback
  int scrollback_offset () const { return t_scrollback_offset; }
  int scrollback_count () const { return t_scrollback_count; }
  void scrollback_scroll (int delta);  // positive=back, negative=forward
  const TermCell *scrollback_line (int index) const; // 0=most recent
  // Get cell for rendering: handles scrollback offset
  const TermCell *display_cell (int row, int col) const;
  int alt_active () const { return t_alt_active; }

  /* OSC で上書きされた色。無ければ -1。index は上の TPALETTE_SIZE 参照。 */
  int32_t palette_entry (int index) const
    { return (t_palette && index >= 0 && index < TPALETTE_SIZE
              ? t_palette[index] : -1); }

  /* feed() が積んだ応答。フロントエンドが pty へ書いてから clear する。 */
  const char *reply_data () const { return t_reply; }
  int reply_len () const { return t_reply_len; }
  void reply_clear () { t_reply_len = 0; }

  int mouse_mode () const { return t_mouse_mode; }
  int mouse_sgr () const { return t_mouse_sgr; }
  int bracketed_paste_p () const { return t_bracketed_paste; }
  int focus_events_p () const { return t_focus_events; }

  /* OSC 52 クリップボード書き込み。feed() 後、他の OSC が来る前に
     読むこと (t_osc は次の OSC 開始で上書きされる) — reply_data() と
     同じ「feed() のたびに一度だけドレインする」約束。 */
  int clipboard_pending () const { return t_clip_pending; }
  const char *clipboard_raw () const { return t_osc; }  // "Pc;Pd"
  void clipboard_clear () { t_clip_pending = 0; }
};

// Convert an lChar key to VT100 escape sequence bytes.
// Returns number of bytes written (0 if key not handled).
int terminal_key_to_bytes (const Terminal *term, lChar key, char *buf, int bufsize);

/* マウスイベントを報告バイト列にする。row / col は 0 起算。
   kind: 0 = press、1 = release、2 = move (drag)。
   button: 0 = 左、1 = 中、2 = 右、3 = なし (move 用)、
           64 = ホイール上、65 = ホイール下。
   mods は TMOUSE_* のビット和。
   返り値は書いたバイト数。報告が無効なら 0。 */
#define TMOUSE_SHIFT 4
#define TMOUSE_META  8
#define TMOUSE_CTRL  16
int terminal_mouse_to_bytes (const Terminal *term, int kind, int button,
                            int row, int col, int mods,
                            char *buf, int bufsize);

/* フォーカス報告 (DECSET 1004)。アプリが要求していれば、xyzzy 側で
   このターミナルバッファが選択ウィンドウになった/外れたときに
   ESC[I / ESC[O を書く。要求していなければ 0 (送らない)。
   focused: 1 = フォーカスを得た、0 = 失った。 */
int terminal_focus_to_bytes (const Terminal *term, int focused,
                            char *buf, int bufsize);

#endif // TERM_H
