#include "stdafx.h"
#include "ed.h"
#include "xdde.h"
#include "safe_ptr.h"

static HDDEDATA CALLBACK topic_list_callback (DdeCallbackInfo *);
static HDDEDATA CALLBACK item_list_callback (DdeCallbackInfo *);
static HDDEDATA CALLBACK formats_callback (DdeCallbackInfo *);
static HDDEDATA CALLBACK help_callback (DdeCallbackInfo *);
static HDDEDATA CALLBACK eval_callback (DdeCallbackInfo *);
static int CALLBACK eval_matcher (const DdeItemList *, HSZ);

const wchar_t DdeServerName[] = L"Xyzzy";

static DdeItemList system_item_list[] =
{
  {0, topic_list_callback, L"Topics"},
  {0, item_list_callback, L"SysItems"},
  {0, formats_callback, L"Formats"},
#ifdef notyet
  {0, help_callback, L"Help"},
#endif
  {0},
};

static DdeItemList lisp_item_list[] =
{
  {0, eval_callback, L"Eval", eval_matcher},
  {0, eval_callback, DDE_EXECUTE_ITEM},
  {0},
};

DdeTopicList DdeServerTopicList[] =
{
  {0, system_item_list, L"System"},
  {0, lisp_item_list, L"Lisp"},
  {0},
};

static void
dde_error (Dde::Exception &e)
{
  switch (e.e)
    {
    case DMLERR_ADVACKTIMEOUT:
    case DMLERR_DATAACKTIMEOUT:
    case DMLERR_EXECACKTIMEOUT:
    case DMLERR_POKEACKTIMEOUT:
    case DMLERR_UNADVACKTIMEOUT:
      FEdde_timeout ();

    case DMLERR_BUSY:
      FEdde_busy ();

    case DMLERR_LOW_MEMORY:
      FEdde_low_memory ();

    case DMLERR_NO_CONV_ESTABLISHED:
      FEdde_no_conv ();

    case DMLERR_NOTPROCESSED:
      FEdde_not_processed ();

    case DMLERR_SERVER_DIED:
      FEdde_server_died ();

    case DMLERR_MEMORY_ERROR:
      FEstorage_error ();

    default:
      FEdde_error (make_fixnum (e.e));
    }
}

static long
dde_timeout ()
{
  long x;
  if (!safe_fixnum_value (xsymbol_value (Vdde_timeout), &x))
    return 30000L;
  return max (min (x, 180000L), 1000L);
}

#define CALL_DDE(fn) \
  try { fn; } catch (Dde::Exception &e) {dde_error (e);}

lisp
Fdde_initiate (lisp lserv, lisp ltopic)
{
  lserv = Fstring (lserv);
  ltopic = Fstring (ltopic);
  lisp lconv = make_win32_dde_handle ();
  int slen = xstring_length (lserv), tlen = xstring_length (ltopic);
  wchar_t *serv = (wchar_t *)alloca ((slen + 1) * sizeof (wchar_t));
  memcpy (serv, xstring_contents (lserv), slen * sizeof (wchar_t));
  serv[slen] = 0;
  wchar_t *topic = (wchar_t *)alloca ((tlen + 1) * sizeof (wchar_t));
  memcpy (topic, xstring_contents (ltopic), tlen * sizeof (wchar_t));
  topic[tlen] = 0;
  CALL_DDE (xwin32_dde_handle_hconv (lconv) = Dde::initiate (serv, topic));
  return lconv;
}

lisp
Fdde_terminate (lisp lconv)
{
  check_win32_dde_handle (lconv);
  HCONV hconv = xwin32_dde_handle_hconv (lconv);
  if (!hconv)
    return Qnil;
  xwin32_dde_handle_hconv (lconv) = 0;
  CALL_DDE (Dde::terminate (hconv));
  return Qt;
}

static HCONV
check_hconv (lisp lconv)
{
  check_win32_dde_handle (lconv);
  HCONV hconv = xwin32_dde_handle_hconv (lconv);
  if (!hconv)
    FEdde_terminated_transaction ();
  return hconv;
}

lisp
Fdde_execute (lisp lconv, lisp ldata)
{
  HCONV hconv = check_hconv (lconv);
  ldata = Fstring (ldata);
  int l = w2sl (ldata) + 1;
  safe_ptr <char> data (new char [l]);
  w2s (data, ldata);
  CALL_DDE (Dde::execute (hconv, dde_timeout (), data, l));
  return Qt;
}

lisp
Fdde_poke (lisp lconv, lisp litem, lisp ldata)
{
  HCONV hconv = check_hconv (lconv);
  litem = Fstring (litem);
  int ilen = xstring_length (litem);
  wchar_t *item = (wchar_t *)alloca ((ilen + 1) * sizeof (wchar_t));
  memcpy (item, xstring_contents (litem), ilen * sizeof (wchar_t));
  item[ilen] = 0;
  ldata = Fstring (ldata);
  int l = w2sl (ldata) + 1;
  safe_ptr <char> data (new char [l]);
  w2s (data, ldata);
  CALL_DDE (Dde::poke (hconv, dde_timeout (), item, data, l));
  return Qt;
}

enum dde_reqtype
{
  dr_text,
  dr_binary,
  dr_int8,
  dr_int16,
  dr_int32
};

static dde_reqtype
req_type (lisp type)
{
  if (!type || type == Qnil || type == Ktext)
    return dr_text;
  if (type == Kbinary)
    return dr_binary;
  if (type == Kint8)
    return dr_int8;
  if (type == Kint16)
    return dr_int16;
  if (type == Kint32)
    return dr_int32;
  return dde_reqtype (int (FEprogram_error (Edde_undefined_return_type, type)));
}

template <class T>
lisp
req_value1 (T *s, int l)
{
  l /= sizeof *s;
  if (l == 1)
    return make_fixnum (*s);

  lisp x = Qnil;
  for (l--; l >= 0; l--)
    x = xcons (make_fixnum (s[l]), x);
  return x;
}

static lisp
req_value (dde_reqtype type, const DdeData &data)
{
  switch (type)
    {
    default:
      assert (0);
    case dr_text:
      return make_string (data.data ());

    case dr_binary:
      {
        int l = data.length ();
        lisp x = make_string (l);
        const u_char *s = (const u_char *)data.data ();
        for (Char *d = xstring_contents (x), *de = d + l; d < de; d++, s++)
          *d = *s;
        return x;
      }

    case dr_int8:
      return req_value1 ((char *)data.data (), data.length ());

    case dr_int16:
      return req_value1 ((short *)data.data (), data.length ());

    case dr_int32:
      return req_value1 ((int *)data.data (), data.length ());
    }
}

lisp
Fdde_request (lisp lconv, lisp ldata, lisp type)
{
  HCONV hconv = check_hconv (lconv);
  ldata = Fstring (ldata);
  dde_reqtype dr_type = req_type (type);
  int dlen = xstring_length (ldata);
  wchar_t *data = (wchar_t *)alloca ((dlen + 1) * sizeof (wchar_t));
  memcpy (data, xstring_contents (ldata), dlen * sizeof (wchar_t));
  data[dlen] = 0;
  lisp result = Qnil;
  try
    {
      result = req_value (dr_type, DdeData (Dde::request (hconv, dde_timeout (), data)));
    }
  catch (Dde::Exception &e)
    {
      dde_error (e);
    }
  return result;
}

static HDDEDATA CALLBACK
topic_list_callback (DdeCallbackInfo *dci)
{
  if (dci->type == XTYP_ADVSTART)
    return HDDEDATA (1);
  if (dci->type != XTYP_REQUEST && dci->type != XTYP_ADVREQ)
    return 0;

  int nbytes = 0;
  for (DdeTopicList *t = DdeServerTopicList; t->topic; t++)
    nbytes += WideCharToMultiByte (CP_ACP, 0, t->topic, -1, 0, 0, 0, 0);

  HDDEDATA hdata = DdeCreateDataHandle (Dde::instance (), 0, 0, nbytes,
                                        dci->item, dci->fmt, 0);
  if (!hdata)
    return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
  char *data = (char *)DdeAccessData (hdata, 0);
  if (!hdata)
    {
      DdeFreeDataHandle (hdata);
      return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
    }
  for (DdeTopicList *t = DdeServerTopicList; t->topic; t++)
    {
      int n = WideCharToMultiByte (CP_ACP, 0, t->topic, -1, data, nbytes, 0, 0);
      data += n - 1;
      *data++ = '\t';
    }
  data[-1] = 0;
  DdeUnaccessData (hdata);
  return hdata;
}

static HDDEDATA CALLBACK
item_list_callback (DdeCallbackInfo *dci)
{
  if (dci->type == XTYP_ADVSTART)
    return HDDEDATA (1);
  if (dci->type != XTYP_REQUEST && dci->type != XTYP_ADVREQ)
    return 0;

  DdeTopicList *t;
  for (t = DdeServerTopicList; t->topic; t++)
    if (!DdeCmpStringHandles (dci->topic, t->hsz_topic))
      break;
  if (!t->topic)
    return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);

  int nbytes = 0;
  for (DdeItemList *il = t->items; il->item; il++)
    if (il->item != DDE_EXECUTE_ITEM)
      nbytes += WideCharToMultiByte (CP_ACP, 0, il->item, -1, 0, 0, 0, 0);

  HDDEDATA hdata = DdeCreateDataHandle (Dde::instance (), 0, 0, nbytes,
                                        dci->item, dci->fmt, 0);
  if (!hdata)
    return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
  char *data = (char *)DdeAccessData (hdata, 0);
  if (!hdata)
    {
      DdeFreeDataHandle (hdata);
      return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
    }
  for (DdeItemList *il = t->items; il->item; il++)
    if (il->item != DDE_EXECUTE_ITEM)
      {
        int n = WideCharToMultiByte (CP_ACP, 0, il->item, -1, data, nbytes, 0, 0);
        data += n - 1;
        *data++ = '\t';
      }
  data[-1] = 0;
  DdeUnaccessData (hdata);
  return hdata;
}

static HDDEDATA CALLBACK
formats_callback (DdeCallbackInfo *dci)
{
  if (dci->type == XTYP_ADVSTART)
    return HDDEDATA (1);
  if (dci->type != XTYP_REQUEST && dci->type != XTYP_ADVREQ)
    return 0;
  HDDEDATA hdata = DdeCreateDataHandle (Dde::instance (), 0, 0, sizeof "CF_TEXT",
                                        dci->item, dci->fmt, 0);
  if (!hdata)
    return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
  char *data = (char *)DdeAccessData (hdata, 0);
  if (!hdata)
    {
      DdeFreeDataHandle (hdata);
      return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
    }
  strcpy (data, "CF_TEXT");
  DdeUnaccessData (hdata);
  return hdata;
}

static HDDEDATA CALLBACK
help_callback (DdeCallbackInfo *dci)
{
  if (dci->type == XTYP_ADVSTART)
    return HDDEDATA (1);
  if (dci->type != XTYP_REQUEST && dci->type != XTYP_ADVREQ)
    return 0;
  return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
}

static int CALLBACK
eval_matcher (const DdeItemList *il, HSZ hsz)
{
  wchar_t b[6];
  if (!DdeQueryStringW (Dde::instance (), hsz, b, 6, CP_WINUNICODE))
    return 0;
  return !_wcsicmp (L"eval:", b);
}

static HDDEDATA CALLBACK
eval_callback (DdeCallbackInfo *dci)
{
  if (dci->type == XTYP_ADVSTART)
    return HDDEDATA (1);

  lisp string;
  switch (dci->type)
    {
    case XTYP_REQUEST:
    case XTYP_ADVREQ:
      {
        int l = DdeQueryStringW (Dde::instance (), dci->item, 0, 0, CP_WINUNICODE);
        safe_ptr <wchar_t> data (new wchar_t [l + 2]);
        DdeQueryStringW (Dde::instance (), dci->item, data, l + 1, CP_WINUNICODE);
        const wchar_t *p = (wchar_t *)data + 5;
        string = make_string ((const Char *)p, wcslen (p));
        break;
      }

    case XTYP_POKE:
    case XTYP_EXECUTE:
      {
        DdeDataAccess data (dci->hdata);
        string = make_string (data.data ());
        break;
      }

    default:
      return 0;
    }

  lisp stream = Fmake_string_input_stream (string, 0, 0);
  protect_gc gcpro1 (stream);
  lisp result = Qnil;
  protect_gc gcpro2 (result);
  try
    {
      lisp form = Fread (stream, Qnil, Qnil, Qnil);
      protect_gc gcpro (form);
      result = Feval (form);
      refresh_screen (1);
      Fclose (stream, Qnil);
    }
  catch (nonlocal_jump &)
    {
      refresh_screen (1);
      Fclose (stream, Qnil);
      throw;
    }

  switch (dci->type)
    {
    case XTYP_REQUEST:
    case XTYP_ADVREQ:
      {
        result = Fwrite_to_string (result, Qnil);
        HDDEDATA hdata = DdeCreateDataHandle (Dde::instance (), 0, 0,
                                              w2sl (result) + 1,
                                              dci->item, dci->fmt, 0);
        if (!hdata)
          return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
        char *data = (char *)DdeAccessData (hdata, 0);
        if (!hdata)
          {
            DdeFreeDataHandle (hdata);
            return HDDEDATA (dci->type == XTYP_REQUEST ? DDE_FNOTPROCESSED : 0);
          }
        w2s (data, result);
        DdeUnaccessData (hdata);
        return hdata;
      }

    default:
      return HDDEDATA (DDE_FACK);
    }
}
