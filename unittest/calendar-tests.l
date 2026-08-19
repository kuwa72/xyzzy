;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; 祝日法の改正 (2016 年以降) と元号 (令和) の対応
;;;
;;;   upstream: xyzzy-022/xyzzy#419, #424 (山の日)、#431 (新元号)

(require "calendar")
(require "timestmp")

(defun holiday-of (year month day)
  (let ((v (make-vector 33)))
    (ed::calendar-japanese-holiday year month v)
    (svref v day)))

;;; 山の日 - 2014(平成26)年 法律43号

(deftest calendar-mountain-day ()
  "山の日は 2016 年から"
  (values (holiday-of 2015 8 11)
          (holiday-of 2016 8 11)
          (holiday-of 2026 8 11))
  => nil
  => "山の日"
  => "山の日")

;;; 天皇誕生日 - 代替わりによる移動

(deftest calendar-emperors-birthday ()
  "天皇誕生日は 2018 年まで 12/23、2019 年はなく、2020 年から 2/23"
  (values (holiday-of 2018 12 23)
          (holiday-of 2019 12 23)
          (holiday-of 2019 2 23)
          (holiday-of 2020 2 23)
          (holiday-of 2026 2 23))
  => "天皇誕生日"
  => nil
  => nil
  => "天皇誕生日"
  => "天皇誕生日")

;;; 即位関連 - 2018(平成30)年 法律99号

(deftest calendar-2019-enthronement ()
  "2019 年の即位の日と即位礼正殿の儀、および前後の国民の休日"
  (values (holiday-of 2019 4 30)
          (holiday-of 2019 5 1)
          (holiday-of 2019 5 2)
          (holiday-of 2019 10 22))
  => "国民の休日"
  => "天皇の即位の日"
  => "国民の休日"
  => "即位礼正殿の儀の行われる日")

;;; 体育の日 -> スポーツの日 - 2018(平成30)年 法律57号

(deftest calendar-sports-day ()
  "10 月の第 2 月曜は 2019 年まで体育の日、2022 年からスポーツの日"
  (values (holiday-of 2019 10 14)
          (holiday-of 2022 10 10)
          (holiday-of 2026 10 12))
  => "体育の日"
  => "スポーツの日"
  => "スポーツの日")

;;; オリンピックによる移動 (2020、2021 のみ)

(deftest calendar-olympic-2020 ()
  "2020 年は海の日・スポーツの日・山の日が移動する"
  (values (holiday-of 2020 7 23)
          (holiday-of 2020 7 24)
          (holiday-of 2020 8 10)
          (holiday-of 2020 7 20)
          (holiday-of 2020 8 11)
          (holiday-of 2020 10 12))
  => "海の日"
  => "スポーツの日"
  => "山の日"
  => nil
  => nil
  => nil)

(deftest calendar-olympic-2021 ()
  "2021 年も移動し、8/8 が日曜なので 8/9 が振替休日になる"
  (values (holiday-of 2021 7 22)
          (holiday-of 2021 7 23)
          (holiday-of 2021 8 8)
          (holiday-of 2021 8 9)
          (holiday-of 2021 7 19)
          (holiday-of 2021 10 11))
  => "海の日"
  => "スポーツの日"
  => "山の日"
  => "振替休日"
  => nil
  => nil)

(deftest calendar-back-to-normal-2022 ()
  "2022 年からは海の日・山の日・スポーツの日が元に戻る"
  (values (holiday-of 2022 7 18)
          (holiday-of 2022 8 11)
          (holiday-of 2022 10 10))
  => "海の日"
  => "山の日"
  => "スポーツの日")

;;; 元号 - 令和

(deftest timestamp-reiwa ()
  "令和は 2019 年 5 月 1 日から"
  (values (format-date-string "%g%E年" (encode-universal-time 0 0 0 30 4 2019))
          (format-date-string "%g%E年" (encode-universal-time 0 0 0 1 5 2019))
          (format-date-string "%G%e" (encode-universal-time 0 0 0 1 5 2019))
          (format-date-string "%#g%#E年" (encode-universal-time 0 0 0 19 8 2026)))
  => "平成31年"
  => "令和元年"
  => "R01"
  => "令8年")
