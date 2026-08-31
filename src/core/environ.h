#ifndef _environ_h_
# define _environ_h_

#ifdef environ
# undef environ
#endif

/* **ファンクションバーのラベルの数。** ini の `fnkeyLabels` に保存される
   設定値で、**GUI の話ではないので core に置く** (issue #185)。以前は
   `FKWin::fk_default_nbuttons` (src/core/fnkey.h) で、その 1 個のために
   GUI のヘッダが core に居た。

   **0 は「設定されていない」。** Win32 の `FKWin` のコンストラクタが
   `fk_divinfo` に無い値を見たら 12 に落とすので、0 の実際の意味は 12 で
   ある。端末にファンクションバーは無いので誰も読まない (以前は端末側の
   スタブが 10 を入れていて、**ini に 10 と書く以外の効果が無かった**)。 */
extern int g_fnkey_default_nbuttons;

class environ
{
public:
  static int save_window_size;
  static int save_window_snap_size;
  static int save_window_position;
  static int restore_window_size;
  static int restore_window_position;
  static int load_geometry (int, POINT *, SIZE *);
  static void save_geometry ();
  /* **位置以外の設定だけ。** 端末フロントエンドには WINDOWPLACEMENT の意味は
     無いが、行番号の表示や折り返しの既定は端末でも意味がある (issue #143)。 */
  static void load_settings ();
  static void save_settings ();
};

class Registry
{
protected:
  static const Char base[];
  HKEY hkey;
  Registry ();
  ~Registry ();
public:
  static const Char Settings[];
  int fail () const;
};

inline
Registry::Registry ()
     : hkey (0)
{
}

inline
Registry::~Registry ()
{
  if (hkey)
    RegCloseKey (hkey);
}

inline int
Registry::fail () const
{
  return !hkey;
}

class ReadRegistry: public Registry
{
protected:
  void open_local (const Char *);
public:
  int get (const Char *, void *, DWORD, DWORD) const;
  int get (const Char *, int *) const;
  int get (const Char *, long *) const;
  int get (const Char *, Char *, int) const;
  int get (const Char *, void *, int) const;
  int query (const Char *, DWORD *) const;
  ReadRegistry (const Char *);
  ReadRegistry (HKEY, const Char *);
};

inline
ReadRegistry::ReadRegistry (const Char *subkey)
{
  open_local (subkey);
}

inline int
ReadRegistry::get (const Char *key, int *x) const
{
  return get (key, x, sizeof *x, REG_DWORD) == sizeof *x;
}

inline int
ReadRegistry::get (const Char *key, long *x) const
{
  return get (key, x, sizeof *x, REG_DWORD) == sizeof *x;
}

inline int
ReadRegistry::get (const Char *key, Char *buf, int size) const
{
  return get (key, buf, size, REG_SZ);
}

inline int
ReadRegistry::get (const Char *key, void *buf, int size) const
{
  return get (key, buf, size, REG_BINARY);
}

class WriteRegistry: public Registry
{
public:
  int set (const Char *, DWORD, const void *, int) const;
  int set (const Char *, long) const;
  int set (const Char *, const Char *) const;
  int set (const Char *, const Char *, int) const;
  int set (const Char *, const void *, int) const;
  int remove (const Char *) const;
  WriteRegistry (const Char *);
};

inline int
WriteRegistry::set (const Char *key, long val) const
{
  return set (key, REG_DWORD, &val, sizeof val);
}

inline int
WriteRegistry::set (const Char *key, const Char *val) const
{
  int l = 0;
  while (val[l]) l++;
  return set (key, REG_SZ, val, (l + 1) * sizeof (Char));
}

inline int
WriteRegistry::set (const Char *key, const Char *val, int size) const
{
  return set (key, REG_SZ, val, size);
}

inline int
WriteRegistry::set (const Char *key, const void *val, int size) const
{
  return set (key, REG_BINARY, val, size);
}

class EnumRegistry: public ReadRegistry
{
public:
  EnumRegistry (const Char *subkey) : ReadRegistry (subkey) {}
  EnumRegistry (HKEY h, const Char *subkey) : ReadRegistry (h, subkey) {}
  operator HKEY () const {return hkey;}
};

struct decoded_time
{
  int year;
  int mon;
  int day;
  int hour;
  int min;
  int sec;
  int dow;
  int timezone;
  int daylight;
};

void decode_universal_time (lisp, decoded_time *);
lisp decoded_time_to_universal_time (int, int, int, int, int, int, int);
lisp file_time_to_universal_time (const FILETIME &);

#endif
