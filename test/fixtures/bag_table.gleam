//// Bag tables, for the tests of keys that have more than one value.

import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/result

/// Creates an empty bag table of strings with the given name.
pub fn bag_string_table(
  name: String,
) -> Result(Table(String, String), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.table_type(config.table_type_bag())
  |> config.create()
}

/// Creates a bag table where the key `"key"` has the values `"first"` and
/// `"second"`.
pub fn two_values(name: String) -> Result(Table(String, String), EtsError) {
  use bag <- result.try(bag_string_table(name))
  use _ <- result.try(operations.set(bag, "key", "first"))
  use _ <- result.try(operations.set(bag, "key", "second"))
  Ok(bag)
}
