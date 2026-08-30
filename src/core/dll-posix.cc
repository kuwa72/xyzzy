// dll-posix.cc -- `si:load-dll-module' の POSIX 版。
//
// **これは issue #133 の段階 1 だけ。** 共有ライブラリを開いてハンドルを
// 持つところまでで、**そこにある関数を呼ぶ部分 (`si:make-c-function' /
// `si:make-c-callable') はまだ無い。**
//
// 分けたのは依存の都合である。読み込みは `dlopen` / `dlsym` / `dlclose` で
// 足り、**新しいライブラリを要らない。** いっぽう呼び出しは呼び出し規約
// (x86_64 SysV、aarch64 AAPCS) とクロージャの生成が必要で、素直にやるなら
// libffi に依存する。**Linux ビルドの依存を ncurses と zlib だけに保つか
// どうかはプロジェクトの方針なので、issue #133 に判断を残してある。**
//
// 段階 1 だけでも `si:load-dll-module` と `si:dll-module-p` が動くので、
// ライブラリが在るかどうかを Lisp から確かめられるようになる。
//
// Win32 側は src/frontend/win32/dll.cc。あちらは `GetModuleHandleW` で
// 「もう読み込んである物」を先に探すが、POSIX の `dlopen` は同じ物を二度
// 開いても同じハンドルを返して参照数を増やすので、その区別が要らない
// (`loaded` は常に 1 で、デストラクタが `dlclose` する)。

#include "stdafx.h"
#include "ed.h"
#include "dll.h"

/* 既に開いてある物を名前で探す。win32/dll.cc の `find_module' と同じ。
   **同じ名前で二度 `dlopen` しても参照数が増えるだけ**だが、Lisp から見て
   同じモジュールに同じオブジェクトを返した方が `eq` が期待どおりに働く。 */
static lisp
find_module (lisp name)
{
  for (lisp p = xsymbol_value (Vdll_module_list); consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (dll_module_p (x)
          && xdll_module_handle (x)
          && Fstring_equalp (xdll_module_name (x), name, Qnil) != Qnil)
        return x;
    }
  return Qnil;
}

lisp
Fsi_load_dll_module (lisp lname)
{
  check_string (lname);

  lisp dll = find_module (lname);
  if (dll != Qnil)
    return dll;

  if (xstring_length (lname) > PATH_MAX)
    FEsimple_error (Epath_name_too_long, lname);

  /* Unix のパスは UTF-8 のバイト列。内部表現は ucs4 なので直して渡す
     (src/core/vfs-posix.cc の os_path と同じ考え方)。 */
  char name[PATH_MAX * 4 + 1];
  i2u8 (xstring_contents (lname), xstring_length (lname), name);

  /* RTLD_LOCAL: 読み込んだ物の記号を他へ漏らさない。Win32 の LoadLibrary が
     そうなので合わせる。 */
  void *h = dlopen (name, RTLD_LAZY | RTLD_LOCAL);
  if (!h)
    {
      /* **`dlerror' の文言を捨てない。** 「読めなかった」だけでは、名前が
         違うのか、依存している別のライブラリが無いのか分からない。
         `dlopen` は errno を立てないので、`file_error` の類は使えない。 */
      const char *e = dlerror ();
      /* **文言に format の指示子を書かない。** `FEsimple_error (code, arg)`
         の経路は「文言 + `: ` + 引数」を並べるだけで format を掛けないので、
         `~A' と書くと字のまま出る (`Epath_name_too_long' などと同じ形にした)。
         `dlerror' の文字列はライブラリ名を含んでいるので、これ 1 つで足りる。 */
      FEsimple_error (Ecannot_load_shared_library,
                      make_string (e ? e : name));
    }

  dll = make_dll_module ();
  lisp list = xcons (dll, xsymbol_value (Vdll_module_list));
  xdll_module_name (dll) = lname;
  xdll_module_handle (dll) = h;
  xdll_module_loaded (dll) = 1;
  xsymbol_value (Vdll_module_list) = list;
  return dll;
}
