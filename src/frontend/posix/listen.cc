#include "stdafx.h"
#include "ed.h"

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <string>

#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

namespace
{
int listen_fd = -1;
std::string listen_path;

bool
runtime_directory (std::string *directory)
{
  const char *runtime = std::getenv ("XDG_RUNTIME_DIR");
  if (!runtime || !*runtime)
    return false;

  struct stat st;
  if (stat (runtime, &st) < 0 || !S_ISDIR (st.st_mode)
      || st.st_uid != getuid () || (st.st_mode & 077) != 0)
    return false;

  *directory = runtime;
  return true;
}

std::string
socket_path ()
{
  std::string directory;
  if (runtime_directory (&directory))
    return directory + "/xyzzy-" + std::to_string (getuid ()) + ".sock";
  return "/tmp/xyzzy-" + std::to_string (getuid ()) + ".sock";
}

bool
remove_stale_socket (const std::string &path)
{
  struct stat st;
  if (lstat (path.c_str (), &st) < 0)
    return errno == ENOENT;
  if (!S_ISSOCK (st.st_mode) || st.st_uid != getuid ())
    {
      errno = EADDRINUSE;
      return false;
    }
  return unlink (path.c_str ()) == 0;
}

bool
bind_listen_socket (const std::string &path)
{
  int fd = socket (AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0)
    return false;

  struct sockaddr_un address;
  std::memset (&address, 0, sizeof address);
  address.sun_family = AF_UNIX;
  if (path.size () >= sizeof address.sun_path)
    {
      close (fd);
      errno = ENAMETOOLONG;
      return false;
    }
  std::strcpy (address.sun_path, path.c_str ());

  mode_t old_umask = umask (077);
  int result = bind (fd, reinterpret_cast<struct sockaddr *> (&address),
                     sizeof address);
  umask (old_umask);

  if (result < 0 && errno == EADDRINUSE)
    {
      int probe = socket (AF_UNIX, SOCK_STREAM, 0);
      bool active = false;
      if (probe >= 0)
        {
          active = connect (probe,
                            reinterpret_cast<struct sockaddr *> (&address),
                            sizeof address) == 0;
          close (probe);
        }
      if (!active && remove_stale_socket (path))
        {
          old_umask = umask (077);
          result = bind (fd, reinterpret_cast<struct sockaddr *> (&address),
                         sizeof address);
          umask (old_umask);
        }
    }

  if (result < 0 || listen (fd, 1) < 0)
    {
      int saved_errno = errno;
      if (result == 0)
        unlink (path.c_str ());
      close (fd);
      errno = saved_errno;
      return false;
    }

  chmod (path.c_str (), 0600);
  listen_fd = fd;
  listen_path = path;
  return true;
}
}

void
init_listen_server ()
{
  if (listen_fd >= 0)
    return;

  std::string path = socket_path ();
  if (!bind_listen_socket (path))
    file_error (errno);
}

void
start_listen_server ()
{
}

void
end_listen_server ()
{
  if (listen_fd < 0)
    return;

  close (listen_fd);
  listen_fd = -1;
  unlink (listen_path.c_str ());
  listen_path.clear ();
}

lisp
Fstart_xyzzy_server ()
{
  if (listen_fd < 0)
    init_listen_server ();
  return boole (listen_fd >= 0);
}

lisp
Fstop_xyzzy_server ()
{
  end_listen_server ();
  return Qnil;
}
