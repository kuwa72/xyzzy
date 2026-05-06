; tree-sitter-markdown block grammar — highlights.scm
; Used by ts-markdown-mode-install in lisp/ts.l

; Heading markers (# / underline)
(atx_h1_marker) @heading.1
(atx_h2_marker) @heading.2
(atx_h3_marker) @heading.3
(atx_h4_marker) @heading.4
(atx_h5_marker) @heading.4
(atx_h6_marker) @heading.4
(setext_heading_underline) @heading.setext

; Fenced and indented code blocks
(fenced_code_block) @code
(indented_code_block) @code

; Info string (language tag after ```)
(info_string) @code.info

; Block quote marker (>)
(block_quote_marker) @quote

; List markers
[
  (list_marker_minus)
  (list_marker_plus)
  (list_marker_star)
  (list_marker_dot)
  (list_marker_parenthesis)
] @list.marker

; Thematic break (---, ***, ___)
(thematic_break) @hr

; Link destinations and labels
(link_destination) @link
(link_label) @link.label
