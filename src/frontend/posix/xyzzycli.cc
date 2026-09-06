#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <climits>
#include <ctime>
#include <fcntl.h>
#include <libgen.h>
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
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

// Receive the one-byte status and an optional wait fd via SCM_RIGHTS.
// Returns true on success.  *wait_fd is set to the received fd or -1.
static bool
recv_response (int fd, char *status, int *wait_fd)
{
  *wait_fd = -1;
  struct iovec iov = {status, sizeof (char)};
  char control[CMSG_SPACE (sizeof (int))];
  struct msghdr message;
  std::memset (&message, 0, sizeof message);
  message.msg_iov = &iov;
  message.msg_iovlen = 1;
  message.msg_control = control;
  message.msg_controllen = sizeof control;

  ssize_t n = recvmsg (fd, &message, 0);
  if (n != 1)
    return false;

  struct cmsghdr *header = CMSG_FIRSTHDR (&message);
  if (header && header->cmsg_level == SOL_SOCKET
      && header->cmsg_type == SCM_RIGHTS
      && header->cmsg_len == CMSG_LEN (sizeof (int)))
    std::memcpy (wait_fd, CMSG_DATA (header), sizeof (int));

  return true;
}

// Resolve the xyzzy server executable path.
// Looks for "xyzzy" next to xyzzycli, then falls back to PATH.
static std::string
find_xyzzy_exe (const char *argv0)
{
  // Try the directory containing xyzzycli itself.
  std::string self;

  // Resolve via /proc/self/exe first (Linux).
  char buf[4096];
  ssize_t len = readlink ("/proc/self/exe", buf, sizeof buf - 1);
  if (len > 0)
    {
      buf[len] = '\0';
      self = buf;
    }
  else if (argv0 && std::strchr (argv0, '/'))
    {
      // argv[0] contains a path component; use it directly.
      char *tmp = strdup (argv0);
      if (tmp)
        {
          self = tmp;
          free (tmp);
        }
    }

  if (!self.empty ())
    {
      // dirname may modify the string, so work on a copy.
      char *tmp = strdup (self.c_str ());
      if (tmp)
        {
          std::string dir = dirname (tmp);
          free (tmp);
          std::string candidate = dir + "/xyzzy";
          if (access (candidate.c_str (), X_OK) == 0)
            return candidate;
        }
    }

  return "xyzzy";
}

// Start the xyzzy server (xyzzy-ncurses) in the background.
// Returns true if the process was started successfully.
static bool
run_server (const char *argv0)
{
  std::string exe = find_xyzzy_exe (argv0);

  pid_t pid = fork ();
  if (pid < 0)
    return false;

  if (pid == 0)
    {
      // Child: start a new session so the server is independent.
      setsid ();

      // Redirect stdin/stdout/stderr to /dev/null.
      int devnull = open ("/dev/null", O_RDWR);
      if (devnull >= 0)
        {
          dup2 (devnull, STDIN_FILENO);
          dup2 (devnull, STDOUT_FILENO);
          dup2 (devnull, STDERR_FILENO);
          if (devnull > STDERR_FILENO)
            close (devnull);
        }

      // Start xyzzy with --batch and an expression that starts the server
      // and waits.
      execlp (exe.c_str (), exe.c_str (),
              "--batch",
              "-e", "(progn (start-xyzzy-server) (loop (sleep 3600)))",
              static_cast<char *> (0));
      _exit (127);
    }

  // Parent: wait briefly for the child to exec (not for it to exit).
  // The actual readiness check is done by wait_for_connection.
  struct timespec ts = {0, 50000000};
  nanosleep (&ts, 0);

  // Check that the child hasn't immediately exited (exec failure).
  int wstatus;
  pid_t r = waitpid (pid, &wstatus, WNOHANG);
  if (r == pid)
    return false;

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
      int e = errno;
      close (fd);

      if (e == ENOENT || e == ECONNREFUSED)
        {
          // Server is not running; try to start it.
          if (!run_server (argv[0]))
            {
              std::fprintf (stderr, "xyzzycli: cannot start server\n");
              return 1;
            }
          if (!wait_for_connection (addr, &fd))
            {
              std::fprintf (stderr,
                            "xyzzycli: server did not become ready: %s\n",
                            std::strerror (errno));
              return 1;
            }
        }
      else
        {
          std::fprintf (stderr, "xyzzycli: cannot connect to server: %s\n",
                        std::strerror (e));
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
  int wait_fd = -1;
  if (!recv_response (fd, &status, &wait_fd) || status != 0)
    {
      if (wait_fd >= 0)
        close (wait_fd);
      close (fd);
      std::fprintf (stderr, "xyzzycli: request failed\n");
      return 1;
    }

  close (fd);

  // If the server returned a wait fd (SCM_RIGHTS), block until the
  // buffer is killed.  The server writes one byte to the pipe when
  // the wait object is cleaned up.
  if (wait_fd >= 0)
    {
      char signal;
      while (read (wait_fd, &signal, sizeof signal) < 0 && errno == EINTR)
        ;
      close (wait_fd);
    }

  return 0;
}
