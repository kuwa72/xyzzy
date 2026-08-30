// -*-C++-*-
//
// FFI の、プラットフォームに依らない部分。
//
// * `si:make-c-function' — DLL の中の関数を Lisp のオブジェクトにする
// * 型の検査 (`:int32' などのキーワード -> CTYPE_*) と大きさの計算
// * 可変長引数の既定の格上げ (char/short -> int、float -> double)
// * `si:last-win32-error' — 直前の呼び出しのエラー番号
//
// **実際に呼ぶ所 (`funcall_dll') は分かれている。** i386 はスタックを自分で
// 組む必要があり、Win32 は SEH でハードウェア例外を拾う。そこだけが
// src/frontend/win32/dll.cc と src/core/dll-posix.cc に分かれていて、
// ここはどちらからも使う (issue #133)。
//
// **`GetProcAddress' は非 Win32 では `dlsym' の別名** (src/core/platform.h)。

#include "stdafx.h"
#include "ed.h"
#include "except.h"

ldll_function *
make_dll_function ()
{
  ldll_function *p = ldata <ldll_function, Tdll_function>::lalloc ();
  p->module = Qnil;
  p->name = Qnil;
  p->proc = 0;
  p->arg_types = 0;
  p->nargs = 0;
  p->return_type = 0;
  p->arg_size = 0;
  return p;
}

u_char
check_c_type (lisp type)
{
  if (type == Kvoid)
    return CTYPE_VOID;
  if (type == Kint8)
    return CTYPE_INT8;
  if (type == Kuint8)
    return CTYPE_UINT8;
  if (type == Kint16)
    return CTYPE_INT16;
  if (type == Kuint16)
    return CTYPE_UINT16;
  if (type == Kint32)
    return CTYPE_INT32;
  if (type == Kuint32)
    return CTYPE_UINT32;
  if (type == Kint64)
    return CTYPE_INT64;
  if (type == Kuint64)
    return CTYPE_UINT64;
  if (type == Kfloat)
    return CTYPE_FLOAT;
  if (type == Kdouble)
    return CTYPE_DOUBLE;
  FEprogram_error (Eunknown_c_type, type);
  return 0;
}

u_char
check_calling_convention (lisp keys)
{
  lisp convention = find_keyword (Kconvention, keys);
  if (convention == Qnil || convention == Kstdcall)
    return CALLING_CONVENTION_STDCALL;
  if (convention == Kcdecl)
    return CALLING_CONVENTION_CDECL;
  FEprogram_error (Eunknown_calling_convention, convention);
  return 0;
}

int
calc_c_size (u_char type)
{
  switch (type)
    {
    case CTYPE_INT8:
    case CTYPE_UINT8:
    case CTYPE_INT16:
    case CTYPE_UINT16:
    case CTYPE_INT32:
    case CTYPE_UINT32:
      return sizeof (int);

    case CTYPE_INT64:
    case CTYPE_UINT64:
      return sizeof (int64_t);

    case CTYPE_FLOAT:
      return sizeof (float);

    case CTYPE_DOUBLE:
      return sizeof (double);

    default:
      assert (0);
    }
  return 0;
}

u_char
check_vaarg_type (lisp type)
{
  u_char t = check_c_type (type);

  // default argument promotions
  switch (t)
    {
    case CTYPE_INT8:
    case CTYPE_INT16:
      t = CTYPE_INT32;
      break;

    case CTYPE_UINT8:
    case CTYPE_UINT16:
      t = CTYPE_UINT32;
      break;

    case CTYPE_FLOAT:
      t = CTYPE_DOUBLE;
      break;
    }

  return t;
}

void
check_vaargs (lisp vaargs)
{
  if (vaargs == Qnil)
    return;

  if (!consp (vaargs))
    FEprogram_error (Einvalid_c_vaarg_type, vaargs);

  for (; consp (vaargs); vaargs = xcdr (vaargs))
    {
      lisp vaarg = xcar (vaargs);
      if (!consp (vaarg) || xlist_length (vaarg) != 2)
        FEprogram_error (Einvalid_c_vaarg_type, vaargs);

      u_char t = check_c_type (xcar (vaarg));
      if (t == CTYPE_VOID)
        FEprogram_error (Einvalid_c_vaarg_type, vaargs);
    }
}

int
calc_vaarg_size (lisp fn, lisp arglist)
{
  if (!xdll_function_vaarg_p (fn))
    return 0;

  int nargs = xdll_function_nargs (fn);
  lisp vaargs = Fnth (make_fixnum (nargs), arglist);
  if (vaargs == Qnil)
    return 0;

  check_vaargs (vaargs);
  int size = 0;
  for (; consp (vaargs); vaargs = xcdr (vaargs))
    {
      u_char t = check_vaarg_type (Fcaar (vaargs));
      size += calc_c_size (t);
    }
  return size;
}

int
calc_argument_size (u_char *at, lisp largs)
{
  int size = 0;
  for (lisp a = largs; consp (a); a = xcdr (a))
    {
      u_char t = check_c_type (xcar (a));
      *at++ = t;
      size += calc_c_size (t);
    }
  return size;
}

lisp
Fsi_make_c_function (lisp lmodule, lisp lname, lisp largs, lisp lrettype, lisp keys)
{
  check_dll_module (lmodule);
  check_string (lname);

  char *name = (char *)alloca (xstring_length (lname) * 2 + 1);
  w2s (name, lname);
  FARPROC proc = GetProcAddress (xdll_module_handle (lmodule), name);
  if (!proc)
    FEsimple_win32_error (GetLastError (), lname);

  int return_type = check_c_type (lrettype);
  int nargs = 0;
  for (lisp a = largs; consp (a); a = xcdr (a), nargs++)
    if (check_c_type (xcar (a)) == CTYPE_VOID)
      FEprogram_error (Einvalid_c_argument_type, Kvoid);

  u_char vaarg_p = find_keyword_bool (Kvaarg, keys);
  if (vaarg_p && check_calling_convention (keys) == CALLING_CONVENTION_STDCALL)
    FEprogram_error (Ecannot_call_vaarg_function_by_stdcall);

  lisp fn = make_dll_function ();
  xdll_function_module (fn) = lmodule;
  xdll_function_name (fn) = lname;
  xdll_function_proc (fn) = proc;
  xdll_function_return_type (fn) = return_type;
  xdll_function_vaarg_p (fn) = vaarg_p;

  xdll_function_nargs (fn) = nargs;
  if (nargs)
    {
      u_char *at = (u_char *)xmalloc (nargs);
      xdll_function_arg_types (fn) = at;
      xdll_function_arg_size (fn) = calc_argument_size (at, largs);
    }
  return fn;
}

lisp
Fsi_last_win32_error ()
{
  return xsymbol_value (Vlast_win32_error);
}

lisp
Fsi_set_last_win32_error (lisp lerror)
{
  DWORD error = fixnum_value (lerror);
  SetLastError (error);
  xsymbol_value (Vlast_win32_error) = lerror;
  return lerror;
}
