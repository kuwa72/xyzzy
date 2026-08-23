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
  *
