#include "stdafx.h"
#include "ed.h"

#include <errno.h>
#include <unistd.h>

struct posix_wait_handle
{
  int read_fd;
  int write_fd;
};

void
lwait_object::cleanup ()
{
  if (hevent)
    {
      posix_wait_handle *handle = static_cast<posix_wait_handle *> (hevent);
      const char signal = 1;
      write (handle->write_fd, &signal, sizeof signal);
      close (handle->write_fd);
      close (handle->read_fd);
      delete handle;
      hevent = 0;
    }
}

static void
decref_waitobj (lisp lwaitobj)
{
  if (xwait_object_hevent (lwaitobj)
      && !--xwait_object_ref (lwaitobj))
    ((lwait_object *)lwaitobj)->cleanup ();
}

void
Buffer::cleanup_waitobj_list ()
{
  for (lisp p = lwaitobj_list; consp (p); p = xcdr (p))
    {
      lisp lwaitobj = xcar (p);
      if (wait_object_p (lwaitobj))
        decref_waitobj (lwaitobj);
    }
  lwaitobj_list = Qnil;
}

lisp
Fsi_create_wait_object ()
{
  int fds[2];
  if (pipe (fds) < 0)
    {
      file_error (errno);
      return Qnil;
    }

  posix_wait_handle *handle = new posix_wait_handle {fds[0], fds[1]};
  lisp lwaitobj = make_wait_object ();
  xwait_object_hevent (lwaitobj) = handle;
  xwait_object_ref (lwaitobj) = 0;
  return lwaitobj;
}

lisp
Fsi_add_wait_object (lisp lwaitobj, lisp lbuffer)
{
  check_wait_object (lwaitobj);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  bp->lwaitobj_list = xcons (lwaitobj, bp->lwaitobj_list);
  xwait_object_ref (lwaitobj)++;
  return Qt;
}

lisp
Fsi_remove_wait_object (lisp lwaitobj, lisp lbuffer)
{
  check_wait_object (lwaitobj);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  if (lwaitobj == Qnil)
    bp->cleanup_waitobj_list ();
  else if (delq (lwaitobj, &bp->lwaitobj_list))
    decref_waitobj (lwaitobj);
  return Qt;
}
