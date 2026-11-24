//// Guide: Getting started, step 3
////
//// Creates every table of a program in one place, at start-up, and passes
//// them to the code that uses them.

import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/int
import gleam/option
import gleam/result

pub type Tables {
  Tables(names: Table(String, String), page_views: Table(String, Int))
}

/// Call this one time, from the process that runs for the whole life of
/// the program, such as `main`.
pub fn create_tables() -> Result(Tables, EtsError) {
  use names <- result.try(
    config.new("app_user_names")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  use page_views <- result.try(helpers.new_counter("app_page_views"))
  Ok(Tables(names: names, page_views: page_views))
}

/// A request handler. It runs in its own process and gets the tables as
/// an argument.
pub fn greet(tables: Tables, user_id: String) -> Result(String, EtsError) {
  use views <- result.try(helpers.increment(tables.page_views, "/greet"))
  use name <- result.map(operations.get(tables.names, user_id))
  let name = option.unwrap(name, "stranger")
  "Hello, " <> name <> ". Views of this page: " <> int.to_string(views)
}
