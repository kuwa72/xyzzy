xyzzy リリースノート

  * バージョン: (未リリース)
  * リリース日: (未リリース)
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

**素の xyzzy を、いまのエディタとして通用する初期状態にする回である。** #30 の
ロードマップに沿って、モダンな Emacs ディストリビューション (Doom / Prelude /
Crafted) が当たり前に持っている操作をひとつずつ入れた。`M-x` はファジー絞り込みに
なり、候補は縦に並んで右端に割り当てキーが出る。`(` を打てば閉じ括弧が入り、
`C-=` で選択範囲が意味のある単位で広がり、`M-↑` で行が動き、`Leader c s` で
シンボル一覧へ跳べる。**設定ファイルを書かなくても、はじめからこうなっている**
ことを目指した。

**この手の追加で怖いのは「既定の挙動を勝手に変えること」なので、そこは分けて
考えた。** 打鍵の意味が変わるもの (自動ペア挿入、`M-x` の絞り込み) は入れたが、
**ユーザのファイルを黙って書き換えるもの (保存時の整形、行末空白の削除) は
既定で無効にしてある**。`M-x format-buffer` は既定で使えるので、まず手で試して
気に入れば 1 行で有効にできる。セッション復元も同じ理由で既定は無効のままで、
代わりに文書化した (実装は元からあったが、既定オフかつ未文書で気づけなかった)。

**画面を見る手段を作ったことが、結果的に一番効いた。** Linux ビルドには Lisp
テストスイートが無く、`linux-smoke.sh` は「プロセスが起動する」ところまでしか
見ないので、**画面に何が描かれるかを確かめる方法が無かった**。pty に打鍵を
流して画面をテキストで吐く道具 (`tools/x pty`) を足したところ、縦型候補表示の
表示バグ 2 件と、Leader メニューがステータス行に出ない原因 (issue #66) が
その場で分かった。逆にその道具自身が VT のスクロール領域と REP を解釈して
いなかったために「エディタ側の描画バグ」に見えた場面もあり、**道具が嘘をつくと
調査そのものが狂う**ことを実際に踏んでいる。


変更
----

  * **`si:putenv` が POSIX で成功を返して何もしていなかったのを直した**
    (既知失敗 63 -> 60)。

    ```lisp
    (si:putenv "X" "1")   ; -> "1"  (成功を主張する)
    (si:getenv "X")       ; -> nil  ← 入っていない
    ```

    **POSIX の `putenv` は渡した文字列を複写せず、そのポインタを環境に置く。**
    `alloca` で積んだ文字列を渡していたので、関数から戻った時点で環境の中身が
    スタックの使い回しを指していた。`setenv` / `unsetenv` に直した (名前と値を
    別に取り、どちらも複写する)。

    **Win32 の `_wputenv` は複写するので、あちらのコードは正しい。**
    `platform.h` の `#define _putenv(s) putenv(s)` が問題で、**同じ名前で
    約束が違うものを別名にすると、呼ぶ側がスタックの文字列を渡して黙って
    壊れる。** 別名を外した。

    **`test-environ-*` を POSIX でも測れるようにした。** 突き合わせ相手が
    `cmd.exe /c set` だったので `env` を使う形にした (シェル自身が足す
    `_` / `PWD` / `SHLVL` は外す)。**この 2 件が POSIX で測れていれば putenv の
    壊れ方は捕まっていた** — 「外の目」を Windows 専用にすると、そこで守られる
    はずの性質が丸ごと測られなくなる。
  * **POSIX で `call-process` / `make-process` の `:environ` が効くように
    なった** (既知失敗 65 -> 63)。**それまで丸ごと無視していた**ので、
    子プロセスに環境変数を渡す手段が無かった。

    ```lisp
    (call-process "sh -c 'echo $HOME'" :environ '(("HOME" . "/tmp/fake")))  ; -> /tmp/fake
    (call-process "sh -c 'echo [${HOME-unset}]'" :environ '(("HOME" . nil))) ; -> [unset]
    ```

    値が nil の項はその名前を**消す**。指定した名前が既にあれば**差し替える**
    — 後ろに足すだけだと `execve` に同じ名前が 2 つ並び、どちらが効くかは
    処理系任せになる (実測で `env | grep -c '^HOME='` が 1 であることを確認)。
    指定しなかった分は親から継がれる (PATH など)。

    **配列は fork の前に組む。** 子の中で `setenv` を呼ぶ方が短いが、
    `setenv` は malloc するので、**fork した瞬間に別のスレッドが malloc の
    ロックを持っていると子が固まる。** xyzzy はスレッドを使う。子の中で
    呼んで良いのは async-signal-safe なものだけなので、親で組んで `execve`
    に渡す。

    これで #143 の残り 2 件 (`xyzzy-ini-path-XYZZYINIFILE` /
    `user-config-path-XYZZYCONFIGPATH`) も通り、**その群は空になった。**
    `unittest/ini-tests.l` に環境変数から ini の場所を渡すテストと、
    **起動オプションが環境変数に勝つ**テストを足した (順序は Win32 と同じで
    なければならない)。
  * **`tools/ci-wait.sh` が push 直後に「落ちた」と誤報するのを直した。**
    チェックがまだ 1 つも登録されていない窓で
    `gh pr checks --watch` を呼ぶと、待たずに
    `no checks reported on the '...' branch` で 1 を返す。**待ち時間 0 で
    「落ちたものがある」と出るので、CI を見に行って初めて分かる。**
    チェックが現れるまで待ってから `--watch` に入るようにした。
  * **`tools/x test` がテストの前にビルドするようになった。** `run-tests.sh` は
    ビルドしないので、**ソースを直したあとの `tools/x test` が古い exe を
    測って通ってしまっていた。**

    実際に踏んだ: `PRLOGFONT` を core へ移した変更で Windows のビルドが
    壊れていたのに、`tools/x test x86_64` が**前の exe で 1146 件 pass と
    報告し**、CI で初めて分かった。ninja は最新なら何もしないので、付けても
    遅くならない。ビルドが失敗したらテストは走らせない (古い exe を測ることに
    なるので、通ったという結果の方が害になる)。

    `docker_run` は既定で `exec` する (コンテナが `tools/x` を置き換える) ので、
    戻ってきてほしい呼び出しは `DOCKER_EXEC= docker_run ...` で呼ぶ形にした。
  * **POSIX ビルドが設定を読み書きするようになった** (issue #143、既知失敗
    70 -> 65)。**Linux ビルドはそれまで `xyzzy.ini` を一切読まず、書かず、
    `(xyzzy-ini-path)` は nil を返していた。**

    `read_conf` / `write_conf` は `ncurses-stubs.cc` と `cli-stubs.cc` で
    **0 を返す空実装**だった (17 個の overload が全部)。既知失敗リストには
    「レジストリと ini ファイルに依っている」と 1 行で片付けてあったが、
    **レジストリが要るのは別の話で、ini ファイルの方は移植できた。**

    **848 行あった `win32/conf.cc` のうち Win32 に触っていたのは
    `Get/WritePrivateProfileStringW` の 2 つだけ**で、残りは書式の処理
    (`long` の 10 進と 16 進、`int` の配列、`RECT`、`LOGFONTW`、
    `WINDOWPLACEMENT`) だった。その 2 つを書き (`src/core/ini-posix.cc`)、
    残りを core へ移した (`src/core/conf-io.cc`)。あちらに残したのは
    ウィンドウの位置 (モニタとタスクバーを見るもの) とレジストリからの移行で、
    どちらも本当に Win32 の話。

    **`PRLOGFONT` の定義を `src/core/conf.h` へ移した。** 印刷のフォントの
    記述だが中身は数と文字列だけで、`src/frontend/win32/print.h` にあったため
    `write_conf (..., const PRLOGFONT &)` を core へ移せなかった (欄を読むので
    前方宣言では足りない)。**フロントエンドのヘッダを core から見に行くのでは
    なく、共通のものを core に置く。**

    **書き込みは読んで差し替えて書き戻す。** キーの順も、他の節も、コメントも
    壊さない。INI は人が手で編集するファイルなので、書き換えのたびに並びが
    変わると差分が読めなくなる。**一時ファイルへ書いて rename する**ので、
    途中で落ちても元の ini が半端な状態で残らない。

    **`environ::load_geometry` / `save_geometry` から位置以外の設定を切り
    出した** (`load_settings` / `save_settings`)。端末に WINDOWPLACEMENT の
    意味は無いが、行番号の表示や折り返しの既定は端末でも意味がある。
    分かれていなかったので、**端末ビルドは 1 つも読めなかった。**

    設定の場所は Win32 と同じ優先順位で決める (`-config` / `XYZZYCONFIGPATH`
    → `-ini` / `XYZZYINIFILE` → `<ホーム>/xyzzy.ini`)。

    **`-config` と `-ini` は Lisp へ渡す引数から取り除く。** `estartup.l` の
    `process-command-line-1` に case が無いので、渡すと**ファイル名として
    `find-file` され、そこで起動が止まっていた** (実測)。Win32 の `init.cc`
    も同じ形で先頭から取り除いている。ただし `--batch` は跨ぐ必要がある:
    `test-self-command` が `<xyzzy> --batch -ini "path" -q -e "..."` の形で
    組むので、跨がないと後ろの `-ini` が見えない。

    **`-ini` の相対指定は絶対パスにする** (`WINFS::GetFullPathName`、Win32 の
    `init.cc` と同じ呼び出し)。途中で `chdir` すると同じ相対パスが別の
    ファイルを指してしまう。

    `unittest/ini-tests.l` に 5 件。**Win32 と POSIX で同じテストになる** —
    読む側の入口は別だが、上に載っている書式の処理は共通なので、ini を置いて
    設定が効くかを見れば両方測れる。観測に `default-fold-width` を使うのは
    **Lisp から見える ini 由来の設定がこれしか無い**ため。コメント・空行・
    大文字小文字を混ぜたものも読めることを見ている (ini は人が手で編集する)。

    残る 2 件 (`xyzzy-ini-path-XYZZYINIFILE` /
    `user-config-path-XYZZYCONFIGPATH`) は**環境変数を子プロセスへ渡す方の
    問題で、ini とは関係が無い。** 非 Win32 の `call-process` /
    `make-process` が `:environ` を丸ごと無視している。**`XYZZYINIFILE`
    自体は効く。**
  * **POSIX で「途中のディレクトリが無い」と「最後の名前が無い」を区別する
    ようにした** (既知失敗 71 -> 70)。

    ```
    /no/such/dir/zzz  -> path-not-found  (途中が無い)
    /tmp/zzz-nope     -> file-not-found  (最後だけ無い)
    ```

    Win32 はこれを `ERROR_PATH_NOT_FOUND` と `ERROR_FILE_NOT_FOUND` で分ける
    が、**POSIX の `ENOENT` は両方を指す**ので、POSIX ビルドでは前者も
    `file-not-found` になっていた。

    **`ENOENT` だけは番号から条件を決められない。** `file_error (int, lisp)`
    が**番号とパスの両方を持つ唯一の場所**なので、そこで親を stat して分けた
    (`refine_not_found`)。`file_error_condition` は番号しか見ないのでそこには
    書けない。1 か所で分けたので `chdir` だけでなく `open` や `delete-file`
    でも Win32 と同じ条件が付く。遡るのは 1 段だけ (親が無い理由まで辿る
    必要は無い。Win32 も `ERROR_PATH_NOT_FOUND` の 1 つで済ませている)。

    既知失敗リストには「区別するには自分で親を辿って確かめるしかない」と
    書いてあった。**そのとおりだったので、そうした。「しかない」で止めずに、
    その手が本当に取れないのかを見る。**
  * **POSIX で `directory` とパスの扱いを 3 つ直した** (既知失敗 76 -> 71)。
    どれも `misc/known-failures/linux.txt` が
    「`directory--*` は WIN32_FIND_DATA の属性 (FILE_ATTRIBUTE_*) をそのまま
    見ている」という理由で 5 件まとめて片付けていたものだが、**5 件のどれも
    属性を見ていなかった。** 測り直したら別々の 3 つの理由で、全部直せた。

    **`get-file-info` が nil を返すスタブだった** (`ncurses-stubs.cc`)。
    中身は `strict_get_file_data` を呼んで `make_file_info` に渡すだけで、
    その `WINFS::get_file_data` は非 Win32 でも stat で実装済み。
    `#ifdef _WIN32` の中にあっただけ。**`directory` の `:file-info t` は同じ
    `make_file_info` を通って動いていたので、同じ情報が片方の入口からだけ
    出ていた。**

    **`(directory dir :show-dots t)` が `./` と `../` を返さなかった。**
    Win32 の `FindFirstFile` はディレクトリのグロブでこの 2 つを返し、
    **弾くのは呼び出し側の仕事** (`glob.cc` の `DF_SHOW_DOTS`、
    `completion.cc`) なのに、`vfs-posix.cc` が `readdir` の段で先に落として
    いた。再帰で無限に潜る心配は無い (`glob.cc` はドットのときは再帰の枝に
    入らない)。

    **`(merge-pathnames "/work/etc" "c:/hoge")` が `"c:/work/etc"` を
    返していた。** ドライブの無い rooted パスに defaults のドライブを被せる
    のは Win32 では正しい (`\foo` は「カレントドライブの \foo」の意味) が、
    **POSIX には被せるドライブという概念が無いので、付いた `c:` は嘘**に
    なる。非 Win32 では `/` で始まればそれで完全とした。

    **属性を見ているという理由は、テストを読めば違うと分かるものだった**
    (`directory--absolute` は `merge-pathnames` に `c:/hoge` を渡している)。
    既知失敗の分類を書くときは、テストが実際に何を呼んでいるかを見る。
  * **文法エラーを見つけて色と下線を付ける `flymake` を追加した**
    (issue #137、`lisp/flymake.l`、`M-x flymake-check` / `Leader c c`)。
    #30「リアルタイム文法エラー / 警告表示」の 1 項目。

    **#30 にはこれを「表示だけの装飾 (overlay) が無いので待ち」と書いて
    あったが、確かめたら間違いだった。** `set-text-attribute` は
    `:underline` / `:foreground` / `:background` / `:prefix` を取り、
    **バッファを一切書き換えない** (実測: 属性を付けても
    `buffer-modified-p` は nil、`buffer-substring` も変わらない)。Avy が
    本当にできないのは「画面上の文字を**別の文字に差し替える**」ことで、
    flymake が要るのは「今ある文字に色と下線を**足す**」こと。**別物だった。**
    `diff.l` と `ispell.l` に前例もあった。

    実測 (gcc -fsyntax-only、端末フロントエンド、生のエスケープ列で確認):

    | 診断 | 出たもの |
    | --- | --- |
    | 3 行 11 桁 warning | `ESC[0;4m ESC[33m` + `undefined_thing ();` |
    | 4 行 7 桁 warning | `ESC[0;4m ESC[33m` + `unused;` |
    | 5 行 11 桁 error | `ESC[0;1;4m ESC[91m` + `x` |

    **桁が行末より後ろでも最後の 1 文字は塗る。** 「`;` が足りない」系の
    診断は行末の次の桁を指してくるので、素直に使うと塗る幅が 0 になって
    **何も出ない**。上の 3 件目 (`expected ';' before '}' token`) が最初は
    印を付けられておらず、生のエスケープ列を見て気づいた。

    **検査するのはディスク上のファイルではなく、今のバッファの中身。**
    保存済みの版を検査すると編集中はずっと古い結果が出続ける。一時ファイルへ
    書き出して渡し、**拡張子は保つ** (linter は拡張子で言語を決める)。

    **終了コードは見ない。** 文法エラーがあれば 0 以外で終わるのが普通なので、
    0 以外を失敗として捨てると診断が全部消える。起動できたかどうかだけを見る。

    **出力の解釈は `*default-process-encoding*`。** バッファのファイル入出力
    用のエンコーディングではない (読むのはファイルの内容ではなく子プロセスの
    出す文字列)。ここを間違えると gcc の出す `‘x’` が化ける。

    **既定は無効。** 保存のたびに外部プロセスが起動するのを望まない使い方と
    両立しないうえ、コマンド行が間違っていると黙ってノイズが出る
    (`M-x toggle-flymake` / `Leader t f`)。`formatter.l` の保存時整形と同じ判断。

    **出力の読み方はモードごとに選ぶ。** 緩い形 (`ファイル:行: 本文`) を常に
    試すと、gcc の出す `t.c: In function 'main':` のような行まで診断として
    拾ってしまう。名前はキーワード (`:gcc` / `:perl` / `:plain`) にした:
    `.xyzzy` から `'(plain)` と書くと読んだパッケージが editor でなければ
    別のシンボルになって一致しない。

    `unittest/flymake-tests.l` に 20 件。**本物の linter は使わない** —
    gcc も shellcheck も CI の Windows には無いので、あるものに頼ると
    「環境に無いから落ちた」が既知失敗に積まれる。出力の読み方は文字列を直に
    渡して見て、起動する経路だけ `echo` で確かめる (cmd.exe の内部コマンドにも
    sh の組み込みにもあるので、両方で同じテストになる)。**装飾がバッファを
    書き換えていないことを毎回見る** — そこが崩れると「エラーを表示したら
    ファイルが変わった」になり、いちばん困る壊れ方。
  * **`tools/x pty` で色と下線が見えるようにした** (`XYZZY_PTY_RAW=1`)。
    画面の模型は文字だけを追って SGR を捨てるので、**属性だけの変更は
    dump が同じままになり「何も起きていない」と読める。**
    `set-text-attribute` に載っているもの — tree-sitter の色分け、diff、
    ispell、calendar、そして flymake — が全部そう。期待する SGR を生の
    バイト列から grep する形にした。画面の模型に属性の面を足す方法もあるが、
    それはスクロール・挿入・削除の全部を写さないと嘘になる。

    ついでに **`XYZZY_PTY_ROWS` / `COLS` / `BOOT` がコンテナへ渡っていなかった**
    のを直した (`tools/x` の `docker run` に `-e` が無く、`pty-drive.py` の
    説明に書いてあるのに効かなかった)。
  * **POSIX ビルドで外部コマンドの引数が黙って落ちていたのを直した**
    (issue #138、`lisp/process.l`)。`M-x shell-command`、`M-x format-buffer`、
    grep、`execute-subprocess` が**全部**静かにおかしくなっていた。
    **コマンドは起動して終了コード 0 で返るので、気づけない。**

    `shell-command-line` が POSIX でコマンド行を `sh -c <cmd>` に包んでいた
    が、**非 Win32 の `call-process` / `make-process` は受け取った cmdline を
    自分で `execl ("/bin/sh", "sh", "-c", cmdline)` に渡している**
    (`ncurses-process.cc`)。二重になると外側の sh が
    `sh -c echo wrapped-ok` を「`sh` を `-c echo wrapped-ok` で起動する」と
    読むので、内側の sh はコマンドとして `echo` だけを受け取り、
    `wrapped-ok` は $0 に落ちる。実測で出力が "wrapped-ok" ではなく空行
    1 つだった。

    **被せる側 1 箇所を直した。** 呼び出し元 5 箇所を個別に直すより確実で、
    「POSIX の `call-process` は既にシェル越し」という事実と一致する。
    Win32 は事情が逆 (`call-process` が CreateProcess を直に呼ぶので呼ぶ側が
    包まなければならない) なので、そちらの分岐はそのまま。

    `unittest/shell-command-line-tests.l` に 3 件。**`echo` だけを使う**ので
    cmd.exe と sh の両方で同じテストになる。引数が残ること、2 つ以上でも
    残ること、そして**シェルを通っていること** — 引数を落とさない直し方と
    して「シェルを通さない」もありえるが、それをすると `M-x shell-command`
    が `ls | head` を受け取れなくなる。

    気づいたのは #137 (flymake) で `gcc -fsyntax-only "ファイル"` が
    `no input files` を返したため。**ファイル名の置換を疑ったが、置換は
    正しく、落ちていたのは 1 段外側だった。**
  * **選択中のウィンドウを自動的に黄金比まで広げる `golden-ratio` を追加した**
    (`lisp/golden-ratio.l`、`M-x toggle-golden-ratio`、`Leader t g`)。
    #30「ゴールデンレシオ自動ウィンドウリサイズ」の 1 項目。

    分割して作業していると見ている側が狭くて読みにくいので、`C-x o` で移った
    先が毎回広がるようにした。実測 (26 行の端末で `C-x 2`): 既定では
    12 対 14、入れると **18 対 8**。

    **既定は無効。** 打鍵ごとにレイアウトが動くのは好みが分かれるうえ、
    「自分で調整した分割を勝手に戻される」形になるので、明示的に入れる形に
    した (セッション復元 #78 と同じ判断)。

    実装は `enlarge-window` に任せ、**幅と高さの両方を試して、変えられなかった
    方は黙って諦める。** 横に並んでいるウィンドウの高さは画面の高さと同じで
    変えようがなく、縦に積んである方の幅も同じなので、**「どちらの向きに
    分割されているか」を自分で判定するより、両方試して失敗を捨てる方が短い**
    (`enlarge-window` は変えられないとエラーを上げる)。

    候補一覧のような一時ウィンドウは除外する
    (`*golden-ratio-exclude-buffer-names*`)。**出した側が大きさを決めている
    ものへ割り込むと、出た瞬間に引き伸ばして候補が読めなくなる。**

    `unittest/golden-ratio-tests.l` に 5 件。**「広げた結果の行数」を期待値に
    書かない** — 画面の大きさが環境で違うので、数を書くとその環境でしか意味を
    持たない。「既定では動かない」「入れると選択中の方が広くなる」「1 つだけの
    ときは触らない」「除外リストでは触らない」を見る形にした。
  * **`si:load-dll-module` を POSIX でも実装した** (issue #133 の段階 1)。
    Linux の既知失敗が **73 件へ**。`dlopen` / `dlsym` / `dlclose` で足りるので
    **新しいライブラリには依存しない。**

    ```lisp
    (si:load-dll-module "libc.so.6")   ;=> #<DLL-module: libc.so.6>
    (si:load-dll-module "libnope.so")
    ;; => 共有ライブラリを読み込めません:
    ;;    "libnope.so: cannot open shared object file: No such file or directory"
    ```

    **`si:make-c-function` / `si:make-c-callable` はまだ無い。** 測ったところ
    `src/frontend/win32/dll.cc` の 1506 行のうち、**難しいのは「動的読み込み」
    ではなく「呼び出し」の方**だった: `LoadLibrary` / `GetProcAddress` は
    3 箇所で `dlopen` / `dlsym` に 1 対 1 で対応するが、呼び出し規約は
    手書きアセンブラ 3 ブロック + SEH で、x86_64 SysV と aarch64 AAPCS の
    それぞれに要る。**素直な方法は libffi だが、依存が増えるので判断を
    issue #133 に残した。**

    `platform.h` の `GetProcAddress` / `FreeLibrary` は 0 を返すスタブだったが、
    **引数がバイト列とハンドルだけなので、そのまま `dlsym` / `dlclose` に
    できた。** `LoadLibraryW` は名前が UTF-16 で来て変換器が core の後ろでしか
    使えないので、スタブのまま残してある。

    テスト側も直した。`"msvcrt"` と決め打ちしていた所を**候補から探す**形に
    した (`msvcrt` → `libc.so.6` → `libc.so` → `libSystem.dylib`)。読み時条件
    (`#+ncurses`) で分けるとバイトコンパイルしたビルドに引きずられるので、
    実行時に試す方を選んだ。

    **その作業で `unittest/typespec-tests.l` に encoding マーカーが無いことに
    引っかかった。** 日本語のコメントを足した瞬間にファイル全体が読めなくなり、
    そのファイルの 26 件が丸ごと走らなくなる。`CLAUDE.md` にある
    `no-lisp-file-has-non-ascii-without-an-encoding-marker` がその場で捕まえた
    ので、マーカーを足して直した。**この検査が無ければ「テストが減ったこと」に
    気付かないまま進んでいた。**
  * **`si:uuid-create` を POSIX でも実装した** (issue #50)。Linux の既知失敗が
    **76 件へ** (`uuid-create-*` 8 件)。

    Win32 は RPC の `UuidCreate` / `UuidCreateSequential` を呼ぶ。POSIX に
    対応するものは無いが、**RFC 4122 の中身は「乱数」(version 4) か
    「時刻 + 機械の識別子」(version 1) で、どちらも標準の手段で作れる。**

    **`libuuid` には依存しなかった。** `/dev/urandom` と `clock_gettime` で
    足りるので、**Linux ビルドの依存を ncurses と zlib だけに保った。**
    既知失敗リストには「`CoCreateGuid` には `uuid_generate` があるので移植
    できる余地がある」と書いてあったが、依存を増やさずに済む方を選んだ。

    `node` は RFC 4122 §4.5 が「MAC が取れないときは乱数にしてマルチキャスト
    ビットを立てる」と決めているのでそうした。**プロセスの間は変えない**ので
    「同じ機械の連番」という性質は保たれる (clock-seq も同じ)。同じ tick で
    2 回呼ばれたら時刻を 1 進めて、「時刻が戻らない」を満たす。

    ```
    v4       168cfdf0-dc28-4844-8f08-e522d22f27f7   (毎回違う)
    v1 1回目  cd78a996-a45f-11f1-acb2-b1378dace5f7
    v1 2回目  cd78ae64-a45f-11f1-acb2-b1378dace5f7   (node と clock-seq は同じ)
    ```
  * **`si:pack-*` / `si:unpack-*` が幅を素の型で書いていたのを直した**
    (issue #50)。Linux の既知失敗が **88 件へ**。**「FFI」の群に並んでいたが、
    FFI とは関係が無かった** — チャンク (バイト列) を読み書きするだけで
    DLL を触らない。

    ```lisp
    ;; 0xFFFFFFFF を pack して読み直す
    (si:unpack-int32 k 0)   ;=> 4294967295   (正: -1)
    ;; 全ビット 1 を pack して読み直す
    (si:unpack-uint64 k 0)  ;=> -1           (正: 18446744073709551615)
    ```

    バグは 2 つとも `long` の幅だった。ひとつ、**`unpack-int32` が `long` で
    読んでいた。** LP64 では 64bit なので**4 バイトの欄から 8 バイト読み**、
    32bit からの符号拡張も起きない。固定幅 (`int32_t` など) に直した。
    `char` も同じ理由で危ない — 符号の有無が処理系任せで、**Linux の ARM では
    符号無し**なので `unpack-int8` が負を返せなくなる (MSVC は常に符号付きな
    ので Windows では表に出ない)。

    ふたつ、**`make_integer (u_long)` が `int64_t` へ落としていた。** LP64 では
    `make_integer (uint64_t)` が `#if ULONG_MAX != UINT64_MAX` の中にあって
    **そもそもコンパイルされない**ので、**`LONG_MAX` を超える符号無し 64bit の
    値を一切作れなかった。**

    **直す途中で Windows を壊して、テストに捕まった。** 型を `u_long` から
    `uint32_t` に直した瞬間、LP64 では `uint32_t` が `u_int` になるので
    `make_integer (u_int)` に来る。そこが `make_fixnum` へ直に渡していて、
    `long` が 32bit の Windows では 0xFFFFFFFF が -1 になる。
    **片方を直してもう片方を壊す形**だったので、`u_long` 経由に変えた。
    **両アーキで走らせていなければ気付かなかった。**

    群の説明にも書き足した。**「群の名前を信じて中を見ないと、こういうものが
    混ざったまま残る。」**
  * **メニューを触る Lisp 関数 5 個とヘルパ 3 個も core に一本化した**
    (#16 Phase 4)。`set-menu` / `get-menu` / `get-menu-position` /
    `current-menu` / `use-local-menu` と、`check_popup_menu` /
    `find_tag_position` / `get_menu`。

    **一度「移せない」と判断して間違えた場所である。** 前の項の作業で
    「`win32_menu_p` などフロントエンド側のヘルパに依っているので別にする」と
    書いたが、測ったら違った:

    | 見立て | 実際 |
    | --- | --- |
    | `win32_menu_p` はフロントエンドのヘルパ | **core のマクロ** (`src/core/ed.h`) |
    | `check_popup_menu` はフロントエンドのヘルパ | **core で宣言済み。** 定義が 2 つあっただけ |
    | `find_tag_position` / `get_menu` は Win32 を触る | **core のアクセサしか触らない** |

    **名前に win32 と付いているだけで Win32 だと決めつけていた。** `HMENU` の
    値は `lwin32_menu` の中に入っているが、それを解釈するのはフロントエンド
    だけで、移した側は「ハンドルが立っているか」しか見ない。

    本当に足りないものが 1 つだけあった。`xwin32_menu_items` は**両フロント
    エンドがローカルに `#define xwin32_menu_items xwin32_menu_command` と
    書いていた。** 同じ枠が葉では「コマンド」、ポップアップでは「中の項目の
    リスト」という**二役**を持つ、という知識がその 1 行に埋まっていた。
    名前ごと core へ上げて、二役であることをコメントに書いた。
  * **`class Process` の共通部分を core の基底クラスに切り出し、残る
    プロセス関数 8 個も一本化した** (issue #127、#16 Phase 4)。これで
    プロセスを触る Lisp 関数は 19 個すべてが core にある。

    `class Process` は win32 と ncurses に別々に定義されていて、core には
    前方宣言しか無かった。**データメンバ 6 個は両方で同じ順で同じ、
    アクセサ 7 個は 1 文字も違わない。** 違うのは実体だけ (Win32 は
    スレッドとハンドル、POSIX は pid とパイプ) なので、共通部分を
    `src/core/process-base.h` の `ProcessBase` にした。

    `process-filter` / `set-process-filter` / `process-sentinel` /
    `set-process-sentinel` / `process-marker` / `signal-process` /
    `kill-process` / `process-send-string` が移り、
    `process_output_byte_stream` と `in_process_send_string` も 1 つになった。

    **`read_fd` / `term` / `poll_output` は基底に上げていない。** fd も
    `Terminal` も Win32 には対応する概念が無く、置くと基底がプラットフォームを
    知ることになる。呼ぶ側 (ncurses の 6 箇所) で `posix_process ()` を
    通して降ろす形にした。

    **メソッド名は `signal_proc` / `kill_proc` に揃えた。** win32 は
    `signal ()` / `kill ()` だったが、POSIX の `kill(2)` / `signal(3)` と
    衝突するのを避けて ncurses が `_proc` を付けており、**衝突しない方を
    採るのが筋。**

    見積もりを 1 度直している。issue には「`xprocess_data` の触点が 38 箇所」
    と書いたが、それは**出現回数であって直すべき箇所ではなかった。**
    分類したら win32 は 0 箇所 (代入と比較は暗黙変換で通り、
    `dynamic_cast<ConPtyProcess *>` も**基底が polymorphic なら通る**)、
    ncurses は 6 箇所だった。**測ってから設計した方が小さく済む。**
  * **プロセスを触る Lisp 関数 11 個を core に一本化した** (#16 Phase 4)。
    `buffer-process` / `process-buffer` / `process-command` /
    `process-status` / `process-exit-code` / `process-incode` /
    `process-outcode` / `set-process-incode` / `set-process-outcode` /
    `process-eol-code` / `set-process-eol-code`。

    読み書きしているのは `lprocess` の枠 (バッファ、コマンド行、状態、
    終了コード、入出力の文字コード、改行コード) だけで、**プロセスの実体
    (Win32 のスレッドとハンドル / POSIX の pid とパイプ) には触らない。**
    `process_char_encoding` と `process_io_encoding` も 1 文字も違わなかった
    ので一緒に移した。

    **`process_eol_code` だけは中身が違うので、フロントエンドの seam として
    残した。** 既定の改行コードが Win32 は CRLF、POSIX は LF になる —
    **この 5 行の関数がプラットフォームの違いそのもの**なので、core に上げて
    `#ifdef` で分けるより宣言で示す方が分かりやすい。

    **`Process` のメソッドを呼ぶ 6 個はまだ移せていない** (`filter` /
    `sentinel` / `marker` / `signal-process` / `kill-process` /
    `process-send-string`)。`class Process` が両フロントエンドに別々に定義
    されていて core に宣言が無く、共通部分を基底クラスに切り出す作業が先に
    要る。データメンバ 6 個とメソッド 7 個が 1 文字も違わないので切り出す形は
    見えているが、`xprocess_data` の触点が 38 箇所あるので issue #127 に
    分けた。
  * **`selected-window` と `enlarge-window` も core に一本化した**
    (#16 Phase 4)。前の項の 13 個は「1 文字も違わない」ので移せたが、この
    2 つは**中身が違っていた。理由を見たら、どちらも片方が間に合わせだった。**

    `selected-window` は win32 側が `assert` 2 つのあと
    `selected_window ()->lwp` を返していて、**選択中のウィンドウが無いときに
    ヌル参照になる。** 端末側は nil を返していた。**`assert` はリリース
    ビルドで消えるので、win32 側は実質何も守っていない。** 画面がまだ無い
    (端末の起動途中) / そもそも無い (ヘッドレスの CLI) 状態は実在するので、
    nil を返す方を採り、不変条件の検査はウィンドウが在るときだけ残した。

    `enlarge-window` は**端末側だけが `Window::enlarge_window` を実装せず、
    Lisp 関数の中に 80 行のジオメトリ計算を直に書いていた。** メソッドの
    宣言は `src/core/Window.h` に最初から在ったので、**seam が用意されて
    いるのに使っていなかった**ことになる。実装をメソッドへ移したら、
    Lisp 関数の側は win32 と同じ 5 行で済んだ。
  * **`si:*file-operation` を POSIX でも実装した** (issue #50)。Linux の既知
    失敗が **103 件から 88 件へ減った** (`shell-operation-*` 15 件)。

    Win32 版は `SHFileOperation` 1 本で済んでいる。POSIX にそれは無いが、
    **やっていることはファイルの複写・移動・削除**で、どれも core の関数が
    既に持っている。無いのは「進捗ダイアログ」「ごみ箱へ入れる undo」
    「上書きの確認」といった**見た目の部分だけ**なので、そこを落として中身を
    組み直した。

    **既知失敗の分類がまた間違っていた。** この 15 件は「Win32 API を直接
    呼ぶもの」の群に置いてあったが、**呼んでいる API が Win32 なだけで、
    やること自体は移植できる。** 群の説明に「名前が Win32 API だからではなく、
    その API がやっていること自体が POSIX に無いから残っている」ものだけを
    置くよう書き足した (`CoCreateGuid` には `uuid_generate` があるので
    `uuid-create` にはまだ余地があり、SEH とレジストリには無い)。

    **`shell-operation-move-multi` は Linux の方だけ走るようになった。**
    この 1 件は「`SHFileOperationW` の中で落ちる」ので Win32 では除外して
    ある。POSIX 版は落ちる先が無いので、除外を Win32 限定にした。
    **同じテストが、一方では実装のせいで走れず、他方では走る。**

    キーワード引数 (`:no-ui` / `:allow-undo` など) は受け取って無視する。
    POSIX に対応するものが無く、**呼ぶ側 (`lisp/filer.l` など) が同じ形で
    書けること**の方が大事だから。`:if-exists` を渡さないので上書きは
    既定の「エラーで止まる」になる。Win32 の `FOF_NOCONFIRMATION` が黙って
    上書きするのとは違うが、安全側に倒してある。

    途中で 1 つ踏んだので書いておく。**`Fcopy_file (from, to)` のように
    キーワード引数を省いて呼ぶと落ちる。** 既定引数が `0` で、
    `find_keyword` は `consp (list)` からループに入るので、ヌルポインタを
    cons として読む。`Qnil` を渡す。
  * **ウィンドウを触る Lisp 関数 13 個と `Window::coerce_to_window` を
    `src/core/window-lisp.cc` に一本化した** (#16 Phase 4)。

    どれも `src/frontend/win32/Window.cc` と
    `src/frontend/ncurses/ncurses-stubs.cc` に**空白を除いて 1 文字も違わない
    形で 2 つあった** (`split-window` / `delete-window` /
    `delete-other-windows` / `next-window` / `previous-window` /
    `get-buffer-window` / `set-window` / `window-buffer` /
    `window-coordinate` / `get-window-line` / `get-window-start-line` /
    `deleted-window-p` / `minibuffer-window-p`)。触るのは `Window` と
    `Buffer` — どちらも core のクラスで、GUI の資源は出てこない。

    **この形の複製が実際にバグを産んでいる。** 補完エンジンでは片方だけに
    スタック破壊が残り (issue #49)、片方だけが大文字小文字を無視していた
    (issue #111)。ミニバッファのプロンプトでは片方が nil を返すだけの
    スタブだった (issue #114)。**全部を測ったところ同じ形の複製が 34 個
    あったので、その最初の 13 個を潰した。** 差分は 19 行追加・269 行削除。

    フロントエンドに残るのは `Window` のメソッドの実装 (`split` /
    `delete_window` / `compute_geometry` など)。**宣言は core の `Window.h` に
    あるので core から呼べる。** 画面の実体を持っているのはフロントエンド
    だけなので、その境界は保っている。

    **作業中に、静的ライブラリならではの落とし穴を踏んだので書いておく。**
    `src/frontend/cli/cli-stubs.cc` に `Fget_buffer_window` が nil を返す
    スタブとして居た。core が実装を持つようになっても、**同じ名前が直接の
    オブジェクトにあると静的ライブラリの側は引かれないので、リンクは通るのに
    CLI だけが nil を返し続ける。** 消したところ今度は `Window` のメソッドが
    足りなくてリンクが落ちたので、CLI にも「無いものは無いと答える」
    スタブを置いた。**リンクが通ることは、実装が使われていることを意味しない。**
  * **エラー番号に「どの空間の番号か」を持たせた** (issue #120)。前の項で
    直した文言の件は、そこだけ塞いでも同じ事故が別の場所で起きる形だったので、
    設計から直した。

    番号の空間が 3 つあるのに、同じ整数の欄に裸で入っていた:

    | category | Win32 | POSIX |
    | --- | --- | --- |
    | `CRTL_ERROR` | errno | errno |
    | `WIN32_ERROR` | `GetLastError ()` の値 | **errno** |
    | `WSA_ERROR` (新) | `WSA*` | **errno** |

    **`WSA_ERROR` を足したのが要点。** それまでソケットのエラーは
    `WIN32_ERROR` として上がっていて、文言を選ぶ側は番号だけを見るので、
    POSIX でファイルの `ENOENT` (2) がソケットの表の `WSATRY_AGAIN` (2) に
    当たっていた。**番号だけを裸で持ち回ると空間をまたいで誤って当たる。**

    他の処理系を調べたところ、同じ結論に落ち着いていた。C++ の
    `std::error_code` は `value` + `category`、Python は PEP 3151 で `errno` と
    `winerror` を**別の属性**に分け、Rust は `ErrorKind` の裏に
    `raw_os_error ()` を残し、libuv は生の番号を `sys_errno_` に取っておく。
    APR は互いに素な番号の範囲に置いて出自が分かるようにしている。
    **番号だけを裸で持ち回っている実装は 1 つも無かった。** GNU Emacs だけが
    「errno に寄せて生の番号を捨てる」形だが、変換がラッパごとに散っていて
    中央に 1 か所が無い。

    xyzzy には `xerror_type` (category) と `file_error_condition`
    (番号 → 移植可能な Lisp の条件の写像、Rust の `decode_error_kind` 相当) が
    **既にあった**ので、新しい仕組みは足していない。3 つ直しただけである:

    ひとつ、`print_error` を category で分岐させた。ふたつ、
    `file_error_condition` を Win32 と POSIX で分け、POSIX の枝を errno で
    書いた。**ディレクトリでないものへ `chdir` すると `ENOTDIR` (20) が
    `ERROR_BAD_UNIT` (20) に当たって `bad-unit` になっていたのが
    `path-not-found` になる。** みっつ、番号を直に比べていた 13 箇所を
    「意味を聞く」述語 (`os_error_already_exists` など、`src/core/error.h`) に
    替えた。**`:if-access-denied` の再試行は `EACCES` (13) が
    `ERROR_ACCESS_DENIED` (5) に一致しないので POSIX で一度も走っていなかった。**

    **`ERROR_*` を errno の別名にする案は採らなかった。** それをやると
    `ERROR_FILE_NOT_FOUND` と `ERROR_PATH_NOT_FOUND` が両方 `ENOENT` になって
    `switch` の `case` が重複し、しかもソケットのエラーと同じ空間で完全に
    重なる。**enum にしても救われない**: 同じ値の enumerator は合法で無警告、
    網羅性の検査は名前ではなく値で効くので、別名にした 2 つを黙って 1 つとして
    飲み込む (実測で確認した)。

    Windows 側も 1 つ変わる。`ERROR_DIRECTORY` (ディレクトリ名として不正) に
    対応する `case` が無く `file-error` に落ちていたので、`path-not-found` を
    返すようにした。**同じ操作に同じ条件が付くようになる**(ファイルへ
    `chdir` したとき、両方で `path-not-found`)。

    `unittest/directory-ops-tests.l` に 1 件。**条件名を期待値に書けること
    自体が、番号の解釈が揃っている証拠になる** (文言は環境で変わるので
    別のテストで見ている)。
  * **POSIX ビルドでファイル操作のエラーの文言が全部でたらめだったのを
    直した** (issue #120)。

    | 操作 | 出ていた文言 |
    | --- | --- |
    | 無いファイルを開く | `Non-Authoritative; Host not found, or SERVERFAIL` |
    | 空でないディレクトリを消す | `Undocumented win32 error: 39` |
    | ファイルへ `chdir` | `Undocumented win32 error: 20` |

    非 Win32 の `GetLastError ()` は errno を返すが、それを Win32 のエラー
    コードとして引いていた。**1 つ目が DNS のエラーになるのは、ソケットの
    エラー表が先に引かれるため。** POSIX では `WSA*` 定数が errno そのものと
    して define されているので (`WSATRY_AGAIN` が 2、`ENOENT` も 2)、ファイルの
    エラーがソケットの表に当たる。2 つ目と 3 つ目は `FormatMessageW` が
    非 Win32 ではスタブで、番号をそのまま印字する経路に落ちるため。

    errno なら `strerror` が正しい文言を持っている。**ソケットのエラーも
    POSIX では errno なので、この 1 本で両方が正しくなる。**

    ```
    無いファイルを開く      → No such file or directory
    空でないディレクトリ削除 → Directory not empty
    ファイルへ chdir        → Not a directory
    ```

    **同じ食い違いで `create-directory` が既にあるディレクトリに対して
    エラーにならず `t` を返していた**のも直した (`EEXIST` の 17 が
    `ERROR_FILE_EXISTS` の 80 にも `ERROR_ALREADY_EXISTS` の 183 にも一致して
    いなかった。Windows では "File already exists." になる)。

    **番号の体系そのものを揃える話は #120 に分けた。** core にある `ERROR_*`
    との比較 38 箇所のうち 13 箇所が POSIX では絶対に一致せず、
    `:if-access-denied` の再試行は一度も走らない。`ERROR_*` を errno の別名に
    するのが素直だが、`switch` の `case` が重複するので機械的にはできない。

    ついでに既知失敗の「ファイル名とパス」群の理由を測り直した。**「`chdir` は
    ドライブごとのカレントディレクトリという Win32 の概念に依っている」と
    書いてあったが、それは違った。** `chdir` 自体は POSIX でも正しく動き、
    落ちているのはテストが `(get-windows-directory)` を行き先に使っていて、
    POSIX ではそれが nil を返すからである (`C:\Windows` に相当するものは
    無いので nil が正しい)。**実装の不足ではなくテストが Windows 前提。**
  * **テストが自分自身を子プロセスとして起動する経路を直した。** Linux の
    既知失敗が **132 件から 103 件へ減った** (issue #50)。コマンドライン引数を
    見る 26 件が丸ごと通るようになり、`kill-xyzzy-exit-code` も除外から
    外せた。

    子に `--batch` を付けていなかったので、**子が親と同じ tty で curses を
    初期化しようとして、どちらも進まなくなっていた** (結果ファイルが書かれず
    「result not sent.」、`call-process` は 1 を返す)。

    コマンド行を組む所が 2 つあったのを 1 つにした。`unittest/simple-test.l`
    の側は `xyzzy.exe` と決め打ちで **POSIX には当たらず**、CI では
    `misc/run-tests-batch.l` がその関数を丸ごと差し替えて回避していた。
    **差し替える側だけを直しても、対話的にテストを走らせたときには効かない。**
    `test-self-command` に寄せて、端末ビルドでだけ `--batch` を足すようにした。

    2 件は別の理由だった: `-e(view-mode)` と `-eval (view-mode)` は
    **括弧がシェルに食われていた。** POSIX では子プロセスを `/bin/sh -c` で
    起動するので `(` が構文エラーになる (cmd.exe はここでは括弧を特別扱い
    しないので Windows では通っていた)。同じファイルの他の指定は最初から
    `-e "..."` の形で引用符に囲まれていて、**この 2 つだけが漏れていた。**
    引用符はどちらのシェルも剥がすので、xyzzy が受け取る引数は変わらない。
  * **`long` が 64bit の環境で、fixnum の端の足し算・引き算・符号反転が
    bignum へ上がらず黙って巻き戻っていたのを直した** (issue #117)。

    ```lisp
    ;; Linux ネイティブビルド (most-positive-fixnum = 9223372036854775807)
    (+ most-positive-fixnum 1)   ;=> -9223372036854775808  (正: 9223372036854775808)
    (- most-negative-fixnum 1)   ;=>  9223372036854775807
    (abs most-negative-fixnum)   ;=> -9223372036854775808  (負の絶対値)
    ```

    **例外にもならず、符号だけ反転した値が返る。** Windows ビルドはどれも
    正しい。`src/num-arith.d` の足し算が `int64_t (x) + int64_t (y)` を
    計算する形で、**「オペランドが 32bit に収まるなら和は int64 に収まる」**
    ことを当てにしていた。`long` が 32bit の Windows (LLP64) ではそのとおり
    だが、64bit の LP64 では `long_int` が 2^63-1 まで持てるので溢れる。

    **掛け算のまったく同じ穴は前の版で直してある** (`(* (expt 2 32) (expt 2 32))`
    が 0 になっていた、issue #49)。そのとき `int64_multiply_overflows` を
    足したのに、**足し算・引き算・符号反転を見ていなかった。**
    同じ形の `int64_add_overflows` / `int64_subtract_overflows` を足し、
    符号反転は `INT64_MIN` だけを特別扱いした。

    `unittest/num-arith-tests.l` に 3 件。**期待値を数値で書いていない。**
    fixnum の幅がプラットフォームで違うので、数値で書くと片方でしか意味を
    持たない。「大小関係」と「既に正しいと分かっている掛け算との一致」で
    見る形にした。
  * **端末ビルドの `--batch` でウィンドウの大きさが失われていたのを直した。**
    Linux の既知失敗が **159 件から 132 件へ減った** (issue #50)。

    `--batch` では curses を上げないので `stdscr` が 0 になる。そこへ
    `compute_geometry` が `getmaxyx (stdscr, ...)` を直に呼んでいて、
    rows も cols も -1 になり、**`app.active_frame.size` が毎回 -1 に
    上書きされていた** (起動時に置いた 80x24 が消える)。その結果すべての
    ウィンドウの矩形が潰れ、`split-window` は「分割できません」、
    `window-height` は 1、`screen-height` は -1 を返していた。

    端末の大きさを取る所を 1 箇所 (`term_size`) にまとめ、curses が上がって
    いなければフレームの持っている大きさを使うようにした。**23 件が通るように
    なった** (`split-window` / `window-configuration` / `save-window-excursion` /
    `popup-window` / `winner` / `add-deleted-window-p` / `non-bmp-buffer-roundtrip`)。

    **これが効いたのは、既知失敗に書いてあった理由が間違っていたからである。**
    そこには「`--batch` には画面が無いから仕方ない」と書いてあった。画面が
    無いのは正しいが、**大きさが無いのは正しくない。** 27 件のうち 27 件が
    環境ではなく実装の問題だった。既知失敗リストの理由欄にこの教訓を残した。

    残った 4 件も環境ではなかった。3 件は `window-lines` が**モード行の 1 行を
    一律に引いていた**こと (`(window-lines (minibuffer-window))` が 1 少なく
    返る。**ミニバッファにモード行は無い**)。判定に `w_disp_flags &
    WDF_MODELINE` を使ってはいけないことも分かった: あれは「モード行を
    持つか」ではなく**「モード行を描き直す必要があるか」という再描画
    フラグ**で、描くたびに立って消える。1 件は `*current-pseudo-frame*` が
    nil のときに `next-pseudo-frame` / `previous-pseudo-frame` が
    `pseudo-frame-name` へ nil を渡して型エラーになること (端末ではタブバーが
    無く初期フレームが作られないので常にこの状態)。

    ついでに **`random-type` が Linux で 9% の確率で落ちる flaky だった**のも
    直した。上限が 10^20 で、fixnum の幅は `long` の幅なので
    **プラットフォームで変わる**: Windows (LLP64) は 2^31 なので 10^20 の
    乱数は必ず bignum になるが、Linux (LP64) は 2^63 ≈ 9.2×10^18 で、
    10^20 が fixnum に収まる確率が 1/10.8 ある (実測で 2000 回中 177 回)。
    **「Linux だけ落ちる」ように見えるので環境の違いに見えてしまう**種類の
    flaky で、上限を 10^40 にした。
  * **端末でプロンプト関数 15 個が何も聞かずに nil を返していたのを直した**
    (issue #114)。`read-string` / `read-file-name` / `completing-read` /
    `read-buffer-name` / `read-integer` / `read-sexp` ほか、
    `src/frontend/ncurses/ncurses-stubs.cc` に全部が `return Qnil;` で
    並んでいた。

    ```lisp
    (read-string "Name: ")   ; プロンプトが出ず、その場で nil
    ```

    **未実装だったのではない。** ミニバッファを読む土台 (`read_minibuffer`
    ほか 4 つ) は端末側にも実装済みで、**win32 側とシグネチャまで一致して
    いた。Lisp から呼べる形に繋いでいなかっただけである。** `C-x C-f` や
    `M-x` のプロンプトが端末でもちゃんと出ていたのはそのためで、
    `interactive` の指定は `src/core/eval.cc` が土台を直接呼ぶ。
    **Lisp から `read-string` を呼んだときだけ nil が返っていた。**

    **エラーではなく nil なので、呼んだ側は「空文字列を入力された」あるいは
    「取り消された」と解釈して静かに違うことをする。** `M-x set-variable` の
    「Value: 」、略称の展開 (`lisp/abbrev.l`)、ispell の「Replace with: 」、
    `M-x` 履歴の「Redo: 」などがこれを踏んでいた。

    包み 16 個を `src/core/minibuffer-read.cc` に移し、フロントエンドに残る
    seam を 4 つに絞った (`src/core/fns.h` に書いてある)。包みは
    「キーワード引数をほどいて土台を呼ぶ」だけで、プラットフォームに固有な
    ものは何も無い。

    **一緒に `minibuffer-buffer` の中身違いも直った。** core が返すべきなのは
    「そのミニバッファに入った時点で選ばれていたバッファ」で、端末側は
    「ミニバッファウィンドウに表示されているバッファ」= ミニバッファ自身を
    返し、引数も見ていなかった。`lisp/dabbrev.l` がミニバッファでの補完に
    これを使うので、**端末ではミニバッファ自身の文字しか候補にならなかった。**

    `unittest/minibuffer-read-tests.l` (17 件)。**プロンプトを出す関数は
    入力を待つのでバッチでは動かせないので、「引数を検査するか」を見る。**
    prompt に数を渡すと、繋がっていれば `type-error`、スタブなら黙って nil。
    「nil が返る」は呼んだ側から見て「空入力」と区別がつかないので、
    **この形でないと壊れていても誰も気付かない。** プロンプトが実際に出て
    値が返ることは pty で確かめた (端末の画面はスイートから触れない)。
  * **ミニバッファの補完エンジンを `src/core/completion.cc` に一本化した**
    (#16 Phase 4「core と frontend の境界分離」)。同じ 520 行が
    `src/frontend/win32/minibuf.cc` と `src/frontend/ncurses/ncurses-stubs.cc`
    の両方にあり、**片方だけが直っている状態が実際に何度も起きていた**。

    | 起きたこと | 影響 |
    | --- | --- |
    | `adjust_prefix` が `Char` (2 バイト) 分しか `alloca` していないのに ucs4_t (4 バイト) 単位で書いていた | 長いパスとマルチバイトの名前でスタックを壊す (issue #49) |
    | 突き合わせが大文字小文字を無視する決め打ちだった | POSIX で存在しないパスを返す (issue #111) |
    | ポート作業中の `displog` が 13 箇所残っていた | — |

    **補完はプラットフォームに依らない。** ファイルシステムを触る所はすべて
    WINFS (`src/core/vfs.h`) 越しで、シンボルとバッファは core のもの。
    固有なのは UNC (`//server/share`) の列挙だけで、そこだけ `#ifdef _WIN32`
    で囲んだ。**POSIX で外さなければならないのは「候補が出ない」からでは
    なく、`//usr/` のような普通のパスを UNC と誤判定して補完を止めて
    しまうから**である (POSIX では先頭の `//` は `/` と同じ意味)。結果として
    `//usr/` の補完が効くようになった。

    差分があった所はどちらを採ったかを `src/core/completion.cc` の冒頭に
    理由付きで書いた。ひとつだけ挙動が変わっているのは
    **「ディレクトリを開けなかったときに `file_error` を上げる」** で、
    写しの側は黙って「候補なし」を返していた。**「候補が無い」と「そこを
    読めない」は別のこと**で、後者を黙って捨てると理由が出ない。これが
    効くように WINFS の POSIX 実装が失敗時に必ず `errno` を立てるように
    した (非 Win32 では `GetLastError ()` が `errno` を返すので、errno に
    触らずに失敗を返すと**前の操作の errno が「この失敗の理由」として
    読まれる**)。
  * **POSIX ビルドのファイル名補完が、打った字の大文字小文字を書き換えて
    存在しないパスを返していたのを直した** (issue #111)。突き合わせが
    「区別しない」の決め打ちで、Win32 のファイルシステムは区別しないので
    正しいが、POSIX では違う。

    ```lisp
    ;; /work には README.md RELEASING.md reference/ がある
    (*do-completion "/work/RE" :exist-file-name)  ;=> "/work/re"  (実在しない)
    (*do-completion "/work/li" :exist-file-name)  ;=> "/work/LI"  (実在しない)
    ```

    3 つとも候補になり、共通前置の綴りが**最初に見つかった候補**のものになる。
    `readdir` の順はファイルシステム任せなので、**どちらに化けるかも一定
    しない。** 端末版で `C-x C-f` から補完するたびに踏むので、実害はテスト
    より大きい。

    区別するかどうかは**ファイルシステムの性質**であってフロントエンドの
    性質ではない (GUI 版と端末版で違ってはいけない) ので、判定を
    ファイルシステムの seam (`src/core/vfs.h` の
    `WINFS::case_insensitive_names`) に置いた。厳密には例外がある
    (macOS の既定は区別しない) が、それを本当に知るにはパスごとに
    問い合わせるしか無く、ここが目的にしているのは「打った字を勝手に
    書き換えない」ことなので、ビルド単位の既定で足りる。

    `unittest/completion-case-tests.l` (3 件)。**期待値をプラットフォームで
    書き分けていない。** 区別するかは実行時にファイルシステムへ聞いて
    (`Zz-alpha` を作ってから `zz-alpha` が見えるか)、補完の答えがそれと
    一致しているかだけを見る。**Wine の Z: ドライブは区別しない側なので、
    この形でないと「Wine で通るが Windows で通らない」を作りかねない。**
  * **POSIX ビルドで、`\` 区切りに直したパスがそのまま OS に渡っていたのを
    直した** (issue #109)。core のパス層は Win32 由来で、区切りを `\` に
    揃えてから WINFS を呼ぶ場所がある。Win32 では `/` も `\` も区切りなので
    害が無いが、**POSIX では `\` はファイル名に使える普通の文字**なので、
    パス全体が 1 個のディレクトリ名に化ける。実害が 3 つ出ていた。

    ひとつ、**カレントディレクトリにゴミが出来ていた。** このリポジトリの
    ワーキングツリーには `\home\kuwa72\.xyzzy.d\backup\home\...` のような、
    名前に `\` を含むフラットなディレクトリが 20 個溜まっていた。バックアップの
    置き場を作る経路がこれを踏む。`.gitignore` に載らないので `git status`
    にも出ず、**端末版で保存するたびに増えていた。**

    ふたつ、**多段の `create-directory` が何も作らずに `t` を返していた。**
    親を順に作るループが `\` を辿るので POSIX では 1 段も作れず、最後に
    「`\tmp\a\b` という名前のディレクトリ」を作って成功するため、成功が
    返る。失敗したことすら分からない。

    みっつ、**`(directory "/")` が nil を返し、`/` 直下のファイル名補完が
    効かなかった。** `FindFirstFile` の POSIX 実装がグロブから区切りを
    切り落として `opendir` するが、ルート直下は区切りが先頭の 1 個だけなので
    空文字列になり、必ず失敗する。

    直しは 3 つ。**WINFS の入口 (`os_path`) で `\` を `/` として受ける。**
    core のパス層はどのプラットフォームでも両方を区切りとして扱い、
    `(namestring "/tmp\\a\\b")` は `"/tmp/a/b"` を返す。つまり **xyzzy から
    見て「名前に `\` を含むファイル」は POSIX でも最初から到達できない**ので、
    境界を core と同じ解釈に揃えても失う機能は無い。加えて `mkdirhier` は
    区切りを書き換えず `/` と `\` の両方を区切りとして辿るようにし
    (保険があってもパスの方言が途中で変わるのは追いにくい)、
    `FindFirstFile` はルートで `"/"` を残すようにした。

    `unittest/directory-ops-tests.l` を追加した (4 件、Win32 / POSIX 両方で
    走る)。**ここに 1 件も無かったことが、3 つとも誰にも気付かれなかった
    理由である。** 「戻り値が t か」だけでなく「実体が出来ているか」と
    「ゴミが出来ていないか」を別々に見る形にしてある。前者だけを見る
    テストは、この壊れ方をすべて見逃す。
  * **端末フロントエンドで `*buffer-package*` がバッファローカルにならず、
    全バッファで共通になっていたのを直した** (issue #105)。あるバッファで
    `M-x set-buffer-package` すると他のバッファの package まで変わり、
    `text-mode` にしても元に戻らない。

    `lisp/startup.l` の `#+ncurses` の互換ブロックが **`defvar`** を使って
    いた。

    ```lisp
    #+ncurses
    (progn
      (defvar ed::*buffer-package* nil)
      (make-variable-buffer-local 'ed::*buffer-package*))
    ```

    **`defvar` はシンボルを special にし、special な変数はバッファローカルに
    なれない。** `set_globally` (`src/core/eval.cc`) は `SFspecial` を見ると
    バッファローカルの経路を通らずグローバルへ書くので、後から
    `make-variable-buffer-local` を呼んでも効かない。同じ変数を用意している
    `lisp/lispmode.l` は `setq-default` を使っており、そちらが正しい形だった。

    **効くかどうかが `.lc` を作ったビルドで変わる**という気持ちの悪い性質も
    あった。`#+ncurses` は読み込み時の条件なので、Windows ビルドが
    `startup.l` をバイトコンパイルするとこのブロックは `.lc` から消え、端末
    ビルドで作ると残る。**同じ `.lc` を両方のビルドで読む作り**なので、ここに
    副作用のある式を置くと再現性が落ちる。そのことをコメントに書き足した。

  * **端末フロントエンドで `documentation` が常に nil を返していたのを直した**
    (issue #105)。`M-x describe-function` が何も出さないのもこれ。

    `si:*get-documentation-string` が**空実装**だった
    (`src/frontend/ncurses/ncurses-stubs.cc`、`src/frontend/cli/cli-stubs.cc`)。
    docstring は `lisp::function-documentation` に文字列で入っているのに、
    **それを見る唯一の経路がここ**なので、`(documentation 'foo 'function)` は
    常に nil になっていた。

    Win32 側 (`src/frontend/win32/doc.cc`) はこの後にもう 1 段あり、property が
    文字列ではなく整数なら `etc/DOC` の中のオフセットとして mmap で読む。
    **端末側にその段は要らない**: `DOC` を書くのは `si:*snarf-documentation` で、
    それが POSIX では空実装なので、property が整数になることがない。組み込み
    関数の説明 (`(documentation 'car 'function)`) は `DOC` 由来なので nil の
    まま。

    Linux の Lisp スイートを CI に載せた (#49) ことで `redefun-docstring` が
    落ちるものとして見えるようになり、**理由が分からないまま
    `misc/known-failures/linux.txt` に置いてあった 4 件の 1 件目**がこれだった。
    直したので一覧から外した。

  * **64bit の `long` を持つ環境で bignum の計算が黙って間違っていたのを直した。**
    Linux ネイティブビルドで Lisp テストスイートを通せるようにした作業
    (issue #49) の途中で見つかった。**Windows では一度も表に出ていない。**

    ```lisp
    (* 4294967296 4294967296)   ; => 0                      正しくは 2^64
    (* 4294967296 (expt 2 64))  ; => 0                      正しくは 2^96
    (- (expt 2 64) 4294967296)  ; => 18446744073709551616    引かれていない
    ```

    原因は `src/core/bignum.cc` の `down` が結果を 16bit にマスクしていたこと。

    ```cpp
    static inline u_long
    down (u_long x)
    {
      return (x >> BR_SHIFT) & BR_MAX;      /* BR_SHIFT=16, BR_MAX=0xffff */
    }
    ```

    `u_long` が 32bit なら `x >> 16` の結果は必ず 16bit なので、**このマスクは
    何もしていない。** `long` が 64bit の環境 (LP64: Linux, macOS) では
    **bit 32 以上を全部捨てる。** 効いていたのは 2 とおりの使い方のうち片方
    だけで、桁上がりの取り出し (加減乗除のループ) では値が 2^32 に収まって
    いるので無害、しかし `u_long` を `u_short` の列へ分解する
    `bignum_rep_long::init` では **1 回目の `down` で値が消える。** その結果
    2^32 以上の `long` が bignum と混ざる演算すべてで 0 として扱われていた。
    マスクを外すと 32bit 環境の挙動は 1 ビットも変わらない。

    整数どうしの掛け算にも同種の穴があった (`src/num-arith.d`)。
    `int64_t (x) * int64_t (y)` を計算して `make_integer` へ渡す形で、これは
    「オペランドが 32bit に収まるなら積は int64 に収まる」ことを当てにして
    いた。LP64 では 2^32 が bignum ではなく long_int になるので**符号付きの
    溢れ (未定義動作) を踏んでいた。** 溢れを先に検査して bignum へ落とす。

    **PR #91 (`make-array` の上限が `LONG_MAX` を見ていた) と同じ族である。**
    `long` の幅を当てにしたコードは、Windows しかビルドしていない間は全部
    正しく見える。

  * **Linux ネイティブビルドで Lisp テストスイートが走るようになった**
    (issue #49)。`.github/workflows/linux.yml` に載せて、
    `misc/known-failures/linux.txt` で gate している。これまでこのジョブは
    **バイナリが起動することしか見ていなかった** (`tools/linux-smoke.sh`)。

    暴走 (メモリを食い潰す) 自体は #91 で直っていたが、**通してみたら 2 件
    落ちて止まっていた。**

    1. **`(xyzzy-ini-path)` を呼ぶとプロセスが落ちる。** ini ファイルの場所を
       決めるのは Win32 の `init_user_inifile_path` だけで、端末 / CLI では
       `app.ini_file_path` が 0 のまま。`make_string (0)` を渡していた。
       **Lisp から呼べる関数がプロセスを落としてはいけない**ので nil を返す。
    2. **ファイル名の補完がスタックを壊す。** 端末側の
       `completion::adjust_prefix` が `Char` (2 バイト) で領域を取って
       `ucs4_t` (4 バイト) で書き込んでいた。**必要な半分しか確保していない
       スタックへ書いていた。** 添字も `Char` 単位で進むので位置も合わない。
       Win32 側は `ucs4_t` へ移してあり、端末側に移す前のコードが残っていた。
       **テストだけの問題ではない**: 端末ビルドで長いパスのファイル名補完を
       すると同じことが起きる。短い名前だと `alloca` の余りに収まって表に
       出ないので、長いパスで初めて落ちる。

    そのうえで見えた 158 件を `linux.txt` に**理由ごとに分けて**並べた:
    FFI (37)、Win32 API (35)、パス (26)、コマンドライン引数 (25)、ウィンドウ
    (25)、OLE (2)、**理由不明 (4)**。最後の 4 件は「Windows では通るのに
    Linux では落ちる、プラットフォーム API とは関係なさそうなもの」で、
    **本物の移植バグである可能性がある**ことを明示して置いてある。

    ウィンドウ関係が丸ごと落ちるのは端末の実装不足ではなく、**`--batch` では
    curses を初期化しないのでフレームに大きさが無い**ためである
    (`split-window` が「分割できません」で失敗する)。Windows ビルドの
    xyzzy-batch は隠しウィンドウを持っているので通る。

    仕組みの側の直しも要った。`tools/run-tests.sh` と `tools/bytecompile.sh` に
    Wine を通さない経路を足し、**出力を行バッファにした** (ブロック
    バッファされると「N 秒出力が無ければ詰まった」という見張りが健全な run を
    殺す)。ログの集計に `grep -a` が要る (端末ビルドは `--batch` でも
    エスケープシーケンスを書くのでログがバイナリ扱いになり、`-a` 無しの
    `grep` は**何も一致しない** — 「Total N tests」の確認まで空振りして、
    完走した run が毎回「終わらなかった」と報告されていた)。既知失敗の
    名前に `#` を含むものが載せられなかったのも直した
    (`|fix (cdr '#1='#1#) printing|`)。

  * **コンテナにメモリの上限を付けた** (`tools/x`)。既定 8GiB、
    `XYZZY_DOCKER_MEMORY` で変えられる。上限が無いと、コンテナの中で暴走した
    ものがホストのメモリを取り切り、**WSL では VM ごと膨らんでホストが道連れに
    なる。** 実際に起きている (issue #49 の暴走は 12.65GiB まで伸びた)。
    `--init` も付けた: これが無いと中のプロセスが PID 1 になり、SIGTERM の
    既定動作が「無視」なので `docker stop` で止まらず、子プロセスも
    回収されない。

  * **ウィンドウを消してから分割すると配置が壊れるのを直した** (issue #83)。
    端末フロントエンドでは、プレフィックスキー (`C-x` など) の次のキーを
    待っている間に Lisp からウィンドウを出して消すと、**それ以降どのキーを
    打っても画面が変わらなくなっていた。**

    **原因は配置格子 (`w_order`) に空いた番号が残ることだった。**
    `compute_geometry` は各ウィンドウの `w_order` を添字にして境界の座標を
    配列へ書き込む。ウィンドウを消すと隣が `w_order` を吸うので、**消えた側の
    境界番号だけが誰にも参照されなくなり、その添字は書かれないまま**になる。
    配列は `alloca` なので、そこには前のスタックの中身が残っている。

    1 枚だけ残っている間は両端の 2 本しか要らないので害が出ない。**次に
    分割したときに、空いた番号のところへ新しい境界が挿し込まれて壊れる。**
    ゼロ高のウィンドウができ、しかもそれが**選択されたまま**になるので、
    打鍵の行き先が画面から消える。「画面が更新されない」という症状の中身は
    これだった。

    直したのは 2 点。ウィンドウを消したら**番号を詰める**
    (`Window::compact_orders`、`src/core/window-config.cc`) ようにして格子に
    穴を作らないこと、それと `compute_geometry` が**未初期化の境界を使わない**
    ように配列を -1 で始めて埋め残しを直前の境界で塞ぐこと。後者だけでも
    症状は止まるが、それは「ごみを読む」のを「決まった値を読む」に変えた
    だけなので、両方入れてある。

    **`M-x eval-expression` から同じことをすると壊れないのは経路の違いでは
    なかった。** ウィンドウを消して作る順序が変わって穴が残らないだけで、
    Lisp から `(split-window) (delete-window) (split-window)` と続けるだけで
    再現する。Win32 でも同じ経路を通るので、同じ直しを入れた (そちらは
    たまたま症状が出ていなかった)。

    テストは 2 つに分けた。Lisp スイート (`unittest/window-order-tests.l`)
    で「消してから分割してもまともな大きさの 2 枚になる」ことを見て、
    **端末の症状そのものは `tools/linux-smoke.sh` で見る** — Lisp スイートは
    Windows ビルドで走るので、端末で画面が固まることは見えない。
    スモークは画面の文字ではなく**「今いるウィンドウの高さ」を editor に
    訊く**。画面を読む形も書いてみたが、ダンプが drain の切り上げ方に
    依存して不安定だった。

  * **ステータス行が表示量に応じて複数行になるようにした** (issue #97、
    報告により発覚)。`message` の出力先が常に 1 行で、収まらない分は切られて
    いた。`ESC ESC` の結果が長いと読めず、**「`*scratch*` で `C-j` を使って
    ください」と案内するしかなかった。**

    ```
    ESC ESC (mapcar #'car *color-theme-table*) RET

    以前: ("Solarized Dark" "Solarized Light" "Molokai" "Gruvbox Dark" "Nor
    今:   ("Solarized Dark" "Solarized Light" "Molokai" "Gruvbox Dark" "Nord"
          "Dracula" "One Dark" "Tomorrow Night" "Catppuccin Mocha" "Tokyo Night"
          ... (全部)
    ```

    **`message` の出力先をエコー領域 (ミニバッファの行) へ移した。** 以前の
    出力先は下のバーで、あれは Win32 のステータスバーに時計や行桁のパーツと
    横並びで入っているので、高さを変えると時計まで縦に伸びて不格好になる。
    エコー領域は伸縮するように作られていて、**普段は 1 行空いたまま遊んで
    いる。** Emacs の `message` が出るのもそこである。下のバーは時計と
    `princ` によるストリーム出力用に残してある。気に入らなければ
    `(setq *message-in-echo-area* nil)` で以前の形に戻る。

    上限は `*max-minibuffer-message-lines*` (既定 10)。1 にすると以前と同じ
    「常に 1 行」になる。画面に入り切らない高さは入る分まで詰める。
    **メッセージに改行を書けばそこで行が変わる** (以前は `^J` と描かれて
    いた)。

    **`C-x` の候補一覧が 8 個から 48 個になった。** which-key はプレフィックス
    キー待ちの候補をステータス行に出しており (分割ウィンドウを使わないのは
    #83 のため)、1 行では 63 個のうち 8 個 + 「+55」しか出せなかった。行数が
    使えるようになったので段組みで出す。入り切らない分は今までどおり
    「... +N」と個数を書く。

    **メッセージを消すタイミングを変えた。** 以前はキーを待つ**前**に消して
    いた。プロンプト (`interactive "c"` のように同じコマンドの中で出して
    読んで消すもの) にはそれで足りたが、`message` の出力先をここへ回すと
    **読む前に消える。** 打鍵まで残す方が Emacs のエコー領域と同じで、
    待っている間ずっと読める。

    **行の割り方は 1 箇所に置いた** (`src/core/minibuffer-message.cc`)。
    高さを決める側と描く側が別々に数えると「4 行分の高さを取ったのに 3 行
    しか描かない」という食い違いになり、フロントエンドが 2 つあるので
    別々に書くと 4 箇所へ散る。

    行数の持ち主も変えた。Win32 の `compute_geometry` はミニバッファの高さ
    から `old_h / lcell` で行数を割り戻していた。フォントを変えても行数が
    保たれるようにするための計算だが、**副作用として行数を変える手段が
    無かった** (ウィンドウ側は前から複数行になれたのに、誰も高くしないし、
    描く側が 1 行しか埋めていなかった)。

    端末フロントエンドでは `si:*minibuffer-message` が**空実装だった。**
    そのため `minibuffer-message` もプロンプトも何も出さず、`message` を
    ここへ回した時点でメッセージが 1 つも見えなくなった。実装した。

    テストは**伸びることより戻ることを見ている**
    (`unittest/echo-area-tests.l`)。高さが変わると他のウィンドウの高さも
    変わるので、伸びたまま戻らないとメッセージを 1 回出すごとに編集できる
    行が減っていく。

  * **カラーテーマが「文字1〜15」の色も決めるようにした** (issue #98、報告に
    より発覚)。`set-text-attribute` の `:foreground` / `:background` で色を
    付けている箇所 — tree-sitter による色付け、calendar の土日、diff、
    hideif、ispell — が**テーマを選んでも赤・緑・黄の固定色のまま**で、
    選んだ配色の上に浮いていた。「ソースを開いた直後やスクロールで、一瞬
    テーマの色が出たあと別の色に塗り替わる」という報告の中身がこれである。

    **原因は 2 つの色付けが別の色表を見ていたこと。** キーワードファイルに
    よる色付けは「キーワード1」などの役割色 (`set-buffer-colors`、
    `USER_DEFINABLE_COLORS`) を引き、テーマはこちらを書き換える。一方
    `set-text-attribute` の `:foreground N` が引くのは「文字1〜文字15」と
    いう別の 16 色表で、**共通設定→表示色のダイアログからしか変えられず、
    Lisp から触る手段が無かった。** つまり設定ミスではなく、tree-sitter の
    色付けはそもそもテーマに届かない作りだった。

    そこで `set-text-attribute-colors` / `get-text-attribute-colors` を足し
    (`src/core/textprop-colors.cc`)、カラーテーマがこの表も背景に合わせる
    ようにした。**設定として保存されている値と、実際に描画で使う値を分けて
    いる。** テーマによる上書きは `xyzzy.ini` に書かないので、テーマを解除
    すれば表示色の設定どおりに戻る (`nil` を渡すと戻す)。表の定義自体も
    `src/frontend/win32/Window.cc` から共通側へ移した。端末フロントエンド
    には存在しなかったので、共通のコードから触れなかった。

    **色みは番号ごとに固定したまま、明るさだけを背景に合わせる。**
    「1 番をテーマのキーワード色にする」ようなことはしない。番号の意味を
    当てにしているコードがあるからで、calendar は日曜日に `:foreground 1`
    の赤、土曜日に 4 の青を使っている。番号を振り替えると日曜日が緑になる。
    直すのは「暗い背景で黒に近い色が沈む」「明るい背景で黄色が読めない」の
    2 点だけである。

    **テーマごとに 15 色を書き並べるのではなく、標準色から導く。** テーマは
    30 個あり、手で足すと元の配色に無い色を 450 個発明することになる。
    導出は「白か黒へ 5% 刻みで寄せて、背景とのコントラスト比が 4.5:1
    (WCAG が本文に求める比) に達したところで止める」だけ。白へ混ぜると
    彩度が落ち、黒へ混ぜると成分の比が保たれるので、**どちらも赤は赤のまま
    になる。**

    **輝度は成分を 2 乗してから重み付けする。** はじめ ITU-R BT.601 の単純な
    加重平均で書いたところ、**暗いテーマだけが直って明るいテーマがほとんど
    直らなかった。** 白地の `#ffff00` は BT.601 では白との差が小さくないので
    「足りている」と判定されて手つかずのまま残る。2 乗してから見ると 928 対
    1000 で、暗くしないと読めないことが分かる。ガンマの付いた値にそのまま
    加重平均を当ててはいけない。

    背景色の表は逆に**目立たせない。** `:background` で敷く色なので、標準の
    色みをテーマの背景へ 75% 寄せて、色みがそれと分かる程度の淡い地色に
    する。純色の赤や黄をそのまま敷くと、上に載る文字が読めなくなる。

    テストは**全 30 テーマ × 15 色**を機械で見る
    (`unittest/textprop-colors-tests.l`)。1 つでも背景に沈む色があれば、
    その番号を使っている色付けがそのテーマで読めなくなるが、テーマを 1 つ
    ずつ目で確かめるわけにはいかない。導出の式を変えたときに、明るい背景と
    暗い背景のどちらかだけを直して他方を壊す事故をここで止める (実際に
    BT.601 版はここで落ちた)。

    端末フロントエンドでも同じ表を引くようにした。端末は色そのものを持て
    ないので、表の色を 16 色へ量子化して色ペアを作り直す。既定値のままなら
    以前と同じ色になる。

  * **同じシンボルをまとめて改名できるようにした** (`lisp/iedit.l`、
    `Leader c r`)。#30「iedit / multiple-cursors 的な一括編集」の 1 項目。

    ```
    foo = foo + 1; foobar(foo);              Leader c r → "counter" → RET
    counter = counter + 1; foobar(counter);
    ```

    打った文字がその場で全部の箇所に入り、`BS` で消え、`RET` で確定、
    **`C-g` で元の名前に戻る**。`foobar` のように**シンボルの途中に埋まって
    いるものは巻き込まない**。`query-replace` との違いは確認しないことで、
    変数名を直したいだけのときに y/n を 20 回押すのが本題ではない。
    **打鍵を自分で読むモーダルな作りにした。** `*self-insert-hook*` は関数を
    1 つしか持てず、既に自動ペア挿入が入っている。そこへ割り込む形にすると
    2 つの機能が互いの返り値に依存してしまう。自分で読むなら、どのキーを
    受けてどのキーで終わるかが 1 箇所に書けて、途中で他のコマンドが走らない
    ことも保証できる。代わりに**名前の途中へカーソルを移して直すことは
    できない** (末尾への追加と `BS` だけ)。変数名の付け替えではそれで足りる。
    **位置はマーカーではなく置換の差分から計算する。** 置換はどの箇所でも
    同じ長さの入れ替えなので、k 番目は (差分 × k) だけ後ろへずれる。
    マーカーにすると「挿入位置にあるマーカーが動くかどうか」に依存する。
    **書く前に、その箇所が本当に想定の文字列かを確かめる。違っていたら何も
    書かずに諦める。** 計算がずれているということなので、そのまま書くと
    ユーザのバッファが壊れる (`move-text.l` で同じ判断をしている)。
    端末でプロンプトが見えるのは #66 が直ったからである
    (`message` の直後に `read-char` で待つ形そのもの)。
    `unittest/iedit-tests.l` に 18 件 (位置の計算、シンボル境界、
    置換の連鎖、**位置をずらして「書かないこと」を確かめるもの**、色付け)。
  * **`lisp/startup.l` を編集すると `tools/x bytecompile` が必ず失敗したのを
    直した** (#54)。編集した瞬間からライブラリ全体のバイトコンパイルが通らず、
    **テストが 1 件も走らない**状態になっていた。
    原因は「`startup.lc` への書き込みが失敗しても何も言わない」こと。
    xyzzy-batch は起動の一部として `startup.lc` を読むので、それを置き換える
    書き込みは通らない。**例外も出ず、mtime も変わらないまま「成功」で
    返ってくる**ため、`makelc` 側の handler-case では捕まらなかった。
    `tools/bytecompile.sh` が、`startup.l` が stale なら **先に
    `startup.lc` を消す**ようにした。`.lc` が無ければ起動はソースから読むので
    誰もファイルを開いておらず、書き込みが通る。代わりにその 1 回だけ起動が
    遅くなる。
    あわせて `misc/makelc.l` の `makelc-and-exit` が、**失敗したときだけ**
    コンパイルログを外へ書き出すようにした。バッチ起動では
    `*compile log*` バッファが誰にも見られないまま捨てられるので、
    `bytecompile-output.txt` が 0 バイトのままで「理由がどこにも残らない」
    状態だった。成功時に出さないのは全ファイル分で 1000 行を超えるため。
  * **端末フロントエンドで `save-window-excursion` が何も戻していなかったのを
    直した** (#82)。`WindowConfiguration` が空の実装で、
    `current-window-configuration` は `nil` を返していた。
    **「一時的にウィンドウを触って元へ戻す」書き方が端末では戻らない**ので、
    囲んだ中で分割・削除をすると画面にそのまま残る。
    実装 (`WindowConfiguration` と 2 つの Lisp 入口) を
    `src/frontend/win32/Window.cc` から `src/core/window-config.cc` へ移した。
    **中身に Win32 固有のものは無い**: `w_prev`/`w_next` と `w_order`/`w_rect`
    を組み替えて `Window::compute_geometry` / `set_buffer_params` / `close` を
    呼ぶだけで、どれも両方のフロントエンドが持っている。二度書くものではない
    (#16 Phase 4)。
    移すにあたって 1 箇所だけ直した: 構成の検証が
    **「一番上のウィンドウの上端は 0」を決め打っていた**。ncurses は 0 行目を
    メニューバーに使うので上端は 1 で、端末で作った構成が自分で「不正」と
    判定されていた。今出ているウィンドウから上端を取るようにしたので、
    どちらのフロントエンドでも通る。
    `unittest/window-config-tests.l` に 7 件。ただし **Lisp スイートは Windows
    ビルドでしか走らないので、これは端末側の保証にはならない** (守るのは
    「core へ移した実装が Windows 側で退行していないこと」)。端末側は
    `tools/x pty` で確認した: 往復、3 枚から 2 枚への復元、バッファの復元、
    `save-window-excursion`、Leader メニュー。
  * **テストスイートが、読み込みに失敗したファイルを黙って見逃していたのを
    直した。** そのせいで 2 つのファイルが **1 件も走らないまま緑になっていた。**
    `misc/run-tests-batch.l` は `ERROR loading ...` と出すだけで、exit code
    にも既知失敗の gate にも反映していなかった。**ファイル 1 本が丸ごと
    落ちているのは、テストが 1 件落ちるより悪い。** 失敗として数え、最後に
    「どのファイルが読めなかったか」も出すようにした。
    見つかったのはこの 2 件。

      * `unittest/formatter-tests.l` — `#\CR` という文字名は xyzzy に無い
        (CR は `#\RET`)。読み込み時に落ちていた。**保存時の整形の
        テスト 18 件が一度も走っていなかった。**
      * `unittest/leader-tests.l` — `Leader SPC` と `Leader b b` の期待値が
        古いまま (ファジー版に差し替えた後の名前になっていなかった)。
        assert で落ちてファイルが途中で終わり、**以降の Leader のテストは
        全部走っていなかった** (#84 で足した 6 件も含む)。

    走らせてみたら **本物のバグが 1 件出た**: 外部フォーマッタの
    コマンド文字列を `format` に渡していたので、`~A` 以外の `~` が書式指定子
    として食われてコマンドが壊れる。**Windows の一時ファイル名は `~` で
    始まることがあり** (`make-temp-file-name` が
    `C:/users/.../Temp/~xyz.tmp` を返す)、そのまま踏む。しかも壊れた
    コマンドでも `call-process` は起動するので、**整形されないことに
    気づけない。** `~A` だけを置き換える関数に分けた。
    テスト件数 1026 → 1032 (`~A` の展開に 3 件、上記の復活分)。
  * **配列の大きさの上限が処理系のポインタ幅で変わっていたのを直した。**
    `make-array` の検査が `LONG_MAX` を見ていた。`long` は Windows (LLP64) では
    32bit、Linux (LP64) では 64bit なので、**同じコードが 2 通りの上限**に
    なっていた。要素数を持つのは `lbase_vector::length` (`int`) なので、
    `INT_MAX` で見るのが正しい。Windows の挙動は変わらず、Linux がそれに揃う。
    Linux では 2 つの形で壊れていた。

      * `(make-array '(536870912 1))` が通ってしまい、4GB を確保しようとして
        メモリを食い潰す。**Linux ネイティブビルドで Lisp テストスイートが
        暴走する** (#49) 原因がこれだった: `test-make-large-array-1` が
        12GB まで伸びたところで kill されていた。
      * 2^31 以上では `int` の `length` に収まらず、**長さが負になる**。

    `unittest/array-tests.l` の 2^31 のテストは、どの条件が飛ぶかが fixnum の
    幅で変わる (fixnum は `long` 幅なので、Windows では `range-error`、
    64bit では `program-error`) ので、**種類ではなく「拒否されたこと」**を
    見るように書き換えた。
    あわせて `unittest/array-tests.l` に encoding マーカーを足した。長く
    ASCII のみだったので付いておらず、**日本語のコメントを 1 行入れると
    読み込みが途中で終わってファイルのテストが全部消える** (cp932 として
    読まれる)。実際にそれで 1 度潰した。
  * **ディレクトリを上へ遡る処理が Windows で無限ループになるのを直した。**
    起動直後に **CPU 100% で応答が無くなる**形で出る。報告により発覚。
    上へ遡るのに `(directory-namestring (remove-trail-slash dir))` を使って
    いたが、**Windows の `C:` は「ドライブ C: のカレントディレクトリ」を
    意味する**ので、

    ```
    C:/  ->  C:  ->  C:/Users/ykuwa/Downloads/xyzzy-latest/xyzzy-amd64/
    ```

    と **長い方へ戻ってくる**。「親が自分と同じなら終わり」だけを見ていたので、
    そこから同じ数ディレクトリを永久に巡回していた。
    判定を **「長さが必ず減ること」** に変えた (正の整数が単調減少するので
    必ず止まる)。処理は `parent-directory` に切り出し、遡っている 2 箇所
    (`lisp/project.l` のプロジェクトルート探索、`lisp/modeline.l` の `.git`
    探索) の両方で使う。
    **プロジェクトルート探索の方は元からこの形だった。** `Leader p f` などを
    ドライブのカレントディレクトリと噛み合う場所で呼ぶと固まりうる状態が
    ずっとあり、モード行が起動時に `.git` を探すようになったことで、
    それが「起動できない」として表に出た。
    **CI が捕まえられなかったのは、ルートまで遡るテストが 1 つも無かった
    ためである。** 遡る処理を呼ぶテストは一時ディレクトリを `si:system-root`
    (= リポジトリ) の下に作るので、すぐ上に `.git` があってドライブのルートに
    到達しない。実機で固まったのは「上に `.git` が 1 つも無い場所」
    (インストール先) だった。**リポジトリの外 (TEMP の下) から呼ぶテストを
    足したところ、Wine でも同じように止まらなくなった** ので、実機固有の
    現象ではなく「そこを通るテストが無かった」だけだと分かった。
    `unittest/parent-directory-tests.l` に 9 件: `parent-directory` 単体
    (6 件)、リポジトリの外からルートまで遡る経路 (2 件)、そして
    `directory-namestring` を差し替えて折り返しを作り、遡りが有限回で終わる
    ことを見るもの (1 件。**呼び出し回数に上限を付けて、止まらなくなっても
    テストが固まらず落ちるようにしてある**)。
  * **タイトルバーと「について」のバージョンで、リリースかどうかが分かるように
    した。** 報告により発覚: **手元の先端ビルドとリリース版が画面から区別
    できない。**

    ```
    xyzzy 0.6.0 (Clang/x64)                      <- タグの上 = リリース
    xyzzy 0.6.0-36-ga34f898a-dirty (Clang/x64)   <- 36 コミット先、未コミット変更あり
    ```

    **仕組みは元からあったが、3 つの理由で一度も動いていなかった。**

      * CMake の判定が逆だった。`git describe --tags --dirty` と `--long` を
        比べて「違えばタグの上ではない」としていたが、実際は逆
        (`--long` は必ず `-N-g<hash>` を書くので、**一致する方が**タグの上で
        ない)。結果、describe 文字列が出るのはリリースのときだけ =
        欲しい場面では絶対に出ない、という状態だった。
      * **生成したヘッダが、同名のコミット済みファイルに隠されていた。**
        `src/core/version-describe.h` (中身は空のコメントだけ) が `version.cc`
        の隣にあり、`#include "version-describe.h"` はまず同じディレクトリを
        見るので、`gen/` の生成物は一度も読まれていなかった。消した。
      * container の中では `git` が「dubious ownership」で拒否していた
        (root で動くのに checkout はホストユーザ所有)。`-c safe.directory`
        を付けた。**これも「手元のビルド」だけが黙って素のバージョンに
        なる形だった。**

    あわせて、**ハッシュを configure 時ではなくビルドごとに取り直す**ように
    した。コミットは CMakeLists.txt よりずっと頻繁に動くので、configure 時の
    値は古くなる。**古いハッシュは無いより悪い** (走っていないビルドの名前を
    名乗る)。ヘッダを `add_custom_command` の `OUTPUT` として宣言しないと
    ビルドグラフが繋がらず、書き換えても `version.cc` が再コンパイルされない
    (`ninja -d explain` で確認した)。
  * **「について」ダイアログを読めるようにした。** 報告により発覚。

      * 幅を 211 → 260 に広げた。**リリースでないビルドのバージョンは長く、
        元の幅では途中で切れて「どのビルドか」が読めなかった。**
      * **下の空の白い箱に見出しを付けた** (「アーカイバ DLL:」)。中身は
        アーカイバ DLL (UNLHA32.DLL など) とそのバージョンで、入れていなければ
        空になる。空だと何の場所か分からないので、`(見つかりません)` の 1 行を
        必ず入れるようにした。
      * `RSA Data Security, Inc.` と `MD5 Message-Digest Algorithm.` の 2 行を
        1 行にまとめた。**これは飾りではなく使用条件である**: MD5 の実装は
        RSA のリファレンス実装 (`src/core/md5c.cc`) で、そのライセンスが
        「この名前で識別すること」を求めている。2 行に割れていたので、
        無関係な 2 つの謝辞のように見えていた。
    `unittest/about-tests.l` に 3 件 (表示用バージョンが素のバージョンで
    始まること、一覧が空にならないこと、2 列であること)。
    **リリースビルドでだけ落ちるテストは書かない**ようにしてある。
  * **encoding マーカーの無い Lisp ファイルに日本語を書いていないかを、
    テストで見張るようにした。** これは 1 日に 3 回踏んだ罠である。
    xyzzy は 1 行目に `-*- ... Encoding: utf-8 -*-` の無いファイルを cp932 と
    して読むので、**純 ASCII だったファイルに日本語のコメントを 1 行足すと、
    多バイト文字の後半が改行や `"` を食ってフォームの構造が変わる。**
    しかも出方が「自分の書いたコメントが原因」に見えない。

      * `misc/run-tests-batch.l` → `-load` が **出力ゼロ・exit 0** で終わり、
        テストが 1 件も走らない
      * `unittest/array-tests.l` → 「文字列が終了していません」でそのファイルの
        テストが全部消える
      * `lisp/ts.l` → バイトコンパイルが「不正なドットリストです」で止まり、
        **ライブラリ全体が `.lc` 無しになる** (CI で気づいた。この PR で
        マーカーを足した)

    `unittest/encoding-marker-tests.l` が `lisp/` `unittest/` `misc/` を走査し、
    **マーカーが無いのに ASCII 以外を含むファイル**を挙げて落ちる。マーカーの
    有無を先に見るので、中身まで読むのは残りの十数個だけ。マーカーを外して
    実際に落ちることを確認した。
    `misc/bytecompile-batch.l` にもマーカーが無かったので足した (こちらは
    たまたま壊れていなかった)。
  * **tree-sitter の色付けを切れるようにした** (`*ts-highlight*`、
    `M-x toggle-ts-highlight`、`Leader t s`)。報告により発覚:
    **カラーテーマを選んでいると、テーマの色が一瞬出たあと別の色に
    塗り替わる。**
    原因は「上書き」で合っていた。色付けが 2 つ順に走っていて、
    **後から走る tree-sitter の色がテーマに従わない。** この 2 つは別の色表を
    見ている: キーワードファイルの色付けは役割色
    (`set-buffer-colors`、テーマが書き換える) を、tree-sitter は
    `set-text-attribute` の `:foreground` が指す「文字1〜文字15」という
    **固定の 16 色表** (`Window::w_textprop_forecolor`) を使う。後者を
    書き換えられるのは共通設定のダイアログだけで、**Lisp から設定する手段が
    無い。** 実機の `xyzzy.ini` を見ると、テーマを当てた後もこの表は既定の
    赤・緑・黄・青・マゼンタ… のままだった。
    `lisp/c-mode.l` などの色表のコメント (`; dark red` `; purple`) は
    **この固定表を指していて正しい**。設定ミスではなく、tree-sitter の色付けは
    そもそもテーマに届かない作りだった。
    直すには「文字1〜15」を Lisp から設定できるようにして、テーマ適用時に
    役割色から作る必要がある (issue #98)。**それが入るまでの逃げ道として、
    切れるようにした。** 切ると、開いているバッファの色付けもその場で外す。
    `unittest/ts-highlight-tests.l` に 4 件。
  * **一時ウィンドウを開いた直後に大きさが取れず、候補が 1 個しか出なかったのを
    直した。** 報告により発覚。

    ```
    [Leader]
    b  Buffer+
    ... +13
    ```

    Win32 では `split-window` の直後のウィンドウは `window-lines` /
    `window-columns` が **1 を返す**。実際の大きさになるのは次の描画のときで、
    フレームのウィンドウ配置は `refresh_screen` の `move_all_windows` で
    反映される。**「1 行 1 桁」として段組みを計算していたので、1 個入れて
    残りを全部落としていた。**
    `popup-window-open` が開いた後に `(refresh-screen)` を呼ぶようにした。
    あわせて、測った値が明らかに小さい (行が 2 以下、桁が 20 以下) 場合は
    **「まだ分からない」として既定値を使う**ようにした
    (`popup-window-measured-lines` / `popup-window-measured-columns`)。
    黙って小さい値を信じると、候補が消えるという形で出る。
    **これは 1 つ前の変更 (無関係なウィンドウを奪わない) の副作用である。**
    奪っていた頃は「既にあって大きさの確定したウィンドウ」を使っていたので、
    測った値が正しかった。自分でウィンドウを作るようになって初めて出た。
  * **候補一覧の一時ウィンドウが、無関係なウィンドウを奪っていたのを直した。**
    報告により発覚: シェルとテキストを左右に並べた状態で `M-m` を打つと、
    **シェルを出していたウィンドウのモード行だけが `*Which Key*` になり、
    画面はシェルのまま**という状態になった (候補は動いていたが見えない)。
    `pop-to-buffer` は **「画面が既に分割されていたら新たに分割せず、別の
    ウィンドウへ移ってそこに出す」** 仕様である。一時的な候補表示にこれを
    使っていたので、隣のウィンドウを奪っていた。奪われた先が端末を出して
    いるウィンドウだと、そこは描き直されないまま中身だけ入れ替わる。
    **今いるウィンドウを分割する**ようにした (既にその一時バッファを出して
    いるウィンドウがあればそれを使う)。`split-window` は元のウィンドウを
    選択したままにするので、増えたウィンドウを差分で見つけて移る
    (`next-window` の順序に依存しない)。
  * **一時ウィンドウを閉じた後に画面全体を描き直させるようにした。**
    こちらも報告: 起動直後に `M-x shell` すると、**候補一覧の文字が
    `*Shell*` の画面に残った。** 一時ウィンドウが消えて残りのウィンドウが
    広がった行は、そのままだと誰も描き直さない。その後に走るのが「変わった
    行だけ描く」種類の描画 (非同期のプロセス出力など) だけだと残る。
    `with-popup-window` が **ウィンドウ構成を戻した後**に
    `(refresh-screen t)` を呼ぶ (Win32 では全ウィンドウに再描画の印を
    付けるだけなので安い)。
    あわせて、#82 の回避として入れていた `popup-window-close` の
    `delete-window` を外した。#82 (端末で構成の復元が効かない) が直った後は
    不要なうえ、構成の復元より先にウィンドウを消すことで描き直しの印が
    付かなくなる側に働いていた。
  * **`C-x` や `C-c` を押したときも、次に何が打てるかを出すようにした** (#73)。
    #30「Which-key ガイダンス」の残り。`M-m` (Leader) では出ていたが、
    標準のプレフィックスキーでは何も出ていなかった。

    ```
    [C-x] C-k  Kanji+  4  OtherWin+  6  Frame+  r  Register+  C-a  add-mode-abbrev  C-b  List  +57
    ```

    **Lisp だけでは書けなかったので、コマンドループにフックを足した。**
    `M-m` は `execute-leader-key` という *コマンド* なので、その中で自分で
    キーを読みながら描ける。一方 `C-x` は *キーマップ* が割り当てられていて、
    次のキーを待つのは C++ 側 (`src/core/cmdloop.cc` の `dispatch`) である。
    その経路は `*post-command-hook*` まで来ないので、Lisp から手が出せなかった。
    `*prefix-key-hook*` を追加し、待機中のキーマップと打ったキーを渡して呼ぶ。
    **待ちが終わったことも通知する。** これは `*pre-command-hook*` より先に
    呼ぶ: 後だと、出したものを片付けるときにコマンドの結果 (`C-x 2` の分割
    など) を消してしまう。キーが未定義だった経路は `*post-command-hook*` まで
    来ないので、そこでも通知が必要だった。
    `C-x` を「候補を出すコマンド」で包む Lisp だけの案は却下した。
    `call-interactively` を通ると `*last-command*` が壊れ、`C-k C-k` の
    kill-ring 追記や `yank-pop` が効かなくなる。
    **候補はステータス行に 1 行だけ出す。分割ウィンドウは使わない。**
    段組みで出す形も書いて動かしたが、**プレフィックス待ちの最中に
    ウィンドウを作って消すと端末フロントエンドの画面が更新されなくなった**
    (issue #83)。`C-x` は日常の打鍵なので、そこでレイアウトを触るのは
    危険が大きすぎる。1 行に入らない分は「`+57`」と件数を書く:
    黙って切ると「これで全部だ」と読めてしまう。
    ついでに `C-x` のコマンドに短いラベルを 50 個ほど付けた
    (`inverse-add-mode-abbrev` のような名前は幅を食うだけで読めない)。
    **副産物として、端末フロントエンドの穴が 2 つ見つかった**:
    `save-window-excursion` と `current-window-configuration` が何もしない
    (#82)、プレフィックス待ち中のウィンドウ操作で画面が固まる (#83)。
    前者は `lisp/popup-window.l` の `popup-window-close` が
    **ウィンドウを明示的に消す**ようにして回避した (ウィンドウ構成の復元に
    任せていた間、端末では一時ウィンドウが残りうる状態だった)。
    あわせて `popup-window-columns` に行数の上限を渡せるようにし、
    Leader メニューも項目が増えたときに黙って切れないようにした。
    `unittest/leader-tests.l` に 6 件、`unittest/popup-window-tests.l` に 4 件。
  * **端末フロントエンド (ncurses) で、コマンドの途中に出したプロンプトが
    画面に出なかったのを直した** (#66)。`message` を書いた直後に
    `read-char` で待つコマンドが、**描かれないまま待ちに入っていた。**

    ```lisp
    ;; 直す前: SMOKE-PROMPT-VISIBLE がどこにも出ないまま入力待ちになる
    (progn (message "SMOKE-PROMPT-VISIBLE") (read-char *keyboard*))
    ```

    コマンドループは「コマンドが終わったら描く」形なので、**コマンドの
    途中で待つ場合が抜けていた。** 入力待ちに入る前 (`kbd_queue::fetch` の
    `select` の直前) で描くようにした。**打鍵ごとに 2 回描かないよう、
    コマンドループからの呼び出しとは区別する**: ncurses の
    `refresh_screen` は毎回全ウィンドウの glyph を作り直すので、余分な
    1 回が効く。コマンドループは直前に描いてから `fetch (1, ...)` を呼び、
    コマンドの途中の `read-char` は `fetch (0, 0)` で来るので、そこで分かる。
    **`isearch` と `query-replace` は元から出ていた** (別の経路でプロンプトを
    出している)。出ていなかったのは「`message` を書いてから `read-char`」の
    形だけで、Leader メニューのステータス行版がこれだった。
    `tools/linux-smoke.sh` に回帰確認を足した。**この症状はビルドでもリンクでも
    Lisp テスト (Windows ビルドのみ) でも分からず、画面を見るしかない。**
  * **端末フロントエンド (ncurses) のモード行で、改行コードが `lf` ではなく
    `l` と 1 文字だけ表示されていたのを直した。** `[utf8n:l]` になっていた。
    原因は `Char` (= `uint16_t`) の列を求めている場所へ `L"lf"` を
    `(const Char *)` でキャストして渡していたこと。**Windows の `wchar_t` は
    2 バイトなので偶然正しく、Linux では 4 バイトなので `6C 00 00 00` を
    16 bit ずつ読むことになり、2 文字目が NUL になって切れる。** 同じ形の
    キャストがタイトルバー (`src/core/Buffer.cc`) にもあり、そちらも直した
    (端末では見えないので誰も気づけない位置だった)。要素を明示した `Char`
    配列と `wchar_t` 用の `wstore` に分け、キャストで済ませられないようにした。
    **見つけたのはモード行を組み立てる機能 (下記) の表示を確認していたときで、
    素の xyzzy でもずっとこうなっていた。** ビルドもリンクも通り、Lisp
    テストスイートは Windows ビルドでしか走らないので、
    **画面を見る以外に気づく方法が無かった。** 同じ穴を残さないよう、
    `tools/linux-smoke.sh` に「モード行の `%` 指定子が最後まで展開される」
    確認を足した (`tools/pty-drive.py` で画面を取り、既定の書式ではなく
    自前の書式を入れてから見るので、既定のモード行を変えても効き続ける)。
    あわせて `tools/pty-drive.py` の起動待ちを直した。**「出力が 1.5 秒
    止まったら起動できた」と見ていたが、xyzzy は `lisp/` を読み終わるまで
    何も描かない。** それが container では 1 秒程度、CI の runner では
    17 秒かかるので、CI では真っ白な画面のまま先へ進み、起きていない
    プロセスに打鍵を投げていた (この確認を足して最初に踏んだ)。
    静かになるのを待つのではなく**最初の描画を待つ**ようにし、
    時間内に何も描かれなかった場合はその旨を書くようにした
    (真っ白な画面を黙って出すと、原因が「描画がおかしい」に見える)。
  * `split-string` の第 3 引数の名前を `ignore-empty` から `empty-ok` に直した
    (#57)。**実装は `empty_ok` で、non-nil のときに空要素を「残す」。名前が
    意味と逆だった。** `describe-function` は宣言の引数名をそのまま出すので、
    読んだ人は「`t` を渡せば空要素が無視される」と受け取る。
    宣言の変更なので挙動は変わらない。あわせて、リポジトリ内で
    **「空要素を無視するつもりで `t` を渡していた」呼び出しを `nil` に直した**:
    `PATH` の分割 (`lisp/complete.l`)、ファイラ・Grep・置換のファイルマスク
    (`lisp/filer.l`, `lisp/grepd.l`, `lisp/gresregd.l`, `lisp/optprop.l`)、
    テスト実行の除外リスト (`misc/run-tests-batch.l`)。`*.c;;*.h` のように
    区切りが連続すると空のマスクが混じっていた。
    矩形貼り付け (`lisp/select.l`) は `t` が正しい (途中の空行を落とすと
    以降の行がずれる) ので、そう書いてある理由をコメントに残した。
    `unittest/split-string-tests.l` に 10 件。書いていて分かったこととして、
    **末尾の区切りに対しては non-nil でも空要素を作らない** (先頭側とは
    非対称) ことをテストと `reference/reference.xml` に書いた。Emacs の
    `split-string` とはここが違うので、行数を数える用途でそのまま
    置き換えられない。
  * **モード行にプロジェクト名と Git のブランチ名を出すようにした**
    (`lisp/modeline.l` を新設、`toggle-rich-modeline` は `Leader t m`)。
    #30「Doom-Modeline 風ステータスバー」の 1 項目。

    ```
     -- | modeline.l | xyzzy | git:topic/rich-modeline | Lisp | 12:3 45% | utf8n lf
    ```

    **素の xyzzy のモード行には「どのリポジトリのどのブランチを触っているか」が
    出ない。** 複数のリポジトリを開いて作業しているとき、これが分からないのが
    そのまま事故になる (別のブランチだと思って書いていた、が起きる)。
    `mode-line-format` は C++ 側が `%` 指定子を展開する**ただの文字列**なので、
    Lisp で組み立てた文字列を buffer-local に差し込めば済む。
    **その代わり、面が持てるのは文字列 1 本だけである。** 色分けはできず
    (モード行は 1 色で描かれる)、右寄せもできない (`%` の展開後の幅が Lisp から
    分からない) ので、doom-modeline のような左右分割ではなく左から順に並べる
    形にした。できないことは `docs/user/configuration.md` に書いた。
    **ブランチ名は `git` を起動せず `.git/HEAD` を直接読む。** サブプロセスの
    起動は打鍵ごとに払える値段ではなく、Windows ではそれが体感できる。
    上に遡って `.git` を探す部分だけキャッシュし、HEAD (41 バイト) は毎回読む:
    キャッシュして古いブランチ名を出す方が損である。`.git` がファイルの場合
    (worktree / submodule) は `gitdir:` を辿る。
    **項目名をキーワード (`:state` `:branch` …) にしたのは、`~/.xyzzy` が
    パッケージ `user` で読まれるためである。** 素のシンボルで書くと
    `editor` パッケージの同名シンボルと別物になり、黙って項目が消える
    (実装中に実際に踏んだ)。名前が合えば素のシンボルでも拾うようにしてある。
    **Lisp が作った文字列は `%` を潰してから渡す。** 潰さないと、`%` を含む
    ブランチ名やディレクトリ名が書式指定子として食われる。
    **起動時に自動で有効になるが、`~/.xyzzy` で `mode-line-format` を設定して
    いる人には何もしない。** `*post-startup-hook*` (= `.xyzzy` の後) で素の値の
    ままかどうかを見ているので、自分の書式を書いている設定を上書きしない。
    **起動後に `mode-line-format` を直接書き換えたい場合は先に切る必要がある**
    (有効なままだとバッファ切り替えや定期の作り直しで上書きされる)。
    これは `tools/linux-smoke.sh` のモード行確認が自前の書式を入れる形なので
    実際に踏み、確認側で先に切るように直した。
    `unittest/modeline-tests.l` に 25 件 (組み立て、`%` の潰し、切り詰め、
    `.git` の探索を実際にファイルを置いて確認、`gitdir:` の追跡、
    有効化・無効化でフックと buffer-local が後始末されること)。
  * 「終了時に開いていたバッファとウィンドウ分割を次の起動で復元する」機能を
    文書化し、切り替えコマンド `toggle-resume-session` を足した。#30
    「ワークスペース / セッション保存」の 1 項目。
    **実装は元からあった** (`lisp/history.l` の `*save-resume-info*` と
    `lisp/session.l` の `save-resume-info` / `restore-resume-info`)。ただし
    既定で無効なうえ利用者向けの文書に一言も無く、事実上気づけない状態だった。
    まず本当に動くのかを確かめてから書いた: 別プロセスで
    「`leader.l` の 20 行目を開いて終了 → 起動」を通し、`leader.l` が
    20 行目で開いた状態で立ち上がることを確認した。
    **既定は無効のままにした。** 起動時に前回のファイルが全部開くのを望まない
    人がいて、「毎回きれいな状態で始めたい」使い方と両立しないので、こちらから
    有効にするものではないと判断した。`~/.xyzzy` に 1 行 (または
    `M-x toggle-resume-session`) で有効になることを
    `docs/user/configuration.md` に書いた。
    `unittest/defaults-tests.l` に 2 件 (仕組みが在って既定が無効であること、
    書き出しが読み戻せる形であること)。既定を変えるときはテストも直る。
  * `CLAUDE.md` と `misc/known-failures/README.md` の記述を直した。
    「`.lc` が無い手元の run は CI より 3 件多く落ちる」のうち 1 件
    (`uuid-create-4-seq`) はローカル固有の差ではなく flaky だったので
    2 件に直し、**「手元だけ落ちると決めつける前に flaky を疑う」**という
    項目を足した。known-failures の README には「flaky はこのリストに
    入れるものではない」ことを書いた: 載せると gate が両方向に嘘をつく
    (落ちたときに緑、通ったときに赤になる)。
  * 走り書きの置き場を追加した (`lisp/memo.l`、`Leader o` の新カテゴリ)。
    #30「クイックメモ / スクラッチバッファ管理」の 1 項目。
    `Leader o s` で `*scratch*` へ跳び (消えていれば作り直す)、
    `Leader o m` でその日のメモ (既定 `<config>/memo/YYYY-MM-DD.md`) を開いて
    時刻の見出しを付けて末尾へ、`Leader o M` で置き場をファイラで開く。
    **1 打鍵で必ず同じ場所に着くことを優先した。** 思いついたことを書く場所を
    探すだけで思考が途切れるのが元の問題なので、そこを無くすのが目的である。
    日付ごとにファイルを分けるのは、1 つの大きなファイルにすると開くのも
    探すのも重くなるため。同じ分に何度呼んでも見出しは重ねない。
    `*scratch*` は保存されないので、残したいものはメモの方へ書く
    (`*scratch*` を「消えても構わない場所」として使い分けられるように、
    両方を別のキーにしてある)。`unittest/memo-tests.l` に 7 件。
  * `C-x b` (バッファ切り替え) と `C-x C-r` (最近開いたファイル) を縦型の
    ファジー絞り込みに寄せた (`lisp/fuzzy-buffer.l` を新設、`lisp/recentf.l`
    を差し替え)。#30「`recentf-open`, `switch-to-buffer`, `find-file` 等を
    統一」の 2/3。
    **並び順は「直前のバッファが先頭、今のバッファが最後」。** `C-x b` は
    「さっきの所に戻る」のに一番よく使うので、`C-x b RET` で戻れる方が速い。
    今のバッファを候補から外さないのは、うっかり選んでも何も起きないだけで
    済むのに対し、外すと「一覧にあるはずのものが無い」ことになるため。
    注釈にはファイルのディレクトリを出す (同じ名前のファイルを複数開いて
    いるときに名前だけでは選べないのを補う)。
    一覧に無い名前を打って `RET` するとそのバッファを作る。この
    「一致が無ければ打った文字列を返す」動作のために
    `fuzzy-completing-read` に `:allow-new` を足した。
    `find-file` (`C-x C-f`) はそのままにした。パス補完は「打ちながら
    ディレクトリを降りていく」もので、候補一覧を絞る話とは別物なので、
    同じ枠に無理に入れると使いにくくなる。プロジェクト内を横断して探すのは
    `Leader p f` (`project-find-file`) が既にファジーである。
  * カラーテーマの暗い/明るい切り替えを追加した
    (`toggle-color-theme-dark-light`、`Leader t T`。テーマ選択は
    `Leader t C`)。#30「ダーク/ライトモード簡単切り替え」の 1 項目。
    相方は「`X Dark` ↔ `X Light`」という名前の対応と、機械的に導けない組の
    表 (`*color-theme-counterpart-alist*`: Catppuccin, Rose Pine, Ayu,
    One Dark/Light) から探す。名前を入れ替えた結果が実在しない場合
    (`Everforest Light` など) は相方なしとして扱い、既定のテーマの反対側へ
    移る。
    **暗いか明るいかは名前ではなく背景色の輝度で判定する。** Dracula・Nord・
    Molokai のように名前に Dark/Light が入らないテーマが 30 個中の大半を
    占めるので、名前を見る方法では判定できない。
    `unittest/color-theme-tests.l` に 10 件。全テーマについて色が引けること、
    相方の表に実在しない名前が無いこと、**相方が本当に明暗の逆側であること**
    (表の書き間違いを検出する) を見ている。
  * `uuid-create-4-seq` が不定期に落ちていたのを直した。
    `si:uuid-create :sequential` の**全フィールドの差が 1 以内**であることを
    見ていたが、`time_low` は 100ns 単位の時刻の下位 32bit なので 2 回の
    呼び出しの間に何千も進む (実測: 3463378576 → 3463381293)。
    **同じ tick に 2 回入ったときだけ通る**テストになっていて、手元でも
    CI (llvm-mingw x86_64) でも落ちた。連番であることの実質は「同じ機械
    (node = MAC) の、同じ clock-seq の、時刻が戻っていない 2 つ」なので、
    それを見るように書き換えた。time_mid は約 7 分ごとに繰り上がるので
    繰り上がった場合も許す。これで手元のテストが初めて完全に緑になった
    (既知失敗 10 件のみ、想定外は 0 件)。
  * `leader-define-key` に文字のリストを渡すと動かなかったのを直した。
    else 節が未定義変数 `keys` を参照していた (`key-seq` のはずだった)。
    文字 1 つをそのまま渡す形も受けるようにし、呼び出し側のリストを
    壊さないよう `copy-list` するようにした。
    あわせて docstring に **「自分で作ったキーマップを `M-m` へ直接
    割り当てないこと」** を書いた。そうすると xyzzy 標準のプレフィックス
    キー処理に入り、候補一覧が出なくなる (ステータス行に `m-` と出て次の
    キーを待つだけになる)。`~/.xyzzy` で
    `(define-key *global-keymap* '(#\M-m) *leader-map*)` と書いていて
    「候補が出ない」という報告が実際にあった。`M-m` は
    `execute-leader-key` のままにして、項目は `leader-define-key` で足す。
  * ファジー絞り込みの候補の右端に注釈を出せるようにした
    (`lisp/fuzzy-complete.l` の `fuzzy-completing-read` に `:annotate` を追加、
    Marginalia 相当)。#30「ミニバッファ注釈機能」の 1 項目。
    `M-x` ではそのコマンドの **割り当てキー** を、`imenu` では **行番号** を
    出す。割り当てが複数あるときは一番短いものを選ぶ: 一覧の目的は「近道を
    知る」ことなので、`C-x C-b` と `F2` があるなら `F2` を出したい。
    **注釈は見えている行に対してだけ引く。** `M-x` は候補が 650 件あるので、
    打鍵ごとに全件のキー割り当てを引いていては間に合わない。
    幅が足りないときは注釈を落とす (行が折り返すと一覧全体が読めなくなる)。
  * `lisp/fuzzy-complete.l` の縦型候補表示を `lisp/popup-window.l` に寄せた。
    #68 で「キーを読みながら一覧を見せる」仕組みを切り出したときの残り。
    ウィンドウの開け閉め・描画・行数の見積りが 1 箇所になった。
  * `tools/pty-drive.py` の VT 解釈を直した。**スクロール領域 (DECSTBM) と
    SU/SD、REP、ECH/DCH/ICH を解釈していなかったため、画面が正しく描かれて
    いるのに壊れて見えていた。** 実際に「候補一覧が
    `kickward-delete-char-untabify` に化けている」ように見えて、エディタ側の
    描画バグだと誤読しかけた。ncurses は端末が対応していればこれらを使って
    再描画を省くので、読む側が解釈しないと古い文字がそのまま残る。
    道具が嘘をつくと調査そのものが狂うので、直した。
  * `move-text` が「置き換えの前後でバッファの長さが変わる」書き込みを
    拒むようにした (`move-text-replace`)。move-text は必ず「同じ文字を
    並べ替える」操作なので長さは変わらない。変わるならこちらの計算が
    狂っているということなので、**書かずに諦めて ding する。**
    「最下行の直前で M-Down するとテキストが増える」「2 行バッファの
    最下行で M-Up すると 1 行目に複製される」という報告があり、Wine 上の
    Win32 GUI と端末で総当たりしても再現できていない。原因が分かるまでの
    間、ユーザのバッファが壊れるより何もしない方がましである。
    あわせて、あらゆる形・位置・方向で長さが変わらないことを総当たりで
    確かめる回帰テストを足した (`unittest/move-text-tests.l`)。
    繰り返し引数が nil で来た場合にも落ちないようにした
    ((max n 1) → (max (or n 1) 1))。
  * Leader メニュー (`M-m`) の候補一覧を、ステータス行ではなく画面を分割した
    `*Which Key*` ウィンドウに段組みで出すようにした (`lisp/popup-window.l`
    を新設、`lisp/leader.l` から使う)。
    **「候補表示が出ない」という報告への対処である。** 端末フロントエンドで
    調べたところ、`message` を書いた直後に `read-char` で待つとステータス行が
    描かれないまま待ちに入ることが分かった (issue #66)。which-key に限らず
    `isearch` や `query-replace` も同じ経路を通る。一時バッファを分割
    ウィンドウに出して打鍵のたびに書き換える形なら通常のバッファ描画の経路を
    通るので、この問題を踏まない。あわせて 1 行に収める必要が無くなり、
    13 項目を 2 行の段組みで読みやすく出せるようになった。
    段組みは縦に読んで順番になるよう列優先で詰める: 横優先だと項目が増えた
    ときに同じものが毎回違う列に来て目が慣れない。
    **コマンドの実行は一時ウィンドウを片付けてウィンドウ構成を戻した後に
    行う。** 順序が逆だと `Leader w s` (ウィンドウ分割) の結果が直後の
    後片付けで消える (実際に踏んだ)。
    `unittest/popup-window-tests.l` に 8 件、`unittest/leader-tests.l` に
    1 件追加。
  * **バグ修正**: `move-text-up` / `move-text-down` (`M-↑` / `M-↓`) が
    バッファ末尾の改行の後ろで空行を作っていたのを直した。そこは行ではなく
    位置なので動かす中身が無いのだが、弾いていなかったため「空の塊と隣の行の
    入れ替え」が成立してしまい、`"aaa\nbbb\n"` が `"aaa\n\nbbb"` に
    なっていた。文字数は変わらないので長さの比較では見つからず、見た目には
    行が増える。上下を繰り返すとその空行が行間を渡り歩く。報告により発覚。
  * **バグ修正**: Leader メニュー (`M-m`) のラベルが一部出ていなかったのを
    直した。`which-key-add-description` が `equal` で比較していたため、
    **まだ空のキーマップ同士が「同じもの」になっていた** (sparse keymap は
    リストなので、中身が空なら構造が一致する)。`*leader-project-map*` と
    `*leader-git-map*` はどちらも中身が別ファイル (`project.l`, `git.l`) で
    入るため `leader.l` の時点では空で、後から登録した方が前の方の登録を
    delete していた。結果 `p:Project+` が `p:prefix+` と表示されていた。
    `eq` 比較に直した。これは今回の追加以前からあった問題。
  * Leader メニューの並び順を「サブメニューが先、その中はキーの文字コード順」
    に揃えた。sparse keymap の中身は定義した順ではなく逆順に並んでいるので、
    そのまま出すと読み手には無秩序に見えていた。区切りも 2 文字空けから
    1 文字空けにして、根メニューの表示幅を 140 桁から 125 桁に縮めた。
  * ウィンドウ分割の状態を戻す / やり直す `winner-undo` / `winner-redo` を
    追加した (`lisp/winner.l`、`Leader w u` / `Leader w r`)。#30
    「ワークスペース・ウィンドウ管理」の 1 項目。「分割して覗いて、閉じた
    つもりが元の形に戻らない」を無くすのが目的。`*post-command-hook*` で
    構成の変化を見張り、変わる直前の構成を溜めておく。
    `current-window-configuration` は不透明な値で比較できないので、変化の
    検出には「ウィンドウごとのバッファ名と大きさ」を並べた署名を使う。
    **署名は並べ替えて持つ。** そうしないと選択中のウィンドウを移すだけ
    (`C-x o`) でも「構成が変わった」ことになり、`Leader w u` が「さっきの
    ウィンドウへ戻る」だけの操作に化ける。`unittest/winner-tests.l` に
    11 件。打鍵ごとに呼ばれても記録が増えないこと (これが効かないとリングが
    1 文字ごとに埋まる) も見ている。
  * 定型コードの挿入 (スニペット) を追加した (`lisp/snippet.l`)。#30
    「スニペット補完 (Yasnippet 相当)」の 1 項目。テンプレートの書き方は
    yasnippet と同じ (`$1`, `${1:既定値}`, `$0`, `$$`)。`Leader c e` で
    点の直前の略語を展開、`Leader c i` で一覧からファジー絞り込みで選んで
    挿入、`M-i` で次の入力位置へ移動する。既定値は **選択された状態で入る**
    ので、そのまま打てば置き換わり、`M-i` で次へ行けば残る。
    同じ番号を 2 度書くとミラーになる
    (`for (int ${1:i} = 0; $1 < ${2:n}; $1++)` がそのまま書ける)。
    値の書き替えに追随はしない -- そこまでやると挿入後もバッファの変更を
    監視し続けることになる。
    入力位置の追跡にはマーカーを使う。オフセットで覚えると、先の位置を
    長い名前に打ち替えた分だけ後ろの位置がずれる (テストで確認している)。
    **端末で実際に打って 1 つ直した**: 既定値の選択を
    `(start-selection 2 nil)` で作ると `self-insert-command` の
    「打ったら選択範囲を置き換える」経路に入らず、`defun` を展開して
    `foo` と打つと `namefoo` になった。第 2 引数を t (pre-selection) に
    することで直った。`unittest/snippet-tests.l` に 22 件。
  * 外部フォーマッタ連携を追加した (`lisp/formatter.l`、`M-x format-buffer`)。
    #30「コード保存時の自動フォーマット」の 1 項目。モードに応じた
    コマンド (`clang-format`, `prettier`, `black`, `shfmt` 等、表は
    `*formatter-alist*`) にバッファを流し込み、結果に差し替える。
    **一番大事なのは失敗したときにバッファを壊さないことである。**
    フォーマッタは入っていないこともあれば、構文エラーで何も出さずに
    終わることもある。そのまま差し替えるとファイルが空になる。
    「起動できなかった」「終了コードが 0 でなかった」「出力が空だった」の
    いずれでもバッファに一切触らない。差し替えるのは 0 で終わって、
    空でない出力が、今の内容と違うときだけ。
    保存時の整形 (`*format-on-save*`) と空白の掃除
    (`*on-save-trim-trailing-whitespace*`, `*on-save-ensure-final-newline*`)
    は **どれも既定で無効** にしてある。保存のたびにユーザのファイルを
    黙って書き換える設定を、こちらが勝手に入れるべきではない。既にある
    行末空白を一斉に落とすと、共同作業しているリポジトリでは差分が本題を
    埋めてしまう。`M-x format-buffer` は既定でも使える。
    `unittest/formatter-tests.l` に 18 件。**外部コマンドを実際に起動して
    いる**: 成功して内容が変わる経路は「入力の前に 1 行足すだけの .cmd」を
    テスト内で作って使い (Wine の cmd には `sort` が無く `more` は入力を
    そのまま返すだけなので、変換するフィルタは自分で書くしかない)、
    `cmd /c more` / `cmd /c exit 1` / `cmd /c break` / 存在しないコマンドで
    残りの経路を見ている。`*before-save-buffer-hook*` は
    `run-hook-until-success` で **non-nil を返すと保存が中止される** ので、
    全部有効にした状態で nil を返すことも見ている。
  * ncurses フロントエンドの画面を確認する道具を足した
    (`tools/pty-drive.py`、`tools/x pty`)。pty に繋いで打鍵を流し込み、
    画面をテキストで吐く。Linux ビルドには Lisp テストスイートが無く (#49)、
    `tools/linux-smoke.sh` は「プロセスが起動する」ところまでしか見ないので、
    **画面に何が描かれるか**を見る手段がこれまで無かった。実際にこれで
    「自動ペア挿入が端末側でも効いている」ことを確認できた
    (`(defun foo (x` と打つと `(defun foo (x))` になる)。
    `\e\e` (eval-expression) の結果がステータス行に出るので、動いている
    エディタにその場で質問できる。
  * ファジー絞り込みの候補を縦に並べるようにした (`lisp/fuzzy-complete.l`、
    Vertico 相当)。#30「汎用縦型ミニバッファ補完」の 1 項目。画面を分割した
    `*Candidates*` ウィンドウに 1 行 1 件で並べ、1 行目にプロンプトと
    打ちかけのクエリと件数、選択行の行頭に `>` を出す。選び終わると
    `save-window-excursion` でウィンドウ構成が元に戻る。
    `*fuzzy-vertical*` を nil にすると従来のステータス行 1 行の表示になる。
    **縦型を既定にしたのは、`M-x` のように候補が 650 件ある相手では
    1 行に数件しか入らず、絞り込みが効いているのかどうかが目で見えない
    ため。** 実際の端末で見ながら作ったので、途中で 2 つ直している:
    (1) ステータス行に出したクエリが候補バッファ書き換え後の再描画で
    消えるので、クエリはウィンドウの 1 行目に自分で持つことにした
    (打っている文字が見えないのは致命的)。(2) 候補を描いてから
    ステータス行を書く順序にした。
    確認は `tools/x pty` (本リリースで追加) で行った。
  * `M-x` をファジー絞り込みにした (`lisp/fuzzy-mx.l`、`Leader SPC` も同じ)。
    #30「ミニバッファ・補完 UI の強化」の 1 項目。素の `M-x`
    (`execute-extended-command`) は `interactive` の "C" 指定から C++ 側の
    `read-command-name` を呼ぶので絞り込み方に手を入れる隙が無く、
    コマンド名の一覧を Lisp 側 (`do-all-symbols` + `commandp`) で作って
    `lisp/fuzzy-complete.l` の絞り込みループに渡す形にした。autoload の
    スタブも `commandp` なので、まだ読み込んでいないライブラリのコマンドも
    候補に出る (素の `M-x` と同じ範囲になる)。直前に実行したものが先に
    並ぶ履歴も付けた。`*fuzzy-mx-mode*` を nil にすると従来の
    `read-command-name` に戻る。
  * ファジー絞り込みを空白区切りの順不同マッチ (Emacs の orderless 相当)
    に対応させた (`lisp/fuzzy-complete.l`)。`buf list` で `list-buffers`、
    `find file` で `find-file` が出る。トークン 1 つずつは今までと同じ
    「順序を守った部分列一致」のままなので、絞り込みの効き方は変わらない。
  * ファジー絞り込みの候補表示をステータス行の幅に合わせた
    (`lisp/fuzzy-complete.l`)。選択中の候補を必ず含めたうえで前後へ広げ、
    入り切らなかった側に `…` を付ける。**あわせて、絞り込み結果自体を
    表示件数で切っていたのをやめた。** これは表示の都合ではなくバグで、
    `*fuzzy-max-candidates*` (既定 15) より後ろの候補は `C-n` で選ぶことが
    できなかった。650 件あるコマンド名を相手にする `M-x` では致命的になる。
  * ファジー絞り込みのスコアに「一致が散らばった分」のペナルティを足した
    (`lisp/fuzzy-complete.l`)。単語区切り直後の一致ボーナスだけだと、長い
    名前の中に文字がばらばらに散っているものがボーナスを何度も稼いで上に
    来てしまう。実例: `buf` で `save-buffer` よりも
    `backward-delete-char-untabify` (b...u...b...if) が上に出た。
  * ファジー絞り込みのループ (`fuzzy-completing-read`) にテストを付けた。
    `read-char` を差し替えて打鍵列を流し込む形なので、キーマップを経由
    しないだけでループの中身は実際の操作と同じ経路を通る。これまで
    純粋な関数 (スコア計算・絞り込み) だけがテストされていて、`C-n`/`C-p`/
    `C-h`/`C-u`/`C-g` の分岐は一度も動かされていなかった。
  * バッファ内の関数・クラス・見出しの一覧から選んでジャンプする `imenu` を
    追加した (`lisp/imenu.l`、`Leader c s`)。#30「IDEライクなコード閲覧」の
    1 項目。選択は `lisp/fuzzy-complete.l` のファジー絞り込みで行う。
    xyzzy には既に `M-x list-function` があるが、(1) Win32 のダイアログ
    ボックスなので ncurses フロントエンドでは使えない、(2) 索引を作れるのは
    `build-summary-function` を持つモードだけで、それは Lisp・C 系・Java・
    Basic の 4 系統しかない (Python・JavaScript・Markdown・シェル・Makefile
    等は何も出ない)、(3) 絞り込みが無い、の 3 点で足りない。
    **既にあるものを置き換えず、足りない所だけを足す形にした。** 正規表現で
    索引を作る汎用の仕組み (`*imenu-generic-expression-alist*`) を新設して
    12 のモードを埋め、`build-summary-function` を持つモードではそれを
    そのまま呼ぶ。C 系の「だいたい」の関数抽出 (`lisp/cfns.l`) を書き直す
    必要は無い。`list-function` も `Leader c f` から引き続き使える。
    正規表現は 1 行で完結するものだけにしてある: 複数行にまたがる宣言
    (C の戻り値型だけ別の行にある関数定義など) を正規表現で当てにいくと
    誤検出のほうが増えるので、そういうモードは
    `build-summary-function` 側に任せる。
    `unittest/imenu-tests.l` に 14 件。モードごとに「拾ってほしい行」と
    「拾ってほしくない行」を同じバッファに混ぜて結果を丸ごと比較している
    (正規表現の間違いは「拾えない」か「拾いすぎる」のどちらかになる)。
  * 現在行 (選択中なら選択範囲に含まれる行) をそのまま 1 行上/下へ移動する
    `move-text-up` / `move-text-down` を追加した (`lisp/move-text.l`、
    `M-↑` / `M-↓`)。#30「編集体験の強化」の 1 項目。同じことは `C-k` して
    `C-y` でもできるが、それだと kill-ring を潰す (貼り付け待ちの内容が
    消える) 上に選択範囲が失われる。ここでは行単位の 2 ブロックを文字列
    として入れ替えるだけにして、kill-ring には触らず、選択範囲は移動後の
    同じテキストへ張り直している。**唯一の面倒はバッファ最終行に改行が
    無い場合で**、素朴に 2 ブロックを連結すると改行の位置が食い違って
    2 行が 1 行に潰れる。改行を持たないブロックが前へ来るときに改行を足し、
    後ろへ回るブロックから末尾の改行を落とすことで吸収した。この形を含む
    14 件のテストを `unittest/move-text-tests.l` に置いてある。
  * 括弧・引用符の自動ペア挿入を追加した (`lisp/autopair.l`、既定で有効、
    `M-x toggle-autopair` / `Leader t p` でオフ)。#30「編集体験の強化」の
    1 項目。`(` `[` `{` `"` を打つと閉じ側も入り、閉じ側を自分で打つと
    重ねずに乗り越え、空の対の中で `BS` を押すと 2 文字まとめて消え、
    選択したまま開き括弧を打つと選択範囲を囲む。
    **キーマップに割り当てていないのがこの実装の要点である。** `(` `)`
    `{` `}` は c-mode / lisp-mode / json-mode 等が既にローカルキーマップで
    奪っており (`c-electric-insert`, `lisp-electric-close` 等)、グローバル
    キーマップに置いても最も使うモードで効かない。ただしそれらはいずれも
    最終的に `self-insert-command` を通るので、`lisp/cmds.l` に
    `*self-insert-hook*` (と BS 側の `*delete-backward-hook*`) を用意して
    そこへ掛けた。フック 1 箇所で全モードに同じ挙動が効き、`{` を打てば
    c-mode の自動インデントと自動ペアの両方が走る。
    余計なことをしない方へ倒してあり、語や記号の直前、文字列・コメントの中、
    `\` の直後、繰り返し引数付き・上書きモード・キーボードマクロ実行中、
    ミニバッファの中では対にしない。`'` と `` ` `` を既定の対に入れていない
    のは、Lisp ではこの 2 つが対ではなくクォートであり、xyzzy の設定
    ファイル自身が Lisp である以上、対にすると邪魔になる場面のほうが
    多いため。`unittest/autopair-tests.l` に 30 件のテストを置いた。
  * 選択範囲を意味のある単位で段階的に広げる / 狭める `expand-region` /
    `contract-region` を追加した (`lisp/expand-region.l`、`C-=` / `M-=`、
    `Leader v` / `Leader V`)。#30「編集体験の強化」の 1 項目。押すたびに
    単語 → シンボル → 引用符の中 → 引用符ごと → 括弧の中 → 括弧ごと →
    (外側の括弧へ、以下同様) → 行 → 関数定義 → バッファ全体 と広がる。
    **段階を手続きとして順番に並べるのではなく、候補を全部作って「今の
    範囲を真に含む中で最も小さいもの」を選ぶ形にした。** こうすると
    候補の順番と実際の広がり方が食い違わず (必ず小さい順に進む)、モードに
    よって成立しない段階 (Lisp でない所の関数定義など) は候補から抜ける
    だけで、飛ばす処理を書かなくて済む。
    括弧を辿る起点だけは調整が必要だった: 点が文字列の中にあると
    `backward-up-list` が失敗する (xyzzy の S 式スキャナは文字列の中から
    外へ出られない) ので、その場合は開始引用符の位置まで戻してから辿る。
    これが無いと `(list "hi there" x)` の文字列の中から広げたときに
    括弧の段階が丸ごと抜け落ちてバッファ全体まで飛ぶ。
    `unittest/expand-region-tests.l` に 12 件。
  *
