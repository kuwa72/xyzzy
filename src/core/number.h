// -*-C++-*-
#ifndef _number_h_
# define _number_h_

/* integer */

class llong_int: public lisp_object
{
public:
  long value;
};

# define long_int_p(X) typep ((X), Tlong_int)

inline void
check_long_int (lisp x)
{
  check_type (x, Tlong_int, Qinteger);
}

inline long &
xlong_int_value (lisp x)
{
  assert (long_int_p (x));
  return ((llong_int *)x)->value;
}

inline llong_int *
make_long_int (long x)
{
  llong_int *p = ldata <llong_int, Tlong_int>::lalloc ();
  p->value = x;
  return p;
}

# define LSHORT_INT_MAX (long ((1L << (BITS_PER_LONG - LSHORT_INT_SHIFT - 1)) - 1))
# define LSHORT_INT_MIN (-long (1L << (BITS_PER_LONG - LSHORT_INT_SHIFT - 1)))

inline int
short_int_p (lisp x)
{
  return (u_long (x) & SHORT_INT_TEST_BITS) == Lshort_int;
}

inline lisp
make_short_int (long x)
{
  return lisp ((u_long (x) << LSHORT_INT_SHIFT) | Lshort_int);
}

inline long
xshort_int_value (lisp x)
{
  assert (short_int_p (x));
  return long (x) >> LSHORT_INT_SHIFT;
}

# include "bignum.h"

class lbignum: public lisp_object
{
public:
  bignum_rep *rep;
  ~lbignum () {br_delete (rep);}
};

# define bignump(X) typep ((X), Tbignum)

inline void
check_bignum (lisp x)
{
  check_type (x, Tbignum, Qbignum);
}

inline bignum_rep *&
xbignum_rep (lisp x)
{
  assert (bignump (x));
  return ((lbignum *)x)->rep;
}

inline lbignum *
make_bignum (bignum_rep *rep)
{
  lbignum *p = ldata <lbignum, Tbignum>::lalloc ();
  p->rep = rep;
  return p;
}

inline lbignum *
make_bignum ()
{
  return make_bignum (&bignum_rep_zero);
}

class lfraction: public lisp_object
{
public:
  lisp num;
  lisp den;
};

# define fractionp(X) typep ((X), Tfraction)

inline lisp &
xfract_num (lisp x)
{
  assert (fractionp (x));
  return ((lfraction *)x)->num;
}

inline lisp &
xfract_den (lisp x)
{
  assert (fractionp (x));
  return ((lfraction *)x)->den;
}

inline lfraction *
make_fraction (lisp n, lisp d)
{
  lfraction *p = ldata <lfraction, Tfraction>::lalloc ();
  p->num = n;
  p->den = d;
  return p;
}

inline lfraction *
make_fraction ()
{
  return make_fraction (make_short_int (0), make_short_int (1));
}

/*GENERIC_FUNCTION:NUMBER*/
inline lisp_object_type
number_typeof (lisp x)
{
  return (immediatep (x)
          ? (short_int_p (x) ? Tshort_intP : TimmediateP)
          : lisp_object_type (object_typeof (x)));
}

/*GENERIC_FUNCTION:INTEGER*/
inline int
integerp (lisp x)
{
  if (immediatep (x))
    return short_int_p (x);
  return object_type_bit_p (object_typeof (x), TNinteger);
}

inline void
check_integer (lisp x)
{
  if (!integerp (x))
    FEtype_error (x, Qinteger);
}

inline int
fixnump (lisp x)
{
  return long_int_p (x) || short_int_p (x);
}

long coerce_to_long_error (lisp);
u_long unsigned_long_value (lisp);

/*GENERIC_FUNCTION:INTEGER*/
inline lisp
make_fixnum (long x)
{
  if (x >= LSHORT_INT_MIN && x <= LSHORT_INT_MAX)
    return make_short_int (x);
  return make_long_int (x);
}

/* floating point */

class lsingle_float: public lisp_object
{
public:
  float value;
};

class ldouble_float: public lisp_object
{
public:
  double value;
};

# define double_float_p(X) typep ((X), Tdouble_float)
# define single_float_p(X) typep ((X), Tsingle_float)

inline void
check_single_float (lisp x)
{
  check_type (x, Tsingle_float, Qfloat);
}

inline void
check_double_float (lisp x)
{
  check_type (x, Tdouble_float, Qfloat);
}

inline float &
xsingle_float_value (lisp x)
{
  assert (single_float_p (x));
  return ((lsingle_float *)x)->value;
}

inline double &
xdouble_float_value (lisp x)
{
  assert (double_float_p (x));
  return ((ldouble_float *)x)->value;
}

lsingle_float *make_single_float (float);
ldouble_float *make_double_float (double);

class lcomplex: public lisp_object
{
public:
  lisp real;
  lisp imag;
};

# define complexp(X) typep ((X), Tcomplex)

inline void
check_complex (lisp x)
{
  check_type (x, Tcomplex, Qcomplex);
}

inline lisp &
xcomplex_real (lisp x)
{
  assert (complexp (x));
  return ((lcomplex *)x)->real;
}

inline lisp &
xcomplex_imag (lisp x)
{
  assert (complexp (x));
  return ((lcomplex *)x)->imag;
}

inline lcomplex *
make_complex_1 (lisp r, lisp i)
{
  lcomplex *p = ldata <lcomplex, Tcomplex>::lalloc ();
  p->real = r;
  p->imag = i;
  return p;
}

/*GENERIC_FUNCTION:RATIONAL*/
inline int
rationalp (lisp x)
{
  if (immediatep (x))
    return short_int_p (x);
  else
    return object_type_bit_p (object_typeof (x), TNrational);
}

/*GENERIC_FUNCTION:FLOAT*/
inline int
floatp (lisp x)
{
  return object_type_bit_p (x, TNfloat);
}

/*GENERIC_FUNCTION:REAL*/
inline int
realp (lisp x)
{
  if (immediatep (x))
    return short_int_p (x);
  else
    return object_type_bit_p (object_typeof (x), TNreal);
}

/*GENERIC_FUNCTION:NUMBER*/
inline int
numberp (lisp x)
{
  if (immediatep (x))
    return short_int_p (x);
  else
    return object_type_bit_p (object_typeof (x), TNnumber);
}

lisp make_integer (char x);
lisp make_integer (u_char x);
lisp make_integer (short x);
lisp make_integer (u_short x);
lisp make_integer (int x);
lisp make_integer (u_int x);
lisp make_integer (long x);
lisp make_integer (u_long x);
lisp make_integer (int64_t);
lisp make_integer (uint64_t);
#if !defined(_WIN32) && defined(__LP64__)
/* On LP64 platforms (macOS/Linux 64-bit), long == int64_t but
   long long is a distinct type.  Cast to long (== int64_t) and call
   make_integer(long) directly to avoid Clang -O3 ARM64 mis-optimization
   that generates an infinite self-call when int64_t and long long
   are the same underlying type. */
inline lisp make_integer (long long x) { return make_integer (static_cast<long> (x)); }
inline lisp make_integer (unsigned long long x) { return make_integer (static_cast<u_long> (x)); }
#endif
lisp make_integer (bignum_rep *);

int safe_fixnum_value (lisp, long *);
long fixnum_value (lisp);
double coerce_to_double_float (lisp);
float coerce_to_single_float (lisp);
bignum_rep *coerce_to_bignum_rep (lisp, bignum_rep_long *);
long coerce_to_long (lisp);
int64_t coerce_to_int64 (lisp);

/* a * b が int64_t に収まるか。収まるなら *r に積を入れて 0 を返す。

   **`long` の幅が処理系で変わるので要る。** src/num-arith.d の整数どうしの
   掛け算は `int64_t (x) * int64_t (y)` を計算して make_integer に渡す形で、
   これは「オペランドが 32bit に収まるなら積は int64 に収まる」ことを当てに
   していた。`long` が 32bit の Windows (LLP64) ではそのとおりだが、64bit の
   Linux (LP64) では 2^32 が bignum ではなく long_int になるので、
   **(* (expt 2 32) (expt 2 32)) が int64 を溢れて 0 になっていた**
   (issue #49)。答えが黙って変わるので、上限の検査より悪い。

   掛けてから確かめる形 (z / b != a) は、符号付きの溢れがそもそも未定義動作
   なので使えない。割り算で先に確かめる。 */
inline int
int64_multiply_overflows (int64_t a, int64_t b, int64_t *r)
{
  if (a == 0 || b == 0)
    {
      *r = 0;
      return 0;
    }
  if (a > 0
      ? (b > 0 ? a > INT64_MAX / b : b < INT64_MIN / a)
      : (b > 0 ? a < INT64_MIN / b : b < INT64_MAX / a))
    return 1;
  *r = a * b;
  return 0;
}

lisp number_add (lisp, lisp);
lisp number_subtract (lisp, lisp);
lisp number_multiply (lisp, lisp);
lisp number_divide (lisp, lisp);
int number_compare (lisp, lisp);
lisp number_negate (lisp);
lisp integer_divide (lisp, lisp);
lisp make_ratio (lisp, lisp);
lisp flonum_to_rational (double);

lisp make_complex (lisp, lisp);

inline float
fract_to_single_float (const lfraction *x)
{
  return coerce_to_single_float (x->num) / coerce_to_single_float (x->den);
}

inline double
fract_to_double_float (const lfraction *x)
{
  return coerce_to_double_float (x->num) / coerce_to_double_float (x->den);
}

#endif
