#ifndef _conf_h_
#define _conf_h_

#ifndef DECLARE_CONF
#define DECLARE_CONF(NAME, VALUE) extern char NAME[];
#endif

DECLARE_CONF (cfgAscii, "ascii");
DECLARE_CONF (cfgBackColor, "backColor");
DECLARE_CONF (cfgBackslash, "backslash");
DECLARE_CONF (cfgBg, "bg");
DECLARE_CONF (cfgBig5, "big5");
DECLARE_CONF (cfgCaretColor, "caretColor");
DECLARE_CONF (cfgColumnLeft, "columnLeft");
DECLARE_CONF (cfgColumnRight, "columnRight");
DECLARE_CONF (cfgColumnSep, "columnSep");
DECLARE_CONF (cfgColumns, "columns");
DECLARE_CONF (cfgColumn, "column");
DECLARE_CONF (cfgCommentColor, "commentColor");
DECLARE_CONF (cfgCtlColor, "ctlColor");
DECLARE_CONF (cfgCursorColor, "cursorColor");
DECLARE_CONF (cfgCustColor, "custColor");
DECLARE_CONF (cfgCyrillic, "cyrillic");
DECLARE_CONF (cfgFg, "fg");
DECLARE_CONF (cfgFnkeyLabels, "fnkeyLabels");
DECLARE_CONF (cfgFoldColumns, "foldColumns");
DECLARE_CONF (cfgFoldLineNumMode, "foldLinenumMode");
DECLARE_CONF (cfgFoldMode, "foldMode");
DECLARE_CONF (cfgFooterOffset, "footerOffset");
DECLARE_CONF (cfgFooterMargin, "footerMargin");
DECLARE_CONF (cfgFooterOn, "footerOn");
DECLARE_CONF (cfgFooter, "footer");
DECLARE_CONF (cfgGb2312, "gb2312");
DECLARE_CONF (cfgGreek, "greek");
DECLARE_CONF (cfgHeaderOffset, "headerOffset");
DECLARE_CONF (cfgHeaderMargin, "headerMargin");
DECLARE_CONF (cfgHeaderOn, "headerOn");
DECLARE_CONF (cfgHeader, "header");
DECLARE_CONF (cfgImeCaretColor, "imeCaretColor");
DECLARE_CONF (cfgJapanese, "japanese");
DECLARE_CONF (cfgKsc5601, "ksc5601");
DECLARE_CONF (cfgKwdColor1, "kwdColor1");
DECLARE_CONF (cfgKwdColor2, "kwdColor2");
DECLARE_CONF (cfgKwdColor3, "kwdColor3");
DECLARE_CONF (cfgLatin, "latin");
DECLARE_CONF (cfgLineFeed, "lineFeed");
DECLARE_CONF (cfgLineNumber, "lineNumber");
DECLARE_CONF (cfgLineSpacing, "lineSpacing");
DECLARE_CONF (cfgMargin, "margin");
DECLARE_CONF (cfgTextMargin, "textMargin");
DECLARE_CONF (cfgModeLineBg, "modeLineBg");
DECLARE_CONF (cfgModeLineFg, "modeLineFg");
DECLARE_CONF (cfgRecommendSize, "recommendSize");
DECLARE_CONF (cfgSizePixel, "sizePixel");
DECLARE_CONF (cfgShowProportional, "showProportional");
DECLARE_CONF (cfgUseBitmap, "useBitmap");
DECLARE_CONF (cfgRestoreWindowPosition, "restoreWindowPosition");
DECLARE_CONF (cfgRestoreWindowSize, "restoreWindowSize");
DECLARE_CONF (cfgSaveWindowPosition, "saveWindowPosition");
DECLARE_CONF (cfgSaveWindowSize, "saveWindowSize");
DECLARE_CONF (cfgSaveWindowSnapSize, "saveWindowSnapSize");
DECLARE_CONF (cfgScale, "scale");
DECLARE_CONF (cfgSortLeft, "sortLeft");
DECLARE_CONF (cfgSortRight, "sortRight");
DECLARE_CONF (cfgSort, "sort");
DECLARE_CONF (cfgStringColor, "stringColor");
DECLARE_CONF (cfgTagColor, "tagColor");
DECLARE_CONF (cfgTextColor, "textColor");
DECLARE_CONF (cfgWindowFlags, "windowFlags");
DECLARE_CONF (cfgColors, "Colors");
DECLARE_CONF (cfgGeometry, "geometry");
DECLARE_CONF (cfgShowCmd, "showCmd");
DECLARE_CONF (cfgLeft, "left");
DECLARE_CONF (cfgTop, "top");
DECLARE_CONF (cfgRight, "right");
DECLARE_CONF (cfgBottom, "bottom");
DECLARE_CONF (cfgFiler, "Filer");
DECLARE_CONF (cfgPrintPreview, "PrintPreview");
DECLARE_CONF (cfgMisc, "Misc");
DECLARE_CONF (cfgBufferSelector, "BufferSelector");
DECLARE_CONF (cfgFont, "Font");
DECLARE_CONF (cfgPrint, "Print");
DECLARE_CONF (cfgSystemRoot, "systemRoot");
DECLARE_CONF (cfgLinenum, "linenum");
DECLARE_CONF (cfgReverse, "reverse");
DECLARE_CONF (cfgSelectionBackColor, "selectionBackColor");
DECLARE_CONF (cfgSelectionTextColor, "selectionTextColor");
DECLARE_CONF (cfgUnselectedModeLineBg, "unselectedModeLineBg");
DECLARE_CONF (cfgUnselectedModeLineFg, "unselectedModeLineFg");

/* **定義をここに置く。** 印刷のフォントの記述だが、中身は数と文字列だけで
   Win32 に依っていない。src/frontend/win32/print.h にあったため、
   `write_conf (..., const PRLOGFONT &)` を core (src/core/conf-io.cc) へ
   移せなかった — 欄を読むので前方宣言では足りない。**フロントエンドの
   ヘッダを core から見に行くのではなく、共通のものを core に置く**
   (issue #143、#16 Phase 4)。 */
struct PRLOGFONT
{
  int point;
  u_char charset;
  u_char bold;
  u_char italic;
  wchar_t face[LF_FACESIZE];   /* font names are not all inside CP932 */
};

void write_conf (const char *, const char *, const char *);
void write_conf (const char *, const char *, const wchar_t *);
void write_conf (const char *, const char *, long, int = 0);
void write_conf (const char *, const char *, const int *, int, int = 0);
void write_conf (const char *, const char *, const RECT &);
void write_conf (const char *, const char *, const LOGFONTW &);
void write_conf (const char *, const char *, const PRLOGFONT &);
void write_conf (const char *, const char *, const WINDOWPLACEMENT &);
int read_conf (const char *, const char *, char *, int);
int read_conf (const char *, const char *, wchar_t *, int);
int read_conf (const char *, const char *, int &);
#if INT_MAX != LONG_MAX
int read_conf (const char *, const char *, u_long &);
#else
static inline int
read_conf (const char *section, const char *name, u_long &value)
{
  return read_conf (section, name, *(int *)&value);
}
#endif
int read_conf (const char *, const char *, int *, int);
int read_conf (const char *, const char *, RECT &);
int read_conf (const char *, const char *, LOGFONTW &);
int read_conf (const char *, const char *, PRLOGFONT &);
int read_conf (const char *, const char *, WINDOWPLACEMENT &);
void flush_conf ();
int conf_load_geometry (HWND, const char *, const char * = 0, int = 1, int = 1);
void conf_save_geometry (HWND, const char *, const char * = 0, int = 1, int = 1);
void adjust_snap_window_size (HWND, WINDOWPLACEMENT &);
void make_geometry_key (char* buf, size_t bufsize, const char *prefix);

void conf_write_string (const char *, const char *, const char *);
void conf_write_string (const char *, const char *, const wchar_t *);
void delete_conf (const char *);

int reg2ini ();
void reg_delete_tree ();

#ifndef _WIN32
/* 設定の置き場所を決める (src/core/ini-posix.cc)。Win32 の init.cc の
   `init_user_config_path' / `init_user_inifile_path' に相当する。
   `-config' と `-ini' の値を渡す (無ければ 0 — 環境変数を見る)。 */
void init_posix_config_paths (const char *config_path, const char *ini_file);

/* `-image <path>' を `app.dump_image' に入れる (src/core/ini-posix.cc)。
   Win32 の init.cc:628 と同じことを、あちらの `CommandLineToArgvW' +
   `WINFS::GetFullPathName' の代わりに UTF-8 の argv からやる。
   **相対指定は絶対パスにする** — 途中で `chdir' すると同じ相対パスが別の
   ファイルを指すので (`-ini' と同じ理由、issue #219)。
   使える名前にならなければ `app.dump_image' を空のままにする。 */
void init_posix_dump_image (const char *path);
#endif

#endif /* _conf_h_ */
