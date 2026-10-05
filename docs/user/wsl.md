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

できないこと (既知の限界)
--------------------------

- トランスペアレントな推論は「バッファのカレントディレクトリ」と
  プロジェクトレジストリ (`*wsl-project-list*`) が起点です。
  ファイルを開いていない状態や、`default-directory` が Windows 側のときは
  WSL への自動ディスパッチは行われません (明示的にディストロを指定してください)。
- ディストロ名がパスにもレジストリにもないときは、対話コマンドは
  選択を促します。`*wsl-distribution*` を設定すると既定値になります。
- `tools/xyzzy-wsl` は WSL 側シェルから Windows の xyzzy を起動する
  補助スクリプトです (WSL 内のシェルから `xyzzy .` で Windows 側の GUI
  xyzzy をそのディレクトリ付きで開きます)。エディタ内で WSL に接込む
  わけではありません。

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

詳細
----

  * パス変換・コマンド生成の実装は `lisp/wsl.l` です
  * LSP との組み合わせは [LSP](lsp.md) の「Windows 側と WSL 側」の節を参照
