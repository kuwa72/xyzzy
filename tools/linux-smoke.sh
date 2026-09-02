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

# カーソルの居る所と点の居る所が同じであること。
#
# **字は点に入るので、カーソルが 1 行上に居ても画面は正しく見える。**
# それで、ルーラを既定で出すようにした時点 (issue #173) から
# 「入力位置とカーソルがずれる」状態が残っていた: カーソルを置く側は
# `w_rect.top` しか足しておらず、描く側は `w_rect.top + ルーラの行数` から
# 描いていた。桁の方も `w_flags` (そのウィンドウで明示的に上書きした分だけ)
# を見ていたので、**既定で出ている行番号を 0 桁として数え**、7 桁左に来ていた。
#
# 測り方は「dump の中でテキストが居る行と桁」と「pty-drive.py が出す
# `=== cursor 行,桁`」の突き合わせ。**数字を焼き付けない**のは、行番号の桁数も
# メニューバーの有無もここで測りたいことではないため。
#
# ルーラを消した状態も測る。**両方測らないと「ルーラの分を足す」と
# 「常に 1 足す」が区別できない。**
cursor_at () {   # cursor_at <log> <n>: n 番目の dump の "行 桁"
  awk -v n="$2" '/^=== cursor /{i++; if (i==n) {gsub(/[^0-9,]/,""); sub(/,/," "); print; exit}}' "$1"
}
text_at () {     # text_at <log> <n> <word>: n 番目の dump で word の直後の "行 桁"
  awk -v n="$2" -v w="$3" '
    /^=== (startup|after) /{i++; row=-1; next}
    /^=== cursor /{next}
    {if (i==n) {row++; c=index($0, w); if (c && row>=0 && !done) {print row, c-1+length(w); done=1; exit}}}' "$1"
}

# **消したルーラは戻してから終わる。** ここで消したまま終えると、次の
# チェックが「ルーラの無い画面」を測ることになる (実際にそう見える形で
# 1 度失敗させた)。設定として残るかどうかに依存しない書き方にする。
log=$build/smoke-cursor.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" 'abc' '\extoggle-ruler\r' '\extoggle-ruler\r' \
  >"$log" 2>&1 || true
# dump 2 = 'abc' を打った直後 (ルーラあり)、dump 3 = ルーラを消した後。
# dump 1 は起動直後、dump 4 は戻した後。
with_ruler=$(cursor_at "$log" 2);    with_ruler_text=$(text_at "$log" 2 abc)
without_ruler=$(cursor_at "$log" 3); without_ruler_text=$(text_at "$log" 3 abc)
if [ -n "$with_ruler_text" ] && [ "$with_ruler" = "$with_ruler_text" ] \
   && [ -n "$without_ruler_text" ] && [ "$without_ruler" = "$without_ruler_text" ]; then
  echo "smoke: カーソル位置 OK -- 点と同じ所に居る (ルーラあり $with_ruler / なし $without_ruler)"
else
  echo "smoke: カーソル位置 FAILED, see $log" >&2
  echo "-- ルーラあり: cursor=[$with_ruler] text=[$with_ruler_text]" >&2
  echo "-- ルーラなし: cursor=[$without_ruler] text=[$without_ruler_text]" >&2
  fail=1
fi

# クリックした所に点が入ること。**同じ数え方の逆写像**なので、カーソルと
# 同じ理由で壊れていた (1 行下・1 桁右に入っていた、issue #255)。
#
# SGR (1006) のマウス報告を生のバイト列で送る。桁と行は**1 起点**なので、
# 画面の行 2・桁 8 (メニューバー 0 / ルーラ 1 / テキスト 2、行番号 7 桁 +
# 左余白 1 桁) は `3;9`。そこは 1 行目の 1 桁目なので `(1 0)` が入るのが正しい。
log=$build/smoke-cursor-click.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" 'abc\rdef\rghi' \
  '\x1b[<0;9;3M\x1b[<0;9;3m' \
  '\e\e(list (current-line-number) (current-column))\r' \
  >"$log" 2>&1 || true
if grep -q '^(1 0)$' "$log"; then
  echo 'smoke: クリック位置 OK -- 1 行目の 1 桁目を押すと点がそこに入る'
else
  echo "smoke: クリック位置 FAILED, see $log" >&2
  grep -nE '^\([0-9-]+ [0-9-]+\)$' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# 横に流れたときのカーソルとルーラ。**画面より長い行で 2 つ壊れていた。**
#
#   * 横スクロールの幅も行番号の桁を数え損ねていて (同じ `w_flags`)、
#     **点が右端の外に出てから**流れる。外に出た `move` は失敗するので、
#     カーソルは前に描いた所 (画面の左下) に残る
#   * ルーラを `ncurses_reframe` より前に描いていたので、目盛が**1 回前の
#     位置**のまま。次の打鍵でようやく揃う
#
# 測るのは 2 つ。**どちらも「流れた桁数」を焼き付けない**:
#
#   カーソル  行末の `[EOF` の直前に居る (点はそこにある)
#   ルーラ    目盛の `+` が来ている桁のテキストが `0` か `5`。`+` はバッファの
#             5 の倍数の桁に付き、テキストは桁番号の下 1 桁を並べたものなので、
#             **流れた桁数がいくつでも成り立つ**。ずれていると成り立たない
#             (32 桁流れた状態で目盛が 0 から始まると、`+` の下は 7 や 2 になる)
log=$build/smoke-cursor-hscroll.txt
long_line=$(awk 'BEGIN{for (i = 0; i < 120; i++) printf "%d", i % 10}')
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" "$long_line" \
  >"$log" 2>&1 || true
hscroll_cursor=$(cursor_at "$log" 2)
hscroll_text=$(text_at "$log" 2 '[EOF')
# `[EOF` の直後ではなく直前が点なので、text_at の桁から `[EOF` の長さを引く。
hscroll_text=$(printf '%s\n' "$hscroll_text" | awk '{print $1, $2 - 4}')
ruler_ok=$(awk '
  /^=== (startup|after) /{i++; row=-1; next}
  /^=== cursor /{next}
  # 行 0 = メニューバー、行 1 = ルーラ、行 2 = テキストの 1 行目。
  {if (i==2) {row++; if (row==1) ruler=$0; if (row==2) text=$0}}
  END {
    if (ruler == "" || text == "") {print "no-rows"; exit}
    start = index(text, "x") + 1        # 行番号の区切り (ACS_VLINE) の右がテキスト
    if (start <= 1) {print "no-text"; exit}
    n = 0
    for (c = start; c <= length(text); c++)
      {
        if (substr(ruler, c, 1) != "+") continue
        d = substr(text, c, 1)
        if (d !~ /[0-9]/) continue
        n++
        if (d != "0" && d != "5") {print "mismatch at " c " (" d ")"; exit}
      }
    print (n >= 5) ? "ok" : "too-few(" n ")"   # 1 個も見ずに通らないようにする
  }' "$log")
if [ "$hscroll_cursor" = "$hscroll_text" ] && [ "$ruler_ok" = ok ]; then
  echo "smoke: 横スクロール OK -- カーソルは点に付いていて ($hscroll_cursor)、ルーラの目盛が揃っている"
else
  echo "smoke: 横スクロール FAILED, see $log" >&2
  echo "-- cursor=[$hscroll_cursor] text=[$hscroll_text] ruler=[$ruler_ok]" >&2
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

# 合図 (ベル)。**Lisp スイートからは測れない**: 音も画面の反転も返り値を持た
# ないし、スイートは全部 --batch なので curses が上がっていない。
#
# `ding` は `*visible-bell*` で 2 つに分かれる。**POSIX ではどちらの枝も
# 何もしていなかった** (issue #203): core が GDI を直に呼んでいて、
# `MessageBeep` / `GetWindowRect` / `LockWindowUpdate` / `GetDCEx` / `PatBlt` /
# `GdiFlush` / `ReleaseDC` の 7 つが platform.h の何もしないスタブだった。
# **検索が見つからないときもエラーのときも、合図が 1 つも出ていなかった。**
#
# 端末には両方ある: curses の `beep ()` が BEL (0x07) を出し、`flash ()` が
# 反転表示のモード (ESC[?5h / ESC[?5l) を出す。**それが端末へ実際に届いて
# いることを生のバイト列で見る** (XYZZY_PTY_RAW)。
#
# **step ごとの塊を分けて見る。** 全体を grep すると、将来ウィンドウタイトルを
# OSC で出すようにしたときに終端の BEL を拾ってしまい、鳴っていなくても通る
# ようになる (`refresh-title-bar` は端末側が未実装、issue #16)。
raw_block () {   # raw_block <log> <n>: n 番目の "=== raw after" の塊だけ出す
  awk -v n="$2" '
    /^=== raw after /{i++; inb=(i==n); next}
    /^=== /{inb=0}
    inb' "$1"
}

log=$build/smoke-bell.txt
XYZZY_PTY_RAW=1 XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(ding)\r' '\w' \
  '\e\e(progn (setq *visible-bell* t) (ding))\r' '\w' \
  >"$log" 2>&1 || true
# 塊 1 = (ding) の直後 (起動時の出力も含む)、塊 3 = *visible-bell* を立てた ding。
if raw_block "$log" 1 | grep -q 'x07' \
   && raw_block "$log" 3 | grep -q 'x1b\[?5h'; then
  echo 'smoke: ベル OK -- (ding) が BEL を出し、*visible-bell* で画面が反転する'
else
  echo "smoke: ベル FAILED, see $log" >&2
  echo "-- (ding) の塊に 0x07 があるか:" >&2
  raw_block "$log" 1 | grep -c 'x07' >&2 || true
  echo "-- *visible-bell* の塊に ESC[?5h があるか:" >&2
  raw_block "$log" 3 | grep -c 'x1b\[?5h' >&2 || true
  fail=1
fi

# ウィンドウ (タブ) のタイトル。**Lisp スイートからは測れない**: OSC は返り値を
# 持たず、--batch では出さない (stdout をテストが読んでいる)。生のバイト列で見る。
log=$build/smoke-title.txt
XYZZY_PTY_RAW=1 XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(find-file "/work/README.md")\r' '\w' \
  >"$log" 2>&1 || true
# **塊ごとに分けて見る。** 起動時の塊にはまだ *scratch* のタイトルしか無く、
# find-file の後の塊に初めてファイル名が出る -- 全体を grep すると
# 「バッファを切り替えてもタイトルが変わらない」を見逃す。
if raw_block "$log" 1 | grep -q 'x1b\]0;.*scratch' \
   && raw_block "$log" 2 | grep -q 'x1b\]0;.*README\.md.*x1b' \
   && grep -q 'x1b\[22;0t' "$log"; then
  echo 'smoke: タイトル OK -- OSC 0 が出て、バッファを切り替えると中身が変わる'
else
  echo "smoke: タイトル FAILED, see $log" >&2
  echo "-- 起動時の塊に *scratch* のタイトルがあるか:" >&2
  raw_block "$log" 1 | grep -c 'x1b\]0;.*scratch' >&2 || true
  echo "-- find-file の後の塊に README.md のタイトルがあるか:" >&2
  raw_block "$log" 2 | grep -c 'x1b\]0;.*README\.md' >&2 || true
  echo "-- 起動時に CSI 22;0t (タイトルを積む) があるか:" >&2
  grep -c 'x1b\[22;0t' "$log" >&2 || true
  fail=1
fi

# 対話起動が ed::startup を通っているか。**batch では測れない。**
# `si:*command-line-args*' を積むのは対話版とバッチ版で別の場所で、対話版は
# 積んでいなかった (issue #217)。テストスイートは全部 --batch なので、
# ここが対話版の起動オプションを見る唯一の場所。
#
# 3 つ同時に見る: 引数のファイルが開いたか / `~/.xyzzy' が読まれたか /
# `init-pseudo-frame' が走ったか。HOME を差し替えるので、この端末が
# ほんとうに使っている ~/.xyzzy は触らない。
log=$build/smoke-startup.txt
home=$build/smoke-home
rm -rf "$home"
mkdir -p "$home"
printf '(setq ed::*smoke-dotxyzzy* :loaded)\n' >"$home/.xyzzy"
HOME=$home XYZZY_PTY_ARGS=$root/README.md XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(list (buffer-name (selected-buffer)) (and (boundp (quote ed::*smoke-dotxyzzy*)) ed::*smoke-dotxyzzy*) (length ed::*pseudo-frame-list*))\r' '\w' \
  >"$log" 2>&1 || true
if grep -q '("README\.md" :loaded 1)' "$log"; then
  echo 'smoke: 対話起動 OK -- 引数のファイルが開き、~/.xyzzy が読まれ、フレームが 1 つある'
else
  echo "smoke: 対話起動 FAILED, see $log" >&2
  echo '-- 期待するのは ("README.md" :loaded 1)。出ていたのは:' >&2
  grep -o '(".*)' "$log" | tail -3 >&2 || true
  fail=1
fi
# ダンプイメージ。**書けても読めなければ意味が無いので、両方を 1 本で測る。**
# `-image` を渡すと、読めなければ startup.l が作り、次からそれで起きる
# (issue #219)。POSIX では誰もこれを測っていなかった -- 書く側は前から
# 動いていて、読む側が繋がっていなかった。
image=$build/smoke-dump.wxp
rm -f "$image"
log=$build/smoke-dump.txt
{
  echo "--- 1 回目: イメージを作る ---"
  "$build/xyzzy" --batch -image "$image" -q \
    -e '(format t "made=~S dumped=~S path=~S~%" (and (file-exist-p (si:dump-image-path)) t) (xyzzy-dumped-p) (and (si:dump-image-path) t))'
  echo "--- 2 回目: それで起きる ---"
  "$build/xyzzy" --batch -image "$image" -q \
    -e '(format t "dumped=~S loadpath=~S sym=~S~%" (xyzzy-dumped-p) *load-pathname* (and (fboundp (quote ed::find-file)) t))'
} >"$log" 2>&1 || true
# 3 つ全部見る: 作れた / 2 回目はイメージから起きた / **そのうえで編集の
# 関数が生きている** (シンボルだけ戻っても関数が貼られていなければ使えない)。
if grep -q 'made=t dumped=nil path=t' "$log" \
   && grep -qi 'dumped=t loadpath=nil sym=t' "$log"; then
  echo 'smoke: ダンプイメージ OK -- 作って、それで起きて、関数が生きている'
else
  echo "smoke: ダンプイメージ FAILED, see $log" >&2
  cat "$log" >&2
  fail=1
fi

# **再ビルドした後の古いイメージが弾かれるか。** ヘッダの `dump_version` は
# `gen-syms` を走らせた時刻を焼いた定数で、CMake の依存は `gen-syms.cc` だけ
# なので**普通の再ビルドでは変わらない**。実行ファイルの大きさと更新時刻を
# ヘッダに入れて判定する (issue #219 の続き)。
#
# ここは exe をコピーして `touch` で測る -- **Lisp からは測れない**
# (走っている exe の更新時刻は変えられない)。
# **`$image` には触らない。** 下の対話のチェックがそれを使うので、ここで
# 消すと「イメージから起きたか」が nil になって落ちる (実際に踏んだ)。
log=$build/smoke-dump-ident.txt
ident=$build/smoke-dump-ident.wxp
copy=$build/smoke-xyzzy-copy
rm -f "$ident" "$copy"
{
  echo "--- 1) 本体でイメージを作る ---"
  "$build/xyzzy" --batch -image "$ident" -q -e '(princ :made)'
  echo
  echo "--- 2) 本体で読む (通るべき) ---"
  "$build/xyzzy" --batch -image "$ident" -q -e '(format t "A dumped=~S~%" (xyzzy-dumped-p))'
  echo "--- 3) 更新時刻を変えた別バイナリで読む (弾かれるべき) ---"
  cp -p "$build/xyzzy" "$copy"
  touch -d '2020-01-01 00:00:00' "$copy"
  "$copy" --batch -image "$ident" -q -e '(format t "B dumped=~S~%" (xyzzy-dumped-p))'
  echo "--- 4) 3 で作り直されたので、同じコピーなら通るべき ---"
  "$copy" --batch -image "$ident" -q -e '(format t "C dumped=~S~%" (xyzzy-dumped-p))'
  echo "--- 5) 本体で読む (今度は弾かれるべき) ---"
  "$build/xyzzy" --batch -image "$ident" -q -e '(format t "D dumped=~S~%" (xyzzy-dumped-p))'
} >"$log" 2>&1 || true
# **4 つ全部見る。** 「弾く」だけなら判定を常に false にしても通ってしまうし、
# 「通す」だけなら判定を消しても通る。両方向を見て初めて判定が効いている。
if grep -qi 'A dumped=t' "$log" && grep -qi 'B dumped=nil' "$log" \
   && grep -qi 'C dumped=t' "$log" && grep -qi 'D dumped=nil' "$log"; then
  echo 'smoke: イメージの同一性判定 OK -- 別バイナリのイメージは弾いて作り直す'
else
  echo "smoke: イメージの同一性判定 FAILED, see $log" >&2
  echo '-- 期待するのは A=t B=nil C=t D=nil。出ていたのは:' >&2
  grep -i 'dumped=' "$log" >&2 || true
  fail=1
fi
rm -f "$copy" "$ident"

# 対話でもイメージから起きて、引数のファイルを開けるか。**batch だけ通って
# 対話が通らない形が実際にあった** (issue #217 の si:*command-line-args*)。
log=$build/smoke-dump-pty.txt
XYZZY_PTY_ARGS="-image $image $root/README.md" XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(list (xyzzy-dumped-p) (buffer-name (selected-buffer)))\r' '\w' \
  >"$log" 2>&1 || true
if grep -q '(t "README\.md")' "$log"; then
  echo 'smoke: ダンプイメージ (対話) OK -- イメージから起きて引数のファイルが開く'
else
  echo "smoke: ダンプイメージ (対話) FAILED, see $log" >&2
  echo '-- 期待するのは (t "README.md")。出ていたのは:' >&2
  grep -o '(.*)' "$log" | tail -3 >&2 || true
  fail=1
fi
rm -f "$image"
# **既定でイメージを使う。** `-image` を渡さなくても設定ディレクトリの下の
# `xyzzy.wxp` を使い、無ければ作る (issue #219)。対話起動が 832ms -> 178ms。
#
# `HOME` を差し替える -- この端末がほんとうに使っている `~/xyzzy.wxp` は
# 触らない。3 つ見る: 1 回目は作る / 2 回目はそれから起きる /
# `-no-image` なら作らない。
log=$build/smoke-dump-default.txt
dhome=$build/smoke-dump-home
rm -rf "$dhome"
mkdir -p "$dhome"
{
  echo "--- 1) 1 回目: 作る ---"
  HOME=$dhome XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
    python3 "$root/tools/pty-drive.py" \
    '\w' '\e\e(list :first (xyzzy-dumped-p) (and (si:dump-image-path) t))\r' '\w'
  echo "--- image があるか ---"
  test -f "$dhome/xyzzy.wxp" && echo "IMAGE-CREATED" || echo "IMAGE-MISSING"
  echo "--- 2) 2 回目: それから起きる ---"
  HOME=$dhome XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
    python3 "$root/tools/pty-drive.py" \
    '\w' '\e\e(list :second (xyzzy-dumped-p))\r' '\w'
  echo "--- 3) -no-image なら使わない ---"
  rm -f "$dhome/xyzzy.wxp"
  HOME=$dhome XYZZY_EXE=$build/xyzzy XYZZYHOME=$root XYZZY_PTY_ARGS=-no-image \
    python3 "$root/tools/pty-drive.py" \
    '\w' '\e\e(list :noimage (xyzzy-dumped-p) (si:dump-image-path))\r' '\w'
  test -f "$dhome/xyzzy.wxp" && echo "NOIMAGE-CREATED-BUG" || echo "NOIMAGE-CLEAN"
} >"$log" 2>&1 || true
# **3 つ全部見る。** 「作る」だけなら既定オフでも通る余地があり、「使う」だけ
# なら作る側が壊れても気付かない。`-no-image` は逃げ道が本当に効くかを見る。
if grep -q '(:first nil t)' "$log" \
   && grep -q 'IMAGE-CREATED' "$log" \
   && grep -q '(:second t)' "$log" \
   && grep -q '(:noimage nil nil)' "$log" \
   && grep -q 'NOIMAGE-CLEAN' "$log"; then
  echo 'smoke: ダンプイメージの既定 OK -- 1 回目で作り、2 回目から使い、-no-image で切れる'
else
  echo "smoke: ダンプイメージの既定 FAILED, see $log" >&2
  grep -o '(:.*)' "$log" >&2 || true
  grep -o 'IMAGE-[A-Z]*\|NOIMAGE-[A-Z-]*' "$log" >&2 || true
  fail=1
fi
rm -rf "$dhome"
# **--batch の標準出力が UTF-8 で行末が LF か。** 既定は CP932 + CRLF で、
# Win32 の日本語コンソールでは正しいが POSIX では化ける (issue #229)。
#
# **対話の端末フロントエンドはこの経路を通らない**ので、上の「日本語 OK」は
# 通ったまま `--batch` だけ壊れていた。ここでしか測れない。
#
# 内部表現は壊れていなかった (char-code は正しい) ので、**バイト列で見る。**
log=$build/smoke-batch-utf8.txt
"$build/xyzzy" --batch -q \
  -e '(format t "X=~A~%" (map (quote string) (function code-char) (list 19981 27491)))' \
  >"$log" 2>&1 || true
# 不正 = U+4E0D U+6B63 -> UTF-8 で e4 b8 8d e6 ad a3
if grep -a '^X=' "$log" | od -An -tx1 | tr -d ' \n' | grep -q 'e4b88de6ada3'; then
  if grep -a '^X=' "$log" | od -An -c | tr -s ' ' | grep -q '\\r'; then
    echo "smoke: batch の UTF-8 FAILED -- 文字は合っているが CR が付いている, see $log" >&2
    fail=1
  else
    echo 'smoke: batch の標準出力 OK -- UTF-8 で行末が LF'
  fi
else
  echo "smoke: batch の UTF-8 FAILED, see $log" >&2
  echo '-- 期待するのは e4 b8 8d e6 ad a3 (不正)。出ていたのは:' >&2
  grep -a '^X=' "$log" | od -An -tx1 | head -2 >&2 || true
  fail=1
fi

# クリップボード (OSC 52)。**Lisp スイートからは片面しか測れない** --
# `unittest/clipboard-tests.l` が測るのは内部バッファの往復までで、
# 端末へ実際にシーケンスが出ているかは返り値を持たない。生のバイト列で見る。
#
# 2 つ同時に見る:
#
#   1. **stdout が端末のときは出る。** `osc52_copy` に
#      `!stdscr || !isatty` の guard を足した (それまで `--batch` でも書いて
#      いて、stdout を読んでいるテストのログにエスケープが混ざった)。guard を
#      広く取りすぎて**機能ごと止めてしまう**方向の壊し方があるので、出る側を
#      ここで押さえる。
#   2. **base64 の padding が `=` である。** `base64_encode` は長さが 3 の
#      倍数でないときに `=` を 1 つも出さず、**0 で埋めた分を `A` として
#      載せていた。** "不正 あいう" は UTF-8 で 16 バイトなので、貼った先には
#      NUL が 2 個付く。**16 バイトのような「3 で割り切れない」入力でないと
#      出ない**ので、ASCII 3 文字で測っても通ってしまう。
log=$build/smoke-clipboard.txt
XYZZY_PTY_RAW=1 XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(copy-to-clipboard "不正 あいう")\r' '\w' \
  >"$log" 2>&1 || true
# 不正 あいう = UTF-8 16 バイト -> base64 で 5LiN5q2jIOOBguOBhOOBhg==
if grep -q 'x1b\]52;c;5LiN5q2jIOOBguOBhOOBhg==' "$log"; then
  echo 'smoke: クリップボード OK -- OSC 52 が端末へ出て、base64 の padding が = になる'
else
  echo "smoke: クリップボード FAILED, see $log" >&2
  echo '-- 期待するのは x1b]52;c;5LiN5q2jIOOBguOBhOOBhg==。出ていたのは:' >&2
  grep -o 'x1b\]52;c;[A-Za-z0-9+/=]*' "$log" | head -3 >&2 || true
  fail=1
fi

# guard の裏側: **`--batch` では出ない。** 上の check だけだと「常に出す」形へ
# 戻しても通ってしまう。ここが落ちるのはテストスイートのログが汚れるのと同じ
# ことなので、そちらより先に分かるようにしておく。
log=$build/smoke-clipboard-batch.txt
"$build/xyzzy" --batch -q -e '(copy-to-clipboard "不正 あいう")' >"$log" 2>&1 || true
if grep -aq ']52;c;' "$log"; then
  echo "smoke: batch のクリップボード FAILED -- --batch の stdout に OSC 52 が出ている, see $log" >&2
  grep -ao ']52;c;[A-Za-z0-9+/=]*' "$log" | head -3 >&2 || true
  fail=1
else
  echo 'smoke: batch のクリップボード OK -- --batch の stdout に OSC 52 が出ない'
fi

# ポップアップ (`popup-list` / `popup-string`)。**端末フロントエンドで最も
# 大きい実装なのに、確認が 1 件も無かった** -- `ncurses-stubs.cc` の
# `Fpopup_list` が 275 行、`Fpopup_string` が 131 行で、`unittest/` と
# ここに名前が 1 度も出ていなかった (`popup-list` を数えた
# `unittest/popup-window-tests.l` は `lisp/popup-window.l` の段組みの方で、
# 別のもの)。
#
# **Lisp スイートからは測れない。** 描くものなので返り値を持たず、スイートは
# 全部 `--batch` で curses が上がっていない。
#
# **飾りではなく既定の経路である。** `lisp/startup.l` が端末で
# `*popup-completion-list-default*` を立てるので、`C-x C-f` の補完で候補が
# 複数あるとここが出る (`lisp/complete.l` の `popup-completion-list`)。
#
# 3 つ見る:
#
#   1. 枠が出ること (上下の罫線があり、長さが揃っている)
#   2. **20 桁の日本語の項目が切れずに枠に収まること。** 幅を「文字数」で
#      数えると全角が半分に見積もられ、**枠が狭いまま項目が切れる。**
#      項目を 20 桁にしてあるのは `inner_width` に 13 桁の下限があるためで、
#      10 桁 (5 文字) では文字数で数えても下限に吸われて差が出ない。
#
#      **上下の長さの比較だけでは足りない。** 幅を間違えると上下は
#      「揃ったまま一緒に縮む」ので、そこは枠が壊れていないことの確認に
#      過ぎない。**切れた項目の行を見るのが幅の確認である。**
#   3. **選んだ文字列がコールバックへ渡ること。** 描くだけ描けて選択が
#      効かない形があるので、画面だけ見ていても足りない
#
# **`tools/pty-drive.py` の画面モデルは全角を 1 桁として持つ** (`put` が
# `self.c += 1` を無条件でやる) ので、**日本語を含む行の「桁」を dump の
# 文字数から数えてはいけない。** ここが罫線 (ASCII) の長さと項目の行の
# grep だけを見ているのはそのため。
log=$build/smoke-popup-list.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' \
  '\e\e(progn (setq ed::*pg* nil) (popup-list (list "あいうえおかきくけこ" "beta") (function (lambda (s) (setq ed::*pg* s)))))\r' \
  '\w' '\r' '\w' \
  '\e\e(format nil "PG=[~A]" ed::*pg*)\r' '\w' \
  >"$log" 2>&1 || true
# 罫線は ACS なので、pty 側のモデルには l/q/k と m/q/j の文字で落ちてくる。
top=$(grep -o 'lq*k' "$log" | head -1)
bot=$(grep -o 'mq*j' "$log" | head -1)
if [ -n "$top" ] && [ "${#top}" = "${#bot}" ] \
   && grep -q 'xあいうえおかきくけこ *x' "$log" \
   && grep -q 'PG=\[あいうえおかきくけこ\]' "$log"; then
  echo 'smoke: popup-list OK -- 枠が出て、20 桁の日本語が切れず、選んだ文字列がコールバックへ渡る'
else
  echo "smoke: popup-list FAILED, see $log" >&2
  echo "-- 枠の上 '$top' (${#top} 桁) と下 '$bot' (${#bot} 桁):" >&2
  echo '-- 日本語の項目の行があるか:' >&2
  grep -c 'xあいうえおかきくけこ *x' "$log" >&2 || true
  echo '-- コールバックが受けた文字列 (PG=[...]):' >&2
  grep -o 'PG=\[[^]]*\]' "$log" | head -2 >&2 || true
  fail=1
fi

# `popup-string` は別の入口で、別の実装 (`lisp/calendar.l` の祝日と
# `lisp/edict.l` の辞書引きが使う)。**`popup-list` が通っても
# こちらは通らない**ので分けて見る。
log=$build/smoke-popup-string.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(popup-string "不正 abc" (point))\r' '\w' \
  >"$log" 2>&1 || true
top=$(grep -o 'lq*k' "$log" | head -1)
bot=$(grep -o 'mq*j' "$log" | head -1)
if [ -n "$top" ] && [ "${#top}" = "${#bot}" ] \
   && grep -q 'x 不正 abc x' "$log"; then
  echo 'smoke: popup-string OK -- 枠が出て、日本語混じりの文字列が桁で収まる'
else
  echo "smoke: popup-string FAILED, see $log" >&2
  echo "-- 枠の上 '$top' (${#top} 桁) と下 '$bot' (${#bot} 桁):" >&2
  echo '-- 中身の行があるか:' >&2
  grep -c 'x 不正 abc x' "$log" >&2 || true
  fail=1
fi

# メニュー (`call-menu` / `create-menu` / `add-menu-item` ほか 11 個)。
# **端末で実装があるのに測られていなかった** (#234)。メニューバーは常に描いて
# あるが、**開けるかどうかは別の話**で、そこを見るものが無かった。
#
# **`call-menu` は入った時点ではドロップダウンを開かない。**
# `run_menu_modal (lmenu)` の `initial_bar_sel` が -1 なので `drop_open = 0` で
# 始まり、RET / 下矢印 / C-n で開く。**ここを知らずに「F10 で何も出ない」と
# 読み違えた。**
#
# **開く前の状態は画面の dump では見えない。** メニューバーの選択は反転表示
# だけで、`tools/pty-drive.py` の画面モデルは属性を落とす (docstring にある)。
# だから「開いた後」を見る。
#
# 3 つ見る:
#
#   1. ドロップダウンの項目が出ること
#   2. **右寄せの割り当て表示が出ること** (`C-x 6 S`)。項目名だけ描けて
#      右の列が落ちる形がある
#   3. **C-f で隣のメニューへ移ること。** バーの移動が効かないと、
#      最初のメニュー以外へ到達できない
log=$build/smoke-menu.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(call-menu 0)\r' '\w' '\r' '\w' '\Cf' '\w' \
  >"$log" 2>&1 || true
if grep -q 'x 新規作成(N)' "$log" \
   && grep -q 'セッションの保存(W)\.\.\. *C-x 6 S' "$log" \
   && grep -q 'x 元に戻す(U)' "$log"; then
  echo 'smoke: メニュー OK -- ドロップダウンが開き、割り当てが右に出て、C-f で隣へ移る'
else
  echo "smoke: メニュー FAILED, see $log" >&2
  echo '-- ファイルメニューの項目があるか:' >&2
  grep -c 'x 新規作成(N)' "$log" >&2 || true
  echo '-- 右寄せの割り当て (C-x 6 S) があるか:' >&2
  grep -c 'セッションの保存(W)\.\.\. *C-x 6 S' "$log" >&2 || true
  echo '-- C-f の後に編集メニューの項目があるか:' >&2
  grep -c 'x 元に戻す(U)' "$log" >&2 || true
  fail=1
fi

# メニューから選んだものが**実際に走ること。** 描画とは別の経路である:
# `run_menu_modal` は選択を kbdq へ `LCHAR_MENU` として積んで戻り、
# コマンドループが `lookup_menu_command` で引き直して実行する。
# **開いて選べても、その積み直しが落ちていれば何も起きない。**
#
# 「新規作成(N)」を選ぶと `new-file` がファイル名を聞くので、ミニバッファに
# `File: ` が出る。**副作用がミニバッファのプロンプトだけ**なので後片付けが
# 要らない (最後に C-g で閉じる)。
log=$build/smoke-menu-invoke.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(call-menu 0)\r' '\w' '\r' '\w' '\Cn' '\w' '\r' '\w' '\Cg' '\w' \
  >"$log" 2>&1 || true
if grep -q '^File: ' "$log"; then
  echo 'smoke: メニューの実行 OK -- 選んだ項目のコマンドがコマンドループで走る'
else
  echo "smoke: メニューの実行 FAILED, see $log" >&2
  echo '-- new-file のプロンプト (File: ) が出ているか:' >&2
  grep -c '^File: ' "$log" >&2 || true
  tail -5 "$log" >&2
  fail=1
fi

# `--batch` でエラーが見えること (issue #236)。**エラーの行き先がどちらも
# 描かれないので、1 文字も出ず exit 0 になっていた** --
# `app.status_window` は画面を描く側が読むバッファで `--batch` では誰も読まず、
# 重要な側の `MsgBox` は `g_batch_mode` のとき既定のボタンを返すだけ。
# **スクリプトから見て、壊れているのに成功に見える形だった。**
#
# 2 つ見る。**片方だけでは足りない:**
#
#   1. stderr にエラーが出ること
#   2. **stdout には出ないこと。** `tools/bytecompile.sh` と
#      `misc/run-tests-batch.l` は stdout を読んでいるので、そこへ混ぜると
#      別のものが壊れる。「出るようにする」だけを測ると、stdout へ出す形に
#      してしまっても通る
out=$build/smoke-batch-err-out.txt
err=$build/smoke-batch-err-err.txt
"$build/xyzzy" --batch -q -e '(progn (format t "SMOKE-OUT~%") (car 1))' \
  >"$out" 2>"$err" || true
if grep -aq '不正なデータ型です' "$err" \
   && grep -aq '^SMOKE-OUT$' "$out" \
   && ! grep -aq '不正なデータ型です' "$out"; then
  echo 'smoke: batch のエラー OK -- stderr に出て、stdout には混ざらない'
else
  echo "smoke: batch のエラー FAILED, see $err / $out" >&2
  echo '-- stderr にエラーがあるか:' >&2
  grep -ac '不正なデータ型です' "$err" >&2 || true
  echo '-- stdout に SMOKE-OUT があるか / エラーが混ざっていないか:' >&2
  grep -ac '^SMOKE-OUT$' "$out" >&2 || true
  grep -ac '不正なデータ型です' "$out" >&2 || true
  fail=1
fi

# `buffer-selector` (#234)。**`--batch` からは測れない** -- ミニバッファで
# 聞くので、答える相手が要る。`unittest/frontend-entry-tests.l` に置けなかった
# 分がこれである。
#
# 2 つ見る:
#
#   1. プロンプトが出ること (「バッファの選択: 」)
#   2. **既定が `other-buffer` になっていて、RET でそれが返ること。**
#      返るのは名前の文字列ではなく**バッファそのもの** (`complete_read` に
#      `:buffer-name` を渡しているので変換される)。ここを名前で期待すると、
#      変換が落ちたときに通ってしまう
log=$build/smoke-buffer-selector.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(progn (get-buffer-create "ZZZTEST") nil)\r' '\w' \
  '\e\e(format nil "BS=[~A]" (buffer-selector))\r' '\w' '\r' '\w' \
  >"$log" 2>&1 || true
if grep -q 'バッファの選択: ' "$log" \
   && grep -q 'BS=\[#<buffer: ZZZTEST>\]' "$log"; then
  echo 'smoke: buffer-selector OK -- プロンプトが出て、既定の他バッファが返る'
else
  echo "smoke: buffer-selector FAILED, see $log" >&2
  echo '-- プロンプトが出ているか:' >&2
  grep -c 'バッファの選択: ' "$log" >&2 || true
  echo '-- 返り値 (BS=[...]):' >&2
  grep -o 'BS=\[[^]]*\]' "$log" | head -2 >&2 || true
  fail=1
fi

# `--batch` の終了コード (issue #236 の段取り 2)。**エラーが見えるように
# なっても、exit 0 のままではスクリプトは気付けない。**
#
# 3 つ見る。**「エラーで 1 になる」だけを測ると、常に 1 を返す形にしても
# 通る。**
#
#   1. 報告まで来たエラー -> 1 (誰も処理しなかったエラーなので run は失敗)
#   2. **正常な出力と警告 -> 0。** 警告は報告するが失敗ではない。
#      **1 つの run にまとめてある** -- 起動が cold な runner で 15 秒ほど
#      かかるので、分けると smoke の予算を食う (実際に 10 分の step timeout に
#      当たった)。どちらかが 1 を返せばこの run が 1 になるので、まとめても
#      落ちる側は変わらない
#   3. **後から走る `kill-xyzzy` が勝つ。** `misc/run-tests-batch.l` が自分で
#      pass/fail を返すので、ここを取り違えるとテストの結果が上書きされる
ec () {   # ec <lisp> : 終了コードだけを出す
  "$build/xyzzy" --batch -q -e "$1" >/dev/null 2>/dev/null && echo 0 || echo $?
}
e_err=$(ec '(car 1)')
e_ok=$(ec '(progn (warn "w") (format t "x~%"))')
e_kill=$(ec '(progn (setq ed::*post-startup-hook* (list (function (lambda () (kill-xyzzy t))))) (car 1))')
if [ "$e_err" = 1 ] && [ "$e_ok" = 0 ] && [ "$e_kill" = 0 ]; then
  echo 'smoke: batch の終了コード OK -- エラーで 1、正常と警告は 0、kill-xyzzy が勝つ'
else
  echo "smoke: batch の終了コード FAILED" >&2
  echo "-- エラー: $e_err (1 のはず) / 正常と警告: $e_ok (0) / kill-xyzzy: $e_kill (0)" >&2
  fail=1
fi

# `IsBadWritePtr` の記帳 (issue #240)。**保守的 GC がマップされていないページを
# 読まないための guard で、POSIX では `return FALSE;` のスタブだったので
# 一度も効いていなかった。**
#
# **Lisp からは測れない。** 述語が Lisp から呼べず、症状 (GC が `PROT_NONE` の
# ページを読んで落ちる) はスタックのゴミがちょうどそこを指す必要があるので、
# Lisp からは作れない。**述語そのものを C++ 側で測る** -- このリポジトリで
# 唯一の C++ のテストである (`src/core/mem-posix-test.cc`)。
# worker スレッドの shim (issue #223)。**tree-sitter の中から出したので、
# 出したことを verify する場所が要る** -- ts のテストは 14 件で、非同期の
# 経路を名指しで測っているものが 1 つも無い。**「ts が通ったから抽出は安全」
# とは言えない。** 4 操作 (起こす / 期限付きで待つ / 手放す / 譲る) と、
# **走っている最中に手放したとき本体が自分で片付ける (orphan)** を見る。
if [ -x "$build/worker-thread-test" ]; then
  if out=$("$build/worker-thread-test" 2>&1); then
    echo "smoke: worker スレッドの shim OK -- $out"
  else
    echo "smoke: worker スレッドの shim FAILED" >&2
    echo "$out" >&2
    fail=1
  fi
else
  echo "smoke: worker スレッドの shim FAILED -- $build/worker-thread-test が無い" >&2
  fail=1
fi

if [ -x "$build/mem-posix-test" ]; then
  if out=$("$build/mem-posix-test" 2>&1); then
    echo "smoke: IsBadWritePtr の記帳 OK -- $out"
  else
    echo "smoke: IsBadWritePtr の記帳 FAILED" >&2
    echo "$out" >&2
    fail=1
  fi
else
  echo "smoke: IsBadWritePtr の記帳 FAILED -- $build/mem-posix-test が無い" >&2
  fail=1
fi

# guard が空回りしていないこと。**予約したまま commit していないページが
# 実在するから guard に意味がある**ので、そこが無くなったら (例えば予約と
# 同時に全部 commit する形に変えたら) この check は「もう要らない」と言って
# いることになる。`---p` は `PROT_NONE` の mapping で、`alloc_page` が
# 64KB 予約して unit ごとに commit する形の副産物である。
log=$build/smoke-prot-none.txt
"$build/xyzzy" --batch -q -e '(progn
  (dotimes (i 200000) (list i i i))
  (with-open-file (s "/proc/self/maps")
    (let (l) (while (setq l (read-line s nil)) (format t "~A~%" l)))))' \
  >"$log" 2>&1 || true
n=$(grep -ac -- '---p' "$log" || true)
if [ "${n:-0}" -gt 0 ]; then
  echo "smoke: PROT_NONE のページが実在する OK -- $n 個 (guard が空回りしていない)"
else
  echo "smoke: PROT_NONE のページ FAILED -- 1 つも無い。guard が意味を失っている, see $log" >&2
  fail=1
fi

# ソケットの待ちを C-g で抜けられること (issue #242)。**`Fdo_events` が
# POSIX のフロントエンドで空実装なので、`posix_wait_ready` の C-g 検出は
# 何も見ていなかった。** 応答しないアドレスへ `connect` するとエディタが
# 固まって戻れなかった。
#
# **時間を測らない。** 「固まらないこと」は時間の性質で、閾値を置くと flaky に
# なる (PR #71 の教訓)。見るのは到達性だけ:
#
#   1. **C-g の後の eval が描かれる** (= 固まっていない)
#   2. **中断が `quit` として届く** (= C-g が実際に届いた)。
#      **これが無いと空回りする** -- `connect` が自分で戻ってきただけでも
#      1 は通ってしまう。`quit` の枝が走ったことが、C-g が効いた証拠になる
#
# **目印は実行時に組み立てる。** `\e\e` は打った式をそのまま画面へ出すので、
# 目印をソースにそのまま書くと、走っていない枝の文字列まで画面に出て grep が
# 当たる (最初にそれで通してしまった)。`concatenate` で繋いで、**結果として
# 出たときだけ一致する形**にする。
log=$build/smoke-socket-quit.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' \
  '\e\e(handler-case (connect "10.255.255.1" 80) (error (e) (concatenate (quote string) "SMOKE" "-CG-ERR")) (quit (e) (concatenate (quote string) "SMOKE" "-CG-QUIT")))\r' \
  '\w' '\Cg' '\w' \
  '\e\e(concatenate (quote string) "SMOKE" "-CG-ALIVE")\r' '\w' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-CG-QUIT' "$log" && grep -q 'SMOKE-CG-ALIVE' "$log"; then
  echo 'smoke: ソケットの待ちを C-g で抜ける OK -- quit が届き、その後も動く'
else
  echo "smoke: ソケットの待ちを C-g FAILED, see $log" >&2
  echo '-- 出た目印:' >&2
  grep -o 'SMOKE-CG-[A-Z]*' "$log" | sort -u >&2 || true
  echo '-- SMOKE-CG-ERR が出ていたら connect が自分で戻ったので、宛先を見直す' >&2
  fail=1
fi

# 名前解決の待ちを C-g で抜けられること (issue #223)。**遅い DNS で
# エディタが数秒固まり、C-g でも戻れなかった** -- `gethostbyname` を直に
# 呼んでいたので `poll_quit_char` を挟む隙が無かった。worker スレッドで
# 引いて、main は 100ms 刻みで C-g を見る形にした。
#
# **応答しないネームサーバを指さないと空回りする。** DNS が普通に動いている
# 所では、無い名前は NXDOMAIN で即座に返るので**待ちが発生しない。**
#
# **`/etc/resolv.conf` を書き換えるので、使い捨てのコンテナの中でしか
# やらない。** `tools/x smoke` は毎回新しいコンテナなので構わないが、
# **CI の runner と開発機では絶対に触ってはいけない** -- 同じ job の後ろの
# step や、その人の機械の DNS を壊す。**触れないときは黙って飛ばさず
# SKIPPED と言う** (「測っていない」と「通った」を混ぜないため)。
#
# つまり **CI ではこの 1 件だけ SKIPPED になる。** それでも置いてあるのは、
# `tools/x smoke` を回す開発者のところでは実際に測れるからである。
#
# 見るのはソケットの側と同じ 2 つ (時間は測らない):
#   1. C-g の後の eval が描かれる
#   2. **中断が `quit` として届く** (= 解決が自分で戻ったのではない)
#
# **60 秒のタイムアウト経路は測らない。** 測ると smoke が 1 分伸びるうえ、
# 遅い runner で閾値に触る形になる。**flaky にするより測らない方を選ぶ。**
log=$build/smoke-dns-quit.txt
if [ ! -f /.dockerenv ] || ! (echo "# smoke probe" >>/etc/resolv.conf) 2>/dev/null; then
  echo 'smoke: 名前解決の待ちを C-g SKIPPED -- 使い捨てのコンテナの中でないので /etc/resolv.conf を触らない'
else
  printf 'nameserver 10.255.255.1\noptions timeout:5 attempts:3\n' >/etc/resolv.conf
  XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
    python3 "$root/tools/pty-drive.py" \
    '\w' \
    '\e\e(handler-case (connect "slow.example.com" 80) (error (e) (concatenate (quote string) "SMOKE" "-DNS-ERR")) (quit (e) (concatenate (quote string) "SMOKE" "-DNS-QUIT")))\r' \
    '\w' '\Cg' '\w' \
    '\e\e(concatenate (quote string) "SMOKE" "-DNS-ALIVE")\r' '\w' \
    >"$log" 2>&1 || true
  if grep -q 'SMOKE-DNS-QUIT' "$log" && grep -q 'SMOKE-DNS-ALIVE' "$log"; then
    echo 'smoke: 名前解決の待ちを C-g で抜ける OK -- quit が届き、その後も動く'
  else
    echo "smoke: 名前解決の待ちを C-g FAILED, see $log" >&2
    echo '-- 出た目印:' >&2
    grep -o 'SMOKE-DNS-[A-Z]*' "$log" | sort -u >&2 || true
    echo '-- SMOKE-DNS-ERR なら解決が自分で戻った。resolv.conf の細工を見直す' >&2
    fail=1
  fi
fi

# 端末の貼り付け (bracketed paste、issue #241)。**囲みが無いと貼り付けと
# 打鍵が区別できず、自動インデント・自動ペア・electric が 1 文字ずつに
# 反応して、貼ったものと違うものが入る。**
#
# **この check は自分で差を作って見せる。** 同じテキストを 2 回送る:
#
#   1. `ESC[200~` … `ESC[201~` で囲む -> **4 桁のまま入る**
#   2. 囲まない (= 直す前と同じ経路) -> **6 桁になる**
#
# 2 が無いと空回りする -- c-mode が自動インデントしない設定になっただけでも
# 1 は通ってしまう。**負の確認が check の中に入っている形である。**
#
# 併せて `ESC[?2004h` が実際に出ていることを生のバイト列で見る。出さなければ
# 端末は囲んで送ってこないので、**中の処理が正しくても機能しない。**
log=$build/smoke-paste.txt
XYZZY_PTY_RAW=1 XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(c-mode)\r' '\w' \
  '\x1b[200~int f(int x) {\r  if (x) {\r    return 1;\r  }\r}\r\x1b[201~' '\w' \
  '\e\e(buffer-substring (point-min) (point-max))\r' '\w' \
  >"$log" 2>&1 || true
log2=$build/smoke-paste-unbracketed.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\w' '\e\e(c-mode)\r' '\w' \
  'int f(int x) {\r  if (x) {\r    return 1;\r  }\r}\r' '\w' \
  '\e\e(buffer-substring (point-min) (point-max))\r' '\w' \
  >"$log2" 2>&1 || true
# 4 桁のまま = 囲みが効いている。6 桁 = 1 文字ずつ流れて electric が働いた。
kept='return 1;'
if grep -q 'x1b\[?2004h' "$log" \
   && grep -q '"int f(int x) {.x0a  if (x) {.x0a    return 1;.x0a  }.x0a}.x0a"' "$log" \
   && grep -q '"int f(int x) {.x0a  if (x) {.x0a      return 1;.x0a  }.x0a}.x0a"' "$log2"; then
  echo 'smoke: 貼り付け OK -- 囲みがあれば 4 桁のまま、無ければ 6 桁になる (差が出ている)'
else
  echo "smoke: 貼り付け FAILED, see $log / $log2" >&2
  echo '-- ESC[?2004h を出しているか:' >&2
  grep -c 'x1b\[?2004h' "$log" >&2 || true
  echo '-- 囲んで送った結果 (4 桁のはず):' >&2
  grep -o '"int f(int x) {[^"]*"' "$log" | head -1 >&2 || true
  echo '-- 囲まずに送った結果 (6 桁のはず。同じなら差が出ていない):' >&2
  grep -o '"int f(int x) {[^"]*"' "$log2" | head -1 >&2 || true
  fail=1
fi

exit $fail
