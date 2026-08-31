#!/bin/bash
# Start the natively built POSIX binaries once and check that they come up.
#
#   tools/linux-smoke.sh [BUILD_DIR]     (default: _build/linux)
#
# The Linux build has no test suite of its own: misc/run-tests-batch.l wedges
# under it, and the known-failures baselines in misc/known-failures/ are written
# against the Windows builds.  So this is the entire runtime gate for it.
#
# It is deliberately more than "the exe exists".  A Linux build that compiles
# and links but cannot get through lisp/startup.l is the failure mode this has
# already caught once (user-config-path was left unbound outside Win32, and
# lisp/backup.l reads it at start up), and nothing about the build itself says
# so: the binaries appear, and only running one shows the library never loads.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build=${1:-$root/_build/linux}

for exe in xyzzy xyzzy-cli; do
  [ -x "$build/$exe" ] || {
    echo "linux-smoke.sh: $build/$exe not built" >&2; exit 2; }
done

# XYZZYHOME points the binaries at this tree's lisp/ rather than at whatever
# may be installed on the machine.
export XYZZYHOME=$root

fail=0

# xyzzy-ncurses in batch mode: loads lisp/startup.l (which loads the whole
# library) and then evaluates what -e hands it.  kill-xyzzy is how a batch run
# ends normally, so the exit code alone proves nothing -- the marker line does.
log=$build/smoke-ncurses.txt
"$build/xyzzy" --batch \
  -e '(progn (format t "SMOKE-NCURSES ~A~%" (lisp-implementation-version)) (kill-xyzzy))' \
  >"$log" 2>&1 || true
if grep -q '^SMOKE-NCURSES ' "$log"; then
  echo "smoke: ncurses batch OK -- $(grep '^SMOKE-NCURSES ' "$log")"
else
  echo "smoke: ncurses batch FAILED, see $log" >&2
  cat "$log" >&2
  fail=1
fi

# File operations, in the frontend that has the lisp library loaded.  Every
# call below reached a "return FALSE" stub in platform.h until the POSIX side
# was written (see src/core/vfs-posix.cc): copy-file copied nothing, and every
# file was dated 1601-01-01, which is what the "changed on disk since you read
# it" check was comparing against.  The equality against get-universal-time is
# the point -- a timestamp that merely exists was there before, and it was
# wrong by three centuries.
tmp=$build/smoke-fileops
rm -rf "$tmp" && mkdir -p "$tmp"
log=$build/smoke-fileops.txt
"$build/xyzzy" --batch -e "(progn
  (with-open-file (s \"$tmp/a.txt\" :direction :output :if-exists :supersede)
    (princ \"SMOKE\" s))
  (copy-file \"$tmp/a.txt\" \"$tmp/b.txt\" :if-exists :overwrite)
  (format t \"SMOKE-FILEOPS ~S ~S ~S~%\"
          (with-open-file (s \"$tmp/b.txt\") (read-line s nil))
          (< (abs (- (file-write-time \"$tmp/a.txt\") (get-universal-time))) 60)
          (equal (file-write-time \"$tmp/a.txt\") (file-write-time \"$tmp/b.txt\")))
  (kill-xyzzy))" >"$log" 2>&1 || true
if grep -qE '^SMOKE-FILEOPS "SMOKE" t t[[:space:]]*$' "$log"; then
  echo 'smoke: file operations OK -- copy-file copies, timestamps are this century'
else
  echo "smoke: file operations FAILED, see $log" >&2
  grep '^SMOKE-FILEOPS' "$log" >&2 || cat "$log" >&2
  fail=1
fi

# The mode line, drawn by the frontend from the % specifiers in
# mode-line-format.  Nothing in the lisp suite can see this: the suite runs on
# the Windows builds, and this is code that differs by platform.  It has already
# been wrong -- (const Char *)L"lf" is 16-bit-correct on Windows (wchar_t is 2
# bytes) and truncates to "l" on Linux (wchar_t is 4 bytes), so the terminal
# drew "[utf8n:l]" and neither the build nor the link said a word.  The check
# sets its own format instead of reading the default one, so that changing the
# default mode line cannot silently turn it off.  lisp/modeline.l rebuilds
# mode-line-format from *post-command-hook*, which would overwrite the format
# set here before it is ever drawn, so turn that off first (ignore-errors: the
# command does not exist on older trees).
log=$build/smoke-modeline.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(progn (ignore-errors (toggle-rich-modeline nil)) (setq mode-line-format "SMOKE-MODELINE[%k:%l][%*]") (update-mode-line t))\r' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-MODELINE\[utf8n:lf\]\[--\]' "$log"; then
  echo 'smoke: mode line OK -- % specifiers expand to their full strings'
else
  echo "smoke: mode line FAILED, see $log" >&2
  grep -n 'SMOKE-MODELINE' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# A prompt written right before a blocking read.  The command loop only paints
# between commands, so a command that writes with `message` and then waits for a
# key used to go into the wait undrawn: the prompt never reached the terminal
# (issue #66).  Anything that asks a question mid-command is on this path, so the
# failure reads as "the editor is not responding" rather than as a missing line.
log=$build/smoke-prompt.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(progn (message "SMOKE-PROMPT-VISIBLE") (read-char *keyboard*))\r' '\w' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-PROMPT-VISIBLE' "$log"; then
  echo 'smoke: mid-command prompt OK -- drawn before the read blocks'
else
  echo "smoke: mid-command prompt FAILED, see $log" >&2
  tail -20 "$log" >&2
  fail=1
fi

# Creating and destroying a window during a prefix key wait.  The layout grid
# (w_order) has to stay dense: deleting a window leaves the boundary number it
# used unreferenced, and the next split inserts a new boundary at that hole,
# where compute_geometry then read uninitialized alloca memory.  The result was
# a zero-height window that stayed *selected*, so **every following keystroke
# went to a window nobody could see and the screen stopped changing** (issue
# #83).  Nothing in the lisp suite can see it: the suite runs on the Windows
# builds, where the same sequence happens to survive.
#
# The check asks the editor for the height of the window it is left in rather
# than looking at the screen.  Reading the screen is what the bug reads like,
# but the dump depends on when the drain gives up, and that made the check
# flaky.  A zero-height selected window is the same defect and is a number.
#
# The expression *returns* the marker instead of calling `message': ESC ESC
# reports its own result with `message', so a message from inside is overwritten
# by "t" the moment the expression finishes.
#
# The hook only fires for C-x (char code 24), and tears down only while the
# temporary buffer is the selected one, so that the ESC ESC used to ask the
# question neither creates a second temporary window nor deletes a real one.
log=$build/smoke-prefix-window.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(setq *prefix-key-hook* (list (lambda (keymaps key) (if keymaps (when (eql (char-code key) 24) (pop-to-buffer (get-buffer-create "*T*") t)) (when (equal (buffer-name (selected-buffer)) "*T*") (delete-window) (delete-buffer (find-buffer "*T*")))))))\r\w' \
  '\Cx\w' '2\w' \
  '\e\e(format nil "SMOKE-PREFIX-WINDOW ~:[NG~;OK~] ~S" (and (> (window-lines) 4) t) (list (count-windows) (window-lines)))\r\w' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-PREFIX-WINDOW OK' "$log"; then
  echo 'smoke: window churn during a prefix key OK -- no zero-height window left'
else
  echo "smoke: window churn during a prefix key FAILED, see $log" >&2
  grep -n 'SMOKE-PREFIX-WINDOW' "$log" >&2 || tail -30 "$log" >&2
  fail=1
fi

# view-lossage (C-h l): 直近の打鍵を出す。**Lisp スイートからは測れない**
# (キーを打つ経路が無い) ので、ここで pty を叩く。
#
# `get-recent-keys` は ncurses-stubs.cc で nil を返すスタブだったので、
# *Help* が空のまま出ていた。**打鍵の履歴は Win32 側では入力キューの環状
# バッファを使い回しているが、端末側の fetch は端末から読んだ字を
# キューを経由せずに返す**ので、そこは空になる。別に小さな環を持たせた
# (src/frontend/ncurses/ncurses-kbd.cc)。
#
# **`peek` も記録すること**が要点だった。名前は peek だが字を消費するので、
# `fetch` だけ記録していると「まとめて届いた打鍵」と「ミニバッファに打った
# 字」が履歴から抜ける (`abc` を 1 回の書き込みで送ると `a` しか残らない)。
log=$build/smoke-lossage.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  'SMOKE' '\w' \
  '\e\e(map (quote list) (function char-code) (get-recent-keys))\r' '\w' \
  >"$log" 2>&1 || true
# S M O K E = 83 77 79 75 69。そのあとに ESC ESC ( ... が続く。
if grep -q '(83 77 79 75 69 27 27 40' "$log"; then
  echo 'smoke: view-lossage OK -- 打鍵の履歴が取れている'
else
  echo "smoke: view-lossage FAILED, see $log" >&2
  grep -n '^(' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# 走っている Lisp を C-g で止める (issue #162)。**Lisp スイートからは測れない**:
# 中断はキーを打つことで起き、スイートはキーを打てない。
#
# `quit-flag` を立てるのは Win32 の専用スレッド (RegisterHotKey) だけだったので、
# **端末では走り出した Lisp を止める手段が無く、暴走したらプロセスを殺すしか
# なかった。** `QUIT` から間引いて端末を覗くようにした (src/core/quit-poll.cc)。
#
# **止まったかどうかは画面ではなく戻り値で見る。** 中断されたら "Quit"、されな
# ければ経過ミリ秒が出る。待ち時間の比較で測ろうとすると、待ちに埋もれて区別が
# 付かない (実際にそれで一度分からなくなった)。
#
# 500000 回のループは手元で約 3.2 秒。C-g は RET の直後に送る。
log=$build/smoke-quit.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(let ((s (get-internal-real-time))) (dotimes (i 500000) nil) (- (get-internal-real-time) s))\r' \
  '\Cg' '\w' '\w' \
  >"$log" 2>&1 || true
if grep -q '^Quit' "$log"; then
  echo 'smoke: C-g で走っている Lisp が止まる OK'
else
  echo "smoke: C-g による中断 FAILED, see $log" >&2
  tail -5 "$log" >&2
  fail=1
fi

# キーボードマクロ。**記録も再生もできなかった** (issue #181):
#
#   C-x (   何も起きない (`start-save-kbd-macro` が nil を返すスタブ)
#   C-x )   「キーボードマクロは定義していません」
#   C-x e   e が挿入される
#
# **Lisp スイートからは測れない**: 打鍵を流す必要がある。記録中はモード行に
# `Def` が出る (`%M` の書式)。
log=$build/smoke-kbd-macro.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\Cx(' 'abc' '\w' '\Cx)' '\Cxe' '\w' \
  >"$log" 2>&1 || true
# 3 番目の dump が記録中 (Def が出ている)、最後が再生後 (abcabc)。
if grep -q ':Def' "$log" && grep -q 'abcabc' "$log"; then
  echo 'smoke: キーボードマクロ OK -- 記録中は Def が出て、C-x e で再生される'
else
  echo "smoke: キーボードマクロ FAILED, see $log" >&2
  grep -nE 'Def|abc' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# ファイル選択のダイアログ。**端末にダイアログは無いが、ミニバッファで聞く道が
# ある** (issue #187)。`return Qnil` のスタブだったので、
# `M-x open-file-dialog` / `save-as-dialog` / `save-kbd-macro-to-file` が
# 黙って何もしていなかった。
#
# 見るのは**戻り値の形**: Win32 側は 4 つの値 (ファイル名 / filter-index /
# エンコーディング / 改行コード) を返し、`:multiple t` のときは**リスト**で
# 返す。`open-file-dialog` が `(dolist (f files) ...)` と使うので、文字列を
# 返すと壊れる。
log=$build/smoke-file-dialog.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(multiple-value-list (file-name-dialog :title "テスト" :default "/tmp/zz.txt" :filter-index 3))\r' \
  '\w' '\r' '\w' \
  '\e\e(multiple-value-list (file-name-dialog :multiple t :default "/tmp/a /tmp/b"))\r' \
  '\w' '\r' '\w' \
  >"$log" 2>&1 || true
# 1 つ目: プロンプトに :title が出て、4 つの値が返る
# 2 つ目: :multiple t はリスト
if grep -q 'テスト:' "$log" \
   && grep -q '("/tmp/zz.txt" 3 nil nil)' "$log" \
   && grep -q '(("/tmp/a" "/tmp/b") 1 nil nil)' "$log"; then
  echo 'smoke: ファイル選択 OK -- ミニバッファで聞いて 4 つの値を返す'
else
  echo "smoke: ファイル選択 FAILED, see $log" >&2
  grep -nE 'テスト|tmp/zz|tmp/a' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# バッファを選ぶダイアログ。**ここも端末には同じ目的の道がある** — バッファ名の
# 補完付きで聞けばよい (issue #187 のファイル選択と同じ形)。`return Qnil` の
# スタブだったので `M-x select-buffer` が黙って何もしていなかった。
#
# 既定は「他のバッファ」。**今いるバッファを既定にしても何も起きない**ので、
# そこが既定になっていることも一緒に見る (RET だけで切り替わる)。
log=$build/smoke-buffer-selector.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(progn (create-new-buffer "zzz") nil)\r' '\w' \
  '\e\e(ed::select-buffer)\r' '\w' '\r' '\w' \
  '\e\e(buffer-name (selected-buffer))\r' '\w' \
  >"$log" 2>&1 || true
if grep -q 'バッファの選択:' "$log" && grep -q '"zzz"' "$log"; then
  echo 'smoke: バッファ選択 OK -- 補完付きで聞いて、既定が他のバッファ'
else
  echo "smoke: バッファ選択 FAILED, see $log" >&2
  grep -nE 'バッファの選択|zzz' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# 日本語のプロンプトとメッセージ。
#
# **端末のフロントエンドが `i2w` の 1 文字版を UTF-16 の値に使っていたので、
# 日本語が全部化けていた** (issue #179)。あれは移行前の内部エンコーディングから
# UTF-16 への表引きで、恒等なのは 65536 のうち 2178 個だけ:
#
#     (read-string "名前を入れて: ")   ->  琥悴筵噤燃黎:
#
# **バッファのテキストは正しく出る** (描画は src/core/glyph.cc の経路で `i2w` を
# 通らない) ので、画面を見ても気付きにくい。**プロンプトとメッセージボックスを
# 別に見る必要がある。**
log=$build/smoke-japanese.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(read-string "名前を入れて: ")\r' '\w' '\Cg' '\w' \
  '\Cx)' '\w' \
  >"$log" 2>&1 || true
# 1 つ目はミニバッファのプロンプト、2 つ目はメッセージボックス
# (`C-x )` をマクロの定義中でなく押すと「キーボードマクロは定義していません」)。
#
# **`C-x (` を先に押してはいけない。** 以前はマクロが動かなかったので
# `C-x ( x C-x )` でエラーが出たが、issue #181 で動くようになったので
# **エラーが出なくなる。** 定義していない状態で `C-x )` を押すだけでよい。
if grep -q '名前を入れて' "$log" \
   && grep -q 'キーボードマクロは定義していません' "$log"; then
  echo 'smoke: 日本語 OK -- プロンプトとメッセージボックスが化けていない'
else
  echo "smoke: 日本語 FAILED, see $log" >&2
  grep -nE '名前|マクロ|琥|染' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# インデントガイド。**Lisp スイートからは測れない**: glyph の中身を Lisp から
# 読む道が無いので、端末に何が出たかを見るしかない。
#
# 縦線は**行頭の空白を置き換える**だけなので、空行やインデントより浅い行には
# 出ない (置き換える文字が無い)。間隔はタブ幅に従う。
#
# 既定の字が `|` (ASCII) なのは、**端末と xyzzy の幅の解釈が一致するのが ASCII
# だけ**だから。`│` (U+2502) は xyzzy が East Asian Ambiguous として 2 桁に
# 数えるので (src/core/eaw.cc)、そのままでは桁がずれる。
log=$build/smoke-indent-guide.txt
sample=$build/indent-guide-sample.py
printf 'def foo():\n    if x:\n        bar()\n            deep()\nqux\n' > "$sample"
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  "\\e\\e(progn (find-file \"$sample\") (set-tab-columns 4) (refresh-screen t))\\r" '\w' \
  >"$log" 2>&1 || true
# 期待する見え方 (issue #173 で**既定の表示が Windows と揃った**ので、行番号と
# 区切りと改行の印が付く):
#
#       1|def foo():.
#       2||   if x:.
#       3||   |   bar().
#       4||   |   |   deep().
#       5|qux.
#
# **`|` と `.` の所は端末の代替文字集合 (ACS) の文字が出る。** pty-drive.py は
# ACS を訳さないので、区切りの縦線は `x` (ACS_VLINE)、改行の印は `j`
# (ACS_LRCORNER) という 1 文字として dump に現れる。数字の直後という位置で
# 見分けているので、`x` や `j` という字そのものとは混ざらない。
#
# **行番号の桁数を焼き付けない** (`^ +[0-9]+` で数える) のは、桁数が
# `LINENUM_COLUMNS` の話でここで測りたいことではないため。
if grep -qE '^ +[0-9]+x\|   \|   bar\(\)' "$log" \
   && grep -qE '^ +[0-9]+x\|   \|   \|   deep\(\)' "$log" \
   && grep -qE '^ +[0-9]+xdef foo\(\):' "$log"; then
  echo 'smoke: インデントガイド OK -- 行頭の空白が縦線になっている'
else
  echo "smoke: インデントガイド FAILED, see $log" >&2
  grep -n 'foo\|bar\|deep' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# 既定で出るもの。**上のガイドと同じ dump を使い回す。**
#
# 描く側は最初から全部あったのに、端末の `Window::w_default_flags` が
# `WF_INDENT_GUIDE` だけだったので**行番号も改行の印も既定で出ていなかった**
# (issue #173)。ここが無いと、既定を戻してしまっても誰も気付かない。
#
#   行番号      数字が行頭に出る
#   区切り      その右が ACS_VLINE (`x`) -- 以前は ACS_HLINE (`q`) で横線だった
#   改行の印    行末が ACS_LRCORNER (`j`)
#   EOF の印    最後に `[EOF]`
if grep -qE '^ +[0-9]+xqux' "$log" && grep -qE 'qux.*j' "$log" \
   && grep -q '\[EOF\]' "$log"; then
  echo 'smoke: 既定の表示 OK -- 行番号・縦の区切り・改行の印・EOF の印が出ている'
else
  echo "smoke: 既定の表示 FAILED, see $log" >&2
  grep -n 'qux\|EOF' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# ルーラ。テキスト領域の 1 行上に桁の目安を出す (issue #173)。
#
#         0----+----10---+----20---
#       1|def foo():.
#
# **テキストの 1 桁目と揃っていること**が要点で、それを見るために
# 「ルーラの `0` と 1 行目の `d` が同じ桁に来る」ことを測る。ずれる原因は
# 2 つあって、どちらも実際に踏んだ: 行番号の桁を飛ばし忘れる、
# `redraw_line` が glyph 列の先頭に置く空白 1 桁を数え忘れる。
ruler_col=$(awk '/^ *0----\+----10/ {print index($0, "0"); exit}' "$log")
text_col=$(awk '/^ *[0-9]+.def foo\(\):/ {print index($0, "def"); exit}' "$log")
if [ -n "$ruler_col" ] && [ "$ruler_col" = "$text_col" ]; then
  echo "smoke: ルーラ OK -- 0 桁目がテキストの 1 桁目と揃っている (桁 $ruler_col)"
else
  echo "smoke: ルーラ FAILED (ruler=$ruler_col text=$text_col), see $log" >&2
  grep -nE '^ *0----|def foo' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# xyzzy-cli links xyzzy-core alone and reads a REPL from stdin.  It exists as
# the core separation test: anything the core leaks that only the Win32
# frontend can satisfy shows up here as a link error or as a start up crash.
#
# The second expression is the filesystem: directory goes through WINFS
# (src/core/vfs.h), whose POSIX side is src/core/vfs-posix.cc.  When that side
# was still inside the ncurses frontend, this frontend got a WINFS that
# forwarded to the always-fail stubs in platform.h and could not list, open or
# create anything -- while still starting up and evaluating (+ 1 2) happily.
# Note that xyzzy-cli does not load lisp/, so only builtins are available here.
log=$build/smoke-cli.txt
printf '%s\n' \
  '(+ 1 2)' \
  "(if (> (length (directory \"$root/lisp/\")) 100) 424242 0)" \
  | "$build/xyzzy-cli" >"$log" 2>&1 || true
# The lisp streams write CRLF even here, so the result line ends "3\r".
if grep -qE '^> 3[[:space:]]*$' "$log" && grep -qE '^> 424242[[:space:]]*$' "$log"; then
  echo "smoke: cli REPL OK -- (+ 1 2) => 3, lisp/ listed through WINFS"
else
  echo "smoke: cli REPL FAILED, see $log" >&2
  cat "$log" >&2
  fail=1
fi

exit $fail
