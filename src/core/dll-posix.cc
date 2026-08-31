// dll-posix.cc -- `si:load-dll-module' と `si:make-c-function' の POSIX 版。
//
// 読み込みは `dlopen` / `dlsym` / `dlclose` で足りる。**呼び出しは libffi。**
// `si:make-c-callable' (Lisp の関数を C から呼べるアドレスにする) はまだ無い
// -- issue #133 の段階 4。
//
// Win32 側は src/frontend/win32/dll.cc。あちらは `GetModuleHandleW` で
// 「もう読み込んである物」を先に探すが、POSIX の `dlopen` は同じ物を二度
// 開いても同じハンドルを返して参照数を増やすので、その区別が要らない
// (`loaded` は常に 1 で、デストラクタが `dlclose` する)。

#include "stdafx.h"
#include "ed.h"
#include "dll.h"

#include <ffi.h>

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
 * **libffi で呼ぶ。** 以前ここには「libffi は要らない。関数ポインタを引数の
 * 個数に合った型 (`int64_t (*)(int64_t, ...)`) へキャストして呼べば、
 * 呼び出し規約はコンパイラが出す」と書いてあった (src/frontend/win32/dll.cc の
 * x86_64 の枝がその形で、そこから持ってきた)。**整数とポインタだけならそれで
 * 足りるが、float / double には届かない。**
 *
 *   * 固定引数の float / double は、SysV が整数と浮動小数で**別のレジスタ列**を
 *     使うので、int64_t を並べたキャストでは渡る場所が違う。
 *   * 可変長引数の double は**もっと悪い**。SysV x86_64 では `al` に
 *     「ベクタレジスタを何本使ったか」を入れる約束で、整数の関数型へキャスト
 *     して呼ぶと `al` が 0 になり、呼ばれた側はレジスタ保存領域の浮動小数の欄を
 *     **埋めないまま**読む。1 個だけなら直前の xmm に残った値で偶然合うことが
 *     あり、それが「通ることもある」の正体だった。2 個目で SIGSEGV になる。
 *
 * **Win64 に同じ問題が無いので、Wine のジョブでは可変長引数のテストが通って
 * いた。** あちらは可変長引数の double を整数レジスタにも置く。SysV 固有の話で
 * あり、「Windows で通るなら実装が正しい」が成り立たない類である。
 *
 * libffi は呼び出し規約を実行時に組み立てるためのライブラリで、可変長引数も
 * `ffi_prep_cif_var` で扱える。**「既定の引数の格上げ」(char/short -> int、
 * float -> double) は呼ぶ側の仕事**だが、それは `check_vaarg_type`
 * (src/core/dll-call.cc) が既にやっている — Win32 側も同じ関数を通るので、
 * ここで書き足すものは無い。
 *
 * stdcall と cdecl の区別は要らない (POSIX には規約が 1 つしか無い)。
 * `FFI_DEFAULT_ABI` がその 1 つを指す。
 *
 * SEH は無いので張らない。**Win32 側はハードウェア例外を Lisp の
 * win32-exception にして返すが、POSIX でそれに相当するのは SIGSEGV で、
 * 拾って Lisp へ戻す仕組みが無い** (既知失敗の handle-* 3 件がそれ)。
 * 落ちるべきものは落ちる。
 */

/* CTYPE_* から libffi の型へ。**幅と符号をそのまま写す**のが要点で、
   以前のキャスト版のように全部 int64_t に潰してはいけない (潰すと、その幅の
   引数を期待している呼び先で上位のごみが見える)。

   ポインタに専用の CTYPE は無い。Lisp 側の `c:string` などは
   `#+64bit :int64 #-64bit :int32` に展開されるので (unittest/foreign-test.l の
   `expand-c-vaargs` を参照)、幅の合った整数として通る。 */
static ffi_type *
c_type_to_ffi_type (u_char t)
{
  switch (t)
    {
    case CTYPE_VOID:   return &ffi_type_void;
    case CTYPE_INT8:   return &ffi_type_sint8;
    case CTYPE_UINT8:  return &ffi_type_uint8;
    case CTYPE_INT16:  return &ffi_type_sint16;
    case CTYPE_UINT16: return &ffi_type_uint16;
    case CTYPE_INT32:  return &ffi_type_sint32;
    case CTYPE_UINT32: return &ffi_type_uint32;
    case CTYPE_INT64:  return &ffi_type_sint64;
    case CTYPE_UINT64: return &ffi_type_uint64;
    case CTYPE_FLOAT:  return &ffi_type_float;
    case CTYPE_DOUBLE: return &ffi_type_double;
    }
  assert (0);
  return &ffi_type_void;
}

/* libffi は「値そのものを持つ領域へのポインタ」を受け取るので、引数 1 つに
   つきその型の大きさの箱が要る。共用体 1 つで足りる。 */
union c_arg_value
{
  int8_t i8;
  uint8_t u8;
  int16_t i16;
  uint16_t u16;
  int32_t i32;
  uint32_t u32;
  int64_t i64;
  uint64_t u64;
  float f;
  double d;
};

static void
store_c_arg (c_arg_value *v, u_char t, lisp x)
{
  switch (t)
    {
    case CTYPE_INT8:   v->i8 = int8_t (cast_to_int64 (x)); break;
    case CTYPE_UINT8:  v->u8 = uint8_t (cast_to_int64 (x)); break;
    case CTYPE_INT16:  v->i16 = int16_t (cast_to_int64 (x)); break;
    case CTYPE_UINT16: v->u16 = uint16_t (cast_to_int64 (x)); break;
    case CTYPE_INT32:  v->i32 = int32_t (cast_to_int64 (x)); break;
    case CTYPE_UINT32: v->u32 = uint32_t (cast_to_int64 (x)); break;
    case CTYPE_INT64:  v->i64 = cast_to_int64 (x); break;
    case CTYPE_UINT64: v->u64 = uint64_t (cast_to_int64 (x)); break;
    /* Win32 側の `push_arg' と同じ 2 つの変換を通す。整数を書いても
       `(sprintf ... (c:double 1))' のように通るのはここのおかげである。 */
    case CTYPE_FLOAT:  v->f = coerce_to_single_float (x); break;
    case CTYPE_DOUBLE: v->d = coerce_to_double_float (x); break;
    default:           assert (0); break;
    }
}

/* `make_c_callable' は src/core/dll.h のインラインへ移した (Win32 側にも
   同じ物があり、`Fsi_make_c_callable' を core へ移したので両方から要る)。 */

lisp
funcall_c_callable (lisp fn, lisp arglist)
{
  /* Win32 側と同じ。**Lisp から `c-callable` オブジェクトを直に funcall した
     ときの経路**で、C から呼ばれる経路 (下の trampoline) とは別。 */
  QUIT;
  return Ffuncall (xc_callable_function (fn), arglist);
}

/*
 * `si:make-c-callable' (issue #133 の段階 4)。
 *
 * **置き場所が Win32 と違う。** あちらは `lc_callable::insn[64]` に機械語を
 * 書き、**その配列そのもの**のアドレスを C へ渡す (ABI ごとに 3 通りの
 * 機械語が src/frontend/win32/dll.cc にある)。libffi の closure は
 * **自分で実行可能なメモリを確保して別のアドレスを返す**ので、Lisp
 * オブジェクトの中の配列には入らない。**POSIX の Lisp ヒープは実行可能では
 * ない**ので、そこへ機械語を書く手も取れない。
 *
 * なので `lc_callable` は非 Win32 では `insn[]` の代わりに 2 本のポインタを
 * 持ち (`state` と `code`)、C へ渡すアドレスは `xc_callable_address` が
 * 選ぶ (src/core/dll.h)。**`ffi_cif` の寿命は closure と同じでなければ
 * ならない** (呼ばれるたびに libffi が読む) ので、`atypes` ごと下の
 * 構造体に入れてオブジェクトと一緒に持つ。
 */

struct c_callable_state
{
  ffi_closure *closure;
  ffi_cif cif;
  ffi_type **atypes;    /* nargs 個。cif が指しているので一緒に持つ */
};

/* C から呼ばれる側。`user_data` は `lc_callable` そのもの。 */
static void
c_callable_trampoline (ffi_cif *, void *ret, void **args, void *user_data)
{
  lisp cc = (lisp)user_data;
  int nargs = xc_callable_nargs (cc);
  const u_char *at = xc_callable_arg_types (cc);

  lisp largs = Qnil;
  for (int i = nargs - 1; i >= 0; i--)
    {
      lisp v;
      switch (at[i])
        {
        case CTYPE_INT8:   v = make_fixnum (*(int8_t *)args[i]); break;
        case CTYPE_UINT8:  v = make_fixnum (*(uint8_t *)args[i]); break;
        case CTYPE_INT16:  v = make_fixnum (*(int16_t *)args[i]); break;
        case CTYPE_UINT16: v = make_fixnum (*(uint16_t *)args[i]); break;
        case CTYPE_INT32:  v = make_fixnum (*(int32_t *)args[i]); break;
        case CTYPE_UINT32: v = make_integer (int64_t (*(uint32_t *)args[i])); break;
        case CTYPE_INT64:  v = make_integer (*(int64_t *)args[i]); break;
        case CTYPE_UINT64: v = make_integer (*(uint64_t *)args[i]); break;
        case CTYPE_FLOAT:  v = make_single_float (*(float *)args[i]); break;
        case CTYPE_DOUBLE: v = make_double_float (*(double *)args[i]); break;
        default:           v = Qnil; assert (0); break;
        }
      largs = xcons (v, largs);
    }

  /* 返り値の欄は libffi が確保したもので、**呼び出し元が読む。** Lisp が
     throw して抜けた場合でも何か入っていなければならないので、先に 0 を
     置いておく。 */
  u_char rt = xc_callable_return_type (cc);
  if (rt == CTYPE_FLOAT)
    *(float *)ret = 0;
  else if (rt == CTYPE_DOUBLE)
    *(double *)ret = 0;
  else if (rt != CTYPE_VOID)
    *(ffi_arg *)ret = 0;

  protect_gc gcpro (largs);
  try
    {
      lisp result = Ffuncall (xc_callable_function (cc), largs);
      switch (rt)
        {
        case CTYPE_VOID:
          break;
        case CTYPE_FLOAT:
          *(float *)ret = coerce_to_single_float (result);
          break;
        case CTYPE_DOUBLE:
          *(double *)ret = coerce_to_double_float (result);
          break;
        default:
          /* 幅の狭い整数も `ffi_arg` の幅で書く約束 (libffi が呼び出し元の
             期待する幅に切る)。 */
          *(ffi_arg *)ret = ffi_arg (cast_to_int64 (result));
          break;
        }
    }
  catch (nonlocal_jump &)
    {
      /* **C の枠を Lisp の throw で飛び越えさせない。** Win32 側の
         `c_callable_stub_*` も同じ形で止めている。 */
    }
}

void
init_c_callable (lisp cc)
{
  /* **先に 0 を入れる。** ダンプイメージからの読み込み (src/core/data.cc の
     `rdump_object') はスカラの欄だけを読んで枠は `make_c_callable' を通らない
     ので、下で失敗して戻ったときに**前の中身が残っていると、デストラクタが
     それを解放しようとする。** */
  ((lc_callable *)cc)->state = 0;
  ((lc_callable *)cc)->code = 0;

  int nargs = xc_callable_nargs (cc);
  const u_char *at = xc_callable_arg_types (cc);

  c_callable_state *st = (c_callable_state *)xmalloc (sizeof *st);
  st->closure = 0;
  st->atypes = nargs ? (ffi_type **)xmalloc (nargs * sizeof *st->atypes) : 0;
  for (int i = 0; i < nargs; i++)
    st->atypes[i] = c_type_to_ffi_type (at[i]);

  void *code = 0;
  st->closure = (ffi_closure *)ffi_closure_alloc (sizeof (ffi_closure), &code);
  if (!st->closure
      || ffi_prep_cif (&st->cif, FFI_DEFAULT_ABI, nargs,
                       c_type_to_ffi_type (xc_callable_return_type (cc)),
                       st->atypes) != FFI_OK
      || ffi_prep_closure_loc (st->closure, &st->cif, c_callable_trampoline,
                               cc, code) != FFI_OK)
    {
      /* **ここで例外を投げてはいけない。** `init_c_callable' はダンプ
         イメージの読み込み中 (src/core/data.cc の `rdump_object') からも
         呼ばれ、そこは Lisp のコンディションを投げられる場所ではない。
         アドレスを 0 のままにしておけば、C へ渡そうとした側が 0 を見る。 */
      if (st->closure)
        ffi_closure_free (st->closure);
      xfree (st->atypes);
      xfree (st);
      return;
    }

  ((lc_callable *)cc)->state = st;
  ((lc_callable *)cc)->code = code;
}

void
free_c_callable_stub (lc_callable *cc)
{
  c_callable_state *st = (c_callable_state *)cc->state;
  if (!st)
    return;
  ffi_closure_free (st->closure);
  xfree (st->atypes);
  xfree (st);
  cc->state = 0;
  cc->code = 0;
}

lisp
funcall_dll (lisp fn, lisp arglist)
{
  assert (dll_function_p (fn));

  if (!xdll_function_proc (fn))
    FEprogram_error (Edll_not_initialized, fn);

  /* 上限は libffi の制限ではなく**下の配列の大きさ**である。以前は
     「int64_t を並べた関数型のキャストを 12 個書いてあった」ので 12 だった。
     `nargs` は u_char なので 255 まで来る -- 数え上げの前に見る。 */
  enum {MAX_ARGS = 64};

  int nargs = xdll_function_nargs (fn);
  if (nargs > MAX_ARGS)
    FEtoo_many_arguments ();

  ffi_type *atypes[MAX_ARGS];
  c_arg_value avalues[MAX_ARGS];
  void *aptrs[MAX_ARGS];

  int total = 0;
  const u_char *at = xdll_function_arg_types (fn);
  for (int i = 0; i < nargs; i++, arglist = xcdr (arglist))
    {
      if (!consp (arglist))
        FEtoo_few_arguments ();
      atypes[total] = c_type_to_ffi_type (at[i]);
      store_c_arg (&avalues[total], at[i], xcar (arglist));
      total++;
    }

  int nfixed = total;

  if (consp (arglist) && xdll_function_vaarg_p (fn))
    {
      lisp vaargs = xcar (arglist);
      check_vaargs (vaargs);
      for (; consp (vaargs); vaargs = xcdr (vaargs))
        {
          if (total >= MAX_ARGS)
            FEtoo_many_arguments ();
          lisp vaarg = xcar (vaargs);
          /* **格上げはここで済んでいる。** `check_vaarg_type' が char / short を
             int に、float を double にして返す (src/core/dll-call.cc)。
             libffi の `ffi_prep_cif_var' は格上げ済みの型を要求するので、
             ちょうど噛み合う。 */
          u_char t = check_vaarg_type (xcar (vaarg));
          atypes[total] = c_type_to_ffi_type (t);
          store_c_arg (&avalues[total], t, Fcadr (vaarg));
          total++;
        }
      arglist = xcdr (arglist);
    }

  if (consp (arglist))
    FEtoo_many_arguments ();

  u_char rt = xdll_function_return_type (fn);

  /* 可変長引数を取る関数は、可変長の分を 1 つも渡さなかった場合でも
     `ffi_prep_cif_var' で組む。**呼ばれる側の宣言が変わるわけではない**ので、
     渡した数で切り替えると同じ関数を 2 通りの規約で呼ぶことになる。 */
  ffi_cif cif;
  ffi_status st = (xdll_function_vaarg_p (fn)
                   ? ffi_prep_cif_var (&cif, FFI_DEFAULT_ABI, nfixed, total,
                                       c_type_to_ffi_type (rt), atypes)
                   : ffi_prep_cif (&cif, FFI_DEFAULT_ABI, total,
                                   c_type_to_ffi_type (rt), atypes));
  if (st != FFI_OK)
    FEprogram_error (Edll_not_initialized, fn);

  for (int i = 0; i < total; i++)
    aptrs[i] = &avalues[i];

  /* 返り値の箱は **`ffi_arg` より小さくてはいけない。** libffi は幅の狭い
     整数をレジスタの幅まで広げて書くので、`int8_t` の箱を渡すと隣を潰す。 */
  union
  {
    ffi_arg i;
    float f;
    double d;
  } rv = {};

  ffi_call (&cif, xdll_function_proc (fn), &rv, aptrs);
  save_last_error ();

  if (rt == CTYPE_DOUBLE)
    return make_double_float (rv.d);
  if (rt == CTYPE_FLOAT)
    return make_single_float (rv.f);

  /* 広げて書かれた物を、宣言された幅と符号で読み直す。 */
  int64_t r = int64_t (rv.i);

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
