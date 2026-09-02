#include "stdafx.h"
#include "cdecl.h"
#include "version.h"
#include "version-describe.h"

/* MAJOR.MINOR.PATCH の 3 桁は末尾が 0 でも省かない。ZIP とインストーラの名前は
   CMake の PROJECT_VERSION (0.3.0) を使うので、本体が "0.3" と名乗ると突き合わせ
   にくい。4 桁目以降は使うときだけ出す (今の体系では使わない)。 */
#define PROGRAM_VERSION_BASE \
  _TOSTR (PROGRAM_MAJOR_VERSION) "." _TOSTR (PROGRAM_MINOR_VERSION) \
    "." _TOSTR (PROGRAM_MAJOR_REVISION)

#if !PROGRAM_PATCH_LEVEL
# if !PROGRAM_MINOR_REVISION
#  define PROGRAM_VERSION PROGRAM_VERSION_BASE
# else /* PROGRAM_MINOR_REVISION */
#  define PROGRAM_VERSION \
  PROGRAM_VERSION_BASE "." _TOSTR (PROGRAM_MINOR_REVISION)
# endif /* PROGRAM_MINOR_REVISION */
#else /* PROGRAM_PATCH_LEVEL */
#  define PROGRAM_VERSION \
  PROGRAM_VERSION_BASE "." _TOSTR (PROGRAM_MINOR_REVISION) \
    "." _TOSTR (PROGRAM_PATCH_LEVEL)
#endif /* PROGRAM_PATCH_LEVEL */

/* 表示用のバージョンは**素のバージョンで始める。** タグより後ろに居るときは
   `git describe` の後ろ半分 ("-37-g97c4acf" / "-dirty") だけを足す
   (cmake/git-describe.cmake)。タグの名前は**前の**リリースを指すので、
   そのまま出すと bump からタグまでの間、0.7.0 のビルドが自分を
   "0.6.0-144-gfc2e845e" と名乗る。 */
#if defined(PROGRAM_VERSION_DESCRIBE_SUFFIX)
# define DISPLAY_VERSION_STRING PROGRAM_VERSION PROGRAM_VERSION_DESCRIBE_SUFFIX
#else
# define DISPLAY_VERSION_STRING PROGRAM_VERSION
#endif

#define TITLEBAR_STRING PROGRAM_NAME " " DISPLAY_VERSION_STRING " (" BUILD_PLATFORM ")"

char TitleBarString[TITLE_BAR_STRING_SIZE] = TITLEBAR_STRING;
wchar_t TitleBarStringW[TITLE_BAR_STRING_SIZE] = L"" TITLEBAR_STRING;

// Char (internal encoding) version — s2w(TitleBarString) at first use or startup
Char TitleBarStringC[TITLE_BAR_STRING_SIZE];

void
init_TitleBarStringC ()
{
  // Char is a UTF-16 code unit and so is wchar_t on Windows, so take it from
  // the wide title rather than the byte one: the host name appended to it is
  // not necessarily ASCII.
  const wchar_t *s = TitleBarStringW;
  Char *d = TitleBarStringC;
  while (*s)
    *d++ = Char (*s++);
  *d = 0;
}
const char VersionString[] = PROGRAM_VERSION;
const char DisplayVersionString[] = DISPLAY_VERSION_STRING;
const char ProgramName[] = PROGRAM_NAME;
const char ProgramNameWithVersion[] = PROGRAM_NAME " version " PROGRAM_VERSION;
const char ProgramAppUserModelId[] = PROGRAM_APP_USER_MODEL_ID;
