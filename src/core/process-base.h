// -*-C++-*-
#ifndef _process_base_h_
# define _process_base_h_

/* プロセスの、**プラットフォームに依らない部分。**
 *
 * `class Process` は win32 と ncurses に別々に定義されていて、core には
 * `class Process;` の前方宣言しか無かった (src/core/lprocess.h)。そのため
 * プロセスを触る Lisp 関数のうち `Process` のメソッドを呼ぶ 6 個が core に
 * 上げられず、両フロントエンドに 1 文字も違わない形で 2 つあった
 * (issue #127)。ここはその共通部分だけを持つ。
 *
 * **データメンバ 6 個は両方で同じ順で同じ**、**下のアクセサ 7 個は 1 文字も
 * 違わなかった。** 違うのは実体の方だけ:
 *
 *              win32                       ncurses
 *   実体       スレッド + ハンドル         pid + パイプ 2 本 + Terminal
 *   停止       signal () / kill ()         signal_proc () / kill_proc ()
 *   送信中保護 in_send_string_p ()         無い (同期なので要らない)
 *   派生       ConPty / Normal / Socket    無し
 *
 * **`fd` や `Terminal` を持つメソッドはここに置かない。** ncurses の
 * `read_fd ()` / `term ()` / `poll_output ()` は Win32 に対応する概念が無く、
 * 置くと基底がプラットフォームを知ることになる。あちら側で
 * `posix_process ()` を通して降ろす。
 */

class ProcessBase
{
protected:
  Buffer *p_bufp;
  lisp p_proc;
  lisp p_filter;
  lisp p_sentinel;
  lisp p_last_incode;
  lisp p_marker;

  ProcessBase (Buffer *bp, lisp pl, lisp marker)
       : p_bufp (bp), p_proc (pl), p_filter (Qnil), p_sentinel (Qnil),
         p_last_incode (Qnil), p_marker (marker) {}

public:
  /* **virtual にしておくこと。** win32 の `find_conpty_process' が
     `dynamic_cast<ConPtyProcess *>' で降ろすので、基底が polymorphic で
     なければならない。 */
  virtual ~ProcessBase () {}

  lisp process_buffer () const {return p_bufp->lbp;}
  lisp &filter () {return p_filter;}
  lisp &sentinel () {return p_sentinel;}
  lisp &marker () {return p_marker;}

  int incode_modified_p () const
    {return xprocess_incode (p_proc) != p_last_incode;}
  eol_code eolcode () const {return xprocess_eol_code (p_proc);}

  static lisp make_process_marker (Buffer *bp)
    {
      lisp marker = Fmake_marker (bp->lbp);
      xmarker_point (marker) = bp->b_contents.p2;
      return marker;
    }

  /* 実体を止める / 書く。**名前は `_proc' の側に揃えた。** win32 は
     `signal ()` / `kill ()` だったが、POSIX の `kill(2)` / `signal(3)` と
     衝突するのを避けて ncurses が `_proc' を付けており、衝突しない方を
     採るのが筋。 */
  virtual void signal_proc () = 0;
  virtual void kill_proc () = 0;
  virtual void send (const char *, int) const = 0;

  /* `process-send-string' の前後。**Win32 だけが使う。** 別スレッドが
     読んでいる間に出力が溜まったら、書き終わってから本体へ知らせる必要が
     ある。POSIX は同期なので何もしない。 */
  virtual void begin_send_string () {}
  virtual void end_send_string () {}
};

#endif /* _process_base_h_ */
