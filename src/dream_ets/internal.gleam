//// Internal ETS operations
////
//// Low-level wrappers around FFI. No public API.

import gleam/dynamic
import gleam/result

pub type EtsTableRef

pub type EtsFfiError {
  /// The key has more than one object, and the operation needs one
  SeveralObjects(Int)
  /// The table does not exist (for example, it was deleted)
  TableNotFound
  InvalidOperation(String)
  EmptyTable
  EndOfTable
}

/// Why ETS did not create a table.
pub type NewTableError {
  /// A named table with this name already exists.
  NameInUse
  /// ETS rejected the table options. The message gives the reason.
  OptionsRejected(String)
}

/// Creates the table. Returns `Error(NameInUse)` when a named table with
/// this name already exists, and `Error(OptionsRejected(message))` when ETS
/// rejects the name or the options.
@external(erlang, "internal_ffi", "ets_new")
fn ets_new(
  name: String,
  options: List(dynamic.Dynamic),
) -> Result(Int, NewTableError)

@external(erlang, "internal_ffi", "ets_match")
pub fn ets_match(
  table_id: Int,
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_match_object")
pub fn ets_match_object(
  table_id: Int,
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_select")
pub fn ets_select(
  table_id: Int,
  match_spec: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_tab2file")
pub fn ets_tab2file(table_id: Int, filename: String) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_file2tab")
pub fn ets_file2tab(filename: String) -> Result(Int, EtsFfiError)

@external(erlang, "internal_ffi", "ets_insert")
pub fn ets_insert(
  table_id: Int,
  object: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_lookup")
pub fn ets_lookup(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_delete_table")
pub fn ets_delete_table(table_id: Int) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_delete_key")
pub fn ets_delete_key(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_delete_all_objects")
pub fn ets_delete_all_objects(table_id: Int) -> Result(Nil, EtsFfiError)

@external(erlang, "internal_ffi", "ets_first")
pub fn ets_first(table_id: Int) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_next")
pub fn ets_next(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError)

@external(erlang, "internal_ffi", "ets_member")
pub fn ets_member(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError)

@external(erlang, "internal_ffi", "ets_insert_new")
pub fn ets_insert_new(
  table_id: Int,
  object: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError)

@external(erlang, "internal_ffi", "ets_take")
pub fn ets_take(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_take_one")
pub fn ets_take_one(
  table_id: Int,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError)

@external(erlang, "internal_ffi", "ets_update_element")
pub fn ets_update_element(
  table_id: Int,
  key: dynamic.Dynamic,
  update_tuple: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError)

@external(erlang, "internal_ffi", "ets_update_counter")
pub fn ets_update_counter(
  table_id: Int,
  key: dynamic.Dynamic,
  amount: Int,
  default_object: dynamic.Dynamic,
) -> Result(Int, EtsFfiError)

@external(erlang, "internal_ffi", "ets_size")
pub fn ets_size(table_id: Int) -> Result(Int, EtsFfiError)

@external(erlang, "internal_ffi", "to_dynamic")
pub fn to_dynamic(value: a) -> dynamic.Dynamic

@external(erlang, "internal_ffi", "wrap_table_ref")
pub fn wrap_table_ref_ffi(table_id: Int) -> EtsTableRef

@external(erlang, "internal_ffi", "unwrap_table_ref")
pub fn unwrap_table_ref_ffi(table: EtsTableRef) -> Int

/// Creates a table with the given name and options. Returns
/// `Error(NameInUse)` when a named table with this name already exists, and
/// `Error(OptionsRejected(message))` when ETS rejects the name (it has more
/// than 255 characters) or the options.
pub fn new_table(
  name: String,
  options: List(dynamic.Dynamic),
) -> Result(EtsTableRef, NewTableError) {
  ets_new(name, options)
  |> result.map(wrap_table_ref)
}

pub fn insert(
  table: EtsTableRef,
  object: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_insert(table_id, object)
}

/// Every object stored under `key`. A set table has at most one, and a bag
/// table can have more.
pub fn lookup(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_lookup(table_id, key)
}

pub fn delete_table(table: EtsTableRef) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_delete_table(table_id)
}

pub fn delete_key(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_delete_key(table_id, key)
}

pub fn delete_all_objects(table: EtsTableRef) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_delete_all_objects(table_id)
}

pub fn first_key(table: EtsTableRef) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_first(table_id)
}

pub fn next_key(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_next(table_id, key)
}

pub fn member(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_member(table_id, key)
}

pub fn insert_new(
  table: EtsTableRef,
  object: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_insert_new(table_id, object)
}

/// Remove every object stored under `key`, and return them.
pub fn take(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_take(table_id, key)
}

/// Remove the object stored under `key` and return it in a list, in one ETS
/// call. When the key has more than one object (a bag table), the objects
/// are put back, and the error is `SeveralObjects` with their count.
pub fn take_one(
  table: EtsTableRef,
  key: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_take_one(table_id, key)
}

pub fn update_element(
  table: EtsTableRef,
  key: dynamic.Dynamic,
  pos: Int,
  value: dynamic.Dynamic,
) -> Result(Bool, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  let update_tuple = to_dynamic(#(pos, value))
  ets_update_element(table_id, key, update_tuple)
}

/// Add `amount` to the integer value stored under `key` and return the new
/// value, in one ETS call (`ets:update_counter/4`). When the key is not in
/// the table, ETS first inserts `default_object`. ETS refuses the call
/// (`InvalidOperation`) when the value is not an integer, or when the table
/// is a bag or duplicate_bag table.
pub fn update_counter(
  table: EtsTableRef,
  key: dynamic.Dynamic,
  amount: Int,
  default_object: dynamic.Dynamic,
) -> Result(Int, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_update_counter(table_id, key, amount, default_object)
}

/// The number of objects in the table, in constant time (`ets:info/1`).
pub fn size(table: EtsTableRef) -> Result(Int, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_size(table_id)
}

pub fn match(
  table: EtsTableRef,
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_match(table_id, pattern)
}

pub fn match_object(
  table: EtsTableRef,
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_match_object(table_id, pattern)
}

pub fn select(
  table: EtsTableRef,
  match_spec: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_select(table_id, match_spec)
}

pub fn tab2file(
  table: EtsTableRef,
  filename: String,
) -> Result(Nil, EtsFfiError) {
  let table_id = unwrap_table_ref(table)
  ets_tab2file(table_id, filename)
}

pub fn file2tab(filename: String) -> Result(EtsTableRef, EtsFfiError) {
  ets_file2tab(filename)
  |> result.map(wrap_table_ref)
}

// Private helper functions

fn wrap_table_ref(table_id: Int) -> EtsTableRef {
  wrap_table_ref_ffi(table_id)
}

fn unwrap_table_ref(table: EtsTableRef) -> Int {
  unwrap_table_ref_ffi(table)
}
