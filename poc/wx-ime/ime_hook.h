// issue #13 step6 PoC — bridge for wx macOS inline-IME hook.
//
// wx's wxNSView implements NSTextInputClient's insertText: but leaves the
// composition methods (setMarkedText:/unmarkText/...) as stubs, so a custom
// wxWindow never sees the in-progress preedit. ime_hook.mm swizzles those
// methods onto the view returned by wxWindow::GetHandle() and forwards the
// marked (preedit) string here.
//
// This header is plain C++ so main.cpp can register a callback without
// pulling in Objective-C.

#ifndef IME_HOOK_H
#define IME_HOOK_H

#include <string>
#include <functional>

// Install the IME swizzle on the given NSView* (passed as void* =
// wxWindow::GetHandle()). Safe to call once per view.
//  - on_preedit(text, caretPos): composition changed (text may be empty when
//    cleared). caretPos is the cursor index within the preedit (UTF-16).
//  - on_commit(text): a string was committed (final).
void install_ime_hook (void *nsview,
                       std::function<void (const std::wstring &, int)> on_preedit,
                       std::function<void (const std::wstring &)> on_commit);

#endif
