#!/usr/bin/env python3
"""Win32 GUI 依存が src/core に漏れていないかを検査する。

issues #281, #294, #295, #296 の構造的な不変条件を、テストスイートの後に
実行する補助チェックとして提供する。
"""
import re
import sys
from pathlib import Path


def remove_c_comments(text: str) -> str:
    # /* ... */ (複数行) と // ... (行末) を取り除く。
    # 文字列リテラルは簡易的に無視するが、対象ファイルに該当するものは無い。
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r'//.*', '', text)
    return text


def check_window_h(repo: Path) -> None:
    path = repo / 'src' / 'core' / 'Window.h'
    text = path.read_text(encoding='utf-8')
    code = remove_c_comments(text)

    if 'HDC' in code:
        raise AssertionError(f'{path}: HDC が残っている')
    if 'void *w_hwnd' not in code or 'void *w_hwnd_ml' not in text:
        raise AssertionError(f'{path}: w_hwnd / w_hwnd_ml が opaque 化されていない')
    if 'frame_window_' in code:
        raise AssertionError(f'{path}: frame_window_* が core Window.h に残っている')


def check_no_mode_line_painter_in_core(repo: Path) -> None:
    core = repo / 'src' / 'core'
    for p in core.rglob('*'):
        if p.suffix not in ('.h', '.cc', '.cpp'):
            continue
        text = remove_c_comments(p.read_text(encoding='utf-8'))
        if re.search(r'\bmode_line_painter', text):
            raise AssertionError(f'{p}: mode_line_painter 系が src/core に残っている')


def check_no_win32_gui_types_in_headers(repo: Path, *paths: Path) -> None:
    for p in paths:
        full = repo / p
        code = remove_c_comments(full.read_text(encoding='utf-8'))
        for t in ('HWND', 'HFONT', 'COLORREF'):
            if re.search(rf'\b{t}\b', code):
                raise AssertionError(f'{full}: Win32 GUI 型 {t} が残っている')


def main() -> int:
    if len(sys.argv) != 2:
        print(f'usage: {sys.argv[0]} REPO_ROOT', file=sys.stderr)
        return 2
    repo = Path(sys.argv[1])

    check_window_h(repo)
    check_no_mode_line_painter_in_core(repo)
    check_no_win32_gui_types_in_headers(
        repo,
        Path('src/core/fns.h'),
        Path('src/core/sysdep.h'),
    )

    print('win32-separation: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
