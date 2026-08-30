#!/usr/bin/env python3
"""docs/release-notes/release-note-next.md の衝突を解く。

新しい項目はいつも「変更」の先頭に足すので、**リベースのたびに同じ形の衝突が
出る。** 中身はどちらも残すのが正解 (別々の項目なので) で、順番は
「自分の側を先、main の側を後」= 新しい順。手で解くと毎回同じ判断をするので
ここに固定した。

    tools/resolve-note-conflict.py

衝突が無ければ何もしない。複数の衝突があれば全部同じ形で解く。
"""
import sys

PATH = 'docs/release-notes/release-note-next.md'

def main():
    s = open(PATH, encoding='utf-8').read()
    n = 0
    while '<<<<<<< ' in s:
        i = s.index('<<<<<<< ')
        i_end = s.index('\n', i) + 1
        j = s.index('\n=======\n', i)
        k = s.index('>>>>>>> ', j)
        k_end = s.index('\n', k) + 1
        head = s[i_end:j + 1]                    # main 側
        mine = s[j + len('\n=======\n'):k]       # 自分側
        s = s[:i] + mine.rstrip('\n') + '\n\n' + head.lstrip('\n') + s[k_end:]
        n += 1
    if n:
        open(PATH, 'w', encoding='utf-8').write(s)
        print('%s: %d 件の衝突を解いた (自分側を先、main 側を後)' % (PATH, n))
    else:
        print('%s: 衝突なし' % PATH)
    return 0

if __name__ == '__main__':
    sys.exit(main())
