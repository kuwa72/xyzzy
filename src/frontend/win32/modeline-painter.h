#ifndef _modeline_painter_h_
# define _modeline_painter_h_

# include "ed.h"

class mode_line_painter
{
public:
  virtual void no_format_specifier() = 0;
  virtual int first_paint(HDC hdc, int start_px) = 0;
  virtual void update_paint(HDC hdc) = 0;
  virtual bool need_repaint_all() = 0;

  Char* get_posp() { return posp; }
  void set_posp(Char* p) { posp = p; }

private:
  Char* posp;
};

class mode_line_percent_painter: public mode_line_painter
{
public:

  virtual void no_format_specifier() {
	  m_point_pixel = -1;
  }
  virtual int first_paint(HDC hdc, int start_px) {
	  m_point_pixel = start_px;
      m_last_percent = -1;
	  return paint_percent(hdc);
  }
  virtual void update_paint(HDC hdc) {
	  if(m_point_pixel == -1) // not in the format.
		  return ;
	  if(m_last_percent == m_percent)
		  return;
	  paint_percent(hdc);
  }

  virtual bool need_repaint_all();
  // end of commmon interface.

  mode_line_percent_painter() {
	  m_modeline_paramp = 0;

	  m_point_pixel = -1;

	  m_percent = -1;
	  m_last_width = -1;

	  m_ml_size.cx = 0xdeadbeef;
	  m_ml_size.cy = 0xdeadbeef;
  }

  inline void setup_paint(ModelineParam *param, int percent, const SIZE& winsize) {
	  m_modeline_paramp = param;
	  m_percent = percent;
	  m_ml_size.cx = winsize.cx;
	  m_ml_size.cy = winsize.cy;
  }

  static int calc_percent(Buffer *bufp, point_t point);

private:
  int paint_percent (HDC hdc);
  int m_point_pixel;
  int m_percent;
  SIZE m_ml_size;
  ModelineParam *m_modeline_paramp;


  int m_last_percent;
  int m_last_width;
};

class mode_line_point_painter : public mode_line_painter
{
public :
  int m_column;
  int m_plinenum;
  SIZE m_ml_size;


  int m_point_pixel;
  int m_last_ml_column;
  int m_last_ml_linenum;
  int m_last_ml_point_width;

  ModelineParam *m_modeline_paramp;

  mode_line_point_painter()
  {
	  m_modeline_paramp = 0;

	  m_point_pixel = -1;
	  m_last_ml_column = -1;
	  m_last_ml_linenum = -1;
	  m_last_ml_point_width = -1;


	  m_plinenum = 1;
	  m_column = 0;

	  m_ml_size.cx = 0xdeadbeef;
	  m_ml_size.cy = 0xdeadbeef;
  }
  virtual void no_format_specifier() {
	  m_point_pixel = -1;
  }
  virtual int first_paint(HDC hdc, int start_px) {
	  m_point_pixel = start_px;
      m_last_ml_column = m_last_ml_linenum = -1;
	  return paint_point(hdc);
  }
  virtual void update_paint(HDC hdc) {
	  paint_point(hdc);
  }

  virtual bool need_repaint_all();

  inline void setup_paint(ModelineParam *param, int column, int plinenum, const SIZE& winsize) {
	  m_modeline_paramp = param;
	  m_column = column;
	  m_plinenum = plinenum;
	  m_ml_size.cx = winsize.cx;
	  m_ml_size.cy = winsize.cy;
  }

private:
  int paint_point (HDC hdc);
};

struct mode_line_state
{
  mode_line_point_painter point;
  mode_line_percent_painter percent;
};

#endif /* _modeline_painter_h_ */
