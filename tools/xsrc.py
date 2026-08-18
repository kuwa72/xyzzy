#!/usr/bin/env python3
"""Read and convert the CP932 (Shift_JIS) sources.  Driven by tools/x.

    show PATH [FIRST[,LAST]]   print as UTF-8 with line numbers
    grep PATTERN [PATH...]     search; the pattern may be UTF-8 Japanese
    utf8 PATH...               rewrite as UTF-8 (so a text editor can be used)
    sjis PATH...               rewrite as CP932 (undo the above)
    check-encoding [PATH...]   verify the files still decode as CP932

A second byte of 0x5C in a double byte character is a backslash in any tool that
does not know the encoding, which is why everything goes through here.
"""
import os
import re
import sys

ENC = 'cp932'
DEFAULT_DIRS = ['src', 'unittest', 'lisp', 'misc']
SOURCE_SUFFIXES = ('.cc', '.h', '.d', '.rc', '.l', '.cpp', '.c')


def die(msg):
    sys.stderr.write('xsrc: %s\n' % msg)
    raise SystemExit(2)


def decode(data):
    return data.decode(ENC, errors='replace')


def collect(paths):
    """Expand directories into the source files below them."""
    out = []
    for path in paths:
        if os.path.isdir(path):
            for dirpath, _, names in os.walk(path):
                for name in sorted(names):
                    if name.endswith(SOURCE_SUFFIXES):
                        out.append(os.path.join(dirpath, name))
        else:
            out.append(path)
    return out


def cmd_show(args):
    if not args:
        die('show needs a path')
    path, rng = args[0], (args[1] if len(args) > 1 else None)
    lines = decode(open(path, 'rb').read()).splitlines()
    first, last = 1, len(lines)
    if rng:
        m = re.match(r'^(\d+)(?:[,:-](\d+))?$', rng)
        if not m:
            die('bad line range %r' % rng)
        first = int(m.group(1))
        last = int(m.group(2)) if m.group(2) else first
    width = len(str(min(last, len(lines))))
    for n in range(max(first, 1), min(last, len(lines)) + 1):
        print('%*d\t%s' % (width, n, lines[n - 1]))


def cmd_grep(args):
    if not args:
        die('grep needs a pattern')
    pattern, paths = args[0], (args[1:] or DEFAULT_DIRS)
    try:
        needle = re.compile(pattern.encode(ENC))
    except UnicodeEncodeError:
        die('pattern is not representable in CP932')
    hits = 0
    for path in collect(paths):
        try:
            data = open(path, 'rb').read()
        except OSError:
            continue
        if not needle.search(data):
            continue
        for n, line in enumerate(data.splitlines(), 1):
            if needle.search(line):
                hits += 1
                print('%s:%d:%s' % (path, n, decode(line)))
    if not hits:
        print('(no match)')
        return 1
    return 0


def convert(paths, src, dst, label):
    for path in collect(paths):
        data = open(path, 'rb').read()
        try:
            text = data.decode(src)
        except UnicodeDecodeError as e:
            die('%s: not %s (%s)' % (path, src, e))
        open(path, 'wb').write(text.encode(dst))
        print('%s -> %s: %s' % (src, label, path))


def cmd_check(args):
    bad = 0
    for path in collect(args or DEFAULT_DIRS):
        data = open(path, 'rb').read()
        try:
            data.decode(ENC)
        except UnicodeDecodeError as e:
            bad += 1
            print('NOT CP932: %s (%s)' % (path, e))
    if bad:
        return 1
    print('all files decode as CP932')
    return 0


def main(argv):
    if not argv:
        die(__doc__)
    cmd, args = argv[0], argv[1:]
    if cmd == 'show':
        return cmd_show(args) or 0
    if cmd == 'grep':
        return cmd_grep(args)
    if cmd == 'utf8':
        if not args:
            die('utf8 needs a path')
        return convert(args, ENC, 'utf-8', 'utf-8') or 0
    if cmd == 'sjis':
        if not args:
            die('sjis needs a path')
        return convert(args, 'utf-8', ENC, 'cp932') or 0
    if cmd == 'check-encoding':
        return cmd_check(args)
    die('unknown command %r' % cmd)


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
