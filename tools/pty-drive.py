#!/usr/bin/env python3
"""Drive the ncurses xyzzy on a pty, send keystrokes, print the screen.

    tools/x pty '(defun foo (x' '\\e\\e(buffer-substring (point-min) (point-max))\\r'

This is the only way to see what the terminal frontend actually draws.  The
lisp suite does not run on the Linux build (issue #49) and tools/linux-smoke.sh
only proves the process comes up; anything about the *screen* -- where the
cursor sits, what a popup window looks like, whether a key reached the command
loop at all -- has to be looked at, and looking at it by hand does not scale.

Each argument is one step: the keys are written, then the screen is printed
once the output goes quiet.  Escapes in a step:

    \\e  ESC        \\r  RET        \\t  TAB        \\n  LFD
    \\CX  control-X (\\Cx is C-x)
    \\xNN  one raw byte
    \\w   wait for the screen to settle without sending anything

ESC is a prefix here just as it is in xyzzy, so M-x is "\\ex" and
eval-expression (ESC ESC) is "\\e\\e" -- the latter is the quickest way to ask
the running editor a question, since its result lands on the status line and
the status line is part of the dump.  A run always ends with M-x kill-xyzzy so
the process does not survive the script.

Environment:
    XYZZY_EXE   the binary to run (default /work/_build/linux/xyzzy, i.e. the
                path inside the tools/x container)
    XYZZY_PTY_ROWS / XYZZY_PTY_COLS   screen size (default 30x100)

The VT parser here understands only what this frontend emits (cursor moves,
erase, insert/delete line, and the private modes it ignores).  It is a way to
read the screen, not a terminal emulator.
"""
import os, pty, re, select, sys, time, fcntl, termios, struct

ROWS = int(os.environ.get("XYZZY_PTY_ROWS", "30"))
COLS = int(os.environ.get("XYZZY_PTY_COLS", "100"))
EXE = os.environ.get("XYZZY_EXE", "/work/_build/linux/xyzzy")
HOME = os.environ.get("XYZZYHOME", "/work")

def unescape(s):
    out = bytearray()
    i = 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            n = s[i+1]
            i += 2
            if n == 'e': out += b'\x1b'
            elif n == 'r': out += b'\r'
            elif n == 't': out += b'\t'
            elif n == 'n': out += b'\n'
            elif n == 'w': out += b'\x00WAIT\x00'
            elif n == 'x':
                out.append(int(s[i:i+2], 16)); i += 2
            elif n == 'C':
                out.append(ord(s[i].upper()) - 64); i += 1
            else: out.append(ord(n))
        else:
            out += c.encode('utf-8'); i += 1
    return bytes(out)

class Screen:
    """Just enough VT to see what is on the screen."""
    def __init__(self):
        self.buf = [[' '] * COLS for _ in range(ROWS)]
        self.r = self.c = 0
    def feed(self, data):
        text = data.decode('utf-8', 'replace')
        i = 0
        while i < len(text):
            ch = text[i]
            if ch == '\x1b':
                m = re.match(r'\x1b\[([0-9;?]*)([A-Za-z@])', text[i:])
                if m:
                    self.csi(m.group(1), m.group(2)); i += m.end(); continue
                m = re.match(r'\x1b[()][A-Za-z0-9]', text[i:])
                if m: i += m.end(); continue
                m = re.match(r'\x1b[=><]', text[i:])
                if m: i += m.end(); continue
                m = re.match(r'\x1b\][^\x07\x1b]*(\x07|\x1b\\)', text[i:])
                if m: i += m.end(); continue
                i += 1; continue
            if ch == '\r': self.c = 0
            elif ch == '\n': self.r = min(self.r + 1, ROWS - 1); self.c = 0
            elif ch == '\b': self.c = max(0, self.c - 1)
            elif ch == '\x07': pass
            elif ch == '\t': self.c = min(COLS - 1, (self.c // 8 + 1) * 8)
            elif ch >= ' ':
                if self.c < COLS:
                    self.buf[self.r][self.c] = ch
                self.c += 1
                if self.c >= COLS: self.c = COLS - 1
            i += 1
    def csi(self, params, final):
        if params.startswith('?'):
            return                      # private mode set/reset: ignore
        ps = [int(x) if x.isdigit() else 0 for x in params.split(';')] if params else []
        p = lambda k, d=1: ps[k] if len(ps) > k and ps[k] else d
        if final == 'H' or final == 'f':
            self.r = min(ROWS - 1, p(0) - 1); self.c = min(COLS - 1, p(1) - 1)
        elif final == 'A': self.r = max(0, self.r - p(0))
        elif final == 'B': self.r = min(ROWS - 1, self.r + p(0))
        elif final == 'C': self.c = min(COLS - 1, self.c + p(0))
        elif final == 'D': self.c = max(0, self.c - p(0))
        elif final == 'G': self.c = min(COLS - 1, p(0) - 1)
        elif final == 'd': self.r = min(ROWS - 1, p(0) - 1)
        elif final == 'J':
            mode = ps[0] if ps else 0
            if mode == 2:
                self.buf = [[' '] * COLS for _ in range(ROWS)]
            elif mode == 0:
                for c in range(self.c, COLS): self.buf[self.r][c] = ' '
                for r in range(self.r + 1, ROWS): self.buf[r] = [' '] * COLS
        elif final == 'K':
            mode = ps[0] if ps else 0
            if mode == 0:
                for c in range(self.c, COLS): self.buf[self.r][c] = ' '
            elif mode == 1:
                for c in range(0, self.c + 1): self.buf[self.r][c] = ' '
            else: self.buf[self.r] = [' '] * COLS
        elif final == 'L':
            for _ in range(p(0)):
                self.buf.insert(self.r, [' '] * COLS); self.buf.pop()
        elif final == 'M':
            for _ in range(p(0)):
                self.buf.pop(self.r); self.buf.append([' '] * COLS)
    def dump(self):
        return '\n'.join(''.join(row).rstrip() for row in self.buf)

def main():
    steps = sys.argv[1:] or [""]
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.environ["XYZZYHOME"] = HOME
        os.environ["LANG"] = "en_US.UTF-8"
        os.execv(EXE, [EXE])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    scr = Screen()

    def drain(quiet=0.6, total=25.0):
        end = time.time() + total
        last = time.time()
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.15)
            if r:
                try: data = os.read(fd, 65536)
                except OSError: return False
                if not data: return False
                scr.feed(data); last = time.time()
            elif time.time() - last > quiet:
                return True
        return True

    drain(quiet=1.5, total=40)
    print("=== startup ===")
    print(scr.dump())
    for step in steps:
        if not step: continue
        for chunk in unescape(step).split(b'\x00WAIT\x00'):
            if chunk:
                os.write(fd, chunk)
            drain()
        print("=== after %r ===" % step)
        print(scr.dump())
    os.write(fd, b'\x1bx')          # M-x
    drain()
    os.write(fd, b'kill-xyzzy\r')
    drain(quiet=0.4, total=5)
    try: os.close(fd)
    except OSError: pass
    os.waitpid(pid, 0)

main()
