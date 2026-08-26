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
  *
