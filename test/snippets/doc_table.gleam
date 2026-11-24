//// Doc comments: dream_ets/table
////
//// The examples in the doc comments of the table module.

import dream_ets/config
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/option
import gleam/result

pub fn create_tables() -> Result(#(String, String), table.EtsError) {
  // Create a table using the builder
  use cache <- result.try(
    config.new("doc_table_cache")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Or use convenience functions
  use counter <- result.try(helpers.new_counter("doc_table_counts"))

  Ok(#(table.table_name(cache), table.table_name(counter)))
}

pub fn typed_operations() -> Result(option.Option(String), table.EtsError) {
  // Create a string-to-string table
  use cache <- result.try(
    config.new("doc_table_typed")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Type-safe operations
  use _ <- result.try(operations.set(cache, "user:123", "Alice"))
  // operations.set(cache, 123, "Alice") does not compile: 123 is not a String
  operations.get(cache, "user:123")
}

pub fn same_table_after_load(
  cache: table.Table(String, String),
  filename: String,
) -> Result(Bool, table.EtsError) {
  use _ <- result.try(operations.save_to_file(cache, filename))
  use _ <- result.try(operations.delete_table(cache))
  use loaded <- result.try(operations.load_from_file(filename))
  // A loaded named table has the reference of the table that was saved
  Ok(loaded == table.table_ref(cache))
}

pub fn cache_name() -> Result(String, table.EtsError) {
  use cache <- result.try(helpers.new_string_table("doc_table_named"))
  Ok(table.table_name(cache))
}

pub fn stored_key(cache: table.Table(String, String)) -> dynamic.Dynamic {
  // This is the key as ETS stores it
  table.encode_key(cache, "user:123")
}

pub fn read_key(
  cache: table.Table(String, String),
) -> Result(String, decode.DecodeError) {
  table.decode_key(cache, dynamic.string("user:123"))
}

pub fn stored_value(cache: table.Table(String, String)) -> dynamic.Dynamic {
  // This is the value as ETS stores it
  table.encode_value(cache, "Alice")
}

pub fn read_value(
  cache: table.Table(String, String),
) -> Result(String, decode.DecodeError) {
  table.decode_value(cache, dynamic.string("Alice"))
}

pub fn typed_view(
  filename: String,
) -> Result(option.Option(String), table.EtsError) {
  use table_ref <- result.try(operations.load_from_file(filename))
  // Give the loaded table its key and value types
  let users =
    table.new_table(
      table_ref,
      "doc_table_loaded",
      encoders.string_encoder,
      encoders.string_decoder(),
      encoders.string_encoder,
      encoders.string_decoder(),
    )
  operations.get(users, "user:123")
}
