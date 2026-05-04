; Comments
(comment) @comment

; Strings
(string_literal) @string
(raw_string_literal) @string
(char_literal) @string

; Numbers
(number_literal) @number

; Preprocessor
(preproc_include) @preproc
(preproc_def) @preproc
(preproc_ifdef) @preproc
(preproc_if) @preproc

; Types
(primitive_type) @type.builtin
(type_identifier) @type

; Functions
(function_declarator declarator: (identifier) @function.def)
(call_expression function: (identifier) @function.call)
