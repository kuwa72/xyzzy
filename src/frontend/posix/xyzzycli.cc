#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <climits>
#include <ctime>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0
#endif

static bool
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

static std::string
socket_path ()
{
  std::string directory;
  if (runtime_directory (&directory))
    return directory + "/xyzzy-" + std::to_string (getuid ()) + ".sock";
  return "/tmp/xyzzy-" + std::to_string (getuid ()) + ".sock";
}

static std::string
quote_string (const std::string &s)
{
  std::string r;
  r.push_back ('"');
  for (unsigned char c : s)
    {
      if (c == '\\' || c == '"')
        r.push_back ('\\');
      r.push_back (c);
    }
  r.push_back ('"');
  return r;
}

static bool
wait_for_connection (const struct sockaddr_un &addr, int *fdp)
{
  for (int i = 0; i < 600; ++i)
    {
      int fd = socket (AF_UNIX, SOCK_STREAM, 0);
      if (fd < 0)
        return false;

      if (connect (fd, reinterpret_cast<const struct sockaddr *> (&addr),
                   sizeof (addr)) == 0)
        {
          *fdp = fd;
          return true;
        }

      int e = errno;
      close (fd);
      if (e != ECONNREFUSED)
        {
          errno = e;
          return false;
        }

      struct timespec ts = {0, 100000000};
      nanosleep (&ts, 0);
    }

  errno = ECONNREFUSED;
  return false;
}

static bool
send_request (int fd, const std::string &request)
{
  const char *p = request.c_str ();
  size_t left = request.size ();
  while (left > 0)
    {
      ssize_t n = send (fd, p, left, MSG_NOSIGNAL);
      if (n < 0)
        return false;
      p += n;
      left -= n;
    }
  return true;
}

int
main (int argc, char *argv[])
{
  if (argc < 2)
    {
      std::fprintf (stderr, "xyzzycli: no file specified\n");
      return 1;
    }

  char cwd[4096];
  if (!getcwd (cwd, sizeof (cwd)))
    {
      std::fprintf (stderr, "xyzzycli: cannot get current directory: %s\n",
                    std::strerror (errno));
      return 1;
    }

  std::string path = socket_path ();
  struct sockaddr_un addr;
  std::memset (&addr, 0, sizeof (addr));
  if (path.size () >= sizeof (addr.sun_path))
    {
      std::fprintf (stderr, "xyzzycli: socket path too long\n");
      return 1;
    }

  addr.sun_family = AF_UNIX;
  std::strcpy (addr.sun_path, path.c_str ());

  int fd = socket (AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0)
    {
      std::fprintf (stderr, "xyzzycli: cannot create socket: %s\n",
                    std::strerror (errno));
      return 1;
    }

  if (connect (fd, reinterpret_cast<const struct sockaddr *> (&addr),
               sizeof (addr)) != 0)
    {
      if (errno == ENOENT)
        {
          close (fd);
          std::fprintf (stderr, "xyzzycli: server is not running\n");
          return 1;
        }

      if (errno == ECONNREFUSED)
        {
          close (fd);
          if (!wait_for_connection (addr, &fd))
            {
              std::fprintf (stderr, "xyzzycli: server did not become ready: %s\n",
                            std::strerror (errno));
              return 1;
            }
        }
      else
        {
          std::fprintf (stderr, "xyzzycli: cannot connect to server: %s\n",
                        std::strerror (errno));
          return 1;
        }
    }

  std::string request = "(ed::*xyzzycli-helper ";
  request += quote_string (cwd);
  request += " '(";
  for (int i = 1; i < argc; ++i)
    {
      if (i > 1)
        request.push_back (' ');
      request += quote_string (argv[i]);
    }
  request += "))";

  if (!send_request (fd, request))
    {
      std::fprintf (stderr, "xyzzycli: cannot send request: %s\n",
                    std::strerror (errno));
      close (fd);
      return 1;
    }

  if (shutdown (fd, SHUT_WR) < 0)
    {
      std::fprintf (stderr, "xyzzycli: cannot shutdown: %s\n",
                    std::strerror (errno));
      close (fd);
      return 1;
    }

  char status;
  if (read (fd, &status, sizeof (status)) != 1 || status != 0)
    {
      close (fd);
      std::fprintf (stderr, "xyzzycli: request failed\n");
      return 1;
    }

  close (fd);
  return 0;
}
