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

Finding = namedtuple("Finding", ("path", "line", "name", "context", "kind"))

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
                if nxt == '{':
                    # OLE dispatch syntax #{obj.Method [ args ]} (also
                    # quoted '#{...}'): one opaque atom, braces nest and
                    # strings inside do not terminate the block.
                    self._advance(2)
                    depth = 1
                    while self.pos < len(src) and depth > 0:
                        ch = src[self.pos]
                        if ch == '"':
                            self._advance()
                            while self.pos < len(src) and src[self.pos] != '"':
                                if src[self.pos] == "\\":
                                    self._advance(2)
                                else:
                                    self._advance()
                            self._advance()
                        elif ch == '{':
                            depth += 1
                            self._advance()
                        elif ch == '}':
                            depth -= 1
                            self._advance()
                        else:
                            self._advance()
                    self.tokens.append(('atom', None, line))
                elif nxt == "'":
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
                        if (
                            self.pos > 0
                            and src[self.pos - 1] == "-"
                            and self.pos < len(src)
                            and src[self.pos] not in " \t\r\n\f\v();\"`|"
                        ):
                            # Modifier prefix with a punctuation base
                            # (an escaped base like #\C-\\ takes two).
                            if src[self.pos] == "\\" \
                                    and self.pos + 1 < len(src):
                                self._advance(2)
                            else:
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
                    if re.fullmatch(r"[0-9]+", word or " ") \
                            and self.pos < len(src) \
                            and src[self.pos] in ("=", "#"):
                        # #N= labels its form (still walked as code) and
                        # #N# refers back to it; neither is a variable.
                        self._advance()
                        self.tokens.append(("atom", None, line))
                        continue
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
                while True:
                    while self.pos < len(src) and src[self.pos] not in " \t\r\n\f\v();\"`|":
                        if src[self.pos] in "'`,":
                            break
                        buf.append(src[self.pos])
                        self._advance()
                    if self.pos < len(src) and src[self.pos] == "|":
                        # A |...| span inside the symbol (:|a(b)|).
                        self._advance()
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
                        continue
                    break
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
        if re.fullmatch(r"[+-]?(\d+\.?\d*|\.\d+)([eEsSfFdDlL][+-]?\d+)?|[+-]?\d+/\d+", value):
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
            self.findings.append(
                Finding(None, sym.line, sym.name, self.context, "function"))

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




VAR_DEFINE_OPS = {
    "defvar",
    "defparameter",
    "defconstant",
    "defvar-local",
    "define-history-variable",
}

CXX_VAR_MACROS = (
    "DEFVAR",
    "DEFVAR2",
    "SI_DEFVAR2",
    "CL_DEFVAR2",
    "MAKE_SYMBOL",
    "MAKE_SYMBOL2",
    "MAKE_SYMBOL2Q",
    "MAKE_SYMBOL2QC",
    "MAKE_SYMBOL2F",
    "SI_MAKE_SYMBOL2",
    "CL_MAKE_SYMBOL2",
    "DEFCONST",
    "DEFCONST2Q",
)


def extract_cxx_variables(source):
    """Variable-namespace counterpart of extract_cxx_functions.

    DEFVAR2 family registers special variables; MAKE_SYMBOL2 family
    registers symbols with value cells (e.g. buffer-local variables
    like mode-name via MAKE_SYMBOL2F). Extra names here only risk
    false negatives, never failures.
    """
    macros = "|".join(map(re.escape, CXX_VAR_MACROS))
    found = set()
    for match in re.finditer(
        r"\b(?:" + macros + r")\s*\(\s*(?:\"((?:\\.|[^\"])*)\"|([^,\s()]+))",
        source,
    ):
        symbol = match.group(1) or match.group(2)
        if match.group(1):
            symbol = bytes(symbol, "utf-8").decode("unicode_escape")
        if symbol:
            found.add(norm(symbol))
    return found


def collect_lisp_variables(forms):
    """Collect value-namespace globals: defvar family, buffer-locals
    from (make-variable-buffer-local 'sym), and (declaim/proclaim
    (special ...)) names."""
    names = set()

    def add(name):
        if name:
            names.add(norm(name))

    def visit(form):
        if isinstance(form, tuple):
            for sub in form[1:]:
                if isinstance(sub, (list, tuple)):
                    visit(sub)
            return
        if not isinstance(form, list) or not form:
            return
        head = form[0]
        op = norm(head.name) if isinstance(head, Symbol) else None
        if op in VAR_DEFINE_OPS:
            if len(form) > 1 and isinstance(form[1], Symbol):
                add(form[1].name)
        elif op in ("make-variable-buffer-local", "make-local-variable"):
            if len(form) > 1:
                target = form[1]
                if isinstance(target, tuple) and target[0] == "quote" \
                        and isinstance(target[1], Symbol):
                    add(target[1].name)
        elif op == "boundp":
            # (or (boundp 'sym) (setq sym ...)) declares a global that
            # may legitimately be absent; (declare (special ...)) does
            # the same for dynamic bindings installed by callers.
            if len(form) > 1:
                target = form[1]
                if isinstance(target, tuple) and target[0] == "quote" \
                        and isinstance(target[1], Symbol):
                    add(target[1].name)
        elif op in ("declaim", "proclaim", "declare"):
            for spec in form[1:]:
                if isinstance(spec, list) and spec \
                        and isinstance(spec[0], Symbol) \
                        and norm(spec[0].name) == "special":
                    for item in spec[1:]:
                        if isinstance(item, Symbol):
                            add(item.name)
        for sub in form:
            if isinstance(sub, (list, tuple)):
                visit(sub)

    for top in forms:
        visit(top)
    return names


class VarChecker:
    """Detect references to variables that are declared nowhere.

    Globals come from the repo-wide pre-pass (defvar family, C++
    DEFVAR/MAKE_SYMBOL, buffer-locals); lexical bindings (let, lambda
    lists, do, dolist, loop, ...) are tracked in a scope stack.
    Operator positions are never value references -- that half belongs
    to Checker.
    """

    MARKERS = Checker.MARKERS

    LOOP_KEYWORDS = frozenset((
        "for", "as", "with", "into", "named",
        "and", "do", "doing", "if", "when", "unless",
        "while", "until", "repeat",
        "collect", "collecting", "append", "appending",
        "nconc", "nconcing", "count", "counting",
        "sum", "summing", "maximize", "maximizing",
        "minimize", "minimizing", "always", "never", "thereis",
        "initially", "finally", "return", "end",
        "from", "to", "upto", "above", "below", "by",
        "in", "on", "across", "being", "each", "the",
        "of-type", "=", "then", "else",
    ))

    def __init__(self, known, macro_ll=None):
        self.known = set(known)
        self.macro_ll = macro_ll or {}
        self.scopes = []
        self.findings = []
        self.context = None

    def push(self):
        scope = set()
        self.scopes.append(scope)
        return scope

    def pop(self):
        self.scopes.pop()

    def bound(self, name):
        key = norm(name)
        return any(key in scope for scope in self.scopes)

    def is_known_var(self, name):
        key = norm(name)
        if key in self.known:
            return True
        return self.bound(name)

    def ref(self, sym):
        name = sym.name
        if name in ("t", "nil", ".", ""):
            return
        if name.startswith("#+") or name.startswith("#-"):
            return
        if not self.is_known_var(name):
            self.findings.append(
                Finding(None, sym.line, sym.name, self.context, "variable"))

    def walk(self, form):
        if isinstance(form, Symbol):
            self.ref(form)
            return
        if isinstance(form, tuple):
            tag = form[0]
            if tag in ("quote", "function"):
                return
            if tag in ("unquote", "unquote-splicing"):
                self.walk(form[1])
                return
            if tag in ("backquote", "vector"):
                self.walk_template(form[1])
                return
            return
        if not isinstance(form, list) or not form:
            return
        head = form[0]
        if isinstance(head, list):
            if head and isinstance(head[0], Symbol) \
                    and norm(head[0].name) == "lambda":
                self.handle_lambda_call(head, form[1:])
                return
            self.walk(head)
            for sub in form[1:]:
                self.walk(sub)
            return
        if not isinstance(head, Symbol):
            for sub in form:
                self.walk(sub)
            return
        op = norm(head.name)
        # NOTE: the "*" is stripped by the mangling below, so let*/do*
        # would land on the non-sequential handlers. Dispatch first.
        if op == "let*":
            self._handle_let(form, True)
            return
        if op == "do*":
            self.handle_do_star(form)
            return
        handler = getattr(self, "handle_" + op.replace("-", "_").replace("*", ""), None)
        if handler is not None:
            handler(form)
            return
        if op in SKIP_FORMS:
            return
        table = self.macro_ll.get(op)
        if table is None:
            for sub in form[1:]:
                self.walk(sub)
        else:
            self.walk_macro_args(table, form[1:])

    def walk_body(self, forms):
        for sub in forms:
            if isinstance(sub, list) and sub and isinstance(sub[0], Symbol) \
                    and norm(sub[0].name) == "declare":
                continue
            self.walk(sub)

    def walk_template(self, form, depth=1):
        # Refs unquoted at depth 1 see the current scope (macro args).
        # Deeper unquotes run in expansion-generated scopes (e.g. the
        # store variable of a generated defsetf) and are not checked.
        if isinstance(form, Symbol):
            return
        if isinstance(form, tuple):
            tag = form[0]
            if tag in ("unquote", "unquote-splicing"):
                if depth <= 1:
                    self.walk(form[1])
                return
            if tag in ("backquote", "vector"):
                self.walk_template(form[1], depth + 1)
                return
            return
        if isinstance(form, list):
            for sub in form:
                self.walk_template(sub, depth)

    def walk_ll_items(self, items, scope, section=None, walk_inits=True):
        """Bind a lambda-list, walking init-forms in the current scope.

        Params bind left to right so later inits see earlier params.
        """
        skip_next = False
        bind_rest = False
        for el in items:
            if isinstance(el, Symbol):
                name = norm(el.name)
                if name in ("&whole", "&environment"):
                    # The whole form / environment object IS bound here.
                    skip_next = True
                    continue
                if name in ("&rest", "&body"):
                    bind_rest = True
                    section = None
                    continue
                if name.startswith("&"):
                    section = name
                    bind_rest = False
                    continue
                if skip_next:
                    skip_next = False
                    scope.add(name)
                    continue
                if bind_rest:
                    scope.add(name)
                    bind_rest = False
                    continue
                scope.add(name)
            elif isinstance(el, list):
                if skip_next:
                    self.bind_pattern(el, scope)
                    skip_next = False
                elif bind_rest:
                    self.bind_pattern(el, scope)
                    bind_rest = False
                elif section is None:
                    self.bind_pattern(el, scope, walk_inits)
                else:
                    self.walk_opt_spec(el, scope, walk_inits)
            else:
                skip_next = False
                bind_rest = False

    def bind_pattern(self, pattern, scope, walk_inits=True):
        """Bind every variable in a destructuring pattern."""
        if isinstance(pattern, Symbol):
            name = norm(pattern.name)
            if not pattern.name.startswith("&") and name not in ("t", "nil"):
                scope.add(name)
            return
        if isinstance(pattern, list):
            self.walk_ll_items(pattern, scope, None, walk_inits)

    def walk_opt_spec(self, spec, scope, walk_inits=True):
        """A (var [init [svar]]) spec: walk init, then bind var+svar."""
        if not spec:
            return
        first = spec[0]
        if isinstance(first, Symbol) and first.name.startswith("&"):
            self.walk_ll_items(spec, scope)
            return
        if len(spec) > 1 and walk_inits:
            self.walk(spec[1])
        if isinstance(first, Symbol):
            name = norm(first.name)
            if name not in ("t", "nil"):
                scope.add(name)
        elif isinstance(first, list):
            self.bind_pattern(first, scope)
        if len(spec) > 2 and isinstance(spec[2], Symbol):
            scope.add(norm(spec[2].name))

    def walk_macro_args(self, params, args):
        """Value-side mirror of Checker.walk_macro_args.

        Required Symbol params are evaluated (walk); required list
        patterns bind their head name and walk the value positions.
        The whole call gets one scope so &body forms see the bound names.
        """
        scope = self.push()
        try:
            self._walk_macro_args(params, args)
        finally:
            self.pop()

    def _walk_macro_args(self, params, args):
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
                        if isinstance(params[j], Symbol):
                            self.bind_symbol(params[j])
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
                            self.walk_var_structure(arg, rest)
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
                if i < len(args):
                    self.walk_var_structure(args[i], param)
                    i += 1
                j += 1
            else:
                j += 1
        for arg in args[i:]:
            self.walk(arg)

    def walk_var_structure(self, arg, pattern):
        """Walk a macro argument against a binding pattern.

        The pattern head names the binding (bind a Symbol argument);
        remaining positions hold evaluated values (walk them).
        """
        if not isinstance(pattern, list):
            return
        items = list(arg) if isinstance(arg, list) else None
        if items is None:
            if isinstance(arg, Symbol):
                self.ref(arg)
            else:
                self.walk(arg)
            return
        k = 0
        m = 0
        section = None
        first = True
        while m < len(pattern):
            pat = pattern[m]
            if isinstance(pat, Symbol):
                name = norm(pat.name)
                if name in ("&whole", "&environment"):
                    m += 1
                    if m < len(pattern) and not (
                            isinstance(pattern[m], Symbol)
                            and norm(pattern[m].name) in self.MARKERS):
                        if isinstance(pattern[m], Symbol):
                            self.bind_symbol(pattern[m])
                        m += 1
                    first = False
                    continue
                if name in ("&rest", "&body"):
                    m += 1
                    rest = pattern[m] if m < len(pattern) else None
                    if isinstance(rest, Symbol):
                        for item in items[k:]:
                            self.walk(item)
                    elif isinstance(rest, list):
                        for item in items[k:]:
                            self.walk_var_structure(item, rest)
                    else:
                        for item in items[k:]:
                            self.walk(item)
                    k = len(items)
                    if m < len(pattern):
                        m += 1
                    first = False
                    continue
                if name in self.MARKERS:
                    section = name
                    m += 1
                    first = False
                    continue
                if k < len(items):
                    item = items[k]
                    if section is None and first and isinstance(item, Symbol):
                        self.bind_symbol(item)
                    else:
                        self.walk(item)
                    k += 1
                m += 1
            elif isinstance(pat, list):
                if k < len(items):
                    if section is None:
                        self.walk_var_structure(items[k], pat)
                    else:
                        self.walk_spec_call(items[k], pat)
                    k += 1
                m += 1
            else:
                m += 1
            first = False

    def walk_spec_call(self, arg, spec):
        if not spec:
            return
        head = spec[0]
        if isinstance(head, list):
            self.walk_var_structure(arg, head)
        else:
            self.walk(arg)

    def bind_symbol(self, sym):
        if sym.name not in ("t", "nil"):
            self.scopes[-1].add(norm(sym.name))

    def _with_scope(self, names=()):
        scope = self.push()
        for name in names:
            scope.add(norm(name))
        return scope

    def _handle_define(self, form):
        """Skip leading name symbols, bind the first list as a
        lambda-list, walk the rest as body."""
        rest = form[1:]
        while rest and isinstance(rest[0], Symbol):
            rest = rest[1:]
        if rest and isinstance(rest[0], list):
            scope = self.push()
            try:
                self.walk_ll_items(rest[0], scope)
                self.walk_body(rest[1:])
            finally:
                self.pop()
        else:
            self.walk_body(rest)

    handle_defun = _handle_define
    handle_defmacro = _handle_define
    handle_defsubst = _handle_define
    handle_defun_builtin = _handle_define
    handle_defmacro_builtin = _handle_define
    handle_defmethod = _handle_define
    handle_defgeneric = _handle_define
    handle_deftype = _handle_define
    handle_define_setf_method = _handle_define

    def handle_define_modify_macro(self, form):
        # (define-modify-macro name ll fn &optional doc): fn names a
        # function, so only the lambda-list binds and the doc runs.
        if len(form) > 2 and isinstance(form[2], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[2], scope)
                self.walk_body(form[4:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_defun_c_callable(self, form):
        # (c:defun-c-callable rettype (name opts...) (args...) &body
        # body): args are (ctype var); typenames never evaluate.
        args = form[3] if len(form) > 3 and isinstance(form[3], list) else None
        body = form[4:] if args is not None else form[1:]
        scope = self.push()
        try:
            if isinstance(args, list):
                for spec in args:
                    if isinstance(spec, list) and len(spec) > 1 \
                            and isinstance(spec[-1], Symbol):
                        if spec[-1].name not in ("t", "nil"):
                            scope.add(norm(spec[-1].name))
                    elif isinstance(spec, Symbol):
                        self.ref(spec)
            self.walk_body(body)
        finally:
            self.pop()

    def handle_lambda(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[1], scope)
                self.walk_body(form[2:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_lambda_call(self, lambda_form, args):
        for arg in args:
            self.walk(arg)
        scope = self.push()
        try:
            if len(lambda_form) > 1 and isinstance(lambda_form[1], list):
                self.walk_ll_items(lambda_form[1], scope)
            self.walk_body(lambda_form[2:])
        finally:
            self.pop()

    def _handle_let(self, form, sequential):
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else []
        body = form[2:]

        def bind_spec(spec, scope):
            if isinstance(spec, Symbol):
                if spec.name not in ("t", "nil"):
                    scope.add(norm(spec.name))
            elif isinstance(spec, list) and spec:
                if isinstance(spec[0], Symbol):
                    if spec[0].name not in ("t", "nil"):
                        scope.add(norm(spec[0].name))
                else:
                    self.bind_pattern(spec[0], scope)

        if sequential:
            scope = self.push()
            try:
                for spec in specs:
                    if isinstance(spec, list) and len(spec) > 1:
                        self.walk(spec[1])
                    bind_spec(spec, scope)
                self.walk_body(body)
            finally:
                self.pop()
        else:
            for spec in specs:
                if isinstance(spec, list) and len(spec) > 1:
                    self.walk(spec[1])
            scope = self.push()
            try:
                for spec in specs:
                    bind_spec(spec, scope)
                self.walk_body(body)
            finally:
                self.pop()

    def handle_let(self, form):
        self._handle_let(form, False)

    def handle_let_star(self, form):
        self._handle_let(form, True)

    handle_compiler_let = handle_let_star

    def _handle_flet(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for spec in form[1]:
                if not isinstance(spec, list) or len(spec) < 2:
                    continue
                if isinstance(spec[1], list):
                    self.walk_ll_items(spec[1], set())
                scope = self.push()
                try:
                    if isinstance(spec[1], list):
                        self.walk_ll_items(spec[1], scope, walk_inits=False)
                    if len(spec) > 2:
                        self.walk_body(spec[2:])
                finally:
                    self.pop()
        self.walk_body(form[2:])

    handle_flet = _handle_flet
    handle_labels = _handle_flet
    def handle_macrolet(self, form):
        # Macro arguments never evaluate at the call site, and local
        # macros mostly quote theirs (test scaffolding); check the
        # expansions with params bound, skip the call-site arguments.
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else []
        names = set()
        for spec in specs:
            if isinstance(spec, list) and len(spec) > 2 \
                    and isinstance(spec[0], Symbol) \
                    and isinstance(spec[1], list):
                names.add(norm(spec[0].name))
                scope = self.push()
                try:
                    self.walk_ll_items(spec[1], scope)
                    self.walk_body(spec[2:])
                finally:
                    self.pop()
        for sub in form[2:]:
            if isinstance(sub, list) and sub and isinstance(sub[0], Symbol) \
                    and norm(sub[0].name) in names:
                continue
            self.walk(sub)

    def handle_multiple_value_bind(self, form):
        if len(form) > 2 and isinstance(form[1], list):
            self.walk(form[2])
            scope = self.push()
            try:
                for var in form[1]:
                    if isinstance(var, Symbol) and var.name not in ("t", "nil"):
                        scope.add(norm(var.name))
                self.walk_body(form[3:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_destructuring_bind(self, form):
        if len(form) > 2 and isinstance(form[1], list):
            self.walk(form[2])
            scope = self.push()
            try:
                self.bind_pattern(form[1], scope)
                self.walk_body(form[3:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def _handle_setq(self, form):
        items = form[1:]
        i = 0
        while i + 1 < len(items):
            target = items[i]
            if isinstance(target, Symbol):
                self.ref(target)
            else:
                self.walk(target)
            self.walk(items[i + 1])
            i += 2
        for extra in items[i:]:
            self.walk(extra)

    handle_setq = _handle_setq
    handle_psetq = _handle_setq

    def handle_multiple_value_setq(self, form):
        if len(form) > 2 and isinstance(form[1], list):
            self.walk(form[2])
            for var in form[1]:
                if isinstance(var, Symbol):
                    self.ref(var)
                else:
                    self.walk(var)
            self.walk_body(form[3:])
        else:
            self.walk_body(form[1:])

    def handle_defsetf(self, form):
        # Short form names functions only. Long form
        # (access ll (stores) &body body) binds ll and stores.
        if len(form) > 3 and isinstance(form[1], Symbol) \
                and isinstance(form[2], list) and isinstance(form[3], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[2], scope)
                for store in form[3]:
                    if isinstance(store, Symbol) and store.name not in ("t", "nil"):
                        scope.add(norm(store.name))
                self.walk_body(form[4:])
            finally:
                self.pop()
        return

    def handle_setf(self, form):
        items = form[1:]
        i = 0
        while i + 1 < len(items):
            self.check_place(items[i])
            self.walk(items[i + 1])
            i += 2
        for extra in items[i:]:
            self.walk(extra)

    def check_place(self, place):
        if isinstance(place, Symbol):
            self.ref(place)
        elif isinstance(place, list) and place and isinstance(place[0], Symbol) \
                and norm(place[0].name) == "values":
            for var in place[1:]:
                if isinstance(var, Symbol):
                    self.ref(var)
                else:
                    self.walk(var)
        else:
            self.walk(place)

    def _handle_place_first(self, form):
        if len(form) > 1:
            self.check_place(form[1])
        for sub in form[2:]:
            self.walk(sub)

    handle_incf = _handle_place_first
    handle_decf = _handle_place_first
    handle_pop = _handle_place_first
    handle_pushnew = _handle_place_first
    handle_remf = _handle_place_first
    handle_rotatef = _handle_place_first
    handle_shiftf = _handle_place_first

    def handle_push(self, form):
        if len(form) > 1:
            self.walk(form[1])
        if len(form) > 2:
            self.check_place(form[2])
        for sub in form[3:]:
            self.walk(sub)

    def handle_assert(self, form):
        if len(form) > 1:
            self.walk(form[1])
        if len(form) > 2 and isinstance(form[2], list):
            for place in form[2]:
                self.check_place(place)
        for sub in form[3:]:
            self.walk(sub)

    def handle_check_type(self, form):
        if len(form) > 1:
            self.check_place(form[1])
        for sub in form[3:]:
            self.walk(sub)

    def handle_defvar(self, form):
        self.walk_body(form[2:])

    handle_defparameter = handle_defvar
    handle_defconstant = handle_defvar
    handle_defvar_local = handle_defvar
    handle_define_history_variable = handle_defvar

    def handle_declare(self, form):
        return

    handle_declaim = handle_declare
    handle_proclaim = handle_declare

    def handle_quote(self, form):
        return

    handle_function = handle_quote

    def handle_backquote(self, form):
        if len(form) > 1:
            self.walk_template(form[1])

    def handle_unquote(self, form):
        if len(form) > 1:
            self.walk(form[1])

    handle_unquote_splicing = handle_unquote

    def handle_the(self, form):
        if len(form) > 1 and isinstance(form[1], Symbol):
            self.walk_body(form[2:])
        else:
            self.walk_body(form[1:])

    def handle_block(self, form):
        self.walk_body(form[2:])

    def handle_return_from(self, form):
        self.walk_body(form[2:])

    def handle_go(self, form):
        return

    def handle_tagbody(self, form):
        for sub in form[1:]:
            if isinstance(sub, Symbol):
                continue
            if isinstance(sub, tuple) and sub[0] in ("num", "str", "kw", "atom"):
                continue
            self.walk(sub)

    def handle_throw(self, form):
        self.walk_body(form[1:])

    handle_catch = handle_throw
    handle_unwind_protect = handle_throw
    handle_progn = handle_throw
    handle_progl = handle_throw
    handle_prog2 = handle_throw
    handle_locally = handle_throw
    handle_time = handle_throw

    def handle_eval_when(self, form):
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

    def handle_do(self, form):
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else []
        rest = form[2:]
        for spec in specs:
            if isinstance(spec, list) and len(spec) > 1:
                self.walk(spec[1])
        scope = self.push()
        try:
            for spec in specs:
                if isinstance(spec, Symbol):
                    if spec.name not in ("t", "nil"):
                        scope.add(norm(spec.name))
                elif isinstance(spec, list) and spec \
                        and isinstance(spec[0], Symbol):
                    if spec[0].name not in ("t", "nil"):
                        scope.add(norm(spec[0].name))
            for spec in specs:
                if isinstance(spec, list):
                    for step in spec[2:]:
                        self.walk(step)
            self.walk_body(rest)
        finally:
            self.pop()

    def handle_do_star(self, form):
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else []
        rest = form[2:]
        scope = self.push()
        try:
            for spec in specs:
                if isinstance(spec, list) and len(spec) > 1:
                    self.walk(spec[1])
                if isinstance(spec, Symbol):
                    if spec.name not in ("t", "nil"):
                        scope.add(norm(spec.name))
                elif isinstance(spec, list) and spec \
                        and isinstance(spec[0], Symbol):
                    if spec[0].name not in ("t", "nil"):
                        scope.add(norm(spec[0].name))
            for spec in specs:
                if isinstance(spec, list):
                    for step in spec[2:]:
                        self.walk(step)
            self.walk_body(rest)
        finally:
            self.pop()

    def _handle_doloop(self, form):
        """((var [value [result]]) &body body): value is outer, the
        rest sees var. Covers dolist, dotimes, do-symbols,
        with-open-file, with-output-to-string, ..."""
        specs = form[1] if len(form) > 1 and isinstance(form[1], list) else None
        body = form[2:]
        if not specs:
            self.walk_body(body)
            return
        if isinstance(specs, Symbol):
            self.walk(specs)
            self.walk_body(body)
            return
        if specs and not isinstance(specs[0], list):
            specs = [specs]
        if specs and isinstance(specs[0], list) and len(specs[0]) > 1:
            self.walk(specs[0][1])
        scope = self.push()
        try:
            if specs and isinstance(specs[0], list) and specs[0]:
                first = specs[0][0]
                if isinstance(first, Symbol):
                    if first.name not in ("t", "nil"):
                        scope.add(norm(first.name))
                else:
                    self.bind_pattern(first, scope)
            self.walk_body(body)
        finally:
            self.pop()

    handle_dolist = _handle_doloop
    handle_dotimes = _handle_doloop
    handle_do_symbols = _handle_doloop
    handle_do_external_symbols = _handle_doloop
    handle_do_all_symbols = _handle_doloop
    handle_with_open_file = _handle_doloop
    handle_with_output_to_string = _handle_doloop
    handle_with_open_stream = _handle_doloop
    handle_with_input_from_string = _handle_doloop
    handle_print_unreadable_object = _handle_doloop

    def _handle_handler(self, form):
        if len(form) > 1:
            self.walk(form[1])
        for clause in form[2:]:
            if not isinstance(clause, list) or not clause:
                continue
            if len(clause) > 1 and isinstance(clause[1], list):
                scope = self.push()
                try:
                    self.walk_ll_items(clause[1], scope)
                    self.walk_body(clause[2:])
                finally:
                    self.pop()
            elif len(clause) > 1 and isinstance(clause[1], Symbol):
                scope = self.push()
                try:
                    if clause[1].name not in ("t", "nil"):
                        scope.add(norm(clause[1].name))
                    self.walk_body(clause[2:])
                finally:
                    self.pop()
            else:
                self.walk_body(clause[1:])

    handle_handler_case = _handle_handler
    handle_handler_bind = _handle_handler
    handle_restart_case = _handle_handler
    handle_restart_bind = _handle_handler

    def handle_symbol_macrolet(self, form):
        if len(form) > 1 and isinstance(form[1], list):
            for spec in form[1]:
                if isinstance(spec, list) and len(spec) > 1:
                    self.walk(spec[1])
        scope = self.push()
        try:
            if len(form) > 1 and isinstance(form[1], list):
                for spec in form[1]:
                    if isinstance(spec, list) and spec \
                            and isinstance(spec[0], Symbol):
                        scope.add(norm(spec[0].name))
            self.walk_body(form[2:])
        finally:
            self.pop()

    def _handle_with_slots(self, form):
        if len(form) > 2:
            self.walk(form[2])
        scope = self.push()
        try:
            if len(form) > 1 and isinstance(form[1], list):
                for entry in form[1]:
                    if isinstance(entry, Symbol):
                        scope.add(norm(entry.name))
                    elif isinstance(entry, list) and entry \
                            and isinstance(entry[0], Symbol):
                        scope.add(norm(entry[0].name))
            self.walk_body(form[3:])
        finally:
            self.pop()

    handle_with_slots = _handle_with_slots
    handle_with_accessors = _handle_with_slots

    def handle_define_dll_entry(self, form):
        # FFI spec only (return type, names, arg types): no runtime code
        # in operand position. c:define-dll-entry shares the handler via
        # package-insensitive matching, *define-dll-entry via mangling.
        return

    handle_define_c_struct = handle_define_dll_entry

    handle_with_fake_functions = _handle_flet
    handle_with_fake_formatter = _handle_doloop

    def handle_selection_start_end(self, form):
        # (selection-start-end (start end) &body body)
        scope = self.push()
        try:
            if len(form) > 1 and isinstance(form[1], list):
                for var in form[1]:
                    if isinstance(var, Symbol) and var.name not in ("t", "nil"):
                        scope.add(norm(var.name))
            self.walk_body(form[2:])
        finally:
            self.pop()

    def _handle_bind_first_vars(self, form):
        # ((var...) &body body): with-temp-files, with-temp-dirs,
        # with-directory-test-dirs, ...
        scope = self.push()
        try:
            if len(form) > 1 and isinstance(form[1], list):
                for var in form[1]:
                    if isinstance(var, Symbol):
                        if var.name not in ("t", "nil"):
                            scope.add(norm(var.name))
                    elif isinstance(var, list):
                        self.bind_pattern(var, scope)
            self.walk_body(form[2:])
        finally:
            self.pop()

    handle_with_temp_files = _handle_bind_first_vars
    handle_with_temp_dirs = _handle_bind_first_vars
    handle_with_directory_test_dirs = _handle_bind_first_vars

    def handle_lambda_bind(self, form):
        # (lambda-bind lambda-list value &body body)
        if len(form) > 2 and isinstance(form[1], list):
            self.walk(form[2])
            scope = self.push()
            try:
                self.walk_ll_items(form[1], scope)
                self.walk_body(form[3:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_define_failure_reporter(self, form):
        # (define-failure-reporter kind name (args...) &body body)
        if len(form) > 3 and isinstance(form[3], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[3], scope)
                self.walk_body(form[4:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_defpred(self, form):
        # (defpred name lambda-list &body body)
        if len(form) > 2 and isinstance(form[2], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[2], scope)
                self.walk_body(form[3:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def _handle_skip_all(self, form):
        # Every argument names something (a type, a function, a quoted
        # declaration); nothing here evaluates.
        return

    handle_defpred_number = _handle_skip_all
    handle_defpred_vector = _handle_skip_all
    handle_defpred_array = _handle_skip_all
    handle_calc_assoc_left = _handle_skip_all
    handle_calc_assoc_right = _handle_skip_all
    handle_c_size_of = _handle_skip_all
    handle_c_struct_size_of = _handle_skip_all
    handle_define_c_type = _handle_skip_all
    handle__define_c_type = _handle_skip_all

    def handle_define_benchmark(self, form):
        # (define-benchmark name ll &body body)
        if len(form) > 2 and isinstance(form[2], list):
            scope = self.push()
            try:
                self.walk_ll_items(form[2], scope)
                self.walk_body(form[3:])
            finally:
                self.pop()
        else:
            self.walk_body(form[1:])

    def handle_deftest_prompt_checks_string(self, form):
        # (deftest-prompt-checks-string name form): name defines a test.
        self.walk_body(form[2:])

    TEST_MARKERS = frozenset(("=>", "!!", "==", ">>"))

    @staticmethod
    def _starts_on_line(el, line):
        while isinstance(el, list) and el:
            el = el[0]
        if isinstance(el, Symbol):
            return el.line == line
        if isinstance(el, tuple):
            if el[0] == "atom":
                return len(el) == 2 and el[1] == line
            return len(el) == 3 and el[2] == line
        return False

    def handle_deftest(self, form):
        # (deftest name [doc] [options] FORM [marker DATUM] ...):
        # only FORMs run; markers and their data never evaluate.
        # Options (e.g. (:compare equalp)) name functions, not values.
        # A >> marker consumes the rest of its line as output text
        # (the test readtable reads it as a string).
        ops = form[1:]
        i = 0
        if i < len(ops) and isinstance(ops[i], Symbol):
            i += 1
        if i < len(ops) and isinstance(ops[i], tuple) and ops[i][0] == "str":
            i += 1
        if i < len(ops) and isinstance(ops[i], list) and ops[i] \
                and isinstance(ops[i][0], tuple) and ops[i][0][0] == "kw":
            i += 1
        while i < len(ops):
            el = ops[i]
            if isinstance(el, Symbol) and el.name in self.TEST_MARKERS:
                if el.name == ">>":
                    mark = el.line
                    i += 1
                    while i < len(ops) and self._starts_on_line(ops[i], mark):
                        i += 1
                else:
                    i += 2
                continue
            self.walk(el)
            i += 1

    def handle_loop(self, form):
        scope = self.push()
        try:
            scope.add("it")
            items = form[1:]
            i = 0
            expect_bind = False
            while i < len(items):
                el = items[i]
                if isinstance(el, Symbol):
                    name = norm(el.name)
                    if name in ("for", "as"):
                        expect_bind = True
                    elif name == "with":
                        nxt = items[i + 1] if i + 1 < len(items) else None
                        if isinstance(nxt, Symbol) \
                                and norm(nxt.name) not in self.LOOP_KEYWORDS:
                            scope.add(norm(nxt.name))
                            i += 1
                            if i + 1 < len(items) \
                                    and isinstance(items[i + 1], Symbol) \
                                    and items[i + 1].name == "=":
                                i += 2
                                if i < len(items):
                                    self.walk(items[i])
                        elif isinstance(nxt, list):
                            self.bind_pattern(nxt, scope)
                            i += 1
                    elif name == "into":
                        nxt = items[i + 1] if i + 1 < len(items) else None
                        if isinstance(nxt, Symbol):
                            scope.add(norm(nxt.name))
                            i += 1
                    elif name == "named":
                        nxt = items[i + 1] if i + 1 < len(items) else None
                        if isinstance(nxt, Symbol):
                            i += 1
                    elif expect_bind:
                        scope.add(name)
                        expect_bind = False
                    elif name in self.LOOP_KEYWORDS:
                        pass
                    else:
                        self.walk(el)
                elif isinstance(el, list):
                    if expect_bind:
                        self.bind_pattern(el, scope)
                        expect_bind = False
                    else:
                        self.walk(el)
                else:
                    self.walk(el)
                i += 1
        finally:
            self.pop()

    def handle_defstruct(self, form):
        rest = form[1:]
        if rest and isinstance(rest[0], (Symbol, list)):
            rest = rest[1:]
        for slot in rest:
            if isinstance(slot, list) and len(slot) > 1:
                self.walk(slot[1])

    def handle_define_condition(self, form):
        # Slot specs are quoted data (names and default values); only
        # :report holds code.
        for spec in form[1:]:
            if isinstance(spec, list) and spec and isinstance(spec[0], tuple) \
                    and spec[0][0] == "kw" and spec[0][1] == ":report":
                for sub in spec[1:]:
                    self.walk(sub)

    def handle_defclass(self, form):
        if len(form) > 3 and isinstance(form[3], list):
            for slot in form[3]:
                if not isinstance(slot, list):
                    continue
                j = 0
                while j < len(slot):
                    item = slot[j]
                    if isinstance(item, tuple) and item[0] == "kw" \
                            and item[1] == ":initform" and j + 1 < len(slot):
                        self.walk(slot[j + 1])
                        j += 2
                    else:
                        j += 1


def find_undefined_variables(source, known, macro_ll=None):
    """Walk value positions, tracking lexical scope; report bare
    symbols and setq targets that resolve to no declaration."""
    checker = VarChecker(set(known), macro_ll)
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
    return checker.findings


def collect_known_variables(repo_root):
    root = Path(repo_root)
    known = set()
    cxx = root / "src" / "gen-syms.cc"
    if cxx.exists():
        known.update(extract_cxx_variables(cxx.read_text(encoding="utf-8")))
    for pattern in LISP_GLOBS:
        for path in sorted(root.glob(pattern)):
            try:
                known.update(collect_lisp_variables(
                    parse_source(path.read_text(encoding="utf-8"))))
            except Exception:
                pass
    return known


def check_repo_vars(repo_root, allowlist=None):
    root = Path(repo_root)
    _, macro_ll = collect_known_functions(root)
    vknown = collect_known_variables(root)
    if allowlist:
        vknown.update(allowlist)
    findings = []
    for pattern in LISP_GLOBS:
        for path in sorted(root.glob(pattern)):
            try:
                source = path.read_text(encoding="utf-8")
            except Exception:
                continue
            checker = VarChecker(vknown, macro_ll)
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


def load_vars_allowlist(repo_root):
    path = Path(repo_root) / "tools" / "lisp-undefined-vars-allowlist.txt"
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
    findings += check_repo_vars(argv[0], load_vars_allowlist(argv[0]))
    if as_json:
        print(json.dumps([f._asdict() for f in findings], ensure_ascii=False, indent=2))
    elif findings:
        for found in findings:
            where = "%s:%d" % (found.path, found.line)
            if found.kind == "variable":
                if found.context:
                    print("%s: undefined variable `%s' (in %s)" % (where, found.name, found.context))
                else:
                    print("%s: undefined variable `%s'" % (where, found.name))
            elif found.context:
                print("%s: undefined function `%s' (in %s)" % (where, found.name, found.context))
            else:
                print("%s: undefined function `%s'" % (where, found.name))
    else:
        print("lisp-undefined: OK")
    return 1 if findings else 0




if __name__ == "__main__":
    sys.exit(main())
