;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;; EAW: 日本語の自然文に出る約物は CJK として 2 桁で数える。
;;;
;;; U+2014 (EM DASH)、U+2026 (HORIZONTAL ELLIPSIS)、U+2018/U+2019、
;;; U+201C/U+201D (引用符)、U+2020-U+2022 (dagger/bullet) 等は UAX #11 で
;;; Ambiguous。xyzzy 本文は CJK として Wide 扱い (src/core/eaw.h) なのに、
;;; src/core/eaw.cc の is_ambiguous が U+2010-U+215F を外していたため
;;; 1 桁で数え、日本語フォントの全角グリフを 1 セルに押し込めて
;;; 字間が不均等に見えていた。ターミナル側は Narrow のまま
;;; (src/core/term.cc が ambiguous_is_wide=0 で引く)。

(deftest eaw-general-punctuation-is-wide-in-editor ()
  "約物 (… — “” ‘’ † ‡ •) は本文では 2 桁。"
  (list (char-columns (code-char #x2026))  ; HORIZONTAL ELLIPSIS …
        (char-columns (code-char #x2014))  ; EM DASH —
        (char-columns (code-char #x201C))  ; LEFT DOUBLE QUOTATION MARK “
        (char-columns (code-char #x201D))  ; RIGHT DOUBLE QUOTATION MARK ”
        (char-columns (code-char #x2018))  ; LEFT SINGLE QUOTATION MARK ‘
        (char-columns (code-char #x2019))  ; RIGHT SINGLE QUOTATION MARK ’
        (char-columns (code-char #x2022))) ; BULLET •
  => (2 2 2 2 2 2 2))

(deftest eaw-dash-variants-are-wide-in-editor ()
  "ダーシ類 (‐ – ―) は本文では 2 桁。"
  (list (char-columns (code-char #x2010))  ; HYPHEN ‐
        (char-columns (code-char #x2013))  ; EN DASH –
        (char-columns (code-char #x2015))) ; HORIZONTAL BAR ―
  => (2 2 2))
