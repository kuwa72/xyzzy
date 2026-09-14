#!/usr/bin/env python3
"""Tests for tools/check-lisp-undefined.py.

TDD regression: calling a function that is defined nowhere (e.g. the
Emacs-ism `prefix-numeric-value` once called from `lsp-mode`) must be
reported before the code is ever executed.
"""
import importlib.util
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "check_lisp_undefined", Path(__file__).with_name("check-lisp-undefined.py")
)
_check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_check)

find_undefined = _check.find_undefined_functions
collect_defs = _check.collect_lisp_definitions
extract_cxx = _check.extract_cxx_functions


def names(findings):
    return sorted(f.name for f in findings)


class UndefinedFunctionTests(unittest.TestCase):
    def test_flags_call_to_nowhere_defined_function(self):
        src = "(defun lsp-mode (&optional (arg nil sv))\n  (toggle-mode (prefix-numeric-value arg)))\n"
        found = find_undefined(src, {"defun", "toggle-mode"})
        self.assertIn("prefix-numeric-value", names(found))

    def test_accepts_defined_and_known_functions(self):
        src = "(defun foo (x)\n  (bar x))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "bar"})), [])

    def test_accepts_local_labels_and_flet(self):
        src = "(defun json-decode (str)\n  (labels ((skip-ws () (peek)) (peek () nil))\n    (skip-ws)))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "labels"})), [])

    def test_ignores_let_bindings_and_lambdalists(self):
        src = "(defun f (arg)\n  (let ((buf 1))\n    buf))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "let"})), [])

    def test_ignores_quoted_data_but_checks_function_ref(self):
        src = "(defun f ()\n  (list 'undefined-fn #'undefined-cb #'list))\n"
        found = names(find_undefined(src, {"defun", "list"}))
        self.assertIn("undefined-cb", found)
        self.assertNotIn("undefined-fn", found)
        self.assertNotIn("list", found)

    def test_skips_declare_forms(self):
        src = "(defun f (x)\n  (declare (ignore x))\n  (known-fn x))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "known-fn"})), [])

    def test_defstruct_generates_accessors(self):
        src = "(defstruct lsp-client\n  process\n  (recv-buf \"\")\n  next-id)\n"
        defs = collect_defs(_check.parse_source(src))
        for want in ("make-lsp-client", "copy-lsp-client", "lsp-client-p",
                     "lsp-client-process", "lsp-client-recv-buf", "lsp-client-next-id"):
            self.assertIn(want, defs)

    def test_setf_place_accessor_is_checked(self):
        src = "(defun f (c)\n  (setf (my-accessor c) 1))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "setf", "my-accessor"})), [])
        self.assertIn("my-accessor", names(find_undefined(src, {"defun", "setf"})))

    def test_extracts_cxx_functions_not_variables(self):
        src = ("  DEFUN3 (foo, 1, 0, 0),\n"
               "  DEFSF3Q (quote),\n"
               "  DEFVAR2 (*bar*),\n"
               "  DEFKWD2 (:baz),\n")
        self.assertEqual(extract_cxx(src), {"foo", "quote"})



class MoreUndefinedFunctionTests(unittest.TestCase):
    def test_cond_test_is_not_a_call(self):
        src = "(defun f ()\n  (cond (var (known a))\n        (t (known b))))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "cond", "known"})), [])

    def test_case_keys_are_data(self):
        src = "(defun f (x)\n  (case x ((1 2) (known a))\n    (otherwise (known b))))\n"
        self.assertEqual(names(find_undefined(src, {"defun", "case", "known"})), [])

    def test_destructuring_lambda_list(self):
        src = "(defmacro dolist ((var listform &optional (resultform nil)) &body body)\n  (list var listform resultform))\n"
        self.assertEqual(names(find_undefined(src, {"defmacro", "list"})), [])

    def test_with_open_file_binds_stream(self):
        src = "(defun f (name)\n  (with-open-file (is name :direction :input)\n    (read is)))\n"
        self.assertEqual(
            names(find_undefined(src, {"defun", "with-open-file", "read"})), [])

    def test_with_output_to_string_binds_var(self):
        src = "(defun f ()\n  (with-output-to-string (s)\n    (princ 1 s)))\n"
        self.assertEqual(
            names(find_undefined(src, {"defun", "with-output-to-string", "princ"})), [])

    def test_defstruct_conc_name(self):
        src = "(defstruct (c-type-definition (:conc-name \"ctypedef-\"))\n  type size)\n"
        defs = collect_defs(_check.parse_source(src))
        self.assertIn("ctypedef-type", defs)
        self.assertIn("ctypedef-size", defs)
        self.assertIn("make-c-type-definition", defs)

    def test_setf_symbol_function_defines(self):
        src = "(setf (symbol-function 'calc-lshift) #'ash)\n(defun f (x)\n  (calc-lshift x 1))\n"
        defs = collect_defs(_check.parse_source(src))
        self.assertIn("calc-lshift", defs)

    def test_define_condition_accessors(self):
        src = "(define-condition check-type-error (type-error)\n  (string place)\n  (:report (lambda (c s) (known c))))\n"
        defs = collect_defs(_check.parse_source(src))
        self.assertIn("check-type-error-place", defs)
        self.assertIn("check-type-error-string", defs)
        found = find_undefined(src, {"define-condition", "lambda", "known"})
        self.assertEqual(names(found), [])

    def test_char_literal_quote_does_not_break_strings(self):
        src = "(set-syntax-string table #\\\")\n(defvar *re* (compile-regexp \"\\\\(a\\\\)\" t))\n"
        found = find_undefined(src, {"set-syntax-string", "defvar", "compile-regexp"})
        self.assertEqual(names(found), [])


class MacroTableTests(unittest.TestCase):
    TABLE = {"with-temp-files": _check.parse_source(
        "((&rest temp-file-vars) &body body)")[0]}

    def test_binding_macro_spec_is_not_a_call(self):
        src = "(with-temp-files (file)\n  (known file))\n"
        found = find_undefined(src, {"with-temp-files", "known"}, self.TABLE)
        self.assertEqual(names(found), [])

    def test_binding_macro_body_is_checked(self):
        src = "(with-temp-files (file)\n  (unknown-call file))\n"
        found = find_undefined(src, {"with-temp-files"}, self.TABLE)
        self.assertIn("unknown-call", names(found))

    def test_value_param_is_checked(self):
        src = "(my-defthing foo (something))\n"
        table = {"my-defthing": _check.parse_source("(name &body body)")[0]}
        found = find_undefined(src, {"my-defthing"}, table)
        self.assertIn("something", names(found))
        self.assertNotIn("foo", names(found))

    def test_allowlist_file_format(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "tools").mkdir()
            (root / "tools" / "lisp-undefined-allowlist.txt").write_text(
                "# comment\n\ncalc-power-expr  # generated\n")
            loaded = _check.load_allowlist(root)
            self.assertEqual(loaded, {"calc-power-expr"})


class TemplateAndFrameworkTests(unittest.TestCase):
    def test_unquote_may_call_template_locals(self):
        src = "(defun f (lib)\n  `(labels ((c (name) (known name)))\n     (list ,(c \"x\"))))\n"
        found = find_undefined(src, {"defun", "labels", "list", "known"})
        self.assertEqual(names(found), [])

    def test_lambda_bind_pattern_is_not_code(self):
        src = "(defun f (r)\n  (lambda-bind (#:type fn &rest vals)\n      r\n    (known fn)))\n"
        table = {"lambda-bind": _check.parse_source("(llist list &body body)")[0]}
        found = find_undefined(src, {"defun", "lambda-bind", "known"}, table)
        self.assertEqual(names(found), [])

    def test_collector_sees_defuns_inside_function_lambda(self):
        src = "(setq hook #'(lambda ()\n  (defun batch-helper ()\n    (known))))\n"
        defs = collect_defs(_check.parse_source(src))
        self.assertIn("batch-helper", defs)


class EarmuffTests(unittest.TestCase):
    def test_earmuff_operator_is_not_a_call(self):
        src = "(defun f ()\n  (with-output-to-string (*standard-output*)\n    (known 1)))\n"
        table = {"with-output-to-string": _check.parse_source("((var) &body body)")[0]}
        found = find_undefined(src, {"defun", "with-output-to-string", "known"}, table)
        self.assertEqual(names(found), [])

if __name__ == "__main__":
    unittest.main()
