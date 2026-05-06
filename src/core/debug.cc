#include "stdafx.h"
#include "lisp.h"
#include "debug.h"

#define BUF_SIZE 512

void
Debug (char *format, ...)
{
  va_list ap;
  char msg[BUF_SIZE];

  va_start (ap, format);
  vsnprintf (msg, BUF_SIZE, format, ap);
  va_end (ap);

  char buf[BUF_SIZE * 2];
  snprintf (buf, BUF_SIZE * 2, "%s\n", msg);
#ifdef _WIN32
  OutputDebugStringA (buf);
#else
  fputs (buf, stderr);
#endif
}

void
Debug (const ucs4_t *b, size_t size)
{
  if (size <= 0)
    return;

  char *msg = (char *)alloca (size * 3 + 1);
  w2s (msg, b, size);
#ifdef _WIN32
  OutputDebugStringA (msg);
#else
  fputs (msg, stderr);
#endif
}
