-*- outline-tree: topic -*-
======================================================================
                treeview  -- TreeView.dll 用ライブラリ
                --------------------------------------

    Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

    Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
    Time-stamp: <2006/01/16 23:28:32 +0900>
======================================================================

■概要

  kazu.y さんの TreeView.dll を複数目的に使用するためのライブラリで
  す。

  仕様は FIX していませんので、このライブラリに依存したコードの公開
  の際はご注意ください。

■インストール

  0. 必要なライブラリを導入します。

          - TreeView.dll (ver. 1.03 以降)
          - color
          - win-window

  1. アーカイブを展開して treeview/ 以下を $XYZZY/site-lisp に
     コピーします。

  2. 必要ならばバイトコンパイルします。

          M-x load-library
          Load library: treeview/makefile

          M-x treeview-make-clean
          M-x treeview-make-all

  3. ‾/.xyzzy または $XYZZY/site-lisp/siteinit.l に以下のコードを
     追加します。

          (require "wip/treeview/setup")

  4. 上記の設定を反映させるために、xyzzy を再起動します。
     siteinit.l に記述した場合は Ctrl キーと Shift キーを押しながら
     xyzzy を再起動し、ダンプファイルを再構築します。

■アンインストール

  1. treeview ライブラリに依存する部分を全て xyzzy 環境から
     除外します。

  2. ESC ESC (treeview::treeview-uninstall) とタイプし、
     treeview 関連の情報を xyzzy から削除します。

  3. treeview に関する記述を削除します。

  4. siteinit.l に記述していた場合は Ctrl キーと Shift キーを押し
     ながら xyzzy を再起動し、ダンプファイルを再構築します。

■ライセンス

  treeview は修正BSDライセンスに基づいて利用可能です。
  <http://www.opensource.org/licenses/bsd-license.php>


  Copyright (C) 2001-2006, OHKUBO Hiroshi.  All rights reserved.

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

■使わせて頂いているもの

  ・kazu.y さんの TreeView.dll
    http://www003.upp.so-net.ne.jp/rex/

