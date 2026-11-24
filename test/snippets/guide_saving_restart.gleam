//// Guide: Saving a table to disk, step 3
////
//// Saves a table, deletes it as a stop of the program would, and loads it
//// again.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/option.{type Option}
import gleam/result
import snippets/guide_saving_load.{load_or_create_settings}

pub fn survive_a_restart(path: String) -> Result(Option(String), EtsError) {
  use before <- result.try(load_or_create_settings("restart_settings", path))
  use Nil <- result.try(operations.set(before, "theme", "dark"))
  use Nil <- result.try(operations.save_to_file(before, path))
  // The program stops, and its tables go with it
  use Nil <- result.try(operations.delete_table(before))
  use after <- result.try(load_or_create_settings("restart_settings", path))
  operations.get(after, "theme")
}

/// Saves a table to a directory that does not exist.
pub fn save_to_missing_directory() -> Result(Nil, EtsError) {
  use settings <- result.try(helpers.new_string_table("unsaved_settings"))
  operations.save_to_file(settings, "/no/such/directory/settings.ets")
}
