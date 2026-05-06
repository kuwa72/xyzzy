; tree-sitter-markdown-inline grammar — highlights-inline.scm
; Used by ts-markdown-mode-install (:inline t) in lisp/ts.l

; Emphasis (* / _)
(emphasis_delimiter) @inline.em.marker
(strong_emphasis_delimiter) @inline.strong.marker

; Inline code span
(code_span) @inline.code
(code_span_delimiter) @inline.code.marker

; Links
(link_text) @inline.link.text
(link_destination) @inline.link.url
(image_description) @inline.link.text

; Autolinks
(uri_autolink) @inline.link.url
(email_autolink) @inline.link.url

; Hard line break
(hard_line_break) @inline.br
