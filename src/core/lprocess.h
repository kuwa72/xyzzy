// -*-C++-*-
#ifndef _process_h_
# define _process_h_

/* process */

# define PS_NONE 0
# define PS_RUN 1
# define PS_EXIT 2

class ProcessBase;
struct Buffer;
enum eol_code : int;

class lprocess: public lisp_object
{
public:
  /* **core の基底 (src/core/process-base.h) を持つ。** 以前はフロントエンドの
     `Process' を持っていたので、core からはメソッドを呼べなかった
     (前方宣言しか無いので不完全型)。プロセス固有のメソッドを呼ぶ側は
     フロントエンドで降ろす (ncurses の `posix_process ()')。 */
  ProcessBase *data;
  int status;
  int exit_code;
  lisp buffer;
  lisp command;
  lisp incode;
  lisp outcode;
  eol_code eol;
};

# define processp(X) typep ((X), Tprocess)

inline void
check_process (lisp x)
{
  check_type (x, Tprocess, Qprocess);
}

inline ProcessBase *&
xprocess_data (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->data;
}

inline int &
xprocess_status (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->status;
}

inline int &
xprocess_exit_code (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->exit_code;
}

inline lisp &
xprocess_buffer (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->buffer;
}

inline lisp &
xprocess_command (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->command;
}

inline lisp &
xprocess_incode (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->incode;
}

inline lisp &
xprocess_outcode (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->outcode;
}

inline eol_code &
xprocess_eol_code (lisp x)
{
  assert (processp (x));
  return ((lprocess *)x)->eol;
}

inline lprocess *
make_process ()
{
  lprocess *p = ldata <lprocess, Tprocess>::lalloc ();
  p->data = 0;
  p->status = PS_NONE;
  p->incode = Qnil;
  p->outcode = Qnil;
  p->command = Qnil;
  p->buffer = Qnil;
  return p;
}

#endif
