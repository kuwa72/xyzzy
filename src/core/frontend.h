#ifndef _FRONTEND_H_
#define _FRONTEND_H_

// Frontend: abstract base class for platform-specific UI operations.
// Concrete implementations: NcursesFrontend, BatchFrontend, (Win32Frontend future)
// Core code calls through the global g_frontend pointer.

class Frontend
{
public:
  virtual ~Frontend () {}

  // Lifecycle
  virtual int init (int argc, char **argv) = 0;
  virtual void cleanup () {}
  virtual int main_loop () = 0;

  // Display
  virtual void refresh_screen (int force) {}

  // Message box / confirmation dialogs
  // Returns IDYES, IDNO, IDOK, IDCANCEL (Win32 compat constants from platform.h)
  virtual int message_box (int flags, const char *msg, const char *title)
  {
    if ((flags & 0x0f) == 0x04 /*MB_YESNO*/)
      return 6 /*IDYES*/;
    return 1 /*IDOK*/;
  }

  // Clipboard
  virtual lisp copy_to_clipboard (lisp) { return Qnil; }
  virtual lisp get_clipboard_data () { return Qnil; }
  virtual int clipboard_empty_p () { return 1; }

  // Popup display
  virtual lisp popup_string (lisp msg, lisp x, lisp y, lisp timeout) { return Qnil; }
  virtual lisp continue_popup () { return Qnil; }
  virtual lisp popup_list (lisp list, lisp okey, lisp ocancel) { return Qnil; }

  // Menu
  virtual lisp call_menu (int n) { return Qnil; }
  virtual lisp track_popup_menu (lisp menu, int button) { return Qnil; }

  // Input
  virtual lChar fetch () { return lChar_EOF; }

  // Cursor
  virtual void begin_wait_cursor () {}
  virtual void end_wait_cursor () {}
};

extern Frontend *g_frontend;

#endif /* _FRONTEND_H_ */
