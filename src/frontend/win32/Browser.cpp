// Browser.dll - xyzzy WebBrowser plugin (ATL-free, MinGW compatible)
// Hosts IWebBrowser2 (Shell.Explorer.2) ActiveX control via raw COM.

#define WIN32_LEAN_AND_MEAN
#ifdef BROWSER_EXPORTS
// already defined by -D
#else
#define BROWSER_EXPORTS
#endif
#include <windows.h>
#include <ole2.h>
#include <oleidl.h>
#include <exdisp.h>
#include <oaidl.h>
#include "xpi.h"
#include "Browser.h"

// ============================================================
// Minimal COM smart pointer
// ============================================================
template<class T>
class ComPtr {
  T *p;
public:
  ComPtr () : p (0) {}
  ~ComPtr () { if (p) p->Release (); }
  T **operator& () { return &p; }
  T *operator-> () { return p; }
  operator T * () { return p; }
  void Release () { if (p) { p->Release (); p = 0; } }
};

// ============================================================
// Minimal OLE container for hosting ActiveX controls in-place.
// Implements IOleClientSite + IOleInPlaceSite + IOleInPlaceFrame.
// Most methods return E_NOTIMPL — just enough for WebBrowser.
// ============================================================
class OleContainer : public IOleClientSite,
                     public IOleInPlaceSite,
                     public IOleInPlaceFrame
{
  LONG ref_count;
  HWND hwnd;
  IOleObject *ole_obj;
  IOleInPlaceObject *inplace_obj;
  ComPtr<IWebBrowser2> web_browser;

public:
  OleContainer ()
    : ref_count (1), hwnd (0), ole_obj (0), inplace_obj (0) {}

  ~OleContainer ()
  {
    if (ole_obj)
      {
        ole_obj->Close (OLECLOSE_NOSAVE);
        ole_obj->Release ();
      }
    if (inplace_obj)
      inplace_obj->Release ();
  }

  IWebBrowser2 *GetWebBrowser () { return web_browser; }

  BOOL Create (HWND parent)
  {
    hwnd = parent;

    HRESULT hr;
    hr = CoCreateInstance (CLSID_WebBrowser, 0, CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER,
                           IID_IOleObject, (void **)&ole_obj);
    if (FAILED (hr))
      return FALSE;

    ole_obj->SetClientSite (this);

    RECT rc;
    GetClientRect (hwnd, &rc);
    hr = ole_obj->DoVerb (OLEIVERB_INPLACEACTIVATE, 0, this, 0, hwnd, &rc);
    if (FAILED (hr))
      return FALSE;

    hr = ole_obj->QueryInterface (IID_IOleInPlaceObject, (void **)&inplace_obj);
    if (SUCCEEDED (hr))
      inplace_obj->SetObjectRects (&rc, &rc);

    hr = ole_obj->QueryInterface (IID_IWebBrowser2, (void **)&web_browser);
    if (FAILED (hr))
      return FALSE;

    web_browser->put_Visible (VARIANT_TRUE);
    return TRUE;
  }

  void Resize ()
  {
    if (!inplace_obj)
      return;
    RECT rc;
    GetClientRect (hwnd, &rc);
    inplace_obj->SetObjectRects (&rc, &rc);
  }

  // --- IUnknown ---
  STDMETHODIMP QueryInterface (REFIID riid, void **ppv)
  {
    if (riid == IID_IUnknown || riid == IID_IOleClientSite)
      *ppv = (IOleClientSite *)this;
    else if (riid == IID_IOleInPlaceSite)
      *ppv = (IOleInPlaceSite *)this;
    else if (riid == IID_IOleInPlaceFrame)
      *ppv = (IOleInPlaceFrame *)this;
    else
      { *ppv = 0; return E_NOINTERFACE; }
    AddRef ();
    return S_OK;
  }
  STDMETHODIMP_(ULONG) AddRef ()  { return InterlockedIncrement (&ref_count); }
  STDMETHODIMP_(ULONG) Release () { LONG r = InterlockedDecrement (&ref_count); if (!r) delete this; return r; }

  // --- IOleClientSite ---
  STDMETHODIMP SaveObject ()                            { return E_NOTIMPL; }
  STDMETHODIMP GetMoniker (DWORD, DWORD, IMoniker **)   { return E_NOTIMPL; }
  STDMETHODIMP GetContainer (IOleContainer **pp)        { *pp = 0; return E_NOINTERFACE; }
  STDMETHODIMP ShowObject ()                            { return S_OK; }
  STDMETHODIMP OnShowWindow (BOOL)                      { return S_OK; }
  STDMETHODIMP RequestNewObjectLayout ()                { return E_NOTIMPL; }

  // --- IOleWindow (base of IOleInPlaceSite) ---
  STDMETHODIMP GetWindow (HWND *p)                      { *p = hwnd; return S_OK; }
  STDMETHODIMP ContextSensitiveHelp (BOOL)              { return E_NOTIMPL; }

  // --- IOleInPlaceSite ---
  STDMETHODIMP CanInPlaceActivate ()                    { return S_OK; }
  STDMETHODIMP OnInPlaceActivate ()                     { return S_OK; }
  STDMETHODIMP OnUIActivate ()                          { return S_OK; }
  STDMETHODIMP GetWindowContext (IOleInPlaceFrame **ppFrame, IOleInPlaceUIWindow **ppDoc,
                                 LPRECT lprcPos, LPRECT lprcClip, LPOLEINPLACEFRAMEINFO lpFI)
  {
    *ppFrame = (IOleInPlaceFrame *)this;
    AddRef ();
    *ppDoc = 0;
    GetClientRect (hwnd, lprcPos);
    *lprcClip = *lprcPos;
    lpFI->fMDIApp = FALSE;
    lpFI->hwndFrame = hwnd;
    lpFI->haccel = 0;
    lpFI->cAccelEntries = 0;
    return S_OK;
  }
  STDMETHODIMP Scroll (SIZE)                            { return E_NOTIMPL; }
  STDMETHODIMP OnUIDeactivate (BOOL)                    { return S_OK; }
  STDMETHODIMP OnInPlaceDeactivate ()                   { return S_OK; }
  STDMETHODIMP DiscardUndoState ()                      { return E_NOTIMPL; }
  STDMETHODIMP DeactivateAndUndo ()                     { return E_NOTIMPL; }
  STDMETHODIMP OnPosRectChange (LPCRECT lprc)
  {
    if (inplace_obj)
      inplace_obj->SetObjectRects (lprc, lprc);
    return S_OK;
  }

  // --- IOleInPlaceUIWindow (base of IOleInPlaceFrame) ---
  STDMETHODIMP GetBorder (LPRECT)                       { return INPLACE_E_NOTOOLSPACE; }
  STDMETHODIMP RequestBorderSpace (LPCBORDERWIDTHS)     { return INPLACE_E_NOTOOLSPACE; }
  STDMETHODIMP SetBorderSpace (LPCBORDERWIDTHS)         { return E_NOTIMPL; }
  STDMETHODIMP SetActiveObject (IOleInPlaceActiveObject *, LPCOLESTR) { return S_OK; }

  // --- IOleInPlaceFrame ---
  STDMETHODIMP InsertMenus (HMENU, LPOLEMENUGROUPWIDTHS)    { return E_NOTIMPL; }
  STDMETHODIMP SetMenu (HMENU, HOLEMENU, HWND)              { return S_OK; }
  STDMETHODIMP RemoveMenus (HMENU)                          { return E_NOTIMPL; }
  STDMETHODIMP SetStatusText (LPCOLESTR)                    { return S_OK; }
  STDMETHODIMP EnableModeless (BOOL)                        { return S_OK; }
  STDMETHODIMP TranslateAccelerator (LPMSG, WORD)           { return E_NOTIMPL; }
};

// ============================================================
// Browser host window (child window that contains WebBrowser)
// ============================================================
static const wchar_t BROWSER_WND_CLASS[] = L"XyzzyBrowserHost";
static HINSTANCE g_hinst;

static LRESULT CALLBACK
browser_wndproc (HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
  OleContainer *oc = (OleContainer *)GetWindowLongPtr (hwnd, GWLP_USERDATA);
  switch (msg)
    {
    case WM_SIZE:
      if (oc)
        oc->Resize ();
      return 0;
    }
  return DefWindowProc (hwnd, msg, wp, lp);
}

static void
register_class ()
{
  static int done;
  if (done)
    return;
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof wc;
  wc.lpfnWndProc = browser_wndproc;
  wc.hInstance = g_hinst;
  wc.lpszClassName = BROWSER_WND_CLASS;
  RegisterClassExW (&wc);
  done = 1;
}

// ============================================================
// DLL state
// ============================================================
struct BrowserState {
  OleContainer *container;
  HWND host_hwnd;
  XPIHANDLE xpi_handle;
};

static BrowserState g_state;

// ============================================================
// DLL exports
// ============================================================
extern "C" {

BROWSER_API int WINAPI createEx (HWND parent, void *xpiArgs, int size, DWORD flag)
{
  if (!xpiInit (xpiArgs))
    return 0;

  register_class ();

  RECT rc;
  GetClientRect (parent, &rc);

  g_state.host_hwnd = CreateWindowExW (
    WS_EX_CLIENTEDGE, BROWSER_WND_CLASS, 0,
    WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
    0, 0, rc.right, rc.bottom,
    parent, 0, g_hinst, 0);
  if (!g_state.host_hwnd)
    return 0;

  g_state.container = new OleContainer ();
  SetWindowLongPtr (g_state.host_hwnd, GWLP_USERDATA, (LONG_PTR)g_state.container);

  if (!g_state.container->Create (g_state.host_hwnd))
    return 0;

  g_state.xpi_handle = xpiCreatePane (g_state.host_hwnd, size, size, flag);
  if (!g_state.xpi_handle)
    return 0;

  return 1;
}

BROWSER_API int WINAPI create (HWND parent, void *xpiArgs)
{
  RECT r;
  GetClientRect (parent, &r);
  int size = (r.right - r.left) / 2;
  return createEx (parent, xpiArgs, size, XPIS_LEFT);
}

BROWSER_API int WINAPI close ()
{
  if (g_state.container)
    {
      g_state.container->Release ();
      g_state.container = 0;
    }
  if (g_state.host_hwnd)
    {
      DestroyWindow (g_state.host_hwnd);
      g_state.host_hwnd = 0;
    }
  g_state.xpi_handle = 0;
  return 1;
}

BROWSER_API HWND WINAPI GetHwnd ()
{
  return g_state.xpi_handle ? g_state.host_hwnd : 0;
}

BROWSER_API int WINAPI navigate (char *url)
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  int len = MultiByteToWideChar (CP_ACP, 0, url, -1, 0, 0);
  BSTR burl = SysAllocStringLen (0, len);
  MultiByteToWideChar (CP_ACP, 0, url, -1, burl, len);
  VARIANT vt;
  VariantInit (&vt);
  HRESULT hr = g_state.container->GetWebBrowser ()->Navigate (burl, &vt, &vt, &vt, &vt);
  SysFreeString (burl);
  return SUCCEEDED (hr);
}

BROWSER_API int WINAPI refresh ()
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  return SUCCEEDED (g_state.container->GetWebBrowser ()->Refresh ());
}

BROWSER_API int WINAPI goBack ()
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  return SUCCEEDED (g_state.container->GetWebBrowser ()->GoBack ());
}

BROWSER_API int WINAPI goForward ()
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  return SUCCEEDED (g_state.container->GetWebBrowser ()->GoForward ());
}

BROWSER_API int WINAPI goHome ()
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  return SUCCEEDED (g_state.container->GetWebBrowser ()->GoHome ());
}

BROWSER_API int WINAPI locationURL (int len, char *outUrl)
{
  if (!g_state.container || !g_state.container->GetWebBrowser ())
    return 0;
  VARIANT_BOOL busy;
  g_state.container->GetWebBrowser ()->get_Busy (&busy);
  while (busy)
    {
      Sleep (500);
      g_state.container->GetWebBrowser ()->get_Busy (&busy);
    }
  BSTR burl = 0;
  HRESULT hr = g_state.container->GetWebBrowser ()->get_LocationURL (&burl);
  if (SUCCEEDED (hr) && burl)
    {
      WideCharToMultiByte (CP_ACP, 0, burl, -1, outUrl, len, 0, 0);
      SysFreeString (burl);
    }
  return SUCCEEDED (hr);
}

} // extern "C"

// ============================================================
// DllMain
// ============================================================
BOOL APIENTRY DllMain (HMODULE hModule, DWORD reason, LPVOID)
{
  switch (reason)
    {
    case DLL_PROCESS_ATTACH:
      g_hinst = hModule;
      OleInitialize (0);
      break;
    case DLL_PROCESS_DETACH:
      OleUninitialize ();
      break;
    }
  return TRUE;
}
