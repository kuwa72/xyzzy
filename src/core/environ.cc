#include "stdafx.h"
#include "ed.h"
#include "environ.h"
#include "conf.h"
#include "fnkey.h"
#ifdef _WIN32
#include "monitor.h"
#endif

const Char Registry::base[] = {'S','o','f','t','w','a','r','e','\\',
                               'F','r','e','e',' ',
                               'S','o','f','t','w','a','r','e','\\',
                               'X','y','z','z','y','\\',0};
const Char Registry::Settings[] = {'S','e','t','t','i','n','g','s',0};

static size_t
wsz_len (const Char *s)
{
  const Char *p = s;
  while (*p) p++;
  return p - s;
}

#define ALLOC_SUBKEY(VAR, SUBKEY) \
  size_t VAR##_blen = sizeof base / sizeof (Char) - 1; \
  size_t VAR##_slen = wsz_len (SUBKEY); \
  Char *(VAR) = (Char *)alloca ((VAR##_blen + VAR##_slen + 1) * sizeof (Char)); \
  memcpy ((VAR), base, VAR##_blen * sizeof (Char)); \
  memcpy ((VAR) + VAR##_blen, (SUBKEY), (VAR##_slen + 1) * sizeof (Char))

void
ReadRegistry::open_local (const Char *subkey)
{
  ALLOC_SUBKEY (b, subkey);
  if (RegOpenKeyExW (HKEY_CURRENT_USER, (LPCWSTR)b, 0, KEY_READ, &hkey) != ERROR_SUCCESS)
    hkey = 0;
}

ReadRegistry::ReadRegistry (HKEY h, const Char *subkey)
{
  if (!h)
    open_local (subkey);
  else if (RegOpenKeyExW (h, (LPCWSTR)subkey, 0, KEY_READ, &hkey) != ERROR_SUCCESS)
    hkey = 0;
}

WriteRegistry::WriteRegistry (const Char *subkey)
{
  ALLOC_SUBKEY (b, subkey);
  DWORD x;
  DWORD e = RegCreateKeyExW (HKEY_CURRENT_USER, (LPCWSTR)b, 0, 0, REG_OPTION_NON_VOLATILE,
                             KEY_WRITE, 0, &hkey, &x);
  if (e != ERROR_SUCCESS)
    {
      hkey = 0;
      SetLastError (e);
    }
}

int
ReadRegistry::get (const Char *key, void *buf, DWORD size, DWORD req) const
{
  assert (!fail ());
  DWORD type;
  return (RegQueryValueExW (hkey, (LPCWSTR)key, 0, &type,
                            (BYTE *)buf, &size) == ERROR_SUCCESS
          && type == req) ? size : -1;
}

int
ReadRegistry::query (const Char *key, DWORD *type) const
{
  assert (!fail ());
  DWORD size = 0;
  if (RegQueryValueExW (hkey, (LPCWSTR)key, 0, type, 0, &size) == ERROR_SUCCESS)
    return size;
  return -1;
}

int
WriteRegistry::set (const Char *key, DWORD type, const void *buf, int size) const
{
  assert (!fail ());
  DWORD e = RegSetValueExW (hkey, (LPCWSTR)key, 0, type, (BYTE *)buf, size);
  if (e == ERROR_SUCCESS)
    return 1;
  SetLastError (e);
  return 0;
}

int
WriteRegistry::remove (const Char *key) const
{
  assert (!fail ());
  DWORD e = RegDeleteValueW (hkey, (LPCWSTR)key);
  if (e == ERROR_SUCCESS || e == ERROR_FILE_NOT_FOUND)
    return 1;
  SetLastError (e);
  return 0;
}

static Char *
lisp_to_wsz (lisp s)
{
  /* Phase 3: ucs4 → UTF-16 (worst case 2x for non-BMP). */
  Char *b = (Char *)alloca (i2wl (s) * sizeof (Char));
  i2w (s, (ucs2_t *)b);
  return b;
}

lisp
Fwrite_registry (lisp lsection, lisp lkey, lisp val)
{
  lsection = Fstring (lsection);
  Char *section = lisp_to_wsz (lsection);

  Char *key;
  if (lkey == Qnil)
    key = 0;
  else
    {
      lkey = Fstring (lkey);
      key = lisp_to_wsz (lkey);
    }

  if (val != Qnil && !stringp (val) && !fixnump (val))
    FEtype_error (val, xsymbol_value (Qor_string_integer));

  WriteRegistry r (section);
  if (r.fail ())
    FEsimple_win32_error (GetLastError (), lsection);

  if (val == Qnil)
    {
      if (!r.remove (key))
        FEsimple_win32_error (GetLastError (), lkey);
      return Qt;
    }

  if (stringp (val))
    {
      Char *b = lisp_to_wsz (val);
      int n = xstring_length (val);
      if (!r.set (key, b, (n + 1) * sizeof (Char)))
        FEsimple_win32_error (GetLastError (), lkey);
      return Qt;
    }

  if (!r.set (key, fixnum_value (val)))
    FEsimple_win32_error (GetLastError (), lkey);
  return Qt;
}

lisp
Fwrite_registry_literally (lisp lsection, lisp lkey, lisp val)
{
  lsection = Fstring (lsection);
  Char *section = lisp_to_wsz (lsection);

  Char *key;
  if (lkey == Qnil)
    key = 0;
  else
    {
      lkey = Fstring (lkey);
      key = lisp_to_wsz (lkey);
    }

  if (val != Qnil)
    check_string (val);

  WriteRegistry r (section);
  if (r.fail ())
    FEsimple_win32_error (GetLastError (), lsection);

  if (val == Qnil)
    {
      if (!r.remove (key))
        FEsimple_win32_error (GetLastError (), lkey);
    }
  else
    {
      if (!r.set (key, (const void *)xstring_contents (val),
                  sizeof (Char) * xstring_length (val)))
        FEsimple_win32_error (GetLastError (), lkey);
    }
  return Qt;
}

static HKEY
check_root (lisp lroot)
{
  if (!lroot || lroot == Qnil)
    return 0;
  if (lroot == Kclasses_root)
    return HKEY_CLASSES_ROOT;
  if (lroot == Kcurrent_user)
    return HKEY_CURRENT_USER;
  if (lroot == Klocal_machine)
    return HKEY_LOCAL_MACHINE;
  if (lroot == Kusers)
    return HKEY_USERS;
  return 0;
}

lisp
Fread_registry (lisp lsection, lisp lkey, lisp lroot)
{
  lsection = Fstring (lsection);
  Char *section = lisp_to_wsz (lsection);

  Char *key;
  if (lkey == Qnil)
    key = 0;
  else
    {
      lkey = Fstring (lkey);
      key = lisp_to_wsz (lkey);
    }

  ReadRegistry r (check_root (lroot), section);
  if (r.fail ())
    return Qnil;

  DWORD type;
  int l = r.query (key, &type);
  if (l < 0)
    return Qnil;

  switch (type)
    {
    case REG_DWORD:
      {
        int x;
        if (!r.get (key, &x))
          FEsimple_win32_error (GetLastError (), lkey);
        return make_fixnum (x);
      }

    case REG_SZ:
      {
        int ncu = l / sizeof (Char);
        Char *b = (Char *)alloca ((ncu + 1) * sizeof (Char));
        if (r.get (key, b, (ncu + 1) * sizeof (Char), type) < 0)
          FEsimple_win32_error (GetLastError (), lkey);
        int n = ncu;
        while (n > 0 && b[n - 1] == 0) n--;
        return make_string (b, n);
      }

    case REG_EXPAND_SZ:
      {
        int ncu = l / sizeof (Char);
        Char *b = (Char *)alloca ((ncu + 1) * sizeof (Char));
        if (r.get (key, b, (ncu + 1) * sizeof (Char), type) < 0)
          FEsimple_win32_error (GetLastError (), lkey);
        DWORD n = ExpandEnvironmentStringsW ((LPCWSTR)b, 0, 0);
        if (!n)
          FEsimple_win32_error (GetLastError (), lkey);
        Char *b2 = (Char *)alloca (n * sizeof (Char));
        if (!ExpandEnvironmentStringsW ((LPCWSTR)b, (LPWSTR)b2, n))
          FEsimple_win32_error (GetLastError (), lkey);
        int rn = n;
        while (rn > 0 && b2[rn - 1] == 0) rn--;
        return make_string (b2, rn);
      }

    case REG_MULTI_SZ:
      {
        int ncu = l / sizeof (Char);
        Char *b = (Char *)alloca ((ncu + 1) * sizeof (Char));
        if (r.get (key, b, (ncu + 1) * sizeof (Char), type) < 0)
          FEsimple_win32_error (GetLastError (), lkey);
        lisp p = Qnil;
        Char *s = b;
        while (*s)
          {
            size_t sl = wsz_len (s);
            p = xcons (make_string (s, sl), p);
            s += sl + 1;
          }
        return Fnreverse (p);
      }

    case REG_BINARY:
      if (l && !(l % sizeof (Char)))
        {
          lisp p = make_string (l / sizeof (Char));
          if (!r.get (key, (void *)xstring_contents (p), l))
            FEsimple_win32_error (GetLastError (), lkey);
          return p;
        }
      return Qnil;

    default:
      return Qnil;
    }
}

lisp
Flist_registry_key (lisp lsection, lisp lroot)
{
  lsection = Fstring (lsection);
  Char *section = lisp_to_wsz (lsection);

  EnumRegistry r (check_root (lroot), section);
  if (r.fail ())
    return Qnil;

  lisp p = Qnil;
  for (int i = 0;; i++)
    {
      Char name[1024];
      DWORD namel = sizeof name / sizeof (Char);
      FILETIME ft;
      int e = RegEnumKeyExW (r, i, (LPWSTR)name, &namel, 0, 0, 0, &ft);
      if (e == ERROR_SUCCESS)
        p = xcons (make_string (name, namel), p);
      else
        break;
    }
  return p;
}

lisp
Fsi_delete_registry_tree ()
{
  reg_delete_tree ();
  return Qnil;
}

lisp
Fmachine_instance ()
{
  return xsymbol_value (Vmachine_name);
}

lisp
Fmachine_type ()
{
  return xsymbol_value (Vmachine_type);
}

lisp
Fmachine_version ()
{
  return xsymbol_value (Vmachine_version);
}

lisp
Fget_decoded_time ()
{
  SYSTEMTIME s;
  GetLocalTime (&s);
  multiple_value::value (1) = make_fixnum (s.wMinute);
  multiple_value::value (2) = make_fixnum (s.wHour);
  multiple_value::value (3) = make_fixnum (s.wDay);
  multiple_value::value (4) = make_fixnum (s.wMonth);
  multiple_value::value (5) = make_fixnum (s.wYear);
  multiple_value::value (6) = make_fixnum ((s.wDayOfWeek + 6) % 7);

  TIME_ZONE_INFORMATION t;
  switch (GetTimeZoneInformation (&t))
    {
    case TIME_ZONE_ID_UNKNOWN:
    case TIME_ZONE_ID_STANDARD:
      multiple_value::value (7) = Qnil;
      multiple_value::value (8) = make_fixnum (t.Bias / 60);
      break;

    case TIME_ZONE_ID_DAYLIGHT:
      multiple_value::value (7) = Qt;
      multiple_value::value (8) = make_fixnum (t.Bias / 60);
      break;

    default:
      multiple_value::value (7) = Qnil;
      multiple_value::value (8) = make_fixnum (0);
      break;
    }

  multiple_value::count () = 9;
  return make_fixnum (s.wSecond);
}

#define BASE_YEAR 1900

static inline int
count_leap_years (int y)
{
  return y / 4 - y / 100 + y / 400;
}

static inline int
leap_years_since_base_year (int year)
{
  return count_leap_years (year) - count_leap_years (BASE_YEAR);
}

static inline int
leap_year_p (int y)
{
  return !(y % 4) && (y % 100 || !(y % 400));
}

lisp
decoded_time_to_universal_time (int year, int mon, int day,
                                int hour, int min, int sec, int timezone)
{
  static const int days_of_month[] =
    {0, -1, 30, 58, 89, 119, 150, 180, 211, 242, 272, 303, 333,};
  int leap_years = leap_years_since_base_year (year);
  day += days_of_month[mon];
  if (mon <= 2 && leap_year_p (year))
    day--;
  year -= BASE_YEAR;
  bignum_rep_long ry (year);
  bignum_rep_long ly (leap_years);
  safe_bignum_rep r (multiply (0, &ry, 365 * 86400L));
  safe_bignum_rep r2 (multiply (0, &ly, 86400L));
  r = add (r, r, r2, 0);
  r = add (r, r, (day * 86400L + hour * 3600 + min * 60 + sec + timezone), 0);
  return make_integer (r.release ());
}

#define FILETIME_UNIT_PER_SECOND 10000000
#define FILETIME_UTC_BASE   9435484800LL   // FileTime (1900/1/1 0:0:0)

lisp
file_time_to_universal_time (const FILETIME &ft)
{
  int64_t i = *(int64_t *)&ft;
  i = i / FILETIME_UNIT_PER_SECOND - FILETIME_UTC_BASE;
  return make_integer (i);
}

lisp
Fget_universal_time ()
{
  SYSTEMTIME st;
  GetSystemTime (&st);
  return decoded_time_to_universal_time (st.wYear, st.wMonth, st.wDay,
                                         st.wHour, st.wMinute, st.wSecond, 0);
}

static int
get_timezone (lisp ltimezone, int *daylight)
{
  *daylight = 0;
  if (!ltimezone || ltimezone == Qnil)
    {
      TIME_ZONE_INFORMATION t;
      switch (GetTimeZoneInformation (&t))
        {
        case TIME_ZONE_ID_UNKNOWN:
        case TIME_ZONE_ID_STANDARD:
          return t.Bias * 60;

        case TIME_ZONE_ID_DAYLIGHT:
          *daylight = -3600;
          return t.Bias * 60;

        default:
          return 0;
        }
    }
  else
    {
      long timezone;
      if (safe_fixnum_value (ltimezone, &timezone))
        {
          if (timezone < -24 || timezone > 24)
            FErange_error (ltimezone);
          timezone *= 3600;
        }
      else
        {
          if (!rationalp (ltimezone))
            FEtype_error (ltimezone, Qrational);
          if (bignump (ltimezone))
            FErange_error (ltimezone);
          lisp t = number_multiply (ltimezone, make_fixnum (3600));
          if (!integerp (t))
            FEsimple_error (Etimezone_is_integral_multiple_of_1_3600);
          if (bignump (t))
            FErange_error (ltimezone);
          timezone = fixnum_value (t);
          if (timezone < -24 * 3600 || timezone > 24 * 3600)
            FErange_error (ltimezone);
        }
      return timezone;
    }
}

#define SECONDS_PER_DAY 86400

void
decode_universal_time (lisp lutc, decoded_time *dt)
{
  bignum_rep_long utcl;
  safe_bignum_rep utc (add (0, coerce_to_bignum_rep (lutc, &utcl),
                            long (dt->timezone + dt->daylight), 1));
  bignum_rep_long spd (u_long (SECONDS_PER_DAY));
  bignum_rep *q, *r;
  truncate (q, r, utc, &spd);
  safe_bignum_rep qq (q), rr (r);
  u_long t = r->to_ulong ();
  dt->hour = t / 3600;
  dt->min = t / 60 % 60;
  dt->sec = t % 60;
  dt->dow = remainder (q, 7);

  bignum_rep_long dpy (u_long (365));
  bignum_rep *yq, *yr;
  truncate (yq, yr, q, &dpy);
  safe_bignum_rep yqq (yq), yrr (yr);

  dt->year = BASE_YEAR + yq->to_ulong ();
  int ndays = yr->to_ulong ();
  ndays -= leap_years_since_base_year (dt->year - 1) - 1;
  while (ndays <= 0)
    {
      dt->year--;
      ndays += leap_year_p (dt->year) ? 366 : 365;
    }
  static const int days_in_month[] =
    {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  int mon;
  for (mon = 1; mon <= 12; mon++)
    {
      int dom = days_in_month[mon];
      if (mon == 2 && leap_year_p (dt->year))
        dom++;
      if (ndays <= dom)
        break;
      ndays -= dom;
    }

  dt->day = ndays;
  dt->mon = mon;
}

lisp
Fdecode_universal_time (lisp lutc, lisp ltimezone)
{
  decoded_time dt;
  dt.timezone = get_timezone (ltimezone, &dt.daylight);
  decode_universal_time (lutc, &dt);

  multiple_value::value (1) = make_fixnum (dt.min);
  multiple_value::value (2) = make_fixnum (dt.hour);
  multiple_value::value (3) = make_fixnum (dt.day);
  multiple_value::value (4) = make_fixnum (dt.mon);
  multiple_value::value (5) = make_fixnum (dt.year);
  multiple_value::value (6) = make_fixnum (dt.dow);
  multiple_value::value (7) = boole (dt.daylight);
  long t = dt.timezone / 3600;
  multiple_value::value (8) = (t * 3600 == dt.timezone
                               ? make_fixnum (t)
                               : make_ratio (make_fixnum (dt.timezone),
                                             make_fixnum (3600)));
  multiple_value::count () = 9;
  return make_fixnum (dt.sec);
}

lisp
Fencode_universal_time (lisp lsec, lisp lmin, lisp lhour,
                        lisp lday, lisp lmon, lisp lyear,
                        lisp ltimezone)
{
  int sec = fixnum_value (lsec);
  int min = fixnum_value (lmin);
  int hour = fixnum_value (lhour);
  int day = fixnum_value (lday);
  int mon = fixnum_value (lmon);
  if (mon < 1 || mon > 12)
    FErange_error (lmon);
  int year = fixnum_value (lyear);
  if (year >= 0 && year < 100)
    {
      SYSTEMTIME s;
      GetLocalTime (&s);
      year += s.wYear / 100 * 100;
      if (year < s.wYear - 50)
        year += 100;
      else if (year >= s.wYear + 50)
        year -= 100;
    }

  int daylight;
  int timezone = get_timezone (ltimezone, &daylight);
  return decoded_time_to_universal_time (year, mon, day,
                                         hour, min, sec, timezone + daylight);
}

lisp
Fget_internal_real_time ()
{
  return make_fixnum (GetTickCount () & LONG_MAX);
}

lisp
Fsi_performance_counter ()
{
  int64_t x;
  if (sysdep.perf_counter_present_p
      && QueryPerformanceCounter ((LARGE_INTEGER *)&x))
    return make_integer (x);
  return Fget_internal_real_time ();
}

lisp
Fsoftware_type ()
{
  return xsymbol_value (Qsoftware_type);
}

lisp
Fsoftware_version ()
{
  return xsymbol_value (Qsoftware_version);
}

lisp
Flisp_implementation_type ()
{
  return xsymbol_value (Qsoftware_type);
}

lisp
Flisp_implementation_version ()
{
  return xsymbol_value (Qsoftware_version);
}

lisp
Fsoftware_version_display_string ()
{
  return xsymbol_value (Qsoftware_version_display_string);
}

lisp
Fuser_name ()
{
  return xsymbol_value (Vuser_name);
}

lisp
Fmachine_name ()
{
  return xsymbol_value (Vmachine_name);
}

lisp
Fos_major_version ()
{
  return xsymbol_value (Vos_major_version);
}

lisp
Fos_minor_version ()
{
  return xsymbol_value (Vos_minor_version);
}

lisp
Fos_build_number ()
{
  return xsymbol_value (Vos_build_number);
}

lisp
Fos_platform ()
{
  return xsymbol_value (Vos_platform);
}

lisp
Fos_csd_version ()
{
  return xsymbol_value (Vos_csd_version);
}

void
init_environ ()
{
#ifdef _WIN32
  wchar_t wb[256];
  DWORD n = numberof (wb);
  if (GetUserNameW (wb, &n))
    /* GetUserNameW fills n as #chars including the null. make_string takes a
       Char count excluding the null, hence n - 1. */
    xsymbol_value (Vuser_name) = make_string ((const Char *)wb, n - 1);
  else
    xsymbol_value (Vuser_name) = make_string ("unknown");

  n = numberof (wb);
  if (GetComputerNameW (wb, &n))
    xsymbol_value (Vmachine_name) = make_string ((const Char *)wb, n);
  else
    xsymbol_value (Vmachine_name) = make_string ("unknown");

  const wchar_t *processor_id = _wgetenv (L"PROCESSOR_IDENTIFIER");
  if (processor_id)
    xsymbol_value (Vmachine_version) =
      make_string ((const Char *)processor_id, wcslen (processor_id));
  else
    xsymbol_value (Vmachine_version) = Qnil;
#else
  /* Non-Win32: wchar_t is 4 bytes here, so the (const Char *) reinterpret cast
     the Win32 path uses on wchar_t buffers does not apply. These come back as
     UTF-8 bytes, which is what a Unix environment holds. */
  {
    const char *user = getenv ("USER");
    if (!user) user = getenv ("LOGNAME");
    xsymbol_value (Vuser_name) = make_string_from_utf8 (user ? user : "unknown");

    char host[256];
    if (gethostname (host, sizeof host) == 0)
      {
        host[sizeof host - 1] = 0;
        xsymbol_value (Vmachine_name) = make_string_from_utf8 (host);
      }
    else
      xsymbol_value (Vmachine_name) = make_string ("unknown");

    const char *processor_id = getenv ("PROCESSOR_IDENTIFIER");
    if (!processor_id) processor_id = getenv ("HOSTTYPE");
    xsymbol_value (Vmachine_version) =
      processor_id ? make_string_from_utf8 (processor_id) : Qnil;
  }
#endif

  xsymbol_value (Vos_major_version) = make_fixnum (sysdep.os_ver.dwMajorVersion);
  xsymbol_value (Vos_minor_version) = make_fixnum (sysdep.os_ver.dwMinorVersion);
  xsymbol_value (Vos_build_number) = make_fixnum (sysdep.os_ver.dwBuildNumber);
#ifdef _WIN32
  /* szCSDVersion is WCHAR[] (UTF-16); read it as a Char run. wcslen can't be
     used since wchar_t is 4 bytes on some platforms — measure it ourselves. */
  {
    const Char *csd = (const Char *)sysdep.os_ver.szCSDVersion;
    size_t csd_len = 0;
    while (csd[csd_len]) csd_len++;
    xsymbol_value (Vos_csd_version) = make_string (csd, csd_len);
  }
#else
  xsymbol_value (Vos_csd_version) = make_string ("");
#endif
  xsymbol_value (Vprocess_id) = make_fixnum (sysdep.process_id);

#ifdef _WIN32
  switch (sysdep.wintype)
    {
    case Sysdep::WINTYPE_WIN32S:
      xsymbol_value (Vos_platform) = Vwin32s;
      xsymbol_value (Vfeatures) = xcons (Kwin32s, xsymbol_value (Vfeatures));
      break;

    case Sysdep::WINTYPE_WINDOWS_95:
      xsymbol_value (Vos_platform) = Vwindows_95;
      xsymbol_value (Vfeatures) = xcons (Kwindows_95, xsymbol_value (Vfeatures));
      break;

    case Sysdep::WINTYPE_WINDOWS_98:
      xsymbol_value (Vos_platform) = Vwindows_98;
      xsymbol_value (Vfeatures) = xcons (Kwindows_98, xsymbol_value (Vfeatures));
      if (sysdep.version () >= Sysdep::WINME_VERSION)
        {
          xsymbol_value (Vos_platform) = Vwindows_me;
          xsymbol_value (Vfeatures) = xcons (Kwindows_me, xsymbol_value (Vfeatures));
        }
      break;

    case Sysdep::WINTYPE_WINDOWS_NT:
    case Sysdep::WINTYPE_WINDOWS_NT5:
    case Sysdep::WINTYPE_WINDOWS_NT6:
      xsymbol_value (Vos_platform) = Vwindows_nt;
      xsymbol_value (Vfeatures) = xcons (Kwindows_nt, xsymbol_value (Vfeatures));
      if (sysdep.Win5p ())
        {
          xsymbol_value (Vos_platform) = Vwindows_2000;
          xsymbol_value (Vfeatures) = xcons (Kwindows_2000, xsymbol_value (Vfeatures));
          if (sysdep.version () >= Sysdep::WINXP_VERSION)
            {
              xsymbol_value (Vos_platform) = Vwindows_xp;
              xsymbol_value (Vfeatures) = xcons (Kwindows_xp, xsymbol_value (Vfeatures));
            }
        }
      if (sysdep.Win6p ())
        {
          xsymbol_value (Vos_platform) = Vwindows_vista;
          xsymbol_value (Vfeatures) = xcons (Kwindows_vista, xsymbol_value (Vfeatures));
          if (sysdep.version () >= Sysdep::WIN7_VERSION)
            {
              xsymbol_value (Vos_platform) = Vwindows_7;
              xsymbol_value (Vfeatures) = xcons (Kwindows_7, xsymbol_value (Vfeatures));
            }
          if (sysdep.version () >= Sysdep::WIN8_VERSION)
            {
              xsymbol_value (Vos_platform) = Vwindows_8;
              xsymbol_value (Vfeatures) = xcons (Kwindows_8, xsymbol_value (Vfeatures));
            }
        }
      break;

    default:
      xsymbol_value (Vos_platform) = Qnil;
      break;
    }

  switch (sysdep.machine_type)
    {
    case Sysdep::MACHINETYPE_X86:
      xsymbol_value (Vfeatures) = xcons (Kx86, xsymbol_value (Vfeatures));
      xsymbol_value (Vmachine_type) = make_string ("x86");
      break;
    case Sysdep::MACHINETYPE_X64:
      xsymbol_value (Vfeatures) = xcons (Kx64, xsymbol_value (Vfeatures));
      xsymbol_value (Vmachine_type) = make_string ("x64");
      break;
    case Sysdep::MACHINETYPE_IA64:
      xsymbol_value (Vfeatures) = xcons (Kia64, xsymbol_value (Vfeatures));
      xsymbol_value (Vmachine_type) = make_string ("IA64");
    case Sysdep::MACHINETYPE_UNKNOWN:
      xsymbol_value (Vmachine_type) = Qnil;
      break;
    }

  switch (sysdep.process_type)
    {
    case Sysdep::PROCESSTYPE_WOW64:
      xsymbol_value (Vfeatures) = xcons (Kwow64, xsymbol_value (Vfeatures));
      break;
    }
#else
  xsymbol_value (Vos_platform) = Qnil;
  xsymbol_value (Vfeatures) = xcons (Kunix, xsymbol_value (Vfeatures));
#ifdef __linux__
  xsymbol_value (Vfeatures) = xcons (Klinux, xsymbol_value (Vfeatures));
#endif
#if defined(__aarch64__)
  xsymbol_value (Vfeatures) = xcons (Kaarch64, xsymbol_value (Vfeatures));
  xsymbol_value (Vmachine_type) = make_string ("aarch64");
#elif defined(__x86_64__)
  xsymbol_value (Vfeatures) = xcons (Kamd64, xsymbol_value (Vfeatures));
  xsymbol_value (Vmachine_type) = make_string ("amd64");
#elif defined(__i386__)
  xsymbol_value (Vfeatures) = xcons (Kx86, xsymbol_value (Vfeatures));
  xsymbol_value (Vmachine_type) = make_string ("x86");
#else
  xsymbol_value (Vmachine_type) = Qnil;
#endif
#endif

  if (sizeof (pointer_t) == 4)
    xsymbol_value (Vfeatures) = xcons (K32bit, xsymbol_value (Vfeatures));
  else
    xsymbol_value (Vfeatures) = xcons (K64bit, xsymbol_value (Vfeatures));
}

lisp
Fget_windows_directory ()
{
  return xsymbol_value (Qwindows_dir);
}

lisp
Fget_system_directory ()
{
  return xsymbol_value (Qsystem_dir);
}

int environ::save_window_size = 1;
int environ::save_window_snap_size = 0;
int environ::save_window_position = 1;
int environ::restore_window_size;
int environ::restore_window_position;

int
environ::load_geometry (int cmdshow, POINT *point, SIZE *size)
{
  read_conf (cfgMisc, cfgSaveWindowSize, save_window_size);
  read_conf (cfgMisc, cfgSaveWindowSnapSize, save_window_snap_size);
  read_conf (cfgMisc, cfgSaveWindowPosition, save_window_position);
  read_conf (cfgMisc, cfgWindowFlags, Window::w_default_flags);
  restore_window_size = save_window_size;
  restore_window_position = save_window_position;
  read_conf (cfgMisc, cfgRestoreWindowSize, restore_window_size);
  read_conf (cfgMisc, cfgRestoreWindowPosition, restore_window_position);

  int x;
  if (read_conf (cfgMisc, cfgFnkeyLabels, x))
    FKWin::default_nbuttons () = x;
  read_conf (cfgMisc, cfgFoldMode, Buffer::b_default_fold_mode);
  if (Buffer::b_default_fold_mode != Buffer::FOLD_NONE
      && Buffer::b_default_fold_mode != Buffer::FOLD_WINDOW
      && Buffer::b_default_fold_mode < 4
      && Buffer::b_default_fold_mode > 30000)
    Buffer::b_default_fold_mode = Buffer::FOLD_NONE;
  read_conf (cfgMisc, cfgFoldLineNumMode, Buffer::b_default_linenum_mode);
  if (Buffer::b_default_linenum_mode != Buffer::LNMODE_DISP
      && Buffer::b_default_linenum_mode != Buffer::LNMODE_LF)
    Buffer::b_default_linenum_mode = Buffer::LNMODE_DISP;

  point->x = point->y = CW_USEDEFAULT;
  size->cx = size->cy = CW_USEDEFAULT;

  char name[64];
  make_geometry_key (name, sizeof name, 0);
  WINDOWPLACEMENT w;
  if (read_conf (cfgMisc, name, w)
      && w.rcNormalPosition.left < w.rcNormalPosition.right
      && w.rcNormalPosition.top < w.rcNormalPosition.bottom)
    {
      if (environ::restore_window_size)
        {
          cmdshow = w.showCmd;
          size->cx = w.rcNormalPosition.right - w.rcNormalPosition.left;
          size->cy = w.rcNormalPosition.bottom - w.rcNormalPosition.top;
        }
      if (environ::restore_window_position)
        {
          RECT r;
          int min_visible = (GetSystemMetrics(SM_CYSIZEFRAME)
                             + GetSystemMetrics(SM_CYBORDER)
                             + GetSystemMetrics(SM_CYCAPTION));
          r.left = w.rcNormalPosition.left + min_visible;
          r.top = w.rcNormalPosition.top + min_visible;
          r.right = w.rcNormalPosition.right - min_visible;
          r.bottom = w.rcNormalPosition.bottom - min_visible;
#ifdef _WIN32
          if (monitor.get_monitor_from_rect (&r))
            {
              point->x = w.rcNormalPosition.left;
              point->y = w.rcNormalPosition.top;
            }
          else
#endif
            {
              point->x = point->y = CW_USEDEFAULT;
            }
        }
    }

  return cmdshow;
}

void
environ::save_geometry ()
{
  save_window_size = xsymbol_value (Vsave_window_size) != Qnil;
  save_window_snap_size = xsymbol_value (Vsave_window_snap_size) != Qnil;
  save_window_position = xsymbol_value (Vsave_window_position) != Qnil;

  if (save_window_size || save_window_position)
    {
      WINDOWPLACEMENT w;
      w.length = sizeof w;
      if (GetWindowPlacement (app.toplev, &w))
        {
          if (save_window_snap_size)
            adjust_snap_window_size (app.toplev, w);
          char name[256];
          make_geometry_key (name, sizeof name, 0);
          if (!save_window_size || !save_window_position)
            {
              WINDOWPLACEMENT ow;
              if (read_conf (cfgMisc, name, ow)
                  && ow.rcNormalPosition.left < ow.rcNormalPosition.right
                  && ow.rcNormalPosition.top < ow.rcNormalPosition.bottom)
                {
                  int old_cx = ow.rcNormalPosition.right - ow.rcNormalPosition.left;
                  int old_cy = ow.rcNormalPosition.bottom - ow.rcNormalPosition.top;
                  int new_cx = w.rcNormalPosition.right - w.rcNormalPosition.left;
                  int new_cy = w.rcNormalPosition.bottom - w.rcNormalPosition.top;

                  if (!save_window_position)
                    {
                      w.showCmd = ow.showCmd;
                      w.rcNormalPosition.left = ow.rcNormalPosition.left;
                      w.rcNormalPosition.top = ow.rcNormalPosition.top;
                    }

                  if (!save_window_size)
                    {
                      w.rcNormalPosition.right = w.rcNormalPosition.left + old_cx;
                      w.rcNormalPosition.bottom = w.rcNormalPosition.top + old_cy;
                    }
                  else
                    {
                      w.rcNormalPosition.right = w.rcNormalPosition.left + new_cx;
                      w.rcNormalPosition.bottom = w.rcNormalPosition.top + new_cy;
                    }
                }
            }

          write_conf (cfgMisc, name, w);
        }
    }

  write_conf (cfgMisc, cfgSaveWindowSize, save_window_size);
  write_conf (cfgMisc, cfgSaveWindowSnapSize, save_window_snap_size);
  write_conf (cfgMisc, cfgSaveWindowPosition, save_window_position);
  write_conf (cfgMisc, cfgRestoreWindowSize,
              xsymbol_value (Vrestore_window_size) != Qnil);
  write_conf (cfgMisc, cfgRestoreWindowPosition,
              xsymbol_value (Vrestore_window_position) != Qnil);
  write_conf (cfgMisc, cfgWindowFlags, Window::w_default_flags, 1);
  write_conf (cfgMisc, cfgFnkeyLabels, FKWin::default_nbuttons ());
  write_conf (cfgMisc, cfgFoldMode, Buffer::b_default_fold_mode);
  write_conf (cfgMisc, cfgFoldLineNumMode, Buffer::b_default_linenum_mode);
  flush_conf ();
}

lisp
Fsi_environ ()
{
  lisp r = Qnil;
#ifdef _WIN32
  /* Phase 2-5: use _wenviron so non-ASCII env values round-trip as UTF-16
     without the w2s/s2w cp932 detour. _wenviron may be NULL until the CRT
     initializes it (MS CRT populates on first _wgetenv / first wmain). A
     harmless _wgetenv (L"") primes it. */
  _wgetenv (L"");
  for (wchar_t **e = _wenviron; e && *e; e++)
    {
      const wchar_t *eq = wcschr (*e, L'=');
      if (!eq)
        continue;
      lisp env = xcons (make_string ((const Char *)*e, eq - *e),
                        make_string ((const Char *)(eq + 1), wcslen (eq + 1)));
      r = xcons (env, r);
    }
#else
  /* Non-Win32: walk the POSIX environ as byte strings; make_string decodes. */
  for (char **e = environ; e && *e; e++)
    {
      const char *eq = strchr (*e, '=');
      if (!eq)
        continue;
      lisp env = xcons (make_string (*e, eq - *e),
                        make_string (eq + 1, strlen (eq + 1)));
      r = xcons (env, r);
    }
#endif

  return Fnreverse (r);
}

lisp
Fsi_getenv (lisp var)
{
  check_string (var);
#ifdef _WIN32
  /* Phase 3: ucs4 → UTF-16. */
  wchar_t *v = (wchar_t *)alloca (i2wl (var) * sizeof (wchar_t));
  i2w (var, (ucs2_t *)v);
  const wchar_t *e = _wgetenv (v);
  return e ? make_string ((const Char *)e, wcslen (e)) : Qnil;
#else
  /* The environment on a Unix system is UTF-8 bytes, not CP932. */
  char *v = (char *)alloca (i2u8l (xstring_contents (var), xstring_length (var)));
  i2u8 (xstring_contents (var), xstring_length (var), v);
  const char *e = getenv (v);
  return e ? make_string_from_utf8 (e) : Qnil;
#endif
}

lisp
Fsi_putenv (lisp var, lisp val)
{
  check_string (var);
#ifdef _WIN32
  /* Phase 3: ucs4 var/val → UTF-16 (worst case 2x). */
  size_t n = (i2wl (var) - 1) + 1 /*=*/ + 1 /*nul*/;
  if (val && val != Qnil)
    {
      check_string (val);
      n += i2wl (val) - 1;
    }

  wchar_t *b = (wchar_t *)alloca (n * sizeof (wchar_t));
  ucs2_t *v = i2w (var, (ucs2_t *)b);
  *v++ = L'=';
  if (val && val != Qnil)
    i2w (val, v);                 // value + NUL
  else
    *v = 0;

  int r = _wputenv (b);
  return (r < 0 || !val) ? Qnil : val;
#else
  /* Build "name=value" as UTF-8 bytes for putenv. */
  size_t l = i2u8l (xstring_contents (var), xstring_length (var)) + 1;
  if (val && val != Qnil)
    {
      check_string (val);
      l += i2u8l (xstring_contents (val), xstring_length (val));
    }

  char *v = (char *)alloca (l);
  char *b = v;
  v = i2u8 (xstring_contents (var), xstring_length (var), v);
  *v++ = '=';
  if (val && val != Qnil)
    i2u8 (xstring_contents (val), xstring_length (val), v);
  else
    *v = 0;

  int r = _putenv (b);
  return (r < 0 || !val) ? Qnil : val;
#endif
}

lisp
Fsi_getpid ()
{
  return xsymbol_value (Vprocess_id);
}

lisp
Fsi_system_root ()
{
  return xsymbol_value (Qmodule_dir);
}

lisp
Fuser_config_path ()
{
  return xsymbol_value (Quser_config_path);
}

lisp
Fxyzzy_ini_path ()
{
  /* **null で呼ばれる。** ini ファイルの場所を決めるのは Win32 の
     init_user_inifile_path だけで、端末 / CLI フロントエンドでは
     app.ini_file_path が 0 のままである (read_conf / write_conf が空実装で、
     設定を保存する先が無い)。ここで make_string (0) を渡していたので、
     `(xyzzy-ini-path)` を呼ぶと**プロセスが落ちていた** (Linux ネイティブ
     ビルドで Lisp テストスイートが signal 11 で死ぬ原因、issue #49)。
     Lisp から呼べる関数がプロセスを落としてはいけない。 */
  if (!app.ini_file_path)
    return Qnil;
  return make_string (app.ini_file_path);
}

lisp
Fsi_dump_image_path ()
{
  return xsymbol_value (Qdump_image_path);
}

lisp
Fsi_system_path ()
{
  return xsymbol_value (Qsystem_path);
}
