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
    XYZZY_PTY_ARGS   コマンドラインの引数 (空白で切る)。付けないと引数なしで
                起動する。**ここが空だと「引数が効かない」ことは測れない** ので、
                起動オプションを見るときは必ず渡す。
    XYZZY_PTY_ROWS / XYZZY_PTY_COLS   screen size (default 30x100)
    XYZZY_PTY_BOOT   seconds to wait for the first paint (default 90).  Start up
                loads the whole lisp library and draws nothing until it is done:
                about a second in the tools/x container, seventeen on a cold CI
                runner.  Waiting only for the output to go quiet returns a blank
                screen there and then types at a process that is not listening
                yet, so the wait is for the first paint, not for silence.

    XYZZY_PTY_RAW   if set, also print the raw byte stream for each step with
                escapes made visible.  The screen model below tracks characters
                only and drops SGR, so a change that is *only* an attribute --
                a colour, a bold, an underline -- leaves the dump identical and
                reads as "nothing happened".  That covers everything built on
                set-text-attribute: tree-sitter highlighting, diff, ispell,
                calendar, flymake.  Grep the raw stream for the SGR you expect
                (underline is ESC[4m) rather than adding an attribute plane to
                the screen, which would have to mirror every scroll, insert and
                erase below to stay honest.

The VT parser here understands only what this frontend emits (cursor moves,
erase, insert/delete line, and the private modes it ignores).  It is a way to
read the screen, not a terminal emulator.

Two things about the model that have each caused a wrong conclusion:

    It has no idea about double width.  `put` advances the column by one for
    every character, so a full width character occupies one cell here and two
    on a real terminal.  A row of CJK text therefore ends at a different
    *character* offset in the dump than the column the frontend addressed with
    CUP, and two rows of the same real width can come out with different
    lengths here.  Assert on ASCII (a box border is all `q`) or on the presence
    of the text, never on how many characters precede something in a row that
    contains CJK.

    With XYZZY_PTY_RAW each step prints two blocks, "=== after" and
    "=== raw after".  Counting occurrences of "=== after" to pick out step N
    then lands one step early, which reads as "the popup never appeared".
"""
import os, pty, re, select, sys, time, fcntl, termios, struct

ROWS = int(os.environ.get("XYZZY_PTY_ROWS", "30"))
COLS = int(os.environ.get("XYZZY_PTY_COLS", "100"))
EXE = os.environ.get("XYZZY_EXE", "/work/_build/linux/xyzzy")
ARGS = os.environ.get("XYZZY_PTY_ARGS", "").split()
HOME = os.environ.get("XYZZYHOME", "/work")
BOOT = float(os.environ.get("XYZZY_PTY_BOOT", "90"))
RAW = bool(os.environ.get("XYZZY_PTY_RAW"))

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
    """Just enough VT to see what this frontend draws.

    The parts that matter beyond plain text are the ones ncurses actually uses
    to avoid redrawing: a scroll region (DECSTBM) plus SU/SD, insert/delete
    line, delete/insert character, erase character, and REP.  Without them the
    dump keeps stale text and reads as a rendering bug in the editor -- which
    is exactly the wrong conclusion to hand back.  This was learned the hard
    way: a candidate list looked corrupted ("kickward-delete-char-untabify")
    when the screen was in fact correct and REP was being dropped here.
    """
    def __init__(self):
        self.buf = [[' '] * COLS for _ in range(ROWS)]
        self.r = self.c = 0
        self.last = ' '                 # for REP (CSI b)
        self.top, self.bot = 0, ROWS - 1
        self.saved = (0, 0)

    def blank(self):
        return [' '] * COLS

    def put(self, ch):
        if self.c < COLS:
            self.buf[self.r][self.c] = ch
        self.c += 1
        if self.c >= COLS:
            self.c = COLS - 1
        self.last = ch

    def scroll_up(self, n=1):
        for _ in range(n):
            del self.buf[self.top]
            self.buf.insert(self.bot, self.blank())

    def scroll_down(self, n=1):
        for _ in range(n):
            del self.buf[self.bot]
            self.buf.insert(self.top, self.blank())

    def newline(self):
        if self.r == self.bot:
            self.scroll_up()
        else:
            self.r = min(ROWS - 1, self.r + 1)

    def feed(self, data):
        text = data.decode('utf-8', 'replace')
        i = 0
        while i < len(text):
            ch = text[i]
            if ch == '\x1b':
                rest = text[i:]
                m = re.match(r'\x1b\[([0-9;?]*)([A-Za-z@`])', rest)
                if m:
                    self.csi(m.group(1), m.group(2)); i += m.end(); continue
                m = re.match(r'\x1b\][^\x07\x1b]*(\x07|\x1b\\)', rest)
                if m: i += m.end(); continue
                m = re.match(r'\x1b[()][A-Za-z0-9]', rest)
                if m: i += m.end(); continue
                m = re.match(r'\x1b([78DEMc=><])', rest)
                if m:
                    self.esc(m.group(1)); i += m.end(); continue
                i += 1; continue
            if ch == '\r': self.c = 0
            elif ch == '\n': self.newline(); self.c = 0
            elif ch == '\b': self.c = max(0, self.c - 1)
            elif ch == '\x07': pass
            elif ch == '\t': self.c = min(COLS - 1, (self.c // 8 + 1) * 8)
            elif ch >= ' ': self.put(ch)
            i += 1

    def esc(self, final):
        if final == '7': self.saved = (self.r, self.c)
        elif final == '8': self.r, self.c = self.saved
        elif final == 'D': self.newline()
        elif final == 'E': self.newline(); self.c = 0
        elif final == 'M':
            if self.r == self.top: self.scroll_down()
            else: self.r = max(0, self.r - 1)
        elif final == 'c': self.__init__()

    def csi(self, params, final):
        if params.startswith('?'):
            return                      # private mode set/reset: ignore
        ps = [int(x) if x.isdigit() else 0
              for x in params.split(';')] if params else []
        p = lambda k, d=1: ps[k] if len(ps) > k and ps[k] else d
        if final in 'Hf':
            self.r = min(ROWS - 1, p(0) - 1); self.c = min(COLS - 1, p(1) - 1)
        elif final == 'A': self.r = max(0, self.r - p(0))
        elif final == 'B': self.r = min(ROWS - 1, self.r + p(0))
        elif final == 'C': self.c = min(COLS - 1, self.c + p(0))
        elif final == 'D': self.c = max(0, self.c - p(0))
        elif final in 'G`': self.c = min(COLS - 1, p(0) - 1)
        elif final == 'd': self.r = min(ROWS - 1, p(0) - 1)
        elif final == 'r':
            self.top = min(ROWS - 1, p(0) - 1)
            self.bot = min(ROWS - 1, p(1, ROWS) - 1)
            if self.bot <= self.top: self.top, self.bot = 0, ROWS - 1
            self.r, self.c = self.top, 0
        elif final == 'J':
            mode = ps[0] if ps else 0
            if mode == 2:
                self.buf = [self.blank() for _ in range(ROWS)]
            elif mode == 0:
                for c in range(self.c, COLS): self.buf[self.r][c] = ' '
                for r in range(self.r + 1, ROWS): self.buf[r] = self.blank()
            elif mode == 1:
                for r in range(0, self.r): self.buf[r] = self.blank()
                for c in range(0, self.c + 1): self.buf[self.r][c] = ' '
        elif final == 'K':
            mode = ps[0] if ps else 0
            if mode == 0:
                for c in range(self.c, COLS): self.buf[self.r][c] = ' '
            elif mode == 1:
                for c in range(0, self.c + 1): self.buf[self.r][c] = ' '
            else: self.buf[self.r] = self.blank()
        elif final == 'L':                              # insert line
            for _ in range(p(0)):
                self.buf.insert(self.r, self.blank()); del self.buf[self.bot + 1]
        elif final == 'M':                              # delete line
            for _ in range(p(0)):
                del self.buf[self.r]; self.buf.insert(self.bot, self.blank())
        elif final == 'S': self.scroll_up(p(0))
        elif final == 'T': self.scroll_down(p(0))
        elif final == 'b':                              # REP
            ch = self.last
            for _ in range(p(0)): self.put(ch)
        elif final == 'X':                              # erase chars
            for c in range(self.c, min(COLS, self.c + p(0))):
                self.buf[self.r][c] = ' '
        elif final == 'P':                              # delete chars
            row = self.buf[self.r]
            del row[self.c:self.c + p(0)]
            row.extend([' '] * (COLS - len(row)))
        elif final == '@':                              # insert chars
            row = self.buf[self.r]
            for _ in range(p(0)): row.insert(self.c, ' ')
            del row[COLS:]

    def dump(self):
        return '\n'.join(''.join(row).rstrip() for row in self.buf)

def main():
    steps = sys.argv[1:] or [""]
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.environ["XYZZYHOME"] = HOME
        os.environ["LANG"] = "en_US.UTF-8"
        os.execv(EXE, [EXE] + ARGS)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    scr = Screen()
    raw = bytearray()

    def drain(quiet=0.6, total=25.0):
        end = time.time() + total
        last = time.time()
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.15)
            if r:
                try: data = os.read(fd, 65536)
                except OSError: return False
                if not data: return False
                if RAW: raw.extend(data)
                scr.feed(data); last = time.time()
            elif time.time() - last > quiet:
                return True
        return True

    # Wait for the first paint rather than for the output to go quiet: nothing
    # is drawn while lisp/ loads, and that takes long enough on a slow machine
    # that "quiet for 1.5s" is reached before the screen exists at all.
    booted = False
    deadline = time.time() + BOOT
    while time.time() < deadline:
        alive = drain(quiet=0.5, total=2.0)
        if scr.dump().strip():
            booted = True
            drain(quiet=1.0, total=10.0)   # let the first screen settle
            break
        if not alive:                      # the child closed the pty: it is gone
            break
    if not booted:
        # Say so rather than dumping a blank screen and carrying on: every step
        # after this would be typed at a process that never came up.
        st = "exited" if os.waitpid(pid, os.WNOHANG)[0] else "still running"
        print("=== startup: nothing was drawn within %gs (child %s) ==="
              % (BOOT, st))
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
        if RAW:
            print("=== raw after %r ===" % step)
            print(repr(bytes(raw)))
            del raw[:]
    # Cancel whatever prompt the last step may have left open: otherwise the
    # keys below get typed into it instead of running the command.
    os.write(fd, b'\x07\x07')      # C-g C-g
    drain(quiet=0.3, total=5)
    os.write(fd, b'\x1bx')          # M-x
    drain()
    os.write(fd, b'kill-xyzzy\r')
    drain(quiet=0.4, total=5)
    try: os.close(fd)
    except OSError: pass
    # ChildProcessError: the start up check above may already have reaped it.
    try: os.waitpid(pid, 0)
    except (ChildProcessError, OSError): pass

main()
