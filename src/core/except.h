#ifndef _EXCEPT_H_
# define _EXCEPT_H_

#ifdef _WIN32

class Win32Exception
{
public:
  struct known_exception
    {
      u_int code;
      const char *desc;
    };
  static const known_exception known_excep[];
  static EXCEPTION_RECORD r;
  static CONTEXT c;
  static u_int code;
  Win32Exception (u_int, const EXCEPTION_POINTERS *);
  void throw_lisp_error ();
};

void __cdecl se_handler (u_int, EXCEPTION_POINTERS *);

#else // !_WIN32

// Dummy Win32Exception for non-Windows (never thrown, but catch blocks reference it)
class Win32Exception
{
public:
  u_int code;
  void throw_lisp_error () {}
};

#endif // _WIN32

void cleanup_exception ();

#endif
