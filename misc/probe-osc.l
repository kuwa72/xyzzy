(setq *post-startup-hook*
  #'(lambda ()
      (setq *standard-output* *terminal-io*)
      (let ((e (string #\ESC)))
        (labels ((cellcolor (s row col)
                   (let ((c (nth col (nth row (si:*terminal-feed-for-test 2 20 s)))))
                     (list (second c) (third c)))))
          ;; スクリプトが出すのと同じ列を流す
          (format t "24bit fg    ~S~%" (cellcolor (concat e "[38;2;255;100;50mX") 0 0))
          (format t "24bit bg    ~S~%" (cellcolor (concat e "[48;2;40;44;52mX") 0 0))
          (format t "colon form  ~S~%" (cellcolor (concat e "[38:2::255:100:50mX") 0 0))
          (format t "256 idx 208 ~S~%" (cellcolor (concat e "[38;5;208mX") 0 0))
          ;; OSC 4 でパレット 1 を緑にしてから index 1 を使う
          (format t "OSC4 then 1 ~S~%"
                  (cellcolor (concat e "]4;1;rgb:00/ff/00" e "\\" e "[48;5;1mX") 0 0))))
      (kill-xyzzy)))
