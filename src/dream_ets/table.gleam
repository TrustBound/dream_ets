//// Core ETS table type and error types
////
//// This module provides the core `Table` type and error handling for ETS
//// (Erlang Term Storage) operations. ETS provides in-memory key-value storage
//// that's fast, concurrent, and process-safe.
////
//// ## Quick Start
////
//// ### Create tables <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L15-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn create_tables() -> Result(#(String, String), table.EtsError) {
////   // Create a table using the builder
////   use cache <- result.try(
////     config.new("doc_table_cache")
////     |> config.key_string()
////     |> config.value_string()
////     |> config.create(),
////   )
////
////   // Or use convenience functions
////   use counter <- result.try(helpers.new_counter("doc_table_counts"))
////
////   Ok(#(table.table_name(cache), table.table_name(counter)))
//// }
//// ```
////
//// ## Type Safety
////
//// Tables are parameterized over their key and value types, ensuring type
//// safety at compile time. The encoder/decoder functions handle conversion
//// to/from Erlang's dynamic types for storage.

import dream_errors.{type Error, Conflict, Failed, Invalid, NotFound}
import dream_ets/internal.{type EtsTableRef}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder, run}
import gleam/list.{first}
import gleam/result.{map_error, unwrap}

/// Type-safe ETS table
///
/// Represents an ETS table with type-safe key and value types. The table
/// stores encoder/decoder functions to convert between Gleam types and
/// Erlang's dynamic types for storage.
///
/// Tables are opaque - you cannot construct them directly. Use the builder
/// pattern in `dream_ets/config` or convenience functions in `dream_ets/helpers`
/// to create tables.
///
/// ## Type Parameters
///
/// - `key`: The type of keys stored in the table
/// - `value`: The type of values stored in the table
///
/// ## Example
///
/// ### Use typed operations <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L30-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn typed_operations() -> Result(option.Option(String), table.EtsError) {
///   // Create a string-to-string table
///   use cache <- result.try(
///     config.new("doc_table_typed")
///     |> config.key_string()
///     |> config.value_string()
///     |> config.create(),
///   )
///
///   // Type-safe operations
///   use _ <- result.try(operations.set(cache, "user:123", "Alice"))
///   // operations.set(cache, 123, "Alice") does not compile: 123 is not a String
///   operations.get(cache, "user:123")
/// }
/// ```
pub opaque type Table(key, value) {
  Table(
    table_ref: EtsTableRef,
    name: String,
    key_encoder: fn(key) -> Dynamic,
    key_decoder: Decoder(key),
    value_encoder: fn(value) -> Dynamic,
    value_decoder: Decoder(value),
  )
}

/// ETS operation error types
///
/// Represents errors that can occur during ETS operations. All operations
/// return `Result(_, EtsError)` to force error handling.
///
/// ## Variants
///
/// - `TableNotFound`: The table does not exist, or it was deleted
/// - `TableAlreadyExists`: A table with this name already exists
/// - `InvalidKey`: The configuration has no key encoder
/// - `InvalidValue`: The configuration has no value encoder
/// - `DecodeError(DecodeError)`: A key or value in the table does not decode
///   with the decoder of the table
/// - `OperationFailed(String)`: An ETS operation failed; the message gives
///   the reason
pub type EtsError {
  /// The table does not exist, or it was deleted.
  TableNotFound
  /// A table with this name already exists.
  TableAlreadyExists
  /// The configuration has no key encoder.
  InvalidKey
  /// The configuration has no value encoder.
  InvalidValue
  /// A key or value in the table does not decode with the decoder of the table.
  DecodeError(decode.DecodeError)
  /// An ETS operation failed. The message gives the reason.
  OperationFailed(String)
}

/// Maps an `EtsError` to the shared error of the Dream packages, and keeps
/// the `EtsError` as the cause.
///
/// - `TableNotFound` gives `NotFound`
/// - `TableAlreadyExists` gives `Conflict`
/// - `InvalidKey` and `InvalidValue` give `Invalid`
/// - `DecodeError` and `OperationFailed` give `Failed`
///
/// The message is text for developers and logs, not for the users of an app.
///
/// ## Example
///
/// ### Map a lookup error to the shared error <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_to_error.gleam#L12-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn find_name(
///   users: Table(String, String),
///   user_id: String,
/// ) -> Result(Option(String), Error(EtsError)) {
///   get(users, user_id)
///   |> map_error(to_error)
/// }
/// ```
pub fn to_error(error: EtsError) -> Error(EtsError) {
  case error {
    TableNotFound -> NotFound("the ETS table does not exist, or it was deleted")
    TableAlreadyExists -> Conflict("an ETS table with this name exists", error)
    InvalidKey -> Invalid("the table configuration has no key encoder", error)
    InvalidValue ->
      Invalid("the table configuration has no value encoder", error)
    DecodeError(_) ->
      Failed(
        "a key or value in the ETS table does not decode with the decoder of the table",
        error,
      )
    OperationFailed(reason) ->
      Failed("the ETS operation failed: " <> reason, error)
  }
}

/// Get the internal table reference
///
/// Returns the underlying EtsTableRef for internal operations. This is
/// primarily used by the operations module and should not be needed in
/// application code.
///
/// ## Parameters
///
/// - `table`: The table to get the reference from
///
/// ## Returns
///
/// The internal table reference.
///
/// ## Example
///
/// ### Compare table references <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L45-L54"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn same_table_after_load(
///   cache: table.Table(String, String),
///   filename: String,
/// ) -> Result(Bool, table.EtsError) {
///   use _ <- result.try(operations.save_to_file(cache, filename))
///   use _ <- result.try(operations.delete_table(cache))
///   use loaded <- result.try(operations.load_from_file(filename))
///   // A loaded named table has the reference of the table that was saved
///   Ok(loaded == table.table_ref(cache))
/// }
/// ```
pub fn table_ref(table: Table(k, v)) -> EtsTableRef {
  let Table(ref, _, _, _, _, _) = table
  ref
}

/// Get the table name
///
/// Returns the name that was used when creating the table. Useful for
/// debugging and logging.
///
/// ## Parameters
///
/// - `table`: The table to get the name from
///
/// ## Returns
///
/// The table name as a string.
///
/// ## Example
///
/// ### Read the table name <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L56-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn cache_name() -> Result(String, table.EtsError) {
///   use cache <- result.try(helpers.new_string_table("doc_table_named"))
///   Ok(table.table_name(cache))
/// }
/// ```
pub fn table_name(table: Table(k, v)) -> String {
  let Table(_, name, _, _, _, _) = table
  name
}

/// Encode a key for storage
///
/// Converts a typed key to a dynamic value for storage in ETS. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the key encoder
/// - `key`: The key to encode
///
/// ## Returns
///
/// The encoded key as a dynamic value.
///
/// ## Example
///
/// ### Encode a key <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L61-L64"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn stored_key(cache: table.Table(String, String)) -> dynamic.Dynamic {
///   // This is the key as ETS stores it
///   table.encode_key(cache, "user:123")
/// }
/// ```
pub fn encode_key(table: Table(k, v), key: k) -> Dynamic {
  let Table(_, _, encoder, _, _, _) = table
  encoder(key)
}

/// Decode a key from storage
///
/// Converts a dynamic value from ETS storage back to the typed key. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the key decoder
/// - `dyn`: The dynamic value to decode
///
/// ## Returns
///
/// - `Ok(key)`: Successfully decoded key
/// - `Error(DecodeError)`: Decoding failed
///
/// ## Example
///
/// ### Decode a key <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L66-L70"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn read_key(
///   cache: table.Table(String, String),
/// ) -> Result(String, decode.DecodeError) {
///   table.decode_key(cache, dynamic.string("user:123"))
/// }
/// ```
pub fn decode_key(
  table: Table(k, v),
  dyn: Dynamic,
) -> Result(k, decode.DecodeError) {
  let Table(_, _, _, decoder, _, _) = table
  run(dyn, decoder)
  |> map_error(extract_first_decode_error)
}

fn extract_first_decode_error(
  errors: List(decode.DecodeError),
) -> decode.DecodeError {
  // A failed decode always reports at least one error. The fallback value
  // only makes the function total.
  errors
  |> first
  |> unwrap(decode.DecodeError("key", "decoding failed", []))
}

/// Encode a value for storage
///
/// Converts a typed value to a dynamic value for storage in ETS. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the value encoder
/// - `value`: The value to encode
///
/// ## Returns
///
/// The encoded value as a dynamic value.
///
/// ## Example
///
/// ### Encode a value <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L72-L75"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn stored_value(cache: table.Table(String, String)) -> dynamic.Dynamic {
///   // This is the value as ETS stores it
///   table.encode_value(cache, "Alice")
/// }
/// ```
pub fn encode_value(table: Table(k, v), value: v) -> Dynamic {
  let Table(_, _, _, _, encoder, _) = table
  encoder(value)
}

/// Decode a value from storage
///
/// Converts a dynamic value from ETS storage back to the typed value. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the value decoder
/// - `dyn`: The dynamic value to decode
///
/// ## Returns
///
/// - `Ok(value)`: Successfully decoded value
/// - `Error(DecodeError)`: Decoding failed
///
/// ## Example
///
/// ### Decode a value <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L77-L81"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn read_value(
///   cache: table.Table(String, String),
/// ) -> Result(String, decode.DecodeError) {
///   table.decode_value(cache, dynamic.string("Alice"))
/// }
/// ```
pub fn decode_value(
  table: Table(k, v),
  dyn: Dynamic,
) -> Result(v, decode.DecodeError) {
  let Table(_, _, _, _, _, decoder) = table
  run(dyn, decoder)
  |> map_error(extract_first_value_decode_error)
}

fn extract_first_value_decode_error(
  errors: List(decode.DecodeError),
) -> decode.DecodeError {
  // A failed decode always reports at least one error. The fallback value
  // only makes the function total.
  errors
  |> first
  |> unwrap(decode.DecodeError("value", "decoding failed", []))
}

/// Create a new Table instance
///
/// Constructs a new Table from its components. This is used internally by
/// the builder pattern and should not be called directly from application code.
///
/// ## Parameters
///
/// - `table_ref`: The internal ETS table reference
/// - `name`: The table name
/// - `key_encoder`: Function to encode keys
/// - `key_decoder`: Decoder for keys
/// - `value_encoder`: Function to encode values
/// - `value_decoder`: Decoder for values
///
/// ## Returns
///
/// A new Table instance with the provided configuration.
///
/// ## Example
///
/// ### Give a loaded table its types <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_table.gleam#L83-L98"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn typed_view(
///   filename: String,
/// ) -> Result(option.Option(String), table.EtsError) {
///   use table_ref <- result.try(operations.load_from_file(filename))
///   // Give the loaded table its key and value types
///   let users =
///     table.new_table(
///       table_ref,
///       "doc_table_loaded",
///       encoders.string_encoder,
///       encoders.string_decoder(),
///       encoders.string_encoder,
///       encoders.string_decoder(),
///     )
///   operations.get(users, "user:123")
/// }
/// ```
pub fn new_table(
  table_ref: EtsTableRef,
  name: String,
  key_encoder: fn(k) -> Dynamic,
  key_decoder: Decoder(k),
  value_encoder: fn(v) -> Dynamic,
  value_decoder: Decoder(v),
) -> Table(k, v) {
  Table(
    table_ref: table_ref,
    name: name,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}
