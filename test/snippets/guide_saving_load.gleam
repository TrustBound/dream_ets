//// Guide: Saving a table to disk, step 2 and step 3
////
//// Loads a saved table at start-up, gives it its types, and starts with an
//// empty table when no file exists yet.

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table, OperationFailed}
import gleam/result
import gleam/string

/// Loads the file and gives the table its key and value types.
pub fn load_settings(
  name: String,
  path: String,
) -> Result(Table(String, String), EtsError) {
  use table_ref <- result.map(operations.load_from_file(path))
  // The file holds the entries, but not the Gleam types. Give them here.
  table.new_table(
    table_ref,
    // The name only labels the value. The file sets the real name.
    name,
    encoders.string_encoder,
    encoders.string_decoder(),
    encoders.string_encoder,
    encoders.string_decoder(),
  )
}

/// Loads the file, or creates an empty table when the file does not exist.
pub fn load_or_create_settings(
  name: String,
  path: String,
) -> Result(Table(String, String), EtsError) {
  case load_settings(name, path) {
    Ok(settings) -> Ok(settings)
    // On the first start there is no file yet
    Error(OperationFailed(reason)) ->
      case string.contains(reason, "enoent") {
        True -> create_settings(name)
        False -> Error(OperationFailed(reason))
      }
    Error(error) -> Error(error)
  }
}

fn create_settings(name: String) -> Result(Table(String, String), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}
