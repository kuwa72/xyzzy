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



class UndefinedVariableTests(unittest.TestCase):
    def find_vars(self, src, known):
        return _check.find_undefined_variables(src, known)


    def test_flags_setq_to_undeclared_variable(self):
        src = "(defun f ()\n  (setq my-state 1))\n"
        self.assertIn("my-state", names(self.find_vars(src, set())))

    def test_accepts_declared_global(self):
        src = "(defun f ()\n  (setq *my-state* 1))\n"
        self.assertEqual(
            names(self.find_vars(src, {"*my-state*"})), [])

    def test_flags_bare_reference_to_undeclared_variable(self):
        src = "(defun f (x)\n  (list x my-var))\n"
        self.assertIn("my-var", names(self.find_vars(src, set())))

    def test_accepts_let_and_lambda_bindings(self):
        src = "(defun f (arg)\n  (let ((x arg))\n    ((lambda (y) (list x y)) 1)))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_ignores_operator_position_and_quoted_data(self):
        src = "(defun f ()\n  (my-fn 1)\n  'my-var\n  #'my-fn)\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_skips_t_nil_and_keywords(self):
        src = "(defun f (x)\n  (list t nil :key x))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_defvar_init_is_checked_but_name_declares(self):
        src = "(defvar *a* other-var)\n"
        found = names(self.find_vars(src, {"*a*"}))
        self.assertIn("other-var", found)
        self.assertNotIn("*a*", found)

    def test_dolist_binds_its_variable(self):
        src = "(defun f (items)\n  (dolist (x items)\n    (list x)))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_loop_for_binds_its_variable(self):
        src = "(defun f (items)\n  (loop for x in items collect x))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_case_keys_and_the_types_are_not_references(self):
        src = "(defun f (x)\n  (case x\n    (1 (the fixnum x))\n    (otherwise nil)))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_collects_defvar_and_buffer_local_declarations(self):
        src = ("(defvar *a* 1)\n"
               "(defparameter *b* 2)\n"
               "(defconstant +c+ 3)\n"
               "(make-variable-buffer-local 'buf-var)\n")
        got = _check.collect_lisp_variables(_check.parse_source(src))
        for want in ("*a*", "*b*", "+c+", "buf-var"):
            self.assertIn(want, got)

    def test_extracts_cxx_variables_not_functions(self):
        src = ("  DEFUN3 (foo, 1, 0, 0),\n"
               "  DEFVAR2 (*bar*),\n"
               "  SI_DEFVAR2 (*baz*),\n"
               "  MAKE_SYMBOL2 (mode-name),\n")
        self.assertEqual(
            _check.extract_cxx_variables(src),
            {"*bar*", "*baz*", "mode-name"})
class UndefinedVariableScopeTests(unittest.TestCase):
    def find_vars(self, src, known):
        return _check.find_undefined_variables(src, known)

    def test_flet_body_sees_its_params(self):
        src = "(defun f (tree)\n  (labels ((make-tree (node)\n              (list node tree)))\n    (make-tree 1)))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_defsetf_long_form_binds_stores(self):
        src = "(defsetf ole-method (obj prop &rest args) (x)\n  (list obj prop args x))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_nested_template_unquotes_are_not_checked(self):
        src = "(defmacro m (name i)\n  `(defsetf ,name (x) (y)\n     `(*set-index-slot-value ,x ,,i ,y)))\n"
        found = names(self.find_vars(src, set()))
        self.assertNotIn("y", found)
        self.assertNotIn("x", found)

    def test_double_unquote_still_sees_macro_args(self):
        src = "(defmacro m (i)\n  `(progn `(old ,,i)))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_sharp_labels_are_not_variables(self):
        src = "(defun f (e)\n  (find e #1=(list e) #1#))\n"
        found = names(self.find_vars(src, {"find"}))
        self.assertNotIn("=", found)
        self.assertNotIn("#1", found)

    def test_char_with_modifier_and_punctuation(self):
        src = "(defun f (e)\n  (list e #\\C-=))\n"
        found = names(self.find_vars(src, set()))
        self.assertNotIn("=", found)

    def test_mid_symbol_bars_stay_one_symbol(self):
        src = "(defun f ()\n  (list :|above-(>_<)|))\n"
        self.assertEqual(names(self.find_vars(src, {"list"})), [])

    def test_deftest_markers_and_data_are_not_checked(self):
        src = ("(deftest sample-test ()\n"
               '  "doc"\n'
               "  (list 1)\n"
               "  => (1)\n"
               "  (list)\n"
               "  => non-nil\n"
               "  (err) => nil)\n")
        found = names(self.find_vars(src, {"deftest", "list", "err"}))
        self.assertNotIn("=>", found)
        self.assertNotIn("non-nil", found)

    def test_deftest_options_name_functions(self):
        src = ("(deftest sample-test (:compare equalp)\n"
               "  (list 1)\n"
               "  => (1))\n")
        found = names(self.find_vars(src, {"deftest", "list"}))
        self.assertNotIn("equalp", found)
        self.assertNotIn("compare", found)

class UndefinedVariableIdiomTests(unittest.TestCase):
    def find_vars(self, src, known):
        return _check.find_undefined_variables(src, known)

    def test_ole_brace_block_is_opaque(self):
        src = ("(defun f (ie)\n"
               "  #{ie.Navigate[\"http://x/\"]}\n"
               "  '#{worksheets.Add[{:After worksheet} {:Count 2}]}\n"
               "  nil)\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_char_backslash_with_modifier(self):
        src = "(defun f ()\n  (list #\\C-\\\\))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_ratios_and_short_float_suffixes_are_numbers(self):
        src = "(defun f ()\n  (list 1/2 9/10 0.0s0 0.0f0 0.0d0 0.0l0 3/4))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_dot_is_not_a_variable(self):
        src = "(defvar *ole-reader-.* '#:|.|)\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_environment_and_whole_bind(self):
        src = ("(defmacro m (a &environment env)\n"
               "  (list a env))\n"
               "(defmacro n (&whole w a)\n"
               "  (list w a))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_destructuring_whole_binds(self):
        src = ("(destructuring-bind (&whole w a b) '(1 2)\n"
               "  (list w a b))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_selection_start_end_binds(self):
        src = ("(defun f ()\n"
               "  (selection-start-end (s e)\n"
               "    (list s e)))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_with_temp_files_and_dirs_bind(self):
        src = ("(with-temp-files (f1 f2)\n"
               "  (list f1 f2))\n"
               "(with-temp-dirs (d)\n"
               "  (list d))\n"
               "(with-directory-test-dirs (t)\n"
               "  (list t))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_lambda_bind_binds(self):
        src = ("(lambda-bind (#:type c &rest vs) lod\n"
               "  (list c vs))\n")
        self.assertEqual(names(self.find_vars(src, {"lod"})), [])

    def test_define_failure_reporter_binds(self):
        src = ("(define-failure-reporter :r :t (exp act)\n"
               "  (list exp act))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_defpred_binds_and_number_skips(self):
        src = ("(defpred member (object r)\n"
               "  (member object r))\n"
               "(defpred-number long-float long-float-p)\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_calc_assoc_names_are_definitions(self):
        src = "(calc-assoc-right calc-power-expr calc-unary-expr expt)\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_define_c_type_args_are_quoted(self):
        src = "(*define-c-type :void void)\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_defun_c_callable_binds_typed_args(self):
        src = ("(c:defun-c-callable c:int\n"
               "  (cmp :convention :cdecl) (((c:void *) a) ((c:void *) b))\n"
               "  (list a b))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_define_modify_macro_fn_is_not_a_variable(self):
        src = "(define-modify-macro incf (&optional (d 1)) +)\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_define_benchmark_binds(self):
        src = "(define-benchmark fib (n)\n  (list n))\n"
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_macrolet_calls_are_opaque_but_bodies_checked(self):
        src = ("(macrolet ((ar (f o)\n"
               "             `(list ',f ,o)))\n"
               "  (ar (x 1) \"s\"))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])
        bad = ("(macrolet ((ar (f)\n"
               "             (list f oops)))\n"
               "  (ar 1))\n")
        self.assertIn("oops", names(self.find_vars(bad, set())))

    def test_deftest_output_lines_are_text(self):
        src = ("(deftest t1 ()\n"
               "  (list 1)\n"
               "  >> foo = 1, test = t\n"
               "  => nil)\n")
        found = names(self.find_vars(src, {"deftest", "list"}))
        self.assertNotIn("=", found)
        self.assertNotIn("foo", found)
        self.assertNotIn("test", found)

    def test_bare_output_marker_before_expectation(self):
        src = ("(deftest t1 ()\n"
               "  (list 1)\n"
               "  >>\n"
               "  => nil)\n")
        self.assertEqual(names(self.find_vars(src, {"deftest", "list"})), [])

    def test_c_size_of_takes_types(self):
        src = ("(c:c-size-of c:void)\n"
               "(c:c-struct-size-of c-size-of-test)\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

    def test_deftest_prompt_macro_skips_name(self):
        src = ("(deftest-prompt-checks-string read-string-checks-prompt\n"
               "  (read-string 5))\n")
        self.assertEqual(
            names(self.find_vars(src, {"read-string"})), [])

    def test_collects_boundp_and_local_and_special(self):
        src = ("(or (boundp 'my-g)\n"
               "    (setq my-g nil))\n"
               "(make-local-variable 'my-l)\n"
               "(defun f (x)\n"
               "  (declare (special my-s))\n"
               "  (list my-s))\n")
        got = _check.collect_lisp_variables(_check.parse_source(src))
        for want in ("my-g", "my-l", "my-s"):
            self.assertIn(want, got)

    def test_define_condition_slots_are_data(self):
        src = ("(define-condition c (e)\n"
               "  (string place)\n"
               "  (:report (lambda (x y) (list x y))))\n")
        self.assertEqual(names(self.find_vars(src, set())), [])

if __name__ == "__main__":
    unittest.main()
