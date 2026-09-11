<#
.SYNOPSIS
    xyzzy の「半角スペース表示 + 固定幅折り返し + スクロール」描画崩れ検証スクリプト

.DESCRIPTION
    xyzzy.exe を起動し、固定幅折り返しと半角スペース表示を有効にした状態で
    テキストを表示・スクロールさせ、崩れが発生する前後のスクリーンショットを自動保存します。

.PARAMETER ExePath
    xyzzy.exe のパス。省略時は _build\x86_64\xyzzy.exe または _build\i686\xyzzy.exe を自動検出。

.PARAMETER TargetFile
    表示するテキストファイル。省略時は半角スペースと長文を含むテストファイルを自動生成。

.PARAMETER FoldWidth
    固定幅折り返しの桁数（既定: 80）。

.PARAMETER ScrollLines
    スクロールさせる行数（既定: 20）。

.PARAMETER OutputDir
    スクリーンショットの保存先ディレクトリ（既定: カレントディレクトリ）。

.PARAMETER KeepOpen
    キャプチャ後も xyzzy を終了せずに開いたままにするスイッチ（手動で操作確認したい場合に推奨）。
#>

[CmdletBinding()]
param(
    [string]$ExePath = "",
    [string]$TargetFile = "",
    [int]$FoldWidth = 80,
    [int]$ScrollLines = 20,
    [string]$OutputDir = ".",
    [switch]$KeepOpen
)

$ErrorActionPreference = "Stop"

# 1. xyzzy.exe の解決
if (-not $ExePath) {
    $candidates = @(
        ".\_build\x86_64\xyzzy.exe",
        ".\_build\i686\xyzzy.exe",
        ".\xyzzy.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $ExePath = (Resolve-Path $cand).Path
            break
        }
    }
}

if (-not $ExePath -or -not (Test-Path $ExePath)) {
    Write-Error "xyzzy.exe が見つかりません。-ExePath でパスを指定してください。"
    exit 1
}

Write-Host "[1/5] Target xyzzy: $ExePath"

# 2. テスト対象ファイルの準備
$cleanTmpTarget = $false
if (-not $TargetFile) {
    $TargetFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "xyzzy_hspc_scroll_sample.txt")
    $cleanTmpTarget = $true

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(";;; === Half-width space + Fold-width + Scroll Test File ===")
    [void]$sb.AppendLine(";;; FoldWidth is set to: $FoldWidth")
    [void]$sb.AppendLine("")

    for ($i = 1; $i -le 100; $i++) {
        switch ($i % 5) {
            0 { [void]$sb.AppendLine(("{0:D3}: Short line with space: [foo bar baz] and some more spaces   end" -f $i)) }
            1 { [void]$sb.AppendLine(("{0:D3}: Long line intended to exceed fold width. Here are spaces: a b c d e f g h i j k l m n o p q r s t u v w x y z. Repeating space pattern:  --  --  --  end of line" -f $i)) }
            2 { [void]$sb.AppendLine(("{0:D3}: Japanese text mixed with spaces: 日本語 の 文章 に 半角 スペース を 挟む と どうなる か の テスト。固定幅 で 折り返された 箇所 で 表示 が 崩れる か 確認 します。" -f $i)) }
            3 { [void]$sb.AppendLine(("{0:D3}: Consecutive spaces: [                16 spaces                ] and [                                32 spaces                                ]" -f $i)) }
            4 { [void]$sb.AppendLine(("{0:D3}: Leading and trailing spaces:        indent 8 spaces, then text, then trailing spaces        " -f $i)) }
        }
    }
    [System.IO.File]::WriteAllText($TargetFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Write-Host "[2/5] Generated test file: $TargetFile"
} else {
    $TargetFile = (Resolve-Path $TargetFile).Path
    Write-Host "[2/5] Using target file: $TargetFile"
}

# 3. テスト用 Lisp 式の準備
# - 対象ファイルを開く
# - 固定幅折り返し設定
# - 半角スペース表示 ON
# - 初期描画
$tmpLisp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "xyzzy_setup_hspc.l")
$escapedTarget = $TargetFile.Replace("\", "/")

$lispCode = @"
(progn
  (find-file "$escapedTarget")
  (set-buffer-fold-width $FoldWidth)
  (toggle-half-width-space 1)
  (goto-char (point-min))
  (refresh-screen))
"@ -replace "`r", ""

[System.IO.File]::WriteAllText($tmpLisp, $lispCode, [System.Text.Encoding]::UTF8)

# 4. Windows API / キャプチャ定義
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$typeDef = @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class WinCapture {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static Bitmap CaptureWindow(IntPtr hWnd) {
        RECT rect;
        GetWindowRect(hWnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0) return null;
        Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);
        }
        return bmp;
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'WinCapture').Type) {
    Add-Type -TypeDefinition $typeDef -ReferencedAssemblies "System.Drawing.dll"
}

# 5. xyzzy 起動
Write-Host "[3/5] Launching xyzzy with fold-width=$FoldWidth and half-width-space enabled..."
$proc = Start-Process -FilePath $ExePath -ArgumentList @("-q", "-l", "`"$tmpLisp`"") -PassThru

$timeout = 10
$elapsed = 0
$hWnd = [IntPtr]::Zero

while ($elapsed -lt $timeout) {
    Start-Sleep -Milliseconds 500
    $elapsed += 0.5
    $proc.Refresh()
    if ($proc.HasExited) {
        Write-Error "xyzzy が予期せず終了しました。"
        exit 1
    }
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
        $hWnd = $proc.MainWindowHandle
        break
    }
}

if ($hWnd -eq [IntPtr]::Zero) {
    Write-Error "xyzzy のメインウィンドウハンドルを取得できませんでした。"
    if (-not $KeepOpen) { Stop-Process -Id $proc.Id -Force }
    exit 1
}

# 最前面化
[WinCapture]::ShowWindow($hWnd, 9) # SW_RESTORE
[WinCapture]::SetForegroundWindow($hWnd) | Out-Null
Start-Sleep -Milliseconds 1000

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# キャプチャ 1: スクロール前
$beforePath = [System.IO.Path]::GetFullPath((Join-Path $OutputDir "hspc_01_before_scroll.png"))
$bmpBefore = [WinCapture]::CaptureWindow($hWnd)
$bmpBefore.Save($beforePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmpBefore.Dispose()
Write-Host "  -> Saved pre-scroll screenshot: $beforePath"

# 6. スクロール操作の実行
Write-Host "[4/5] Scrolling window ($ScrollLines lines)..."
[WinCapture]::SetForegroundWindow($hWnd) | Out-Null

# 複数回の下スクロールキー (Down arrow / PageDown) 送信
# 1行ずつ送ることで部分スクロール再描画を確実にトリガー
for ($i = 0; $i -lt $ScrollLines; $i++) {
    [System.Windows.Forms.SendKeys]::SendWait("{DOWN}")
    Start-Sleep -Milliseconds 50
}
Start-Sleep -Milliseconds 800

# キャプチャ 2: 下スクロール後
$afterPath = [System.IO.Path]::GetFullPath((Join-Path $OutputDir "hspc_02_after_scroll_down.png"))
$bmpAfter = [WinCapture]::CaptureWindow($hWnd)
$bmpAfter.Save($afterPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmpAfter.Dispose()
Write-Host "  -> Saved post-scroll-down screenshot: $afterPath"

# 少し上へスクロールバック（再描画の重ね合わせ検証）
for ($i = 0; $i -lt [Math]::Min(10, $ScrollLines); $i++) {
    [System.Windows.Forms.SendKeys]::SendWait("{UP}")
    Start-Sleep -Milliseconds 50
}
Start-Sleep -Milliseconds 800

# キャプチャ 3: スクロールバック後
$backPath = [System.IO.Path]::GetFullPath((Join-Path $OutputDir "hspc_03_after_scroll_up.png"))
$bmpBack = [WinCapture]::CaptureWindow($hWnd)
$bmpBack.Save($backPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmpBack.Dispose()
Write-Host "  -> Saved post-scroll-up screenshot: $backPath"

# 7. 終了処理
Write-Host "[5/5] Verification complete."
if (-not $KeepOpen) {
    Start-Sleep -Milliseconds 500
    Stop-Process -Id $proc.Id -Force
} else {
    Write-Host "xyzzy は起動したままにしています (PID: $($proc.Id))。画面の崩れをそのまま確認・操作できます。" -ForegroundColor Yellow
}

# 一時ファイル整理
if (Test-Path $tmpLisp) { Remove-Item $tmpLisp -Force }
# テストターゲットファイルは KeepOpen でない場合のみ削除
if ($cleanTmpTarget -and -not $KeepOpen -and (Test-Path $TargetFile)) {
    Remove-Item $TargetFile -Force
}
