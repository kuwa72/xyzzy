#!/usr/bin/env python3
"""WSL -> Windows xyzzy TCP debug client (PoC).

Windows側で  M-x wsl-debug-serve  を起動してから使う::

    tools/wsl-debug.py '(+ 1 2)' '(software-version)'
    echo '(+ 1 2)' | tools/wsl-debug.py
    tools/wsl-debug.py --token s3cr3t '(+ 1 2)'

1行1 S式を送り、1行1応答 (+OK ... / -ERR ...) を受け取る。
-i で対話 REPL になる。終了コードは -ERR が1件でもあれば 1。
"""
import argparse
import socket
import sys


def run(host, port, token, lines, timeout):
    fp = None
    sock = socket.create_connection((host, port), timeout=timeout)
    try:
        fp = sock.makefile("rwb")
        if token:
            fp.write(("AUTH %s\n" % token).encode("utf-8"))
            fp.flush()
            resp = fp.readline().decode("utf-8", "replace").rstrip("\r\n")
            print(resp)
            if resp.startswith("-ERR"):
                return 1
        failed = 0
        for line in lines:
            if not line.strip():
                continue
            fp.write((line.rstrip("\r\n") + "\n").encode("utf-8"))
            fp.flush()
            resp = fp.readline().decode("utf-8", "replace").rstrip("\r\n")
            print(resp)
            if resp.startswith("-ERR"):
                failed = 1
        return failed
    finally:
        try:
            if fp is not None:
                fp.close()
        finally:
            sock.close()


def main(argv=None):
    ap = argparse.ArgumentParser(description="xyzzy wsl-debug client")
    ap.add_argument("expr", nargs="*", help="Lisp forms to eval (else stdin)")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=11722)
    ap.add_argument("--token", default=None)
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("-i", "--interactive", action="store_true")
    args = ap.parse_args(argv)

    if args.interactive or not args.expr:
        if sys.stdin.isatty() and not args.expr:
            print("%s:%d (Ctrl-D to quit)" % (args.host, args.port))
        lines = (l.rstrip("\n") for l in sys.stdin)
        return run(args.host, args.port, args.token, lines, args.timeout)
    return run(args.host, args.port, args.token, args.expr, args.timeout)


if __name__ == "__main__":
    sys.exit(main())
