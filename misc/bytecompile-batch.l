;; Batch byte-compile and exit
;; Usage: xyzzy -q -load misc/bytecompile-batch.l
;;
;; Sets *post-startup-hook* to run byte-compile after GUI is ready.
;; Writes progress to bytecompile-progress.log.

(setq *post-startup-hook*
      #'(lambda ()
          (let ((logfile (merge-pathnames "bytecompile-progress.log"
                                          (si:system-root))))
            (handler-case
                (progn
                  (with-open-file (s logfile :direction :output
                                     :if-exists :supersede)
                    (format s "=== Byte-compile started ===~%")
                    (format s "system-root: ~A~%" (si:system-root))
                    (format s "dump-image-path: ~A~%" (si:dump-image-path)))
                  ;; makelc は最後に "startup" 以外の全モジュールを reload
                  ;; するだけなので、このフック自体を再度呼ぶことはもう
                  ;; ないはずだが、reload-files が startup を除外し損なった
                  ;; 場合に無限再帰で丸ごと再突入するよりは、フックを
                  ;; ここで使い捨てにしておくほうが安全。
                  (setq *post-startup-hook* nil)
                  (load "misc/makelc.l")
                  ;; Load compile.l to resolve autoload, then wrap
                  ;; mc-byte-compile-file for progress logging
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
                  (funcall (read-from-string "makelc:makelc-and-exit") t))
              (condition (e)
                (with-open-file (s logfile :direction :output
                                   :if-exists :append)
                  (format s "~%=== ERROR ===~%~A~%" e))
                (kill-xyzzy nil))))))
