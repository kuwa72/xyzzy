#include "stdafx.h"
#include "cdecl.h"
#include "version.h"
#include "version-describe.h"

#if !PROGRAM_PATCH_LEVEL
# if !PROGRAM_MINOR_REVISION
#  if !PROGRAM_MAJOR_REVISION
#   define PROGRAM_VERSION \
  _TOSTR (PROGRAM_MAJOR_VERSION) "." _TOSTR (PROGRAM_MINOR_VERSION)
#  else /* PROGRAM_MAJOR_REVISION */
#   define PROGRAM_VERSION \
  _TOSTR (PROGRAM_MAJOR_VERSION) "." _TOSTR (PROGRAM_MINOR_VERSION) \
    "." _TOSTR (PROGRAM_MAJOR_REVISION)
#  endif /* PROGRAM_MAJOR_REVISION */
# else /* PROGRAM_MINOR_REVISION */
#  define PROGRAM_VERSION \
  _TOSTR (PROGRAM_MAJOR_VERSION) "." _TOSTR (PROGRAM_MINOR_VERSION) \
    "." _TOSTR (PROGRAM_MAJOR_REVISION) "." _TOSTR (PROGRAM_MINOR_REVISION)
# endif /* PROGRAM_MINOR_REVISION */
#else /* PROGRAM_PATCH_LEVEL */
#  define PROGRAM_VERSION \
  _TOSTR (PROGRAM_MAJOR_VERSION) "." _TOSTR (PROGRAM_MINOR_VERSION) \
    "." _TOSTR (PROGRAM_MAJOR_REVISION) "." _TOSTR (PROGRAM_MINOR_REVISION) \
      "." _TOSTR (PROGRAM_PATCH_LEVEL)
#endif /* PROGRAM_PATCH_LEVEL */

#if defined(PROGRAM_VERSION_DESCRIBE_STRING)
# define DISPLAY_VERSION_STRING PROGRAM_VERSION_DESCRIBE_STRING
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
