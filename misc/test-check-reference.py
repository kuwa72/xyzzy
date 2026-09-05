#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "check_reference", Path(__file__).with_name("check-reference.py")
)
_check_reference = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_check_reference)
extract_lisp_symbols = _check_reference.extract_lisp_symbols
extract_cxx_symbols = _check_reference.extract_cxx_symbols
compare_symbols = _check_reference.compare_symbols


class CheckReferenceTests(unittest.TestCase):
    def test_extracts_lisp_definitions_without_comments(self):
        source = """; (defun ignored (x) x)\n(defun foo (x) x)\n(defmacro bar (&body body) body)\n(defvar *baz* nil)\n(print \"(defun string-not-a-definition)\")\n"""
        self.assertEqual(extract_lisp_symbols(source), {"foo", "bar", "*baz*"})

    def test_extracts_registered_cxx_symbols(self):
        source = """#define DEFUN3(name, req, opt, f) DEFUN (name, req, opt, f)\n#define DEFUN2(lname, cname, req, opt, f) \\\n  DEFUN (lname, cname, req, opt, f)\n\n  DEFUN3 (foo, 1, 0, 0),\n  SI_DEFUN2X (si:bar, bar, 0, 0, 0),\n  DEFVAR2 (*baz*),\n  DEFSF3Q (quote),\n  SI_DEFUN2X (\"#\\\\-reader\", reader, 2, 0, 0),\n"""
        self.assertEqual(
            extract_cxx_symbols(source),
            {"foo", "si:bar", "*baz*", "quote", "#\\-reader"},
        )

    def test_compares_documented_and_implemented_symbols(self):
        result = compare_symbols({"foo", "old"}, {"foo", "new"})
        self.assertEqual(result, {"undocumented": ["new"], "missing": ["old"]})


if __name__ == "__main__":
    unittest.main()
