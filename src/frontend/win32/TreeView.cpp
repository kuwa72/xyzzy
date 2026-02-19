// TreeView.dll - xyzzy TreeView plugin (MFC-free, MinGW compatible)
// Wraps Win32 TreeView common control via direct API.
// Original by kazu.y (2002), rewritten for MinGW/clang.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <stdlib.h>
#include <wchar.h>
#include "xpi.h"

#ifdef TREEVIEW_EXPORTS
#define TV_API __declspec(dllexport)
#else
#define TV_API __declspec(dllimport)
#endif

// ============================================================
// Callback types (matches original TreeView.dll)
// ============================================================
typedef BOOL (PASCAL *TvClickCallback)(HTREEITEM);
typedef BOOL (PASCAL *TvKeyDownCallback)(HTREEITEM, WORD, UINT);
typedef BOOL (PASCAL *TvEditLabelCallback)(HTREEITEM, LPCTSTR);
typedef BOOL (PASCAL *NmCallback)(NMHDR *, LRESULT *);

// ============================================================
// Per-instance state
// ============================================================
struct TreeViewInstance {
  HWND host_hwnd;
  HWND htree;
  HIMAGELIST image_list;
  XPIHANDLE xpi_handle;

  TvClickCallback click_cb;
  TvClickCallback dblclk_cb;
  TvClickCallback rclick_cb;
  TvKeyDownCallback keydown_cb;
  TvEditLabelCallback editlabel_cb;
  NmCallback nmtree_cb;

  BOOL disable_char_jump;
};

// ============================================================
// Simple instance map (viewId -> TreeViewInstance*)
// viewId is (int)(intptr_t)xpiHandle
// ============================================================
#define MAX_VIEWS 32

static TreeViewInstance *g_views[MAX_VIEWS];
static int g_view_count;

static TreeViewInstance *
find_view (int viewId)
{
  for (int i = 0; i < g_view_count; i++)
    if (g_views[i] && (int)(intptr_t)g_views[i]->xpi_handle == viewId)
      return g_views[i];
  return 0;
}

static void
add_view (TreeViewInstance *v)
{
  for (int i = 0; i < MAX_VIEWS; i++)
    if (!g_views[i])
      {
        g_views[i] = v;
        if (i >= g_view_count)
          g_view_count = i + 1;
        return;
      }
}

static void
remove_view (TreeViewInstance *v)
{
  for (int i = 0; i < g_view_count; i++)
    if (g_views[i] == v)
      {
        g_views[i] = 0;
        return;
      }
}

// ============================================================
// Host window (contains TreeView control)
// ============================================================
static const wchar_t TV_WND_CLASS[] = L"XyzzyTreeViewHost";
static HINSTANCE g_hinst;

static TreeViewInstance *
get_inst_from_hwnd (HWND hwnd)
{
  return (TreeViewInstance *)GetWindowLongPtr (hwnd, GWLP_USERDATA);
}

static LRESULT CALLBACK
tv_wndproc (HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
  TreeViewInstance *inst = get_inst_from_hwnd (hwnd);

  switch (msg)
    {
    case WM_SIZE:
      if (inst && inst->htree)
        MoveWindow (inst->htree, 0, 0, LOWORD (lp), HIWORD (lp), TRUE);
      return 0;

    case WM_MOUSEACTIVATE:
      return MA_ACTIVATE;

    case WM_NOTIFY:
      if (inst)
        {
          NMHDR *nmhdr = (NMHDR *)lp;
          if (nmhdr->hwndFrom == inst->htree)
            {
              HTREEITEM hItem = TreeView_GetSelection (inst->htree);

              switch (nmhdr->code)
                {
                case NM_CLICK:
                  if (inst->click_cb)
                    { inst->click_cb (hItem); return 0; }
                  break;
                case NM_DBLCLK:
                  if (inst->dblclk_cb)
                    { inst->dblclk_cb (hItem); return 0; }
                  break;
                case NM_RCLICK:
                  if (inst->rclick_cb)
                    { inst->rclick_cb (hItem); return 0; }
                  break;
                case TVN_KEYDOWN:
                  if (inst->keydown_cb)
                    {
                      NMTVKEYDOWN *tvkd = (NMTVKEYDOWN *)lp;
                      inst->keydown_cb (hItem, tvkd->wVKey, tvkd->flags);
                      return 0;
                    }
                  break;
                case TVN_ENDLABELEDIT:
                  {
                    NMTVDISPINFO *disp = (NMTVDISPINFO *)lp;
                    if (disp->item.pszText)
                      {
                        if (inst->editlabel_cb)
                          inst->editlabel_cb (hItem, disp->item.pszText);
                        else
                          TreeView_SetItem (inst->htree, &disp->item);
                      }
                    return 0;
                  }
                }

              if (inst->nmtree_cb)
                {
                  LRESULT result = 0;
                  if (inst->nmtree_cb (nmhdr, &result))
                    return result;
                }
            }
        }
      break;

    case WM_CHAR:
      if (inst && inst->disable_char_jump)
        return 0;
      break;
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
  wc.lpfnWndProc = tv_wndproc;
  wc.hInstance = g_hinst;
  wc.lpszClassName = TV_WND_CLASS;
  RegisterClassExW (&wc);
  done = 1;
}

// Subclass proc for tree control to handle WM_CHAR (DisableCharJump)
static LRESULT CALLBACK
tree_subclass_proc (HWND hwnd, UINT msg, WPARAM wp, LPARAM lp,
                    UINT_PTR id, DWORD_PTR data)
{
  if (msg == WM_CHAR)
    {
      TreeViewInstance *inst = (TreeViewInstance *)data;
      if (inst && inst->disable_char_jump)
        return 0;
    }
  return DefSubclassProc (hwnd, msg, wp, lp);
}

// ============================================================
// DLL exports
// ============================================================
extern "C" {

TV_API int WINAPI CreateEx (HWND parentHwnd, void *arg, int iSize, DWORD flag)
{
  if (!xpiInit (arg))
    return 0;

  register_class ();

  RECT rc;
  GetClientRect (parentHwnd, &rc);

  // Compute initial size
  if (iSize == 0)
    {
      switch (flag & XPIS_POSMASK)
        {
        case XPIS_TOP: case XPIS_BOTTOM:
          iSize = (rc.bottom - rc.top) / 2;
          break;
        default:
          iSize = (rc.right - rc.left) / 2;
          break;
        }
    }

  TreeViewInstance *inst = new TreeViewInstance ();
  memset (inst, 0, sizeof *inst);

  // Create host window
  inst->host_hwnd = CreateWindowExW (
    0, TV_WND_CLASS, 0,
    WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
    0, 0, rc.right, rc.bottom,
    parentHwnd, 0, g_hinst, 0);
  if (!inst->host_hwnd)
    { delete inst; return 0; }

  SetWindowLongPtr (inst->host_hwnd, GWLP_USERDATA, (LONG_PTR)inst);

  // Create TreeView common control
  RECT hostrc;
  GetClientRect (inst->host_hwnd, &hostrc);
  inst->htree = CreateWindowExW (
    0, WC_TREEVIEWW, 0,
    WS_CHILD | WS_VISIBLE | WS_BORDER | TVS_DISABLEDRAGDROP | TVS_SHOWSELALWAYS,
    0, 0, hostrc.right, hostrc.bottom,
    inst->host_hwnd, 0, g_hinst, 0);
  if (!inst->htree)
    { DestroyWindow (inst->host_hwnd); delete inst; return 0; }

  // Subclass tree control for WM_CHAR interception
  SetWindowSubclass (inst->htree, tree_subclass_proc, 0, (DWORD_PTR)inst);

  // Register with xyzzy pane system
  inst->xpi_handle = xpiCreatePane (inst->host_hwnd, iSize, iSize, flag);
  if (!inst->xpi_handle)
    { DestroyWindow (inst->host_hwnd); delete inst; return 0; }

  add_view (inst);
  return (int)(intptr_t)inst->xpi_handle;
}

TV_API int WINAPI Create (HWND parentHwnd, void *arg)
{
  return CreateEx (parentHwnd, arg, 0, XPIS_LEFT);
}

TV_API int WINAPI Close (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return -1;

  if (inst->htree)
    {
      RemoveWindowSubclass (inst->htree, tree_subclass_proc, 0);
      // TreeView control is destroyed with host window
    }
  if (inst->image_list)
    ImageList_Destroy (inst->image_list);
  if (inst->host_hwnd)
    DestroyWindow (inst->host_hwnd);

  remove_view (inst);
  delete inst;
  return -1;
}

TV_API HWND WINAPI GetHwnd (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? inst->host_hwnd : 0;
}

TV_API BOOL WINAPI SetSize (int viewId, int size, int min, int max, int step)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  return xpiSetPaneSize (inst->xpi_handle, size, min, max, step);
}

TV_API BOOL WINAPI SetPos (int viewId, DWORD flags)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  return xpiSetPanePos (inst->xpi_handle, flags);
}

TV_API HWND WINAPI GetHtree (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? inst->htree : 0;
}

TV_API BOOL WINAPI ModifyStyle (int viewId, DWORD dwRemove, DWORD dwAdd, UINT nFlags)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  DWORD style = GetWindowLong (inst->htree, GWL_STYLE);
  style = (style & ~dwRemove) | dwAdd;
  SetWindowLong (inst->htree, GWL_STYLE, style);
  if (nFlags)
    SetWindowPos (inst->htree, 0, 0, 0, 0, 0,
                  SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | nFlags);
  return TRUE;
}

// --- Tree item query functions ---

TV_API HTREEITEM WINAPI GetChildItem (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetChild (inst->htree, hItem) : 0;
}

TV_API UINT WINAPI GetCount (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetCount (inst->htree) : 0;
}

TV_API BOOL WINAPI GetItem (int viewId, TVITEM *pItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetItem (inst->htree, pItem) : FALSE;
}

TV_API DWORD WINAPI GetItemData (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return 0;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = TVIF_PARAM;
  TreeView_GetItem (inst->htree, &tvi);
  return (DWORD)tvi.lParam;
}

TV_API UINT WINAPI GetItemState (int viewId, HTREEITEM hItem, UINT nStateMask)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetItemState (inst->htree, hItem, nStateMask) : 0;
}

TV_API BOOL WINAPI GetItemText (int viewId, HTREEITEM hItem, LPTSTR pszText, int cchTextMax)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = TVIF_TEXT;
  tvi.pszText = pszText;
  tvi.cchTextMax = cchTextMax;
  return TreeView_GetItem (inst->htree, &tvi);
}

TV_API HTREEITEM WINAPI GetNextItem (int viewId, HTREEITEM hItem, UINT nCode)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetNextItem (inst->htree, hItem, nCode) : 0;
}

TV_API HTREEITEM WINAPI GetNextSiblingItem (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetNextSibling (inst->htree, hItem) : 0;
}

TV_API HTREEITEM WINAPI GetParentItem (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetParent (inst->htree, hItem) : 0;
}

TV_API HTREEITEM WINAPI GetPrevSiblingItem (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetPrevSibling (inst->htree, hItem) : 0;
}

TV_API HTREEITEM WINAPI GetRootItem (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetRoot (inst->htree) : 0;
}

TV_API HTREEITEM WINAPI GetSelectedItem (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_GetSelection (inst->htree) : 0;
}

TV_API BOOL WINAPI ItemHasChildren (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  return TreeView_GetChild (inst->htree, hItem) != 0;
}

// --- Tree item modification functions ---

TV_API BOOL WINAPI SetItem (int viewId, HTREEITEM hItem, UINT nMask,
                            LPCTSTR lpszItem, int nImage, int nSelectedImage,
                            UINT nState, UINT nStateMask, LPARAM lParam)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = nMask;
  tvi.pszText = (LPTSTR)lpszItem;
  tvi.iImage = nImage;
  tvi.iSelectedImage = nSelectedImage;
  tvi.state = nState;
  tvi.stateMask = nStateMask;
  tvi.lParam = lParam;
  return TreeView_SetItem (inst->htree, &tvi);
}

TV_API BOOL WINAPI SetItemData (int viewId, HTREEITEM hItem, DWORD dwData)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = TVIF_PARAM;
  tvi.lParam = dwData;
  return TreeView_SetItem (inst->htree, &tvi);
}

TV_API BOOL WINAPI SetItemState (int viewId, HTREEITEM hItem, UINT nState, UINT nStateMask)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = TVIF_STATE;
  tvi.state = nState;
  tvi.stateMask = nStateMask;
  return TreeView_SetItem (inst->htree, &tvi);
}

TV_API BOOL WINAPI SetItemText (int viewId, HTREEITEM hItem, LPCTSTR lpszItem)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  TVITEM tvi = {};
  tvi.hItem = hItem;
  tvi.mask = TVIF_TEXT;
  tvi.pszText = (LPTSTR)lpszItem;
  return TreeView_SetItem (inst->htree, &tvi);
}

TV_API BOOL WINAPI DeleteAllItems (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_DeleteAllItems (inst->htree) : FALSE;
}

TV_API BOOL WINAPI DeleteItem (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_DeleteItem (inst->htree, hItem) : FALSE;
}

TV_API HWND WINAPI EditLabel (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_EditLabel (inst->htree, hItem) : 0;
}

TV_API HTREEITEM WINAPI InsertItem (int viewId, UINT nMask, LPCTSTR lpszItem,
                                    int nImage, int nSelectedImage,
                                    UINT nState, UINT nStateMask, LPARAM lParam,
                                    HTREEITEM hParent, HTREEITEM hInsertAfter)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return 0;
  TVINSERTSTRUCT tvins = {};
  tvins.hParent = hParent;
  tvins.hInsertAfter = hInsertAfter;
  tvins.item.mask = nMask;
  tvins.item.pszText = (LPTSTR)lpszItem;
  tvins.item.iImage = nImage;
  tvins.item.iSelectedImage = nSelectedImage;
  tvins.item.state = nState;
  tvins.item.stateMask = nStateMask;
  tvins.item.lParam = lParam;
  return TreeView_InsertItem (inst->htree, &tvins);
}

TV_API BOOL WINAPI Select (int viewId, HTREEITEM hItem, UINT nCode)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_Select (inst->htree, hItem, nCode) : FALSE;
}

TV_API BOOL WINAPI Expand (int viewId, HTREEITEM hItem, UINT nCode)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_Expand (inst->htree, hItem, nCode) : FALSE;
}

TV_API UINT WINAPI SortChildren (int viewId, HTREEITEM hItem)
{
  TreeViewInstance *inst = find_view (viewId);
  return inst ? TreeView_SortChildren (inst->htree, hItem, 0) : FALSE;
}

// --- Callback registration ---

TV_API BOOL WINAPI SetClickCallback (int viewId, TvClickCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->click_cb = callback;
  return TRUE;
}

TV_API BOOL WINAPI SetRclickCallback (int viewId, TvClickCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->rclick_cb = callback;
  return TRUE;
}

TV_API BOOL WINAPI SetDblclkCallback (int viewId, TvClickCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->dblclk_cb = callback;
  return TRUE;
}

TV_API BOOL WINAPI SetKeyDownCallback (int viewId, TvKeyDownCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->keydown_cb = callback;
  return TRUE;
}

TV_API BOOL WINAPI SetNmTreeCallback (int viewId, NmCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->nmtree_cb = callback;
  return TRUE;
}

TV_API BOOL WINAPI SetEditLabelCallback (int viewId, TvEditLabelCallback callback)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst) return FALSE;
  inst->editlabel_cb = callback;
  return TRUE;
}

// --- Icon management ---

static HIMAGELIST
ensure_image_list (TreeViewInstance *inst)
{
  if (!inst->image_list)
    {
      int cx = GetSystemMetrics (SM_CXSMICON);
      int cy = GetSystemMetrics (SM_CYSMICON);
      inst->image_list = ImageList_Create (cx, cy, ILC_MASK | ILC_COLOR16, 4, 4);
      TreeView_SetImageList (inst->htree, inst->image_list, TVSIL_NORMAL);
    }
  return inst->image_list;
}

TV_API int WINAPI AddFileIcon (int viewId, LPCTSTR lpszFilename)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return -1;
  HIMAGELIST il = ensure_image_list (inst);
  int cx = GetSystemMetrics (SM_CXSMICON);
  int cy = GetSystemMetrics (SM_CYSMICON);
  HICON hIcon = (HICON)LoadImage (
    g_hinst, lpszFilename, IMAGE_ICON, cx, cy,
    LR_LOADFROMFILE | LR_CREATEDIBSECTION);
  if (!hIcon)
    return -1;
  int idx = ImageList_AddIcon (il, hIcon);
  DestroyIcon (hIcon);
  return idx;
}

TV_API int WINAPI AddIcon (int viewId, HICON hIcon)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst || !hIcon)
    return -1;
  HIMAGELIST il = ensure_image_list (inst);
  return ImageList_AddIcon (il, hIcon);
}

TV_API BOOL WINAPI RemoveIcon (int viewId, int nImage)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst || !inst->image_list)
    return FALSE;
  return ImageList_Remove (inst->image_list, nImage);
}

TV_API BOOL WINAPI RemoveAllIcons (int viewId)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst || !inst->image_list)
    return FALSE;
  return ImageList_SetImageCount (inst->image_list, 0);
}

// --- Misc ---

TV_API BOOL WINAPI DisableCharJump (int viewId, BOOL bDisable)
{
  TreeViewInstance *inst = find_view (viewId);
  if (!inst)
    return FALSE;
  inst->disable_char_jump = bDisable;
  return TRUE;
}

TV_API int WINAPI SimpleTrackPopupMenu (LPCWSTR lpszFormat)
{
  // Format: L"label\nflags\nlabel\nflags\n..."
  int len = lstrlenW (lpszFormat) + 1;
  wchar_t *buf = (wchar_t *)HeapAlloc (GetProcessHeap (), 0, len * sizeof (wchar_t));
  if (!buf)
    return 0;
  lstrcpyW (buf, lpszFormat);

  HMENU menu = CreatePopupMenu ();
  wchar_t *ctx = 0;
  wchar_t *token = wcstok (buf, L"\n", &ctx);

  for (int i = 0; token; i++)
    {
      wchar_t *strFlag = wcstok (0, L"\n", &ctx);
      if (!strFlag)
        break;
      UINT flags = (UINT)wcstol (strFlag, 0, 10);
      AppendMenuW (menu, flags, i + 1, token);
      token = wcstok (0, L"\n", &ctx);
    }

  HeapFree (GetProcessHeap (), 0, buf);

  POINT pt;
  GetCursorPos (&pt);
  int res = TrackPopupMenu (menu,
    TPM_RETURNCMD | TPM_LEFTALIGN | TPM_RIGHTBUTTON,
    pt.x, pt.y, 0, GetActiveWindow (), 0);
  DestroyMenu (menu);
  return res;
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
      {
        INITCOMMONCONTROLSEX icc = {};
        icc.dwSize = sizeof icc;
        icc.dwICC = ICC_TREEVIEW_CLASSES;
        InitCommonControlsEx (&icc);
      }
      break;
    }
  return TRUE;
}
