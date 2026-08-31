// -*-C++-*-
#ifndef _error_h_
# define _error_h_

/* エラーの番号がどの空間のものかを表す category。**番号と必ず対で持つ。**
   `std::error_code` の `value` + `category`、Python が `errno` と `winerror`
   を別の属性に分けているのと同じ趣旨 (PEP 3151)。

     CRTL_ERROR   C ランタイムの errno
     WIN32_ERROR  OS のエラーコード。Win32 では GetLastError () の値、
                  POSIX では errno (src/core/platform.h の GetLastError)
     WSA_ERROR    ソケットのエラー。Win32 では WSA*、POSIX では errno
                  (platform.h が WSA* を errno の別名として define している)

   **番号だけを裸で持ち回ると空間をまたいで誤って当たる。** 実際に起きていた:
   POSIX でファイルが見つからない `ENOENT` (2) が、ソケットの表の
   `WSATRY_AGAIN` (2) に当たって「Non-Authoritative; Host not found, or
   SERVERFAIL」と出ていた。**WSA_ERROR はそれを型で分けるために足した。**
   issue #120 を参照。

   `SOCKET_ERROR` という名前は使えない (Win32 が -1 の意味で使っている)。 */
enum {CRTL_ERROR, WIN32_ERROR, WSA_ERROR};

/* OS のエラー番号の**意味**を聞く。`GetLastError ()' の戻り値を `ERROR_*' と
   直に比べてはいけない: 番号の空間がプラットフォームで違う (Win32 は Win32 の
   コード、POSIX は errno) ので、**POSIX では一致しない比較がそのまま残る。**

   実際に効いていなかったもの: `EACCES' (13) は `ERROR_ACCESS_DENIED' (5) に
   一致しないので `:if-access-denied' の再試行が POSIX で一度も走らず、
   `EEXIST' (17) は `ERROR_FILE_EXISTS' (80) にも `ERROR_ALREADY_EXISTS' (183)
   にも一致しないので `create-directory' が既存のディレクトリで黙って成功して
   いた。issue #120 を参照。

   意味を聞く形にして、プラットフォームの分岐をここ 1 か所に閉じる。
   **`ERROR_*' を errno の別名にする案は採らない。** それをすると
   `ERROR_FILE_NOT_FOUND' と `ERROR_PATH_NOT_FOUND' が両方 `ENOENT' になって
   `switch' の `case' が重複し、しかもソケットのエラー (POSIX では WSA* が
   errno の別名) と同じ空間で完全に重なる。 */
inline int
os_error_already_exists (int e)
{
#ifdef _WIN32
  return e == ERROR_FILE_EXISTS || e == ERROR_ALREADY_EXISTS;
#else
  return e == EEXIST;
#endif
}

inline int
os_error_access_denied (int e)
{
#ifdef _WIN32
  return e == ERROR_ACCESS_DENIED;
#else
  return e == EACCES || e == EPERM;
#endif
}

inline int
os_error_path_not_found (int e)
{
#ifdef _WIN32
  return e == ERROR_PATH_NOT_FOUND;
#else
  /* POSIX の `chdir' や `open' は「途中の要素が無い」も `ENOENT' で返すので、
     Win32 の ERROR_PATH_NOT_FOUND と 1 対 1 にはならない。ここが問うている
     のは「親を作れば通る見込みがあるか」なので、両方を含める。 */
  return e == ENOENT || e == ENOTDIR;
#endif
}

/* 「その名前のものが無い」。**Win32 の 4 通りをまとめている**のは、POSIX の
   `ENOENT` がその 4 通り全部に当たるため。ファイルが無いのか途中の要素が
   無いのかを区別したい所では `os_error_path_not_found` の方を使う。

   **Win32 側で 4 通りをまとめてよい所だけで使う。** `ERROR_FILE_NOT_FOUND`
   だけを見ていた所をこれに置き換えると、Windows の答えが変わる
   (`ERROR_PATH_NOT_FOUND` も一致するようになる)。そういう所は
   `os_error_file_not_found` を使う。 */
inline int
os_error_not_found (int e)
{
#ifdef _WIN32
  return (e == ERROR_FILE_NOT_FOUND || e == ERROR_PATH_NOT_FOUND
          || e == ERROR_BAD_NETPATH || e == ERROR_BAD_PATHNAME);
#else
  return e == ENOENT || e == ENOTDIR;
#endif
}

/* 「ファイルが無い」だけ。**`os_error_not_found` と違って、途中の要素が無い
   場合を Win32 側で含めない。** `ERROR_FILE_NOT_FOUND` だけを見ていた所を
   そのままの意味で書き直すためのもの。

   POSIX 側は `ENOENT` で、**そこは区別できない** (`open` も `unlink` も、
   最後の要素が無い場合と途中の要素が無い場合の両方を `ENOENT` で返す)。
   区別が要る所は `refine_not_found` (src/core/pathname.cc) が親を stat して
   分けている。 */
inline int
os_error_file_not_found (int e)
{
#ifdef _WIN32
  return e == ERROR_FILE_NOT_FOUND;
#else
  return e == ENOENT;
#endif
}

inline int
os_error_sharing_violation (int e)
{
#ifdef _WIN32
  return e == ERROR_SHARING_VIOLATION;
#else
  return e == EBUSY || e == ETXTBSY;
#endif
}

class lerror: public lisp_object
{
public:
  int type;
  int number;
};

# define errorp(X) typep ((X), Terror)

inline int &
xerror_type (lisp x)
{
  assert (errorp (x));
  return ((lerror *)x)->type;
}

inline int &
xerror_number (lisp x)
{
  assert (errorp (x));
  return ((lerror *)x)->number;
}

inline lerror *
make_error (int type, int number)
{
  lerror *p = ldata <lerror, Terror>::lalloc ();
  p->type = type;
  p->number = number;
  return p;
}

#endif
