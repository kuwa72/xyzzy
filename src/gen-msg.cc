#include "gen-stdafx.h"
#include "chtype.h"
#ifndef _WIN32
#include <iconv.h>
#endif

#include "chtab.cc"

struct msgdef
{
  const char *ident;
  const char *text;
};

#define MSG(a, b) {#a, b}

static const msgdef msg[] =
{
#include "msgdef.h"
};

/* Convert UTF-8 string to CP932. Caller must free() the result. */
static char *
utf8_to_cp932 (const char *utf8)
{
#ifdef _WIN32
  int wlen = MultiByteToWideChar (CP_UTF8, 0, utf8, -1, NULL, 0);
  wchar_t *wbuf = (wchar_t *)malloc (wlen * sizeof (wchar_t));
  MultiByteToWideChar (CP_UTF8, 0, utf8, -1, wbuf, wlen);

  int clen = WideCharToMultiByte (932, 0, wbuf, -1, NULL, 0, NULL, NULL);
  char *cbuf = (char *)malloc (clen);
  WideCharToMultiByte (932, 0, wbuf, -1, cbuf, clen, NULL, NULL);

  free (wbuf);
  return cbuf;
#else
  /* Non-Windows: convert UTF-8 to CP932 using iconv */
  iconv_t cd = iconv_open ("CP932", "UTF-8");
  if (cd == (iconv_t)-1)
    {
      /* Fallback: pass through as-is (will be garbled but won't crash) */
      char *cbuf = (char *)malloc (strlen (utf8) + 1);
      strcpy (cbuf, utf8);
      return cbuf;
    }
  size_t inlen = strlen (utf8);
  size_t outlen = inlen * 2 + 4; /* CP932 can be up to 2 bytes per UTF-8 char */
  char *cbuf = (char *)malloc (outlen);
  char *inp = (char *)utf8;
  char *outp = cbuf;
  size_t inrem = inlen;
  size_t outrem = outlen - 1;
  size_t r = iconv (cd, &inp, &inrem, &outp, &outrem);
  if (r == (size_t)-1 && inrem > 0)
    {
      /* Conversion failed partway: fill rest with '?' */
      while (outrem > 0 && inrem > 0) { *outp++ = '?'; inrem--; outrem--; }
    }
  *outp = '\0';
  iconv_close (cd);
  return cbuf;
#endif
}

/* Output CP932 bytes with C escaping.
   Non-ASCII bytes are emitted as octal escapes to avoid
   SJIS trail-byte-is-backslash issues. */
static void
print_quote_cp932 (const char *p)
{
  while (*p)
    {
      unsigned char c = *p & 0xff;
      if (c < ' ' || c >= 0x80)
        {
          printf ("\\%03o", c);
          p++;
        }
      else if (c == '\\' || c == '"')
        {
          putchar ('\\');
          putchar (*p++);
        }
      else
        putchar (*p++);
    }
}

static void
print_quote (const char *p)
{
  while (*p)
    {
      if ((*p & 0xff) < ' ')
        printf ("\\%03o", *p++);
      else
        {
          if (*p == '\\' || *p == '"')
            putchar ('\\');
          putchar (*p);
          p++;
        }
    }
}

static void
print_quote_rc (const char *p)
{
  while (*p)
    {
      if ((*p & 0xff) < ' ')
        printf ("\\%03o", *p++);
      else
        {
          if (*p == '\\' || *p == '"')
            putchar (*p);
          putchar (*p);
          p++;
        }
    }
}

void
gen_msg (int argc, char **argv)
{
  if (argc == 1)
    exit (2);
  if (!strcmp (argv[1], "-def"))
    {
      for (int i = 0; i < numberof (msg); i++)
        printf ("#define %s %d\n", msg[i].ident, i);
    }
  else if (!strcmp (argv[1], "-enum"))
    {
      printf ("enum message_code : int\n{\n");
      int i;
      for (i = 0; i < numberof (msg) - 1; i++)
        printf ("  %s,\n", msg[i].ident);
      printf ("  %s\n", msg[i].ident);
      printf ("};\n");
    }
  else if (!strcmp (argv[1], "-c"))
    {
      /* Convert all message texts from UTF-8 to CP932 */
      int nmsg = numberof (msg);
      char **texts = (char **)malloc (nmsg * sizeof (char *));
      for (int i = 0; i < nmsg; i++)
        texts[i] = utf8_to_cp932 (msg[i].text);

      printf ("const char SSM[] =\n");
      for (int i = 0; i < nmsg; i++)
        {
          printf ("  \"");
          print_quote_cp932 (texts[i]);
          printf ("\\0\"\n");
        }
      printf (";\n\n");

      printf ("static const char *const message_string[] =\n");
      printf ("{\n");
      int l = 0;
      for (int i = 0; i < nmsg; i++)
        {
          printf ("  SSM + %d,\n", l);
          l += strlen (texts[i]) + 1;
        }
      printf ("};\n\n");

      for (int i = 0; i < nmsg; i++)
        free (texts[i]);
      free (texts);

      printf ("const char *\n"
              "get_message_string (int code)\n"
              "{return message_string[code];}\n");
    }
  else if (!strcmp (argv[1], "-stbl"))
    {
      printf ("STRINGTABLE DISCARDABLE\n");
      printf ("BEGIN\n");
      for (int i = 0; i < numberof (msg); i++)
        {
          printf ("  %d \"", i + 1024);
          print_quote_rc (msg[i].text);
          printf ("\"\n");
        }
      printf ("END\n");
    }
  else if (!strcmp (argv[1], "-rc"))
    {
      printf ("#include \"ed.h\"\n"
              "const char *\n"
              "get_message_string (int code)\n"
              "{\n"
              "  static char buf[256];\n"
              "  if (!LoadString (app.hinst, 1024 + code, buf, sizeof buf))\n"
              "    sprintf (buf, \"String resource %%d not found.\", code);\n"
              "  return buf;\n"
              "}\n");
    }
  exit (0);
}
