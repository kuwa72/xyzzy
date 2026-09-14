#!/usr/bin/env python3
"""Detect calls to functions that are defined nowhere.

`lsp-mode` once called the Emacs-ism `prefix-numeric-value` and nobody
noticed until runtime. The byte compiler emits no warning for this, so
scan `lisp/`, `unittest/` and `misc/` statically instead: parse every
`.l` file, collect the known functions (C++ builtins from
`src/gen-syms.cc` plus `defun`/`defmacro`/etc. across the tree) and
report every call position that resolves to none of them.

Only the function namespace is checked. Lexical bindings (`let`,
lambda lists, `labels`/`flet`, ...) are understood so binding specs
are never mistaken for calls; quoted data and backquote templates are
skipped except for their unquoted parts.

Usage: tools/check-lisp-undefined.py REPO_ROOT [--json]
Exit status is 1 when undefined calls are found.
"""

import json
import re
import sys
from collections import namedtuple
from pathlib import Path

Finding = namedtuple("Finding", ("path", "line", "name", "context"))

CXX_FUNC_MACROS = (
    "DEFUN",
    "DEFUN2",
    "DEFUN3",
    "DEFUN3Q",
    "SI_DEFUN2X",
    "SI_DEFUN3",
    "CL_DEFUN2X",
    "CL_DEFUN3",
    "DEFSF",
    "DEFSF2",
    "DEFSF3",
    "DEFSF3Q",
    "SI_DEFSF3",
    "CL_DEFSF3",
    "DEFMACRO",
    "DEFMACRO3",
    "DEFMACRO3Q",
    "DEFPMACRO",
    "DEFPMACRO3",
    "DEFPMACRO3Q",
    "DEFCMD",
    "DEFCMD2",
    "DEFCMD3",
)

DEFINE_OPS = {
    "defun",
    "defmacro",
    "defsubst",
    "define-modify-macro",
    "defsetf",
    "define-setf-method",
    "deftype",
    "defgeneric",
    "defmethod",
    "defclass",
    "define-condition",
    "define-dll-entry",
    "*define-dll-entry",
    "defun-c-callable",
    "defun-builtin",
    "defun-builtin-1",
}

SKIP_FORMS = {
    "in-package",
    "defpackage",
    "provide",
    "require",
    "export",
    "import",
    "shadow",
    "shadowing-import",
    "use-package",
    "declaim",
    "proclaim",
}

class Symbol:
    __slots__ = ("name", "line")

    def __init__(self, name, line):
        self.name = name
        self.line = line

    def __repr__(self):
        return "Symbol(%r)" % (self.name,)


def norm(name):
    """Compare symbols by bare name, case-insensitively.

    `editor:foo`, `ed::foo` and `foo` are the same function for the
    purpose of "is it defined anywhere", and the tree mixes cases.
    """
    return name.split(":")[-1].lower()


def opname(form):
    """Normalized operator name of a form head (Symbol or :keyword)."""
    if isinstance(form, Symbol):
        return norm(form.name)
    if isinstance(form, tuple) and form[0] == "kw":
        return norm(form[1])
    return None


class Reader:
    def __init__(self, source):
        self.src = source
        self.pos = 0
        self.line = 1
        self.tokens = []
        self._tokenize()
        self.cursor = 0

    def _peek_char(self):
        if self.pos < len(self.src):
            return self.src[self.pos]
        return ""

    def _advance(self, n=1):
        for _ in range(n):
            if self.pos < len(self.src):
                if self.src[self.pos] == "\n":
                    self.line += 1
                self.pos += 1

    def _tokenize(self):
        src = self.src
        while self.pos < len(src):
            c = src[self.pos]
            if c in " \t\r\n\f\v":
                self._advance()
            elif c == ";":
                while self.pos < len(src) and src[self.pos] != "\n":
                    self.pos += 1
            elif src.startswith("#|", self.pos):
                depth = 0
                while self.pos < len(src):
                    if src.startswith("#|", self.pos):
                        depth += 1
                        self._advance(2)
                    elif src.startswith("|#", self.pos):
                        depth -= 1
                        self._advance(2)
                        if depth == 0:
                            break
                    else:
                        self._advance()
            elif c == '"':
                line = self.line
                self._advance()
                buf = []
                while self.pos < len(src) and src[self.pos] != '"':
                    if src[self.pos] == "\\":
                        buf.append(src[self.pos : self.pos + 2])
                        self._advance(2)
                    else:
                        buf.append(src[self.pos])
                        self._advance()
                self._advance()
                self.tokens.append(("str", "".join(buf), line))
            elif c == "|":
                line = self.line
                self._advance()
                buf = []
                while self.pos < len(src) and src[self.pos] != "|":
                    if src[self.pos] == "\\":
                        self._advance()
                        if self.pos < len(src):
                            buf.append(src[self.pos])
                            self._advance()
                    else:
                        buf.append(src[self.pos])
                        self._advance()
                self._advance()
                self.tokens.append(("sym", "".join(buf), line))
            elif c == "(":
                self.tokens.append(("lp", None, self.line))
                self._advance()
            elif c == ")":
                self.tokens.append(("rp", None, self.line))
                self._advance()
            elif c == "'":
                self.tokens.append(("quote", None, self.line))
                self._advance()
            elif c == "`":
                self.tokens.append(("backquote", None, self.line))
                self._advance()
            elif c == ",":
                if src.startswith(",@", self.pos):
                    self.tokens.append(("unquote-splicing", None, self.line))
                    self._advance(2)
                else:
                    self.tokens.append(("unquote", None, self.line))
                    self._advance()
            elif c == "#":
                line = self.line
                nxt = src[self.pos + 1 : self.pos + 2]
                if nxt == "'":
                    self.tokens.append(("sharp-quote", None, line))
                    self._advance(2)
                elif nxt == "(":
                    self.tokens.append(("sharp-lp", None, line))
                    self._advance(2)
                elif nxt == "\\":
                    self._advance(2)
                    if self.pos < len(src) and src[self.pos].isalpha():
                        while self.pos < len(src) and (
                            src[self.pos].isalnum() or src[self.pos] in "-+"
                        ):
                            self._advance()
                    elif self.pos < len(src):
                        self._advance()
                    self.tokens.append(("atom", None, line))
                elif nxt == ":" and src[self.pos + 2 : self.pos + 3] not in ("", " ", "\t", "\n", "(", ")"):
                    self._advance(2)
                    start = self.pos
                    while self.pos < len(src) and src[self.pos] not in " \t\r\n\f\v();\"`|',":
                        self._advance()
                    self.tokens.append(("sym", src[start : self.pos], line))
                elif nxt == "*":
                    self._advance(2)
                    while self.pos < len(src) and src[self.pos] in "01":
                        self._advance()
                    self.tokens.append(("atom", None, line))
                elif nxt == ".":
                    self._advance(2)
                elif nxt and (nxt.isdigit() or nxt.isalpha()):
                    self._advance()
                    start = self.pos
                    while self.pos < len(src) and (
                        src[self.pos].isalnum() or src[self.pos] in "+-"
                    ):
                        self._advance()
                    word = src[start : self.pos]
                    if self.pos < len(src) and src[self.pos] == "(":
                        self.tokens.append(("sharp-lp", None, line))
                        self._advance()
                    elif re.fullmatch(r"[xX][0-9a-fA-F]+|[bB][01]+|[oO][0-7]+|[0-9]+[rR][0-9A-Za-z]+", word or " ") \
                            or (nxt.isdigit() and word == ""):
                        self.tokens.append(("atom", None, line))
                    else:
                        self.tokens.append(("atom", None, line))
                else:
                    self._advance()
                    start = self.pos
                    while self.pos < len(src) and src[self.pos] not in " \t\r\n\f\v();\"`|',":
                        self._advance()
                    word = src[start : self.pos]
                    if word == "":
                        self.tokens.append(("atom", None, line))
                    else:
                        self.tokens.append(("sym", "#" + word, line))
            elif c == "." and (
                self.pos + 1 >= len(src) or src[self.pos + 1] in " \t\r\n\f\v()"
            ):
                self._advance()
            else:
                line = self.line
                buf = []
                while self.pos < len(src) and src[self.pos] not in " \t\r\n\f\v();\"`|":
                    if src[self.pos] in "'`,":
                        break
                    buf.append(src[self.pos])
                    self._advance()
                if buf:
                    self.tokens.append(("sym", "".join(buf), line))

    def peek(self):
        if self.cursor < len(self.tokens):
            return self.tokens[self.cursor]
        return (None, None, self.line)

    def next(self):
        tok = self.peek()
        self.cursor += 1
        return tok

    def parse_all(self):
        forms = []
        while self.cursor < len(self.tokens):
            forms.append(self.parse_form())
        return forms

    def parse_form(self):
        kind, value, line = self.next()
        if kind == "lp" or kind == "sharp-lp":
            items = []
            while self.peek()[0] != "rp":
                if self.peek()[0] is None:
                    break
                items.append(self.parse_form())
            self.next()
            if kind == "sharp-lp":
                return ("vector", items, line)
            return items if items else []
        if kind == "rp":
            return []
        if kind in ("quote", "backquote", "unquote", "unquote-splicing", "sharp-quote"):
            inner = self.parse_form()
            tag = {"quote": "quote", "backquote": "backquote",
                   "unquote": "unquote",
                   "unquote-splicing": "unquote-splicing",
                   "sharp-quote": "function"}[kind]
            return (tag, inner, line)
        if kind == "str":
            return ("str", value, line)
        if kind == "atom":
            return ("atom", line)
        sym = Symbol(value, line)
        if value.startswith(":"):
            return ("kw", value, line)
        if re.fullmatch(r"[+-]?(\d+\.?\d*|\.\d+)([eEdD][+-]?\d+)?", value):
            return ("num", value, line)
        return sym


def parse_source(source):
    return Reader(source).parse_all()


def collect_lisp_definitions(forms, macro_ll=None):
    """Collect function-namespace definitions from parsed forms.

    When macro_ll is a dict it is filled with defmacro name -> lambda-list
    so callers can distinguish evaluated arguments from binding structure.
    """
    defs = set()

    def add(name):
        if name:
            defs.add(norm(name))

    def struct_names(name, slots, conc, predicate=True):
        add("make-" + name)
        add("copy-" + name)
        if predicate:
            add(name + "-p")
        prefix = name + "-" if conc is None else (
            "" if conc is False else str(conc))
        for slot in slots:
            if isinstance(slot, Symbol):
                add(prefix + slot.name)
            elif isinstance(slot, list) and slot and isinstance(slot[0], Symbol):
                add(prefix + slot[0].name)

    def condition_slots(body):
        found = []
        if not body:
            return found
        slots = body[0]
        if isinstance(slots, Symbol):
            found.append((slots.name, None))
        elif isinstance(slots, list):
            for item in slots:
                if isinstance(item, Symbol):
                    if not item.name.startswith(":"):
                        found.append((item.name, None))
                elif isinstance(item, list) and item and isinstance(item[0], Symbol):
                    if item[0].name.startswith(":"):
                        continue
                    found.append((item[0].name, item[1] if len(item) > 1 else None))
        return found

    def visit(form):
        if isinstance(form, tuple):
            tag = form[0]
            if tag == "quote":
                return
            if tag == "function":
                inner = form[1] if len(form) > 1 else None
                if isinstance(inner, list) and inner and isinstance(inner[0], Symbol) \
                        and norm(inner[0].name) == "lambda":
                    visit(inner)
                return
            if tag == "backquote":
                return
            for sub in form[1:]:
                if isinstance(sub, (list, tuple)):
                    visit(sub)
            return
        if not isinstance(form, list) or not form:
            return
        head = form[0]
        op = norm(head.name) if isinstance(head, Symbol) else None
        if op == "defstruct":
            rest = form[1:]
            if rest:
                if isinstance(rest[0], Symbol):
                    name = norm(rest[0].name)
                    struct_names(name, rest[1:], None, True)
                elif isinstance(rest[0], list) and rest[0] and isinstance(rest[0][0], Symbol):
                    name = norm(rest[0][0].name)
                    conc = None
                    predicate = True
                    for opt in rest[0][1:]:
                        if not (isinstance(opt, list) and opt):
                            continue
                        key = opname(opt[0])
                        if key == "conc-name" and len(opt) > 1:
                            conc = opt[1]
                            if isinstance(conc, Symbol):
                                conc = "" if norm(conc.name) == "nil" else conc.name
                            elif isinstance(conc, tuple) and conc[0] == "str":
                                conc = conc[1].encode("utf-8").decode("unicode_escape")
                            else:
                                conc = None
                        elif key in ("constructor", "copier", "predicate") and len(opt) > 1:
                            target = opt[1]
                            sym = None
                            if isinstance(target, Symbol):
                                sym = target.name
                            elif isinstance(target, list) and target \
                                    and isinstance(target[0], Symbol):
                                sym = target[0].name
                            if sym and norm(sym) != "nil":
                                add(sym)
                                if key == "predicate":
                                    predicate = False
                    struct_names(name, rest[1:], conc, predicate)
            for sub in form[1:]:
                visit(sub)
            return
        if op == "define-condition":
            if len(form) > 1 and isinstance(form[1], Symbol):
                cname = norm(form[1].name)
                add(form[1].name)
                for slot, _init in condition_slots(form[3:]):
                    add(cname + "-" + slot)
            return
        if op == "compile" and len(form) > 1:
            # (compile 'name ...) defines name at run time (used by tests).
            target = form[1]
            if isinstance(target, tuple) and target[0] in ("quote", "function") \
                    and isinstance(target[1], Symbol):
                add(target[1].name)
        if op == "setf" and len(form) > 2:
            # (setf (symbol-function 'foo) ...) defines foo at load time.
            place = form[1]
            if isinstance(place, list) and len(place) == 2 \
                    and isinstance(place[0], Symbol) \
                    and norm(place[0].name) == "symbol-function":
                target = place[1]
                if isinstance(target, tuple) and target[0] in ("quote", "function") \
                        and isinstance(target[1], Symbol):
                    add(target[1].name)
            for sub in form[1:]:
                visit(sub)
            return
        if op == "defmacro" and len(form) > 2 and isinstance(form[1], Symbol) \
                and isinstance(form[2], list) and macro_ll is not None:
            macro_ll[norm(form[1].name)] = form[2]
        if op in DEFINE_OPS:
            if len(form) > 1:
                nameform = form[1]
                if isinstance(nameform, Symbol):
                    add(nameform.name)
                elif isinstance(nameform, list) and len(nameform) >= 2:
                    if isinstance(nameform[0], Symbol) and norm(nameform[0].name) == "setf":
                        pass
                    elif isinstance(nameform[0], Symbol):
                        add(nameform[0].name)
                    for extra in nameform[1:]:
                        if isinstance(extra, Symbol):
                            add(extra.name)
                if op in ("define-dll-entry", "*define-dll-entry", "defun-c-callable"):
                    for extra in form[2:]:
                        if isinstance(extra, Symbol):
                            add(extra.name)
                        elif isinstance(extra, list):
                            for item in extra:
                                if isinstance(item, Symbol):
                                    add(item.name)
                            break
            for sub in form[2:]:
                visit(sub)
            return
        if op == "defvar" or op == "defconstant" or op == "defparameter" \
                or op == "defvar-local" or op == "define-history-variable":
            return
        for sub in form:
            visit(sub)

    for top in forms:
        visit(top)
    return defs


def extract_cxx_functions(source):
    macros = "|".join(map(re.escape, CXX_FUNC_MACROS))
    funcs = set()
    for match in re.finditer(
        r"\b(?:" + macros + r")\s*\(\s*(?:\"((?:\\.|[^\"])*)\"|([^,\s()]+))",
        source,
    ):
        symbol = match.group(1) or match.group(2)
        if match.group(1):
            symbol = bytes(symbol, "utf-8").decode("unicode_escape")
        if symbol:
            funcs.add(norm(symbol))
    return funcs


def collect_template_funcs(form):
    """Function names bound inside a backquote template.

    Unquoted fragments (e.g. `,(c "double")`) may call locals the
    template itself binds (`(labels ((c ...) ...) ...)`); treat those
    as known while checking the unquotes.
    """
    found = set()

    def scan(node):
        if isinstance(node, Symbol):
            return
        if isinstance(node, tuple):
            if node[0] in ("quote", "function"):
                return
            for sub in node[1:]:
                if isinstance(sub, (list, tuple)):
                    scan(sub)
            return
        if not isinstance(node, list) or not node:
            return
        head = node[0]
        name = opname(head)
        if name in ("defun", "defmacro", "defsubst"):
            if len(node) > 1 and isinstance(node[1], Symbol):
                found.add(norm(node[1].name))
        elif name in ("flet", "labels", "macrolet"):
            if len(node) > 1 and isinstance(node[1], list):
                for spec in node[1]:
                    if isinstance(spec, list) and spec and isinstance(spec[0], Symbol):
                        found.add(norm(spec[0].name))
        for sub in node:
            scan(sub)

    scan(form)
    return found


class Checker:
    def __init__(self, known, macro_ll=None):
        self.known = set(known)
        self.macro_ll = macro_ll or {}
        self.findings = []
        self.context = None
        self.local_funcs = []

    def is_known(self, name):
        key = norm(name)
        if key in self.known:
            return True
        return any(key in scope for scope in self.local_funcs)

    def record(self, sym):
        if not self.is_known(sym.name):
            self.findings.append(Finding(None, sym.line, sym.name, self.context))

    def walk(self, form):
        if isinstance(form, Symbol):
            return
        if isinstance(form, tuple):
            tag = form[0]
            if tag == "quote":
                return
            if tag == "function":
                inner = form[1]
                if isinstance(inner, Symbol):
                    self.record(inner)
                else:
                    self.walk(inner)
                return
            if tag == "backquote":
                self.walk_template(form[1])
                return
            if tag in ("unquote", "unquote-splicing"):
                self.walk(form[1])
                return
            if tag == "vector":
                self.walk_template(form[1])
                return
            return
        if not isinstance(form, list) or not form:
            return
        head = form[0]
        if isinstance(head, list) or isinstance(head, tuple):
            self.walk(head)
            for sub in form[1:]:
                self.walk(sub)
            return
        if not isinstance(head, Symbol):
            for sub in form:
                self.walk(sub)
            return
        op = norm(head.name)
        handler = getattr(self, "handle_" + op.replace("-", "_").replace("*", ""), None)
        if handler is not None:
            handler(form)
            return
        if op in SKIP_FORMS:
            return
        if head.name.startswith(":"):
            for sub in form[1:]:
                self.walk(sub)
            return
        if len(head.name) > 2 and head.name.startswith("*") and head.name.endswith("*"):
            # *earmuffs* name a special variable, never a function.  Such a
            # form in operator position is a binding spec or data (e.g. the
            # (*standard-output* ...) argument of with-output-to-string).
            for sub in form[1:]:
                self.walk(sub)
            return
        if op == "fboundp" and len(form) == 2:
            target = form[1]
            if isinstance(target, tuple) and target[0] == "quote" \
                    and isinstance(target[1], Symbol):
                self.known.add(norm(target[1].name))
        self.record(head)
        table = self.macro_ll.get(op)
        if table is None:
            for sub in form[1:]:
                self.walk(sub)
        else:
            self.walk_macro_args(table, form[1:])

    MARKERS = frozenset((
        "&optional", "&rest", "&key", "&allow-other-keys", "&aux",
        "&body", "&whole", "&environment",
    ))

    def walk_macro_args(self, params, args):
        args = list(args)
        i = 0
        j = 0
        section = None
        while j < len(params):
            param = params[j]
            if isinstance(param, Symbol):
                name = norm(param.name)
                if name in ("&whole", "&environment"):
                    j += 1
                    if j < len(params) and not (
                            isinstance(params[j], Symbol)
                            and norm(params[j].name) in self.MARKERS):
                        j += 1
                    continue
                if name in ("&rest", "&body"):
                    j += 1
                    rest = params[j] if j < len(params) else None
                    if isinstance(rest, Symbol):
                        for arg in args[i:]:
                            self.walk(arg)
                    elif isinstance(rest, list):
                        for arg in args[i:]:
                            self.walk_structure(arg, rest)
                    else:
                        for arg in args[i:]:
                            self.walk(arg)
                    i = len(args)
                    if j < len(params):
                        j += 1
                    continue
                if name in self.MARKERS:
                    section = name
                    j += 1
                    continue
                if i < len(args):
                    self.walk(args[i])
                    i += 1
                j += 1
            elif isinstance(param, list):
                if section is None:
                    if i < len(args):
                        self.walk_structure(args[i], param)
                        i += 1
                else:
                    if i < len(args):
                        self.walk_spec_call(args[i], param)
                        i += 1
                j += 1
            else:
                j += 1
        for arg in args[i:]:
            self.walk(arg)

    def walk_spec_call(self, arg, spec):
        # &optional/&key/&aux (var-pattern [default [svar]]): the value
        # argument is evaluated only when the head is a plain variable.
        if not spec:
            return
        head = spec[0]
        if isinstance(head, Symbol) and not head.name.startswith("&"):
            self.walk(arg)
        elif isinstance(head, list):
            self.walk_structure(arg, head)
        elif isinstance(head, tuple):
            self.walk(arg)
        else:
            self.walk(arg)

    def walk_structure(self, arg, pattern):
        # Destructuring pattern against a binding-structure argument:
        # plain variables bind (skip), nested patterns recurse. Only the
        # argument side can contain code, and only where the pattern has
        # already established structure -- a bare symbol argument is a
        # variable reference, never a call.
        if isinstance(arg, Symbol):
            return
        if not isinstance(arg, list):
            self.walk(arg)
            return
        items = list(arg)
        k = 0
        m = 0
        section = None
        while m < len(pattern):
            pat = pattern[m]
            if isinstance(pat, Symbol):
                name = norm(pat.name)
                if name in ("&whole", "&environment"):
                    m += 1
                    if m < len(pattern) and not (
                            isinstance(pattern[m], Symbol)
                            and norm(pattern[m].name) in self.MARKERS):
                        m += 1
                    continue
                if name in ("&rest", "&body"):
                    m += 1
                    rest = pattern[m] if m < len(pattern) else None
                    if isinstance(rest, Symbol):
                        k = len(items)
                    elif isinstance(rest, list):
                        for item in items[k:]:
                            self.walk_structure(item, rest)
                        k = len(items)
                    if m < len(pattern):
                        m += 1
                    continue
                if name in self.MARKERS:
                    section = name
                    m += 1
                    continue
                k += 1
                m += 1
            elif isinstance(pat, list):
                if k < len(items):
                    if section is None:
                        self.walk_structure(items[k], pat)
                    else:
                        self.walk_spec_call(items[k], pat)
                    k += 1
                m += 1
            else:
                m += 1

    def walk_template(self, form):
        self.local_funcs.append(collect_template_funcs(form))
        try:
            self._walk_template(form)
        finally:
            self.local_funcs.pop()

    def _walk_template(self, form):
        if isinstance(form, Symbol):
            return
        if isinstance(form, tuple):
            tag = form[0]
            if tag in ("unquote", "unquote-splicing"):
                self.walk(form[1])
                return
            if tag == "backquote":
                self._walk_template(form[1])
                return
            if tag == "vector":
                self._walk_template(form[1])
                return
            return
        if isinstance(form, list):
            for sub in form:
                self._walk_template(sub)

    def walk_lambda_list(self, arglist):
        """Walk init-forms in a lambda-list without mistaking specs for calls.

        Macro lambda-lists nest: ((pattern &optional (var init)) &body body).
        Only init-forms are code; everything else is binding structure.
        """
        if not isinstance(arglist, list):
            return
        self._walk_ll(arglist, None)

    def _walk_ll(self, items, section):
        skip_next = False
        for el in items:
            if isinstance(el, Symbol):
                name = norm(el.name)
                if name in ("&rest", "&body", "&whole", "&environment"):
                    skip_next = True
                elif name.startswith("&"):
                    skip_next = False
            elif isinstance(el, list):
                if skip_next:
                    self._walk_ll(el, None)
                elif section is None:
                    self._walk_ll(el, None)
                else:
                    self.walk_spec(el)
                skip_next = False
            else:
                skip_next = False

    def walk_spec(self, spec):
        """A (var [init [svar]]) or (pattern [init [svar]]) spec: only init is code."""
        if not spec:
            return
        first = spec[0]
        if isinstance(first, Symbol) and first.name.startswith("&"):
            self._walk_ll(spec, None)
            return
        if isinstance(first, list):
            self._walk_ll(first, None)
        if len(spec) > 1:
            self.walk(spec[1])

    def walk_body(self, forms, skip_declares=True):
        for sub in forms:
            if skip_declares and isinstance(sub, list) and sub \
                    and isinstance(sub[0], Symbol) and norm(sub[0].name) == "declare":
                continue
            self.walk(sub)

    def handle_declare(self, form):
        return

    def handle_declaim(self, form):
        return

    def handle_proclaim(self, form):
        return

    def _handle_define(self, form):
        if len(form) > 1 and isinstance(form[1], Symbol):
            saved = self.context
            self.context = form[1].name
            if len(form) > 2 and isinstance(form[2], list):
                self.walk_lambda_list(form[2])
            self.walk_body(form[3:])
            self.context = saved
        else:
            for sub in form[1:]:
                self.walk(sub)

    handle_defun = _handle_define
    handle_defun_builtin = _handle_define
    handle_defmacro = _handle_define

    def handle_defun_c_callable(self, form):
        # (op return-type name args body...): only body is evaluated.
        saved = self.context
        if len(form) > 2 and isinstance(form[2], Symbol):
            self.context = form[2].name
        elif len(form) > 2 and isinstance(form[2], list) and form[2] \
                and isinstance(form[2][0], Symbol):
            self.context = form[2][0].name
        self.walk_body(form[4:])
        self.context = saved

    def handle_define_dll_entry(self, form):
        # (op return-type name-and-options (args) dll-name ...):
        # only dll-name may be evaluated.
        if len(form) > 4:
            self.walk(form[4])

    def handle_define_c_struct(self, form):
        return

    handle_define_c_type = handle_define_c_struct

    def handle_c_vaargs(self, form):
        # (c-vaargs (type value)...): type tags are data, values are code.
        for arg in form[1:]:
            if isinstance(arg, list):
                self.walk_body(arg[1:])
            else:
                self.walk(arg)
    handle_defsubst = _handle_define
    handle_defun_c_callable = _handle_define

    def handle_lambda(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            self.walk_lambda_list(form[1])
        self.walk_body(form[2:])

    def handle_let(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for spec in form[1]:
                if isinstance(spec, list):
                    for sub in spec[1:]:
                        self.walk(sub)
        self.walk_body(form[2:])

    handle_let_star = handle_let

    def _handle_flet(self, form):
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else []
        names = set()
        for spec in specs:
            if isinstance(spec, list) and spec and isinstance(spec[0], Symbol):
                names.add(norm(spec[0].name))
        self.local_funcs.append(names)
        for spec in specs:
            if isinstance(spec, list) and len(spec) > 1 and isinstance(spec[1], list):
                self.walk_lambda_list(spec[1])
            if isinstance(spec, list):
                self.walk_body(spec[2:])
        self.walk_body(form[2:])
        self.local_funcs.pop()

    handle_flet = _handle_flet
    handle_labels = _handle_flet
    handle_macrolet = _handle_flet

    def handle_multiple_value_bind(self, form):
        for sub in form[2:]:
            self.walk(sub)

    handle_destructuring_bind = handle_multiple_value_bind
    handle_multiple_value_setq = handle_multiple_value_bind

    def handle_do(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for spec in form[1]:
                if isinstance(spec, list):
                    for sub in spec[1:]:
                        self.walk(sub)
        self.walk_body(form[2:], skip_declares=False)

    handle_do_star = handle_do

    def _handle_doloop(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for sub in form[1][1:]:
                self.walk(sub)
        self.walk_body(form[2:], skip_declares=False)

    handle_dolist = _handle_doloop
    handle_dotimes = _handle_doloop

    def _handle_handler(self, form):
        if len(form) > 1:
            self.walk(form[1])
        for clause in form[2:]:
            if not isinstance(clause, list) or not clause:
                continue
            if len(clause) > 1 and isinstance(clause[1], list):
                self.walk_body(clause[2:])
            else:
                self.walk_body(clause[1:])

    handle_handler_case = _handle_handler
    handle_handler_bind = _handle_handler
    handle_restart_case = _handle_handler

    def handle_defstruct(self, form):
        for sub in form[1:]:
            if isinstance(sub, Symbol):
                continue
            if isinstance(sub, list) and sub:
                if isinstance(sub[0], Symbol):
                    for item in sub[1:]:
                        self.walk(item)
                else:
                    self.walk(sub)

    def _handle_with_stream(self, form):
        # (op (var init...) body...): var is bound, inits are code.
        # with-input-from-buffer also takes ((selected-buffer) ...) where
        # the head may itself be a call.
        if len(form) > 1 and isinstance(form[1], list):
            spec = form[1]
            if spec and isinstance(spec[0], list):
                self.walk(spec[0])
            for sub in spec[1:]:
                self.walk(sub)
        self.walk_body(form[2:])

    def _handle_with_bound_stream(self, form):
        # (op (var init...) body...): var is always bound, inits are code.
        if len(form) > 1 and isinstance(form[1], list):
            for sub in form[1][1:]:
                self.walk(sub)
        self.walk_body(form[2:])

    handle_with_output_to_string = _handle_with_bound_stream
    handle_with_input_from_string = _handle_with_bound_stream
    handle_with_open_file = _handle_with_bound_stream
    handle_with_open_stream = _handle_with_bound_stream

    handle_with_input_from_buffer = _handle_with_stream
    handle_with_output_to_buffer = _handle_with_stream
    handle_with_output_to_temp_buffer = _handle_with_stream

    def handle_selection_start_end(self, form):
        self.walk_body(form[2:])

    handle_do_symbols = _handle_doloop
    handle_do_external_symbols = _handle_doloop
    handle_do_all_symbols = _handle_doloop

    def _condition_slots(self, body):
        """Yield (slot-name, init-form-or-None) from a define-condition body."""
        if not body:
            return
        slots = body[0]
        if isinstance(slots, Symbol):
            yield slots.name, None
            rest = body[1:]
        elif isinstance(slots, list):
            rest = body[1:]
            for item in slots:
                if isinstance(item, Symbol):
                    yield item.name, None
                elif isinstance(item, list) and item and isinstance(item[0], Symbol):
                    yield item[0].name, item[1] if len(item) > 1 else None
        else:
            rest = body[1:]
        for clause in rest:
            if isinstance(clause, list) and clause and isinstance(clause[0], tuple) \
                    and clause[0][0] == "kw" and clause[0][1] == ":report":
                for sub in clause[1:]:
                    self.walk(sub)

    def handle_define_condition(self, form):
        saved = self.context
        if len(form) > 1 and isinstance(form[1], Symbol):
            self.context = form[1].name
        for _name, init in self._condition_slots(form[3:]):
            if init is not None:
                self.walk(init)
        self.context = saved

    def handle_define_modify_macro(self, form):
        if len(form) > 2 and isinstance(form[2], list):
            self.walk_lambda_list(form[2])
        if len(form) > 3:
            target = form[3]
            if isinstance(target, Symbol):
                self.record(target)
            else:
                self.walk(target)

    def handle_defsetf(self, form):
        if len(form) > 2 and isinstance(form[2], Symbol):
            self.record(form[2])
            self.walk_body(form[3:])
            return
        if len(form) > 2 and isinstance(form[2], list):
            self.walk_lambda_list(form[2])
        if len(form) > 3 and isinstance(form[3], list) \
                and all(isinstance(x, Symbol) for x in form[3]):
            self.walk_body(form[4:])
        else:
            self.walk_body(form[3:])

    def handle_define_setf_method(self, form):
        if len(form) > 2 and isinstance(form[2], list):
            self.walk_lambda_list(form[2])
        self.walk_body(form[3:])

    def handle_with_popup_window(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for sub in form[1]:
                self.walk(sub)
        self.walk_body(form[2:])

    def _handle_name_arglist_body(self, form):
        # (op name lambda-list body...): deftype, defpred, ...
        if len(form) > 2 and isinstance(form[2], list):
            self.walk_lambda_list(form[2])
        self.walk_body(form[3:])

    handle_deftype = _handle_name_arglist_body
    handle_defpred = _handle_name_arglist_body
    handle_defpred_number = _handle_name_arglist_body
    handle_defpred_vector = _handle_name_arglist_body
    handle_defpred_array = _handle_name_arglist_body

    def handle_lambda_bind(self, form):
        for sub in form[2:]:
            self.walk(sub)

    def handle_define_failure_reporter(self, form):
        if len(form) > 3 and isinstance(form[3], list):
            self.walk_lambda_list(form[3])
        self.walk_body(form[4:])

    handle_with_fake_functions = _handle_flet

    def handle_deftest(self, form):
        # (deftest name options doc code... => expected...): everything
        # after => is expected data, not code.
        saved = self.context
        if len(form) > 1 and isinstance(form[1], Symbol):
            self.context = form[1].name
        code = []
        for sub in form[2:]:
            if isinstance(sub, Symbol) and sub.name == "=>":
                break
            code.append(sub)
        self.walk_body(code)
        self.context = saved

    def handle_defvar(self, form):
        self.walk_body(form[2:])

    def handle_cond(self, form):
        for clause in form[1:]:
            if not isinstance(clause, list) or not clause:
                continue
            head = clause[0]
            if isinstance(head, Symbol):
                self.walk_body(clause[1:])
            else:
                self.walk(clause)

    def handle_case(self, form):
        if len(form) > 1:
            self.walk(form[1])
        for clause in form[2:]:
            if isinstance(clause, list):
                self.walk_body(clause[1:])
            elif isinstance(clause, tuple):
                self.walk(clause)

    handle_ecase = handle_case
    handle_ccase = handle_case
    handle_typecase = handle_case
    handle_etypecase = handle_case
    handle_ctypecase = handle_case

    handle_defconstant = handle_defvar
    handle_defparameter = handle_defvar
    handle_defvar_local = handle_defvar
    handle_define_history_variable = handle_defvar


for _alias, _target in (("defmethod", "defun"), ("defgeneric", "defun")):
    setattr(Checker, "handle_" + _alias, Checker._handle_define)


def find_undefined_functions(source, known, macro_ll=None):
    checker = Checker(known, macro_ll)
    for top in parse_source(source):
        if isinstance(top, list) and top and isinstance(top[0], Symbol):
            op = norm(top[0].name)
            if op in ("defun", "defmacro") and len(top) > 1 and isinstance(top[1], Symbol):
                checker.context = top[1].name
                checker.walk(top)
                checker.context = None
                continue
        checker.walk(top)
    return checker.findings


LISP_GLOBS = ("lisp/*.l", "unittest/*.l", "misc/*.l")


def collect_known_functions(repo_root):
    root = Path(repo_root)
    known = set()
    macro_ll = {}
    cxx = root / "src" / "gen-syms.cc"
    if cxx.exists():
        known.update(extract_cxx_functions(cxx.read_text(encoding="utf-8")))
    for pattern in LISP_GLOBS:
        for path in sorted(root.glob(pattern)):
            try:
                known.update(collect_lisp_definitions(
                    parse_source(path.read_text(encoding="utf-8")), macro_ll))
            except Exception:
                pass
    return known, macro_ll


def check_repo(repo_root, allowlist=None):
    root = Path(repo_root)
    known, macro_ll = collect_known_functions(root)
    if allowlist:
        known.update(allowlist)
    findings = []
    for pattern in LISP_GLOBS:
        for path in sorted(root.glob(pattern)):
            try:
                source = path.read_text(encoding="utf-8")
            except Exception:
                continue
            checker = Checker(known, macro_ll)
            for top in parse_source(source):
                if isinstance(top, list) and top and isinstance(top[0], Symbol):
                    op = norm(top[0].name)
                    if op in ("defun", "defmacro") and len(top) > 1 \
                            and isinstance(top[1], Symbol):
                        checker.context = top[1].name
                        checker.walk(top)
                        checker.context = None
                        continue
                checker.walk(top)
            for found in checker.findings:
                findings.append(found._replace(path=str(path.relative_to(root))))
    findings.sort(key=lambda f: (f.path, f.line))
    return findings


def load_allowlist(repo_root):
    path = Path(repo_root) / "tools" / "lisp-undefined-allowlist.txt"
    names = set()
    if not path.exists():
        return names
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        names.add(norm(line.split()[0]))
    return names


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    as_json = False
    if "--json" in argv:
        as_json = True
        argv.remove("--json")
    if len(argv) != 1:
        print("usage: check-lisp-undefined.py REPO_ROOT [--json]", file=sys.stderr)
        return 2
    findings = check_repo(argv[0], load_allowlist(argv[0]))
    if as_json:
        print(json.dumps([f._asdict() for f in findings], ensure_ascii=False, indent=2))
    elif findings:
        for found in findings:
            where = "%s:%d" % (found.path, found.line)
            if found.context:
                print("%s: undefined function `%s' (in %s)" % (where, found.name, found.context))
            else:
                print("%s: undefined function `%s'" % (where, found.name))
    else:
        print("lisp-undefined: OK")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
