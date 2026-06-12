// issue #13 step6 PoC — Qt inline IME on a self-drawn (custom) widget.
//
// Goal: prove that a QWidget which paints its own text (no QLineEdit/
// QTextEdit) can host Japanese inline IME — preedit shown underlined at the
// caret, candidate window positioned at the caret, commit inserts text.
// This mirrors how xyzzy would draw its buffer via the Painter and only use
// the toolkit for the window + input. Compare against poc/wx-ime.
//
// Build (after `brew install qt`):
//   see CMakeLists.txt in this dir, or:
//   /opt/homebrew/opt/qt/bin/qmake && make   (if a .pro is added)

#include <QApplication>
#include <QWidget>
#include <QPainter>
#include <QPaintEvent>
#include <QInputMethodEvent>
#include <QFont>
#include <QFontMetrics>
#include <QString>
#include <QDebug>

// A custom widget that draws its own text and handles IME itself.
class ImeCanvas : public QWidget
{
public:
  ImeCanvas ()
  {
    // Required for a custom widget to receive input-method events.
    setAttribute (Qt::WA_InputMethodEnabled, true);
    setFocusPolicy (Qt::StrongFocus);
    m_font = QFont ("Menlo", 18);          // a monospace face
    setMinimumSize (800, 200);
  }

protected:
  // Self-drawn text: committed text, then the IME preedit (underlined),
  // then a caret. No Qt text widget involved.
  void paintEvent (QPaintEvent *) override
  {
    QPainter p (this);
    p.fillRect (rect (), Qt::white);
    p.setFont (m_font);
    QFontMetrics fm (m_font);

    int x = 10, y = 60 + fm.ascent ();
    p.setPen (Qt::black);
    p.drawText (x, y, m_committed);
    x += fm.horizontalAdvance (m_committed);

    // Preedit (composition) text, drawn underlined to mark it as in-progress.
    if (!m_preedit.isEmpty ())
      {
        QFont uf = m_font;
        uf.setUnderline (true);
        p.setFont (uf);
        p.setPen (Qt::darkBlue);
        p.drawText (x, y, m_preedit);
        x += fm.horizontalAdvance (m_preedit);
        p.setFont (m_font);
      }

    // Caret.
    p.setPen (Qt::black);
    p.drawLine (x + 1, y - fm.ascent (), x + 1, y + fm.descent ());

    p.setPen (Qt::gray);
    p.drawText (10, 30, QStringLiteral ("Qt IME PoC — type Japanese (かな漢字). preedit/commit logged."));
    m_caretX = x;
    m_caretTop = y - fm.ascent ();
    m_caretBottom = y + fm.descent ();
  }

  // Receive composition + commit from the IME.
  void inputMethodEvent (QInputMethodEvent *e) override
  {
    if (!e->commitString ().isEmpty ())
      {
        m_committed += e->commitString ();
        qDebug () << "commit:" << e->commitString ();
      }
    m_preedit = e->preeditString ();
    if (!m_preedit.isEmpty ())
      qDebug () << "preedit:" << m_preedit;
    update ();
    // Tell the IME its candidate window should move (caret moved).
    updateMicroFocus ();
    e->accept ();
  }

  // The IME queries this to place the candidate window at the caret.
  QVariant inputMethodQuery (Qt::InputMethodQuery q) const override
  {
    if (q == Qt::ImCursorRectangle)
      return QRect (m_caretX, m_caretTop, 2, m_caretBottom - m_caretTop);
    if (q == Qt::ImFont)
      return m_font;
    return QWidget::inputMethodQuery (q);
  }

private:
  QFont m_font;
  QString m_committed = QStringLiteral ("xyzzy> ");
  QString m_preedit;
  int m_caretX = 10, m_caretTop = 40, m_caretBottom = 70;
};

int
main (int argc, char **argv)
{
  QApplication app (argc, argv);
  ImeCanvas w;
  w.setWindowTitle ("Qt inline-IME PoC");
  w.show ();
  return app.exec ();
}
