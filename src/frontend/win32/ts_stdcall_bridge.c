/* ts_stdcall_bridge.c - x86 MSVC stdcall/cdecl bridge for tree-sitter
 *
 * Problem: the project uses /Gz (global __stdcall default) on x86 MSVC.
 * tree-sitter-core.lib is added to CMake BEFORE /Gz is set, so it is built
 * without /Gz and exports plain cdecl symbols (_ts_xxx, no @N suffix).
 * ts.cc, built with /Gz, generates stdcall references (_ts_xxx@N) that the
 * linker cannot satisfy from tree-sitter-core.lib.
 *
 * Fix: bridge functions in this file are compiled as __stdcall (via /Gz).
 * Each wrapper forwards its call to a uniquely-named cdecl alias declared
 * with explicit __cdecl (overriding /Gz for those declarations).  The linker
 * resolves each cdecl alias to tree-sitter-core.lib via /ALTERNATENAME.
 *
 * Stack discipline is preserved: ts.cc's stdcall call sites rely on the
 * bridge's RETN N to pop arguments; the bridge's cdecl calls to _impl add
 * to ESP after return.  No double-pop, no corruption.
 *
 * Only active on _M_IX86 (32-bit x86 MSVC).  On x64/ARM64, stdcall == cdecl
 * so no bridge is needed; this file compiles to an empty translation unit.
 */
#ifdef _M_IX86

#include <tree_sitter/api.h>

/* ---- Cdecl declarations (unique _impl suffix) ----------------------------
   __cdecl overrides the /Gz default so these declarations produce plain
   _ts_xxx_impl symbols (no @N suffix), matching tree-sitter-core.lib. */

extern TSParser      * __cdecl ts_parser_new_impl(void);
extern void            __cdecl ts_parser_delete_impl(TSParser *);
extern bool            __cdecl ts_parser_set_language_impl(TSParser *, const TSLanguage *);
extern TSTree        * __cdecl ts_parser_parse_with_options_impl(TSParser *, const TSTree *, TSInput, TSParseOptions);
extern TSTree        * __cdecl ts_tree_copy_impl(const TSTree *);
extern void            __cdecl ts_tree_delete_impl(TSTree *);
extern void            __cdecl ts_tree_edit_impl(TSTree *, const TSInputEdit *);
extern TSNode          __cdecl ts_tree_root_node_impl(const TSTree *);
extern const char    * __cdecl ts_node_type_impl(TSNode);
extern uint32_t        __cdecl ts_node_start_byte_impl(TSNode);
extern uint32_t        __cdecl ts_node_end_byte_impl(TSNode);
extern bool            __cdecl ts_node_is_null_impl(TSNode);
extern TSNode          __cdecl ts_node_parent_impl(TSNode);
extern TSNode          __cdecl ts_node_named_descendant_for_byte_range_impl(TSNode, uint32_t, uint32_t);
extern TSQuery       * __cdecl ts_query_new_impl(const TSLanguage *, const char *, uint32_t, uint32_t *, TSQueryError *);
extern void            __cdecl ts_query_delete_impl(TSQuery *);
extern const char    * __cdecl ts_query_capture_name_for_id_impl(const TSQuery *, uint32_t, uint32_t *);
extern TSQueryCursor * __cdecl ts_query_cursor_new_impl(void);
extern void            __cdecl ts_query_cursor_delete_impl(TSQueryCursor *);
extern void            __cdecl ts_query_cursor_exec_impl(TSQueryCursor *, const TSQuery *, TSNode);
extern bool            __cdecl ts_query_cursor_set_point_range_impl(TSQueryCursor *, TSPoint, TSPoint);
extern bool            __cdecl ts_query_cursor_next_match_impl(TSQueryCursor *, TSQueryMatch *);

/* ---- /ALTERNATENAME: resolve _impl cdecl names to tree-sitter-core exports */

#pragma comment(linker, "/ALTERNATENAME:_ts_parser_new_impl=_ts_parser_new")
#pragma comment(linker, "/ALTERNATENAME:_ts_parser_delete_impl=_ts_parser_delete")
#pragma comment(linker, "/ALTERNATENAME:_ts_parser_set_language_impl=_ts_parser_set_language")
#pragma comment(linker, "/ALTERNATENAME:_ts_parser_parse_with_options_impl=_ts_parser_parse_with_options")
#pragma comment(linker, "/ALTERNATENAME:_ts_tree_copy_impl=_ts_tree_copy")
#pragma comment(linker, "/ALTERNATENAME:_ts_tree_delete_impl=_ts_tree_delete")
#pragma comment(linker, "/ALTERNATENAME:_ts_tree_edit_impl=_ts_tree_edit")
#pragma comment(linker, "/ALTERNATENAME:_ts_tree_root_node_impl=_ts_tree_root_node")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_type_impl=_ts_node_type")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_start_byte_impl=_ts_node_start_byte")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_end_byte_impl=_ts_node_end_byte")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_is_null_impl=_ts_node_is_null")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_parent_impl=_ts_node_parent")
#pragma comment(linker, "/ALTERNATENAME:_ts_node_named_descendant_for_byte_range_impl=_ts_node_named_descendant_for_byte_range")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_new_impl=_ts_query_new")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_delete_impl=_ts_query_delete")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_capture_name_for_id_impl=_ts_query_capture_name_for_id")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_cursor_new_impl=_ts_query_cursor_new")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_cursor_delete_impl=_ts_query_cursor_delete")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_cursor_exec_impl=_ts_query_cursor_exec")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_cursor_set_point_range_impl=_ts_query_cursor_set_point_range")
#pragma comment(linker, "/ALTERNATENAME:_ts_query_cursor_next_match_impl=_ts_query_cursor_next_match")

/* ---- Stdcall bridge wrappers (compiled as __stdcall via /Gz) --------------
   These definitions produce _ts_xxx@N symbols that ts.cc references.
   Each forwards to its _impl cdecl alias resolved to tree-sitter-core.lib.  */

TSParser *ts_parser_new(void)
  { return ts_parser_new_impl(); }

void ts_parser_delete(TSParser *self)
  { ts_parser_delete_impl(self); }

bool ts_parser_set_language(TSParser *self, const TSLanguage *language)
  { return ts_parser_set_language_impl(self, language); }

TSTree *ts_parser_parse_with_options(TSParser *self, const TSTree *old_tree, TSInput input, TSParseOptions opts)
  { return ts_parser_parse_with_options_impl(self, old_tree, input, opts); }

TSTree *ts_tree_copy(const TSTree *self)
  { return ts_tree_copy_impl(self); }

void ts_tree_delete(TSTree *self)
  { ts_tree_delete_impl(self); }

void ts_tree_edit(TSTree *self, const TSInputEdit *edit)
  { ts_tree_edit_impl(self, edit); }

TSNode ts_tree_root_node(const TSTree *self)
  { return ts_tree_root_node_impl(self); }

const char *ts_node_type(TSNode self)
  { return ts_node_type_impl(self); }

uint32_t ts_node_start_byte(TSNode self)
  { return ts_node_start_byte_impl(self); }

uint32_t ts_node_end_byte(TSNode self)
  { return ts_node_end_byte_impl(self); }

bool ts_node_is_null(TSNode self)
  { return ts_node_is_null_impl(self); }

TSNode ts_node_parent(TSNode self)
  { return ts_node_parent_impl(self); }

TSNode ts_node_named_descendant_for_byte_range(TSNode self, uint32_t start, uint32_t end)
  { return ts_node_named_descendant_for_byte_range_impl(self, start, end); }

TSQuery *ts_query_new(const TSLanguage *language, const char *source, uint32_t source_len, uint32_t *error_offset, TSQueryError *error_type)
  { return ts_query_new_impl(language, source, source_len, error_offset, error_type); }

void ts_query_delete(TSQuery *self)
  { ts_query_delete_impl(self); }

const char *ts_query_capture_name_for_id(const TSQuery *self, uint32_t index, uint32_t *length)
  { return ts_query_capture_name_for_id_impl(self, index, length); }

TSQueryCursor *ts_query_cursor_new(void)
  { return ts_query_cursor_new_impl(); }

void ts_query_cursor_delete(TSQueryCursor *self)
  { ts_query_cursor_delete_impl(self); }

void ts_query_cursor_exec(TSQueryCursor *self, const TSQuery *query, TSNode node)
  { ts_query_cursor_exec_impl(self, query, node); }

bool ts_query_cursor_set_point_range(TSQueryCursor *self, TSPoint start_point, TSPoint end_point)
  { return ts_query_cursor_set_point_range_impl(self, start_point, end_point); }

bool ts_query_cursor_next_match(TSQueryCursor *self, TSQueryMatch *match)
  { return ts_query_cursor_next_match_impl(self, match); }

#endif /* _M_IX86 */
