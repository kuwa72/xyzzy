; Comments
(comment) @comment

; Literals
(string_literal) @string
(raw_string_literal) @string
(char_literal) @string
(number_literal) @number
(true) @number
(false) @number
(null) @number
(nullptr) @number

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
(call_expression function: (field_expression field: (field_identifier) @function.call))
