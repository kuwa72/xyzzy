// -*-C++-*-
#ifndef _fns_h_
# define _fns_h_

# include "xcolor.h"

/* eval.cc */
lisp eval (lisp, lex_env &);
lisp funcall_1 (lisp, lisp);
lisp funcall_2 (lisp, lisp, lisp);
lisp funcall_3 (lisp, lisp, lisp, lisp);
lisp funcall_4 (lisp, lisp, lisp, lisp, lisp);
lfunction_proc fast_funcall_p (lisp, int);
struct Buffer;
lisp symbol_value (lisp, const Buffer *);
void set_globally (lisp, lisp, Buffer *);
int symbol_value_as_integer (lisp, const Buffer *);
void check_stack_overflow ();
lisp call_hook_nargs (lisp, lisp, lisp);

/* pathname.cc */
void file_error (message_code, lisp);
void file_error (message_code);
void file_error (int, lisp);
void file_error (int);
int parse_namestring (ucs4_t *, const ucs4_t *, int, const ucs4_t *, int);
char *pathname2cstr (lisp, char *);
wchar_t *pathname2wstr (lisp, wchar_t *);
char *pathname2u8 (lisp, char *);   /* PATH_MAX * 2 + 1 bytes */
int special_file_p (const wchar_t *);
int sub_directory_p (wchar_t *, const wchar_t *);
lisp make_path (const char *s, int append_slash = 1);
lisp make_path (const wchar_t *s, int append_slash = 1);
void map_backsl_to_sl (ucs4_t *, int);
void map_sl_to_backsl (ucs4_t *, int);
inline void map_backsl_to_sl (wchar_t *p, int n)
  {for (int i = 0; i < n; i++) if (p[i] == '\\') p[i] = '/';}
inline void map_sl_to_backsl (wchar_t *p, int n)
  {for (int i = 0; i < n; i++) if (p[i] == '/') p[i] = '\\';}
int match_suffixes (const wchar_t *, lisp);
int set_device_dir (const wchar_t *, int);
const wchar_t *get_device_dir (int);
int strict_get_file_data (const wchar_t *, WIN32_FIND_DATAW &);
lisp make_file_info (const WIN32_FIND_DATAW &);
wchar_t *root_path_name (wchar_t *, const wchar_t *);

/* lprint.cc */
void print_stack_trace (lisp, lisp);
void print_condition (struct nonlocal_data *);
void write_object (lisp, lisp, lisp);
const char *get_message_string (int);
int msgbox (int, lisp, lisp = 0);
void message (lisp, lisp = 0);
int yes_or_no_p (lisp, lisp = 0);
int msgbox (int, message_code, lisp = 0);
void message (message_code, lisp = 0);
int yes_or_no_p (message_code, lisp = 0);
void warn_msgbox (lisp, lisp = 0);
void warn (lisp, lisp = 0);
void warn_msgbox (message_code, lisp = 0);
void warn (message_code, lisp = 0);
void format_message (message_code, ...);
int format_yes_or_no_p (message_code, ...);
char *print_key_sequence (char *, char *, Char);
void ding (int);
int get_glyph_width (Char, const struct glyph_width &);

/* environ.cc */
void init_environ ();

/* lread.cc */
void init_readtable ();

/* keymap.cc */
lisp parse_keymap (lChar, lisp);
lisp lookup_keymap (lChar, lisp *, int);
Char *lookup_command_keyseq (lisp, lisp, const lisp *, int, Char *, Char *, Char *);
int find_in_current_keymaps (lChar);

/* data.cc */
lisp interactive_string (lisp);
void destruct_string (lisp);
void destruct_regexp (lisp);
#ifdef DEBUG_GC
void output_funcall_mark (FILE *);
#endif

/* cmdloop.cc (core) */
void command_loop ();
lisp execute_string (lisp);
void toplev_gc_mark (void (*)(lisp));
int toplev_accept_mouse_move_p ();

/* toplev.cc (frontend) */
LRESULT CALLBACK toplevel_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK frame_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK client_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK modeline_wndproc (HWND, UINT, WPARAM, LPARAM);
void main_loop ();
int start_quit_thread ();
int wait_process_terminate (HANDLE);
int end_wait_cursor (int);
void set_ime_caret ();
void recalc_toplevel ();
void set_caret_blink_time ();
void restore_caret_blink_time ();

/* minibuf.cc */
lisp load_default (lisp, int);
lisp load_history (lisp, int);
lisp load_history (lisp, int, lisp);
lisp load_title (lisp, int);
lisp read_minibuffer (const ucs4_t *, long, lisp, lisp, lisp, lisp, int, int, int, lisp, int);
lisp complete_read (const ucs4_t *, long, lisp, lisp, lisp, lisp, int, int);
lisp read_filename (const ucs4_t *, long, lisp, lisp, lisp, lisp);
lisp minibuffer_read_integer (const ucs4_t *, long);

/* chname.cc */
Char standard_char_name2Char (const ucs4_t *, int);
Char function_char_name2Char (const ucs4_t *, int);
Char char_bit_name2Char (const ucs4_t *, int, int &);
const char *function_Char2name (Char);
const char *standard_Char2name (Char);

/* process.cc */
void read_process_output (WPARAM, LPARAM);
void wait_process_terminate (WPARAM, LPARAM);
int buffer_has_process (const Buffer *);
int query_kill_subprocesses ();
void process_gc_mark (void (*)(lisp));

/* menu.cc */
int init_menu_flags (lisp);
void init_menu_popup (WPARAM, LPARAM);
lisp lookup_menu_command (int);
lisp track_popup_menu (lisp, lisp, const POINT *);

/* dialogs.cc */
void center_window (HWND);
void set_window_icon (HWND);
void init_list_column (HWND, int, const int *, const int *, int, const char *, const char *);
void save_list_column_width (HWND, int, const char *, const char *);
int lv_find_selected_item (HWND);
int lv_find_focused_item (HWND);

/* fileio.cc */
int same_file_p (const wchar_t *, const wchar_t *);
int make_temp_file_name (wchar_t *, const wchar_t * = 0, const wchar_t * = 0, HANDLE = 0, int = 0);
void do_auto_save (int, int);

/* Buffer.cc */
void change_local_colors (const XCOLORREF *, int, int);
void update_buffer_bar ();

/* init.cc */
void report_out_of_memory ();

/* popup.cc */
void erase_popup (int, int);

/* disp.cc */
void reload_caret_colors ();

/* listen.cc */
void start_listen_server ();
void init_listen_server ();
void end_listen_server ();
int read_listen_server (WPARAM, LPARAM);
extern UINT wm_private_xyzzysrv;

/* ces.cc */
void init_char_encoding ();
lisp find_char_encoding (lisp);
lisp make_char_encoding_constructor (lisp);
lisp symbol_value_char_encoding (lisp);
int to_vender_code (lisp);
int to_lang (lisp);
lisp from_lang (int);

/* Window.cc */
void ForceSetForegroundWindow (HWND);

/* usertool.cc */
lisp get_tooltip_text (lisp);

/* stdctl.cc */
void stdctl_hook_init (HINSTANCE);
int stdctl_operation (int);

#endif
