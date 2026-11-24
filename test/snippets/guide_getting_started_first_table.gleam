//// Guide: Getting started, step 1
////
//// Creates a table with String keys and String values, stores a name and
//// reads it back.

import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/option.{type Option}
import gleam/result

pub fn first_table() -> Result(Option(String), EtsError) {
  use names <- result.try(
    config.new("user_names")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  use Nil <- result.try(operations.set(names, "user:1", "Alice"))
  operations.get(names, "user:1")
}
