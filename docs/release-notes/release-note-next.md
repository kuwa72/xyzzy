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

  * README とリポジトリの概要が、この木を上流そのもののように見せていたのを直した。
    バッジとダウンロードのリンクが snmsts/xyzzy を指したままで、GitHub の説明文は
    xyzzy-022 のものが残っていた。私家版であること、どこから分岐した木なのか、
    不具合の報告先がここであって上流ではないことを先頭に書いてある。
  * ドキュメントを利用者向け (docs/user/)・開発者向け (docs/dev/)・リリースノート
    (docs/release-notes/) に分けた。README がビルド手順やバージョン体系の詳細まで
    抱えていて「導入とポインタ」になっていなかったのと、機能一覧・キーバインド・
    設定 (GUIダイアログと ini/.xyzzy.history/~/.xyzzy の3層構造)・Lisp拡張の
    書き方がどこにも無かったのを直した。あわせてリリースの ZIP/インストーラに
    docs/dev/ (設計メモ、上流の古い ChangeLog) やリリースノート本体がそのまま
    入ってしまっていたのもやめ、docs/user/ だけを配布物に入れるように
    CMakeLists.txt の install() を変えた。リリースノート自体も docs/ 直下から
    docs/release-notes/ へ移し、それに合わせて `.githooks/pre-push`、
    `.github/workflows/release.yml`、`tools/release-prep.sh`、`RELEASING.md`、
    `CLAUDE.md` が参照するパスを一括で更新した (ファイル名は変えていないので
    `release-note-<版>.md` という命名はそのまま)。
  * `docs/user/keybindings.md` に Emacs との違いに注意する表を追加し、`C-s`/`C-r`
    の説明を実態 (デフォルトでは isearch ではなく `RET` 確定の非インクリメンタル
    検索) に合わせて直した。`lisp/loadup.l` を確認すると `isearch.l` は起動時の
    ロード対象に入っておらず、ドキュメントが「デフォルトでインクリメンタル
    サーチ」と書いていたのは実際の挙動と食い違っていたため。
  * `docs/user/keybindings.md` に、自明すぎて省いていた基本のカーソル移動・編集
    キー (`C-f`/`C-b`/`C-n`/`C-p`/`C-k`/`C-y` など) と、`M-x` 実行時などに使う
    ミニバッファでのキー (履歴呼び出しの `C-p`/`C-n`/`M-p`/`M-n`、補完の `TAB`、
    中断の `C-g` など) の一覧を追加した。
  * `docs/user/keybindings.md` に画面スクロール系のキー (`C-l`/`C-Down`/`C-Up`/
    `S-C-Down`/`S-C-Up`/`C-x <`/`C-x >`/`ESC C-v`) が抜けていたので追加した。
  * `docs/user/keybindings.md` の `Home`/`End` の説明が誤っていたのを直した。
    `C-a`/`Home`、`C-e`/`End` と同じ行にまとめて書いていたが、`lisp/buffer.l`と
    `lisp/cmds.l` を確認すると `Home` は次のバッファへの切り替え、`End` は undo
    (`S-End` は redo) で、行頭・行末移動ではない。Emacs との違いに注意する表にも
    追記した。
  * `docs/user/keybindings.md` を大幅に拡充した。抜けていたグローバルキー
    (略語展開・レジスタ・キーボードマクロ・ページ (フォームフィード) 移動・
    外部コマンド実行・タグジャンプ・ブックマーク・`C-c` プレフィックス・
    文字コード/EOL 切り替え・擬似フレーム/セッション・シフト選択・`C-x 4`/
    `C-x 6` 系・段落/S式移動など) を `lisp/loadup.l` の全ロード対象から洗い出し
    て追加し、`C-←`/`C-→` が単語移動ではなく行頭/行末移動になっている点も
    Emacs との違いの表に加えた。あわせてファイラ・バッファ一覧・補完リスト・
    query-replace・カレンダー・ターミナルなど、専用キーマップを持つ組み込みの
    サブウィンドウ/ダイアログの中で効くキーと、lisp-mode・c-mode/c++-mode・
    shell-mode・markdown-mode・html+-mode など既定で組み込まれているモードの
    モード固有キーも追記した。
  * Windows 向けデプロイのバイトコンパイルが、`.l` の変更が無くても
    `tools/deploy-windows.sh` を叩くたびに x86_64 で `wine: Unhandled stack
    overflow`、i686 で `xyzzy-batch: メモリ不足です` を吐くようになっていたのを
    直した。原因は `misc/makelc.l` の `reload-files` が `"startup"` モジュールも
    無条件にリロードしていたこと。`lisp/startup.l` は末尾の `(si:*startup)` で
    `ed::startup` 経由の起動処理全体を再実行し、その中で `*post-startup-hook*`
    が走る。ところがバッチ版バイトコンパイル (`misc/bytecompile-batch.l`) は
    まさにこのフックから `makelc` を起動しているため、`reload-files` が
    `startup` を読み直すたびに `makelc` が再突入し、ネストするごとに
    141 本のライブラリ全体をもう一度コンパイルし続ける無限再帰になっていた。
    アーキごとに落ち方が違っていたのはスタックとヒープのどちらが先に
    尽きるかの違いでしかなく、両方とも同じ再帰が原因だった。`reload-files`
    から `startup` を除外し (`*modules*` には provide 済みとして残す)、
    バッチ側でも `*post-startup-hook*` を使い捨てにして二重に塞いだ。
    実害は無かった (`compile-files` は再帰が起きる前に 141 本すべてを
    書き終えている) が、デプロイのたびに数分と一見不穏なクラッシュログを
    生んでいた。
  * 標準添付の Lisp ライブラリ・主要モードをまとめた利用者向けドキュメント
    (`docs/user/lisp-libraries.md`) を追加した。C/C++, C#, Java, JS/TS, Python,
    Perl, HTML+, CSS, XML, JSON, YAML, TOML, Markdown, Makefile, CMake などの言語・
    設定ファイルモードの拡張子や機能、ターミナル・Grep・一括置換・略称展開・TAGS・
    ファイラ・セッション・辞書・電卓・ゲームなどの各種ツール、Common Lisp 互換や
    エディタ操作を支えるコアライブラリ、`lisp/wip/` 内のアウトラインツリーや
    TreeView などの拡張群を網羅して一覧化した。
  * ターミナルバッファで、エディタ側に取られたキーをターミナルの中のアプリへ
    そのまま渡す `terminal-send-next-key` (`C-c C-q`) を足した。ターミナルの
    キーは `*terminal-map*` にあるものだけがエディタへ行き、残りは全部 pty へ
    流れる仕組みなので、素通しの経路が必要なのは `C-v` (貼り付け) や
    `S-PageUp` (スクロールバック) のようにこちらで意味を持たせたキーだけで、
    vim の `C-v` や less の `S-PageUp` がそれまで押せなかった。
  * `(read-char *keyboard*)` がターミナルバッファで返ってこなくなっていたのを
    直した。キーの pty への横流しは入力キューを読む `fetch` の中で起きていて、
    Lisp が明示的にキーを待っているときも横流しが優先されるため、キーは
    `read-char` に届かないまま pty へ消えていた。`y-or-n-p` や `query-replace`
    の応答待ちがターミナルバッファでは何を押しても進まなかったのがこれ。
    Lisp が `*keyboard*` を読んでいる間だけ横流しを止める。
  * 機能キーを `(read-char *keyboard*)` で取ると別のキーになっていたのを直した。
    `decode_keys` が積む lChar は kind field (bit 21-23) を持つ新しい表現
    (`LCKEY_UP` = `0x200005`) だが、char object にするときに下位 16bit を
    取っていたので kind が落ち、`#\Up` が `#\C-e` になっていた。Lisp の char は
    今も旧表現 (`#\Up` = `CCF_UP` = `0xff05`) なので、`ccf_from_lc` で戻す。
    `read-key-sequence` や `describe-key` が矢印キーを取り違えていたのも同じ
    原因で、あわせて直っている。
  * `si:terminal-send-key` に char を渡すと機能キーとして扱われなかったのを
    直した。`#\Up` (`0xff05`) の `LCHAR_KIND` は CHAR に見えるため、`ESC[A` では
    なく U+FF05 (全角パーセント) の UTF-8 が pty へ流れていた。char で渡された
    ものは `lc_from_ccf` で昇格し、BMP 外の code point だけは `Char` (16bit) に
    落とすと `0xF600` = `CCF_META` とぶつかるのでそのまま渡す。この経路は
    process が無いと呼べずテストが書けなかったので、`si:*terminal-key-for-test`
    も char を受けるようにして `unittest/terminal-tests.l` に固定した。
  * ターミナルバッファで `S-PageUp`/`S-PageDown` のスクロールバックと
    `S-Insert` の貼り付けが効いていなかったのを直した。キーを pty へ流すか
    エディタへ渡すかの判定で `*terminal-map*` を引くとき、lChar を下位 16bit に
    落としてから渡していた。kind と modifier はそこより上のビットにあるので、
    `#\S-PageUp` (`0x01200000`) は `0`、`#\S-Insert` は `0x0C` として引かれ、
    どちらも map に無い別のキー扱いで pty へ流れていた。`C-v` の貼り付けだけが
    動いていたのは、`LCKIND_CHAR` の制御文字が下位 16bit に収まっていて
    偶然一致していたため。`parse_keymap` は内部で新旧どちらの encoding も
    正規化するので、lChar をそのまま渡す。
