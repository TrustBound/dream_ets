//// Reads the ETS options of a table, so that a test can check the options
//// that `config.create` gave to ETS.

import dream_ets/table.{type Table}

@external(erlang, "dream_ets_test_ffi", "table_info")
fn table_info_by_name(name: String, item: String) -> String

/// Returns one `ets:info/2` item of the table, formatted as Erlang shows it.
/// For example `"protected"`, `"true"` or `"ordered_set"`.
pub fn table_info(table: Table(k, v), item: String) -> String {
  table_info_by_name(table.table_name(table), item)
}
