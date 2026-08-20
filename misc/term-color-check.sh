#!/bin/sh
# xyzzy のターミナル (M-x shell) で色が出るかを目で確かめる。
# WSL / Linux のシェルから実行する。POSIX sh で書いてあるので bash でも動く。
#
#   sh misc/term-color-check.sh
#
# 直したものが見えているかどうかを、直す前にどう見えていたかと並べて書く。

e=$(printf '\033')
r="${e}[0m"

echo "=== 1. 24bit 色 (SGR 38;2;r;g;b) ============================"
echo "   直す前: 色が付かないうえ DIM が立ち背景色が化けていた"
printf '   %s[38;2;255;100;50mORANGE%s  ' "$e" "$r"
printf '%s[38;2;80;250;123mGREEN%s  ' "$e" "$r"
printf '%s[38;2;139;233;253mCYAN%s  ' "$e" "$r"
printf '%s[38;2;255;121;198mPINK%s\n' "$e" "$r"
printf '   背景: %s[48;2;40;44;52m  40,44,52  %s' "$e" "$r"
printf '%s[48;2;98;114;164m  98,114,164  %s\n' "$e" "$r"

echo "   なめらかな階調 (段差や色相のずれが無いこと):"
printf '   '
i=0
while [ $i -lt 64 ]; do
  v=$((i * 4))
  printf '%s[48;2;%d;%d;%dm ' "$e" "$v" $((255 - v)) 128
  i=$((i + 1))
done
printf '%s\n' "$r"

echo
echo "=== 2. 24bit 色のあとに属性が続く形 ========================="
echo "   直す前: 後続のパラメータが色指定に化けていた"
printf '   %s[38;2;0;255;0;1mbold green%s  ' "$e" "$r"
printf '%s[38;2;255;0;0;4munderline red%s\n' "$e" "$r"

echo
echo "=== 3. T.416 の ':' 形式 ===================================="
echo "   直す前: ':' が区切りにならず 1 個の巨大な数値に潰れていた"
printf '   %s[38:2::255:100:50mcolon form%s  ' "$e" "$r"
printf '%s[38:5:208mcolon 256%s\n' "$e" "$r"

echo
echo "=== 4. 256 色パレット ======================================="
echo "   直す前: 16 ずれていて 208 (橙) が薄いピンクだった"
printf '   16-51:  '
i=16
while [ $i -le 51 ]; do
  printf '%s[48;5;%dm  ' "$e" "$i"
  i=$((i + 1))
done
printf '%s\n' "$r"
printf '   196-231:'
i=196
while [ $i -le 231 ]; do
  printf '%s[48;5;%dm  ' "$e" "$i"
  i=$((i + 1))
done
printf '%s\n' "$r"
printf '   232-255 (灰):'
i=232
while [ $i -le 255 ]; do
  printf '%s[48;5;%dm  ' "$e" "$i"
  i=$((i + 1))
done
printf '%s\n' "$r"
printf '   目印: %s[38;5;208m208 は橙%s  ' "$e" "$r"
printf '%s[38;5;226m226 は黄%s  ' "$e" "$r"
printf '%s[38;5;21m21 は青%s  ' "$e" "$r"
printf '%s[38;5;255m255 は白に近い灰%s\n' "$e" "$r"

echo
echo "=== 5. 基本 16 色 ==========================================="
printf '   通常: '
i=0
while [ $i -lt 8 ]; do
  printf '%s[4%dm  ' "$e" "$i"
  i=$((i + 1))
done
printf '%s\n' "$r"
printf '   明るい: '
i=0
while [ $i -lt 8 ]; do
  printf '%s[10%dm  ' "$e" "$i"
  i=$((i + 1))
done
printf '%s\n' "$r"

echo
echo "=== 6. 属性 ================================================="
echo "   斜体と取消線は直す前は無視されていた"
printf '   %s[1mbold%s  %s[2mdim%s  %s[3mitalic%s  ' "$e" "$r" "$e" "$r" "$e" "$r"
printf '%s[4munderline%s  %s[7mreverse%s  %s[9mstrike%s\n' "$e" "$r" "$e" "$r" "$e" "$r"
echo "   点滅 (5) は受け取るが描画しない。後続が壊れないことだけ見る:"
printf '   %s[5;31mこれは赤で出るのが正しい%s\n' "$e" "$r"

echo
echo "=== 7. 反転と既定色の組合せ ================================="
printf '   %s[7m既定色の反転%s  ' "$e" "$r"
printf '%s[31;7m赤を反転%s\n' "$e" "$r"

echo
echo "=== 8. OSC 4 でパレットを差し替える ========================="
echo "   直す前: handle_osc が空だったので全部捨てていた"
printf '   差し替え前の色 1: %s[48;5;1m      %s\n' "$e" "$r"
printf '%s]4;1;rgb:00/ff/00%s\\' "$e" "$e"
printf '   差し替え後 (緑に): %s[48;5;1m      %s\n' "$e" "$r"
printf '%s]104;1%s\\' "$e" "$e"
printf '   戻したあと:        %s[48;5;1m      %s\n' "$e" "$r"

echo
echo "=== 9. 文字 ================================================="
echo "   日本語 ハングル 한국어 簡体字 简体字 絵文字 😀🎨 全角幅"
echo "   BMP 外が豆腐にならず、全角 2 セルで出ること"
