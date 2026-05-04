; Comments
(comment) @comment

; Strings
(interpolated_string_literal) @string
(string_literal) @string

; Numbers
(number) @number

; Variables
(scalar) @variable
(array) @variable
(hash) @variable

; Subroutines
(subroutine_declaration_statement (bareword) @function.def)
