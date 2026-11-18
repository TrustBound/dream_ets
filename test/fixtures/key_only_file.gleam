//// Writes a table file whose object has a key and no value, for the tests
//// that load data that a typed table cannot read.

/// Writes `filename` with a named table `name` that holds one object
/// `{key}`. The table exists only while the file is written.
@external(erlang, "dream_ets_test_ffi", "write_key_only_table")
pub fn write(name: String, key: String, filename: String) -> Nil
