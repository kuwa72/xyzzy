#!/usr/bin/env python3
"""LSP E2Eテスト用のfake言語サーバー (unittest/lsp-e2e-tests.l の相手)。

stdioでLanguage Server Protocolを話す最小実装。実サーバー (clangd等) は
CIのWindowsイメージに無いので、起動・送受信の経路検証はこのfakeで行う。

    python3 tools/fake-lsp-server.py --log <path> [--content-type]

受信した通知を --log へ1行ずつ追記する:

    initialized
    didOpen <uri>
    didChange <uri>
    didClose <uri>

応答する要求:

    initialize              -> definitionProvider 付き capabilities
    textDocument/definition -> 固定位置 (file:///fake-target.c の3行目)
    shutdown                -> null

didOpenを受けたら publishDiagnostics 通知を1件送る。exit通知で終了する。

--content-type を付けると応答ヘッダに Content-Type を足す。実サーバー
(clangd など) はこれを送るので、付けた形でも動くことをテストできる。
"""
import json
import sys


def read_message(buf_in):
    """1件分のLSPメッセージを読む。EOFならNone。"""
    header = b""
    while b"\r\n\r\n" not in header:
        chunk = buf_in.readline()
        if not chunk:
            return None
        header += chunk
    length = None
    for line in header.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1].strip())
    if length is None:
        raise ValueError("no Content-Length: %r" % (header,))
    body = b""
    while len(body) < length:
        chunk = buf_in.read(length - len(body))
        if not chunk:
            raise EOFError("truncated body")
        body += chunk
    return json.loads(body.decode("utf-8"))


def write_message(buf_out, obj, content_type=False):
    body = json.dumps(obj).encode("utf-8")
    buf_out.write(b"Content-Length: %d\r\n" % (len(body),))
    if content_type:
        # Real servers (clangd among them) send this.  A client that only
        # skips over the one header it expects stalls on the second line and
        # never sees the message at all, so the fake server has to be able to
        # emit it.
        buf_out.write(b"Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n")
    buf_out.write(b"\r\n")
    buf_out.write(body)
    buf_out.flush()


def log_line(log_path, line):
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def fake_target_location():
    return {
        "uri": "file:///fake-target.c",
        "range": {
            "start": {"line": 2, "character": 4},
            "end": {"line": 2, "character": 10},
        },
    }


def main(argv):
    log_path = None
    content_type = False
    for i, arg in enumerate(argv):
        if arg == "--log" and i + 1 < len(argv):
            log_path = argv[i + 1]
        elif arg == "--content-type":
            content_type = True

    buf_in = sys.stdin.buffer
    buf_out = sys.stdout.buffer
    shutdown_seen = False

    while True:
        try:
            msg = read_message(buf_in)
        except EOFError:
            break
        if msg is None:
            break
        msg_id = msg.get("id")
        method = msg.get("method")
        params = msg.get("params") or {}

        if method == "initialize":
            write_message(buf_out, {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"capabilities": {
                    "definitionProvider": True,
                    "textDocumentSync": 1,
                }},
            }, content_type)
        elif method == "initialized":
            if log_path:
                log_line(log_path, "initialized")
        elif method == "textDocument/didOpen":
            uri = ((params.get("textDocument") or {}).get("uri"))
            if log_path:
                log_line(log_path, "didOpen %s" % (uri,))
            write_message(buf_out, {
                "jsonrpc": "2.0",
                "method": "textDocument/publishDiagnostics",
                "params": {"uri": uri, "diagnostics": [{
                    "range": {"start": {"line": 0, "character": 0},
                              "end": {"line": 0, "character": 5}},
                    "severity": 1,
                    "message": "fake-diagnostic",
                }]},
            }, content_type)
        elif method == "textDocument/didChange":
            uri = ((params.get("textDocument") or {}).get("uri"))
            if log_path:
                log_line(log_path, "didChange %s" % (uri,))
        elif method == "textDocument/didClose":
            uri = ((params.get("textDocument") or {}).get("uri"))
            if log_path:
                log_line(log_path, "didClose %s" % (uri,))
        elif method == "textDocument/definition":
            write_message(buf_out, {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": fake_target_location(),
            }, content_type)
        elif method == "shutdown":
            shutdown_seen = True
            write_message(buf_out, {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": None,
            }, content_type)
        elif method == "exit":
            break
        elif msg_id is not None:
            write_message(buf_out, {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": "Method not found"},
            }, content_type)

    return 0 if shutdown_seen else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
