// -*-C++-*-
#ifndef _ts_h_
# define _ts_h_

class lts_grammar : public lisp_object
{
public:
  lisp name;           // language name string
  const void *lang;    // TSLanguage* (opaque to avoid header dep)
  HMODULE hmod;        // grammar DLL handle (外さない。下のデストラクタ)
  int loaded;          // 1 if we called LoadLibraryW / dlopen

  /* 文法 DLL はプロセスが終わるまで読み込んだままにする。**ここで
     `FreeLibrary' / `dlclose' してはいけない。**

     `TSLanguage' は DLL の中の静的データで、`si:ts-query-buffer' などが
     `g_ts_cache' に置く `TSTree' / `TSQuery' と解析用の裏スレッドが、この
     オブジェクトより長くそれを指す。GC された瞬間に外すと、**まだ使う側が
     残っているのに `TSLanguage' だけが消える。**

     これは机上の話ではなく、`ts-register-mode' (lisp/ts.l) が同じモードを
     二度登録すると前のオブジェクトを捨てるので実際に起きる。Windows では
     二度目の `si:load-ts-grammar' が `GetModuleHandleW' で拾って所有権を
     持たないため参照数が増えず、一度目が GC されると DLL が外れた。外れた
     `TSLanguage' を裏スレッドが読んで `ts_query_cursor__advance' の中で
     0xc0000005 になっている (issue #382)。 */
  ~lts_grammar () {}
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
