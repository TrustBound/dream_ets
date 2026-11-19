//// Doc comments: dream_ets/helpers
////
//// The examples in the doc comments of the helpers module.

import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn quick_start() -> Result(#(Int, String), table.EtsError) {
  // Create a counter table
  use counter <- result.try(helpers.new_counter("doc_helpers_page_views"))
  use count <- result.try(helpers.increment(counter, "homepage"))

  // Create a string-to-string cache
  use cache <- result.try(helpers.new_string_table("doc_helpers_user_cache"))

  Ok(#(count, table.table_name(cache)))
}

pub fn count_page_views() -> Result(List(Int), table.EtsError) {
  // Create counter
  use counter <- result.try(helpers.new_counter("doc_helpers_counter"))

  // Increment counters
  use first <- result.try(helpers.increment(counter, "homepage"))
  use second <- result.try(helpers.increment(counter, "homepage"))
  use about <- result.try(helpers.increment(counter, "about"))
  Ok([first, second, about])
}

pub fn counter_with_builder() -> Result(String, table.EtsError) {
  use counter <- result.try(
    config.new("doc_helpers_counter_builder")
    |> config.counter()
    |> config.create(),
  )
  Ok(table.table_name(counter))
}

pub fn cache_user() -> Result(option.Option(String), table.EtsError) {
  // Create cache
  use cache <- result.try(helpers.new_string_table("doc_helpers_cache"))

  // Use it
  use _ <- result.try(operations.set(cache, "user:123", "Alice"))
  operations.get(cache, "user:123")
}

pub fn string_table_with_builder() -> Result(String, table.EtsError) {
  use cache <- result.try(
    config.new("doc_helpers_cache_builder")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  Ok(table.table_name(cache))
}

pub fn count_requests() -> Result(List(Int), table.EtsError) {
  use counter <- result.try(helpers.new_counter("doc_helpers_metrics"))

  // The first increment creates the key with value 1
  use first <- result.try(helpers.increment(counter, "requests"))

  // Later increments add 1
  use second <- result.try(helpers.increment(counter, "requests"))
  use third <- result.try(helpers.increment(counter, "requests"))
  Ok([first, second, third])
}

pub fn add_points() -> Result(List(Int), table.EtsError) {
  use counter <- result.try(helpers.new_counter("doc_helpers_scores"))

  // Add 10 points
  use first <- result.try(helpers.increment_by(counter, "player1", 10))
  use second <- result.try(helpers.increment_by(counter, "player1", 10))

  // A negative amount subtracts
  use third <- result.try(helpers.increment_by(counter, "player1", -5))
  Ok([first, second, third])
}

pub fn use_widgets() -> Result(List(Int), table.EtsError) {
  use counter <- result.try(helpers.new_counter("doc_helpers_inventory"))

  // Set the initial value
  use _ <- result.try(operations.set(counter, "widgets", 100))

  // Decrement as items are used
  use first <- result.try(helpers.decrement(counter, "widgets"))
  use second <- result.try(helpers.decrement(counter, "widgets"))
  Ok([first, second])
}

pub fn deduct_api_calls() -> Result(List(Int), table.EtsError) {
  use counter <- result.try(helpers.new_counter("doc_helpers_quota"))

  // Set the initial quota
  use _ <- result.try(operations.set(counter, "api_calls", 1000))

  // Deduct a batch of API calls
  use first <- result.try(helpers.decrement_by(counter, "api_calls", 100))
  use second <- result.try(helpers.decrement_by(counter, "api_calls", 50))
  Ok([first, second])
}
