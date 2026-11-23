//// Guide: Saving a table to disk, step 1
////
//// Writes every entry of a table to a file.

import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/result

pub fn save_settings(name: String, path: String) -> Result(Nil, EtsError) {
  use settings <- result.try(
    config.new(name)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  use Nil <- result.try(operations.set(settings, "theme", "dark"))
  use Nil <- result.try(operations.set(settings, "language", "en"))
  operations.save_to_file(settings, path)
}
