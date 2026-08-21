# 日付・時間 (datetime)

reference/reference.xml から自動生成。13 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `calendar`

- Function / package: editor / 定義: calendar.l
- 呼び出し: `calendar &optional YEAR`

```text
YEARにより指定された年のカレンダーを表示します。当日には下線が、
祝祭日には色が付いています。マウスをこれらの上に移動すると、休日
の内容がポップアップ表示されます。
```

## `decode-universal-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `decode-universal-time UNIVERSAL-TIME &optional TIME-ZONE`

```text
ユニバーサルタイム形式の時間から日時に変換します。

  UNIVERSAL-TIME : ユニバーサルタイム形式の時間を指定します。
  TIME-ZONE      : タイムゾーンを指定します。

変換された日時は多値で返されます。multiple-value-***系のマクロで受け取り
ましょう。日時からユニバーサルタイム形式の時間に変換するには、
encode-universal-timeを使用します。

使用例：
  ;;; .xyzzyの最終更新日(2003/3/30 9:34:25)を取得する。
  (multiple-value-list
   (decode-universal-time
    (file-write-time ".xyzzy")))
  => (25 34 9 30 3 2003 6 nil -9)

参照：
  timestmp.l
```

関連: `format-date-string`, `encode-universal-time`

## `encode-universal-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `encode-universal-time SECOND MINUTE HOUR DAY MONTH YEAR &optional TIME-ZONE`

```text
日時からユニバーサルタイム形式の時間に変換します「1900年1月1日0時0分0秒
から指定された日時まで秒数」をユニバーサルタイム形式の時間と呼びます。

  SECOND    : 秒数
  MINUTE    : 分
  HOUR      : 時
  DAY       : 日
  MONTH     : 月
  YEAR      : 年
  TIME-ZONE : タイムゾーンを指定します。GMTからの差分の時間を指定するようです。
              省略すると選択しているタイムゾーンとの差分が使用されます。
              普通はGMTとJSTとの差分の-9(時間)となります。

ユニバーサルタイム形式の時間から日時への変換はdecode-universal-timeを使用します。

使用例：
  (encode-universal-time 0 0 0 1 1 1900)    => -32400
  (encode-universal-time 0 0 0 1 1 1900 0)  => 0
  (encode-universal-time 0 0 0 1 1 1900 -9) => -32400
  (encode-universal-time 0 30 18 24 4 2003) => 3260165400

参照：
  timestmp.l
```

関連: `decode-universal-time`, `format-date-string`

## `format-date`

- Function / package: editor / 定義: timestmp.l
- 呼び出し: `format-date S FMT &optional UNIVERSAL-TIME`

```text
書式に従って整形した日時をストリームに出力します。

  S              : 出力ストリームを指定します。
                   formatの様にtやnilを指定することはできません。
  FMT            : 日付用の書式文字列を指定します。
                   日付用の書式文字列はformat-date-stringを参照して下さい。
  UNIVERSAL-TIME : 出力する日時をユニバーサルタイム形式で指定します。
                   省略時は現在時刻が使われます。
```

関連: `decode-universal-time`, `format-date-string`

## `format-date-string`

- Function / package: editor / 定義: timestmp.l
- 呼び出し: `format-date-string FMT &optional UNIVERSAL-TIME`

```text
書式に従って整形した日時を文字列として返します。

  FMT            : 日付用の書式文字列を指定します。
  UNIVERSAL-TIME : 出力する日時をユニバーサルタイム形式で指定します。
                   省略時は現在時刻が使われます。

使用例：
  (format-date-string "%y/%m/%d %H:%M:%S" 3112500590)
  => "98/08/19 16:29:50"
  (format-date-string "%y年%#m月%#d日(%v)")
  => "99年11月10日(水)"

日付用の書式：
  書式文字については timestmp.l を参照して下さい。以下は抜粋です。 
  a: 短い形式の曜日
  A: 長い形式の曜日
  b: 短い形式の月
  B: 長い形式の月
  d: 日(00～31)                 # (0～31)
  e: 和暦の年(01～)             # (1～)
  E: 和暦の年(元, 02～)         # (元, 2～)
  g: 元号(明治,大正,昭和,平成)  # (明,大,昭,平)
  G: 元号(M, T, S, H)
  H: 時(00～23)                 # (0～23)
  I: 12時間の時(01～12)         # (1～12)
  i: Internet Time(000～999)
  m: 月(01～12)                 # (1～12)
  M: 分(00～59)                 # (0～59)
  p: 午前/午後
  P: AM/PM                      # am/pm
  S: 秒(00～59)                 # (0～59)
  v: 曜日(日本語)
  y: 年(2桁)
  Y: 年(4桁)
  z: タイムゾーン名(JST-9)
  Z: タイムゾーン(+0900)        # (+09:00)
```

関連: `decode-universal-time`, `format-date`

## `get-decoded-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-decoded-time`

```text
現在の時間を多値で返します。
  
  (get-decoded-time) == (decode-universal-time (get-universal-time))
  
使用例：
  (multiple-value-list (get-decoded-time))
  => (55 35 14 17 11 1999 2 nil -9)
```

関連: `decode-universal-time`, `format-date-string`

## `get-internal-real-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-internal-real-time`

```text
内部的にGetTickCountを呼び出しています。GetTickCountはMSDNによると
システムを起動した後の経過時間を、ミリ秒（ms）単位で取得します。
この時間は、システムタイマの分解能による制限を受けます。
システムを 49.7 日間連続して動作させると、経過時間は 0 に戻ります。

だそうです。

使用例：  
  ;;普通に呼び出す。整数が帰ってくる
  (get-internal-real-time)
  =>984001406

  ;;書式付で起動時間を表示
  (let ((tick (get-internal-real-time))
        d h m s ms)
    (multiple-value-setq (tick ms)
        (truncate tick 1000))
    (multiple-value-setq (tick s)
        (truncate tick 60))
    (multiple-value-setq (tick m)
        (truncate tick 60))
    (multiple-value-setq (d h)
        (truncate tick 24))
    (format nil "PC起動経過時間 day ~D time ~2,'0D:~2,'0D:~2,'0D.~3,'0D" d h m s ms))
  =>"PC起動経過時間 day 11 time 09:20:04.578"
```

関連: `internal-time-units-per-second`, `si:performance-counter`

## `get-universal-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-universal-time`

```text
現在の時間を返します。

使用例：
  (get-universal-time)
  => 3151806404
```

関連: `decode-universal-time`, `format-date-string`, `file-write-time`

## `internal-time-units-per-second`

- Variable / package: editor

```text
get-internal-real-time で取得した値の、1秒あたりの量を表します。
Windowsの種類により、この値が変わるかどうかは不明です。
```

関連: `get-internal-real-time`

## `sit-for`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `sit-for TIMEOUT &optional NO-REDRAW`

```text
指定された秒数停止します。途中でキー入力があれば直ぐに再開します。

  TIMEOUT   : 停止する秒数を指定します。
  NO-REDRAW : 再開後に画面を再描画するかどうかを指定します。
```

関連: `sleep-for`, `do-events`, `refresh-screen`

## `sleep-for`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `sleep-for TIMEOUT`

```text
指定された秒数停止します。途中でキー入力があっても直ぐには再開しません。

  TIMEOUT   : 停止する秒数を指定します。
```

関連: `sit-for`, `refresh-screen`

## `start-timer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `start-timer INTERVAL FN &optional ONE-SHOT-P`

```text
タイマーを設定します。INTERVAL秒後に、FNがfuncallされます。

  INTERVAL   : 何秒後に関数を実行するかを指定します。
  FN         : 実行する関数を指定します。
  ONE-SHOT-P : 継続して作動させるかどうかを指定します。
        nil      継続して作動させます。
        non-nil  1 回だけ作動させます。
  
使用例：
  ;; パターンを循環参照で作る
  (setq pat '(#\― #\／ #\｜ #\＼))
  => pat
  (setf (cdr (last pat)) pat)
  => #1=(#\― #\／ #\｜ #\＼ . #1#)
  (defun func () (setq pat (cdr pat)) (message "~A" (car pat)))
  => func
  ;; 動かす時は…
  (start-timer 0.2 'func)
  => t  
  ;; 止める時は…
  (stop-timer 'func)
  => t
```

関連: `stop-timer`

## `stop-timer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `stop-timer FN`

```text
設定したタイマーを停止します。
```

関連: `start-timer`
