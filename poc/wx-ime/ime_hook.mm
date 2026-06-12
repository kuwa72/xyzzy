// issue #13 step6 PoC — wx macOS inline-IME hook (Objective-C++).
//
// wx's wxNSView adopts NSTextInputClient but only implements insertText:;
// the composition (marked-text / preedit) methods are stubs, so a custom
// wxWindow never sees the in-progress conversion. We method-swizzle the
// NSTextInputClient composition methods onto the live view class so the IME's
// marked text reaches us, then forward it as a normalized (preedit, commit)
// pair — the same boundary a future built-in SKK backend would feed.
//
// PoC scope: prove the preedit string is obtainable on a custom-drawn wx
// window. Geometry/firstRect is approximate (candidate window placement is a
// follow-up once the data path is proven).

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include "ime_hook.h"

namespace {
std::function<void (const std::wstring &, int)> g_on_preedit;
std::function<void (const std::wstring &)>      g_on_commit;

std::wstring to_wstring (NSString *s)
{
  if (!s) return std::wstring ();
  std::wstring out;
  NSUInteger n = [s length];
  out.reserve (n);
  for (NSUInteger i = 0; i < n; i++)
    out.push_back ((wchar_t)[s characterAtIndex:i]);
  return out;
}

// Extract the plain NSString from either an NSString or NSAttributedString.
NSString *plain_string (id aString)
{
  if ([aString isKindOfClass:[NSAttributedString class]])
    return [(NSAttributedString *)aString string];
  return (NSString *)aString;
}

// Track marked (preedit) state per process — fine for a single-view PoC.
NSString *g_marked = nil;

// --- swizzled NSTextInputClient methods --------------------------------

void swz_setMarkedText (id self, SEL _cmd, id aString,
                        NSRange selectedRange, NSRange replacementRange)
{
  NSString *s = plain_string (aString);
  g_marked = [s copy];
  if (g_on_preedit)
    g_on_preedit (to_wstring (s), (int) selectedRange.location);
}

void swz_unmarkText (id self, SEL _cmd)
{
  g_marked = nil;
  if (g_on_preedit)
    g_on_preedit (std::wstring (), 0);
}

BOOL swz_hasMarkedText (id self, SEL _cmd)
{
  return g_marked != nil && [g_marked length] > 0;
}

NSRange swz_markedRange (id self, SEL _cmd)
{
  if (g_marked && [g_marked length] > 0)
    return NSMakeRange (0, [g_marked length]);
  return NSMakeRange (NSNotFound, 0);
}

NSRange swz_selectedRange (id self, SEL _cmd)
{
  return NSMakeRange (NSNotFound, 0);
}

// insertText: is the commit path. wx already implements it, so we add our own
// under a different selector and also observe via swizzle: clear marked state
// and forward the committed string.
void swz_insertText (id self, SEL _cmd, id aString, NSRange replacementRange)
{
  NSString *s = plain_string (aString);
  g_marked = nil;
  if (g_on_preedit)
    g_on_preedit (std::wstring (), 0);     // clear preedit on commit
  if (g_on_commit)
    g_on_commit (to_wstring (s));
}

NSArray *swz_validAttributesForMarkedText (id self, SEL _cmd)
{
  return @[];
}

// Approximate caret rect (PoC): top-left-ish. Refined later via the widget.
NSRect swz_firstRectForCharacterRange (id self, SEL _cmd,
                                       NSRange aRange, NSRange *actualRange)
{
  NSView *v = (NSView *)self;
  NSRect r = NSMakeRect (20, 20, 2, 24);
  r = [v convertRect:r toView:nil];
  return [[v window] convertRectToScreen:r];
}

void set_impl (Class cls, SEL sel, IMP imp, const char *types)
{
  Method m = class_getInstanceMethod (cls, sel);
  if (m)
    method_setImplementation (m, imp);
  else
    class_addMethod (cls, sel, imp, types);
}
} // namespace

void
install_ime_hook (void *nsview,
                  std::function<void (const std::wstring &, int)> on_preedit,
                  std::function<void (const std::wstring &)> on_commit)
{
  g_on_preedit = on_preedit;
  g_on_commit  = on_commit;

  NSView *view = (__bridge NSView *)nsview;
  Class cls = [view class];   // the concrete wxNSView subclass

  set_impl (cls, @selector(setMarkedText:selectedRange:replacementRange:),
            (IMP) swz_setMarkedText, "v@:@{_NSRange=QQ}{_NSRange=QQ}");
  set_impl (cls, @selector(unmarkText), (IMP) swz_unmarkText, "v@:");
  set_impl (cls, @selector(hasMarkedText), (IMP) swz_hasMarkedText, "B@:");
  set_impl (cls, @selector(markedRange), (IMP) swz_markedRange, "{_NSRange=QQ}@:");
  set_impl (cls, @selector(selectedRange), (IMP) swz_selectedRange, "{_NSRange=QQ}@:");
  set_impl (cls, @selector(insertText:replacementRange:),
            (IMP) swz_insertText, "v@:@{_NSRange=QQ}");
  set_impl (cls, @selector(validAttributesForMarkedText),
            (IMP) swz_validAttributesForMarkedText, "@@:");
  set_impl (cls, @selector(firstRectForCharacterRange:actualRange:),
            (IMP) swz_firstRectForCharacterRange, "{_NSRect={_NSPoint=dd}{_NSSize=dd}}@:{_NSRange=QQ}^{_NSRange=QQ}");
}
