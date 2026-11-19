//// ETS table operations
////
//// This module provides all operations for working with ETS tables. Every
//// function is type-safe and returns `Result` to force explicit error handling.
////
//// ## Quick Start
////
//// ### Set, get and delete <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L16-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn crud() -> Result(option.Option(String), table.EtsError) {
////   // Create table
////   use cache <- result.try(helpers.new_string_table("doc_operations_crud"))
////
////   // Basic CRUD
////   use _ <- result.try(operations.set(cache, "user:123", "Alice"))
////   use _ <- result.try(operations.get(cache, "user:123"))
////   use _ <- result.try(operations.delete(cache, "user:123"))
////   operations.get(cache, "user:123")
//// }
//// ```
////
//// ## Operation Categories
////
//// ### Basic Operations
////
//// - `set()` - Insert or update a key-value pair
//// - `get()` - Retrieve a value by key
//// - `delete()` - Remove a key-value pair
//// - `member()` - Check if a key exists
////
//// ### Advanced Operations
////
//// - `insert_new()` - Insert only if key doesn't exist
//// - `take()` - Get and remove atomically
//// - `update_element()` - Update tuple elements in-place
////
//// ### Bulk Operations
////
//// - `keys()` - Get all keys
//// - `values()` - Get all values
//// - `to_list()` - Get all key-value pairs
//// - `size()` - Count entries
////
//// ### Table Management
////
//// - `delete_table()` - Remove the entire table
//// - `delete_all_objects()` - Clear all entries
////
//// ### Persistence
////
//// - `save_to_file()` - Save table to disk
//// - `load_from_file()` - Load table from disk
////
//// ### Advanced (Low-level)
////
//// - `match()` - Pattern matching
//// - `match_object()` - Object pattern matching
//// - `select()` - SQL-like queries with match specifications
////
//// ## Error Handling
////
//// All operations return `Result(_, EtsError)`. Common errors:
////
//// - `TableNotFound` - Table was deleted
//// - `DecodeError` - Failed to decode value
//// - `EncodeError` - Failed to encode value
//// - `OperationFailed` - General operation failure
////
//// ## Performance Notes
////
//// - `set()`, `get()`, `delete()` - O(1) constant time
//// - `keys()`, `values()`, `to_list()` - O(n) iterates entire table
//// - `size()` - O(n) counts by iterating (no cached counter)
////
//// ## Concurrency
////
//// All operations are safe for concurrent access. Enable `read_concurrency`
//// and `write_concurrency` in table configuration for better performance
//// under high concurrent load.

import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result

/// Insert or update a key-value pair in the table
///
/// Sets a key-value pair in the table. If the key already exists, the value
/// is updated. If the key doesn't exist, it's created.
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to set
/// - `value`: The value to associate with the key
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully set the key-value pair
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Set and replace a value <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L27-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn set_twice(
///   users: table.Table(String, String),
/// ) -> Result(Nil, table.EtsError) {
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   // Replaces the existing value
///   operations.set(users, "user:123", "Bob")
/// }
/// ```
pub fn set(
  table: table.Table(k, v),
  key: k,
  value: v,
) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let encoded_value = table.encode_value(table, value)
  let object = #(encoded_key, encoded_value)
  let table_ref = table.table_ref(table)

  internal.insert(table_ref, internal.to_dynamic(object))
  |> result.map_error(ffi_error_to_ets_error)
}

/// Lookup a value by key
///
/// Retrieves the value associated with a key. Returns `None` if the key
/// doesn't exist, or `Some(value)` if it does.
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to query
/// - `key`: The key to look up
///
/// ## Returns
///
/// - `Ok(Some(value))`: Key exists, returns the value
/// - `Ok(None)`: Key doesn't exist
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(DecodeError(error))`: The stored value could not be decoded
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### Handle each lookup result <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L35-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn describe_user(
///   users: table.Table(String, String),
///   key: String,
/// ) -> String {
///   case operations.get(users, key) {
///     Ok(option.Some(name)) -> "Found: " <> name
///     Ok(option.None) -> "User not found"
///     Error(error) -> "Lookup failed: " <> string.inspect(error)
///   }
/// }
/// ```
pub fn get(
  table: table.Table(k, v),
  key: k,
) -> Result(option.Option(v), table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.lookup(table_ref, encoded_key) {
    Ok(dyn_object) -> decode_lookup_result(table, dyn_object)
    Error(internal.NotFound) -> Ok(option.None)
    Error(err) -> Error(ffi_error_to_ets_error(err))
  }
}

/// Delete a key from the table
///
/// Removes a key-value pair from the table. If the key doesn't exist,
/// this is a no-op (no error).
///
/// This operation is atomic and safe for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to delete
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully deleted (or key didn't exist)
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Delete a key <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L46-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn remove_user(
///   users: table.Table(String, String),
/// ) -> Result(Nil, table.EtsError) {
///   operations.delete(users, "user:123")
/// }
/// ```
pub fn delete(table: table.Table(k, v), key: k) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.delete_key(table_ref, encoded_key)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Check if a key exists in the table
///
/// Returns `Ok(True)` if the key exists in the table, `Ok(False)` otherwise.
/// This is more efficient than `get()` when you only need to check existence
/// without retrieving the value.
///
/// ## Parameters
///
/// - `table`: The table to query
/// - `key`: The key to check
///
/// ## Returns
///
/// - `Ok(True)`: Key exists in the table
/// - `Ok(False)`: Key doesn't exist
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### Check whether a user exists <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_member.gleam#L11-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn describe_user(
///   users: table.Table(String, String),
///   user_id: String,
/// ) -> String {
///   case operations.member(users, user_id) {
///     Ok(True) -> user_id <> " exists"
///     Ok(False) -> user_id <> " does not exist"
///     Error(table.TableNotFound) -> "The table was deleted"
///     Error(other) -> "Check failed: " <> string.inspect(other)
///   }
/// }
/// ```
///
/// ## Performance
///
/// `member()` is faster than `get()` because it doesn't need to decode
/// the value. Use it when you only care about existence.
///
/// ## See Also
///
/// - `get()` - Retrieve the value if you need it
/// - `insert_new()` - Insert only if key doesn't exist
pub fn member(
  table: table.Table(k, v),
  key: k,
) -> Result(Bool, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  internal.member(table_ref, encoded_key)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Delete the entire table
///
/// Permanently deletes the table and all its data. After calling this,
/// the table cannot be used for any operations.
///
/// ## Parameters
///
/// - `table`: The table to delete
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully deleted
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   already deleted)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process does not own the table)
///
/// ## Example
///
/// ### Delete a table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L52-L56"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn drop_table(
///   users: table.Table(String, String),
/// ) -> Result(Nil, table.EtsError) {
///   operations.delete_table(users)
/// }
/// ```
pub fn delete_table(table: table.Table(k, v)) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.delete_table(table_ref)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Get the number of objects in the table
///
/// Returns the total number of key-value pairs in the table.
///
/// ## Parameters
///
/// - `table`: The table to count
///
/// ## Returns
///
/// - `Ok(Int)`: The number of entries in the table (>= 0)
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(DecodeError)`: A key failed to decode during iteration
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### Show the table size <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L58-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn describe_size(users: table.Table(String, String)) -> String {
///   case operations.size(users) {
///     Ok(count) -> "Table has " <> int.to_string(count) <> " entries"
///     Error(error) -> "Size failed: " <> string.inspect(error)
///   }
/// }
/// ```
///
/// ## Performance Warning
///
/// **This function is O(n)** - it iterates through all keys to count them.
/// For large tables (>10,000 entries), this can be slow.
///
/// ### Better Alternatives for Large Tables
///
/// If you need frequent size checks on large tables, maintain a counter:
///
/// ### Track the size with a counter <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L65-L81"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn track_size(
///   cache: table.Table(String, String),
///   stats: table.Table(String, Int),
/// ) -> Result(option.Option(Int), table.EtsError) {
///   // Increment on insert
///   use _ <- result.try(operations.set(cache, "user:1", "Ada"))
///   use _ <- result.try(helpers.increment(stats, "size"))
///   use _ <- result.try(operations.set(cache, "user:2", "Grace"))
///   use _ <- result.try(helpers.increment(stats, "size"))
///
///   // Decrement on delete
///   use _ <- result.try(operations.delete(cache, "user:1"))
///   use _ <- result.try(helpers.decrement(stats, "size"))
///
///   // Fast O(1) size lookup
///   operations.get(stats, "size")
/// }
/// ```
///
/// ## See Also
///
/// - `keys()` - If you need the keys anyway
/// - `member()` - Check single key existence (O(1))
pub fn size(table: table.Table(k, v)) -> Result(Int, table.EtsError) {
  // Simple implementation: count the keys
  use all_keys <- result.try(keys(table))
  Ok(list.length(all_keys))
}

/// Get all keys from the table
///
/// Returns a list of all keys in the table. The order is undefined and
/// may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables. Consider using iteration patterns if
/// you don't need all keys at once.
///
/// ## Parameters
///
/// - `table`: The table to get keys from
///
/// ## Returns
///
/// - `Ok(List)`: All keys successfully decoded
/// - `Error(DecodeError)`: A key failed to decode (data corruption or encoder mismatch)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### List the keys <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L83-L88"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn list_keys(users: table.Table(String, String)) -> List(String) {
///   case operations.keys(users) {
///     Ok(all_keys) -> list.map(all_keys, fn(key) { "Key: " <> key })
///     Error(error) -> ["Keys failed: " <> string.inspect(error)]
///   }
/// }
/// ```
pub fn keys(table: table.Table(k, v)) -> Result(List(k), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_keys(table, table_ref)
}

/// Get all values from the table
///
/// Returns a list of all values in the table. The order is undefined and
/// may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables. Consider using iteration patterns if
/// you don't need all values at once.
///
/// ## Parameters
///
/// - `table`: The table to get values from
///
/// ## Returns
///
/// - `Ok(List)`: All values successfully decoded
/// - `Error(DecodeError)`: A value failed to decode (data corruption or encoder mismatch)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### Use every value <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L90-L96"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn count_characters(users: table.Table(String, String)) -> Int {
///   case operations.values(users) {
///     Ok(all_values) ->
///       list.fold(all_values, 0, fn(total, value) { total + string.length(value) })
///     Error(_) -> 0
///   }
/// }
/// ```
pub fn values(table: table.Table(k, v)) -> Result(List(v), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_values(table, table_ref)
}

/// Convert table to a list of key-value pairs
///
/// Returns a list of all key-value pairs in the table as tuples.
/// The order is undefined and may vary between calls.
///
/// **Performance Note**: This function iterates the entire table, which
/// can be slow for large tables.
///
/// ## Parameters
///
/// - `table`: The table to convert
///
/// ## Returns
///
/// - `Ok(List)`: All key-value pairs successfully decoded
/// - `Error(DecodeError)`: A key or value failed to decode (data corruption or encoder mismatch)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot read the table)
///
/// ## Example
///
/// ### List the pairs <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L98-L103"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn list_pairs(users: table.Table(String, String)) -> List(String) {
///   case operations.to_list(users) {
///     Ok(pairs) -> list.map(pairs, fn(pair) { pair.0 <> " => " <> pair.1 })
///     Error(error) -> ["List failed: " <> string.inspect(error)]
///   }
/// }
/// ```
pub fn to_list(
  table: table.Table(k, v),
) -> Result(List(#(k, v)), table.EtsError) {
  let table_ref = table.table_ref(table)
  collect_all_pairs(table, table_ref)
}

/// Insert only if the key doesn't exist
///
/// Atomically inserts a key-value pair only if the key doesn't already exist.
/// This is the atomic equivalent of "check then insert" and is safe for
/// concurrent access without race conditions.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to insert
/// - `value`: The value to associate with the key
///
/// ## Returns
///
/// - `Ok(True)`: Key was inserted successfully (didn't exist before)
/// - `Ok(False)`: Key already existed, no change made
/// - `Error(TableNotFound)`: The table does not exist (for example, it was
///   deleted)
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Create a user once <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L105-L111"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn create_user(users: table.Table(String, String)) -> String {
///   case operations.insert_new(users, "user:123", "Alice") {
///     Ok(True) -> "User created"
///     Ok(False) -> "User already exists"
///     Error(error) -> "Insert failed: " <> string.inspect(error)
///   }
/// }
/// ```
///
/// ## Use Cases
///
/// ### Preventing Duplicate Registrations <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L113-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn register_user(
///   users: table.Table(String, String),
///   user_id: String,
///   name: String,
/// ) -> Result(String, String) {
///   case operations.insert_new(users, user_id, name) {
///     Ok(True) -> Ok("User registered")
///     Ok(False) -> Error("User ID already taken")
///     Error(error) -> Error("Database error: " <> string.inspect(error))
///   }
/// }
/// ```
///
/// ### Distributed Locks <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L125-L135"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn acquire_lock(
///   locks: table.Table(String, String),
///   resource_id: String,
///   owner_id: String,
/// ) -> Result(String, String) {
///   case operations.insert_new(locks, resource_id, owner_id) {
///     Ok(True) -> Ok("Lock acquired")
///     Ok(False) -> Error("Resource locked by another process")
///     Error(error) -> Error("Lock system error: " <> string.inspect(error))
///   }
/// }
/// ```
///
/// ## Why Not Use `member()` + `set()`?
///
/// ### Member and set, compared with insert_new <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_insert_new_race.gleam#L10-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Race condition: another process can insert the key between the two calls
/// pub fn insert_if_missing_with_member(
///   users: table.Table(String, String),
///   key: String,
///   value: String,
/// ) -> Result(Bool, table.EtsError) {
///   use exists <- result.try(operations.member(users, key))
///   case exists {
///     True -> Ok(False)
///     False -> operations.set(users, key, value) |> result.replace(True)
///   }
/// }
///
/// // Atomic: safe for concurrent access
/// pub fn insert_if_missing(
///   users: table.Table(String, String),
///   key: String,
///   value: String,
/// ) -> Result(Bool, table.EtsError) {
///   operations.insert_new(users, key, value)
/// }
/// ```
///
/// ## See Also
///
/// - `set()` - Insert or update (always succeeds)
/// - `member()` - Check existence only
pub fn insert_new(
  table: table.Table(k, v),
  key: k,
  value: v,
) -> Result(Bool, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let encoded_value = table.encode_value(table, value)
  let object = #(encoded_key, encoded_value)
  let table_ref = table.table_ref(table)

  internal.insert_new(table_ref, internal.to_dynamic(object))
  |> result.map_error(ffi_error_to_ets_error)
}

/// Lookup and delete a key-value pair atomically
///
/// Retrieves a value and removes it from the table in a single atomic operation.
/// This is safer than separate `get()` + `delete()` calls for concurrent access.
///
/// ## Parameters
///
/// - `table`: The table to modify
/// - `key`: The key to take and remove
///
/// ## Returns
///
/// - `Ok(Some(value))`: Key existed, returns the value (now removed from table)
/// - `Ok(None)`: Key didn't exist (table unchanged)
/// - `Error(EtsError)`: An error occurred during retrieval or deletion
/// - `Error(OperationFailed("ETS refused the operation: badarg"))`: The table
///   exists, but ETS refused the operation (for example, the calling
///   process cannot write to the table)
///
/// ## Example
///
/// ### Take a job <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L137-L144"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn take_job(jobs: table.Table(String, String)) -> String {
///   case operations.take(jobs, "job:123") {
///     // The job is now removed from the queue
///     Ok(option.Some(job)) -> "Processing " <> job
///     Ok(option.None) -> "Job not found"
///     Error(error) -> "Take failed: " <> string.inspect(error)
///   }
/// }
/// ```
///
/// ## Use Cases
///
/// ### Work Queue <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L146-L157"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn claim_next_job(
///   queue: table.Table(String, String),
///   worker_id: String,
/// ) -> String {
///   case operations.take(queue, "next_job") {
///     // This worker claimed the job atomically
///     Ok(option.Some(job)) -> worker_id <> " claimed " <> job
///     // No jobs available
///     Ok(option.None) -> worker_id <> " found no job"
///     Error(error) -> "Queue error: " <> string.inspect(error)
///   }
/// }
/// ```
///
/// ### Cache Eviction <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L159-L168"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn evict_entry(
///   cache: table.Table(String, String),
///   key: String,
/// ) -> Result(String, String) {
///   case operations.take(cache, key) {
///     Ok(option.Some(old_value)) -> Ok(old_value)
///     Ok(option.None) -> Error("Key not in cache")
///     Error(error) -> Error("Cache error: " <> string.inspect(error))
///   }
/// }
/// ```
///
/// ### Token Consumption <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L170-L180"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn use_token(
///   tokens: table.Table(String, String),
///   token_id: String,
/// ) -> Result(String, String) {
///   case operations.take(tokens, token_id) {
///     // A token can be used only once
///     Ok(option.Some(token_data)) -> Ok(token_data)
///     Ok(option.None) -> Error("Invalid or already used token")
///     Error(error) -> Error("Token system error: " <> string.inspect(error))
///   }
/// }
/// ```
///
/// ## Why Not Use `get()` + `delete()`?
///
/// ### get and delete, compared with take <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L182-L198"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Race condition: another process can change the value between get and delete
/// pub fn get_then_delete(
///   cache: table.Table(String, String),
///   key: String,
/// ) -> Result(option.Option(String), table.EtsError) {
///   use value <- result.try(operations.get(cache, key))
///   use _ <- result.try(operations.delete(cache, key))
///   Ok(value)
/// }
///
/// // Atomic: get and delete in one operation
/// pub fn take_value(
///   cache: table.Table(String, String),
///   key: String,
/// ) -> Result(option.Option(String), table.EtsError) {
///   operations.take(cache, key)
/// }
/// ```
///
/// ## See Also
///
/// - `get()` - Retrieve without deleting
/// - `delete()` - Delete without retrieving
/// - `insert_new()` - Insert only if doesn't exist
pub fn take(
  table: table.Table(k, v),
  key: k,
) -> Result(option.Option(v), table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.take(table_ref, encoded_key) {
    Ok(dyn_object) -> decode_take_result(table, dyn_object)
    Error(internal.NotFound) -> Ok(option.None)
    Error(err) -> Error(ffi_error_to_ets_error(err))
  }
}

/// Replace one element of the object stored under a key
///
/// Changes the element at position `pos` of the stored object in place. The
/// object of a table is `{key, value}`, so position 2 is the value. The new
/// element is a `Dynamic`, so the decoder of the table must be able to read it.
/// This is a low-level function. Most code uses `set` instead.
///
/// ## Parameters
///
/// - `table`: The table to update
/// - `key`: The key of the object
/// - `pos`: The 1-based position of the element to replace
/// - `value`: The new element
///
/// ## Returns
///
/// `Ok(Nil)` when the element was replaced.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist, or no object has this key
/// - `OperationFailed("ETS refused the operation: badarg")`: The table exists,
///   but ETS refused the operation (for example, the calling process cannot
///   write to the table, or `pos` is not a position of the object)
///
/// ## Example
///
/// ### Replace a value in place <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L200-L212"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn replace_value(
///   users: table.Table(String, String),
/// ) -> Result(option.Option(String), table.EtsError) {
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   // Position 2 is the value in the {key, value} object
///   use _ <- result.try(operations.update_element(
///     users,
///     "user:123",
///     2,
///     dynamic.string("Bob"),
///   ))
///   operations.get(users, "user:123")
/// }
/// ```
///
/// ## See Also
///
/// - `set()` - Store a whole value
/// - [ets:update_element/3](https://www.erlang.org/doc/apps/stdlib/ets.html#update_element/3)
pub fn update_element(
  table: table.Table(k, v),
  key: k,
  pos: Int,
  value: dynamic.Dynamic,
) -> Result(Nil, table.EtsError) {
  let encoded_key = table.encode_key(table, key)
  let table_ref = table.table_ref(table)

  case internal.update_element(table_ref, encoded_key, pos, value) {
    Ok(_) -> Ok(Nil)
    Error(internal.NotFound) -> Error(table.TableNotFound)
    Error(error) -> Error(ffi_error_to_ets_error(error))
  }
}

/// Delete every object from the table
///
/// Removes all objects and keeps the table, so you can use it again.
///
/// ## Parameters
///
/// - `table`: The table to clear
///
/// ## Returns
///
/// `Ok(Nil)` when the table is empty.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist (for example, it was deleted)
/// - `OperationFailed("ETS refused the operation: badarg")`: The table exists,
///   but ETS refused the operation (for example, the calling process cannot
///   write to the table)
///
/// ## Example
///
/// ### Clear a cache <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L214-L221"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn clear_cache(
///   cache: table.Table(String, String),
/// ) -> Result(Int, table.EtsError) {
///   use _ <- result.try(operations.set(cache, "a", "1"))
///   use _ <- result.try(operations.delete_all_objects(cache))
///   // The table still exists, and it is empty
///   operations.size(cache)
/// }
/// ```
///
/// ## See Also
///
/// - `delete()` - Delete one key
/// - `delete_table()` - Delete the whole table
pub fn delete_all_objects(
  table: table.Table(k, v),
) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.delete_all_objects(table_ref)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Find the objects that match an Erlang match pattern
///
/// Returns the bound variables (`'$1'`, `'$2'`, ...) of each matching object,
/// as one list for each object. This is a low-level function. Most code uses
/// `get`, `keys` or `values` instead.
///
/// ## Parameters
///
/// - `table`: The table to search
/// - `pattern`: An Erlang match pattern as a `Dynamic`
///
/// ## Returns
///
/// `Ok` with the bound variables of each matching object.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist (for example, it was deleted)
/// - `OperationFailed("ETS refused the operation: badarg")`: The table exists,
///   but ETS refused the operation (for example, the calling process cannot
///   read the table)
///
/// ## Example
///
/// ### Bind the key and the value of each object <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L223-L233"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn match_pairs(
///   users: table.Table(String, String),
/// ) -> Result(List(dynamic.Dynamic), table.EtsError) {
///   // The pattern {'$1', '$2'} binds the key and the value of each object
///   let pattern =
///     dynamic.array([
///       atom.to_dynamic(atom.create("$1")),
///       atom.to_dynamic(atom.create("$2")),
///     ])
///   operations.match(users, pattern)
/// }
/// ```
///
/// ## See Also
///
/// - `match_object()` - Return the whole objects
/// - [ets:match/2](https://www.erlang.org/doc/apps/stdlib/ets.html#match/2)
pub fn match(
  table: table.Table(k, v),
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.match(table_ref, pattern)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Find the whole objects that match an Erlang match pattern
///
/// Returns each matching `{key, value}` object. This is a low-level function.
/// Most code uses `get` or `to_list` instead.
///
/// ## Parameters
///
/// - `table`: The table to search
/// - `pattern`: An Erlang match pattern as a `Dynamic`
///
/// ## Returns
///
/// `Ok` with each matching object.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist (for example, it was deleted)
/// - `OperationFailed("ETS refused the operation: badarg")`: The table exists,
///   but ETS refused the operation (for example, the calling process cannot
///   read the table)
///
/// ## Example
///
/// ### Find the objects with one value <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L235-L242"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn match_alice(
///   users: table.Table(String, String),
/// ) -> Result(List(dynamic.Dynamic), table.EtsError) {
///   // The pattern {'_', <<"Alice">>} matches every object with the value Alice
///   let pattern =
///     dynamic.array([atom.to_dynamic(atom.create("_")), dynamic.string("Alice")])
///   operations.match_object(users, pattern)
/// }
/// ```
///
/// ## See Also
///
/// - `match()` - Return only the bound variables
/// - [ets:match_object/2](https://www.erlang.org/doc/apps/stdlib/ets.html#match_object/2)
pub fn match_object(
  table: table.Table(k, v),
  pattern: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.match_object(table_ref, pattern)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Query the table with an Erlang match specification
///
/// Returns the result of the match specification for each matching object.
/// This is a low-level function for complex queries.
///
/// ## Parameters
///
/// - `table`: The table to query
/// - `match_spec`: An Erlang match specification as a `Dynamic`
///
/// ## Returns
///
/// `Ok` with the results of the match specification.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist (for example, it was deleted)
/// - `OperationFailed("ETS refused the operation: badarg")`: The table exists,
///   but ETS refused the operation (for example, the calling process cannot
///   read the table, or the match specification is not valid)
///
/// ## Example
///
/// ### Select every value <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L244-L260"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn select_values(
///   users: table.Table(String, String),
/// ) -> Result(List(dynamic.Dynamic), table.EtsError) {
///   // [{{'$1', '$2'}, [], ['$2']}] returns the value of each object
///   let match_spec =
///     dynamic.list([
///       dynamic.array([
///         dynamic.array([
///           atom.to_dynamic(atom.create("$1")),
///           atom.to_dynamic(atom.create("$2")),
///         ]),
///         dynamic.list([]),
///         dynamic.list([atom.to_dynamic(atom.create("$2"))]),
///       ]),
///     ])
///   operations.select(users, match_spec)
/// }
/// ```
///
/// ## See Also
///
/// - `match()` - Use a match pattern
/// - [ets:select/2](https://www.erlang.org/doc/apps/stdlib/ets.html#select/2)
pub fn select(
  table: table.Table(k, v),
  match_spec: dynamic.Dynamic,
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.select(table_ref, match_spec)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Save the table to a file
///
/// Writes every object of the table to `filename` with `ets:tab2file/2`. Load
/// the file again with `load_from_file`.
///
/// ## Parameters
///
/// - `table`: The table to save
/// - `filename`: The path of the file to write
///
/// ## Returns
///
/// `Ok(Nil)` when the file is written.
///
/// ## Errors
///
/// - `TableNotFound`: The table does not exist (for example, it was deleted)
/// - `OperationFailed(reason)`: The file could not be written, or the calling
///   process cannot read the table. The reason is the Erlang error, for example
///   `{file_error,"/missing/table.ets",enoent}`
///
/// ## Example
///
/// ### Save a table and load it again <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L262-L272"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn save_and_load(
///   users: table.Table(String, String),
///   filename: String,
/// ) -> Result(option.Option(String), table.EtsError) {
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   use _ <- result.try(operations.save_to_file(users, filename))
///   use _ <- result.try(operations.delete_table(users))
///   use _ <- result.try(operations.load_from_file(filename))
///   // The loaded table has the same name, so `users` finds it again
///   operations.get(users, "user:123")
/// }
/// ```
///
/// ## See Also
///
/// - `load_from_file()` - Load the file again
pub fn save_to_file(
  table: table.Table(k, v),
  filename: String,
) -> Result(Nil, table.EtsError) {
  let table_ref = table.table_ref(table)
  internal.tab2file(table_ref, filename)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Load a table from a file
///
/// Creates the table that `save_to_file` wrote, with the same name and the same
/// objects. It returns a raw table reference without type information. A named
/// table is found by its name, so a `Table` value that you made for that name
/// reads the loaded table.
///
/// ## Parameters
///
/// - `filename`: The path of the file to read
///
/// ## Returns
///
/// `Ok` with the reference of the loaded table.
///
/// ## Errors
///
/// - `OperationFailed(reason)`: The file could not be read, or a table with
///   the same name exists (`cannot_create_table`). The reason is the Erlang error.
///
/// ## Example
///
/// ### Save a table and load it again <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_operations.gleam#L262-L272"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn save_and_load(
///   users: table.Table(String, String),
///   filename: String,
/// ) -> Result(option.Option(String), table.EtsError) {
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   use _ <- result.try(operations.save_to_file(users, filename))
///   use _ <- result.try(operations.delete_table(users))
///   use _ <- result.try(operations.load_from_file(filename))
///   // The loaded table has the same name, so `users` finds it again
///   operations.get(users, "user:123")
/// }
/// ```
///
/// ## See Also
///
/// - `save_to_file()` - Write the file
pub fn load_from_file(
  filename: String,
) -> Result(internal.EtsTableRef, table.EtsError) {
  internal.file2tab(filename)
  |> result.map_error(ffi_error_to_ets_error)
}

/// Converts an FFI error to the public `EtsError`. Each caller first handles
/// the FFI errors that have a meaning of their own for it (`NotFound`,
/// `EmptyTable`, `EndOfTable`), so only `TableNotFound` and
/// `InvalidOperation` arrive here.
fn ffi_error_to_ets_error(error: internal.EtsFfiError) -> table.EtsError {
  case error {
    internal.InvalidOperation(message) -> table.OperationFailed(message)
    _ -> table.TableNotFound
  }
}

// Private helper functions

fn decode_lookup_result(
  table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case extract_value_from_tuple(table, dyn_object) {
    Ok(dyn_value) -> decode_value_to_option(table, dyn_value)
    Error(err) -> Error(err)
  }
}

fn decode_take_result(
  table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case extract_value_from_tuple(table, dyn_object) {
    Ok(dyn_value) -> decode_value_to_option(table, dyn_value)
    Error(err) -> Error(err)
  }
}

fn extract_value_from_tuple(
  _table: table.Table(k, v),
  dyn_object: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, table.EtsError) {
  // ETS returns tuples as {Key, Value} in Erlang
  // When decoded through Dynamic, we need to extract the second element (index 1)
  // Use decode.at to access tuple elements
  decode.run(dyn_object, decode.at([1], decode.dynamic))
  |> result.map_error(first_decode_error)
}

/// A failed decode always reports at least one error. The fallback value
/// only makes the function total.
fn first_decode_error(errors: List(decode.DecodeError)) -> table.EtsError {
  errors
  |> list.first
  |> result.unwrap(decode.DecodeError("tuple", "failed to extract value", []))
  |> table.DecodeError
}

fn decode_value_to_option(
  table: table.Table(k, v),
  dyn_value: dynamic.Dynamic,
) -> Result(option.Option(v), table.EtsError) {
  case table.decode_value(table, dyn_value) {
    Ok(value) -> Ok(option.Some(value))
    Error(decode_err) -> Error(table.DecodeError(decode_err))
  }
}

fn collect_all_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(k), table.EtsError) {
  case internal.first_key(table_ref) {
    Ok(first_dyn_key) ->
      collect_keys_from_first(table, table_ref, first_dyn_key)
    Error(internal.EmptyTable) -> Ok([])
    Error(err) -> Error(ffi_error_to_ets_error(err))
  }
}

fn collect_keys_from_first(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  first_dyn_key: dynamic.Dynamic,
) -> Result(List(k), table.EtsError) {
  case table.decode_key(table, first_dyn_key) {
    Ok(first_key) ->
      collect_remaining_keys(table, table_ref, first_dyn_key, [first_key])
    Error(decode_err) -> Error(table.DecodeError(decode_err))
  }
}

fn collect_remaining_keys(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
  current_dyn_key: dynamic.Dynamic,
  acc: List(k),
) -> Result(List(k), table.EtsError) {
  case internal.next_key(table_ref, current_dyn_key) {
    Error(internal.EndOfTable) -> Ok(acc)
    // Another error comes only when a second process deletes the table
    // during the walk.
    next -> {
      use next_dyn_key <- result.try(result.map_error(
        next,
        ffi_error_to_ets_error,
      ))
      case table.decode_key(table, next_dyn_key) {
        Ok(next_key) ->
          collect_remaining_keys(table, table_ref, next_dyn_key, [
            next_key,
            ..acc
          ])
        Error(decode_err) -> Error(table.DecodeError(decode_err))
      }
    }
  }
}

fn collect_all_values(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(v), table.EtsError) {
  use keys_list <- result.try(collect_all_keys(table, table_ref))
  collect_values_for_keys(table, keys_list, [])
}

fn collect_values_for_keys(
  table: table.Table(k, v),
  keys: List(k),
  acc: List(v),
) -> Result(List(v), table.EtsError) {
  case keys {
    [] -> Ok(list.reverse(acc))
    [key, ..rest] -> {
      use value <- result.try(get(table, key))
      case value {
        option.Some(v) -> collect_values_for_keys(table, rest, [v, ..acc])
        option.None ->
          Error(table.OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          ))
      }
    }
  }
}

fn collect_all_pairs(
  table: table.Table(k, v),
  table_ref: internal.EtsTableRef,
) -> Result(List(#(k, v)), table.EtsError) {
  use keys_list <- result.try(collect_all_keys(table, table_ref))
  collect_pairs_for_keys(table, keys_list, [])
}

fn collect_pairs_for_keys(
  table: table.Table(k, v),
  keys: List(k),
  acc: List(#(k, v)),
) -> Result(List(#(k, v)), table.EtsError) {
  case keys {
    [] -> Ok(list.reverse(acc))
    [key, ..rest] -> {
      use value <- result.try(get(table, key))
      case value {
        option.Some(v) ->
          collect_pairs_for_keys(table, rest, [#(key, v), ..acc])
        option.None ->
          Error(table.OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          ))
      }
    }
  }
}
