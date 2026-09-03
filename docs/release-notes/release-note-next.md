xyzzy リリースノート
====================

  * バージョン: (未リリース)
  * リリース日: (未リリース)
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

(次のリリースで何が変わるのかを、1〜2 段落で。)


変更
----

  * **非 ASCII のホスト名とサービス名が引けるようになった** (issue #258)。
    POSIX の名前解決は UTF-8 のバイト列を取るのに、`w2s` で **CP932 に変換して
    渡していた** (Unicode 化のときの取り残し、`w2s` / `w2sl` の 44 箇所のうち
    2 箇所)。`/etc/hosts` に UTF-8 で置いた「日本.test」を引くと
    `gethostbyname: Host not found` になり、ASCII の名前は引ける、という形で
    出る。`src/core/environ.cc` の環境変数と同じく `#ifdef _WIN32` で分けた
    (Windows は ANSI の API に渡すので従来どおり)。

    **測り方に穴があった。** 最初はコマンドラインで日本語のホスト名を渡して
    測ったが、**それでは直す前でも通る**: 引数のバイト列を CP932 として読んだ
    文字列を `w2s` が CP932 へ戻すので、**2 つの誤りが打ち消し合う。**
    `(code-char #x65e5)` でコードポイントから名前を組んで初めて差が出た。
    この落とし穴はコードと `tools/linux-smoke.sh` の両方にコメントで書いた。

    確認は smoke に 1 件 (42 件になった)。**「引けた」と「つながった」を
    混ぜない**ように、127.0.0.9 の port 9 (誰も listen していない) へ
    つないで、**拒否のエラーが返ることで「解決できた」を見る。**
    無い名前 (`no-such-name.test`) を対照に置いて、`Host not found` と
    `Connection refused` の差で判定する。`/etc/hosts` を書き足すので
    **使い捨てのコンテナの中でしかやらない** (DNS の check と同じ理由で、
    触れないときは SKIPPED と言う)。
  * **端末側の `FontMetrics` のダミーを消した** (issue #261)。`FontMetrics`
    (#195) は core が GDI を直に呼ばないための seam だが、**端末には尋ねる
    相手が居ない**: `FontSet::create` は Win32 だけでコンパイルされ、端末は
    フォントを 1 度も measure しない。参照 0 件の実装が置いてあると、
    **繋がっているように見えて実は死んでいる。** 実際にそう読み違えて
    issue を立てた。

    同じ issue で「端末の `Painter` が色を捨てている」とも書いたが、**測ったら
    渡す側に色が無かった**: glyph 版の `draw_text` は色を glyph が持っており
    (`output_glyph` がそれで描く)、`fill_rect` は呼ぶ側が `CLR_INVALID` を
    渡す (端末の fill は「セルを空白にする」ことなので塗る色が無い)、罫線は
    ACS の文字で引く。**コメントが "honored in a later step" と書いてあったのが
    誤解のもと**だったので、primitive ごとに「なぜ色の引数を使わないか」に
    書き換えた。**予定として書くと、実装が足りないように読める。**
  * **`eval-in-another-xyzzy` が「結果が来なかった」ときに理由を出すように
    した** (issue #253)。子プロセスを起こして式を評価させ、結果をファイルで
    受け取るテスト用の関数で、受け取れなかったときのエラーが
    `result not sent.` の 1 行だけだった。**CI のログには落ちたテストの名前
    しか残らない**ので、次に起きたときも同じ推測から始めることになる。

    実際にそうなった: #253 では「子が `xyzzy.ini` を書き終える前に消しに
    行っている」と推測したが、**後から落ちた `xyzzy-ini-path-startup-option`
    にはその 2 つ目の値が無く、推測は外れていた。** 出すのは 3 つ — 子の
    終了コード、結果ファイルの大きさ、**子の出力** (起動に失敗したときの
    メッセージはそこにしか出ない)。

    **確認は「起きるようにして」測った**: 子に `(kill-xyzzy)` を評価させると
    結果を書く前に死ぬので、`exit-code=0 status=:exit file-length=0` と
    子の出力が出ることを見た。
  * **端末の行の打ち切りが、その関数だけで正しいと分かる形にした**
    (挙動は変えていない)。`render_glyph_row` の条件が「`x < cols` を見てから
    `x += 2`」だったので、**関数だけ読むと全角で 1 桁溢れるように見える。**
    実際に溢れないのは core の側の性質で、そこには書いていなかった:
    `Window::redraw_line` (`src/core/glyph.cc`) が
    `if (g + 1 == ge) { exceed = 1; break; }` で**全角に 1 桁しか残っていない
    ときは置くのをやめ**、fold mark に回す。**半分だけの全角は frontend まで
    来ない。**

    「残り桁に収まらない glyph は出さない」に書き換えて、**なぜ溢れないのかを
    その場に書いた。** 生のバイト列で前後を測って同じ (`window-columns` 43 の
    縦分割に全角を並べ、書き込まれる全角の個数が変わらないこと) を確認した。

    **smoke に check は足していない。** 到達できない経路なので、入れても
    絶対に落ちない check になる (`tools/linux-smoke.sh` の決まりは「入れた
    check が本当に落ちるか確かめる」)。
  * **Lisp から editor を落とせる `alloca` を 2 箇所直した** (issue #260)。
    どちらも**長さを Lisp が決める**のに `alloca` していた:

      * `gethash-region` -- リージョン長 x 4 バイト。**3MB のバッファで
        SIGSEGV** した (`src/core/hash.cc`)
      * `format` の引数配列 -- 引数の数 x 8 バイト、2 箇所。
        `(format nil "~{~A~}" (make-list 3000000))` で **SIGSEGV**
        (`src/core/lprint.cc`)

    `check_stack_overflow` は**再帰の深さしか見ない**ので、この形は捕まらない。

    **`format` の側には GC の罠がある。** 配列の中身が Lisp オブジェクトなので、
    heap に移すと `gc_mark_in_stack` から見えなくなる (`alloca` ならスタックが
    走査されるので見えていた)。`protect_gc` で明示的に根にし、**先に `nil` で
    埋めてから protect する** -- 未初期化のゴミを GC に辿らせると、以前それで
    実 Windows のアクセス違反になった (多値バッファの件)。

    **速さは測って変わらない**: 20 万回の `(format nil "~A~A~S" ...)` が
    1578 / 1587 ms (前) 対 1584 ms (後)。誤差の範囲なので、小さいときだけ
    `alloca` に戻す分岐は入れていない。

    **確認は smoke に置いた** (43 件になった)。**Lisp スイートには置かない** --
    直っていないとプロセスが落ちる種類なので、スイートに置くと run 全体が
    死んで後ろが測られなくなる。大きさは linux のスタック (8MB) を超える所に
    取ってあり、**Windows は 32MB なのでこの check は POSIX 側の番犬**である。
    負の確認: 2 つの修正を戻すと check が Segmentation fault で落ちる。

  * **`FilerView::thread_main` の `alloca` を `std::vector` に変えた** (issue
    #260)。これは Windows 専用のフォルダビューアイコン読み込みスレッドの本体
    で、外側の `while (WaitForSingleObject (...))` が**スレッド生存中ずっと
    回り続けて return しない**。`alloca` はスタックフレームが戻るまで解放
    されないので、この形では**ディレクトリを切り替えて while が 1 回転する
    たびに前回分が積み残る** -- フォルダビューアを開いたまま長時間ディレクト
    リを切り替え続けると、いつかスタックが溢れる。

    `std::vector` はブロックローカルの自動変数なので、`continue` / `break` /
    `goto term` のどの出口でも while 1 回分の終わりで確実に解放される。

    Windows 専用の経路で、手元 (Linux/Wine) では再現も再測定もできない。
    mingw クロスビルドが通ることと、`alloca` がこの関数から消えたことは
    確認済み。動作の再現・確認は CI のビルド以降になる。
  * **ConPTY reader スレッドとの排他を、格子を触る GUI 側の残り 2 箇所へ
    広げた** (issue #264)。PR #28 で入れた `terminal_lock ()` は reader
    スレッドの `feed ()` と、GUI スレッドの描画・リサイズだけを排他して
    いた。**選択範囲のクリップボードコピー (`terminal_copy_selection`) と
    スクロールバー操作 (`process_vscroll` の `scrollback_scroll`) は
    まだ外に居た。**

    `terminal_copy_selection` は格子のセル (`display_cell`) を読んでいる間
    だけロックする (クリップボード API 呼び出しは格子を触らないので外)。
    `process_vscroll` は `scrollback_scroll` が書く `t_scrollback_offset`
    を、reader スレッドの `feed ()` も新しい出力が届くたびに直接書いている
    (スクロールバックを追っている最中にライブ表示へ戻す処理、
    `src/core/term.cc` の `feed ()`) ので、両方をロックの下に入れて排他する。

    スクロールバーのカウンタ表示 (`update_vscroll_bar` / `vscroll_lines`)
    はカウンタの読みだけで torn read にならないので対象外 (issue に書かれた
    優先度どおり)。データ競合自体は CI では測れない (経路は Wine の ConPty
    で走るが、競合の検出手段が無い) ので、確認は mingw クロスビルドが通る
    ことと `CRITICAL_SECTION` の再入 (同一スレッドなので許される) の形を
    崩していないことに留まる。
  * **端末で黙って `nil` を返すだけだった 3 関数をエラーにした** (issue
    #259)。`ncurses-stubs.cc` の「何もせず `nil` を返すだけ」の 98 箇所を
    見直し、3 件が**間違って `nil` 側に居た**と分かった:

      * `si:get-key-state` -- Win32 の `GetKeyState` は「今この瞬間」の
        物理キー状態をいつでも問い合わせられるが、端末には修飾キーの
        継続的な押下状態を知る手段が無い。「押されていない」と黙って
        答えるのは、実際に押されている時に誤った答えを返す
      * `set-ole-event-handler` -- 同じグループの兄弟関数 (`ole-create-object`
        ほか 11 個) は全部エラー化されているのに、これだけ変換漏れ
      * `convert-to-SFX` -- 同じグループの兄弟関数 (`create-archive` ほか)
        は全部エラー化されているのに、これだけ変換漏れ。しかもこの関数
        の直前にあるコメント自身が「扱うものはエラー」と書いていた

    3 件とも `unsupported-on-this-platform` に揃えた (既存の仕組みで、
    新しい仕組みは足していない)。確認は `--batch` で3つとも呼んで
    `handler-case` がエラーを捕まえることを見た。

    **待機オブジェクト (`si:*create-wait-object` ほか) は直さなかった。**
    issue #222 で調べ済みで、オブジェクトの側は移植できるが「待つ相手」
    (`xyzzycli` に相当するプログラム) が POSIX に 1 つも無いので、
    ここだけ直しても機能は 1mm も動かない。**コメントの根拠は誤っていた**
    (「`Buffer::cleanup_waitobj_list` から無条件に触るので」と書いてあったが、
    端末版の同関数は自前の空実装で wait-object を一切触らない) ので、
    そこだけ #222 の結論に合わせて直した。

    残り 89 件は既存のコメントで「nil が正しい答え」と説明済みだった
    (issue #185 以降の作業で分類が進んでいたので、今回の対象はその後に
    残っていた分)。未実装だが実装できる側 (`si:search-path` / `eject-media`)
    と、判断が割れる側 (`current-kbd-layout` 系 2 件) は今回は対象外。
  * **`si:getenv` / `si:putenv` に長い文字列を渡すと SIGSEGV で落ちていた
    のを直した** (issue #286)。`environ.cc` の POSIX 側と Win32 側の 4 箇所
    で、`alloca` のサイズが呼び出し元の文字列長そのものだった。33MB の文字列で
    スタック (8MB) を超え、即座にページフォルト。`alloca` を `std::vector`
    に変更した。

