;;; -*- Encoding: utf-8 -*-
;;; -*-Lisp-*-
;;;
;;; This file is part of xyzzy.
;;;

;; Use .l explicitly for ncurses to bypass .lc files
;; (.lc was compiled without :ncurses in *features*)
#+ncurses (si:*load-library "loadup.l")
#-ncurses (si:*load-library "loadup")

;; Define variables from #-ncurses excluded files that are still needed
;; Must use ed:: prefix since these are in the editor package
#+ncurses
(progn
  ;; **`defvar' を使ってはいけない。** defvar はシンボルを special にし、
  ;; **special な変数はバッファローカルになれない** (set_globally が
  ;; SFspecial を見てバッファローカルの経路を通らずグローバルへ書く、
  ;; src/core/eval.cc)。その結果 *buffer-package* が全バッファで共通になり、
  ;; `text-mode' の kill-all-local-variables が消せなくなっていた
  ;; (issue #105)。lisp/lispmode.l と同じ形にする。
  ;;
  ;; **効くかどうかが .lc を作ったビルドで変わる。** `#+ncurses' は読み込み時
  ;; の条件なので、Windows ビルドが startup.l をバイトコンパイルするとこの
  ;; ブロックは .lc から消える。端末ビルドで作ると残る。同じ .lc を両方で
  ;; 読む作りなので、ここに副作用のある式を置くと再現性が落ちる。
  (setq-default ed::*buffer-package* nil)
  (make-variable-buffer-local 'ed::*buffer-package*))

(provide "startup")

#+ncurses
(progn
  ;; Use popup-list for completion display
  (setq ed::*popup-completion-list-default* t)
  (setq ed::*minibuffer-popup-completion-list* t))

;;; 端末だけのキー割り当て。
;;;
;;; **`*pre-startup-hook*' に置くのは `~/.xyzzy' より前に走らせるため。**
;;; ここを `si:*startup' の中に直に書くと、ユーザの設定を後から上書きして
;;; しまうか、あるいは書く場所によって上書きされるかが変わる。既定値は
;;; 常にユーザ設定より前に置く。
#+ncurses
(progn
  ;; F10: activate menu bar (call-menu requires an arg on Win32,
  ;; so wrap it as an interactive command for ncurses keybinding)
  (defun ed::activate-menu ()
    (interactive)
    (call-menu 0))

  (defun ed::init-terminal-key-bindings ()
    ;; BS/DEL key binding (terminal sends 0x7f for backspace)
    (global-set-key #\DEL 'ed::delete-backward-char-or-selection)
    (global-set-key #\F10 'ed::activate-menu)
    ;; Selection keys (same as Gates.l / Windows-style key bindings)
    (global-set-key #\S-Left 'ed::selection-backward-char)
    (global-set-key #\S-Right 'ed::selection-forward-char)
    (global-set-key #\S-Up 'ed::selection-previous-line)
    (global-set-key #\S-Down 'ed::selection-next-line)
    (global-set-key #\S-Home 'ed::selection-beginning-of-line)
    (global-set-key #\S-End 'ed::selection-end-of-line)
    (global-set-key #\S-PageUp 'ed::selection-previous-page)
    (global-set-key #\S-PageDown 'ed::selection-next-page))

  (add-hook 'ed::*pre-startup-hook* 'ed::init-terminal-key-bindings))

;;; **端末版もここを通る。** 以前は `#+ncurses' 側が `ed::startup' の一部を
;;; 手で書き写していて、写し損じた分がそのまま欠落していた:
;;; `~/.xyzzy' を読まない、履歴ファイルを読まない (書くだけ)、`-q' を
;;; 食べないので「-q」という名前のバッファが開く、`*pre-startup-hook*' が
;;; 走らない、`init-pseudo-frame' / `keep-compatibility' /
;;; `init-misc-options' が呼ばれない (issue #217)。
;;;
;;; **テストが全部 `--batch -q` で走るので、誰も気付かなかった。** その
;;; 呼び方は「`~/.xyzzy' を読まない」ことを期待する形なので、読まない
;;; バグを隠す。
(defun si:*startup ()
  (ed::startup))

#-ncurses
(unless (xyzzy-dumped-p)
  (si:*show-window-foreground)
  (ed::init-misc-objects)
  (lisp::snarf-documentation)
  (dump-xyzzy))

(si:*startup)

