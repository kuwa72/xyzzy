# xyzzy Dictionary Binary Format

## Overview

The xyzzy dictionary system converts free text dictionary sources (primarily Jim Breen's EDICT, GENE95, and Eijiro) into a proprietary binary format for fast lookup. Two tools exist:

- **gendic.exe** -- Generates files using the `EDIX` index format (offset arrays per hash bucket)
- **gendicnm.exe** -- "No memory" variant, generates files using the `EDix` index format (one entry per match, smaller but slightly less efficient)

The generated files are:

| File       | Contents                          |
|------------|-----------------------------------|
| `xyzzydic` | Dictionary data file (DIC)        |
| `xyzzye2j` | English-to-Japanese index (IDX)   |
| `xyzzyj2e` | Japanese-to-English index (IDX)   |
| `xyzzyidi` | English idiom index (IDX)         |
| `xyzzyjrd` | Japanese reading index (IDX)      |

All five files are created in the current directory. Files from `gendic` and `gendicnm` are **not interchangeable** (different index format).

## Source Input Files

- **`edict`** -- Required. Jim Breen's EDICT format (Japanese-English dictionary)
- **`gene.txt`** -- Optional. GENE95 dictionary
- **`Y-[A-Z].TXT`** -- Optional. Eijiro files, pattern `Y-A.TXT` through `Y-Z.TXT`

## Encoding

All strings in the binary files are encoded in **Shift_JIS (CP932)**.

Internally, xyzzy uses a 16-bit `Char` type (`u_int16_t`) where:
- Single-byte characters (ASCII, half-width katakana): `Char < 256`, stored as one byte in SJIS
- Double-byte characters (kanji, etc.): `Char >= 256`, the high byte is the SJIS lead byte, low byte is the trail byte

## DIC File (`xyzzydic`)

```
Offset  Size     Description
------  ----     -----------
0x00    4 bytes  Magic: "EDIC" (0x45, 0x44, 0x49, 0x43 = 0x43494445 LE)
0x04    4 bytes  File size (little-endian long)
0x08    varies   dic_string records (packed at 2-byte alignment)
```

Each `dic_string` record:

```c
#pragma pack(2)
struct dic_string {
    u_short l;       // Length of the string in bytes (Shift_JIS)
    char data[l];    // Variable-length SJIS string data (NOT null-terminated)
};
#pragma pack()
```

The data file contains **both** lookup keys and result values in the same flat pool. Index files reference entries by byte offset from the start of the DIC file.

## IDX File -- EDIX Format (gendic.exe)

```
Offset  Size            Description
------  ----            -----------
0x00    4 bytes         Magic: "EDIX" (0x45, 0x44, 0x49, 0x58 = 0x58494445 LE)
0x04    4 bytes         File size
0x08    4 bytes         ih_hash (number of hash buckets)
0x0C    ih_hash * 4     Hash table: offsets into this IDX file
...     varies          idx_index chains
...     varies          Result offset arrays
```

### Hash Table

`ih_hash` entries of `long`, each an offset into this IDX file pointing to a chain of `idx_index` entries.

### idx_index Chains

```c
struct idx_index {
    long i_data;     // Byte offset into DIC file -> dic_string (search key)
    long i_offset;   // Byte offset into IDX file -> result offset array
};
```

Terminated by an entry with `i_data == 0`.

### Result Offset Arrays

Null-terminated array of `long` values, each a byte offset into the DIC file pointing to a result `dic_string`.

### Lookup Algorithm (EDIX)

1. Compute hash: `h = ihashpjw(word) % ih_hash`
2. Walk `idx_index` chain at `ih_offset[h]`
3. For each entry, compare key (case-insensitive via `strequal`)
4. On match: walk result offset array, collect all `dic_string` results
5. Return on first matching key

## IDX File -- EDix Format (gendicnm.exe)

Same header structure but with magic `"EDix"` (`0x78694445` LE).

Key difference: `i_offset` points **directly** to a `dic_string` in the DIC file (no indirection array). Multiple results for the same key appear as separate `idx_index` entries in the chain.

### Lookup Algorithm (EDix)

1. Same hash computation
2. Walk chain, but **collect all matching entries** (don't stop at first match)
3. Each `i_offset` is a direct DIC file offset to one result string

## Hash Function: `ihashpjw`

Case-insensitive PJW (Peter J. Weinberger) hash. Source: `src/core/hashpjw.cc`

```c
u_int ihashpjw(const Char *p, int size) {
    u_int hash = 0;
    for (const Char *pe = p + size; p < pe; p++) {
        hash = (hash << 4) + char_downcase(*p);
        u_int g = hash & 0xf0000000;
        if (g) {
            hash ^= g >> 24;
            hash ^= g;
        }
    }
    return hash;
}
```

**Important**: The hash operates on internal `Char` values (16-bit), not raw SJIS bytes. SJIS double-byte characters are converted to a single `Char` as `(lead_byte << 8) | trail_byte` before hashing. `char_downcase` only affects ASCII a-z/A-Z.

## String Comparison: `strequal`

Source: `src/core/utils.cc`

Case-insensitive for ASCII; exact match for double-byte characters. Compares SJIS byte strings against internal Char arrays.

## Notes for Reimplementation

1. **Byte order**: All `long` values are little-endian.
2. **`#pragma pack(2)`** on `dic_string` is critical -- `data` starts immediately after the 2-byte `l` field with no padding.
3. **Hash on Char, not SJIS bytes**: Convert SJIS to internal Char representation before hashing.
4. **Case-insensitive**: Both hash and comparison are case-insensitive for ASCII only.
5. **Auto-detection**: The C code checks the magic number and dispatches to the correct lookup function automatically.
6. **Four indices, one data file**: All four index files reference the same `xyzzydic` data file.

## Source References

| File | Description |
|------|-------------|
| `src/frontend/win32/edict.cc` | Dictionary loading/lookup (145 lines) |
| `lisp/edict.l` | Lisp interface (245 lines) |
| `etc/README.gendic` | Original tool documentation (SJIS) |
| `src/core/hashpjw.cc` | PJW hash function |
| `src/core/utils.cc` | `strequal` comparison (lines 290-331) |
| `src/core/string.cc` | SJIS/Char conversion |
