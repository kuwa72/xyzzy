// gendic.cc - reimplementation of xyzzy's gendic.exe
//
// Converts EDICT format Japanese-English dictionary to xyzzy binary format.
//
// Usage: gendic [edict-file]
//   edict-file: EDICT file (Shift_JIS). Defaults to "./edict". Use "-" for stdin.
//
// Output files (written to current directory):
//   xyzzydic  - data pool
//   xyzzye2j  - English -> Japanese index
//   xyzzyj2e  - Japanese -> English index
//   xyzzyidi  - English idiom index
//   xyzzyjrd  - Japanese reading index

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
#include <errno.h>
#include <vector>
#include <map>
#include <string>
#include <algorithm>

typedef uint16_t Char;

// ======== SJIS utilities ========

static bool sjis_lead (uint8_t c)
{
  return (c >= 0x81 && c <= 0x9F) || (c >= 0xE0 && c <= 0xFC);
}

// Convert SJIS byte string to Char array (for hashing)
static std::vector<Char> to_chars (const char *s, int len)
{
  std::vector<Char> r;
  for (int i = 0; i < len;)
    {
      uint8_t c = (uint8_t)s[i];
      if (sjis_lead (c) && i + 1 < len)
        {
          r.push_back ((Char)((c << 8) | (uint8_t)s[i + 1]));
          i += 2;
        }
      else
        {
          r.push_back ((Char)c);
          i++;
        }
    }
  return r;
}

static Char char_downcase (Char c)
{
  return (c >= 'A' && c <= 'Z') ? (Char)(c - 'A' + 'a') : c;
}

static uint32_t ihashpjw (const char *s, int len)
{
  auto chars = to_chars (s, len);
  uint32_t h = 0;
  for (Char c : chars)
    {
      h = (h << 4) + char_downcase (c);
      uint32_t g = h & 0xf0000000u;
      if (g)
        {
          h ^= g >> 24;
          h ^= g;
        }
    }
  return h;
}

// Find next ASCII char c in SJIS string, skipping double-byte sequences
static const char *sjis_find (const char *s, const char *end, char c)
{
  while (s < end)
    {
      if (sjis_lead ((uint8_t)*s))
        s += (s + 1 < end) ? 2 : 1;
      else if (*s == c)
        return s;
      else
        s++;
    }
  return nullptr;
}

// ======== Binary format ========

static const uint32_t DIC_MAGIC = 0x43494445u; // "EDIC"
static const uint32_t IDX_MAGIC = 0x58494445u; // "EDIX"

static void write32 (std::vector<uint8_t> &buf, size_t off, uint32_t val)
{
  buf[off]     = (uint8_t)(val);
  buf[off + 1] = (uint8_t)(val >> 8);
  buf[off + 2] = (uint8_t)(val >> 16);
  buf[off + 3] = (uint8_t)(val >> 24);
}

// ======== DIC pool ========

struct DicPool
{
  std::vector<uint8_t> buf;
  std::map<std::string, int32_t> cache;

  DicPool ()
  {
    buf.resize (8, 0);
    write32 (buf, 0, DIC_MAGIC);
  }

  // Add SJIS string to pool, return its DIC offset. Deduplicates.
  int32_t add (const char *s, int len)
  {
    std::string key (s, len);
    auto it = cache.find (key);
    if (it != cache.end ())
      return it->second;

    if (buf.size () % 2)
      buf.push_back (0); // 2-byte align

    int32_t off = (int32_t)buf.size ();
    buf.push_back ((uint8_t)(len & 0xFF));
    buf.push_back ((uint8_t)(len >> 8));
    buf.insert (buf.end (), (const uint8_t *)s, (const uint8_t *)s + len);
    cache[key] = off;
    return off;
  }

  void finalize ()
  {
    write32 (buf, 4, (uint32_t)buf.size ());
  }

  bool write (const char *path)
  {
    FILE *f = fopen (path, "wb");
    if (!f) { perror (path); return false; }
    bool ok = fwrite (buf.data (), 1, buf.size (), f) == buf.size ();
    fclose (f);
    return ok;
  }
};

// ======== Index builder ========

struct IdxEntry
{
  int32_t     key_off; // DIC offset of key string
  std::string key;     // SJIS key (for grouping same keys)
  int32_t     val_off; // DIC offset of value string
};

static int32_t choose_buckets (size_t n)
{
  // Odd number ~1.5x entries, minimum 127
  int32_t b = (int32_t)(n * 3 / 2);
  if (b < 127) b = 127;
  if (!(b & 1)) b++;
  return b;
}

static bool write_edix (const char *path, const std::vector<IdxEntry> &raw)
{
  // Group by key: same SJIS key -> one idx_index with result array
  struct Group
  {
    int32_t              key_off;
    std::vector<int32_t> vals;
  };
  std::map<std::string, Group> groups;
  for (auto &e : raw)
    {
      auto &g = groups[e.key];
      g.key_off = e.key_off;
      g.vals.push_back (e.val_off);
    }

  struct Entry
  {
    int32_t              key_off;
    std::string          key;
    std::vector<int32_t> vals;
  };
  std::vector<Entry> entries;
  entries.reserve (groups.size ());
  for (auto &kv : groups)
    entries.push_back ({kv.second.key_off, kv.first, kv.second.vals});

  int32_t ih_hash = choose_buckets (entries.size ());

  // Group entries by hash bucket
  std::vector<std::vector<int>> buckets (ih_hash);
  for (int i = 0; i < (int)entries.size (); i++)
    {
      uint32_t h = ihashpjw (entries[i].key.c_str (),
                              (int)entries[i].key.size ()) % (uint32_t)ih_hash;
      buckets[h].push_back (i);
    }

  // Compute layout
  // Header: magic(4) + size(4) + ih_hash(4) + ih_offset[ih_hash](4 each)
  int32_t header_sz   = 12 + ih_hash * 4;
  int32_t chain_start = header_sz;

  std::vector<int32_t> bucket_off (ih_hash, 0);
  int32_t chain_total = 0;
  for (int b = 0; b < ih_hash; b++)
    {
      if (!buckets[b].empty ())
        {
          bucket_off[b] = chain_start + chain_total;
          chain_total += (int32_t)((buckets[b].size () + 1) * 8);
        }
    }
  // Shared {0,0} terminator for empty buckets
  int32_t term_off = chain_start + chain_total;
  chain_total += 8;
  for (int b = 0; b < ih_hash; b++)
    if (buckets[b].empty ())
      bucket_off[b] = term_off;

  // Result arrays after chains
  int32_t result_start = chain_start + chain_total;
  std::vector<int32_t> result_off (entries.size ());
  int32_t result_total = 0;
  for (int i = 0; i < (int)entries.size (); i++)
    {
      result_off[i] = result_start + result_total;
      result_total += (int32_t)((entries[i].vals.size () + 1) * 4);
    }

  int32_t total = header_sz + chain_total + result_total;
  std::vector<uint8_t> buf (total, 0);

  write32 (buf, 0, IDX_MAGIC);
  write32 (buf, 4, (uint32_t)total);
  write32 (buf, 8, (uint32_t)ih_hash);
  for (int b = 0; b < ih_hash; b++)
    write32 (buf, 12 + b * 4, (uint32_t)bucket_off[b]);

  // Write idx_index chains
  for (int b = 0; b < ih_hash; b++)
    {
      if (!buckets[b].empty ())
        {
          size_t off = (size_t)bucket_off[b];
          for (int ei : buckets[b])
            {
              write32 (buf, off,     (uint32_t)entries[ei].key_off);
              write32 (buf, off + 4, (uint32_t)result_off[ei]);
              off += 8;
            }
          // {0, 0} terminator (already zero from initialization)
        }
    }
  // Shared terminator already zero

  // Write result arrays
  for (int i = 0; i < (int)entries.size (); i++)
    {
      size_t off = (size_t)result_off[i];
      for (int32_t v : entries[i].vals)
        {
          write32 (buf, off, (uint32_t)v);
          off += 4;
        }
      // null terminator already zero
    }

  FILE *f = fopen (path, "wb");
  if (!f) { perror (path); return false; }
  bool ok = fwrite (buf.data (), 1, buf.size (), f) == buf.size ();
  fclose (f);
  return ok;
}

// ======== EDICT parser ========

struct ParsedLine
{
  std::string              word;    // Japanese word (SJIS)
  std::string              reading; // Hiragana reading (SJIS), may be empty
  std::string              full;    // Full line (SJIS) - stored as value
  std::vector<std::string> defs;    // Individual /definition/ strings
};

static bool parse_edict_line (const char *line, int len, ParsedLine &out)
{
  if (len == 0 || (uint8_t)line[0] < 0x20)
    return false;

  const char *end = line + len;
  const char *p   = line;

  // Word: up to first space, '[', or '/'
  const char *word_start = p;
  while (p < end)
    {
      if (sjis_lead ((uint8_t)*p)) { p += (p + 1 < end) ? 2 : 1; continue; }
      if (*p == ' ' || *p == '[' || *p == '/') break;
      p++;
    }
  if (p <= word_start) return false;
  out.word.assign (word_start, p);

  while (p < end && *p == ' ') p++;

  // Optional [reading]
  if (p < end && *p == '[')
    {
      const char *rb = p + 1;
      const char *re = sjis_find (rb, end, ']');
      if (re)
        {
          out.reading.assign (rb, re);
          p = re + 1;
        }
    }

  while (p < end && *p == ' ') p++;

  // Definitions start at first '/'
  const char *def_start = sjis_find (p, end, '/');
  if (!def_start) return false;

  // Full line as value (trim trailing whitespace)
  out.full.assign (line, len);
  while (!out.full.empty ()
         && (out.full.back () == '\n' || out.full.back () == '\r'
             || out.full.back () == ' '))
    out.full.pop_back ();

  // Parse /def1/def2/.../
  p = def_start + 1;
  while (p < end)
    {
      const char *next = sjis_find (p, end, '/');
      if (!next) next = end;
      std::string def (p, next);
      while (!def.empty ()
             && (def.back () == '\n' || def.back () == '\r'
                 || def.back () == ' '))
        def.pop_back ();
      if (!def.empty ())
        out.defs.push_back (def);
      if (next >= end) break;
      p = next + 1;
    }

  return !out.word.empty () && !out.defs.empty ();
}

// Extract individual alphabetic words from an ASCII definition string
static std::vector<std::string> extract_words (const std::string &def)
{
  std::vector<std::string> words;
  const char *s   = def.c_str ();
  const char *end = s + def.size ();
  while (s < end)
    {
      while (s < end && !isalpha ((uint8_t)*s)) s++;
      if (s >= end) break;
      const char *ws = s;
      while (s < end && (isalpha ((uint8_t)*s) || *s == '-' || *s == '\''))
        s++;
      if (s > ws + 1) // skip single-character words
        words.emplace_back (ws, s);
    }
  return words;
}

// ======== Main ========

int main (int argc, char *argv[])
{
  const char *input_path = "edict";
  for (int i = 1; i < argc; i++)
    {
      if (argv[i][0] != '-' || argv[i][1] == '\0')
        input_path = argv[i];
      else
        { fprintf (stderr, "unknown option: %s\n", argv[i]); return 1; }
    }

  FILE *edict_f = strcmp (input_path, "-") == 0
                    ? stdin
                    : fopen (input_path, "rb");
  if (!edict_f)
    {
      fprintf (stderr, "error: cannot open %s: %s\n", input_path,
               strerror (errno));
      return 1;
    }

  DicPool dic;
  std::vector<IdxEntry> e2j_raw, j2e_raw, idi_raw, jrd_raw;

  std::vector<char> linebuf;
  linebuf.reserve (4096);
  int line_num    = 0;
  int entry_count = 0;

  // Read lines
  for (;;)
    {
      linebuf.clear ();
      int c;
      while ((c = fgetc (edict_f)) != EOF)
        {
          linebuf.push_back ((char)c);
          if (c == '\n') break;
        }
      if (linebuf.empty ()) break;
      linebuf.push_back (0);

      line_num++;
      int len = (int)strlen (linebuf.data ());
      while (len > 0
             && (linebuf[len - 1] == '\n' || linebuf[len - 1] == '\r'))
        linebuf[--len] = 0;
      if (len == 0) continue;
      if (line_num == 1) continue; // skip EDICT header line

      ParsedLine pl;
      if (!parse_edict_line (linebuf.data (), len, pl)) continue;
      entry_count++;

      // Add full line as value in DIC
      int32_t val_off = dic.add (pl.full.c_str (), (int)pl.full.size ());

      // j2e: key = Japanese word
      {
        int32_t key_off = dic.add (pl.word.c_str (), (int)pl.word.size ());
        j2e_raw.push_back ({key_off, pl.word, val_off});
      }

      // jrd: key = reading (if present)
      if (!pl.reading.empty ())
        {
          int32_t key_off =
            dic.add (pl.reading.c_str (), (int)pl.reading.size ());
          jrd_raw.push_back ({key_off, pl.reading, val_off});
        }

      // e2j and idi: from definitions
      for (auto &def : pl.defs)
        {
          // idi: multi-word English phrase (has spaces, starts with ASCII)
          bool is_ascii_phrase = !def.empty () && isalpha ((uint8_t)def[0])
                                 && def.find (' ') != std::string::npos;
          if (is_ascii_phrase)
            {
              int32_t key_off = dic.add (def.c_str (), (int)def.size ());
              idi_raw.push_back ({key_off, def, val_off});
            }

          // e2j: individual English words
          for (auto &w : extract_words (def))
            {
              int32_t key_off = dic.add (w.c_str (), (int)w.size ());
              e2j_raw.push_back ({key_off, w, val_off});
            }
        }

      if (entry_count % 10000 == 0)
        printf ("  %d entries...\n", entry_count);
    }

  if (edict_f != stdin) fclose (edict_f);

  printf ("parsed %d entries\n", entry_count);
  printf ("e2j: %zu  j2e: %zu  idi: %zu  jrd: %zu\n",
          e2j_raw.size (), j2e_raw.size (), idi_raw.size (), jrd_raw.size ());

  dic.finalize ();
  printf ("xyzzydic: %zu bytes\n", dic.buf.size ());

  if (!dic.write ("xyzzydic"))        return 1;
  if (!write_edix ("xyzzye2j", e2j_raw)) return 1;
  if (!write_edix ("xyzzyj2e", j2e_raw)) return 1;
  if (!write_edix ("xyzzyidi", idi_raw)) return 1;
  if (!write_edix ("xyzzyjrd", jrd_raw)) return 1;

  printf ("done.\n");
  return 0;
}
