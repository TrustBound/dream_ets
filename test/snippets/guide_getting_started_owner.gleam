//// Guide: Getting started, step 3
////
//// A table belongs to the process that created it. When that process
//// stops, the table is deleted.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process
import gleam/option.{type Option}

/// Wrong: creates the table in a process that stops right afterwards.
pub fn create_in_short_process() -> Result(Option(String), EtsError) {
  let created = process.new_subject()
  process.spawn(fn() {
    process.send(created, helpers.new_string_table("short_lived_names"))
  })
  case process.receive_forever(created) {
    Ok(names) -> read_after_owner_stopped(names)
    Error(error) -> Error(error)
  }
}

fn read_after_owner_stopped(
  names: Table(String, String),
) -> Result(Option(String), EtsError) {
  // Give the owner time to stop
  process.sleep(50)
  operations.get(names, "user:1")
}
