// -*-C++-*-
#ifndef _ts_h_
# define _ts_h_

class lts_grammar : public lisp_object
{
public:
  lisp name;           // language name string
  const void *lang;    // TSLanguage* (opaque to avoid header dep)
  HMODULE hmod;        // grammar DLL handle
  int loaded;          // 1 if we called LoadLibraryW

  ~lts_grammar () { if (hmod && loaded) FreeLibrary (hmod); }
};

# define ts_grammar_p(X) typep ((X), Tts_grammar)

inline void
check_ts_grammar (lisp x)
{
  check_type (x, Tts_grammar, Qsi_ts_grammar);
}

inline lisp &
xts_grammar_name (lisp x)
{
  assert (ts_grammar_p (x));
  return ((lts_grammar *)x)->name;
}

inline const void *&
xts_grammar_lang (lisp x)
{
  assert (ts_grammar_p (x));
  return ((lts_grammar *)x)->lang;
}

inline HMODULE &
xts_grammar_hmod (lisp x)
{
  assert (ts_grammar_p (x));
  return ((lts_grammar *)x)->hmod;
}

lts_grammar *make_ts_grammar ();

#endif /* !_ts_h_ */
