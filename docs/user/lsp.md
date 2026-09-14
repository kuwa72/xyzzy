LSP (Language Server Protocol)
==============================

xyzzy には言語サーバーと会話する LSP クライアント (`lisp/lsp.l`) が同梱されて
います。起動イメージにあらかじめ読み込まれるので、`require` は要りません。
C, C++, Python, Rust, Go, JavaScript, TypeScript, YAML, JSON のモードで
**カーソル位置の定義へ飛ぶ**ことと、**サーバーが報告したエラー・警告を受け取る**
ことができます。言語サーバー本体は別途インストールが必要です。

概要
----

LSP (Language Server Protocol) は、エディタと言語サーバーのやり取りを標準化
したプロトコルです。エディタ側は言語ごとの解析処理を持たず、外部プロセスに
「このファイルのここは何か」を問い合わせます。xyzzy 側がやるのは、バッファの
内容をサーバーへ送ることと、返ってきた答えを画面に反映することだけです。

いまできること
--------------

  * 定義ジャンプ。`M-.` (`lsp-find-definition`) でカーソル位置のシンボルの
    定義ファイルへ移動します。
  * ドキュメント同期。ファイルを開いた時点 (`didOpen`)、打鍵が止まって
    `*lsp-idle-delay*` 秒後 (`didChange`)、保存時 (`didChange` と `didSave`) に、
    **バッファの全文**を送ります。
  * 診断の収集。サーバーが `textDocument/publishDiagnostics` で送ってきた
    エラー・警告を受け取り、件数をミニバッファに
    `LSP Diagnostics: N issue(s) reported` と表示します。
  * Windows 上の xyzzy から WSL 内のファイルを編集するとき、サーバーを
    `wsl.exe` 越しに WSL 側で起動します (パスと URI は自動で変換)。

いまできないこと
----------------

  * 補完 (`textDocument/completion`)、ホバー (`textDocument/hover`)、参照検索、
    名前変更は未実装です。
  * 診断は件数がミニバッファに出るだけで、該当行のハイライトや一覧画面は
    ありません。受け取った診断はクライアントごとに保持しているので、表示側を
    足せば使えます。
  * ドキュメント同期は差分ではなく全文送信です。サーバーは受け取った `text` を
    全文として扱う必要があります。
  * サーバーから `workspace/configuration` のような要求が来たときは、常に
    `null` を返します。

対応しているモードと既定のサーバー
----------------------------------

`*lsp-default-servers*` に登録されている組み合わせは次のとおりです。表に無い
モードでは、`M-x lsp-mode` は `No language server configured for <モード名>` と
言ってサーバーにはつながりません (マイナーモード自体は有効になります)。

| モード | languageId | 既定のサーバーコマンド | 導入方法の例 |
|---|---|---|---|
| `c-mode` | `c` | `clangd` | `winget install LLVM.LLVM` / `sudo apt install clangd` |
| `c++-mode` | `cpp` | `clangd` | 同上 |
| `python-mode` | `python` | `pylsp` | `pip install python-lsp-server` / `sudo apt install python3-pylsp` |
| `rust-mode` | `rust` | `rust-analyzer` | `rustup component add rust-analyzer` |
| `go-mode` | `go` | `gopls` | `go install golang.org/x/tools/gopls@latest` |
| `javascript-mode` | `javascript` | `typescript-language-server --stdio` | `npm install -g typescript-language-server typescript` |
| `yaml-mode` | `yaml` | `yaml-language-server --stdio` | `npm install -g yaml-language-server` |
| `json-mode` | `json` | `vscode-json-language-server --stdio` | `npm install -g vscode-langservers-extracted` |

`typescript-mode` (`.ts` / `.tsx`) は languageId だけ `typescript` として登録
されていますが、サーバーの既定は入っていません。使うなら
`*lsp-default-servers*` に `typescript-language-server --stdio` を足してください。
`languageId` の表 (`*lsp-language-ids*`) に無いモードは `plaintext` として
送られます。

導入
----

### `M-x lsp-install-server` で入れる

`M-x lsp-install-server` はサーバー名をミニバッファで選ばせて、その環境向けの
コマンドを実行します。カーソル位置のモードに対応するサーバーが既定候補になり
ます。

  1. `C-x C-f` で対象のファイルを開く (拡張子からモードが決まります)。
  2. `M-x lsp-install-server` を実行し、`clangd` / `pylsp` / `gopls` /
     `rust-analyzer` / `typescript-language-server` / `yaml-language-server` /
     `json-language-server` から選ぶ。
  3. すでに入っていれば `... is already installed.` と出て何もしません。
     前提ツール (`pip` / `npm` / `go` / `rustup` など) が無ければ、先にそれを
     入れるよう促します。

失敗したときの見え方は 2 通りです。

  * 権限エラー (`Permission denied` など) と判断できたときは、実行すべき
    コマンドをミニバッファに表示し、kill-ring にも入れます。ターミナルで
    そのまま実行してください。
  * それ以外の失敗は `*lsp-install*` バッファに実行したコマンド・終了コード・
    出力を残します。同じ内容が一時ディレクトリ (`$TEMP` / `$TMP`) の
    `xyzzy-lsp-install-<サーバー名>.log` にも書かれ、そのパスは
    `*lsp-last-install-log*` に入ります。

インストールそのものは成功したのにコマンドが PATH から見つからないときは、
その旨が表示されます。**PATH の変更は xyzzy を起動し直すまで効きません。**

### 自分で入れる

`M-x lsp-install-server` が想定しているのは上表のコマンドだけです。別の
サーバーを使う場合や、パッケージマネージャを使いたい場合は、普通に
インストールしてコマンドが PATH に通った状態にしてください。どのコマンドを
起動するかは `*lsp-default-servers*` で決まります。

### Windows 側と WSL 側

`M-x lsp-install-server` はカレントバッファの `default-directory` を見て、
WSL の UNC パス (`\\wsl.localhost\...`、Windows 10 では `\\wsl$\...`) なら
`wsl.exe` 越しに WSL 側へ、そうでなければ Windows 側へ入れます。ファイルが
WSL 側にあるときは **サーバーも WSL 側に入れてください。** xyzzy は WSL 側の
ファイルに対して `wsl.exe -d <ディストロ> -- <コマンド>` の形でサーバーを
起動します。

WSL 側の導入は `sudo` を使うものがあります (`sudo apt install clangd` など)。
パスワードを要求されると失敗するので、その場合は WSL のターミナルで手動で
実行してください。

使い方
------

  1. `C-x C-f` でファイルを開きます。
  2. `M-x lsp-mode` で LSP マイナーモードを有効にします。ファイルを保存して
     いないバッファでは `This buffer is not visiting a file.` と言ってサーバー
     にはつながりません (URI が決まらないため)。先に保存してください。
  3. `M-.` でカーソル位置のシンボルの定義へ飛びます。定義が見つからなければ
     `Definition not found.` と出ます。
  4. もう一度 `M-x lsp-mode` を実行すると無効になります。このとき
     `didClose` を送るだけで、**サーバーのプロセスは止めません。**

`M-.` は LSP が有効なバッファだけで `lsp-find-definition` に変わります。
無効なバッファでは [キーバインド](keybindings.md) にあるとおり、TAGS の
`jump-tag` (`M-.`) がそのまま効きます。

毎回 `M-x lsp-mode` を打つのが面倒なら、モードフックに入れます。

```lisp
; Python のファイルを開いたら LSP を有効にする
(add-hook '*python-mode-hook* #'(lambda () (lsp-mode t)))
```

サーバーはコマンドが同じなら共有されます。Python のバッファを 2 つ開いても
`pylsp` は 1 つだけ起動し、それぞれのバッファが別のドキュメントとして
`didOpen` されます。

設定
----

設定は `~/.xyzzy` に Lisp で書きます ([設定](configuration.md) を参照)。

| 変数 | 既定 | 内容 |
|---|---|---|
| `*lsp-default-servers*` | 上表の 8 モード | モード名 (文字列) → サーバーコマンド (文字列) の alist。先に見つかった項目が使われます。 |
| `*lsp-language-ids*` | 上表の 9 モード | モード名 → LSP の `languageId`。無いモードは `plaintext`。 |
| `*lsp-idle-delay*` | `0.5` | 打鍵が止まってから `didChange` を送るまでの秒数。 |
| `*lsp-mode-hook*` | `nil` | `lsp-mode` を有効にしたとき (`lsp-connect` の後) に走るフック。 |
| `*lsp-mode-map*` | `M-.` のみ | LSP が有効なバッファのキーマップ。 |
| `*lsp-clients*` | `nil` | 起動中のクライアントのリスト。 |
| `*lsp-server-installers*` | 上表の 7 サーバー | サーバー名 → `(:windows コマンド 前提ツール)` と `(:wsl コマンド 前提ツール)`。 |
| `*lsp-last-install-log*` | `nil` | 直近に `lsp-install-server` が失敗したときのログファイル。 |

`*wsl-command*` (`lisp/wsl.l`) は WSL を起動するコマンドで、既定は
`wsl.exe` です。WSL のディストロ名はパスから拾い、分からないときは `Ubuntu`
として扱います。

```lisp
; 打鍵が止まってから送るまでの時間を短くする
(setq *lsp-idle-delay* 0.2)

; Python だけ別のサーバーにする (先頭に積むと既定より優先される)
(setq *lsp-default-servers*
      (cons '("python-mode" . "pyright-langserver --stdio")
            *lsp-default-servers*))

; 表に無いモードを足す。languageId も一緒に足さないと plaintext になる
(setq *lsp-default-servers*
      (cons '("csharp-mode" . "omnisharp --languageserver")
            *lsp-default-servers*))
(setq *lsp-language-ids*
      (cons '("csharp-mode" . "csharp") *lsp-language-ids*))
```

### サーバーを止める

`lsp-mode` を切ってもプロセスは残ります。止めるのは `lsp-stop-server` の仕事
ですが、**これは `M-x` からは呼べません** (`interactive` 指定が無い Lisp 関数
です)。`ESC ESC` の式評価 ([キーバインド](keybindings.md)) から呼んでください。

```lisp
; *lsp-clients* の先頭のサーバーを止める
(lsp-stop-server)
```

`lsp-stop-server` は `shutdown` と `exit` を送り、最大 1 秒待ってから
`kill-process` します。`lsp-start-server` / `lsp-connect` / `lsp-disconnect` も
同じく `M-x` には出ない Lisp 関数です。

うまく動かないとき
------------------

まず、サーバーが起動しているかを見ます。`ESC ESC` で次を評価すると、動いて
いるクライアントの数が分かります。

```lisp
(length *lsp-clients*)
```

`0` なら `lsp-connect` の時点で失敗しています。よくある原因は次のとおりです。

  * **モードが表に無い。** `M-x lsp-mode` が
    `No language server configured for <モード名>` と言うなら
    `*lsp-default-servers*` に足りていません。`*lsp-language-ids*` も忘れずに。
  * **サーバーのコマンドが PATH に無い。** `M-x lsp-install-server` で入れ直すか、
    PATH を通して xyzzy を起動し直します。
  * **バッファがファイルを訪ねていない。** `This buffer is not visiting a file.`
    と出るときは保存してから有効にします。

サーバーの出力は ` *lsp server output*` という名前のバッファに捨ててあります
(先頭に空白があります)。サーバーが動いている間だけ存在し、終了すると消えます。
`C-x b` でこの名前を打ち込むと中身を見られます。ここに起動エラーが出ている
ことがあります。

サーバーが応答しないときは、次の点も確認してください。

  * **WSL 側のコマンドが見つからない。** WSL のターミナルで
    `wsl.exe -d <ディストロ> -- which clangd` のように打って確かめます。
    ディストロ名が拾えていないと `Ubuntu` として起動を試みます。
  * **サーバーが `initialize` に答えていない。** xyzzy は `initialize` の応答を
    待ってから `didOpen` を送ります。応答が無いとバッファの内容も送られない
    ままになります。` *lsp server output*` に何か出ていないかを見てください。
  * **`workspace/configuration` に `null` を返している。** これを嫌うサーバーは
    あります。うまく動かないサーバーがあったら、そのサーバー名とバージョンを
    添えて報告してください。

送受信は UTF-8 (BOM なし)・改行変換なしで行います。`Content-Length` はバイト数
なので、バッファは生バイトで受け、復号はこちらで行います。

関連
----

  * [キーバインド](keybindings.md) — `M-.` など全体の割り当て
  * [標準添付 Lisp ライブラリ・モード](lisp-libraries.md) — 言語モードと
    TAGS (`jump-tag`) の説明
  * [設定](configuration.md) — `~/.xyzzy` の場所と読み込まれる順番
