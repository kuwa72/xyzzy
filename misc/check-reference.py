#!/usr/bin/env python3
"""Compare reference.xml symbols with symbols registered by Lisp and C++."""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REFERENCE = REPO_ROOT / "reference" / "reference.xml"
LISP_DIR = REPO_ROOT / "lisp"
CXX_REGISTRY = REPO_ROOT / "src" / "gen-syms.cc"

DOCUMENTED_TYPES = {
    "Accessor",
    "BufferLocal",
    "Function",
    "Keyword",
    "Macro",
    "Special Form",
    "Variable",
}

# These macros populate the symbol table in src/gen-syms.cc.  The first
# argument is the Lisp-visible name for every macro in this list.
REGISTRATION_MACROS = (
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
    "DEFCONST",
    "DEFCONST2Q",
    "DEFKWD",
    "DEFKWD2",
    "DEFVAR",
    "DEFVAR2",
    "SI_DEFVAR2",
    "CL_DEFVAR2",
)


def _strip_lisp_comments(source):
    result = []
    in_string = False
    escaped = False
    block_depth = 0
    i = 0
    while i < len(source):
        if block_depth:
            if source.startswith("#|", i):
                block_depth += 1
                result.extend("  ")
                i += 2
            elif source.startswith("|#", i):
                block_depth -= 1
                result.extend("  ")
                i += 2
            else:
                result.append("\n" if source[i] == "\n" else " ")
                i += 1
            continue
        char = source[i]
        if in_string:
            result.append("\n" if char == "\n" else " ")
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
            result.append(" ")
        elif char == ";":
            while i < len(source) and source[i] != "\n":
                result.append(" ")
                i += 1
            continue
        elif source.startswith("#|", i):
            block_depth = 1
            result.extend("  ")
            i += 2
            continue
        else:
            result.append(char)
        i += 1
    return "".join(result)


def extract_lisp_symbols(source):
    source = _strip_lisp_comments(source)
    return {
        match.group(1)
        for match in re.finditer(
            r"\((?:[A-Za-z0-9_*+-]+::)?def(?:un|macro|var)(?:-builtin(?:-\d+)?)?\s+([^\s()]+)",
            source,
            re.IGNORECASE,
        )
    }


def _strip_cxx_comments(source):
    source = re.sub(r"//[^\n]*", "", source)
    return re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)


def _strip_cxx_macro_definitions(source):
    lines = []
    skipping = False
    for line in source.splitlines(keepends=True):
        if not skipping and re.match(r"\s*#define\b", line):
            skipping = line.rstrip().endswith("\\")
            continue
        if skipping:
            skipping = line.rstrip().endswith("\\")
            continue
        lines.append(line)
    return "".join(lines)


def extract_cxx_symbols(source):
    source = _strip_cxx_macro_definitions(_strip_cxx_comments(source))
    macros = "|".join(map(re.escape, REGISTRATION_MACROS))
    symbols = set()
    for match in re.finditer(
        rf"\b({macros})\s*\(\s*(?:\"((?:\\.|[^\"])*)\"|([^,\s()]+))",
        source,
    ):
        symbol = match.group(2) or match.group(3)
        if match.group(2):
            symbol = bytes(symbol, "utf-8").decode("unicode_escape")
        symbols.add(symbol)
    return symbols


def extract_documented_symbols(path=REFERENCE):
    root = ET.parse(path).getroot()
    return {
        (chapter.findtext("title") or "").strip()
        for chapter in root.findall("chapter")
        if (chapter.findtext("type") or "").strip() in DOCUMENTED_TYPES
        and (chapter.findtext("title") or "").strip()
    }


def extract_implemented_symbols(lisp_dir=LISP_DIR, cxx_registry=CXX_REGISTRY):
    symbols = set()
    for path in sorted(Path(lisp_dir).glob("*.l")):
        symbols.update(extract_lisp_symbols(path.read_text(encoding="utf-8")))
    symbols.update(
        extract_cxx_symbols(Path(cxx_registry).read_text(encoding="utf-8"))
    )
    return symbols


def compare_symbols(documented, implemented):
    return {
        "undocumented": sorted(implemented - documented, key=str.lower),
        "missing": sorted(documented - implemented, key=str.lower),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--strict", action="store_true", help="exit 1 when either list is non-empty")
    args = parser.parse_args()

    documented = extract_documented_symbols()
    implemented = extract_implemented_symbols()
    result = compare_symbols(documented, implemented)
    result.update({"documented_count": len(documented), "implemented_count": len(implemented)})

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Documented symbols: {result['documented_count']}")
        print(f"Implemented symbols: {result['implemented_count']}")
        for heading, key in (
            ("Missing from implementation (documented only)", "missing"),
            ("Undocumented implementation symbols", "undocumented"),
        ):
            print(f"\n{heading} ({len(result[key])}):")
            print("\n".join(f"  {symbol}" for symbol in result[key]) or "  (none)")

    if args.strict and (result["missing"] or result["undocumented"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
