;; Batch byte-compile and exit
;; Usage: xyzzy -q -load misc/bytecompile-batch.l
;;
;; Sets *post-startup-hook* to run byte-compile after GUI is ready.
;; Writes progress to bytecompile-progress.log for diagnostics.

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
                  (with-open-file (s logfile :direction :output
                                     :if-exists :append)
                    (format s "makelc.l loaded successfully~%")
                    (format s "Starting makelc...~%"))
                  (funcall (read-from-string "makelc:makelc-and-exit") t))
              (condition (e)
                (with-open-file (s logfile :direction :output
                                   :if-exists :append)
                  (format s "~%=== ERROR ===~%~A~%" e))
                (kill-xyzzy nil))))))
