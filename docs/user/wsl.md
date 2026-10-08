# WSL (Windows Subsystem for Linux)

Windows 上で動く xyzzy から、WSL 内のファイル・シェル・ツールを透過的に使う機能です。
Windows 10 / 11 どちらでも動きます (Windows 10 の場合は設定が必要、下記参照)。

概要
----

WSL 統合の基本は「パスが判断する」です。

バッファのカレントディレクトリが WSL の UNC パス
(`\\wsl.localhost\Ubuntu\home\user\project` など) なら、シェル・ビルド・git・
言語サーバーは自動で WSL 側のものが使われます。ユーザーがどこで WSL を
選ぶかを意識する場面は、むしろ少ないです。

  * ファイル中の Linux パス (`/home/...`, `/mnt/c/...`) と Windows パス
    (`C:/...`, `\\wsl.localhost\...`) は境界で自動的に変換されます
  * ディストリビューション名は UNC パスから自動で拾います。
    `wsl-open-directory` で開いたプロジェクトは `*wsl-project-list*` に
    (ルート, ディストロ) が記憶され、再起動後も同じディストロが使われます
  * ディストロが全く決まらないときは対話コマンドが選択を促します
    (勝手に `Ubuntu` を仮定しません)
  * WSL 側のコマンドは `wsl.exe -d <ディストロ> -- <コマンド>` の形で起動されます

できること
----------

  * `M-x wsl-open-directory` でディストロと WSL 内ディレクトリを選び、
    作業バッファとして開く (補完付き ミニバッファ)
  * `M-x wsl` で WSL のシェルをターミナルバッファとして開く
    (Windows OS 標準の ConPTY を使うターミナルエミュレータ バッファ)
  * `M-x build` でビルドコマンドを実行する。WSL プロジェクトなら
    WSL 側、Windows プロジェクトならカレント側で走らす。
    コンパイルエラーの Linux パスは Windows パスに変換され、
    `next-error` で該当箇所へジャンプできます
  * `M-x wsl-compile` でビルドコマンドを WSL 内で走らす
    (常に WSL 側で実行したいときの明示的な入口)
  * `M-x git-status` / `git-diff` / `git-log` / `git-blame` は
    WSL プロジェクトでは WSL 側の git を透過的に実行する
  * `M-x wsl-git` で git を WSL 内のプロジェクトで実行
    (常に WSL 側で実行したいときの明示的な入口)
  * LSP (`lisp-mode` を伴うファイル開き、[LSP](lsp.md) 参照) は WSL のファイルを
    開いているときは言語サーバーも WSL 側で起動され、パスと URI が自動変換されます
  * クリップボードの Windows 連携 (`wsl-copy-region` / `wsl-paste`)
  * パス変換の内部 API: `wsl-path-to-windows` (Linux → Windows)、
    `windows-path-to-wsl` (Windows → Linux)。自作拡張からも使えます
  * `M-x wsl-find-file` で WSL プロジェクト内のファイルを補完選択して開く
  * 逆方向 (WSL のシェルから Windows 側の xyzzy を開く) には
    `tools/xyzzy-wsl` を使います。後述「WSL 側シェルから xyzzy を開く」
    を参照

できないこと (既知の限界)
--------------------------

- トランスペアレントな推論は「バッファのカレントディレクトリ」と
  プロジェクトレジストリ (`*wsl-project-list*`) が起点です。
  ファイルを開いていない状態や、`default-directory` が Windows 側のときは
  WSL への自動ディスパッチは行われません (明示的にディストロを指定してください)。
- ディストロ名がパスにもレジストリにもないときは、対話コマンドは
  選択を促します。`*wsl-distribution*` を設定すると既定値になります。
- `tools/xyzzy-wsl` (後述) は WSL のシェルから Windows の xyzzy を起動する
  だけのスクリプトで、エディタ内から WSL に接込むわけではありません。

始め方
------

  1. `M-x wsl-open-directory` を実行し、ディストロと WSL 内のディレクトリを
     選択します。開かれたバッファの `default-directory` が WSL の UNC パスに
     設定され、以降の `C-x C-f` (ファイルを開く) はそのディレクトリから始まります。
     プロジェクトは `*wsl-project-list*` に記憶されるので、次回以降は
     その下のディレクトリで同じディストロが自動的に使われます。
  2. 普通にファイルを開いて編集します。
  3. `M-x wsl` でシェル、`M-x build` でビルド、`M-x git-status` 等で git を、
     すべて同じディレクトリ文脈で使えます (WSL プロジェクトなら
     何も指定しなくても WSL 側で実行されます)。
  4. LSP を使う場合は [LSP](lsp.md) に従います。WSL 側のファイルに対しては
     サーバーも WSL 側に入れる必要があります (`lsp-install-server` は
     カレントバッファのディレクトリを見て、WSL 側に入るか Windows 側に入るか
     自動で判断します)。

設定
----

設定は `~/.xyzzy` に Lisp で書きます ([設定](configuration.md) を参照)。

| 変数 | 既定 | 内容 |
|---|---|---|
| `*wsl-distribution*` | `nil` | 既定のディストロ名。パス・レジストリから拾えないときに使われます。 |
| `*wsl-unc-prefix*` | `"\\\\wsl.localhost"` | WSL ルートへの UNC プレフィックス。Windows 10 では `"\\\\wsl$"` を設定します。 |
| `*wsl-path-prefix*` | `"/mnt/"` | Windows ドライブがマウントされる Linux 側プレフィックス (例: `/mnt/c`)。 |
| `*wsl-command*` | `"wsl.exe"` | WSL を起動する実行ファイル。 |
| `*wsl-project-distro*` | `nil` | カレントバッファのディストロ (バッファローカル、`wsl-open-directory` が設定)。 |
| `*wsl-project-list*` | `nil` | WSL プロジェクトの (ルート . ディストロ) 一覧。`wsl-open-directory` が登録し、ヒストリファイルに保存されます。 |

WSL ディストロの切り替え
------------------------

複数のディストロを使う場合は、UNC パスの 2 番目の要素が使われます
(`\\wsl.localhost\Debian\home\...` なら Debian)。`wsl-open-directory` で
開いたプロジェクトは `*wsl-project-list*` に (ルート, ディストロ) が
記憶され、その下のディレクトリでは同じディストロが使われます
(ヒストリファイルに保存され、再起動後も有効)。`M-x wsl` はどのディストロで
開くかを都度尋ねる場合は、引数付き (`M-x wsl C-u`) で選べます。
`*wsl-distribution*` を設定すると、パス・レジストリから決められない場合の
既定値になります。

Windows 10 の場合
-----------------

Windows 10 では WSL の UNC プレフィックスは `\wsl.localhost` ではなく `\wsl$`
です。`~/.xyzzy` に以下を書いてください。

```lisp
(setq *wsl-unc-prefix* "\\\\wsl$")
```

WSL 側シェルから xyzzy を開く
------------------------------

これまでの説明は「Windows 上の xyzzy → WSL 内のファイルやツール」という
方向です。逆向き、つまり **WSL のシェルの中から `xyzzy .` と打って
Windows 側 GUI の xyzzy をそのディレクトリ付きで開く**ための入口が
`tools/xyzzy-wsl` です。

```
$ tools/xyzzy-wsl .          # カレントディレクトリを xyzzy で開く
$ tools/xyzzy-wsl README.md  # ファイルを xyzzy で開く
```

`xyzzy` という名前で PATH の通った場所 (`~/bin/` など) に置くか、
シェルの alias / 関数から呼んでください。

探す順序は `XYZZY_EXE` → `XYZZYHOME/xyzzycli.exe` / `xyzzy.exe` →
PATH 上の `xyzzycli.exe` / `xyzzy.exe` → `/mnt/c/xyzzy/` や
`/mnt/c/Program Files/xyzzy/` といった既定のインストール先です。
実在するパスの引数は `wslpath -w` で Windows パスに変換して渡します
(`xyzzy .` が WSL 側のカレントディレクトリを指すのはこの変換のため)。
見つからないときは `XYZZY_EXE` に `xyzzycli.exe` へのフルパス
(例: `export XYZZY_EXE=/mnt/c/xyzzy/xyzzycli.exe`) を設定してください。

`tools/` の WSL 関係スクリプトは 3 つあり、対象者が違います。
役割表は [tools/README.md](../../tools/README.md) にまとめてあります。

WSL 側から xyzzy を操作するデバッグサーバ (PoC)
----------------------------------------------

`lisp/wsl-debug.l` は、WSL 上のシェルやコーディングエージェントから
Windows 上の xyzzy に Lisp 式を送って評価させる TCP デバッグサーバです。
**PoC (概念実証) なので制約があります** (下記)。

  1. `~/.xyzzy` に `(require "wsl-debug")` を書くか、`M-: (require "wsl-debug")`
     で読み込みます。
  2. xyzzy 側で `M-x wsl-debug-serve` を実行すると `127.0.0.1:11722` で
     待受を始めます。
  3. WSL 側から `tools/wsl-debug.py` で 1 行 1 S 式を送ると、評価結果が
     `+OK <値>` / `-ERR <エラー>` の 1 行で返ります。

```
$ tools/wsl-debug.py '(+ 1 2)' '(software-version)'
+OK 3
+OK "0.9.0"
$ echo '(selected-buffer)' | tools/wsl-debug.py
+OK #<buffer *scratch*>
```

  * 認証: 既定では `*wsl-debug-token*` が `nil` で**認証なし**です。
    loopback とはいえ同じマシン (WSL からも localhost で届きます) の
    どのプロセスからも Lisp を評価できるので、共有環境では
    `M-: (wsl-debug-generate-token)` でトークンを作り、クライアント側に
    `tools/wsl-debug.py --token <トークン>` と渡してください。
    トークンは `si:uuid-create` (UUID v4) 由来の値です。
  * プロトコル: 行単位・UTF-8。先頭行 `AUTH <トークン>` (トークン設定時
    のみ)、以降 1 行 1 S 式。応答は必ず 1 行 (改行は空白に畳まれます)。
  * 制約 (PoC なので): `accept` がブロッキングなので、serve 中の xyzzy は
    応答専念になります (C-g または切断で復帰)。1 接続 1 セッションで、
    同時接続は捌けません。ノンブロック化は今後の課題です。

詳細
----

  * パス変換・コマンド生成の実装は `lisp/wsl.l` です
  * LSP との組み合わせは [LSP](lsp.md) の「Windows 側と WSL 側」の節を参照
