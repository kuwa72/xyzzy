#!/usr/bin/env python3
"""Print the body for a GitHub release from a release note file.

    tools/release-body.py docs/release-notes/release-note-0.7.0.md 0.7.0

The note goes out as-is when it fits.  **GitHub refuses a release body over
125,000 characters** (HTTP 422 "body is too long"), and that is not a
theoretical limit: 0.7.0's note is 183,333 characters, so `gh release create`
failed *after* all three architectures had built -- twenty-five minutes in,
with the tag already pushed and no release created.

When it does not fit, print a digest instead: the header, the whole
"このリリースについて", an index of the sections with their bullet counts, the
whole "既知の問題", and a link to the complete note at the tag.  **The two
sections kept whole are the ones written to be read**; the middle is 166
bullets that the repository holds better than a release page does.

Exits non-zero if even the digest does not fit, rather than printing something
the API will reject.
"""
import re
import sys

# 125,000 is the API limit; leave room for the pointer we append and for the
# limit being counted in something other than code points.
LIMIT = 118000

HEADING = re.compile(r'^-{3,}$')


def sections(lines):
    """[(title, start, end)] for every "title\n----" section, in file order."""
    heads = [i for i in range(len(lines) - 1)
             if HEADING.match(lines[i + 1] or '') and lines[i].strip()
             and not lines[i].startswith(' ')]
    out = []
    for n, i in enumerate(heads):
        end = heads[n + 1] if n + 1 < len(heads) else len(lines)
        out.append((lines[i].strip(), i, end))
    return out


def digest(text, version):
    lines = text.split('\n')
    secs = sections(lines)
    by_title = {t: (s, e) for t, s, e in secs}

    # Header: everything before the first section heading.
    head = lines[:secs[0][1]] if secs else lines
    parts = ['\n'.join(head).rstrip()]

    def whole(title):
        if title not in by_title:
            return None
        s, e = by_title[title]
        return '\n'.join(lines[s:e]).rstrip()

    intro = whole('このリリースについて')
    if intro:
        parts.append(intro)

    index = ['変更', '----', '',
             '**全文はリポジトリにある** (下のリンク)。'
             'GitHub のリリース本文は 125,000 文字までで、'
             'このリリースのノートは入らない。節と件数だけ並べる:', '']
    for title, s, e in secs:
        if title in ('このリリースについて', '既知の問題'):
            continue
        n = sum(1 for l in lines[s:e] if l.startswith('  * '))
        index.append('  * %s — %d 件' % (title, n))
    parts.append('\n'.join(index))

    known = whole('既知の問題')
    if known:
        parts.append(known)

    parts.append(
        '---\n\n'
        '変更の全文 (なぜそうしたかを含む) は\n'
        '<https://github.com/kuwa72/xyzzy/blob/v%s/docs/release-notes/'
        'release-note-%s.md>。' % (version, version))
    return '\n\n\n'.join(parts) + '\n'


def main():
    if len(sys.argv) != 3:
        sys.stderr.write('usage: release-body.py <note file> <version>\n')
        return 2
    path, version = sys.argv[1], sys.argv[2]
    with open(path, encoding='utf-8') as f:
        text = f.read()

    if len(text) <= LIMIT:
        sys.stdout.write(text)
        return 0

    body = digest(text, version)
    sys.stderr.write('release-body.py: %s is %d characters; sending a %d '
                     'character digest instead\n'
                     % (path, len(text), len(body)))
    if len(body) > LIMIT:
        sys.stderr.write('release-body.py: the digest does not fit either '
                         '(%d > %d). Shorten "このリリースについて" or '
                         '"既知の問題".\n' % (len(body), LIMIT))
        return 1
    sys.stdout.write(body)
    return 0


if __name__ == '__main__':
    sys.exit(main())
