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

  * C++ 標準を C++11 から C++17 に引き上げた (`CMakeLists.txt`)。#16 の
    ロードマップ (現代化・リファクタリング) の足場で、`std::string_view`
    や構造化束縛など、以降のリファクタリングで使う言語機能を有効にする
    ための変更。今回はビルドフラグのみで、コード側の書き換えはまだ無い。
    `tools/x build x86_64` の全ビルドと `tools/x test x86_64` の
    テストスイートで既存の警告・失敗が増えていないことを確認した。
  * `src/core/cdecl.h`/`lisp.h` の独自 `bcopy`/`bcmp`/`bzero` (`memcpy`/
    `memcmp`/`memset` を薄くラップした BSD 風の互換関数) を全呼び出し箇所
    (44 ファイル、143 箇所) で標準の `memcpy`/`memcmp`/`memset` に置き換え、
    ラッパー自体を削除した。#16 の Phase 1 (レガシーマクロの整理) の一環。
    `bcopy`/`bcmp` は第 3 引数を要素数として受け取り、内部で
    `sizeof (要素型)` 倍してから `memcpy`/`memcmp` に渡していた
    (`Char` なら ×2、`ucs4_t` なら ×4)。単純な字面置換では抜けがちな罠で、
    最初の機械的な置換ではこの掛け算を丸ごと落としてしまい、コピー量が
    要素サイズ分の1になって手元の `tools/x test` で起動直後から文字化け
    する形で再現した (バイナリ二分探索で `StrBuf::add` まで絞り込んで発覚)。
    呼び出し側の型がどれであっても正しく倍率を掛けられるよう、置換後の
    サイズ式は呼び出し箇所ごとに `sizeof (*(元のポインタ式))` を掛ける形に
    した (ポインタの実体型を辿るので `Char`/`ucs4_t`/`lisp` のどれでも
    自動的に正しい倍率になる)。加えて `bcopy` は重なり合う領域のコピーも
    正しく動く BSD 由来の関数だったため、`memcpy` に置き換えると未定義動作
    になる 2 箇所 (`insdel.cc` の削除時のシフト、`sequence.cc` の
    `xdelete`) は `memmove` にした。
  * 上のバイト数計算の監査中に、`memcmp`/`memcpy` へ移行する前から
    存在していた実際のバグを 2 件見つけて直した
    (`src/frontend/win32/dialogs.cc` のバッファ名比較、
    `src/frontend/ncurses/ncurses-stubs.cc` の補完候補への末尾スラッシュ
    付与)。どちらも呼び出し側が `bcopy`/`bcmp` の第 3 引数へ
    「要素数」ではなくすでに `sizeof (ucs4_t)` を掛けた「バイト数」を渡して
    しまっており、ラッパー内部の掛け算と二重になって本来の 4 倍の
    バイト数を読み書きしていた (後者はヒープバッファオーバーフロー)。
    ncurses フロントエンドは Windows 向け CIではビルド対象外
    (`ncursesw` が無いと `xyzzy-ncurses` ターゲット自体が生成されない) の
    影響もあり見過ごされていたとみられる。
  * `src/core/cdecl.h` の独自 `min`/`max`/`swap` (int/long/float 等の型別に
    手書きしていたオーバーロード群) を削除し、`using std::min; using
    std::max; using std::swap;` で標準ライブラリのものを使うようにした。
    #16 ロードマップ Phase 1 の一環。呼び出し側は非修飾の `min (a, b)` の
    ままで動くよう `using` 宣言でグローバルスコープに引き込む形にした
    (数百箇所ある既存の呼び出しを `std::min (a, b)` へ書き換える必要が
    無い)。独自版には `int`/`u_int`/`long` 等の具体的な型ごとの
    非テンプレート版もあり、`enum` 定数と `int` を混ぜて呼ぶような箇所
    (例: `max (MIN_WIDTH, w)`、`MIN_WIDTH` は無名 `enum`) は暗黙変換で
    通っていた。`std::min`/`std::max` は完全な同型テンプレートしか
    無いためこれらはコンパイルエラーになり、`tools/x build x86_64` で
    洗い出した 12 箇所に `int (...)` 等の明示キャストを足した。
  * 固定幅の独自整数型 `u_int8_t`/`u_int16_t`/`u_int32_t`/`u_int64_t`
    (`u_char`/`u_short`/`u_long` 等の実体幅に依存するチェーンで定義されて
    いた) を `<cstdint>` 標準の `uint8_t`/`uint16_t`/`uint32_t`/`uint64_t`
    に置き換えた。#16 ロードマップ Phase 1「独自整数型の `<cstdint>` への
    段階的整理」の最初の一歩。`Char`/`ucs2_t`/`ucs4_t` の定義元をこれらに
    直結させたことで、実際の呼び出し箇所を書き換えずに 14 ファイルの
    直接利用箇所だけ手直しすれば済んだ。`u_char`/`u_short`/`u_int`/
    `u_long` 自体 (1300 箇所近い生の利用がある) はプラットフォーム
    ネイティブ幅に依存する箇所とそうでない箇所の判別が要るため、今回は
    手を付けていない (後続 PR で段階的に進める)。
  * 上の置き換えで `src/core/chtype.h` の文字種判定関数
    (`alpha_char_p`/`digit_char_p`/`kana_char_p` 等) が軒並み
    「call is ambiguous」でコンパイルエラーになった。`ucs4_t` は
    `u_int32_t` (=`u_long`) 経由の定義だったため、LLP64 (Win32) では
    `u_long` が 32bit である都合で `lChar` (`u_long`) と偶然同じ型になって
    おり、chtype.h はそれを前提に `#ifdef __LP64__` で `ucs4_t` 専用
    オーバーロードを Win32 では意図的に外していた
    (`lChar` 版と再定義衝突するため)。`ucs4_t` を `uint32_t` に固定した
    ことで Win32 でも `unsigned long` と `uint32_t` (=`unsigned int`) は
    別型になり、前提が崩れた。`ucs4_t` 専用オーバーロードを常に有効にする
    よう `#ifdef __LP64__` ガードを外して修正した。あわせて
    `src/frontend/win32/minibuf.cc` の `char_width (lChar (*s))` は
    `char_width` に `lChar` 版オーバーロードが元々無く (`Char`/`ucs4_t`
    版のみ)、同じ理由でエラーになったため、素の `ucs4_t` を渡す
    `char_width (*s)` に直した (`s` は元から `const ucs4_t *`)。
  * #16 ロードマップ Phase 1 の残り2項目 (`std::string_view` の段階的導入、
    コンパイラ警告の厳格化) を評価し、実施の意味があるかどうかを判断した。
      - `std::string_view`: 調査の結果、安全かつ意味のある足がかりが
        無いと判断し見送った。この codebase の Lisp 文字列は
        `xstring_contents`/`xstring_length` という (ポインタ, 長さ) の
        自前の慣習に既に統一されており (`ucs4_t`/`Char` 要素、
        `std::string` ではない)、これを `std::basic_string_view` へ
        置き換えるのは数千箇所の関数シグネチャに触れる大工事で、今回の
        `bcopy`/`min`/`max`/整数型タスクで実際に3件のバグを踏んだ経験
        からしてもリスクが見合わない。ナロー文字列 (`char*`) を扱う
        箇所は少なく、`getenv` 結果を可変バッファへコピーする処理
        (`std::string` 向き) か、完結した NUL 終端比較 (`strcmp`、
        改善の余地無し) のどちらかで、唯一ポインタ+長さのスライスらしい
        処理がある `gendic.cc` (オフラインの辞書生成ツール) もスライスを
        即座に `std::string` へコピーしており、置き換えても実質シグネチャ
        の書き換えだけで実利が無い。
      - コンパイラ警告の厳格化: `-Wall`/`-Wextra` (`/W4`) を今回丸ごと
        有効にするのは見送った。現状 (厳格フラグ無し) でも clang ビルドに
        118箇所ぶんの警告が既に出ており、その中には Win32 ハンドル系の
        ポインタ⇔整数キャスト (約44箇所) や GC/Lisp オブジェクト層の
        `-Wundefined-var-template` など、今回の `min`/`max`/整数型
        タスクで実際にハマった「型の実体を変えると壊れる」領域に近い、
        構造的な調査が要るクラスタが混ざっている。`-Wall`/`-Wextra` を
        足せば対象箇所はさらに大きく膨らむため、一括有効化はせず、
        代わりに今回は「安価で安全な単発の警告」と「実バグの疑いがある
        警告」だけを選んで直した (次項)。`-Wall`/`-Wextra` の広い有効化と
        大規模な警告解消は、リスクが分かっている領域を切り分けたうえで
        別途の段階的な取り組みとして残す。
  * 上の警告監査で見つけた、安価で安全な単発の警告 8 件を直した。
    `cdecl.h` の `PATH_MAX` マクロ再定義、`except.cc` のトライグラフ
    (`"(???)"` の `??)` が偶然トライグラフに一致)、`oledata.cc` の
    `!this` (C++ 的に呼び出せた時点で `this` は非 null と仮定されるため
    このチェックは常に false、単なる死んだコード)、`statarea.cc` の
    文字列リテラルへのポインタオフセット (`"..." + n` を `&"..."[n]` に
    書き直して意図を明示)、`lprint.cc`/`dockbar.cc` の多文字文字定数
    (`'#:'`/`'MB'`。前者は `"#:"` の単純なクォート違いのタイプミス、
    後者は BMP マジックナンバー `0x4d42` を明示化)、`lprint.cc` の
    `format_message`/`format_yes_or_no_p` の `va_start` (最後の named
    parameter が `enum` 型だと未定義動作になるため、引数型を `int` に
    変え、内部で `message_code` へキャストし直した。既存の呼び出し側は
    unscoped enum の暗黙変換でそのまま動く)。`dsfmt/dSFMT.h` の
    `#warning` (`DSFMT_MEXP` 未定義時の警告) は、ベンダー同梱の third
    -party 乱数生成ライブラリ自体は変更せず、`CMakeLists.txt` の該当
    ターゲット (`xyzzy-core`/`xyzzy`/`xyzzy-batch`/`xyzzy-cli`/
    `xyzzy-ncurses`) に `DSFMT_MEXP=19937` (ライブラリ自身のデフォルト値
    と同じ) を明示的に渡して黙らせた。
  * 上の警告監査で、実際のバグを 3 件見つけて直した。
      - `encoding.cc`: HQX デコードで `(s_version = get ()) == eof` が
        `s_version` (`u_char`) への代入で `get ()` の戻り値 (`eof=-1` を
        含みうる `int`) を先に切り詰めてしまい、`== eof` が常に false に
        なっていた (EOF を検出できず壊れたファイルとして扱われない)。
        `get ()` の結果を `int` の一時変数で先に判定してから代入する形に
        直した。
      - `regex.cc` の `char_class_fastmap`: 上位バイトが非0の文字クラス
        が「256/NBITS 個のグループ全体を覆っている」かどうかを判定する
        比較式が `<< 16` になっており (`p[1]` は `Char` = 16bit なので
        絶対に一致しない、シフト量のタイポ)、常に false 側 (`-1`) の
        結果になっていた。同じ関数内の他行が `>> 8`/`& 0xff` で
        上位/下位バイトに分解しているのと整合するよう `<< 8` に直した。
        `fastmap` の 1/-1 は単純な真偽判定では違いが出ないが、他の
        fastmap と `|=` で合成する経路 (`merge_fastmap`) ではビットパターン
        が変わるため、広い Unicode 文字クラスを含む正規表現の一部で
        意味のある違いが出る可能性がある。テストスイートは全体として
        既存の合否と一致することを確認したが、この経路自体を狙った
        既存テストは無いため、正規表現の挙動が変わったように見えたら
        まずここを疑ってほしい。
      - `toplev.cc`: quit キーの割り当てで `VkKeyScan` の失敗判定
        `LOWORD (vk) == -1` が、`LOWORD` の戻り値型 `WORD` (符号無し) と
        リテラル `-1` (符号付き) の比較で通常の算術変換により `WORD` が
        `int` に昇格するため常に false になっていた (失敗時
        `return Qnil` に落ちず、無効な `vk` のまま処理が続いていた)。
        `LOWORD (vk) == 0xffff` に直した。
  * #16 ロードマップ Phase 2「シーケンス関数のキーワード引数の網羅的監査と
    ANSI CL 準拠修正」に着手した。`position`/`find`/`remove`/`delete`
    (系列関数含む) の `:key`/`:test`/`:test-not`/`:start`/`:end`/
    `:from-end`/`:count` は監査の結果すでに CLHS 準拠だったが、
    テストが一切無かったため CLHS の Examples 節にある例をそのまま
    移植したテストを追加し、現在の (正しい) 挙動を固定した。
    `lisp/sequence.l` の `mismatch` は `:from-end` をラムダリストで
    受け取るだけで本体で一切参照しておらず、`:from-end t` を指定しても
    無視されて `:from-end nil` と同じ結果を返す実バグだったため、
    CLHS の公式例 (`(mismatch '(3 2 1 1 2 3) '(1 2 3) :from-end t) => 3`)
    で検証しながら実装して修正した。`count`/`count-if` も同様に
    `:from-end` を無視しているが、こちらは単純な集計で走査方向が結果に
    影響しないため実害が無いことを確認し、変更していない。`search` は
    ANSI CL 関数として全く実装されていない (`:key` 監査ではなく新規実装が
    要る) ため今回のスコープ外とし、別途フォローアップとして残す。
  * テスト追加の過程で、`unittest/simple-test.l` の `*test-file-readtable*`
    ( `deftest` 内の `=>` 期待値構文をパースするための専用リードテーブル)
    の落とし穴を踏んだ。`>` を `set-macro-character` で登録しており、
    `>` の直後が `>` でも空白でもない場合 (例: `#'>)` のように `>` の
    直後が `)`) `>` に続けて次のフォームを読もうとして
    `(read stream ...)` が `)` を読み込み `予期しない文字です: )` で
    失敗する。`unittest/project-tests.l:65` は `#'>  :key ...`
    (`>` の直後にスペース) で既にこれを回避していたので同じ流儀に
    倣い、`:test #'> )` のようにスペースを1つ挟んで回避した。リード
    テーブル自体 (`)` 等の標準的な終端マクロ文字も終端として扱うように
    する) は今回の範囲外とし、テストを書く上での既知の落とし穴として
    ここに記録しておく。
  * #16 ロードマップ Phase 2「多値関連の仕様差異修正」を監査した。
    `values`/`values-list`/`multiple-value-bind`/`multiple-value-setq`/
    `multiple-value-list`/`multiple-value-call`/`multiple-value-prog1`/
    `nth-value` の実装 (`src/core/eval.cc`、一部 `lisp/evalmacs.l`) を
    具体的な再現式で1つずつ追跡した結果、実際の仕様差異は見つからな
    かった。`multiple-value-setq` は最後に setq した変数ではなく
    フォームの第1値を正しく返し、余分な値は捨てられ足りない分は `nil`
    になる。`multiple-value-prog1` は最初のフォームの多値をまるごと
    保持したまま返す。`multiple-value-call` は全引数フォームの値を
    正しく平坦化する。インタプリタとバイトコンパイル後の両方の経路で
    挙動が一致することも確認した。ただしこれらを検証するテストが
    一切無かったため、新規に `unittest/multiple-value-tests.l` を
    追加し、上記の挙動を固定した。`nth-value` は範囲外の N で `nil`
    を返す前に多値リストを丸ごと構築しており非効率だが、これは正確性
    の問題ではないため今回は変更していない。
  * `unittest/multiple-value-tests.l` の追加中に、日本語コメントを含む
    `.l` ファイルに `;;; -*- Encoding: utf-8 -*-` 宣言が無いと、離れた
    箇所の読み込みが `変数が定義されていません: =>` のような無関係な
    エラーで壊れる (エンコーディング誤判定でコメントの読み飛ばし位置が
    ずれ、後続のトップレベルフォームの区切りを見失う) 落とし穴を踏んだ。
    日本語を含む既存の `.l` ファイルは軒並みこの宣言を持っており、
    無いのは (今回のファイルを除けば) 純 ASCII のファイルだけだった。
    宣言を追加して解決したが、テストを書く上での既知の落とし穴として
    ここにも記録しておく。
  * `destructuring-bind` を新規実装した (#16 ロードマップ Phase 2
    「destructuring-bind のフルスペック対応」)。これまで xyzzy には
    `destructuring-bind` 自体が存在しなかった。破壊束縛ラムダリストの
    解析は `lex_env::lambda_bind` (`macro_level=1`, `src/core/lex.cc`)
    がマクロ呼び出しの構文形に対しては `&whole`・入れ子パターンを
    含めて既に正しく実装しているが、それは未評価の呼び出しフォームを
    破壊する経路であり、評価済みの値を破壊する `destructuring-bind`
    とは前提が異なる。一方 `lambda` (`funcall_lambda`, `macro_level=0`)
    は `&whole` と入れ子パターンを明示的に禁止している。どちらの
    既存経路も転用できないため、独立した Lisp マクロとして
    `lisp/evalmacs.l` に一から実装した。ラムダリストをマクロ展開時に
    静的に解析し対応する `let*` 束縛節を生成するだけなので、
    `defmacro`/`macrolet` 等すべてのマクロ定義の土台である C++ 側の
    共有破壊束縛機構には一切触れていない。`&whole`、`&optional`
    (デフォルト値・supplied-p)、`&rest`/`&body` (同義)、`&key`
    (デフォルト値・supplied-p・`((:kw var))` によるキーワード名
    上書き)、`&allow-other-keys`、`&aux`、要素数不一致時の
    `too-few-arguments`/`too-many-arguments` シグナル、ドット対
    (`(a b . rest)`) による暗黙の `&rest`、および `&key` の変数位置
    での入れ子パターン (`((:point (px py)))`。lex.cc 側の共有機構には
    無い、独立実装ゆえのボーナス) に対応した。CLHS の
    `destructuring-bind` サンプル例と合わせて `unittest/
    common-lisp-tests.l` にテストを追加し、動作を固定した。
  * 上の実装で `&allow-other-keys` を新規シンボルとして導入した際、
    パッケージ間のシンボル同一性に関わる実バグを踏んで直した。
    `&optional`/`&rest`/`&key`/`&aux`/`&body`/`&whole`/`&environment`
    は C++ コアの `DEFLAMBDAKEY` テーブル (`src/gen-syms.cc`) で
    起動時に一度だけ生成される特別なシンボルで、どのパッケージで
    書いても常に同一のオブジェクトになる。`&allow-other-keys` は
    このテーブルに無い (今回追加もしていない、C++ 側の変更は
    今回のスコープ外) ため、単に `lisp/evalmacs.l` で
    `(eq x '&allow-other-keys)` と書いただけでは `lisp` パッケージの
    シンボルしか見ておらず、他のパッケージ (`editor`/`user` など)
    で `destructuring-bind` を書いた際に読み込まれる
    `&allow-other-keys` は別パッケージの非 `eq` な別シンボルになり、
    比較が常に外れて `&key` の変数と誤認識されていた
    (`(&key x &allow-other-keys)` の `&allow-other-keys` がキーワード
    `:&allow-other-keys` の変数として束縛されてしまう)。`lisp`
    パッケージの `export` リストに `&allow-other-keys` を追加し、
    他パッケージが `lisp` を `:use` することで同一シンボルを継承
    するようにして直した。テストで `common-lisp-tests.l` (`lisp`
    パッケージではない) から `destructuring-bind` の `&allow-other-keys`
    を使うことで、この種のクロスパッケージ不整合を今後も検知できる
    ようにしてある。
  * #16 ロードマップ Phase 2「typespec / 型システムのサポート拡充」を
    監査し、`lisp/typespec.l` の `subtypep` に実バグ 3 件を見つけて
    修正した。全体としては `subtypep` は既に本格的な実装で
    (数値区間の包含判定、配列次元の包含判定、`and`/`or`/`not` の
    再帰処理まで実装済み)、「複合型は常に `(values nil nil)` を返す
    だけの玩具実装」ではなかったが、`unittest/typespec-tests.l` は
    xyzzy 独自拡張型 (`wait-object` 等) のテストしかなく、ANSI CL の
    基本的な型指定子 (数値区間、`member`、`and`/`or`/`not`、`eql`、
    `satisfies`) を検証するテストが皆無だったため、これらのバグは
    見過ごされていた。
      - `member` を第1引数側に取る分岐 (`(subtypep '(member ...) X)`)
        で、要素が対象型を満たさない場合に未定義関数 `value` を
        呼んでいた (`values` のタイプミス)。
        `(subtypep '(member 1 2 "a") 'integer)` が正しく
        `(values nil t)` を返す代わりに関数未定義エラーで落ちていた。
      - `(deftype eql (x) `(member (,x)))` が値を余分な1重リストで
        包んでいた (`(member (,x))` ではなく `(member ,x)` であるべき
        だった)。`typep` は `eql` 専用のハンドラを直接持っており
        `canonicalize-type` を経由しないため影響を受けなかったが、
        `subtypep` は `canonicalize-type` 経由でこの (誤った)
        展開形を使うため、`(subtypep '(eql 5) 'integer)` が誤って
        `nil` を返していた (5 というリストになるはずが `(5)` という
        リストの要素同士を比較してしまい常に不一致になっていた)。
      - `(subtypep type1 '(or A B))` と `(subtypep type1 '(and A B))`
        の分岐ロジックが互いに入れ替わっていた。`or` 側は「type1 が
        **全ての**要素の部分型である」ことを要求し (本来は
        **いずれか1つ**で十分)、`and` 側は「type1 が**いずれか1つ**の
        要素の部分型であれば」成立としていた (本来は**全て**が必要)。
        結果、`(subtypep 'integer '(or integer float))` が誤って
        `nil` を、`(subtypep 'integer '(and integer string))` が
        誤って `t` を返していた。
    3 件とも `unittest/typespec-tests.l` に CLHS 準拠の回帰テストを
    追加して固定した。ついでに、`two-way-stream`/`echo-stream`/
    `broadcast-stream`/`synonym-stream`/`string-stream`/
    `concatenated-stream` の組み込み述語 (`two-way-stream-p` 等) は
    既に存在するのに `typespec-alist` に登録されておらず、`subtypep`
    はこれらを `stream` の部分型として認識するのに `typep` は常に
    `nil` を返す不整合があったため、6 エントリを追加して揃えた
    (`pathname`/CLOS 系の型は xyzzy の設計上そもそも存在しないため
    対象外とした)。
  * Shell バッファで放置後にキー入力が画面に反映されなくなる問題を修正した。
    ターミナルの synchronized output タイムアウトを壁時計から monotonic clock
    に切り替え、システム時刻の巻き戻りや長時間放置後に更新が止まるのを防ぐ。
    加えて ncurses 版では pty 出力を EAGAIN まで一括で読み、強制リフレッシュ
    以外で画面が固まる経路を減らした。
  * #16 ロードマップ Phase 3「Lisp コンパイラ最適化」の一環として、
    `lisp/compile.l` のバイトコード最適化パスに `NULL`/`NOT` と直後の
    条件ジャンプの融合 (`NULL/NOT - IF-NIL-GOTO-AND-POP` →
    `IF-NON-NIL-GOTO-AND-POP`、およびその逆) を追加した。これはファイル
    冒頭のコメントに元々「予定」とだけ書かれていて未実装だった最適化で、
    `(if (null x) ...)` や `(unless x ...)` のように `null`/`not` を
    条件に使う分岐で 1 命令 (`insn-call null 1`) を消せる。
    実装時に気づいた点として、コメントには `-AND-POP` でない
    `IF-NIL-GOTO`/`IF-NON-NIL-GOTO` (2引数 `if` 専用) への適用も
    「予定」と書かれていたが、これは実際には適用できない。
    `BCif_nil_goto`/`BCif_non_nil_goto` はジャンプ時にテスト値そのもの
    (pop せず top のまま) を `if` 式全体の戻り値として残す設計のため、
    テスト対象を `(null x)` の結果から `x` 自身へすり替えると、`x` が
    non-nil のときの `(if (null x) then)` の戻り値が `NIL` (ANSI 上
    else 省略時に返すべき値) から `x` 自身へ変わってしまう。この対象を
    -AND-POP 系 (3引数 `if`・`when`・`unless` 等、テスト値を必ず pop
    して捨てる) に限定することで回避した。挙動テストに加えて、insn 列
    そのものを直接検証するホワイトボックステストを
    `unittest/compile-tests.l` に追加した。挙動が正しいだけでは、
    そもそも最適化パスが一度も発火していない (元の遅いコードのまま)
    場合でも通ってしまうため。
    Phase 3 の残り項目のうち TCO (末尾再帰最適化) は、真の実装に
    VM 側の呼び出し規約変更 (フレーム再利用等、`src/core/bytecode.cc`)
    を要し、末尾呼び出し/深い再帰に関する既存の回帰テストが皆無なこと
    と合わせてリスクが高いため、この作業では見送った。詳細は #16 の
    コメントを参照。
  * #16 ロードマップ Phase 3「パフォーマンスベンチマークスイートの
    作成」向けに `misc/benchmark.l`/`misc/benchmark-batch.l` を追加した
    (`tools/x wine x86_64 -q -load misc/benchmark-batch.l` で実行)。
    リポジトリには最適化効果を計測する仕組みが一切無かったため、
    最小限のマイクロベンチマーク (素朴な再帰・cons 主体・シーケンス
    関数・文字列組み立て・`null`/`not` 分岐主体) を用意した。上記の
    `NULL/NOT-IF-GOTO-AND-POP` 融合をこのスイートで前後比較したところ
    (`null-heavy-branching`, 200万回条件分岐)、374 msec → 373 msec と
    誤差の範囲でしかなかった。1 分岐あたり命令 1 個を削るだけの
    ピープホール最適化なので、これは想定通りの結果であり誇張しない。
    このスイートの価値は今回の1件の最適化を華々しく実証することでは
    なく、今後 TCO や定数畳み込みの拡張など影響の大きい最適化を
    加える際に、before/after を数字で比較できる土台を用意したこと。
  * #16 ロードマップ Phase 3「全標準 Lisp ライブラリの再バイトコンパイル
    検証」として `tools/x bytecompile x86_64 --force` と
    `tools/x bytecompile i686 --force` を実行した。CI は
    `lisp/**/*.l` のハッシュに基づく差分コンパイルのみを継続的に検証
    しており、全 148 ファイルを強制的に再コンパイルする経路は
    これまで一度も通っていなかった。両アーキとも 148 ファイル全てが
    エラーなく再コンパイルでき、`tools/x test` の結果も差分コンパイル
    時と同じ (既知失敗のみ) だった。
  *
