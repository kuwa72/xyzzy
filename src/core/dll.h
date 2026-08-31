// -*-C++-*-
#ifndef _dll_h_
# define _dll_h_

class ldll_module: public lisp_object
{
public:
  lisp name;        // DLLの名前
  HMODULE handle;   // モジュールハンドル
  int loaded;       // LoadLibraryした場合は1, LoadModuleの場合は0

  ~ldll_module () {if (handle && loaded) FreeLibrary (handle);}
};

# define dll_module_p(X) typep ((X), Tdll_module)

inline void
check_dll_module (lisp x)
{
  check_type (x, Tdll_module, Qsi_dll_module);
}

inline lisp &
xdll_module_name (lisp x)
{
  assert (dll_module_p (x));
  return ((ldll_module *)x)->name;
}

inline HMODULE &
xdll_module_handle (lisp x)
{
  assert (dll_module_p (x));
  return ((ldll_module *)x)->handle;
}

inline int &
xdll_module_loaded (lisp x)
{
  assert (dll_module_p (x));
  return ((ldll_module *)x)->loaded;
}

# define CTYPE_VOID 0
# define CTYPE_INT8 1
# define CTYPE_UINT8 2
# define CTYPE_INT16 3
# define CTYPE_UINT16 4
# define CTYPE_INT32 5
# define CTYPE_UINT32 6
# define CTYPE_FLOAT 7
# define CTYPE_DOUBLE 8
# define CTYPE_INT64 9
# define CTYPE_UINT64 10

# define CALLING_CONVENTION_STDCALL 0
# define CALLING_CONVENTION_CDECL 1

class ldll_function: public lisp_object
{
public:
  lisp module;        // DLLモジュールオブジェクト
  lisp name;          // DLL内の名前
  FARPROC proc;       // 関数のポインタ
  u_char *arg_types;  // 引数の型
  u_short arg_size;   // 引数全体のサイズ
  u_char nargs;       // 引数の数
  u_char vaarg_p;     // 可変長引数を取るかどうか
  u_char return_type; // 戻り値の型

  ~ldll_function () {xfree (arg_types);}
};

#define dll_function_p(X) typep ((X), Tdll_function)

inline void
check_dll_function (lisp x)
{
  check_type (x, Tdll_function, Qsi_c_function);
}

inline lisp &
xdll_function_module (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->module;
}

inline lisp &
xdll_function_name (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->name;
}

inline FARPROC &
xdll_function_proc (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->proc;
}

inline u_char *&
xdll_function_arg_types (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->arg_types;
}

inline u_char &
xdll_function_nargs (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->nargs;
}

inline u_char &
xdll_function_vaarg_p (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->vaarg_p;
}

inline u_char &
xdll_function_return_type (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->return_type;
}

inline u_short &
xdll_function_arg_size (lisp x)
{
  assert (dll_function_p (x));
  return ((ldll_function *)x)->arg_size;
}

#if defined(_M_ARM64) || defined(__aarch64__) || defined(_M_X64) || defined(__x86_64__)
# define INSN_SIZE 64
#else
# define INSN_SIZE 16
#endif

class lc_callable;

/* オブジェクトが回収されるときに呼ぶ。**Win32 は何も要らない** (下の
   `insn[]` はオブジェクトの中にあるので一緒に消える) ので inline の空実装。
   POSIX は libffi の closure を解放する (src/core/dll-posix.cc)。 */
#ifdef _WIN32
inline void free_c_callable_stub (lc_callable *) {}
#else
void free_c_callable_stub (lc_callable *);
#endif

class lc_callable: public lisp_object
{
public:
  lisp function;      // 関数
  u_char *arg_types;  // 引数の型
  u_short arg_size;   // 引数全体のサイズ
  u_char nargs;       // 引数の数
  u_char return_type; // 戻り値の型
  u_char convention;  // 呼び出し規約
#ifdef _WIN32
  alignas(4) u_char insn[INSN_SIZE]; // stubコード
#else
  /* **C へ渡すアドレスの持ち方がプラットフォームで違う。**
     Win32 は上の `insn[]` に機械語を自分で書き、**その配列そのもの**を C へ
     渡す。POSIX は libffi の closure を使うが、あれは**自分で実行可能な
     メモリを確保して別のアドレスを返す** — Lisp オブジェクトの中の配列には
     入らないし、POSIX の Lisp ヒープは実行可能でないので、そこへ機械語を
     書く手も取れない。だから 2 本のポインタを持つ。

     `state` の中身 (`ffi_closure` と `ffi_cif`) は src/core/dll-posix.cc の
     中だけで見える。**`ffi.h` をここから引くと core の全 TU に広がる**ので、
     ここでは `void *` にしてある。 */
  void *state;
  void *code;
#endif

  ~lc_callable () {xfree (arg_types); free_c_callable_stub (this);}
};

#define c_callable_p(X) typep ((X), Tc_callable)

inline void
check_c_callable (lisp x)
{
  check_type (x, Tc_callable, Qsi_c_callable);
}

inline lisp &
xc_callable_function (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->function;
}

inline u_char *&
xc_callable_arg_types (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->arg_types;
}

inline u_char &
xc_callable_nargs (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->nargs;
}

inline u_char &
xc_callable_return_type (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->return_type;
}

inline u_short &
xc_callable_arg_size (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->arg_size;
}

inline u_char &
xc_callable_convention (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->convention;
}

#ifdef _WIN32
inline u_char *
xc_callable_insn (lisp x)
{
  assert (c_callable_p (x));
  return ((lc_callable *)x)->insn;
}
#endif

/* **C へ渡すアドレス。** Win32 は自分で機械語を書いた `insn[]`、POSIX は
   libffi の closure が用意したもの (`lc_callable` のコメントを参照)。
   `cast_to_int64` (src/core/chunk.cc) が `si:make-c-callable` の返り値を
   C の引数に変えるときに通る**唯一の場所**なので、そこだけ見ればよい。 */
inline void *
xc_callable_address (lisp x)
{
  assert (c_callable_p (x));
#ifdef _WIN32
  return ((lc_callable *)x)->insn;
#else
  return ((lc_callable *)x)->code;
#endif
}

/* **`make_dll_module' はここに置く。** 中身は枠を確保して 3 つ埋めるだけで
   プラットフォームに依らないが、定義は src/frontend/win32/dll.cc にあった。
   POSIX 側でも `si:load-dll-module' が要る (src/core/dll-posix.cc) ので、
   両方から使えるようにインラインにした。`make_process' (src/core/lprocess.h)
   と同じ形。

   下の 2 つは「関数を呼ぶ」側で、まだ Win32 だけにある (issue #133)。 */
inline ldll_module *
make_dll_module ()
{
  ldll_module *p = ldata <ldll_module, Tdll_module>::lalloc ();
  p->name = Qnil;
  p->handle = 0;
  p->loaded = 0;
  return p;
}

/* **`make_c_callable' も同じ理由でここ。** 前は「関数を呼ぶ側」として
   src/frontend/win32/dll.cc と src/core/dll-posix.cc の両方に同じ物が
   置いてあったが、`Fsi_make_c_callable' を core (src/core/dll-call.cc) へ
   移したので、**Win32 の xyzzy-cli.exe が win32/dll.cc をリンクしないまま
   これを参照する**ようになった。中身は枠を埋めるだけなのでインラインにする。
   プラットフォームの違いは `lc_callable' の欄そのもの (`insn[]` か
   ポインタ 2 本か) で、そこだけ分かれる。 */
inline lc_callable *
make_c_callable ()
{
  lc_callable *p = ldata <lc_callable, Tc_callable>::lalloc ();
  p->function = Qnil;
  p->arg_types = 0;
  p->nargs = 0;
  p->return_type = 0;
  p->arg_size = 0;
#ifndef _WIN32
  p->state = 0;
  p->code = 0;
#endif
  return p;
}

ldll_function *make_dll_function ();
lisp funcall_dll (lisp fn, lisp arglist);
lisp funcall_c_callable (lisp, lisp);
void init_c_callable (lisp);

/* **型の検査と大きさの計算は src/core/dll-call.cc にある。** 実際に呼ぶ所
   (`funcall_dll') はプラットフォームごとに分かれていて (i386 はスタックを
   自分で組む、Win32 は SEH を張る)、そこから使う (issue #133)。 */
u_char check_c_type (lisp type);
u_char check_calling_convention (lisp keys);
int calc_c_size (u_char type);
u_char check_vaarg_type (lisp type);
void check_vaargs (lisp vaargs);
int calc_vaarg_size (lisp fn, lisp arglist);
int calc_argument_size (u_char *at, lisp largs);

/* 直前の呼び出しのエラー番号を `si:last-win32-error' から見えるように覚える。
   非 Win32 では `GetLastError ()' が errno を返す (src/core/platform.h)。 */
inline void
save_last_error ()
{
  xsymbol_value (Vlast_win32_error) = make_fixnum (GetLastError ());
}

#endif
