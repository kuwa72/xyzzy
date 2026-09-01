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

**もう 1 つの柱が端末版 (Linux / POSIX) である。** 前の回で「起動して編集して
保存できる」ところまで来ていたが、この回で**日常的に使える**ところまで来た。
Lisp テストスイートは走るようになり (走っていなかった -> 1210 件)、既知失敗は
158 件から 10 件に減った。残る 10 件は**全部「POSIX に対応物が無い」側**
(user32 / kernel32 の API、待機オブジェクト、OLE、ダンプイメージ) である。

**端末版で見つかった不具合は「無い」よりも「黙って違うことをする」が多かった。**
それが最後まで残っていた理由でもある:

  * 日本語のプロンプトが**全部化けていた** (`名前を入れて:` が
    `琥悴筵噤燃黎:`)。バッファのテキストは正しく出るので画面を見ても
    気付かない
  * キーボードマクロの `C-x (` が**黙って成功したように見えて**、次に
    `C-x )` を押したときに初めて分かる
  * `rename-file` が `:if-exists` を見ずに**行き先を消していた** (既定は
    `:error` なのに)
  * `:supersede` で書いたファイルが **0600** になり、コンテナで
    バイトコンパイルすると `.lc` が読めなくなる
  * 行番号・改行の印・ルーラが**既定で出ていなかった** (描く側は最初から
    実装済み)

**「実装が無い」と書いてあった所の多くは、実装済みで繋がっていなかっただけ
だった。** ミニバッファの入力 17 個、`save-window-excursion`、タイマ、
表示フラグ、キーボードマクロ — どれも土台は core にあり、フロントエンドに
`return Qnil` のスタブが挟まっていた。既知失敗リストの「理由」も測り直すと
ほぼ外れていて、**27 件が「`--batch` には画面が無いから仕方ない」と書かれて
いたが、27 件とも実装の問題だった。**

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

  * **`si:octet-length` の既定を `*default-fileio-encoding*` に寄せた**
    (issue #154)。**戻り値が変わる:** `(si:octet-length "abcあいう")` は
    9 (CP932) ではなく 12 (utf8n) を返す。

    **既定が 2 つ存在していた。** このフォークは `*default-fileio-encoding*`
    を UTF-8 にしているのに、「保存したら何バイトか」を聞く関数の既定が
    CP932 だった。

    リファレンスには元々「デフォルトはエンコーディング変換なし」と書いて
    あった。**内部表現が CP932 のバイト列だった頃はそれが正しかった**
    (変換しないことと CP932 で数えることが同じだった)。内部表現が Unicode に
    なったあと「変換なし」に当たるものは無くなり、実装 (`w2sl`) だけが CP932 を
    数え続けていた。**説明が 2 世代古かった。**

    `symbol_value_char_encoding` を通すので、**変数に自動判別や
    エンコーディングでない値が入っていても落ちない** (CP932 に落ちる)。
    `Buffer` が生成時に既定を読む経路と同じ扱いにした。**落ちる実装にすると、
    `*default-fileio-encoding*` を触った設定ファイルで `si:octet-length` が
    全部エラーになる。**

    測って分かったことが 1 つある。**`let` で `*default-fileio-encoding*` を
    束縛しても、この既定には効かない。** C++ 側が `xsymbol_value` で
    シンボルの値セルを直接読むためで、`Buffer` の初期化と同じである。
    **正しいと言い切れる話ではない**ので、
    `octet-length-default-ignores-a-let-binding` で書き留めて、
    動的束縛を見る形に変えるなら何を直すかをコメントに残した。

    `unittest/system-tests.l` に 6 件足した (既定が変数を読むこと、変数が
    壊れていても落ちないこと、`let` が効かないこと、`:start` / `:end` が
    既定でも効くこと、**リファレンスの補足に書いた数がその通りであること**)。
    最後のものは、**リファレンスだけが古くなるのを機械に見張らせるため**で
    ある — この関数はまさにそれで壊れていた。

  * **`clipboard` と `status_area` を `Application` から出した** (issue #195)。
    `src/frontend/win32/clipboard.h` / `statarea.h` になり、実体は
    `g_clipboard` / `g_stat_area` としてフロントエンドが持つ。**core の
    `HWND` は 117 から 105 になった。**

    **これで #185 §1 の「GUI のヘッダを core から出す」は終わり。**

    #185 はここを **「`Application` のメンバの型なので、`Painter` (#13) と
    同じ形の抽象化が要る」** と書いていた。**測ると抽象化は要らなかった。**
    `src/core/` の中から `app.clipboard` も `app.stat_area` も触っていない。
    触っているのは `toplev.cc` (11 か所) と `disp.cc` (1 か所) だけで、
    **どちらも `src/frontend/win32/` の中**である。

    **`Application` のメンバであることが唯一の理由だった。** `ed.h` を
    include する全ての翻訳単位が 2 つのクラスの定義を要求するので、
    ヘッダは core に残り続ける。抽象基底を作る必要はなく、**メンバをやめて
    フロントエンドが持てば済んだ。**

    ここでも**同じ構図で 5 セット目**が出た。POSIX の 2 つのフロントエンド
    から消えたもの:

    ```cpp
    /* clipboard が Application のメンバなので、端末とヘッドレスも
       コンストラクタを埋めるしかなかった。中身は Win32 のフィールドを
       0 にするだけで、その後 1 度も読まれない */
    clipboard::clipboard () { hwnd_next_clipboard = 0; ... }

    /* CLIPBOARDTEXT が core のヘッダに居たので型が見えていたが、
       呼ぶ側は win32 の中にしか無かった = 誰も参照しないシンボル */
    int make_clipboard_text (CLIPBOARDTEXT &, lisp, int) { return 0; }
    int make_string_from_clipboard_text (lisp, const void *, UINT, int) { return 0; }
    ```

    **`clipboard` は Lisp の `copy-to-clipboard` の経路ではない。** あちらは
    `Frontend::copy_to_clipboard` を通る。こちらは**他のアプリがクリップ
    ボードを書き換えたことを知る**ための仕掛け (`*clipboard-change-hook*`) で、
    Win32 のウィンドウメッセージを捌く。**名前だけでは区別できないので、
    両方のヘッダにその旨を書いた。** `status_area` と
    `app.status_window` も同様に別物である (後者は下のバーのメッセージで、
    core が使う)。

    この作業で**クリップボードの Lisp 入口 3 つ (`copy-to-clipboard` /
    `get-clipboard-data` / `clipboard-empty-p`) にテストが 1 件も無い**ことが
    分かった。この変更は `Frontend::copy_to_clipboard` に触っていないので
    影響は無いが、**次にこの経路を触るときに支えが無い。** 何を測るべきかを
    issue #198 に書いた (端末は無条件に測れるが、**Win32 の round-trip を
    CI で測ると flaky になる危険がある** — runner がセッションを持たない
    文脈で走るため)。

  * **GDI で線と矩形を描く道具を core から出した** (issue #195)。
    `fill_rect` / `draw_hline` / `draw_vline` / `paint_button_*` と
    `frameDC` で、`src/frontend/win32/gdi-utils.{h,cc}` になった。
    **core の `HDC` は 72 から 58 になった。**

    **issue #185 はここを「`Painter` に同じ primitive があるので寄せられる」
    と書いていたが、測ると寄せる先が要らなかった。** `src/core/` の中から
    これを呼んでいるコードが**1 つも無い**。呼んでいるのは
    `disp.cc` / `Window.cc` / `dockbar.cc` / `toplev.cc` / `fnkey.cc` /
    `ColorDialog.cc` / `ChooseFont.cc` / `print.cc` / `pane.cc` の 9 つで、
    全部 `src/frontend/win32/` の中である。**core が `HDC` を 15 個抱えて
    いた理由は「core が使っているから」ではなく、置き場所だけだった。**

    `find_handle` / `wnet_enum_handle` は `utils.h` に残した。**`HANDLE` は
    `HDC` と違ってデバイスの話ではなく**、`pathname.cc` / `glob.cc` /
    `completion.cc` が実際に使っている。

    移すときに `paint_button_*` の `#if 0` (ペンと `SetPixel` で Windows 95 風
    の 3D の縁を描く版) を見つけたが、**消さずに移した。消す判断は「見た目を
    どうするか」であって置き場所の話ではない**ので、無効であることを
    コメントに書いて残した。

  * **描画の抽象化 (`Painter` / `FontMetrics`) の追跡先を作り直した**
    (issue #195)。**コード中の 47 箇所が「issue #13」を追跡先として書いていた
    が、この番号は issue ではなくマージ済みの PR に取られていて**、追っても
    描画の話は出てこない (「標準添付 Lisp ライブラリの一覧ドキュメント」)。
    issue #185 の実測で見つかった。

    **実際に誤読を起こしている。** 直前の作業で「次は #13 (Painter) に
    進む」と書いてから、開いて初めて別物だと分かった。**番号は自動で
    検算されないので、間違っていても静かに残る。**

    ついでに 2 つのコメントを直した。どちらも**古くなったまま読まれていた**:

    * `src/core/painter.h` の冒頭が「Phase: Step 1 (this file) / Step 2 /
      Step 3」で止まっていた。**段階 5 まで済んだ後も「段階 1 が現在地」と
      書いてあり、そう読まれた。** 段階の一覧はここから消して issue へ集め、
      **「段階の一覧をここに書き直すな」と理由付きで書いた。**
      `src/core/font-metrics.h` の「5a (this file)」も同じ
    * 同じコメントが `disp.cc` の**行番号** (「around 403-748」) を指して
      いた。**その範囲は今どちらの関数も指していない。** 他のファイルの行
      番号をコメントに書かない、と理由を残した

    コードの動きは変わらない (コメントとドキュメントだけ)。

  * **タブバーのバッファ順を seam にして、GUI のヘッダ 3 つを core から出した**
    (issue #185)。`buffer-bar.h` / `dockbar.h` / `DnD.h` で、`HWND` を 26 個
    抱えていた。core の `HWND` は 141 から 120 になった。

    core の側にあったのは `src/core/Buffer.cc` の `#ifdef _WIN32` で囲んだ
    6 行だけである。**バッファには 2 つの並び順がある:**

    | | 何の順か | 誰が持っているか |
    | --- | --- | --- |
    | 内部の順 | 最後に選んだものが先頭 | `Buffer::b_blist` (core) |
    | タブの順 | タブに並んでいる見た目の順 | バッファバー (Win32 の GUI) |

    `buffer-list` の `:buffer-bar-order` と `get-next-buffer` の TAB-ORDER が
    後者を指す。**後者はフロントエンドの持ち物なので、`frontend_tab_order_*`
    (`src/core/fns.h`) に出した。**

    **seam が返す「無い」は 0 で、nil ではない。** タブバーは Win32 でも
    `buffer-bar` コマンドを実行するまで存在せず、そのときの
    `:buffer-bar-order` は内部の順に落ちる、というのが元の振る舞いである。
    `frontend_tab_order_buffer_list` が `lisp` を返すのに `Qnil` ではなく 0 を
    返すのはこのためで、**「タブバーが空」と「タブバーが無い」を区別する
    必要がある。** ここを `Qnil` にすると `(buffer-list :buffer-bar-order t)`
    が全バッファを落として nil を返す。

    **この 2 つの Lisp の入口は 1216 件のスイートに 1 件も無かった。**
    `unittest/buffer-order-tests.l` に 8 件置いた。**バーを作らない状態は
    Win32 と端末で同じ**なので、`featurep` で分けていない。

    POSIX 側から消えたのは、`#ifdef _WIN32` で囲まれて**死んでいた**
    `buffer_bar::` の空実装 6 行 (両方のフロントエンド) である。GUI の
    クラスが core のヘッダに居たので**一度は書かれ、それから `#ifdef` に
    切られていた。**

  * **GUI のクラス 2 つを core から出した** (issue #185)。`XMessageBox`
    (`src/core/msgbox.h`) と `FKWin` (`src/core/fnkey.h`) で、core の `HWND`
    は 150 から 141 になった。

    **どちらも「core に残す数」と「win32 へ出す GUI クラス」に割れた:**

    | ヘッダ | core に残したもの | win32 へ出したもの |
    | --- | --- | --- |
    | `msgbox.h` | ボタンの番号 (`MSGBOX_IDBUTTON1`..) と seam (`MsgBox` / `MsgBoxEx`) | `XMessageBox` (`xmessagebox.h`) |
    | `fnkey.h` | `MAX_Fn` / `MAX_FUNCTION_BAR_LABEL` (ラベルの数え方) | `FKWin` と `fnkey_wndproc` (`fkwin.h`) |

    **残す側の基準は「Lisp から見える値かどうか」。** `message-box` の戻り値は
    `:button1`..`:button5` なので**番号は API の一部**であり、
    `MAX_FUNCTION_BAR_LABEL` は**端末のフロントエンドも読む**
    (ラベルを入れるベクタの大きさ)。

    **GUI のクラスが core にあると、端末側もそのメソッドを埋める必要がある。**
    `ncurses-stubs.cc` と `cli-stubs.cc` の両方から消えた:

    ```cpp
    void XMessageBox::add_button (UINT, const Char *) {}
    void XMessageBox::set_button (int, UINT, const Char *) {}
    int XMessageBox::doit (HWND) { return IDOK; }
    int FKWin::fk_default_nbuttons = 10;
    ```

    ラベルの数の設定値は `g_fnkey_default_nbuttons`
    (`src/core/environ.h`) に出した。**ini に保存される設定値で、GUI の話では
    ない。** ここで 1 つ判断が要った: Win32 は 0、POSIX のスタブは 10 で
    初期化していた。**Win32 の `FKWin` のコンストラクタが `fk_divinfo` に
    無い値を見たら 12 に落とす**ので、0 の実際の意味は 12 である。core の
    変数は 0 (= 未設定) にした。**POSIX 側の 10 は ini に 10 と書く以外の
    効果が無かった** (端末にファンクションバーは無いので誰も読まない)。

    **これで #185 の §1 で機械的に片付く分は終わり。** 残るのは設計を伴う
    2 件である:

    * `dockbar.h` (HWND 21) — `core/buffer-bar.h` が include している。
      動かすには `Buffer.cc` の**バッファの並び順 6 か所** を「タブバーの
      バッファ順」という 1 つの seam にする必要がある (この次の項目で
      やった)
    * `clipboard.h` (11) / `statarea.h` (2) — `Application` (`ed.h`) の
      **メンバの型**なので、`Painter` (#195) と同じ形の抽象化が要る

  * **`g_frame` をフロントエンドの hook にして、GUI のヘッダ 2 つを core から
    出した** (issue #185)。`mainframe.h` / `pane.h` で、これで core の
    `HWND` は 178 から 150 になった。

    core の側にあったのは `#ifdef _WIN32` で囲んだ 2 行である:

    ```cpp
    /* src/core/cmdloop.cc -- ツールバーのボタンからコマンドを引く */
    command = g_frame.lookup_command (c);
    /* src/core/data.cc -- GC の mark */
    g_frame.gc_mark (gc_mark_object);
    ```

    **この 2 行のために、POSIX のフロントエンドが Win32 専用のオブジェクトを
    作っていた。** `ncurses-stubs.cc` と `cli-stubs.cc` の両方に

    ```cpp
    #ifdef _WIN32
    dock_frame::dock_frame () : f_hwnd (0), f_arrange (0) {}
    void dock_frame::gc_mark (void (*)(lisp)) {}
    splitter::splitter () { ... }
    main_frame g_frame;
    #endif
    ```

    が置かれていた。**Windows でビルドする端末版・ヘッドレス版が、core が
    `g_frame` を直に触るために `main_frame` を 1 つ作る**必要があったので
    ある。hook (`frontend_lookup_tool_command` / `frontend_gc_mark`) にしたら
    両ファイルから丸ごと消えた。

    **GC の mark を hook にするのは取りこぼすとオブジェクトが回収される**
    ので、宣言のコメントに「フロントエンドを足すときはここを埋め忘れない
    こと」と書いた。

    **`splitter` のデストラクタだけが別の節に離れて置かれていて、x86_64 の
    ビルドが落ちた。** `dock_frame` / `splitter` / `g_frame` のスタブは
    1 か所にまとまっていると思っていたが、380 行離れた「Splitter dtor stub」
    という節にもう 1 つあった。**linux は `#ifdef _WIN32` の中なので通って
    しまう。**

    `dockbar.h` (HWND 21) はまだ core に居る。`core/buffer-bar.h` が
    include していて、そこを動かすには `Buffer.cc` の「バッファの並び順は
    タブバーに従う」6 か所を seam にする必要がある。

  * **GUI のヘッダ 3 つを `src/core/` から `src/frontend/win32/` へ移した**
    (issue #185)。`Filer.h` / `dialogs.h` / `privctrl.h` で、**端末ビルドで
    一度も使われないのに core に居た。**

    core の側にあったのは `src/core/Buffer.cc` の 1 行だけである:

    ```cpp
    #ifdef _WIN32
      Filer::close_mlfiler ();   /* xyzzy を終わらせる直前 */
    #endif
    ```

    **この 1 行のために、ヘッダ 3 つが core に居続けていた。** フロントエンドの
    hook (`frontend_before_kill_xyzzy`) にして、core から `Filer` への参照を
    無くした。両フロントエンドの `Filer::close_mlfiler` のスタブ定義も要らなく
    なった。

    **hook を `#ifdef _WIN32` の中に置いてはいけない**ことに 1 度引っかかった。
    以前は core の呼び出しも定義も `#ifdef` で囲まれていて釣り合っていたが、
    hook は core が**無条件に**呼ぶので、POSIX でも定義が要る。

    **残りは「機械的に動かせる」わけではないことが分かった。** #185 は 10 個の
    ヘッダを挙げているが、実際に測ると core が中身を使っている:

    | ヘッダ | core が何に使っているか |
    | --- | --- |
    | `clipboard.h` / `statarea.h` | `Application` (ed.h) のメンバの型 |
    | `msgbox.h` | `lprint.cc` が `XMessageBox::IDBUTTON*` を見る |
    | `buffer-bar.h` | `Buffer.cc` がバッファの並び順に使う (`buffer_bar::next_buffer` ほか) |
    | `mainframe.h` / `dockbar.h` / `pane.h` | `cmdloop.cc` と `data.cc` が `g_frame` を使う (ツールバーの ID からコマンドを引く / GC の mark) |
    | `fnkey.h` | `environ.cc` が `FKWin::default_nbuttons ()` を ini から読む |

    **試しに `mainframe.h` の include を core から外したら、Windows ビルドが
    `g_frame` で落ちた。** 使っている 2 か所はどちらも `#ifdef _WIN32` の中だが、
    **Windows ではその中が本当にコンパイルされる。** ここを動かすには hook が
    2 つ (ツールバーのコマンド引きと GC の mark) 要るので、別の作業になる。

  * **実時間を待つテストが 1 件、固定の `sleep-for` で書かれていて flaky
    だった。** `flymake-idle-check-runs-after-a-pause` が

    ```lisp
    (ed::flymake-schedule)
    (sleep-for 0.5)
    ```

    としていた。**タイマが起きて、さらに子プロセス (`echo`) が走って回収
    されるまでを 0.5 秒の枠に押し込む**ことになるので、機械が混んでいると
    落ちる。実際に落ちた — **コメントだけの変更を挟んだ前後で落ちたり通ったり
    したので、コードのせいではないと分かった。**

    `unittest/timer-tests.l` には**既に正しい形があった** (`timer-test-wait`:
    条件が真になるまで刻んで待ち、諦める期限を長く取る)。同じ形にした。通る
    ときは 0.1 秒ほどで抜けるので、スイート全体は遅くならない。

  * **no-op のままにしたものに「なぜ no-op でよいか」を書いた** (issue #185)。

    上の分類で「エラーを上げる」ものは名前で分かるが、**残したものは
    「まだ書いていない」のか「そもそも無い」のかが読んでも分からない。**
    書いていないと、次に見た人が A と区別できない。

    群ごとに理由を置いた: フォント / IME / ツールバー / タブバー /
    ファンクションバー / マウスカーソルの形 / 砂時計カーソル /
    `do-events` / `get-window-handle` / ネットワークの共有の一覧 /
    ショートカット / プラグインの引数 / xyzzy のウィンドウ間の行き来。

    **理由は 3 通りに分かれた:**

    * **端末にその概念が無いので nil が正しい答え** — `get-window-handle`
      (ハンドルは無い)、`filer-modal-p` (filer は開いていない)、
      `list-servers` (サーバは無い)、`resolve-shortcut` (.lnk ではない)
    * **飾りなので何もしないのが正しい** — ツールバー、タブバー、砂時計
      カーソル。**`lisp/filer.l` の `long-operation` などが無条件に呼ぶので、
      エラーにすると使えなくなる。** `startup.l` が起動時に
      `system:*show-window-foreground` を呼ぶのも同じ形
    * **「無い」ではなく「まだ書いていない」** — `eject-media` は端末でも
      意味がある (POSIX なら `eject` か `CDROMEJECT` の ioctl)。ここは
      **そう書いておかないと「無い」と読まれてしまう**

  * **端末で使えない機能が「黙って nil を返す」のをやめた** (issue #185)。

    ```
    M-x filer   ->   この環境では使えません: filer
    ```

    `src/frontend/ncurses/ncurses-stubs.cc` の「`return Qnil` だけ」の関数は
    140 個以上あり、**「未実装」が圧倒的に「黙って成功を返す」形で表現されて
    いた** (エラーを上げるものは 10 個しか無かった)。この回で直した不具合も
    ほとんどがその形で、`si:putenv` が成功を返して何もしていなかった件
    (PR #147) や `format-buffer` のテスト 8 件のうち 5 件が「コマンドが起動
    できないから通る」状態だった件 (#158) も同じである。

    **ただし一律にエラーにしてはいけない。** Lisp ライブラリが無条件に呼ぶ
    もの (ツールバー、IME、待ちカーソル) をエラーにすると起動しなくなる。
    分かれ目は**「ユーザが名指しで呼んだのか、飾りなのか」**である:

    | | 何をするか | 個数 |
    | --- | --- | --- |
    | エラーを上げる | filer / OLE / DDE / アーカイバ / 印刷 / winhelp / ショートカットの作成 / キーボードレイアウトの選択 / xyzzy サーバ | 67 |
    | nil のまま | 問い合わせ (`filer-modal-p` / `filer-get-directory` / `list-servers` など)。**nil が正しい答え** (「filer は開いていない」「サーバは無い」) | 20 |
    | no-op のまま | ツールバー / タブバー / IME / `do-events` / 待ちカーソル。飾りなので何もしないのが正しい | 残り |

    **問い合わせをエラーにしないのが要点。** 第三者の Lisp が「filer は
    開いているか」を見るために呼ぶことがあり、そこでエラーにすると
    「無い」ことを確かめる手段が無くなる。

    メッセージには**その関数のシンボルを入れる** (`この環境では使えません:
    filer`)。既存の `*_not_supported` のメッセージ 5 個は**名前が入っていない
    ので何が無いのか分からない**。60 個以上あるのでメッセージを 1 つずつ
    足すのではなく、名前を datum に持たせる形にした。文字列ではなくシンボルを
    渡すのは、文字列だと `"filer"` と引用符が付くため。

  * **端末で `M-x select-buffer` が黙って何もしていなかった** (issue #187)。
    `buffer-selector` が `return Qnil` のスタブで、`lisp/buffer.l` は
    `(and buffer (switch-to-buffer buffer))` と書いているので静かに終わる。

    **ここも端末には同じ目的の道がある** — バッファ名の補完付きで聞けば、
    Win32 のダイアログと同じ「バッファを 1 つ選ぶ」ができる。
    `Kexist_buffer_name` を渡すと `complete_read` が `Ffind_buffer` を通して
    **バッファのオブジェクト**を返すので、**Win32 側と戻り値の形も同じ**に
    なる。

    既定は「他のバッファ」にした。`read-buffer-name` が同じものを使っていて、
    **バッファを切り替えるときに一番役に立つ既定**である (今いるバッファを
    既定にしても何も起きない)。

  * **端末でファイル選択のダイアログを呼ぶコマンドが黙って何もしていなかった**
    (issue #187)。

    ```
    M-x open-file-dialog          何も起きない
    M-x save-as-dialog            何も起きない
    M-x save-kbd-macro-to-file    何も起きない
    ```

    `file-name-dialog` / `directory-name-dialog` が `return Qnil` のスタブ
    だった。**端末にダイアログは無いが、同じ目的の道はある** — ミニバッファで
    ファイル名を聞く経路が issue #114 で動くようになっている。そこへ繋いだ。

    キーワードは 13 個あるが、**端末で意味があるのは 5 つだけ**
    (`:title` / `:default` / `:must-exist` / `:multiple` /
    `:initial-directory`)。残りは GUI のダイアログの部品なので無視する。

    **戻り値で 1 つ決める必要があった。** Win32 は 4 つの値 (ファイル名 /
    filter-index / エンコーディング / 改行コード) を返し、3 つ目は
    ダイアログのコンボボックスで選んだ値である。端末にその UI は無い。

    **渡された値をそのまま返してはいけない。** `open-file-dialog` は
    `:char-encoding (or *expected-fileio-encoding* t)` を渡して、戻り値を
    `(find-file files encoding)` に使う。`t` を返すと `(find-file files t)`
    になる。**char-encoding のオブジェクトなら返し、それ以外は nil を返す**
    ようにした (nil は呼ぶ側で自動判別に落ちる)。

    `:multiple t` は**リストで返す** (Win32 と同じ)。文字列を返すと
    `open-file-dialog` の `(dolist (f files) ...)` が壊れる。人が打った
    空白区切りを分ける形にした — **Win32 の複数選択の形 (先頭が
    ディレクトリ、残りが名前) は当てはまらない**: あれはダイアログが作る形で、
    ここは人が打った文字列である。

    **Win32 と 1 つだけ違う: 中止したときの答え。** あちらはダイアログの
    キャンセルで nil が返るが、端末は `C-g` なのでコマンドごと中止になる
    (ミニバッファで `C-g` を押したときの普通の振る舞い)。

    **キーボードマクロが端末で動くようになった (#181) ので、
    `save-kbd-macro-to-file` が黙って何もしないのが目立っていた。** 記録 →
    保存 → 読み直しまで通ることを確かめた。

  * **POSIX で `path-equal` と `sub-directory-p` が大文字小文字を無視して
    いた** (issue #183)。**別々に存在する 2 つのファイルを「同じファイル」と
    答える。**

    ```
                                          直す前   直した後
    (path-equal ".../a" ".../A")            t        nil
    (sub-directory-p ".../Foo/bar" ".../foo")  t     nil
    ```

    判定そのものは正しく移植されていた (`same_file_p` の後段は device +
    inode の比較で、`WINFS::GetFileInformationByHandle` が `fstat` の
    `st_dev` / `st_ino` を入れている)。**その手前の速い経路**
    (`pathname_equal`) が `_wcsnicmp` を直に呼んでいて、POSIX では
    `platform.h` がそれを `wcsncasecmp` に当てている。**`path1` が存在し
    さえすれば inode を見ずに t を返して終わる**ので、`path2` が別の
    ファイルでも同じと答えていた。

    **区別するかどうかを聞く seam は最初からあった** —
    `WINFS::case_insensitive_names` (`src/core/vfs.h`) で、ヘッダのコメントが
    「区別するかどうかはファイルシステムの性質であってフロントエンドの性質
    ではない」とまさにこの用途で置かれたことを書いている。**使っていたのは
    ファイル名補完の 1 箇所だけ**だった。パス名の突き合わせを `path_ncmp`
    にまとめて、そこから聞くようにした。

  * **`platform.h` が `memicmp` を `strncasecmp` の別名にしていた**
    (issue #184)。**この 2 つは約束が違う: `memicmp` は指定バイト数を必ず
    比べ、`strncasecmp` は NUL で止まる。**

    渡していたのは `ucs4_t` の配列 (`parse_namestring` が defaults の
    device と突き合わせる所) で、リトルエンディアンでは**先頭 1 文字の次の
    バイトが 0 なのでそこで止まり、device 全体ではなく 1 文字目だけを
    比べていた:**

    ```
                                    直す前        直した後
    (merge-pathnames "//x/y" "//a/b/dir/")
                                  "//x/y/dir"     "//x/y/"
    ```

    `//x/y` と `//a/b` を「同じ device」と見て、**別のホストのパスに
    defaults の trail を被せていた。** `c:` と `d:` は先頭が違うので偶然
    合っていた。

    **19 行下に、同じ罠についての警告が自分で書いてあった** (`_putenv` の
    別名を置かない理由)。別名を消して、`ucs4_ncasecmp` (コードポイント単位)
    と `path_ncmp` (ファイルシステムに従う) に分けた。

    **Win32 側にも同じ誤用が 2 つあった。** `src/frontend/win32/filer.cc` と
    `dialogs.cc` が `ucs4_t` の配列を `_memicmp` に渡している。あちらは
    バイト数どおり比べるので device の件は起きないが、**バイトごとに畳むので
    `あ` (U+3042) と `ぢ` (U+3062) が同じ文字列になる** — 下位バイトの
    0x42 (`B`) が 0x62 (`b`) に畳まれるため。filer の「前にいたディレクトリ」
    の突き合わせとバッファ一覧の並べ替えが誤答する。こちらも
    `ucs4_ncasecmp` に直した。

    **`WINFS::case_insensitive_names` の定義が 1 つ足りなかったことも
    分かった。** core から参照するようにしたら **Windows の
    `xyzzy-cli.exe` だけが link error** になった: あれは
    `src/frontend/win32/vfs.cc` を link せず
    `src/frontend/cli/cli-stubs.cc` が WINFS を埋めているのに、そこに定義が
    無かった。**core が参照するまで誰も気付かない**形だった。

  * **端末でキーボードマクロが記録も再生もできなかった** (issue #181)。

    ```
    C-x (        何も起きない (記録が始まらない)
    hello
    C-x )        「キーボードマクロは定義していません」
    C-x e        e が挿入される
    ```

    `start-save-kbd-macro` / `stop-save-kbd-macro` / `kbd-macro-saving-p` が
    `return Qnil` のスタブで、**`C-x (` が黙って成功したように見えて、
    次の打鍵で初めて分かる**という出方だった。

    **中身に Win32 の API は出てこない。** `start_macro` / `end_macro` /
    `stop_macro` / `macro_char` が触っているのは `src/core/kbd.h` の欄
    (`current_mode` / `saved[]` / `nsaved` / `last_command_key_index` /
    `kbd_macro`) だけである。`src/core/kbd-macro.cc` へ移した。

    再生の土台は最初から core にあった (`kbd_macro_context` と
    `command-execute` の文字列の枝)。**端末側に足りなかったのは 2 つ:**

    * **記録。** Win32 は入力キューから字を取る所で `saved[]` へ積むが、
      端末の `fetch` は端末から読んだ字を `cc[]` を経由せずに返すのでその
      経路を通らない。**判定を `kbd_queue::save_key` に 1 つにまとめて**、
      Win32 側の枝もそこへ寄せた (2 つ書くと片方だけ直る状態になる —
      補完エンジンとミニバッファで実際に起きた、issue #114)。呼ぶのは
      view-lossage 用に入れた `record_key` で、返り口が全部そこを通っている。
    * **再生。** `ncurses-kbd.cc` の `fetch` に**空の枝**があった
      (「`macro_char` が private なので書けない」というコメントだけが
      置かれていた)。取り出す所を `macro_getc` として公開した。

    記録中はモード行に `Def` が出る (`%M` の書式) ようにもなった。これは
    `Fkbd_macro_saving_p` を見ているだけなので、直したら勝手に付いてきた。

    **`peek` にも同じ枝が要る。** 名前は peek だが xyzzy のこれは字を消費
    するもので、Win32 側も `kbd_macro` を見ている。端末側で忘れると、
    再生中に `input-pending-p` などが呼ばれた瞬間にマクロが途切れる。
    **マクロを見る順番も Win32 に揃えた** (入力キューより先): 再生中に打った
    字はキューに溜まるので、キューを先に見ると再生とユーザの打鍵が混ざる。

  * **端末で日本語のプロンプトとメッセージが文字化けしていた** (issue #179)。

    ```
    (read-string "名前を入れて: ")   ->   琥悴筵噤燃黎:
    ```

    `src/core/charset.h` の**1 文字版の `i2w`** は、移行前の内部
    エンコーディング (CP932 系) から UTF-16 への**表引き**である。
    `src/core/ucs2tab.h` の表を数えると、**65536 のうち恒等なのは 2178 個
    だけ** (ほぼ ASCII と Latin-1):

    ```
    0x30ad -> 0x67d3   (キ -> 染)
    0x3042 -> 0x8a00   (あ -> 言)
    0x8868 -> 0xffff   (表 -> 未定義)
    ```

    ところが**移行後の `Char` は UTF-16 の code unit である**
    (`src/core/cdecl.h` の `typedef uint16_t Char`、`Chunk::c_text` も
    `Char *` で surrogate pair を持つ)。正しい変換は恒等で、表を引いては
    いけない。端末のフロントエンドが 12 箇所でこれを呼んでいた:
    メッセージボックス、ミニバッファのプロンプト、ダイアログの入力欄、
    ポップアップ、カーソルの桁数え、Terminal のセル。

    **1 文字版の `i2w` に正しい用途はまだある** — コーデックの中
    (`src/core/ucs2.cc` / `encoding.cc` / `char.cc` / `kanji.cc`) では
    「内部エンコーディング」が本当に旧内部エンコーディングを指す。端末側にも
    1 箇所だけ正しい呼び出しがあった (CP932 の 2 バイト文字を組んで渡して
    いる所)。**呼ぶ側を見分ける必要があるので、`char_to_wchar` を足して
    「UTF-16 を渡すだけ」の意図を名前で分けた。**

    **バッファのテキストは正しく出るので気付きにくい。** 描画は
    `src/core/glyph.cc` の経路で `i2w` を通らない。カーソルの桁数えは
    **幅が偶然一致することが多い** (あ (U+3042) が 言 (U+8A00) に化けても
    どちらも 2 桁) ので、症状が安定しない。

    `tools/linux-smoke.sh` に check を足した。**入れた check が本当に落ちるか
    を確かめてある**: `char_to_wchar` を一時的に `i2w` へ戻すと FAILED になる。

  * **テストが 1 件、公開インターネットへ HTTPS GET を出していた**
    (issue #174)。`unittest/ole-tests.l` の
    `fix-ole-getmethod-immediate-array` が

    ```lisp
    (ole-method xhr 'open "GET" "https://github.com/xyzzy-022/xyzzy/" nil)
    ```

    としていた。測っているのは「`ole-method` の戻り値が配列
    (`responseBody` は VT_ARRAY|VT_UI1) のとき、それが即値で返るか」で、
    **github.com とは何の関係も無い。** 網の状態でも相手側の都合でも落ちる
    ので、**測っているものと関係の無い理由で CI が赤くなる** (実際に Wine で
    落ちた。同じコミットで直前の run は通っている)。

    バイト配列がどこから来るかはこのテストの関心事ではないので、一時ファイル
    を `file://` で読む形にした。**相手が居なくなったら落ちるテストを CI に
    置いておくと、いつか必ず理由の分からない赤が出る。**

  * **端末にルーラが出るようになった** (issue #173)。テキスト領域の 1 行上に
    桁の目安を出す。

    ```
            0----+----10---+----20---+----30---+----40
          1|def foo():.
          2||   if x:.
    ```

    Win32 と同じ情報を桁の格子に置き換えたもので (`src/frontend/win32/
    Window.cc` の `paint_ruler`)、10 の倍数は番号、5 の倍数は `+`、それ以外は
    `-`、カーソルの桁は反転。横スクロール (`w_top_column`) にも従う。

    **桁がずれる原因が 2 つあって、どちらも実際に踏んだ:** 行番号の桁を
    飛ばし忘れる (Win32 の `calc_ruler_rect` も同じ分を足している) と、
    **`redraw_line` が glyph 列の先頭に置く空白 1 桁**を数え忘れる
    (Win32 では `cell.cx / 2` の左余白で、桁の格子では 1 桁になる)。
    `tools/linux-smoke.sh` の check は**ルーラの `0` とテキストの 1 桁目が
    同じ桁に来ること**を測る形にした。ずれても「出ている」だけは通って
    しまうので、そこを見ないと意味が無い。

  * **端末の既定の表示が Windows と揃った** (issue #173)。行番号・改行の印・
    EOF の印・折り畳みの印・ルーラが**既定で出るようになった。**

    ```
          1|abc.
          2|def.
          3|ghi[EOF]
    ```

    描く側 (`src/core/glyph.cc`) は最初から全部実装済みで、`toggle-*` では
    出せた (#166)。**端末の `Window::w_default_flags` が `WF_INDENT_GUIDE`
    だけだったので「無い」ように見えていた**だけである。Win32 は 8 つ立てて
    いる。落としたのは 2 つ:

    落としたのは `WF_VSCROLL_BAR` だけで、端末にスクロールバーが無いため。

    **立てるビットは「描けるもの」に限る。** 描けないものを立てると
    `toggle-ruler` が「切り替わったのに何も起きない」に見える (ルーラは
    この回で描くようにしたので立てた)。

    一緒に 2 つ直した:

    * **`compute_geometry` が `WF_MODE_LINE` を見ていなかった。** テキストの
      高さを `- 1` の決め打ちで出していたので、`toggle-mode-line` で消しても
      1 行取られたままだった (`window-lines` が動かない)。`window-lines`
      自身も「ミニバッファでなければ 1 行引く」と書かれていて、同じ形で
      フラグを見ていなかった。
    * **行番号の右の区切りが横線になっていた。** 端末は bitmap の glyph を
      文字で代えるが (`bitmap_slot_char`)、`FontSet::sep` と `fold_sep*` が
      `ACS_HLINE` に、`fold_mark_sep*` が `ACS_PLUS` に割り当てられていた。
      Win32 側 (`src/frontend/win32/font.cc`) が描いているのは**どれも縦線**
      である (`sep` は実線、`fold_sep*` は 2 px 置きの点線、
      `fold_mark_sep*` はその点線 + `<`)。**既定で行番号を出していなかった
      ので誰も見ていなかった。**

  * **端末でウィンドウ単位・バッファ単位の表示フラグが効くようになった**
    (`set-local-window-flags` / `get-local-window-flags`、issue #50、#16 Phase 4)。

    `get-local-window-flags` が 0、`set-local-window-flags` が nil を返す
    スタブだった。**「このバッファでは行番号を出さない」のような指定が
    端末で一切効かなかった。**

    Win32 側 (`src/frontend/win32/Window.cc`) に 80 行あったが、**写すのでは
    なく core へ移した** (`src/core/window-config.cc`)。全体の 2 つ
    (`get/set-window-flags`) も #166 で端末側に書いたものが Win32 の写しに
    なっていたので、そちらも一緒に 1 つにした。

    **フラグの意味は `Window::flags ()` の性質で、フロントエンドの性質では
    ない。** 3 段 (ウィンドウ局所 / バッファ局所 / 全体の既定) の重ね合わせと
    mask の扱いが core にある。フロントエンドに残したのは 2 つだけ:

    ```
    window_update_scroll_bars   スクロールバーの表示が変わった
                                (端末にスクロールバーは無いので何もしない)
    window_default_flags_changed 全体のフラグが変わった
                                (Win32 は反転表示の背景色とファンクションバー)
    ```

    `Window::invalidate_glyphs` も `src/core/Window.h` へ出した。触っている
    のは全部 core の欄なのに、**win32/Window.cc の中に `inline` で書かれて
    いたので他の翻訳単位から呼べなかった**だけである。

    **測っている途中で、端末ではフラグが画面の作りに届いていない所が
    2 つ見つかった** (issue #173): 端末の既定フラグがほぼ空で行番号も
    改行の印も出ない、`compute_geometry` が `WF_MODE_LINE` と `WF_RULER` を
    見ていない。局所フラグが実際に効くことを測るテストが**モード行ではなく
    行番号を見ている**のはそのためである (幾何に届いているのが行番号だけ)。

  * **POSIX で `rename-file` が `:if-exists` を無視して行き先を黙って
    上書きしていた** (issue #170)。既定は `:if-exists :error` なので、
    **何も指定しなければエラーになるはずのものが、相手のファイルを消していた。**

    `Frename_file` は「`MoveFile` が失敗したこと」で行き先の存在を知る。
    Win32 の `MoveFileW` は行き先があると失敗するが、**POSIX の `rename` は
    成功して上書きする。** `WINFS::MoveFile` はその `rename` をそのまま
    呼んでいたので、`:if-exists` を見る所へ一度も来ていなかった。

    直す前に測ったもの (`from.txt` に "FROM"、`to.txt` に "TO" を入れて
    `(rename-file from to :if-exists MODE)`):

    ```
    MODE          戻り値  エラー  from が残る  to の中身
    :error        t       なし    いいえ       "FROM"   <- 消している
    :skip         t       なし    いいえ       "FROM"   <- 消している
    :overwrite    t       なし    いいえ       "FROM"
    ```

    **3 つとも同じ動作**で、`:overwrite` だけが正しかった。

    直したのは `WINFS::MoveFile` の側で、Win32 の約束に揃えた
    (`renameat2 (RENAME_NOREPLACE)` があればそれ、無ければ `lstat` で見てから
    `rename`)。**同じ前提に乗っている呼び出しが他にもあるので、そちらも
    一緒に直る:** `src/core/fileio.cc` のバックアップ名の候補を 1 つずつ試して
    `os_error_already_exists` なら次へ進む loop (`make_backup_file` の `~%x`、
    `pack_backupfile` の `%d~`) は、上書きされると最初の候補で必ず成功する
    ので**既にあるバックアップを潰していた。**

    **呼ぶ側を 1 つずつ直すのではなく seam を直した**のは、この前提が
    「行き先があれば失敗する」という 1 つの約束だからである。呼ぶ側で
    確かめる形にすると、同じ判定が 4 か所に散る。

    **1 つだけ、揃えたことで答えが分かれた所があった。**
    `(rename-file "a" "a")` は Win32 では成功する (`MoveFileW` が同じ名前を
    受ける) が、「行き先があれば失敗する」を素直に書くと POSIX で
    `file-exists` になる。同じ inode を指しているなら成功にした:
    **POSIX の `rename` も「2 つの名前が同じファイルへのリンクなら成功して
    何もしない」と決まっている**ので、そのとおりの動作である。
    **両方のプラットフォームで測って気付いた**もので、片方だけ見ていたら
    そのまま入っていた。

    ついでに `src/core/pathname.cc` に残っていた裸の `ERROR_*` との比較を
    `os_error_*` (issue #120) に直した: `valid-path-p`、`delete-file` と
    `delete-directory` の `:if-does-not-exist :skip`。**どれも `ENOENT` (2) が
    `ERROR_FILE_NOT_FOUND` (2) と偶然一致して通っていた。**

    ここで `os_error_not_found` (Win32 の 4 通りをまとめたもの) を使うと
    **Windows の答えが変わる** (`ERROR_PATH_NOT_FOUND` も一致するように
    なるので、`C:/no-such-dir/x` に対する `valid-path-p` が nil から t に
    なる)。`ERROR_FILE_NOT_FOUND` だけを見ていた所はそのままの意味で
    書き直すために `os_error_file_not_found` を足した。**「番号を述語に
    置き換える」のは機械的な作業に見えるが、どの述語かで意味が変わる。**

  * **`(open ... :if-exists :rename)` が書いた内容を捨てていた** (issue #168)。
    ファイルは作られず、代わりに一時ファイルが 1 回ごとに 1 つずつ溜まる。
    **Windows でも同じ**で、上流の import (0.2.2.235) からこの形だった。

    `src/core/stream.cc` の `create_file_stream` は `:new-version` /
    `:supersede` / `:rename-and-delete` / `:rename` のために一時ファイルを
    作ってそちらへハンドルを開き、閉じるときに本来の名前へ被せる。ところが
    `:rename` だけは開いた直後に

    ```cpp
    if (if_exists == Krename && xfile_stream_alt_pathname (stream))
      { xfree (...); xfile_stream_alt_pathname (stream) = 0; }
    ```

    で**一時ファイルの名前を忘れていた。** 名前が消えると
    `close_file_stream` は先頭の `if (!alt_pathname) return;` で戻るので、
    書いた内容は一時ファイルの中に取り残され、本来のパスは作られないまま
    終わる。

    **一時ファイルを経由する必要が無かった。** CL の `:rename` は「既存の
    ファイルを別の名前にしてから、新しいファイルを作る」で、退避するのは
    **古い方**である。開くときに既存のファイルを `<path>~` へ動かして、
    本来のパスをそのまま作るようにした。退避先をエディタ自身のバックアップの
    慣習 (`~`) に合わせたのは、`xyz4b8b.tmp` のような名前で残ると
    **それが退避されたものだと分からない**ため。

    この tree の `lisp/` には取り残された一時ファイルが **132 個**あった
    (8/24〜8/28、全部 `startup.lc` と同じ内容)。`.gitignore` に `*.tmp` が
    あるので **`git status` には出ない。** 一時ファイルの置き場所が「書き先と
    同じディレクトリ」なのは rename を同じファイルシステム内で済ませるためで
    そこは正しく、**閉じられないまま終わると溜まる**という形だった。

  * **POSIX で `:supersede` などで書いたファイルが 0600 になっていた**
    (issue #169)。umask も、置き換える前のファイルのモードも効かない。

    一時ファイルを作るのは `WINFS::GetTempFileName` (`src/core/vfs-posix.cc`)
    で、`mkstemp` を使っている。**`mkstemp` は 0600 で作る**のが正しい
    (一時ファイルの中身を他人に見せないため) が、この名前は
    `close_file_stream` が**そのまま本来の名前へ rename する**ので、0600 が
    最終的なファイルのモードになっていた。

    ```
    -rw-r--r-- 1 kuwa72 kuwa72 13105 Aug 31 09:48 lisp/defs.l
    -rw------- 1 root   root   16373 Aug 31 10:00 lisp/defs.lc
    ```

    `lisp/compile.l` はバイトコンパイルの出力を `:if-exists :supersede` で
    書くので、**コンテナ (root) でバイトコンパイルすると `.lc` がホストの
    ユーザから読めなくなる** (`xyzzy --batch` が
    `lisp/defs.lc: Permission denied` で起動できない)。他に
    `lisp/history.l` / `lisp/session.l` / `lisp/kbdmacro.l` /
    `lisp/encdec.l` が同じ経路で書いている。

    一時ファイルに**通常のファイルと同じモード** (`0666 & ~umask`) を与える
    ようにした。ついでに**置き換える相手のモードを引き継ぐ**ようにもした
    (`0755` のファイルを `:supersede` で書き直すと実行ビットが落ちていた)。
    `Buffer::save_buffer` の precious な経路は
    `SetFileAttributes (tmpname, filemode)` として最初から同じことを
    しているので、**ストリームの経路だけが抜けていた**という形である。

    モードを写す所を `WINFS::CopyFileMode` としてファイルシステムの seam
    (`src/core/vfs.h`) に置いた。既にある `SetFileAttributes` で済まないのは、
    **POSIX のモードが Win32 の属性のビットに収まらない**ため:
    `GetFileAttributes` は POSIX では「書けるか」を
    `FILE_ATTRIBUTE_READONLY` に潰すので、それを書き戻すと `0755` が
    `0644` になる。

  * **`open` が POSIX で「エラーを出さずに nil を返す」約束を守っていなかった。**
    `:if-exists nil` が nil ではなく `file-exists` をシグナルし、
    `:if-does-not-exist nil` も途中のディレクトリが無い場合はシグナルしていた。

    `create_file_stream` が `GetLastError ()` の戻り値を `ERROR_*` と直に
    比べていた。**番号の空間がプラットフォームで違う** (Win32 は Win32 の
    コード、POSIX は errno) ので、POSIX ではどの `case` にも当たらず
    `default` の `file_error` に落ちる。意味を聞く述語は issue #120 で
    `src/core/error.h` に入れてあり、**ここが漏れていた。**

    直す前に測ったもの (linux ネイティブビルド):

    ```
    :if-exists :skip         -> simple-program-error 「不正な`:if-exists'…」
    :if-exists nil           -> file-exists          (nil を返すべき)
    存在しないファイル       -> nil                  (ENOENT (2) が
                                ERROR_FILE_NOT_FOUND (2) に偶然一致する)
    途中のディレクトリが無い -> path-not-found       (ENOTDIR (20) は
                                どの ERROR_* にも当たらない)
    ```

    **1 つだけ偶然通っていたのが厄介**で、「ファイルが無いとき」を試すと
    正しく動いているように見える。

    ついでに **`:if-exists :skip` を受けるようにした。** reference には
    「エラーは出力せず、nil を返します」と書いてあるのに `不正な
    :if-exists オプションです` になっていた。`create-directory` や
    `delete-file` は最初から `:skip` を受けるので、名前の方を揃えた。

  * **`open` の `:if-exists` の説明を reference に書いた。** `:supersede` /
    `:rename` / `:rename-and-delete` の 3 つは
    `---- 以下詳細不明 ----` の下に「更新？」「リネーム用にストリームを
    開く？」と書かれていた。上の 2 件で実際に測ったので、書ける。

  * **型の punning を 17 箇所やめた** (issue #165)。**実際に誤コンパイルを
    起こしていた。**

    `(int &)wp->w_selection_type |= Buffer::CONTINUE_PRE_SELECTION;` のように、
    enum の lvalue を `int &` にキャストして書き換えている箇所が 16 あった。
    strict aliasing に反する書き方で、`src/frontend/ncurses/ncurses-stubs.cc`
    には**その被害の跡がコメントで残っていた**:

    ```
    // Use (int &) cast to match the (int &) &= ~CONTINUE_PRE_SELECTION below;
    // without this, strict aliasing lets the compiler cache the enum value
    // across the (int &) write, so the VOID assignment silently disappears.
    ```

    **キャストを揃えるのではなく、punning をやめるのが正しい。** `selection_type`
    に `operator |=` / `operator &=` を定義して、列挙型のまま計算して代入する
    ようにした。`kbd_queue::input_mode` の 2 箇所も同じ形に直した。

    17 箇所目は `lstream::alt_pathname` で、**ストリームの種類によって
    `wchar_t *` と `lisp` を使い分けている欄**である。こちらは union にした:
    **union のメンバとして読み書きするのは規格が認めている書き方**で、同じ 1 語
    を指すことは変わらないので GC の見え方も変わらない。

    直したので `-Wstrict-aliasing` を LP64 (gcc) で有効にした。**`-Wno-` を
    外すだけでは効かない** (gcc は `-Wall` に入れている) ので、明示的に付けて
    ある。`_build/linux` を作り直して**警告はリンカの注意 1 件だけ**。

  * **インデントガイドを追加した** (#30 の最後の項目)。行頭の空白を縦線にする。
    **既定で有効** (`M-x toggle-indent-guide` / フラグは
    `*window-flag-indent-guide*`)。

    ```
    def foo():
    |   if x:
    |   |   bar()
    |   |   |   deep()
    qux
    ```

    **#30 に書いてあった「本当に手段が無い。文字の無い場所に縦線を出す必要が
    ある」は Lisp から見た話だった。** core (`src/core/glyph.cc`) から見ると
    **インデントの中には実際に文字がある** — 空白そのもの、あるいはタブが
    広がった詰め物のセルである。しかも「空白の代わりに別の字を出す」機構は
    タブ可視化として既にあった。flymake のときと同じ間違いで、**「表示層が
    無い」を理由に見送る前に、どの層から見て無いのかを確かめる。**

    空行とインデントより浅い行には出ない (置き換える文字が無いので、そこは
    本当に表示専用のセルが要る)。間隔はタブ幅 (`set-tab-columns`) に従うので
    **字の並びと必ず一致する。** 折り返しの継続行では出さない (表示行の先頭が
    論理行の途中なので、行頭からの空白を数えられない)。

    **縦線の字の既定は `|` (ASCII)。** `│` (U+2502) の方が見た目は良いが、
    xyzzy は Box Drawing を East Asian Ambiguous として **2 桁**に数えるので
    (`src/core/eaw.cc`)、そのままでは桁がずれる。実際それを既定にして
    「何も出ない」状態を作った (2 桁の字は断るようにしてある)。**端末と
    xyzzy の幅の解釈が一致するのは ASCII だけ**である。Ambiguous を 1 桁と
    する端末なら `(setq-default display-indent-guide-char (code-char #x2502))`
    で置ける。

  * **端末で `toggle-line-number` などウィンドウ表示の切り替え 14 個が何も
    していなかったのを直した** (issue #50)。

    `get-window-flags` が 0 を返し、`set-window-flags` が nil を返すスタブ
    だった (`src/frontend/ncurses/ncurses-stubs.cc`)。`lisp/window.l` の
    `toggle-window-flag` はこの 2 つしか使わないので、**`toggle-line-number` /
    `toggle-ruler` / `toggle-newline` / `toggle-tab` / `toggle-eof` /
    `toggle-fold-mark` / `toggle-cursor-line` ほかが揃って無効だった** —
    端末では行番号を出すことすらできなかった。描く側は最初からフラグを見て
    いる。

    **ウィンドウ単位・バッファ単位の方 (`set-local-window-flags`) はまだ
    スタブ。** Win32 側に 80 行あり、写すのではなく core へ移すのが正しいので
    分けた (#16 Phase 4)。

    `unittest/window-flags-tests.l` に 5 件。**「既定で有効」はここでは測れ
    ない**: `xyzzy.ini` に保存されたフラグが C 側の既定を上書きするので、
    走る環境で答えが変わる (Wine の環境で実際に落ちた)。新しい環境で本当に
    出ることは `tools/linux-smoke.sh` が画面を見て確かめている。

  * **`write-registry` / `read-registry` がセクションとキーを取り違える可能性が
    あったのを直した** (Windows 側の話)。

    `src/core/environ.cc` の `lisp_to_wsz` が **`alloca` した領域を返していた。**
    返った時点でその領域は無効で、しかも `Fwrite_registry` はセクションとキーで
    2 回呼ぶので、**2 回目の `alloca` が 1 回目と同じ場所を取り、セクションが
    キーの文字列を指す。**

    ```lisp
    ;; lisp/history.l の erase-registry-chunk-compat がこの形で呼ぶ
    (write-registry key name nil)
    ```

    **インライン展開されると壊れない** (`alloca` が呼ぶ側の枠に載って別々の
    場所になる) ので、**最適化の具合で動く/壊れるが変わる**種類の不具合である。
    gcc は `-Wreturn-local-addr` で言っていた — Linux ビルドに残っていた唯一の
    コンパイラ警告がこれで、**中身を読むまで「POSIX ではレジストリがスタブだから
    無害」に見えていた。** 実際には同じ関数を Windows もコンパイルしている。

    呼ぶ側の領域に書く形にした (`pathname2wstr` と同じ約束)。

    **テストは書いていない。** 観測するにはレジストリに実際に書く必要があり、
    POSIX では `Reg*` がスタブなので Lisp から見えない。根拠はコンパイラの警告と
    コードである。

    **ついでに LP64 (gcc) で `-Wformat` を有効にした。** 実在した 9 箇所
    (`%d` に `long` を渡していたもの) を直してから入れた。**LP64 では `%d` は
    下位 32bit しか読まない**ので、たとえば 2GB を超えるファイルの読み込み
    進捗が「Reading -1234/…」のような数になる (`src/core/fileio.cc`)。他は
    行番号・桁・バッファ版数・マーカ位置で、実用上の値では表に出ない。

    Windows 側 (MSVC の `/wd4477`、Clang の `-Wno-format`) は**塞いだまま**に
    した: LLP64 では `long` が 32bit なので、`%d` + `long` が**すべて偽陽性**に
    なる (実測で 100 件以上)。**同じ警告が片方では役に立ち、もう片方では雑音に
    なる。**

    **`-Wno-format` を外すだけでは効かないことにも引っかかった。** gcc は
    `-Wformat` を既定で有効にしていない (`-Wall` に入っている) ので、外しても
    何も出ない。一度それで「0 件だった」と誤解した。`-Wall` を丸ごと入れるのは
    やめた: 測ったら 396 件出て、大半は `-Wnarrowing` 60 / `-Wsign-compare` 51
    / `-Wparentheses` 42 のようなこのコードベースの書き方そのものだった。
    残りは issue に分けた。

  * **端末で、走っている Lisp を `C-g` で止められるようになった** (issue #162)。
    それまでは**暴走したらプロセスを殺すしかなく**、編集中のバッファは失われた。

    `quit-flag` を立てているのは木全体で 1 か所だけで、それが Win32 の専用
    スレッド (`RegisterHotKey` でホットキーを受ける) だった。端末にそれに当たる
    ものが無いので `QUITP` は永遠に偽で、`handle_quit` は呼ばれなかった。
    `raw()` を使っているので **C-c も signal にならない** (ISIG が落ちる) し、
    xyzzy の C-c は前置キーなので ISIG を戻す方には倒せない。

    **`QUIT` から主スレッドで端末を覗く。** `QUIT` はインタプリタの最も熱い所に
    居るので、あちらでやるのは「カウンタを 1 つ減らして分岐する」だけにして、
    実際の仕事を `src/core/quit-poll.cc` に置いた。覗く間隔には**時計の下限**
    (50ms) を掛けている: カウンタだけだと速いループで数マイクロ秒に 1 回
    `select` を呼ぶことになる。時計を読むのはカウンタが尽きたときだけ。

    **シグナルは使わない。** ハンドラの中で端末から読むと主入力経路とバイトを
    取り合う。主スレッドなら、quit char でなかったバイトを入力キューへ戻すのも
    安全である。

    **`select` で fd を見るだけでは足りなかった。** 打鍵は ncurses の内部
    バッファに入っていることがある — `fetch` が RET を読んだときに直後の C-g
    まで一緒に読み込まれていて、**fd には何も残っていない。** `wget_wch` を
    nodelay で呼ぶと両方を見る。

    費用を測った: 200000 回の解釈実行ループ x 5 の最小値で **1304ms -> 1326ms
    (約 1.7%)**。**ビルドごとの揺れ (コード配置) が 1 プロセス内の揺れより
    大きい**ので、プロセスの中で 5 回回して最小を取る形にしないと分からない
    (最初は 500000 回を別プロセスで 3 回ずつ測って、差が揺れに埋もれた)。
    Win32 側は `#ifndef _WIN32` で外してあるので変わらない。

    `set-quit-char` も nil を返すだけだったので実装した (`quit-char` と同じ
    変数を読む)。確認は `tools/linux-smoke.sh` に入れた: **止まったかどうかは
    画面ではなく戻り値で見る** (中断されたら `Quit`、されなければ経過ミリ秒)。

  * **端末で嘘をついていた述語と、空だった view-lossage を直した** (issue #50)。

    どちらも `src/frontend/ncurses/ncurses-stubs.cc` で nil を返していた。

    **`pos-not-visible-in-window-p` は「常に nil」= 「どこでも見えている」と
    答えていた。** 中身は Win32 に依っていない — 表示の先頭 (`w_disp`) と
    ウィンドウの高さ (`w_ech.cy`) から行番号を比べるだけで、どちらの
    フロントエンドも両方を埋めている。それでも
    `src/frontend/win32/Window.cc` に居たので、端末側は書かれていなかった。
    `src/core/window-config.cc` へ移した。**嘘をつく述語は、呼ぶ側を間違った
    方に分岐させる**: `lisp/ispell.l` は見えない位置でも画面を送らず、公開
    されている `pos-visible-in-window-p` も嘘を返していた。

    **`view-lossage` (`C-h l`) は空の *Help* を出していた。**
    `get-recent-keys` が nil を返すため。Win32 側は**入力キューの環状バッファを
    履歴として使い回している** (head が進んだ後ろに消費済みの打鍵が残る) が、
    端末側の `fetch` は端末から読んだ字をキューを経由せずに返すので、そこが
    空になる。**入力キューには手を出さず**、別に小さな環を持たせた。

    **`peek` も記録することが要点だった。** 名前は peek だが字を消費するので、
    `fetch` だけ記録していると「まとめて届いた打鍵」と「ミニバッファに打った
    字」が履歴から抜ける (`abc` を 1 回の書き込みで送ると `a` しか残らない)。

    `unittest/window-visible-tests.l` に 3 件。view-lossage の方は打鍵が要る
    ので `tools/linux-smoke.sh` に入れた (Lisp スイートからはキーを打てない)。

  * **POSIX の FFI テストが「ライブラリを開けない」だけで落ちていたのを直した**
    (issue #50、既知失敗 40 -> 17)。

    `unittest/foreign-test.l` は C のライブラリを `"msvcrt"` と決め打ちして
    いた。POSIX では `dlopen` に失敗し、その関数を使うテストが全部
    「共有ライブラリを読み込めません」で落ちていた。

    ```lisp
    (sprintf 0 0 123)
    ;; 期待: 「不正な可変長引数です: 123」
    ;; 実際: 「共有ライブラリを読み込めません: msvcrt: cannot open ...」
    ```

    **落ちていた大半はプラットフォームと関係が無かった。**
    `funcall-invalid-vaargs-*` 7 件は `si:make-c-function` に渡す型を検査する
    だけで、**関数を呼ぶ所まで行かない。** 既知失敗リストに書いてあった
    「テストが msvcrt 固有の関数を呼んでいる」という分類は、半分しか当たって
    いなかった。ライブラリ名を選ぶようにして **20 件通った。**

    msvcrt にしか無いのは `_itoa` / `_ultoa` / `_i64toa` / `_ui64toa` の 4 つ
    だけで、POSIX では `sprintf` に書式を渡す。

    **副作用で 2 件見つかった。どちらも「落ちないようにする」直しである。**

    1. **可変長引数に `c:double` を渡すと SIGSEGV でエディタが死んだ。**
       ここは「ビット列を整数の枠で渡す。受け側が整数として読むなら通る」と
       書いて通していたが、**SysV x86_64 では `al` に「ベクタレジスタを何本
       使ったか」を入れる約束**があり、整数の関数型へキャストして呼ぶと `al`
       が 0 になる。呼ばれた側はレジスタ保存領域の浮動小数の欄を**埋めない
       まま**読む。1 個だけなら直前の xmm に残った値で偶然合うことがあり、
       それが「通ることもある」の正体だった。固定引数の float / double と同じ
       ように**断るようにした** (issue #133)。
    2. **SEH のテスト 3 件が SIGFPE / SIGSEGV でスイートごと落ちるように
       なった。** 以前は `div` / `strcat` を "msvcrt" から引いていて `dlopen`
       に失敗していたので、**無害に落ちていただけ**だった。POSIX では走らせ
       ない (走った時点で終わりなので、既知失敗に載せる話ではない)。

  * **端末で `abbreviate-display-string` が何もしていなかったのを直した。**
    `ncurses-stubs.cc` で**引数をそのまま返すスタブ**だった。呼んでいるのは
    `lisp/app-menu.l` (最近使ったファイルの一覧) と `lisp/mouse.l` (URL の
    表示) で、**長いパスが縮まないまま出ていた。**

    ```
    /very/long/directory/name/that/does/not/fit/anywhere/wordlist.h
      -> .../fit/anywhere/wordlist.h        (上限 30)
      -> wordlist....                       (上限 12)
    ```

    **幅を測る単位がプラットフォームで違う。** Win32 は GDI で可変幅フォントの
    ピクセルを測り、上限は「平均文字幅 x 引数」である。端末は文字セルの格子
    なので桁で測る。戦略は同じで、パス名なら末尾のファイル名を必ず残し、先頭の
    ドライブが入るなら残して間を `...` にする。全角は 2 桁で数える
    (`char_width`)。

    **既知失敗 `fix-abbreviate-display-string` はこれで通るようにはならない。**
    あの期待値は片方の環境のフォントの寸法を焼き付けていて、38 文字のパスを
    上限 40 で縮めることを求める。桁で数えれば 38 <= 40 なので縮めないのが
    正しい。**どちらも正しい**ので、リストに理由を書き直して残した (以前の
    「理由が分かっていない」は、端末側がスタブで結果が偶然一致していたため)。

    `unittest/abbrev-tests.l` に 7 件。**どちらの数え方でも成り立つ性質**で
    書いてある (十分長いものは縮む、`...` が入る、末尾のファイル名は残る)。
    桁数そのものを見る 2 件だけ POSIX 限定。

  * **POSIX で `format-buffer` (外部フォーマッタ) が測られていなかったのを
    直した** (issue #50、既知失敗 42 -> 40)。

    `unittest/formatter-tests.l` は偽フォーマッタを `cmd /c ...` で書いていて、
    **POSIX では 1 つも起動できていなかった。**

    落ちて見えていたのは「成功して内容が変わる」経路の 2 件だけだったが、
    **失敗する側の 3 件も測れていなかった。** あちらは「バッファに触らないこと」を
    見るテストなので、**コマンドが起動できなくても通ってしまう。** 8 件のうち
    5 件が「起動できないから通る」状態で、**`format-buffer` が POSIX で動くか
    どうかはどのテストも言っていなかった。**

    POSIX 側は**ファイルを作らない**。`shell-command-line` が cmdline を
    `/bin/sh -c` にそのまま渡すので、`(echo FORMATTED; cat)` とその場で書ける。
    最初はスクリプトを書こうとして失敗した: **xyzzy が書く改行が CRLF なので、
    `sh` が `cat\r` というコマンドを探す。** エラーには `\r` が見えないので
    「cat: not found」とだけ出て、PATH の問題に見える。

  * **POSIX でチャンクの中の文字列が CP932 になっていたのを UTF-8 にした。**

    チャンクは C の `char *` で、**そのバイト列の意味はプラットフォームで
    違う**: Win32 の ANSI API (`MessageBoxA`、`atoi` など) は CP932 を読み、
    POSIX の C 関数は UTF-8 を読む。`si:make-string-chunk` /
    `si:unpack-string` / `si:pack-string` はどれも CP932 決め打ちだった。

    ```lisp
    ;; POSIX、直す前
    (si:make-string-chunk "日本語")   ; -> 93 FA 96 7B 8C EA  (CP932)
    ;; 直したあと
    (si:make-string-chunk "日本語")   ; -> E6 97 A5 E6 9C AC E8 AA 9E  (UTF-8)
    ```

    **読み書きが対称なので、Lisp の中で往復させる限り気付かない。** 壊れるのは
    C に渡したときだけである — つまり FFI で非 ASCII の文字列を渡したときで、
    そこは POSIX では今回のリリースで初めて動くようになった所でもある。

    プラットフォームの分岐は変換の 6 つ (向き 2 x 区切り方 3) に閉じ込めた
    (`src/core/chunk.cc`)。パスと環境変数が既に同じ考え方で書かれている
    (`src/core/vfs-posix.cc` の `os_path`、`src/core/environ.cc`)。
    長さで区切る UTF-8 の変換器が無かったので足した (`src/core/utils.cc`、
    CP932 側の `s2wl` / `s2w` / `w2s` と同じ約束)。

    `unittest/ffi-portable-tests.l` に 3 件。**バイト列そのものを見る。**
    往復させるテストは前から通っていた (両方向が同じエンコーディングだった
    ため) ので、それでは捕まらない。

  * **`si:hmac-sha-*` が、0x80 以上のバイトを含む短い鍵で違う値を出していたのを
    直した** (全ターゲットの既知失敗 1 件)。

    `hash_method::hmac` (`src/core/encdec.cc`) が**鍵だけ CP932 に変換して
    いた** (`w2sl` / `w2s`)。内部表現が CP932 のバイト列だった頃はそれが恒等
    変換だったが、**Unicode になったあとは 0x80 以上のバイト値が U+00AA などの
    文字として入り、CP932 へ変換すると別のバイトになる** (`wc2cp932` に無ければ
    `?`)。データの方は `update (lisp)` がバイトとして読むので、**鍵とデータで
    解釈が食い違っていた。**

    **壊れ方が「短い鍵だけ」だったので、HMAC が動いていないようには見えなかった。**
    鍵がブロック長 (SHA-224/256 は 64、SHA-384/512 は 128) より長いときは
    鍵自身をハッシュする経路を通り、そこはバイトとして読んでいた。ASCII だけの
    鍵も一致する。**0x80 以上のバイトを含む短い鍵だけが静かに違う値を出して
    いた** — 相手側の実装と突き合わせるまで気付けない形である。

    既知失敗として `hmac-sha2-test-case-3` (RFC 4231、鍵 = 0xAA x 20) が
    全ターゲットで落ちていた。**リストにあった理由は「長い鍵の場合」だったが、
    RFC の case 3 は短い鍵の方である** (長い鍵は case 6 / 7 で、そちらは
    通っていた)。

    RFC 4231 のベクタは鍵が 20 / 4 / 25 / 131 バイトで、**ブロック長ちょうどを
    踏んでいない。そこが実装の分かれ目**なので、64 と 128 の前後を hashlib で
    作ったベクタで埋めた (`hmac-sha-*-block-size-boundary` 4 件、各 3 値)。
    鍵は 0xAA の並びにしてある: **0x80 以上のバイトでないと、鍵をバイトとして
    読むか CP932 として読むかの違いが出ない。**

    これで **`misc/known-failures/common.txt` (全ターゲットで落ちるもの) は
    4 件から 1 件になった。** 残りは `fix-ole-for-each-2` だけである。

  * **`si:octet-length` の既定が CP932 であることを、リファレンスとテストに
    書き直した** (全ターゲットの既知失敗 2 件を外した)。

    リファレンスには「`:encoding` のデフォルトはエンコーディング変換なし」と
    書いてあった。**内部表現が CP932 のバイト列だった頃はそれで正しかった**
    (変換しないことと CP932 で数えることが同じだった)。内部表現が Unicode に
    なったあと「変換なし」に当たるものは無くなり、実装は CP932 を数え続けて
    いる (`w2sl`)。

    この食い違いが `octet-length-eucjp` と `octet-length-utf8` を**全ターゲット
    で落としていた。** どちらも

    ```lisp
    (si:octet-length (convert-encoding-from-internal *encoding-utf8n* "漢字"))
    ```

    が 6 になることを期待していた。バイト列にしたあとの「文字」を CP932 で
    数え直すと、**U+00A2 が 2 バイトになるので 7 になる。**

    **実装を直す方には倒せなかった。** 既定を「文字数を数える」に変えれば
    この 2 件は通るが、**同じファイルの `octet-length-sjis` が既定は CP932 だと
    言っていて通っている** (リファレンスの主たる例
    `(si:octet-length "abcあいう") => 9` も CP932 の側)。両方を同時に満たす答えは
    無く、公開 API の既定を黙って変える話になる。既定を
    `*default-fileio-encoding*` (このフォークでは UTF-8) に寄せるかどうかは
    issue #154 に分けた。

    テストは 2 つに割った。`octet-length-*` は `:encoding` を渡す方だけを見て、
    バイト数の方は `convert-encoding-from-internal-byte-counts` が `length` で
    見る。**どちらも元の期待値のまま通る**ので、測っていたものは失っていない。
    既定が CP932 であること自体も書き留めた。リファレンスの
    「変換なし」と、そこにあった `=> 12` という例 (実際は 13) も直した。

  * **POSIX で `chdir` / `truename` / `get-disk-usage` が測られていなかったのを
    直した** (issue #50、既知失敗 56 -> 45)。

    **`get-windows-directory` と `get-system-directory` が POSIX で未束縛
    だった。** 値を入れているのは `src/frontend/win32/init.cc` の
    `init_windows_dir` だけで、POSIX にはそれに当たるものが無い。

    ```lisp
    (get-windows-directory)                 ; => #:unbound
    (ignore-errors (get-windows-directory)) ; => #:unbound  (捕まらない)
    ```

    **未束縛の変数を読むと `#:unbound` という内部の印がそのまま Lisp へ出て
    くる。** `unbound-variable` にならないので `ignore-errors` でも止まらず、
    どこにも無い値が `merge-pathnames` やリストへ静かに流れていく。POSIX に
    Windows ディレクトリは無いので nil を入れた。

    **既知失敗 11 件はこれを踏んでいただけで、テストが要求していたのは
    「実在する入れ子のディレクトリ」だった。** `chdir-0`〜`-6` は
    `C:\Windows` と `C:\Windows\system32` を「2 段の入れ子」として、
    `fix-truename-1`〜`-4` は `system32\drivers\etc\hosts` を「何段か下に
    ある実在するパス」として使っていた。プラットフォームごとに選ぶ形に直した
    (Windows 側の行き先は変えていない)。**11 件の裏で `chdir` と `truename`
    が一度も測られていなかった。**

    1 件だけ期待値の意味が違った。`chdir-6` は 4 つ目の `..` が nil を返す
    ことを見ていて、それは「Windows のドライブの根には親が無い」という形の
    言い方である。POSIX の `/` の親は `/` 自身なので同じ理屈にならない。
    測りたいのは**「これ以上は上がれない」**なので、居場所が動かないことで
    書いた (実装は両方で同じ判定をしていて、POSIX でも根では nil が返る)。

    **`get-disk-usage` が POSIX で失敗を返していた**のも直した。
    `WINFS::GetDiskFreeSpace` が `return FALSE;` のスタブで、
    `Fget_disk_usage` はそれを見て `file_error` を投げる。**実在する
    ディレクトリを渡して「file-not-found」が返る**ので、使う側からは
    「そのディレクトリが無い」と読める。`statvfs` で埋めた。欄が `DWORD` なので
    大きなファイルシステムでは数が入り切らないが (Win32 の
    `GetDiskFreeSpace` も同じ)、呼ぶ側はブロック数 x ブロックの大きさで見る
    ので、**入り切るまでブロックを 2 倍にして数を半分にする。**

  * **POSIX で tree-sitter による色付けが動くようになった** (issue #150)。
    `*ts-highlight*` は**既定で `t`** なので、Linux ビルドでは
    **有効になっているのに何も起きなかった。** `lisp/ts.l` は例外を出さずに
    諦めるので、ユーザからは「色が付かない」だけに見える。C / C++ / Perl /
    Markdown の 4 言語で、端末に色が出るようになった。

    `src/frontend/win32/ts.cc` を `src/core/ts.cc` へ移し、Win32 依存を
    3 つ外した。

    **スレッドは `platform.h` の `HANDLE` を通さず、ts.cc の中だけで
    pthread を直に使う形にした。** 当初は「`CreateThread` /
    `WaitForSingleObject` のエミュレーションを 1 つ書けば他の移植も進む」と
    考えたが、それは成り立たない: **`platform.h` の `HANDLE` はファイル
    記述子で、`CloseHandle` は中身を fd として `close()` を呼ぶ。**
    スレッドやイベントのハンドルをヒープのポインタにすると、`CloseHandle`
    がポインタを fd として閉じにかかる。直すにはハンドルに種類の印を付ける
    か表を作ることになり、`HANDLE` を触る全ての場所を見直す話になる
    (しかも間欠的に壊れる種類の変更)。他の `CreateThread` の利用者
    (`filer.cc` `toplev.cc` `process.cc`) はいずれも Win32 GUI 側のコードで
    移植の対象ではないので、広げる理由も無かった。要る操作は 4 つだけ
    (起こす / 期限付きで待つ / 手放す / CPU を譲る) で、**期限付きの join は
    `pthread_timedjoin_np` が Linux 専用なので使わず**、終了の印と条件変数を
    持って `pthread_cond_timedwait` で待つ。

    **`WideCharToMultiByte (CP_UTF8, ...)` をやめて `i2u8` に替えた。**
    POSIX の `platform.h` のそれは符号ページを見ずに下位バイトへ切り落とす
    ので、非 ASCII が壊れる。実際に
    `grammars/markdown/highlights.scm` の 1 行目 (全角ダッシュ入りの
    コメント) が該当する。**長さも NUL を含んだ値を返すので、ASCII だけの
    問い合わせでも余分な NUL を tree-sitter に渡していた。** `i2u8` は core
    の本物の変換器で Win32 でも同じ結果になるので、枝を分けずに 3 箇所とも
    差し替えた。

    文法の読み込みは POSIX で `dlopen` を直に呼ぶ (`platform.h` の
    `LoadLibraryW` は、名前を UTF-16 からバイト列へ直す変換器が core の後ろで
    定義されるため 0 を返すスタブのまま)。`si:load-dll-module` と同じ形。

    **ついでに 3 つ直した。**

    1. `C:/tmp/ts-outline.log` へ書くデバッグ出力が消し忘れで残っていた
       (16 箇所)。**問い合わせ 1 回ごとに `fopen` し、捕捉 1 件ごとに 1 行
       書く。** Windows で `C:\tmp` があると大きなファイルで実害が出る。
    2. 背景スレッドがメモリ確保に失敗したときの後始末が、outline の仕事でも
       highlight の印 (`bg_active`) を消していた。**`oq_active` が 1 のまま
       残るので、そのバッファでは outline が二度と動かない。**
    3. 文法をソースツリーへ複製する処理が `POST_BUILD` で、**文法が
       リンクし直された時だけ**動いていた。別のアーキテクチャでビルドすると
       `grammars/` が前のアーキのまま残り、`si:load-ts-grammar` が
       "Bad EXE format" で落ちる。`ts-register-mode` は `ignore-errors` の
       中なので、これも**色が付かないだけに見える**。実際に**コミットされて
       いた `.dll` は AArch64 のもの**だった。毎回走る `ALL` の custom
       target に変えた。

    `unittest/ts-tests.l` に 10 件。**解析と問い合わせが本当に動いているかは、
    これまでどちらのプラットフォームでも測られていなかった**
    (`ts-highlight-tests.l` が見ているのは切り替えの Lisp だけ)。位置が
    バイトではなく文字単位で返ることは、日本語を混ぜないと測れない
    (ASCII だけだと 3 つの数え方が一致してしまう)。既知失敗は Linux で
    56 件のまま、Windows 3 アーキで 10 / 10 / 8 件のまま。

  * **flymake が「入力が止まってから」検査できるようになった**
    (`*flymake-idle-delay*`)。#137 では「打鍵ごとには走らせない」として保存時
    だけにしていたが、**それは `start-timer` が POSIX で動かなかったから**
    でもあった。動くようになったので入口を足した。

    ```lisp
    (setq ed::*flymake-idle-delay* 0.5)
    ```

    **打鍵ごとに検査するのではない。** `*post-command-hook*` から 1 回だけの
    タイマを張り直すので、入力が続いている間は発火せず、**止まってから 1 回**
    走る (`lisp/ts.l` の `ts-schedule-highlight` と同じ形)。

    **既定は nil。** 重い検査コマンド (`g++` など) では待たされるので、速い
    linter を使うときだけ入れる。設定の無いモードではタイマを張らない
    (張って発火して何もせず消えるのを打鍵ごとに繰り返す意味が無い)。

    端末で実測: ファイルを開いて打鍵をやめると、保存も `M-x flymake-check`
    もせずに下線が付いた。テストは 4 件。
  * **POSIX で `start-timer` / `stop-timer` が動くようになった**
    (既知失敗 57 -> 56)。**それまで nil を返すスタブだった。**

    既知失敗は `fix-start-timer` の 1 件だけだったが、**1 件の裏に測られて
    いない機能が 2 つあった**: `lisp/ts.l` の tree-sitter ハイライトの遅延
    更新 (`start-timer 0.1`) と `lisp/grepd.l` の非同期 grep が、どちらも
    黙って動かなかった。

    **`utimer` が OS に触っているのは `SetTimer` / `KillTimer` の 2 つだけ**で、
    残りは待ち行列の管理だった。core へ移し (`src/core/utimer.cc`)、POSIX では
    **端末の `select` の待ち時間を次の期限に合わせる** (`next_timeout_ms`)。
    POSIX には「時間が来たら呼んでくれる」仕組みが無いので、待つ側が期限を
    見るしかない。

    `sleep-for` / `sit-for` も**待っている間に期限の来たものを呼ぶ**ように
    した。Win32 はその間メッセージループを回すのでタイマが動く。1 回の
    `select` で寝てしまうと、`(start-timer 0.5 f)` のあと `(sleep-for 0.2)` で
    待つコードが永遠に進まない (`fix-start-timer` がまさにその形)。

    `unittest/timer-tests.l` に 5 件 (1 回だけ / 繰り返し / 止められる /
    知らない関数は nil / **`sleep-for` の途中で呼ばれる**)。
  * **POSIX の時刻が 1 秒刻みで、しかもタイムゾーンの分ずれていたのを直した**
    (`src/core/platform.h`)。タイマを直す途中で出てきた 2 つのバグ。

    **`GetSystemTime` が `wMilliseconds` を 0 に固定していた。** SYSTEMTIME を
    通る時刻の分解能が 1 秒だったので、**0.05 秒のタイマが「秒が変わるまで」
    来なかった** (実測: `(start-timer 0.05 f)` のあと `(sleep-for 0.5)` で
    0 回。直したあとは 10 回)。`GetLocalTime` も同じ。

    **`SystemTimeToFileTime` が `mktime` を使っていた。** SYSTEMTIME は Win32
    では UTC で、`GetSystemTime` も `gmtime` で作っているのに、`mktime` は
    **ローカル時刻として解釈する**。round trip がタイムゾーンの分だけずれて
    いた (`set-file-write-time` が UTC でない環境で違う時刻を書く)。
    **コンテナは TZ=UTC なので見えなかった。** `timegm` に直した。
  * **端末版で合図 (ベル) が鳴りも光りもしていなかったのを直した**
    (issue #203)。`ding` の**どちらの枝も POSIX では何もしていなかった。**

    ```cpp
    if (xsymbol_value (Vvisible_bell) != Qnil)
      {
        HWND hwnd = get_active_window ();
        RECT r; GetWindowRect (hwnd, &r);   // FALSE、r は未初期化
        ...                                  // GDI の 6 つが全部 no-op
      }
    else
      MessageBeep (x);                       // {} -- 空
    ```

    **エラーも警告も検索の失敗も、合図が 1 つも出ていなかった。** 入口は
    2 つあり、**どちらも既定で開いている**: Lisp の `(ding)`
    (`*beep-on-never*` は nil。isearch / expand-region / iedit /
    fuzzy-complete など 15 ファイル以上が呼ぶ) と、エラー・警告の
    メッセージ (`putmsg` が `Fding` を直に呼ぶ。`*beep-on-error*` と
    `*beep-on-warn*` はどちらも t)。

    **端末には両方ある。** curses の `beep ()` が鳴らす方、`flash ()` が
    光らせる方で、`*visible-bell*` の 2 つの枝にそのまま対応する。

    frontend の seam を 2 つ足した (`frontend_beep` / `frontend_flash`)。
    **どちらを使うかの判断は core に残した** — `*beep-on-never*` と
    `*visible-bell*` の読みを 3 つの frontend に複写したくないので、
    frontend が持つのは「どう鳴らすか」「どう光らせるか」だけ。

    | frontend | 鳴らす | 光らせる |
    | --- | --- | --- |
    | win32 | `MessageBeep` | 今までの GDI の本体 (`gdi-utils.cc` へ移動) |
    | ncurses | `beep ()` | `flash ()` |
    | cli | `\a` を stderr へ | 画面が無いので音に落ちる |

    **`--batch` では curses を上げていないので `stdscr` が 0 で、そこへ
    `beep ()` を呼ばない。** 代わりに端末があるときだけ `\a` を **stderr へ**
    書く — stdout はテストやパイプの相手が読んでいるので混ぜない。

    **`platform.h` から 7 つ消えた** (`MessageBeep` / `GetWindowRect` /
    `LockWindowUpdate` / `GetDCEx` / `PatBlt` / `GdiFlush` / `ReleaseDC` と
    `DSTINVERT` / `DCX_*`)。**core に残っていた GDI 呼び出しの最後の
    まとまり**である (issue #16 の Phase 4)。

    **測り方が要点だった。Lisp スイートからは測れない** — 音も画面の反転も
    返り値を持たず、スイートは全部 `--batch` で curses が上がっていない。
    `tools/linux-smoke.sh` に入れて、**pty の生のバイト列で見る**ようにした
    (`XYZZY_PTY_RAW`)。

    ```
    (ding)                      -> \x07 が 1 個
    *visible-bell* を立てて ding -> ESC[?5h ... ESC[?5l
    ```

    修正を戻すと**どちらも 0 個**になる (実測)。**step ごとの塊を分けて
    見ている**: 全体を grep すると、将来ウィンドウタイトルを OSC で出す
    ようにしたとき終端の BEL を拾って、鳴っていなくても通るようになる。
  * **端末版が既定でダンプイメージを使うようになった。対話起動が 832ms から
    178ms になる** (issue #219)。`-image` を渡さなくても
    **`<設定ディレクトリ>/xyzzy.wxp`** を使い、無ければ 1 回目に作る。

    ```
    1 回目 (作る)      832 ms
    2 回目以降         178 ms      (4.7 倍)
    ```

    **置き場所は exe の隣ではない。** Win32 は exe 名から導くが (`xyzzy.exe`
    -> `xyzzy.wxp`)、POSIX でそれをすると `/usr/bin` に書こうとして毎回失敗
    する。設定と同じ場所に置くのが POSIX の作法である。場所の決め方は
    `-config` -> `XYZZYCONFIGPATH` -> `$HOME` で、**`(user-config-path)` と
    同じ決め方を通す** (`posix_config_dir` に切り出して両方から呼ぶ)。
    Lisp が起きる前に決まらなければならないので、Lisp のシンボルは使えない。

    **`--batch` は既定オフにした。** イメージは Lisp ライブラリ全体を含むので、
    **`.lc` を作り直してもバイナリが同じなら同一性判定 (`dump_exe_ident`) では
    弾けない。** 既定オンにすると、テストスイートと `tools/bytecompile.sh` が
    古いライブラリのイメージ越しに走り得る。速さが要るのは人が待つ対話起動で、
    `--batch` はスイート 1 回につき 1 プロセスしか起きないので効きが小さい。
    **危ない側を既定にしない。** `--batch` でも `-image` を明示すれば使える。

    **切る手段を足した: `-no-image`。** 3.7 MB のファイルを置きたくない場合と、
    `lisp/` を触りながら試す場合。`-image` と両方渡すと `-no-image` が勝つ。

    測るのは 3 つを 1 本で: 1 回目で作る / 2 回目はそれから起きる /
    `-no-image` なら作らない (`tools/linux-smoke.sh`)。**「作る」だけなら既定
    オフでも通る余地があり、「使う」だけなら作る側が壊れても気付かない。**

    `CLAUDE.md` の「古いダンプイメージは絶対アドレスを持っている」も直した --
    **これは誤りで**、イメージは `lmap`/`rlmap` の添字で書いてあり関数ポインタも
    入っていない。**だから POSIX へ移植できた。**
  * **端末のポップアップ (`popup-list` / `popup-string`) に確認を 2 件足した。**
    **端末フロントエンドで最も大きい実装なのに、テストが 1 件も無かった** --
    `ncurses-stubs.cc` の `Fpopup_list` が 275 行、`Fpopup_string` が 131 行で、
    `unittest/` と `tools/linux-smoke.sh` に名前が 1 度も出ていなかった。

    **飾りではなく既定の経路である。** `lisp/startup.l` が端末で
    `*popup-completion-list-default*` を立てるので、`C-x C-f` で候補が複数
    あるとここが出る。

    数えるときに引っかかった: `unittest/popup-window-tests.l` は
    `popup-list` という名前を含むが、あれは `lisp/popup-window.l` の段組みの
    テストで**別のもの**である。**名前で数えると「ある」ことになる。**

    見るのは 3 つ: 枠が出ること / **20 桁の日本語の項目が切れずに収まること** /
    **選んだ文字列がコールバックへ渡ること。** 2 つ目は幅を「文字数」で数えると
    全角が半分に見積もられて**枠が狭いまま項目が切れる**ところ。項目を 20 桁に
    してあるのは **`inner_width` に 13 桁の下限がある**ためで、10 桁 (5 文字)
    では文字数で数えても下限に吸われて差が出ない。3 つ目が要るのは、**描くだけ
    描けて選択が効かない形**があるため。

    **上下の罫線の長さを比べるだけでは幅の確認にならない。** 幅を間違えると
    上下は「揃ったまま一緒に縮む」ので、そこは枠が壊れていないことの確認に
    過ぎない。切れた項目の行を見るのが幅の確認である
    (`tools/linux-smoke.sh` のコメントも直した)。

    負の確認 2 つ (どちらも他の 25 項目は通ったまま):

      * `wcwidth` を 1 に潰す -> `popup-list` と `popup-string` の両方が落ちる
      * コールバックの `funcall_1` を消す -> `popup-list` だけが落ちる

  * **`(set-quit-char nil)` が端末では nil、Win32 では型エラーだったのを
    揃えた** (#234 のテストを書いていて出た)。

    端末側に `if (!c || c == Qnil) return Qnil;` が入っていて、Win32 側
    (`src/frontend/win32/toplev.cc`) は `check_char` を先に通す。**同じ
    呼びが片方だけ通っていた。** 引数は 1 つ必須 (`lisp/builtin.l` の宣言も
    `(char)`) なので nil は呼ぶ側の間違いで、**受け側で黙って飲むと
    「中断文字が変わらない」形で残る。** Win32 に揃えた。

    端末では `C-g` を入力から直に見ている (`ncurses-kbd.cc` の
    `ncurses_quit_char`) ので、ここが効かないと**走っている Lisp を
    止められなくなる** (issue #162 で入れた経路)。

  * **フロントエンドの Lisp 入口にテストを 22 件 + 確認 1 件足した** (#234)。
    実装があるのに測られていなかった 24 個のうち、**`--batch` から測れる
    ものを片付けた。**

    | | 何を見るか |
    | --- | --- |
    | `screen-width` / `screen-height` / `window-width` | **数ではなく関係。** 実測で linux は 80x24、Wine は 119x45 で、端末の大きさと GUI のフォントで決まる。分割して足したら画面に収まること (境界の桁を二重に数えていないこと) |
    | `quit-char` / `set-quit-char` | 書いた文字が読めること。**書く方だけ測ると、返り値を返して何も設定していない形が通る** |
    | `si:*minibuffer-message` | 3 行のメッセージで 3 行になり、nil で 1 行に戻ること。**戻る方が大事** (伸びたまま戻ると編集領域がじわじわ減る) |
    | `si:get-documentation-string` | 全文 / apropos は 1 行目だけ / 無ければ nil |
    | `reset-prefix-args` / `set-next-prefix-args` | 受け付ける形と第 3 引数の型検査 |
    | `continue-popup` | 呼べること |
    | `buffer-selector` | **pty で。** プロンプトが出て、既定の他バッファが返る |

    **測れないものは測れないと書いた。** `*next-prefix-args*` /
    `*minibuffer-message*` / `*minibuffer-prompt*` は **uninterned なので
    Lisp から見えない** (`src/gen-syms.cc` の `unint[]`)。前置引数は次の
    コマンドが受け取る形なので、**コマンドループを 1 周回さないと観測
    できない。** そこは受け付ける形だけを見て、理由をテストに書いた。

    **`get-documentation-string` の 1 件だけ分けた。** property が文字列で
    ないとき、端末は nil を返し (POSIX では `si:*snarf-documentation` が
    空実装なので property が DOC ファイルの位置を表す整数にならない)、
    Win32 はその整数を位置として DOC ファイルを開こうとして **pathname の
    型エラーになる。** Win32 側は DOC ファイルの扱いの話なので測っていない。

  * **`--batch` でエラーが 1 文字も出なかったのを、stderr へ出すようにした**
    (issue #236)。

    ```
    $ xyzzy --batch -q -e '(progn (format t "BEFORE~%") (car 1) (format t "AFTER~%"))'
    変更前: BEFORE                      (AFTER は出ない。エラーの文字も無い)
    変更後: BEFORE
            不正なデータ型です: 1: cons   (stderr)
    ```

    **エラーの行き先がどちらも「描かれない所」だった。** 重要でない側は
    `app.status_window` へ入るが、あれは画面を描く側が読むバッファで、
    `--batch` では誰も読まない (端末版は `g_status_buf` へ memcpy するだけ、
    Win32 版は `SendMessage` の相手が居ない)。重要な側の `MsgBox` は
    `g_batch_mode` のとき既定のボタンを返すだけで何も出さない。**両方とも
    捨てていた。**

    **`--batch -e` はスクリプトが使う形である。** 壊れていても無言で成功に
    見えるので、CI の 1 行が死んでいても緑のまま通る。手で試したときも
    「何も起きない」に見えて手掛かりが無い。

    **stdout ではなく stderr にした。** `tools/bytecompile.sh` と
    `misc/run-tests-batch.l` は stdout を読んでいるので、そこへ混ぜると別の
    ものが壊れる。encoding は `create_std_stream` が決めたものに従うので、
    POSIX では UTF-8、Win32 のコンソールでは CP932 で出る (issue #229 で
    分けたところがそのまま効く)。

    ついでに 1 つ直した: **端末版は core の `g_batch_mode` を立てていなかった。**
    Win32 は `batch-main.cc` が立てているが、端末版は `main` のローカル変数で
    済ませていたので、**core から見ると常に対話**だった。`Fkill_xyzzy` も
    同じ値を見る。

    **終了コードは変えていない。** 非 0 にするのが正しいが、`--batch -e` が
    失敗したら止まるようになるので、既にある呼び元 (`tools/`、CI) を全部見て
    からにする。#236 に段取り 2 として分けてある。

    負の確認 2 つ (どちらも他の 29 項目は通ったまま):

      * `g_batch_mode` を立てるのをやめる -> stderr に何も出なくなる
      * 行き先を `*standard-output*` にする -> stdout に混ざる方で落ちる

  * **端末のメニューに確認を 2 件足した** (#234)。メニューバーは常に描いて
    あるが、**開けるかどうかは別の話**で、そこを見るものが無かった
    (`call-menu` / `create-menu` / `add-menu-item` ほか 11 個)。

    見るのは、ドロップダウンの項目が出ること / **右寄せの割り当て表示
    (`C-x 6 S`) が出ること** / **C-f で隣のメニューへ移ること**、そして別の
    check で**選んだ項目のコマンドが実際に走ること。** 最後のものは描画とは
    別の経路である: `run_menu_modal` は選択を kbdq へ `LCHAR_MENU` として
    積んで戻り、コマンドループが `lookup_menu_command` で引き直して実行する。
    **開いて選べても、その積み直しが落ちていれば何も起きない。**

    **測る前に 2 回読み違えた。** `call-menu` は入った時点ではドロップダウンを
    開かない (`initial_bar_sel` が -1) ので、開く打鍵を送らないと何も出ない。
    そして `tools/pty-drive.py` の画面モデルは属性を落とすので、**メニューバーの
    選択 (反転表示) は dump では見えない。** どちらも「壊れている」に見える。
    同じモデルは**全角を 1 桁として持つ**ので、日本語を含む行の桁を dump の
    文字数から数えてもいけない。**この 3 つを docstring に書いた。**

    負の確認 2 つ (それぞれ狙った check だけが落ちる):

      * `fill_menu_keybinds` を即 return にする -> 「メニュー」だけが落ちる
      * `app.kbdq.putc (LCHAR_MENU | id)` を消す (2 箇所) ->
        「メニューの実行」だけが落ちる

  * **端末でコピーしたものを他のアプリへ貼ると末尾に NUL が付いていたのを
    直した** (issue #198 のテストを書きに行って出た)。

    ```
    (copy-to-clipboard "不正 あいう")   ; UTF-8 で 16 バイト
    変更前: ESC]52;c;5LiN5q2jIOOBguOBhOOBhgAA BEL
    変更後: ESC]52;c;5LiN5q2jIOOBguOBhOOBhg== BEL
    ```

    端末版はクリップボードを OSC 52 で端末へ送る。その `base64_encode`
    (`src/frontend/ncurses/ncurses-stubs.cc`) が、**長さが 3 の倍数でないとき
    `=` を 1 つも出さず、0 で埋めた分を `A` として載せていた。** 受け側は
    NUL 2 個の付いた文字列を貼ることになる (厳格なデコーダなら何も貼らない)。
    `i` を進めながら `(i - 1 > len)` で padding を判定していたが、**足りない
    バイトの分は `i` を進めない**ので条件が最後の塊でも成立しなかった。
    塊に何バイト入っているかを先に数える形にした。

    **3 の倍数の入力では出ない。** `"abc"` は `YWJj` で正しいので、ASCII 3 文字
    で測ると通ってしまう。`tools/linux-smoke.sh` の確認は 16 バイトの日本語で
    見ている。

  * **`copy-to-clipboard` が `--batch` でも端末へエスケープシーケンスを
    書いていたのを直した** (同じ作業で出た)。

    `osc52_copy` は ncurses を通さず fd へ直に書くので、**リダイレクトされた
    stdout にエスケープが混ざる。** すぐ下の `frontend_set_frame_title` は
    同じ理由で `!stdscr || !isatty (STDOUT_FILENO)` の guard を持っているのに、
    **こちらには無かった。** 同じ条件を足した。

    測る側の話でもある: **テストスイートは全部 `--batch` で stdout を読んで
    いるので、`copy-to-clipboard` を 1 件でも測るとログにシーケンスが入る。**
    クリップボードのテストが 1 件も無かったこと (issue #198) と、この guard が
    無かったことは繋がっている。バッファ (`g_clipboard_buf`) の更新は送信より
    先なので、送らなくても `get-clipboard-data` は往復する。

    **guard は両面を見ないと守れない。** 「出ない」だけを確認すると機能ごと
    止めたときに通り、「出る」だけを確認すると常に出す形へ戻したときに通る。
    `tools/linux-smoke.sh` に 2 件足した (pty では出る / `--batch` では出ない)。

  * **クリップボードの Lisp 入口 3 つにテストを 7 件足した** (issue #198)。
    `copy-to-clipboard` / `get-clipboard-data` / `clipboard-empty-p` は
    `unittest/` と `tools/linux-smoke.sh` の両方に 1 件も出てこなかった。

    **`(featurep :unix)` で分ける必要は無かった。** issue #198 は分けろと
    書いていたが、14 項目を linux native と Wine x86_64 の両方で実際に測ったら
    **返り値まで全部一致した** -- 空文字列で `nil` を返して中身を変えないこと、
    非 ASCII が文字コードで往復すること、改行が LF 1 個で往復すること、
    文字列以外で `type-error` になること。**一致しているものを分けて書くと、
    片方が壊れたときに「元からそういう仕様」に見えてしまう。**

    分かれるのは**プロセスをまたぐかどうかだけ**である。端末は
    `g_clipboard_buf` なのでプロセス内で閉じ、Win32 は OS のクリップボードな
    ので親が書いたものが子から見える。**測るのは端末側だけにした**: 親が書いて
    子が読む形は、同時に走っている別のプロセスがクリップボードを置き換えたら
    落ちる。**落ちうるテストを足すより「測らない」と書く方を選んだ** (PR #71
    で flaky を 1 つ潰しているので、その判断に倒す)。

    非 ASCII と改行は**文字コードで見る**。表示は stream の encoding を通るので、
    内部が壊れていても正しく見えることがある (直前の `--batch` の CP932 が
    まさにそれだった)。

  * **`--batch` の標準出力が CP932 + CRLF だったのを UTF-8 + LF にした**
    (issue #229 を測っている途中で見つけた)。

    ```
    $ xyzzy --batch -q -e '(format t "~A~%" (map (quote string) (function code-char) (list 19981 27491)))'
    変更前: \x95\x73\x90\xb3   (CP932 の「不正」)
    変更後: 不正             (UTF-8。行末の CR も消えた)
    ```

    **メッセージ表は壊れていない。** `char-code` で見ると内部表現は正しく
    (不 = 19981)、**出口の 1 行が CP932 に落としていた。** `create_std_stream`
    (`src/core/stream.cc`) が encoding を設定しないので、`make_stream` の既定
    `ENCODE_CANON` (= CP932 + CRLF) になっていた。Win32 の日本語コンソールでは
    それが正しいので、**POSIX だけ `ENCODE_RAW_UTF8` にした。**

    **対話の端末フロントエンドはこの経路を通らない** (`*standard-output*` は
    status stream) ので、smoke の「日本語 OK」は通ったまま `--batch` の側だけ
    壊れていた。**測る場所が無かったので、`tools/linux-smoke.sh` に
    バイト列で見る確認を足した。**

    行末の `\r` も消えた。他のコマンドへ繋いだときに CR が混ざらない。

    **例を差し替えた** (2026-09-02)。元は `-e '(car 1)'` のエラー文で書いて
    あったが、**あの例は再現しない** -- `--batch` ではエラーが行き先ごと
    捨てられていて、CP932 も UTF-8 も出ていなかった (下の #236 の項)。
    直したのは `format t` (= `*standard-output*`) の encoding で、
    `tools/linux-smoke.sh` の「batch の標準出力」が見ているのもそれである。

  * **`:ssl t` のエラーが「削除はサポートしていません」だったのを直した**
    (issue #229)。

    ```
    変更前: 削除はサポートしていません
    変更後: SSLはこのビルドではサポートしていません
    ```

    `Eremove_not_supported` を流用していた。**SSL を頼んだ人に削除の話をして
    いた。** `Essl_not_supported` を足して 2 か所 (`connect :ssl t` と
    ストリームの後付け SSL) を直した。

    **測って分かった良い方の話: POSIX で SSL は「黙って平文」にはならない。**
    `src/core/sockssl.cc` は全体が `#ifdef _WIN32` で、`stream.cc` の
    `#else` がはっきり断る。`platform.h` の SChannel スタブも実務をするものは
    `-1` (失敗) を返す形で、**到達もしない。** SSL を頼んだのに平文で送るのが
    一番悪い形なので、そこを先に測った。
  * **解決できないホスト名のエラーが `gethostbyname: Success` だったのを直した**
    (issue #223)。

    ```
    変更前: gethostbyname: Success
    変更後: gethostbyname: Host not found
    ```

    **`gethostbyname` は `errno` を触らない。** 立てるのは `h_errno` である。
    なのに `sock_error (ope)` の 1 引数版は `WSAGetLastError ()` (= POSIX では
    errno) を読んでいたので、**直前の成功した操作の errno = 0 が出て
    「Success」になっていた。**

    **`h_errno` を errno に入れ直すのも駄目である。** `HOST_NOT_FOUND` = 1 は
    `EPERM` で、`TRY_AGAIN` = 2 は `ENOENT`、`NO_RECOVERY` = 3 は `ESRCH`、
    `NO_DATA` = 4 は `EINTR`。**1..4 が完全に重なる。** それをやると
    「Operation not permitted」と出る -- issue #212 で直したのと同じ形の嘘に
    なるだけである。

    `src/core/error.h` の category に **`DNS_ERROR` を足した。** あのファイルは

    > **番号だけを裸で持ち回ると空間をまたいで誤って当たる。**

    と書いてあり、`CRTL_ERROR` / `WIN32_ERROR` / `WSA_ERROR` の 3 つを分けた
    のと同じ理由で 4 つ目が要る。`sock_error` が番号と category を対で持ち、
    `FEsocket_error` がそれをそのまま `make_error` に渡す。

    **ついでに分かったこと: POSIX でホスト名は前から解決できていた。**
    `resolver.h` の非 Win32 側に同期版 (`gethostbyname` を呼ぶだけ) が既に
    あった。**issue #223 に「名前解決が無い」と書いたのは誤りで**、無いのは
    Win32 の非同期の仕組み (ウィンドウメッセージ) だけである。測って分かった。
    ホスト名で繋ぐテストも足した (`socket-connect-by-hostname`)。
  * **POSIX でソケットが使えるようになった** (issue #223 の段取り 2)。
    落ちなくしただけだったところに BSD ソケットの実体を入れた。

    ```lisp
    (let* ((srv  (make-listen-socket "127.0.0.1" 0 :reuseaddr t))
           (port (socket-stream-local-port srv))
           (cli  (connect "127.0.0.1" port))
           (acc  (accept-connection srv)))
      (format cli "ping~%") (finish-output cli)
      (read-line acc))                        ; => "ping"
    ```

    `WSOCKDEF` の並びは BSD とほぼ 1:1 だが**型がずれる**ので、そのまま
    アドレスを取って代入できない。長さの引数が `int *` と `socklen_t *`、
    バッファが `char *` と `void *`、`send` / `recv` の戻りが `int` と
    `ssize_t`。`htons` などは Linux では**マクロ**なのでアドレスが取れない。
    薄いアダプタを並べた。

    **`select` の第 1 引数に罠があった。** core は `select (1, ...)` と
    呼んでいる -- **Winsock はそこを無視するので Win32 では正しい。** POSIX の
    `select` は「最大の fd + 1」を要求するので、**1 のままだとデータが
    あっても常にタイムアウトになる。** 呼び出し側を直すのではなくアダプタで
    数える (表の裏に隠す差は表の裏で閉じる)。

    **ブロッキングでエディタが固まらないようにした。** Win32 は
    `WSASetBlockingHook` で、ブロッキング中に Winsock 側から呼び返して
    もらって `Fdo_events` を回す。POSIX にその仕組みは無いので、
    `connect` / `accept` / `recv` / `send` の前に `select` で刻みながら待ち、
    その隙間で `Fdo_events` を回して `C-g` も見る。**既定のタイムアウトは
    -1 (無限) で、core 側の `readablep` / `writablep` の門は
    `s_rtimeo.tv_sec >= 0` でしか通らないので、既定では core に一切の待ちが
    無かった。**

    **使われていないものは dummy のままにした。** `sock::ioctl` には
    呼び出し元が 1 つも無く、`gethostname` は `WS_CALL` がどこにも無い。
    **到達しないものにアダプタを書くと、動くと主張したことになる。**

    テストは 4 件。**同じプロセスの中で往復させる** -- 外のサーバに繋ぐと CI の
    環境に依るし、子プロセスを立てると片方が落ちたときにどちらが悪いか
    分からない。ポートは 0 で開いて実際の番号を聞く (決め打ちは CI で衝突する)。
    **Windows でも 4 件通る** ので、移植性のあるテストになった。

    **まだ名前解決が無い** (`s_resolver` は Win32 の非同期ウィンドウ
    メッセージで作られている) ので、**ホスト名では繋がらない。** IP アドレス
    だけである。issue #223 の段取り 3。
  * **POSIX で `(connect ...)` / `(make-listen-socket ...)` がエディタごと
    SIGSEGV していたのを直した** (issue #223)。`handler-case` でも捕まらない
    ので、**対話中に呼べば未保存のバッファごとプロセスが消えていた。**

    ```
    $ xyzzy --batch -q -e '(handler-case (connect "127.0.0.1" 80) (error (e) e))'
    Fatal signal 11
    Segmentation fault (core dumped)
    ```

    門は何も閉まっていない。`Fconnect` / `Fmake_listen_socket`
    (`src/core/stream.cc`) は `#ifdef _WIN32` の外で、`lisp/builtin.l` の宣言も
    無条件である。**「POSIX には無い機能」ではなく、呼べて落ちる機能**だった。
    既定で起動時に呼ぶものは無いので起動は壊れないが、**ネットワークを触る
    拡張を 1 つ書いた瞬間に 100% 落ちる。**

    `src/core/sockimpl.h` は Winsock を**関数ポインタの表**で呼ぶ (Win32 は
    `WSOCK32.DLL` を `LoadLibrary` して埋める設計)。表を埋める
    `init_winsock_functions` を呼ぶのは `sock::init_winsock` の
    `#ifdef _WIN32` 側だけで、しかもその `sock::init_winsock` を呼ぶのは
    `src/frontend/win32/init.cc` の 1 か所だけ。**POSIX では表が一生 null の
    ままで、`WS_CALL (socket)(...)` が null 関数ポインタ呼び出しになっていた。**

    **正直な代替は最初から書かれていた。** `WSOCKDEF` の第 4 引数が失敗値で、
    `dummy_socket` などが `INVALID_SOCKET` / `SOCKET_ERROR` を返すように
    用意されている。しかも POSIX では `LoadLibraryW` が 0 を返すので、
    **`init_winsock_functions` は POSIX でもそのまま正しく動く** (全部 dummy を
    入れる)。呼ばれていなかっただけだった。

    直しは**表を最初から dummy で初期化する**こと。呼ばれる順序に関係なく
    最悪でも「正直な失敗」になり、Win32 でも `init_winsock` を呼び忘れても
    落ちなくなる (安全側)。

    **文言も直した。** `WSASYSNOTREADY` (10091) は errno に対応物が無く、
    `platform.h` でも Win32 の番号のまま置いてあるので `strerror` に渡すと
    「**Unknown error 10091**」になっていた。POSIX で最初に出るのがこれなので、
    番号に対応物が無い 4 つ (10091/10092/10093/10101) だけ明示した:

    ```
    変更前: socket: Unknown error 10091
    変更後: socket: Socket subsystem is not available
    ```

    **名前解決の 4 つ (`WSAHOST_NOT_FOUND` = 1 ..) はここでは直せない。**
    POSIX では 1..4 が `EPERM`..`EINTR` と完全に重なっていて、番号だけでは
    見分けられない。実体を入れるとき (`getaddrinfo`) に別の category で持つ
    形で直す。そう書いてある。

    **ソケットが使えるようにはなっていない。** 実体 (BSD ソケット) を入れるのは
    issue #223 の段取り 2 で、これは段取り 1 (落ちなくして、テストが書ける
    状態にする) である。テストは「使えること」ではなく「**Lisp のエラーとして
    返ること**」と「番号が裸で出ていないこと」を見る。
  * **ダンプイメージに「どのバイナリが書いたか」を持たせた** (issue #219 の続き)。
    これが無いと、**再ビルドした後の古いイメージが「有効」と判定される。**

    ヘッダの互換性判定は `dump_version` で、これは `gen-syms` を走らせた時刻を
    焼いた定数である。CMake の依存は:

    ```
    DEPENDS gen-src1 ${SRC_DIR}/gen-syms.cc
    ```

    つまり **`gen-syms.cc` 以外を直した再ビルドでは変わらない。** 構造体の
    レイアウトを変えて作り直しても古いイメージが通り、エラーもクラッシュも
    なく壊れた状態で動き出す (`CLAUDE.md` の「出力ゼロで 100% CPU なら
    `.wxp` を疑う」がこれ)。Win32 はこの露出を持ったまま動いてきたが、
    **踏まずに済んでいたのはツールが `.wxp` を消すガードを持っていたから**で
    (`tools/bytecompile.sh` / `run-tests.sh` / `wine-run.sh`)、ユーザの手元に
    そのガードは無い。

    ヘッダに**実行ファイルの大きさと更新時刻**を入れた。再ビルドすれば必ず
    どちらかが変わるので、古いイメージはヘッダの段で弾かれて通常起動に落ちる
    (1 回遅く起動して作り直される)。stat 1 回なので起動の速さには影響しない。

    **これで完全ではない。** 更新時刻を保って入れ替えられ、かつ大きさも同じ
    バイナリは見分けられない。中身のハッシュなら確実だが起動のたびに数 MB
    読むことになるので、**踏む形 (再ビルド) を全部止められれば実用上足りる**と
    判断した。そう書いてある。

    測るのは「弾く」だけでは足りない -- 判定を常に false にしても通ってしまう。
    `tools/linux-smoke.sh` は**4 つの状態を順に見る**: 本体で作って読む (通る)
    -> 更新時刻を変えた別バイナリで読む (弾く) -> 作り直された後は同じコピーで
    通る -> 本体では今度は弾かれる。**exe をコピーして `touch` するので Lisp
    からは測れない** (走っている exe の更新時刻は変えられない)。

    既存の `.wxp` は 1 回だけ無効になる (Win32 も含む)。
  * **16 年ぶんの FIXME を閉じた: `*load-pathname*` のテストが、ダンプイメージを
    使わずにダンプイメージの性質を測っていた** (issue #219 の続き)。

    2010 年の修正 (「ダンプ作成時にロードしたファイル名がダンプに保存されるので
    起動時に初期化する」) を守るテストは、こう書いてあった:

    ```lisp
    ;; FIXME: ダンプイメージがまだ無い場合 pass ってしまう。
    (eval-in-another-xyzzy `*load-pathname* :options "-q")
    => nil
    ```

    **`-image` を渡していないので、イメージから起きたかを制御していない。**
    Win32 では `xyzzy-batch.exe` が隣の `.wxp` を勝手に読むおかげで偶然 nil に
    なり、POSIX ではイメージを使わないので `startup.l` を load している最中の
    値 (`"/work/lisp/startup.l"`) が見えて落ちていた。**16 年間、Windows では
    偶然通り、POSIX では既知失敗として置かれていた。**

    イメージを本当に作ってから測る形に書き換えた。2 回起動する必要がある
    (1 回目が作り、2 回目が読む) ので `with-dump-image` として
    `unittest/simple-test.l` に置いた。

    **負の確認で、これが初めて本当の見張りになったことを確かめた。**
    `Vload_pathname = Qnil` の 1 行 (2010 年の修正そのもの) を消すと、
    **このテストだけ**が落ちる。書き換える前は、修正が有るか無いかに関係なく
    既知失敗だった。

    ついでに責任を分けた。`dump-image-actually-loads` は「イメージが使われて
    **関数が生きている**」を見る (シンボルが戻っても builtin の関数ポインタが
    貼り直されていなければ何もできない)。`*load-pathname*` はこちらの
    歴史的テストが持つ。既知失敗は 10 -> 9 件。
  * **POSIX でダンプイメージが使えるようになった。起動が 762ms から 206ms に
    なる** (issue #219)。**書く側は前から動いていて、読む側が繋がって
    いなかった** -- 誰も測っていなかったので誰も知らなかった。

    ```
    $ xyzzy --batch -q -e '(dump-xyzzy "/tmp/probe.wxp")'
    size=(4119575)      # 前からこれは動いていた
    ```

    `Fdump_xyzzy` / `rdump_xyzzy` (`src/core/data.cc`) が使う `_wfopen` /
    `_wfsopen` は `src/core/platform.h` で shim 済みで、**イメージは絶対
    アドレスではなく `lmap`/`rlmap` の添字で書いてある**ので原理的な障害も
    無かった。関数ポインタもイメージに入っていない (`combine_syms` が名前で
    貼り直す)。繋がっていなかったのは 3 か所だけ:

    | | Win32 | 端末版 (直す前) |
    | --- | --- | --- |
    | `-image <path>` を argv から読む | ある | **無い** |
    | `app.dump_image` / `Qdump_image_path` | 設定する | `Qnil` 固定 |
    | 起動時に `rdump_xyzzy ()` を呼ぶ | ある | **呼ばれない** (宣言だけあった) |

    **`-image` を渡したときだけ使う形にした。** Win32 は exe の名前から
    イメージのパスを必ず導くので `(si:dump-image-path)` が常に非 nil で、
    初回起動で黙って作る。端末版で同じことをすると `xyzzy` と打つだけで
    4 MB のファイルが増えるので、既定の起動経路は変えていない。**既定に
    するかは別の判断**として残した。

    **測るのは「作れた」ではなく「作って、それで起きて、関数が生きている」**
    の 3 つを 1 本で見る (`tools/linux-smoke.sh`)。シンボルだけ戻っても
    builtin の関数が貼られていなければ編集はできないので、書く側だけを
    測っていると今回のような穴が空いたままになる。対話版も別に測る --
    **batch だけ通って対話が通らない形が実際にあった** (issue #217)。

    既知失敗が 1 件外れた (`image-startup-option`)。**もう 1 件
    (`fix-*load-pathname*-from-dump-image`) は残す** -- あれはテスト自身が
    `;; FIXME: ダンプイメージがまだ無い場合 pass ってしまう` と認めていて、
    **Win32 でも「nil であること」を偶然で測っている。** 代わりに
    `dump-image-actually-loads` が子プロセスを 2 回起こして (1 回目が作り、
    2 回目が読む)、`(xyzzy-dumped-p)` と `*load-pathname*` を一緒に見る。
  * **端末版が `~/.xyzzy` をまったく読んでいなかったのを直した** (issue #217)。
    `lisp/startup.l` の `si:*startup` は `#-ncurses` 側が `ed::startup` を
    呼ぶだけなのに対し、**`#+ncurses` 側は `ed::startup` の中身を手で書き
    写していて、写し損じた分がそのまま欠けていた。**

    ```
    ~/.xyzzy                     読まない
    ~/.xyzzy.history             読まない (書くだけ -- 保存フックは登録済み)
    -q / -no-init-file           食べないので「-q」という名前のバッファが開く
    *pre-startup-hook*           走らない
    keep-compatibility           呼ばれない (*last-xyzzy-version* が未束縛)
    init-misc-options            呼ばれない (タブ幅・禁則が設定値を見ない)
    init-pseudo-frame            呼ばれない (*pseudo-frame-list* が空)
    ```

    **写し間違いではなく、写すという方針自体が保たない。** 直しは
    `si:*startup` を両フロントエンドで `(ed::startup)` の 1 行にし、端末
    固有のキー割り当て (`DEL`、`F10`、`S-矢印`) を `*pre-startup-hook*` へ
    移した。**フックに置いたのは `~/.xyzzy` より前に走らせるため**で、
    既定値がユーザ設定を後から上書きしないようにする。

    **対話版はさらに引数を全部捨てていた。** `si:*command-line-args*` を
    積んでいるのは `BatchFrontend::init` だけで、`NcursesFrontend::init`
    には無かった。つまり `xyzzy foo.txt` が端末で何も開かない。積む処理を
    `init_command_line_args` に切り出して両方から呼ぶ
    (`src/frontend/ncurses/ncurses-main.cc`)。

    **テストが全部 `--batch -q` で走ることが、この穴を隠していた。** その
    呼び方は「`~/.xyzzy` を読まない」ことを期待する形なので、読まないバグは
    そこでは見えない。既知失敗にも 1 件も現れていなかった。`ed::startup` の
    後半 (`keep-compatibility` / `init-pseudo-frame` / `-q` の消費 / 引数の
    ファイル) は `-q` 付きでも測れるので**普通のテストにした** (5 件、
    `unittest/editor-tests.l`)。`~/.xyzzy` と履歴は `HOME` を差し替えて測る
    ので unix 限定にした -- Windows は `XYZZYHOME` を先に見て、それは同時に
    子プロセスの `lisp/` の場所も変えてしまう。**対話版の引数だけは Lisp から
    測れない** (テストは子プロセスを `--batch` で起こす) ので、
    `tools/linux-smoke.sh` に pty の確認を足した。`tools/pty-drive.py` は
    引数を渡せなかったので `XYZZY_PTY_ARGS` を足した -- **渡せないままだと
    「引数が効かない」ことは測れない。**
  * **既知失敗 1 件の裏で、リーダを測る 18 個の値が POSIX で暗かった**
    (issue #215)。`lisp-mode-eval-last-sexp` は **19 個の値を 1 つの
    `deftest` で見ていて、COM が要るのは 1 個だけ**だった
    (`#{fso.BuildPath[...]}`)。`deftest` は 1 個でも合わなければ落ちるので、
    `#x123` / `#3(1 2)` / `#2A((1))` / `#C(1 2)` / `#<function: car>` が
    `reader-error` になること、といった**どこでも同じ答えになる 18 個が
    まるごと測られていなかった。** 個別に測ったら全部期待どおりだったので、
    OLE の 3 行だけを別の `deftest` に分けた。

    **既知失敗の件数は変わらない** (`lisp-mode-eval-last-sexp` が
    `lisp-mode-eval-last-sexp-ole` に替わるだけ) が、測られる性質が 18 個
    増えた。`misc/known-failures/linux.txt` の分類は**理由としては正しかった**
    -- 群の見出しが隠していたのは「COM が無い」ではなく「リーダを測るテストが
    1 つ無い」である。

    **同じ形が 3 度目である。** 同じファイルに 2 回書いてあった:
    `fix-start-timer` の 1 件の裏に測られていない機能が 2 つ (tree-sitter の
    ハイライト遅延更新と非同期 grep)、`formatter-*` の 8 件のうち 5 件が
    「コマンドが起動できないから通る」。**群の名前が正しくても、テストの粒度が
    粗いと中の性質が測られない。** 名前を足すときの注意として
    known-failures に書き足した。
  * **POSIX で `write-registry` のエラーが「Operation not permitted」に
    なっていたのを直した** (issue #212)。**あの文言は嘘である** -- レジストリが
    無いことと権限が足りないことは別の話で、ユーザに `chmod` や `sudo` を
    探させる。

    `Reg*` は他の Win32 API と違って**エラーコードを `GetLastError ()` では
    なく戻り値で返す。** `src/core/environ.cc` の Registry 系はそれを

    ```cpp
    if (e != ERROR_SUCCESS) { hkey = 0; SetLastError (e); }
    ```

    と持ち回し、POSIX の `SetLastError` は errno への代入 (`platform.h`) なので、
    **スタブの「失敗 = 1」がそのまま errno の 1 = `EPERM` になっていた。**
    番号の空間を跨いで裸の整数を持ち回ると誤って当たる、という #120 と同じ
    話がここにも残っていた。

    スタブが `ENOSYS` を返すようにした。その経路を通っても意味が変わらない:
    **「このプラットフォームにその機能が無い」がここで起きていることそのもの**
    である。`ERROR_SUCCESS` 以外なので失敗の判定は変わらず、特別扱いされて
    いる `ERROR_FILE_NOT_FOUND` (2) と `ERROR_NO_MORE_ITEMS` (259) の
    どちらとも衝突しない。**core は 1 行も触っていない。**

    ```
    変更前: Operation not permitted: "Settings"
    変更後: Function not implemented: "Settings"
    ```

    **読み側は nil のままにした。** `read-registry` / `list-registry-key` が
    黙って nil を返すのは嘘ではない (値が無いのだから)。書き側と揃えて
    エラーにする理由が無い。

    起動には影響しない (測った)。`lisp/history.l` の compat 経路は
    `*convert-registry-to-file-p*` で門が閉まっていて、**この変数は
    `src/frontend/win32/init.cc` でしか設定されない**ので端末版では nil の
    ままである。

    テストは**期待値を文言そのもので書かず、「出てはいけないもの」を見る**形に
    した (`strerror` は locale で変わる)。`create-directory` で同じことを
    している (issue #121)。負の確認で、`ENOSYS` を 1 に戻すと
    `write-registry-error-is-not-nonsense` **だけ**が落ちることを確かめた。
  * **端末版でウィンドウ (タブ) のタイトルが出るようにした** (issue #211)。
    `Buffer::refresh_title_bar` (`src/core/Buffer.cc`) は組み立てたタイトルを
    `SetWindowTextW (app.toplev, ...)` へ渡していて、POSIX ではそれが
    `FALSE` を返すだけのスタブだったので**組み立てた文字列を捨てていた。**

    **出す先だけの話ではなかった。** タイトルを更新すべきか判断して
    `refresh_title_bar` を呼ぶ `Buffer::set_frame_title` の呼び出し元は
    `src/frontend/win32/disp.cc` の 1 箇所しかなく、**端末の再描画からは
    呼ばれていなかった。** 出口を直しても、呼ばれなければ何も変わらない。

    ベル (issue #203) と同じ形にした。**タイトルを組み立てる所は core に
    残し**、出す所だけ seam にした:

    ```cpp
    void frontend_set_frame_title (const Char *title);   // src/core/fns.h
    ```

      win32   : 今までの SetWindowTextW (app.toplev, ...)
      ncurses : OSC 0 (ESC ] 0 ; <title> ST)
      cli     : 画面が無いので何もしない

    `title-bar-format` の展開、ファイル名とアプリ名の並び順
    (`*title-bar-text-order*`)、管理者権限の印は**どの環境でも同じ答えを出す
    べきもの**なので core に置いたままである。**core から user32 の呼び出しが
    2 つ減った** (issue #16 の Phase 4)。

    終端は BEL ではなく **ST (`ESC \`) を使う。** BEL だと
    `tools/linux-smoke.sh` のベルの check (生のバイト列から `\x07` を探す) と
    混ざって、鳴っていないのに通るようになる。

    **制御文字は落としている。** POSIX のファイル名には ESC も改行も入れられ
    るので、そのまま流すと**タイトルの中から端末へ好きなエスケープシーケンス
    を送り込める。**

    終了時にタイトルを元へ戻す (`CSI 22;0t` で積んで `CSI 23;0t` で降ろす)。
    これが無いと、xyzzy が終わった後もシェルのタブに開いていたファイル名が
    残る。解釈しない端末は CSI をそのまま無視する。

    実測 (`XYZZY_PTY_RAW=1`、`tools/linux-smoke.sh` に入れた):

    ```
    起動時         -> ESC]0;xyzzy 0.6.0-... - *scratch*ESC\
    find-file の後 -> ESC]0;xyzzy 0.6.0-... - /work/README.mdESC\
    ```

    **塊ごとに分けて見ている**: 全体を grep すると「バッファを切り替えても
    タイトルが変わらない」を見逃す。1 打鍵ごとに OSC を投げているわけでは
    ない (`set_frame_title` が変化を見ている。実測で 2 回だけ)。
  * **POSIX で `(special-file-p ...)` が常に nil だったのを直した**
    (issue #206)。`src/core/platform.h` の `GetFileType` が**常に
    `FILE_TYPE_DISK` を返すスタブ**だったので、`special_file_p`
    (`src/core/pathname.cc`) の

    ```cpp
    int dev = GetFileType (h) != FILE_TYPE_DISK;   // 常に 0
    ```

    が**デバイスノードにも FIFO にもソケットにも「ふつうのファイル」と
    答えていた。**

    **1 個の答えで 7 つの門が開いていた。** `(special-file-p ...)` 自身より、
    それを見て弾く側が問題だった。門に条件変数は無いので、既定の設定でそのまま
    通る:

    | 呼び出し元 | 通ると何が起きるか |
    | --- | --- |
    | `find-file` / `read-file` / `insert-file` (`lisp/files.l`) | `C-x C-f /dev/null` がデバイスファイルをバッファとして開く |
    | `insert-file-contents` (`src/core/insdel.cc`) | 同上を Lisp から |
    | `Buffer::save_buffer` (`src/core/fileio.cc`) | **改名による保存 (precious file の作法) をデバイスファイルに対してやる** |
    | `do_auto_save` / `write-region` (同) | 同上 |

    POSIX の `HANDLE` は fd なので (`WINFS::CreateFile`, `vfs-posix.cc`)、
    `fstat` の `st_mode` から `S_ISCHR` / `S_ISBLK` を `FILE_TYPE_CHAR`、
    `S_ISFIFO` / `S_ISSOCK` を `FILE_TYPE_PIPE` に写した。**Windows でも
    パイプのハンドルは `FILE_TYPE_PIPE` を返すので、両方の答えが揃う。**

    **測っていて 2 つ目が出てきた。`GetFileType` を直すだけでは FIFO の経路は
    答えに到達しない。** POSIX の `open(2)` は FIFO の相手側を待ち合わせるので、
    種類を知るために一度開くだけの `special_file_p` が**書き手が現れるまで
    xyzzy 全体を固めていた** (`C-x C-f` で FIFO を指すと戻ってこない。実測で
    確認した)。`WINFS::CreateFile` が `O_NONBLOCK` を付けて開き、開いたら
    `fcntl` で外すようにした -- **実際の read/write はどの呼び出し元から見ても
    これまで通り待つ。** ふつうのファイルに `O_NONBLOCK` は何の効果も無い。
    同じ理由で `O_NOCTTY` も足した: 種類を調べるためにデバイスノードを開くの
    だから、`/dev/tty*` を渡されたときに制御端末を取ってしまわないように
    する。

    FIFO のテストは**別プロセスで測っている** (`eval-in-another-xyzzy` の
    `:timeout`)。戻らなくなったときに**スイート全体を止めずに赤にする**ため。
  * **POSIX でタイムゾーンが常に UTC だったのを直した** (issue #204)。
    `src/core/platform.h` の `GetTimeZoneInformation` が**構造体を 0 で埋めて
    返すだけ**だったので、`Bias` が常に 0 になっていた。

    | Lisp | 何がずれていたか |
    | --- | --- |
    | `(get-decoded-time)` | 8 番目の値 (タイムゾーン) が常に 0、7 番目 (夏時間) が常に nil |
    | `(encode-universal-time ...)` / `(decode-universal-time ...)` | タイムゾーンを明示しないと UTC+0 として扱う。**地方時の offset の分だけ間違った値** |

    エラーは出ない。POSIX には `localtime_r` の `tm_gmtoff` と `tm_isdst` が
    あるので、そこから組むようにした。**`Bias` は「標準時の (UTC - 地方時)」
    を分で**表したもので、`tm_gmtoff` (地方時 - UTC、秒、夏時間を含む) とは
    符号も単位も基準も違う。呼び出し側が夏時間のときに 3600 秒引くので、
    そこと噛み合わせて `isdst > 0` なら `(-tm_gmtoff + 3600) / 60` にした。

    **上の `SystemTimeToFileTime` と同じ理由で見えていなかった。** コンテナも
    CI の runner も TZ=UTC なので、**間違った値と正しい値が一致する。**
    2 度目なので、**測り方の方を直した**: `call-process` の `:environ` が
    POSIX でも動くようになっている (issue #50) ので、**TZ を変えた子プロセス**に
    答えさせる形にした (`unittest/environ-tests.l` に 3 件)。TZ には
    `JST-9` という POSIX 形式を使う — `Asia/Tokyo` と違って **tzdata の
    ファイルが要らない**ので、テストが `/usr/share/zoneinfo` の中身に依らない。

    **夏時間の差が 1 時間でない地域は今も合わない。** 呼び出し側
    (`src/core/environ.cc` の `get_timezone`) が `-3600` を決め打ちしていて、
    この関数だけでは直せない (Win32 は `DaylightBias` を別に持っている)。

    見つけ方: `src/core/platform.h` の 183 個の inline スタブを
    **「呼ばれているのに no-op なもの」**で数え上げた (issue #16 の Phase 4)。
    12 件あり、これはそのうちの 1 件。
  * **`*detect-char-encoding-mode*` が `:xyzzy` のとき、UTF-16LE の BOM 付き
    ファイルが判定されなかったのを直した** (issue #205)。

    `src/core/kanji.cc` の `detect_char_encoding_xyzzy` は、**LE と BE で
    違う判定を通していた:**

    ```cpp
    // LE
    !sysdep.WinNTp () ? simple_unicode_p (...) : IsTextUnicode (...)
    // BE (すぐ下)
    simple_rev_unicode_p (...)
    ```

    Win9x では `IsTextUnicode` が当てにならないので自前で見て、NT では API に
    任せる、という**Win9x 時代の分岐**である。POSIX では `IsTextUnicode` が
    常に FALSE を返すスタブで、`WinNTp ()` は偽の `GetVersionExW` のおかげで
    真になるので、**LE の枝が一度も通らなかった。BE は本物の判定があるので
    通る。**

    **「POSIX だけ `simple_unicode_p`」は選ばなかった。** core に `#ifdef` を
    増やす (issue #16 の方針に反する) 上に、**BOM が既にある場所で
    `IsTextUnicode` の統計的な判定を通す必要がそもそも無い。** BE の枝が
    まさにそう書かれていて、**この 2 つが非対称だったこと自体がおかしい。**
    LE も `simple_unicode_p` に寄せ、`IsTextUnicode` のスタブを消した。

    **Win32 の挙動は変わる。** `IsTextUnicode` は第 3 引数 0 で「全部の
    テストを行う」意味になり、**本物の UTF-16 を弾くことがある** (有名な
    "Bush hid the facts" と同じ性質)。変わる方向は**「BOM 付きの UTF-16LE を
    弾かなくなる」側だけ**である。

    **最初に「`find-file` の自動判定が壊れている」と書いたが、それは
    間違いだった。** 判定は `*detect-char-encoding-mode*` で 2 通りあり、
    **既定は `:libguess`** で両方のフロントエンドが起動時にそう設定している。
    `:xyzzy` を選んだ人にだけ起きる。

    **分かったのはテストを書いて修正を戻したから**である。戻しても通って
    しまい、証拠が出ないので経路を追い直した。**「呼ばれているのに no-op」の
    数え上げでは、その呼び出しが既定の設定で到達するかまでは見ていなかった。**

    テストは 4 件 (`unittest/editor-tests.l`)。既存の
    `find-file-auto-encoding-*` 4 件はマジックコメントで判定を誘導するので、
    **BOM だけで判定する経路は 1 件も測られていなかった。** `:libguess` と
    `:xyzzy` の両方 x LE / BE で測る — **既定の側だけ見ていると `:xyzzy` の
    壊れが見えない**ことが実際に分かったので。`*detect-char-encoding-mode*`
    は `setf` で変える: **`let` の束縛は C++ から見えない**
    (`xsymbol_value` は大域の値を読む。`si:octet-length` の既定値で同じ
    ことを踏んだ)。
  * **POSIX で FFI が使えるようになった** (issue #133 の段階 2〜3、
    既知失敗 59 -> 57)。**libffi は要らなかった。**

    ```lisp
    (c:define-dll-entry c:int (_abs :convention :cdecl) (c:int)
      "libc.so.6" "abs")
    (_abs -5)        ; => 5
    ```

    実測 (glibc): `abs(-5)` = 5、`getpid()` が `si:getpid` と一致、
    `atoi("42")` = 42、`llabs(-8589934592)` = 8589934592、`strchr` が
    ポインタを返す。

    **判断待ちにしていた「libffi を入れるか」は、要らない判断だった。**
    `src/frontend/win32/dll.cc` の x86_64 の枝は、アセンブリでも libffi でも
    なく**関数ポインタのキャスト**で呼んでいる:

    ```cpp
    typedef int64_t (*f2)(int64_t, int64_t);
    r = ((f2)proc)(a[0], a[1]);
    ```

    **呼び出し規約はコンパイラが出す。** `int64_t (*)(int64_t, int64_t)` へ
    キャストして呼べば、Win64 なら Win64 の、SysV なら SysV の規約になる。
    POSIX x86_64 / aarch64 には規約が 1 つしか無いので、**stdcall の区別も
    要らない分だけ簡単。**

    型の検査と `si:make-c-function` を core (`src/core/dll-call.cc`) へ移し、
    実際に呼ぶ所を `src/core/dll-posix.cc` に書いた。win32 側に残したのは
    i386 のスタック組みと SEH でハードウェア例外を拾う部分で、**どちらも
    本当に Win32 の話。**

    **float / double の引数は 64bit では断る。** 64bit
    (Win64 / SysV / AAPCS) は整数と浮動小数で別のレジスタ列を使うので、
    int64_t を並べるキャスト 1 本では渡せない。**これは Win32 の x86_64 側と
    同じ制限**で、あちらも同じ理由で断っている。返り値の float / double は
    返り値の型でキャストすれば渡せるので通る。

    **i386 は引数を全部スタックに積むので float もそのまま渡せる**
    (`push_arg` が扱っている)。テストを 64bit 限定にしていなかったため、
    **「できることをできない」と書いたテストが i686 の CI で落ちた。**

    `unittest/ffi-portable-tests.l` に 9 件。**`unittest/foreign-test.l` は
    `msvcrt` の `_itoa` / `_atoi64` / `_i64toa` を呼ぶので POSIX では動かず、
    POSIX 側の FFI は 1 件も測られていなかった。** 標準 C の関数だけを使って、
    **両方のプラットフォームで同じテストになる**ようにした (実際どちらでも
    9 件通る)。知らない型を断ること・無い名前を断ることも見ている。
  * **POSIX の FFI を libffi で呼ぶようにした。可変長引数の `double` が渡る**
    (issue #133、既知失敗 17 -> 13)。**上の「libffi は要らなかった」は半分しか
    当たっていなかった。**

    ```lisp
    (sprintf b (si:make-string-chunk "foo: %d, %.3f, %s")
             (c:c-vaargs (c:int 123) (c:double 1.23)
                         (c:string (si:make-string-chunk "bar"))))
    ; => 20   "foo: 123, 1.230, bar"
    ```

    キャストで足りるのは整数とポインタまでで、**浮動小数には 2 通りの届かなさ
    があった。**

      * 固定引数の float / double は、SysV が整数と浮動小数で**別のレジスタ列**
        を使うので渡る場所が違う。
      * 可変長引数の double は**もっと悪い。** SysV x86_64 では `al` に
        「ベクタレジスタを何本使ったか」を入れる約束で、整数の関数型へキャスト
        して呼ぶと `al` が 0 になり、呼ばれた側はレジスタ保存領域の浮動小数の
        欄を**埋めないまま**読む。1 個だけなら直前の xmm に残った値で偶然合う
        ことがあり、それが「通ることもある」の正体だった。2 個目で SIGSEGV。

    **Win64 に同じ問題が無いので、Wine のジョブではこの 4 件が通っていた。**
    あちらは可変長引数の double を整数レジスタにも置く。**「Windows で通るなら
    実装が正しい」が成り立たない例である** — 既知失敗リストは
    「MSVC は通る / mingw は落ちる」の形で書かれているので、片方の ABI でしか
    起きない欠陥はこの形の記録に残らない。

    libffi は呼び出し規約を実行時に組み立てるライブラリで、可変長引数も
    `ffi_prep_cif_var` で扱える。**「既定の引数の格上げ」(char/short -> int、
    float -> double) は呼ぶ側の仕事だが、`check_vaarg_type` が既にやっていた**
    — Win32 側も同じ関数を通るので、書き足すものは無かった。

    **`libffi-dev` が Linux ビルドの必須の依存に増えた** (`tools/devenv/`
    の Dockerfile と `.github/workflows/linux.yml`)。**任意にはしなかった**:
    無いときに FFI だけ落とすと、パッケージを入れ忘れた人に 4 件の失敗が
    出るだけで、原因がどこにも書かれない。無ければ configure が
    パッケージ名を出して止まる。

    `ffi-float-argument-is-refused` は**捨てた。**「64bit なら断ること」を
    両方のプラットフォームに期待していたので、POSIX で渡せるようになった時点で
    **できることをできないと書いたテスト**になる。代わりに `ldexp` で固定引数の
    double を測る `ffi-double-argument` を書いた (2 の冪なので誤差が出ない)。
    判定はプラットフォームで選ぶ — Win32 の x86_64 は今も断るので。

    **残るのは `make-c-callable` (段階 4) だけ** — 下で入れた。
  * **POSIX で `si:make-c-callable` が使えるようになった。Lisp の関数を C の
    callback として渡せる** (issue #133 の段階 4、既知失敗 13 -> 10)。

    ```lisp
    (c:defun-c-callable c:int (int32-comparator :convention :cdecl)
      (((c:void *) a) ((c:void *) b))
      ...)
    (qsort array 10 4 #'int32-comparator)   ; libc の qsort が Lisp を呼ぶ
    ```

    **違ったのは置き場所だけだった。** Win32 は `lc_callable::insn[64]` に
    機械語を書き、**その配列そのもの**のアドレスを C へ渡す (ABI ごとに 3 通り
    の機械語が `src/frontend/win32/dll.cc` にある)。libffi の closure は
    **自分で実行可能なメモリを確保して別のアドレスを返す**ので、Lisp
    オブジェクトの中の配列には入らない。**POSIX の Lisp ヒープは実行可能では
    ない**ので、そこへ機械語を書く手も取れない。

    非 Win32 では `insn[]` の代わりにポインタ 2 本 (closure の置き場と C へ
    渡すアドレス) を持ち、**C へ渡すアドレスを選ぶ所を 1 箇所に集めた**
    (`xc_callable_address`、`src/core/dll.h`)。`cast_to_int64` がそこを通る
    唯一の場所なので、それ以外は今までと同じである。

    `Fsi_make_c_callable` は core (`src/core/dll-call.cc`) へ移した。型を検査
    して枠を埋めて `init_c_callable` を呼ぶだけで、**プラットフォームに依るの
    はその `init_c_callable` だけ**だった。非 Win32 の
    `return Qnil` のスタブが 2 つ消えた。

    **`defun-c-callable-stdcall` だけは残る。callback の話ではなかった。**
    `EnumWindows` に callback を渡すテストで、**user32 を `dlopen` する所で
    止まる。** `:stdcall` の指定は POSIX では既定の規約 1 つに落ちるだけで
    問題にならない。既知失敗リストの「呼び出し規約が要る」群から
    「その API が無い」群へ移した。

    **`last-win32-error` 2 件の理由も測り直した。** 「FFI で止まっているので、
    そちらが動けば一緒に通るはず」と書いてあったが、**FFI が動いても通らな
    かった。** 止まっているのは呼ぶ側ではなく**呼ぶ相手**で、
    `MultiByteToWideChar` は kernel32 の中にある。

    テストを 1 件足した (`c-callable-swallows-a-lisp-error`)。**callback の
    中で投げたものが C のフレームを飛び越えないこと。** 越えると呼び出し元
    (libc の `qsort`) が自分のスタックを片付けられず、**壊れ方がプロセスの死に
    なる。** Win32 側は前から `catch (nonlocal_jump &)` で止めていたが、
    **そこを測るテストは無かった。**
  * **`machine-type` が Windows 以外で測られていなかったのを直した**
    (既知失敗 60 -> 59)。既知失敗リストには「GetSystemInfo」と書いてあったが、
    **POSIX でも `machine-type` は値を返していた** (`"amd64"`)。落ちていたのは
    テストの期待値が `#+x86 "x86" #+x64 "x64" #+ia64 "IA64"` で、**POSIX の
    名前 (amd64 / aarch64) を書いていなかったため期待値が空になっていた**から。

    同じ CPU に Win32 は "x64"、POSIX は "amd64" という別の名前を付けるが、
    どちらもそのプラットフォームで通じる呼び方なので揃えていない。

    **`MACHINETYPE_IA64` に `break` が無く、下の `UNKNOWN` へ落ちて nil で
    上書きしていた**のも直した。IA64 の実機はもう無いが fall through の事故。
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

    **窓は 1 回で終わらない。** force-push でやり直すと run が作り直される
    ので、`--watch` が戻ったあとにまた空になることがある (最初は「現れるまで
    待つ」だけを足して、そのあと同じ形で 2 度目を踏んだ)。
    「現れるのを待つ → `--watch`」を**塊ごと繰り返す**形にした。

    **衝突している PR にはチェックが 1 つも付かない**のも見るようにした。
    GitHub は merge ref を作れないので workflow が発火せず、**上の窓と
    見分けが付かないまま 30 分待つ**ことになる (base の PR が squash merge
    された直後に踏んだ)。先に `mergeable` を見て、衝突なら rebase を促す。
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
