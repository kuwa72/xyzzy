// issue #13 step6 PoC — wxWidgets inline IME on a self-drawn (custom) window.
//
// Goal: see how far a custom-drawn wxWindow (we paint our own text, no
// wxTextCtrl/wxStyledTextCtrl) can host Japanese inline IME — preedit shown
// underlined at the caret, candidate window at the caret, commit inserts.
// This is the wx counterpart of poc/qt-ime; the comparison is specifically
// about how much IME machinery wx makes us hand-wire for a custom widget.
//
// What wx gives us out of the box for a custom window:
//   - wxEVT_CHAR / wxEVT_KEY_DOWN for committed keystrokes.
//   - There is NO portable "preedit/composition" event in wx for a custom
//     window. On macOS the wxNSView NSTextInputClient hooks are stubs, so the
//     in-progress composition is not delivered to us as inline preedit; the
//     IME typically commits the final string via char events instead.
//   - This PoC therefore shows committed text and logs what events we DO get;
//     the "inline underline preedit + candidate-at-caret" is exactly the part
//     that needs platform-specific work in wx (the thing we're measuring).
//
// Build (after `brew install wxwidgets`):
//   see CMakeLists.txt in this dir.

#include <wx/wx.h>
#include <wx/dcbuffer.h>
#include "ime_hook.h"

class ImeCanvas : public wxWindow
{
public:
  ImeCanvas (wxWindow *parent)
    : wxWindow (parent, wxID_ANY, wxDefaultPosition, wxSize (800, 200),
                wxWANTS_CHARS | wxFULL_REPAINT_ON_RESIZE)
  {
    SetBackgroundStyle (wxBG_STYLE_PAINT);
    m_font = wxFont (18, wxFONTFAMILY_TELETYPE, wxFONTSTYLE_NORMAL,
                     wxFONTWEIGHT_NORMAL);
    Bind (wxEVT_PAINT, &ImeCanvas::OnPaint, this);
    Bind (wxEVT_CHAR, &ImeCanvas::OnChar, this);
    Bind (wxEVT_KEY_DOWN, &ImeCanvas::OnKeyDown, this);
    SetFocus ();

    // Install the macOS inline-IME hook on our native NSView. It forwards the
    // IME's marked (preedit) text and commits as a normalized (preedit,
    // commit) pair — the same boundary a built-in SKK backend would feed.
    install_ime_hook (
      GetHandle (),
      [this] (const std::wstring &preedit, int /*caret*/)
        {
          m_preedit = wxString (preedit);
          wxLogMessage ("PREEDIT: '%s'", m_preedit);
          Refresh ();
        },
      [this] (const std::wstring &commit)
        {
          m_committed += wxString (commit);
          m_preedit.clear ();
          wxLogMessage ("COMMIT: '%s'", wxString (commit));
          Refresh ();
        });
  }

private:
  void OnPaint (wxPaintEvent &)
  {
    wxAutoBufferedPaintDC dc (this);
    dc.SetBackground (*wxWHITE_BRUSH);
    dc.Clear ();
    dc.SetFont (m_font);

    int x = 10, y = 60;
    dc.SetTextForeground (*wxBLACK);
    dc.DrawText (m_committed, x, y);
    wxCoord tw, th;
    dc.GetTextExtent (m_committed, &tw, &th);
    x += tw;

    // Preedit (if we ever receive one on this platform) — underlined.
    if (!m_preedit.empty ())
      {
        wxFont uf = m_font;
        uf.SetUnderlined (true);
        dc.SetFont (uf);
        dc.SetTextForeground (*wxBLUE);
        dc.DrawText (m_preedit, x, y);
        wxCoord pw, ph;
        dc.GetTextExtent (m_preedit, &pw, &ph);
        x += pw;
        dc.SetFont (m_font);
      }

    // Caret.
    dc.SetPen (*wxBLACK_PEN);
    dc.DrawLine (x + 1, y, x + 1, y + th);

    dc.SetTextForeground (*wxLIGHT_GREY);
    dc.DrawText ("wx IME PoC — type Japanese (かな漢字). Watch what events arrive.",
                 10, 20);
  }

  void OnChar (wxKeyEvent &e)
  {
    // With the IME hook installed, committed text (including plain ASCII)
    // arrives via the swizzled insertText:. We only log wxEVT_CHAR here to see
    // whether wx still routes anything through its normal path.
    wxChar c = e.GetUnicodeKey ();
    wxLogMessage ("wxEVT_CHAR: U+%04X", (int) c);
    e.Skip ();
  }

  void OnKeyDown (wxKeyEvent &e)
  {
    // Log to see whether composition keystrokes reach us as key events
    // (they should NOT during IME composition if inline IME were working).
    wxLogMessage ("KEY_DOWN: code=%d raw=%d", e.GetKeyCode (), e.GetRawKeyCode ());
    e.Skip ();
  }

  wxFont m_font;
  wxString m_committed = "xyzzy> ";
  wxString m_preedit;
};

class App : public wxApp
{
public:
  bool OnInit () override
  {
    wxFrame *f = new wxFrame (nullptr, wxID_ANY, "wx inline-IME PoC",
                              wxDefaultPosition, wxSize (820, 240));
    new ImeCanvas (f);
    // A log window so we can see which events actually arrive.
    new wxLogWindow (f, "IME event log", true, false);
    f->Show ();
    return true;
  }
};

wxIMPLEMENT_APP (App);
