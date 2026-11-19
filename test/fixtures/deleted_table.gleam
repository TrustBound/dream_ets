//// Tables that were created and then deleted, for the tests that check
//// what each operation returns for a table that no longer exists.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/result

/// Creates a string table with the given name and deletes it.
pub fn deleted_string_table(
  name: String,
) -> Result(Table(String, String), EtsError) {
  use created <- result.try(helpers.new_string_table(name))
  use _ <- result.try(operations.delete_table(created))
  Ok(created)
}

/// Creates a counter table with the given name and deletes it.
pub fn deleted_counter(name: String) -> Result(Table(String, Int), EtsError) {
  use created <- result.try(helpers.new_counter(name))
  use _ <- result.try(operations.delete_table(created))
  Ok(created)
}
