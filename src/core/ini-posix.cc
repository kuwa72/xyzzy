// -*-C++-*-
//
// 非 Win32 の INI ファイル読み書き — `GetPrivateProfileStringW` と
// `WritePrivateProfileStringW` の 2 つだけ。
//
// **設定の読み書き (src/core/conf-io.cc) はこの 2 つの上に建っている。**
// 848 行あった win32/conf.cc のうち Win32 に触っていたのはこの 2 つだけで、
// 残りは書式の処理だった。ここを書いたので、あちらがそのまま POSIX でも
// 動く (issue #143)。
//
// **Win32 の約束に合わせる。** 呼び出し側はそれを前提に書かれている:
//
//   * 節もキーも無ければ既定値 (`def`) を返す
//   * `name` が null なら節を丸ごと消す (delete_conf)
//   * `str` が null ならキーを消す
//   * `section` も `name` も null なら「キャッシュを書き出す」= ここでは
//     何もしない (flush_conf)
//   * 返す長さは終端を含まない文字数。バッファに収まらなければ切る
//
// **書き込みは読んで差し替えて書き戻す。** キーの順も、他の節も、コメントも
// 壊さない。INI は人が手で編集するファイルなので、書き換えのたびに並びが
// 変わると差分が読めなくなる。

#include "stdafx.h"
#include "ed.h"

#ifndef _WIN32

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include <string>
#include <vector>

namespace {

/* INI の中身を行の並びとして持つ。**行をそのまま持つ**のが要点で、
   構文解析した結果を持って書き戻すと、コメントや空行や見慣れない行が
   消える。 */
struct ini_file
{
  std::vector <std::string> lines;
  bool crlf;                    // 元のファイルが CRLF だったか

  ini_file () : crlf (false) {}
};

std::string
os_path_of (const wchar_t *path)
{
  if (!path)
    return std::string ();
  char buf[PATH_MAX * 4 + 1];
  /* w2u8 相当。ここでは ASCII とマルチバイトの両方を通す必要があるので、
     既にある変換を使う。 */
  int n = 0;
  for (const wchar_t *p = path; *p && n < int (sizeof buf) - 5; p++)
    {
      u_int c = u_int (*p);
      if (c < 0x80)
        buf[n++] = char (c);
      else if (c < 0x800)
        {
          buf[n++] = char (0xc0 | (c >> 6));
          buf[n++] = char (0x80 | (c & 0x3f));
        }
      else
        {
          buf[n++] = char (0xe0 | (c >> 12));
          buf[n++] = char (0x80 | ((c >> 6) & 0x3f));
          buf[n++] = char (0x80 | (c & 0x3f));
        }
    }
  buf[n] = 0;
  return std::string (buf);
}

std::string
narrow (const wchar_t *s)
{
  return os_path_of (s);
}

void
widen (const std::string &s, wchar_t *buf, int size)
{
  /* UTF-8 -> wchar_t。size は終端を含む。 */
  int n = 0;
  const u_char *p = (const u_char *)s.c_str ();
  while (*p && n < size - 1)
    {
      u_int c = *p;
      if (c < 0x80)
        p++;
      else if ((c & 0xe0) == 0xc0 && (p[1] & 0xc0) == 0x80)
        {
          c = ((c & 0x1f) << 6) | (p[1] & 0x3f);
          p += 2;
        }
      else if ((c & 0xf0) == 0xe0 && (p[1] & 0xc0) == 0x80 && (p[2] & 0xc0) == 0x80)
        {
          c = ((c & 0x0f) << 12) | ((p[1] & 0x3f) << 6) | (p[2] & 0x3f);
          p += 3;
        }
      else
        p++;                    // 壊れたバイトは 1 つ読み捨てる
      buf[n++] = wchar_t (c);
    }
  buf[n] = 0;
}

void
trim (std::string &s)
{
  std::string::size_type b = s.find_first_not_of (" \t\r\n");
  if (b == std::string::npos)
    {
      s.clear ();
      return;
    }
  std::string::size_type e = s.find_last_not_of (" \t\r\n");
  s = s.substr (b, e - b + 1);
}

int
same_name (const std::string &a, const std::string &b)
{
  /* **節名とキー名は大文字小文字を区別しない。** Win32 の
     Get/WritePrivateProfileString がそうなので、区別すると同じ ini を
     Windows と Linux で共有したときに二重にキーができる。 */
  if (a.size () != b.size ())
    return 0;
  for (std::string::size_type i = 0; i < a.size (); i++)
    {
      int x = a[i], y = b[i];
      if (x >= 'A' && x <= 'Z') x += 'a' - 'A';
      if (y >= 'A' && y <= 'Z') y += 'a' - 'A';
      if (x != y)
        return 0;
    }
  return 1;
}

/* 行が `[節]' ならその名前を返す。違えば空。 */
int
section_of (const std::string &line, std::string &name)
{
  std::string s (line);
  trim (s);
  if (s.size () < 2 || s[0] != '[' || s[s.size () - 1] != ']')
    return 0;
  name = s.substr (1, s.size () - 2);
  trim (name);
  return 1;
}

/* 行が `キー=値' ならキーと値を返す。コメント行 (`;' `#') は違う。 */
int
entry_of (const std::string &line, std::string &key, std::string &value)
{
  std::string s (line);
  trim (s);
  if (s.empty () || s[0] == ';' || s[0] == '#' || s[0] == '[')
    return 0;
  std::string::size_type eq = s.find ('=');
  if (eq == std::string::npos)
    return 0;
  key = s.substr (0, eq);
  value = s.substr (eq + 1);
  trim (key);
  trim (value);
  return key.empty () ? 0 : 1;
}

int
load (const std::string &path, ini_file &ini)
{
  FILE *fp = fopen (path.c_str (), "rb");
  if (!fp)
    return 0;
  std::string buf;
  int c;
  while ((c = getc (fp)) != EOF)
    {
      if (c == '\n')
        {
          if (!buf.empty () && buf[buf.size () - 1] == '\r')
            {
              ini.crlf = true;
              buf.erase (buf.size () - 1);
            }
          ini.lines.push_back (buf);
          buf.clear ();
        }
      else
        buf += char (c);
    }
  if (!buf.empty ())
    ini.lines.push_back (buf);
  fclose (fp);
  return 1;
}

int
store (const std::string &path, const ini_file &ini)
{
  /* **一時ファイルへ書いて rename する。** 途中で落ちても元の ini が
     半端な状態で残らない。設定ファイルは失うと痛い。 */
  std::string tmp (path);
  tmp += ".xyzzytmp";
  FILE *fp = fopen (tmp.c_str (), "wb");
  if (!fp)
    return 0;
  const char *eol = ini.crlf ? "\r\n" : "\n";
  for (std::vector <std::string>::const_iterator i = ini.lines.begin ();
       i != ini.lines.end (); i++)
    {
      if (fwrite (i->data (), 1, i->size (), fp) != i->size ()
          || fputs (eol, fp) == EOF)
        {
          fclose (fp);
          unlink (tmp.c_str ());
          return 0;
        }
    }
  if (fclose (fp))
    {
      unlink (tmp.c_str ());
      return 0;
    }
  if (rename (tmp.c_str (), path.c_str ()))
    {
      unlink (tmp.c_str ());
      return 0;
    }
  return 1;
}

/* SECTION の行の範囲を [begin, end) で返す。無ければ 0。 */
int
find_section (const ini_file &ini, const std::string &section,
              size_t &begin, size_t &end)
{
  std::string name;
  for (size_t i = 0; i < ini.lines.size (); i++)
    if (section_of (ini.lines[i], name) && same_name (name, section))
      {
        begin = i + 1;
        for (end = begin; end < ini.lines.size (); end++)
          if (section_of (ini.lines[end], name))
            break;
        return 1;
      }
  return 0;
}

} // namespace

/* 設定の置き場所を決める。Win32 の src/frontend/win32/init.cc の
   `init_user_config_path' / `init_user_inifile_path' に相当する。

   **優先順位は Win32 と同じ。** 起動オプション → 環境変数 → 既定。
   ここが違うと「Windows では -ini が効くのに Linux では効かない」になる。

     -config <dir>   / XYZZYCONFIGPATH   設定を置くディレクトリ
     -ini <file>     / XYZZYINIFILE      ini ファイルそのもの

   `config_path` の既定はホーム (Win32 は `usr/<ユーザ名>/` を作るが、POSIX に
   はホームがあるのでそこへ置く)。`ini_file` の既定は
   `<config_path>/xyzzy.ini`。

   **ini ファイルが無ければ空で作る。** Win32 は `-ini` に区切りを含む名前を
   渡された場合だけ CreateFile (OPEN_ALWAYS) で作るが、あちらは GUI が終了時に
   ウィンドウの位置を書くので結果としていつも存在する。端末ビルドには終了時に
   書くものが無いので、**作らないと「設定ファイルの場所」が指す先が存在しない
   まま**になる。 */
void
init_posix_config_paths (const char *config_path, const char *ini_file)
{
  if (!config_path)
    config_path = getenv ("XYZZYCONFIGPATH");
  if (!ini_file)
    ini_file = getenv ("XYZZYINIFILE");

  /* 設定ディレクトリ。指定があってディレクトリとして使えるならそれ、
     でなければホーム。**存在しない指定で黙って落ちないこと** —
     lisp/backup.l が起動時に (user-config-path) を連結するので、
     ここが壊れると startup.l ごと死ぬ。 */
  if (config_path && *config_path)
    {
      std::string dir (config_path);
      mkdir (dir.c_str (), 0700);       /* 既にあれば EEXIST で何もしない */
      struct stat st;
      if (stat (dir.c_str (), &st) == 0 && S_ISDIR (st.st_mode))
        {
          if (dir[dir.size () - 1] != '/')
            dir += '/';
          wchar_t w[PATH_MAX + 1];
          widen (dir, w, numberof (w));
          xsymbol_value (Quser_config_path) = make_path (w);
        }
    }

  /* ini ファイル。区切りを含む指定はそのまま使い、含まなければ設定
     ディレクトリの下の名前として扱う。 */
  std::string path;
  if (ini_file && *ini_file && strchr (ini_file, '/'))
    {
      /* **相対指定は絶対パスにする。** Win32 の init.cc も
         `WINFS::GetFullPathName' を通しているので、同じものを呼ぶ
         (非 Win32 の実装は src/core/vfs-posix.cc にある)。`-ini ./x.ini' で
         `(xyzzy-ini-path)' が相対パスを返すとそこだけ挙動が違い、途中で
         `chdir' すると同じ相対パスが別のファイルを指してしまう。 */
      wchar_t w[PATH_MAX + 1], full[PATH_MAX + 1], *tail;
      widen (std::string (ini_file), w, numberof (w));
      DWORD l = WINFS::GetFullPathName (w, numberof (full), full, &tail);
      path = (l && l < numberof (full)) ? narrow (full) : std::string (ini_file);
    }
  else
    {
      lisp cfg = xsymbol_value (Quser_config_path);
      if (!stringp (cfg))
        return;
      wchar_t w[PATH_MAX + 1];
      int l = i2wl (xstring_contents (cfg), xstring_length (cfg));
      if (l >= numberof (w))
        return;
      *i2w (xstring_contents (cfg), xstring_length (cfg), w) = 0;
      path = narrow (w);
      if (!path.empty () && path[path.size () - 1] != '/')
        path += '/';
      path += (ini_file && *ini_file) ? ini_file : "xyzzy.ini";
    }

  /* 無ければ空で作る (上のコメント参照)。作れなくても場所は覚える:
     読めないだけで、設定が既定に戻るのは今までと同じ。 */
  int fd = open (path.c_str (), O_RDONLY | O_CREAT, 0600);
  if (fd >= 0)
    close (fd);

  wchar_t w[PATH_MAX + 1];
  widen (path, w, numberof (w));
  xfree (app.ini_file_path);
  app.ini_file_path = xwcsdup (w);
}

DWORD WINAPI
GetPrivateProfileStringW (LPCWSTR lsection, LPCWSTR lname, LPCWSTR ldef,
                          LPWSTR buf, DWORD size, LPCWSTR lfile)
{
  if (!buf || size == 0)
    return 0;
  *buf = 0;

  std::string def (ldef ? narrow (ldef) : std::string ());

  if (lfile && lsection && lname)
    {
      ini_file ini;
      if (load (os_path_of (lfile), ini))
        {
          size_t begin, end;
          if (find_section (ini, narrow (lsection), begin, end))
            {
              std::string wanted (narrow (lname)), key, value;
              for (size_t i = begin; i < end; i++)
                if (entry_of (ini.lines[i], key, value) && same_name (key, wanted))
                  {
                    widen (value, buf, int (size));
                    return DWORD (wcslen (buf));
                  }
            }
        }
    }

  widen (def, buf, int (size));
  return DWORD (wcslen (buf));
}

BOOL WINAPI
WritePrivateProfileStringW (LPCWSTR lsection, LPCWSTR lname, LPCWSTR lstr,
                            LPCWSTR lfile)
{
  if (!lfile)
    return FALSE;
  /* section も name も null = キャッシュの書き出し。ここには溜めていない。 */
  if (!lsection)
    return TRUE;

  std::string path (os_path_of (lfile));
  std::string section (narrow (lsection));
  ini_file ini;
  load (path, ini);             // 無ければ空から作る

  size_t begin, end;
  int found = find_section (ini, section, begin, end);

  if (!lname)
    {
      /* 節を丸ごと消す (見出しの行も)。 */
      if (!found)
        return TRUE;
      ini.lines.erase (ini.lines.begin () + (begin - 1),
                       ini.lines.begin () + end);
      return store (path, ini) ? TRUE : FALSE;
    }

  std::string name (narrow (lname));

  if (!found)
    {
      if (!lstr)
        return TRUE;            // 消す相手が無い
      /* 節を末尾に足す。**前に空行を 1 つ置く** — 節の切れ目が見えないと
         手で編集しづらい。 */
      if (!ini.lines.empty () && !ini.lines.back ().empty ())
        ini.lines.push_back (std::string ());
      ini.lines.push_back ("[" + section + "]");
      ini.lines.push_back (name + "=" + narrow (lstr));
      return store (path, ini) ? TRUE : FALSE;
    }

  std::string key, value;
  for (size_t i = begin; i < end; i++)
    if (entry_of (ini.lines[i], key, value) && same_name (key, name))
      {
        if (!lstr)
          ini.lines.erase (ini.lines.begin () + i);
        else
          ini.lines[i] = name + "=" + narrow (lstr);
        return store (path, ini) ? TRUE : FALSE;
      }

  if (!lstr)
    return TRUE;                // 消す相手が無い

  /* 節の末尾へ足す。**節の最後の空行より前に入れる** — 節の間の空行を
     食うと、書くたびに節がくっついていく。 */
  size_t at = end;
  while (at > begin && ini.lines[at - 1].empty ())
    at--;
  ini.lines.insert (ini.lines.begin () + at, name + "=" + narrow (lstr));
  return store (path, ini) ? TRUE : FALSE;
}

#endif // !_WIN32
