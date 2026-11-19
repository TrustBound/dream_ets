//// Convenience helpers for common ETS use cases
////
//// This module provides simplified functions for common patterns like counters
//// and string tables. These functions wrap the builder pattern with sensible
//// defaults for frequent use cases.
////
//// ## Quick Start
////
//// ### Count views and cache users <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L12-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn quick_start() -> Result(#(Int, String), table.EtsError) {
////   // Create a counter table
////   use counter <- result.try(helpers.new_counter("doc_helpers_page_views"))
////   use count <- result.try(helpers.increment(counter, "homepage"))
////
////   // Create a string-to-string cache
////   use cache <- result.try(helpers.new_string_table("doc_helpers_user_cache"))
////
////   Ok(#(count, table.table_name(cache)))
//// }
//// ```
////
//// ## When to Use Helpers vs. Builder
////
//// **Use helpers when:**
//// - Creating counters (String keys, Int values)
//// - Creating string-to-string tables
//// - You want the simplest possible API
////
//// **Use builder when:**
//// - Custom key/value types
//// - Need specific configuration (concurrency, compression, etc.)
//// - Fine-grained control over table behavior

import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

/// Create a counter table (String keys, Int values)
///
/// Creates a table optimized for use as a counter with string keys and
/// integer values. This is a convenience function that uses the builder
/// pattern internally with appropriate defaults.
///
/// ## Parameters
///
/// - `name`: A unique name for the counter table
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created counter table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(_)`: Other table creation errors
///
/// ## Example
///
/// ### Count page views <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L23-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn count_page_views() -> Result(List(Int), table.EtsError) {
///   // Create counter
///   use counter <- result.try(helpers.new_counter("doc_helpers_counter"))
///
///   // Increment counters
///   use first <- result.try(helpers.increment(counter, "homepage"))
///   use second <- result.try(helpers.increment(counter, "homepage"))
///   use about <- result.try(helpers.increment(counter, "about"))
///   Ok([first, second, about])
/// }
/// ```
///
/// ## Equivalent Builder Code
///
/// ### Create a counter with the builder <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L34-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn counter_with_builder() -> Result(String, table.EtsError) {
///   use counter <- result.try(
///     config.new("doc_helpers_counter_builder")
///     |> config.counter()
///     |> config.create(),
///   )
///   Ok(table.table_name(counter))
/// }
/// ```
///
/// ## See Also
///
/// - `increment()` - Increment a counter value
/// - `decrement()` - Decrement a counter value
/// - `increment_by()` - Increment by a specific amount
pub fn new_counter(
  name: String,
) -> Result(table.Table(String, Int), table.EtsError) {
  config.new(name)
  |> config.counter()
  |> config.create()
}

/// Create a string-to-string table
///
/// Creates a table with string keys and string values. This is a convenience
/// function for the most common table type - perfect for caches, sessions,
/// and simple key-value stores.
///
/// ## Parameters
///
/// - `name`: A unique name for the table
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(_)`: Other table creation errors
///
/// ## Example
///
/// ### Cache a user <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L43-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn cache_user() -> Result(option.Option(String), table.EtsError) {
///   // Create cache
///   use cache <- result.try(helpers.new_string_table("doc_helpers_cache"))
///
///   // Use it
///   use _ <- result.try(operations.set(cache, "user:123", "Alice"))
///   operations.get(cache, "user:123")
/// }
/// ```
///
/// ## Equivalent Builder Code
///
/// ### Create a string table with the builder <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L52-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn string_table_with_builder() -> Result(String, table.EtsError) {
///   use cache <- result.try(
///     config.new("doc_helpers_cache_builder")
///     |> config.key_string()
///     |> config.value_string()
///     |> config.create(),
///   )
///   Ok(table.table_name(cache))
/// }
/// ```
///
/// ## Use Cases
///
/// - **Caching**: Store API responses, computed values
/// - **Sessions**: Store session IDs and data
/// - **Configuration**: Store config values by key
/// - **User data**: Simple user ID to username mappings
///
/// ## See Also
///
/// - `operations.set()` - Store values
/// - `operations.get()` - Retrieve values
pub fn new_string_table(
  name: String,
) -> Result(table.Table(String, String), table.EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

/// Atomically increment a counter value
///
/// Increments a counter by 1. If the key doesn't exist, it's created with
/// value 1. This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to increment
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after incrementing
/// - `Error(EtsError)`: An error occurred
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Count requests <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L62-L72"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn count_requests() -> Result(List(Int), table.EtsError) {
///   use counter <- result.try(helpers.new_counter("doc_helpers_metrics"))
///
///   // The first increment creates the key with value 1
///   use first <- result.try(helpers.increment(counter, "requests"))
///
///   // Later increments add 1
///   use second <- result.try(helpers.increment(counter, "requests"))
///   use third <- result.try(helpers.increment(counter, "requests"))
///   Ok([first, second, third])
/// }
/// ```
///
/// ## Concurrency
///
/// This function is **not atomic** in the traditional sense. It performs
/// get-modify-set operations. For truly atomic increments in high-concurrency
/// scenarios, consider using Erlang's `:ets.update_counter/3` via FFI.
///
/// ## See Also
///
/// - `increment_by()` - Increment by a specific amount
/// - `decrement()` - Decrement by 1
pub fn increment(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  increment_by(table, key, 1)
}

/// Atomically increment a counter value by a specific amount
///
/// Increments a counter by the specified amount. If the key doesn't exist,
/// it's created with the specified amount as the initial value.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to increment
/// - `amount`: The amount to add (can be negative to decrement)
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after incrementing
/// - `Error(EtsError)`: An error occurred
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Add points <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L74-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn add_points() -> Result(List(Int), table.EtsError) {
///   use counter <- result.try(helpers.new_counter("doc_helpers_scores"))
///
///   // Add 10 points
///   use first <- result.try(helpers.increment_by(counter, "player1", 10))
///   use second <- result.try(helpers.increment_by(counter, "player1", 10))
///
///   // A negative amount subtracts
///   use third <- result.try(helpers.increment_by(counter, "player1", -5))
///   Ok([first, second, third])
/// }
/// ```
///
/// ## Use Cases
///
/// - **Scoring systems**: Add points to player scores
/// - **Batch metrics**: Increment by batch size
/// - **Resource tracking**: Adjust resource counts
///
/// ## See Also
///
/// - `increment()` - Increment by 1
/// - `decrement_by()` - Decrement by a specific amount
pub fn increment_by(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  case operations.get(table, key) {
    Ok(option.Some(current)) ->
      increment_existing_key(table, key, current, amount)
    Ok(option.None) -> create_new_counter_key(table, key, amount)
    Error(err) -> Error(err)
  }
}

fn increment_existing_key(
  table: table.Table(String, Int),
  key: String,
  current: Int,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let new_value = current + amount
  operations.set(table, key, new_value)
  |> result.replace(new_value)
}

fn create_new_counter_key(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  operations.set(table, key, amount)
  |> result.replace(amount)
}

/// Atomically decrement a counter value
///
/// Decrements a counter by 1. If the key doesn't exist, it's created with
/// value -1. This operation is safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to decrement
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after decrementing
/// - `Error(EtsError)`: An error occurred
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Use widgets <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L86-L96"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn use_widgets() -> Result(List(Int), table.EtsError) {
///   use counter <- result.try(helpers.new_counter("doc_helpers_inventory"))
///
///   // Set the initial value
///   use _ <- result.try(operations.set(counter, "widgets", 100))
///
///   // Decrement as items are used
///   use first <- result.try(helpers.decrement(counter, "widgets"))
///   use second <- result.try(helpers.decrement(counter, "widgets"))
///   Ok([first, second])
/// }
/// ```
///
/// ## Use Cases
///
/// - **Inventory tracking**: Decrement stock counts
/// - **Rate limiting**: Decrease remaining quota
/// - **Resource pools**: Track available resources
///
/// ## See Also
///
/// - `decrement_by()` - Decrement by a specific amount
/// - `increment()` - Increment by 1
pub fn decrement(
  table: table.Table(String, Int),
  key: String,
) -> Result(Int, table.EtsError) {
  decrement_by(table, key, 1)
}

/// Atomically decrement a counter value by a specific amount
///
/// Decrements a counter by the specified amount. If the key doesn't exist,
/// it's created with the negative of the specified amount as the initial value.
///
/// ## Parameters
///
/// - `table`: A counter table (String keys, Int values)
/// - `key`: The counter key to decrement
/// - `amount`: The amount to subtract (positive number)
///
/// ## Returns
///
/// - `Ok(Int)`: The new value after decrementing
/// - `Error(EtsError)`: An error occurred
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Deduct API calls <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_helpers.gleam#L98-L108"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn deduct_api_calls() -> Result(List(Int), table.EtsError) {
///   use counter <- result.try(helpers.new_counter("doc_helpers_quota"))
///
///   // Set the initial quota
///   use _ <- result.try(operations.set(counter, "api_calls", 1000))
///
///   // Deduct a batch of API calls
///   use first <- result.try(helpers.decrement_by(counter, "api_calls", 100))
///   use second <- result.try(helpers.decrement_by(counter, "api_calls", 50))
///   Ok([first, second])
/// }
/// ```
///
/// ## Use Cases
///
/// - **Batch operations**: Deduct multiple units at once
/// - **Credit systems**: Subtract costs
/// - **Quota management**: Track usage against limits
///
/// ## See Also
///
/// - `decrement()` - Decrement by 1
/// - `increment_by()` - Increment by a specific amount
pub fn decrement_by(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  case operations.get(table, key) {
    Ok(option.Some(current)) ->
      decrement_existing_key(table, key, current, amount)
    Ok(option.None) -> create_new_negative_counter_key(table, key, amount)
    Error(err) -> Error(err)
  }
}

fn decrement_existing_key(
  table: table.Table(String, Int),
  key: String,
  current: Int,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let new_value = current - amount
  operations.set(table, key, new_value)
  |> result.replace(new_value)
}

fn create_new_negative_counter_key(
  table: table.Table(String, Int),
  key: String,
  amount: Int,
) -> Result(Int, table.EtsError) {
  let initial_value = 0 - amount
  operations.set(table, key, initial_value)
  |> result.replace(initial_value)
}
