#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""reference/reference.xml から Claude Code Skill 用の参照ファイルを生成する。

出力:
  .claude/skills/xyzzy-lisp/references/index.tsv   全シンボルの索引 (grep 用)
  .claude/skills/xyzzy-lisp/references/<slug>.md   セクションごとの本文

使い方:
  python3 misc/gen-reference-skill.py
  python3 misc/gen-reference-skill.py --check   # 差分があれば exit 1 (CI 用)
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE = REPO_ROOT / "reference" / "reference.xml"
OUTDIR = REPO_ROOT / ".claude" / "skills" / "xyzzy-lisp" / "references"

# reference.xml の <section> は日本語なので、ファイル名用の ASCII スラグに対応づける。
# 新しいセクションが増えたらここに足す (未知のセクションは生成時にエラーで知らせる)。
SECTION_SLUGS = {
    "データ型": "datatypes",
    "変数と定数": "variables",
    "制御構造": "control-flow",
    "パッケージ": "packages",
    "関数": "functions",
    "マクロ": "macros",
    "シンボル": "symbols",
    "数値": "numbers",
    "文字": "characters",
    "文字列": "strings",
    "シーケンス": "sequences",
    "リスト": "lists",
    "配列": "arrays",
    "ハッシュ": "hashtables",
    "評価": "evaluation",
    "エラー": "errors",
    "入出力": "io",
    "ファイルシステム": "filesystem",
    "プロセス": "processes",
    "システム": "system",
    "日付・時間": "datetime",
    "バッファ": "buffers",
    "ウィンドウ": "windows",
    "フレーム": "frames",
    "ポジション": "positions",
    "リージョン": "regions",
    "テキスト": "text",
    "検索・正規表現": "search-regexp",
    "シンタックス": "syntax",
    "キーマップ": "keymaps",
    "モード": "modes",
    "ミニバッファ": "minibuffer",
    "メニュー": "menus",
    "ダイアログ": "dialogs",
    "ファイラ": "filer",
    "チャンク": "chunks",
    "その他": "misc",
}


def text_of(chapter, tag):
    node = chapter.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def all_text_of(chapter, tag):
    return [n.text.strip() for n in chapter.findall(tag) if n.text and n.text.strip()]


def one_line(s):
    """索引に載せるためタブ・改行を潰す。"""
    return re.sub(r"\s+", " ", s).strip()


def parse():
    chapters = ET.parse(SOURCE).getroot().findall("chapter")
    entries = []
    unknown = set()
    for ch in chapters:
        section = text_of(ch, "section")
        if section not in SECTION_SLUGS:
            unknown.add(section)
            continue
        entries.append(
            {
                "name": text_of(ch, "title"),
                "type": text_of(ch, "type"),
                "arguments": text_of(ch, "arguments"),
                "package": text_of(ch, "package"),
                "description": text_of(ch, "description"),
                "seealso": all_text_of(ch, "seealso"),
                "link": all_text_of(ch, "link"),
                "section": section,
                "slug": SECTION_SLUGS[section],
                "file": text_of(ch, "file"),
            }
        )
    if unknown:
        sys.exit(
            "未知の <section> があります。SECTION_SLUGS に追加してください: "
            + ", ".join(sorted(unknown))
        )
    return entries


def render_index(entries):
    lines = ["# name\ttype\tpackage\tsection\targuments"]
    for e in sorted(entries, key=lambda e: (e["name"].lower(), e["name"])):
        lines.append(
            "\t".join(
                [
                    e["name"],
                    e["type"],
                    e["package"] or "-",
                    e["slug"],
                    one_line(e["arguments"]) or "-",
                ]
            )
        )
    return "\n".join(lines) + "\n"


def render_section(section, slug, entries):
    out = [
        f"# {section} ({slug})",
        "",
        f"reference/reference.xml から自動生成。{len(entries)} エントリ。",
        "編集しないこと — 直すなら reference/reference.xml を直して再生成する。",
        "",
    ]
    for e in sorted(entries, key=lambda e: (e["name"].lower(), e["name"])):
        out.append(f"## `{e['name']}`")
        out.append("")
        meta = [e["type"]]
        if e["package"]:
            meta.append(f"package: {e['package']}")
        if e["file"]:
            meta.append(f"定義: {e['file']}")
        out.append("- " + " / ".join(meta))
        if e["arguments"]:
            out.append(f"- 呼び出し: `{one_line(e['arguments'])}`")
        out.append("")
        if e["description"]:
            out.append("```text")
            out.append(e["description"])
            out.append("```")
            out.append("")
        refs = e["seealso"] + e["link"]
        if refs:
            out.append("関連: " + ", ".join(f"`{r}`" for r in refs))
            out.append("")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--check",
        action="store_true",
        help="生成物が最新かどうかだけ調べる (書き込まない)",
    )
    args = ap.parse_args()

    entries = parse()
    by_section = {}
    for e in entries:
        by_section.setdefault((e["section"], e["slug"]), []).append(e)

    files = {"index.tsv": render_index(entries)}
    for (section, slug), es in by_section.items():
        files[f"{slug}.md"] = render_section(section, slug, es)

    if args.check:
        stale = [
            name
            for name, body in files.items()
            if not (OUTDIR / name).exists()
            or (OUTDIR / name).read_text(encoding="utf-8") != body
        ]
        if stale:
            sys.exit(
                "生成物が古いです。python3 misc/gen-reference-skill.py を実行してください: "
                + ", ".join(sorted(stale))
            )
        print(f"up to date ({len(entries)} エントリ / {len(by_section)} セクション)")
        return

    OUTDIR.mkdir(parents=True, exist_ok=True)
    # 消えたセクションの残骸を掃除する
    for old in OUTDIR.iterdir():
        if old.is_file() and old.name not in files:
            old.unlink()
    for name, body in files.items():
        (OUTDIR / name).write_text(body, encoding="utf-8")

    print(f"{OUTDIR.relative_to(REPO_ROOT)} に書きました")
    print(f"  {len(entries)} エントリ / {len(by_section)} セクション")


if __name__ == "__main__":
    main()
