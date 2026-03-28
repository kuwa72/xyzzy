-*- outline-tree: topic -*-
======================================================================
                            outline-tree
                            ------------

    Copyright (C) 2001-2012 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

    Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
    Time-stamp: <2012/03/30 21:39:50 +0900>
======================================================================

■概要

  TreeView.dll を用いて、バッファリストのツリー表示、バッファ内のア
  ウトライン表示を行います。

  outline-tree 及び、使用している treeview ライブラリが提供する機能
  の概要を以下に列挙します。

  □基本機能
   - バッファリストのツリー表示
      - バッファの選択
      - フォルダを閉じる
   - バッファ内アウトライン表示
      - バッファ内ノード位置への移動
  □Treeview設定・操作
   - TreeView の各種設定
   - TreeView ウィンドウ位置の変更
   - TreeView ウィンドウの開閉
   - TreeView ウィンドウ上キーバインドの設定 (Alt キー使用不可)
   - 大体の操作が TreeView 上右クリックから可能
  □編集
   - 「範囲ノード」の上下入替え
  □出力
   - テキスト, HTML 出力
  □その他
   - アウトライン作成関数の半自動生成
   - ファイル先頭部分への記述による outline 種類自動選択


  ナローイングはユーザがインタラクティブに設定するものと考え、
  outline-tree がノードに対応するリージョンを自動的にナローイングす
  る機能は有しません。

■インストール

  0. 必要なライブラリを導入します。

          - treeview (treeview ライブラリ)
             | 2005/05/17 時点では、treeview は以下を必要とします。
             | - TreeView.dll (ver. 1.03 以降)
             | - color
             | - win-window
          - buf2html

  1. アーカイブを展開して outline-tree/ 以下を $XYZZY/site-lisp に
     コピーします。
     toolbar-outline-tree.bmp を $XYZZY/etc にコピーします。

  2. 必要ならばバイトコンパイルします。

          M-x load-library
          Load library: outline-tree/makefile

          M-x outline-tree-make-clean
          M-x outline-tree-make-all

  3. ~/.xyzzy または $XYZZY/site-lisp/siteinit.l に以下のコードを
     追加します。

          (require "outline-tree/outline-tree")

  4. 上記の設定を反映させるために、xyzzy を再起動します。
     siteinit.l に記述した場合は Ctrl キーと Shift キーを押しながら
     xyzzy を再起動し、ダンプファイルを再構築します。

■アンインストール

  1. ESC ESC (outline-tree2::outline-tree-uninstall) とタイプし、
     outline-tree 関連の情報を xyzzy から削除します。

  2. outline-tree に関する記述を削除します。

  3. siteinit.l に記述していた場合は Ctrl キーと Shift キーを押し
     ながら xyzzy を再起動し、ダンプファイルを再構築します。

■ライセンス

  outline-tree は修正BSDライセンスに基づいて利用可能です。
  <http://www.opensource.org/licenses/bsd-license.php>


  Copyright (C) 2001-2012, OHKUBO Hiroshi.  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in
     the documentation and/or other materials provided with the
     distribution.

  3. Neither the name of the University nor the names of its
     contributors may be used to endorse or promote products derived
     from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

■outline-tree キーバインド

  ●注意

    快適な使用のためには、以下の設定が必要だと考えています。

      ・TreeView <-> Editor のフォーカスを切り替えるキーバインド
      ・outline を更新するキーバインド

    作者はそれぞれ exkey-C-tab (Ctrl+TAB), exkey-C-return
    (Ctrl+Return) を使用していますが、それらのキーは xyzzy 標準では
    使用できるようになっていません。そのため outline-tree では設定し
    ていません。
    以下では、exkey-C-tab を F23、exkey-C-return を F20 にマッピング
    した上でキー設定する例を示します。

    F23, F20 にマッピングしているのは、単純に、作者のこれまでの xyzzy
    設定との兼ね合いによっています。下記を参考にして設定を行う場合は、
    各人の環境に合わせて F13～F24 辺りを使用してください。

      ;; extended-key-translate-table 設定
      (set-extended-key-translate-table exkey-C-tab #\F23)
      (set-extended-key-translate-table exkey-C-return #\F20)

      ;; Editor <-> TreeView
      ; Editor -> TreeView
      (require "treeview/setup")
      (global-set-key #\F23 'treeview::treeview-focus-treeview)
      ; TreeView (outline-tree) -> Editor
      (require "outline-tree/outline-tree")
      (define-key outline-tree2::*outline-tree-map*
                  #\F23 'treeview::treeview-focus-editor)

      ;; outline 更新
      (global-set-key #\F20 'outline-tree2::outline-tree-create-outline-and-select-node)
      (define-key outline-tree2::*outline-tree-map*
                  #\F20 'outline-tree2::outline-tree-create-outline-and-select-node)

  ●エディタ上

    基本的に TreeView 上での操作のみにしていますので、キー設定はあり
    ません。上記「注意」の設定をした場合、以下2点が設定されます。
      ・Editor -> TreeView とフォーカスを切り替えるキーバインド
      ・outline を更新するキーバインド

  ●TreeView 上

    [右クリック]-[ヘルプ]-[キー割り当て一覧] を参照ください。

    ○ノード間移動
        Up,        C-p
        Down,      C-n
        Left,      C-b
        Right,     C-f

        PageUp,    S-PageUp
        PageDown,  S-PageDown
        Home,      S-Home
        End,       S-End

        C-a
        C-e
        C-z
        C-v

    ○スクロール
        C-Up,        S-C-Up
        C-Down,      S-C-Down
        C-Left,      S-C-Left
        C-Right,     S-C-Right
        C-PageUp,    S-C-PageUp
        C-PageDown,  S-C-PageDown
        C-Home,      S-C-Home
        C-End,       S-C-End

        <              左端にスクロール
        >              右端にスクロール

        C-l            リセンター

    ○ノード検索
        C-s            インクリメンタルサーチ
        C-r            インクリメンタルサーチ(逆順)

    ○ノード実行
        Return
        左ダブルクリック

    ○アウトラインの削除
        Delete

    ○エディタ部をフォーカス
        (exkey-C-tab : F23)

    ○範囲ノード入替え
        P
        N

    ○範囲ノード削除
        D

    ○その他
        Apps           ポップアップメニュー表示
        右クリック     ポップアップメニュー表示

        C-c C-f        ファイラ起動

        C-x 0          TreeView を閉じる
        C-x 1          TreeView を開く
        C-:            TreeView を開閉する

        C-c w t        ウィンドウを上に
        C-c w b        ウィンドウを下に
        C-c w l        ウィンドウを左に
        C-c w r        ウィンドウを右に
        C-c w w        ウィンドウを次の位置に

        C-x ?          キー説明

■プロパティシート

  主な設定は、下記操作で表示されるプロパティシート/ダイアログから設
  定可能です。

  ・[右クリックメニュー]-[アウトラインツリー設定]
  ・[右クリックメニュー]-[TreeView 設定]

■ツールバー

  アウトラインツリーの起動・終了を行います。
  アウトラインツリーが起動している場合、アイコンは押された
  状態で表示されます。

    未起動時：（通常状態の）アイコンをクリック⇒起動
    起動時  ：（押下状態の）アイコンをクリック⇒終了

■設定ファイル

  outline-tree 開始時に
      ~/.outline-tree/autoload/ 以下の *.l(c)
      ~/.outline-tree/config.l(c)
  ファイルを読み込みます。

■参考フォーマット

  ○構造化エディタ (STED)
  ・松崎 暁 HP
    http://www008.upp.so-net.ne.jp/momotan/

  ○eMemoPad
  ・eMemoPad Home
    http://www.ememopad.net/

  ○ChangeLog
  ・たつをのホームページ
    http://nais.to/~yto/

  ・Let's try ChangeLog MEMO
    http://pop-club.hp.infoseek.co.jp/emacs/changelog.html

  ・横着プログラミング: Unixのメモ技術
    http://namazu.org/~satoru/unimag/1/index.html

  ○RD
  ・RD working draft 日本語版
    http://www.rubyist.net/~rubikitch/RDP.cgi?cmd=view&name=RD

  ・RD事始め
    http://www.rubyist.net/~rubikitch/computer/rd-intro/

  ・What is RD? What is RDtool?
    http://www2.pos.to/~tosh/ruby/rdtool/ja/whats.html

  ○Markdown
  ・Daring Fireball: Markdown Syntax Documentation
    http://daringfireball.net/projects/markdown/syntax

  ○Hiki
  ・Hikiトップページ
    http://www.namaraii.com/hiki/

  ・整形ルール
    http://www.namaraii.com/hiki/?TextFormattingRules

  ○RFC
  ・サンプル: Internet Small Computer Systems Interface (iSCSI)
    http://www.ietf.org/rfc/rfc3720.txt

