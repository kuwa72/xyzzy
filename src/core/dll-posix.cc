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

/*
 * FFI の呼び出し側 (issue #133 の段階 2 と 3)。
 *
 * **libffi は要らない。** 関数ポインタを引数の個数に合った型へキャストして
 * 呼べば、**呼び出し規約はコンパイラが出す。** src/frontend/win32/dll.cc の
 * x86_64 の枝が同じ形で書かれていて、そこから持ってきた。POSIX x86_64 /
 * aarch64 には規約が 1 つしか無いので、stdcall と cdecl の区別も要らない。
 *
 * **float / double の引数は受け付けない。可変長引数も同じ。** SysV では整数と浮動小数で別の
 * レジスタ列を使うので、int64_t を並べるキャスト 1 本では渡せない。
 * **これは Win32 の x86_64 側と同じ制限**で、あちらも同じ理由で断っている
 * (返り値の float / double は別の型でキャストすれば渡せるので、そちらは通る)。
 *
 * SEH は無いので張らない。**Win32 側はハードウェア例外を Lisp の
 * win32-exception にして返すが、POSIX でそれに相当するのは SIGSEGV で、
 * 拾って Lisp へ戻す仕組みが無い** (既知失敗の handle-* 3 件がそれ)。
 * 落ちるべきものは落ちる。
 */

lc_callable *
make_c_callable ()
{
  lc_callable *p = ldata <lc_callable, Tc_callable>::lalloc ();
  p->function = Qnil;
  p->arg_types = 0;
  p->nargs = 0;
  p->return_type = 0;
  p->arg_size = 0;
  return p;
}

lisp
funcall_c_callable (lisp, lisp)
{
  /* **Lisp の関数を C から呼べるアドレスにするのは、まだできない。**
     実行時に機械語を作る必要がある (lc_callable::insn)。ABI ごとに書くか
     libffi の closure を使うかの判断が残っている (issue #133 の段階 4)。 */
  FEsimple_error (Edll_not_initialized);
  return Qnil;
}

void
init_c_callable (lisp)
{
}

lisp
funcall_dll (lisp fn, lisp arglist)
{
  assert (dll_function_p (fn));

  if (!xdll_function_proc (fn))
    FEprogram_error (Edll_not_initialized, fn);

  int nargs = xdll_function_nargs (fn);
  int total = nargs;

  int64_t a[12] = {};
  const u_char *at = xdll_function_arg_types (fn);
  for (int i = 0; i < nargs; i++, arglist = xcdr (arglist))
    {
      if (!consp (arglist))
        FEtoo_few_arguments ();
      lisp x = xcar (arglist);
      switch (at[i])
        {
        case CTYPE_FLOAT:
        case CTYPE_DOUBLE:
          /* 上の注を参照。Win32 の x86_64 側と同じ理由で断る。 */
          FEprogram_error (Edll_not_initialized, fn);
          break;
        default:
          a[i] = cast_to_int64 (x);
          break;
        }
    }

  if (consp (arglist) && xdll_function_vaarg_p (fn))
    {
      lisp vaargs = xcar (arglist);
      check_vaargs (vaargs);
      for (; consp (vaargs); vaargs = xcdr (vaargs))
        {
          if (total >= 12)
            FEprogram_error (Edll_not_initialized, fn);
          lisp vaarg = xcar (vaargs);
          u_char t = check_vaarg_type (xcar (vaarg));
          lisp val = Fcadr (vaarg);
          switch (t)
            {
            case CTYPE_FLOAT:
            case CTYPE_DOUBLE:
              /* **断る。落ちるので。**
                 ここは「ビット列を整数の枠で渡す。受け側が整数として読むなら
                 通る」と書いて通していた (Win32 の x86_64 側と同じ扱い)。
                 **測ったら通らないどころか SIGSEGV でエディタが落ちた。**

                     (sprintf b "foo: %d, %.3f, %s"
                              (c:c-vaargs (c:int 123) (c:double 1.23)
                                          (c:string ...)))
                     -> Fatal signal 11 (_IO_sprintf の中)

                 SysV x86_64 の可変長引数では、**`al` に「ベクタレジスタを
                 何本使ったか」を入れる約束**になっている。整数の関数型へ
                 キャストして呼ぶと `al` は 0 になり、呼ばれた側は
                 レジスタ保存領域の浮動小数の欄を**埋めないまま**読む。
                 1 個だけなら直前の xmm に残った値で偶然合うことがあり、
                 それが「通ることもある」の正体だった。

                 **正しくやるには段階 4 と同じ仕掛け (ABI ごとの機械語か
                 libffi) が要る** (issue #133)。それまでは、間違った値を返す
                 より落ちない方を選ぶ。固定引数の float / double を断って
                 いるのと同じ理由・同じ返し方にした。 */
              FEprogram_error (Edll_not_initialized, fn);
              break;
            default:
              a[total] = cast_to_int64 (val);
              break;
            }
          total++;
        }
      arglist = xcdr (arglist);
    }

  if (consp (arglist))
    FEtoo_many_arguments ();

  FARPROC proc = xdll_function_proc (fn);

  typedef int64_t (*f0)();
  typedef int64_t (*f1)(int64_t);
  typedef int64_t (*f2)(int64_t, int64_t);
  typedef int64_t (*f3)(int64_t, int64_t, int64_t);
  typedef int64_t (*f4)(int64_t, int64_t, int64_t, int64_t);
  typedef int64_t (*f5)(int64_t, int64_t, int64_t, int64_t, int64_t);
  typedef int64_t (*f6)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t);
  typedef int64_t (*f7)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                        int64_t);
  typedef int64_t (*f8)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                        int64_t, int64_t);
  typedef int64_t (*f9)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                        int64_t, int64_t, int64_t);
  typedef int64_t (*f10)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                         int64_t, int64_t, int64_t, int64_t);
  typedef int64_t (*f11)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                         int64_t, int64_t, int64_t, int64_t, int64_t);
  typedef int64_t (*f12)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t,
                         int64_t, int64_t, int64_t, int64_t, int64_t, int64_t);

  /* 返り値が float / double のときだけ、返り値の型を持つ関数型でキャストする
     (整数の枠で受け取ると XMM から取れない)。引数は同じ並べ方でよい。 */
  u_char rt = xdll_function_return_type (fn);
  if (rt == CTYPE_FLOAT || rt == CTYPE_DOUBLE)
    {
      typedef double (*d0)();
      typedef double (*d1)(int64_t);
      typedef double (*d2)(int64_t, int64_t);
      typedef double (*d3)(int64_t, int64_t, int64_t);
      typedef double (*d4)(int64_t, int64_t, int64_t, int64_t);
      typedef float (*s0)();
      typedef float (*s1)(int64_t);
      typedef float (*s2)(int64_t, int64_t);
      typedef float (*s3)(int64_t, int64_t, int64_t);
      typedef float (*s4)(int64_t, int64_t, int64_t, int64_t);

      if (total > 4)
        FEprogram_error (Edll_not_initialized, fn);

      if (rt == CTYPE_DOUBLE)
        {
          double dr = 0;
          switch (total)
            {
            case 0: dr = ((d0)proc)(); break;
            case 1: dr = ((d1)proc)(a[0]); break;
            case 2: dr = ((d2)proc)(a[0], a[1]); break;
            case 3: dr = ((d3)proc)(a[0], a[1], a[2]); break;
            case 4: dr = ((d4)proc)(a[0], a[1], a[2], a[3]); break;
            }
          save_last_error ();
          return make_double_float (dr);
        }

      float sr = 0;
      switch (total)
        {
        case 0: sr = ((s0)proc)(); break;
        case 1: sr = ((s1)proc)(a[0]); break;
        case 2: sr = ((s2)proc)(a[0], a[1]); break;
        case 3: sr = ((s3)proc)(a[0], a[1], a[2]); break;
        case 4: sr = ((s4)proc)(a[0], a[1], a[2], a[3]); break;
        }
      save_last_error ();
      return make_single_float (sr);
    }

  int64_t r = 0;
  switch (total)
    {
    case 0:  r = ((f0)proc)(); break;
    case 1:  r = ((f1)proc)(a[0]); break;
    case 2:  r = ((f2)proc)(a[0], a[1]); break;
    case 3:  r = ((f3)proc)(a[0], a[1], a[2]); break;
    case 4:  r = ((f4)proc)(a[0], a[1], a[2], a[3]); break;
    case 5:  r = ((f5)proc)(a[0], a[1], a[2], a[3], a[4]); break;
    case 6:  r = ((f6)proc)(a[0], a[1], a[2], a[3], a[4], a[5]); break;
    case 7:  r = ((f7)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6]); break;
    case 8:  r = ((f8)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]); break;
    case 9:  r = ((f9)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
                            a[8]); break;
    case 10: r = ((f10)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
                             a[8], a[9]); break;
    case 11: r = ((f11)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
                             a[8], a[9], a[10]); break;
    case 12: r = ((f12)proc)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
                             a[8], a[9], a[10], a[11]); break;
    default:
      FEprogram_error (Edll_not_initialized, fn);
    }

  save_last_error ();

  switch (rt)
    {
    default:
      assert (0);

    case CTYPE_VOID:
      return Qnil;

    case CTYPE_INT8:
      return make_fixnum ((char)r);

    case CTYPE_UINT8:
      return make_fixnum ((u_char)r);

    case CTYPE_INT16:
      return make_fixnum ((short)r);

    case CTYPE_UINT16:
      return make_fixnum ((u_short)r);

    case CTYPE_INT32:
      return make_fixnum ((int32_t)r);

    case CTYPE_UINT32:
      return make_integer ((int64_t)(uint32_t)r);

    case CTYPE_INT64:
      return make_integer ((int64_t)r);

    case CTYPE_UINT64:
      return make_integer ((uint64_t)r);
    }
}
