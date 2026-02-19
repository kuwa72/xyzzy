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
                  (load "misc/makelc.l")
                  ;; Load compile.l to resolve autoload, then wrap
                  ;; mc-byte-compile-file for progress logging
                  (require "compile")
                  (let ((orig (symbol-function 'mc-byte-compile-file))
                        (count 0)
                        (srcdir (merge-pathnames "lisp" (si:system-root))))
                    (let ((total (length (directory srcdir
                                                   :absolute t :wild "*.l"
                                                   :recursive t))))
                      (with-open-file (s logfile :direction :output
                                         :if-exists :append)
                        (format s "makelc.l loaded, ~D files to compile~%" total))
                      (setf (symbol-function 'mc-byte-compile-file)
                            #'(lambda (filename &optional encoding)
                                (setq count (1+ count))
                                (with-open-file (s logfile :direction :output
                                                   :if-exists :append)
                                  (format s "[~D/~D] ~A~%" count total filename))
                                (funcall orig filename encoding)))))
                  (funcall (read-from-string "makelc:makelc-and-exit") t))
              (condition (e)
                (with-open-file (s logfile :direction :output
                                   :if-exists :append)
                  (format s "~%=== ERROR ===~%~A~%" e))
                (kill-xyzzy nil))))))
