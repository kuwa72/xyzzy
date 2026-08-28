;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;; Batch byte-compile and exit
;; Usage: xyzzy -q -load misc/bytecompile-batch.l
;;
;; Sets *post-startup-hook* to run byte-compile after GUI is ready.
;; Writes progress to bytecompile-progress.log.

(setq *post-startup-hook*
      #'(lambda ()
          ;; makelc の出力 (どのファイルがなぜ失敗したか) は
          ;; *standard-output* へ行く。バッチ起動では、それが繋がっていないと
          ;; **失敗理由がどこにも残らない** (tools/bytecompile.sh が拾う
          ;; bytecompile-output.txt が 0 バイトになる)。issue #54 の
          ;; 「何も出ない」がこれだった。
          (setq *standard-output* *terminal-io*)
          (setq *error-output* *terminal-io*)
          (let ((logfile (merge-pathnames "bytecompile-progress.log"
                                          (si:system-root))))
            (handler-case
                (progn
                  (with-open-file (s logfile :direction :output
                                     :if-exists :supersede)
                    (format s "=== Byte-compile started ===~%")
                    (format s "system-root: ~A~%" (si:system-root))
                    (format s "dump-image-path: ~A~%" (si:dump-image-path)))
                  (setq *post-startup-hook* nil)
                  (load "misc/makelc.l")
                  (require "compile")
                  (let ((orig (symbol-function 'mc-byte-compile-file))
                        (count 0))
                    (with-open-file (s logfile :direction :output
                                       :if-exists :append)
                      (format s "makelc.l loaded~%"))
                    (setf (symbol-function 'mc-byte-compile-file)
                          #'(lambda (filename &optional encoding)
                              (setq count (1+ count))
                              (with-open-file (s logfile :direction :output
                                                 :if-exists :append)
                                (format s "[~D] ~A~%" count filename))
                              (funcall orig filename encoding))))
                  (funcall (read-from-string "makelc:makelc-and-exit")
                           (let ((force (si:getenv "XYZZY_BYTECOMPILE_FORCE")))
                             (and force (not (string= force "")) t))))
              (condition (e)
                (with-open-file (s logfile :direction :output
                                   :if-exists :append)
                  (format s "~%=== ERROR ===~%~A~%" e))
                (kill-xyzzy nil))))))
