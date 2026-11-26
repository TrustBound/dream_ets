//// Table configuration and builder pattern
////
//// This module provides the builder pattern for creating ETS tables with
//// type-safe configuration. Use this module to create tables with custom
//// settings for concurrency, access control, and data types.
////
//// ## Quick Start
////
//// ### Create tables <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L16-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn quick_start() -> Result(List(String), table.EtsError) {
////   // Create a simple string-to-string table
////   use users <- result.try(
////     config.new("doc_config_users")
////     |> config.key_string()
////     |> config.value_string()
////     |> config.create(),
////   )
////
////   // Create a counter table (String keys, Int values)
////   use counter <- result.try(
////     config.new("doc_config_page_views")
////     |> config.counter()
////     |> config.create(),
////   )
////
////   // Create with custom configuration
////   use cache <- result.try(
////     config.new("doc_config_cache")
////     |> config.table_type(config.table_type_set())
////     |> config.access(config.access_public())
////     |> config.read_concurrency(True)
////     |> config.write_concurrency(False)
////     |> config.key_string()
////     |> config.value_string()
////     |> config.create(),
////   )
////
////   Ok([
////     table.table_name(users),
////     table.table_name(counter),
////     table.table_name(cache),
////   ])
//// }
//// ```
////
//// ## Builder Pattern
////
//// The configuration follows the builder pattern:
////
//// 1. Start with `new(name)` to create a config
//// 2. Chain configuration methods to customize settings
//// 3. Specify key and value encoders (required)
//// 4. Call `create()` to build the table
////
//// ## Type Safety
////
//// Tables are parameterized by key and value types. The type system
//// ensures you cannot insert wrong types into a table.

import dream_ets/encoders
import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/option
import gleam/result

/// Table configuration builder
///
/// Opaque type that holds all configuration for creating an ETS table.
/// Use the builder methods to configure the table before calling `create()`.
///
/// ## Type Parameters
///
/// - `key`: The type of keys that will be stored in the table
/// - `value`: The type of values that will be stored in the table
pub opaque type TableConfig(key, value) {
  TableConfig(
    name: String,
    table_type: TableType,
    access: Access,
    read_concurrency: Bool,
    write_concurrency: Bool,
    compressed: Bool,
    key_encoder: option.Option(fn(key) -> dynamic.Dynamic),
    key_decoder: option.Option(decode.Decoder(key)),
    value_encoder: option.Option(fn(value) -> dynamic.Dynamic),
    value_decoder: option.Option(decode.Decoder(value)),
  )
}

/// Table type for ETS tables
///
/// Determines how the table handles duplicate keys and ordering.
///
/// ## Variants
///
/// - `Set`: Keys are unique, no ordering guarantees. **Default and recommended.**
/// - `OrderedSet`: Keys are unique and sorted. Slower inserts but ordered iteration.
/// - `Bag`: Keys can have multiple values, order not preserved.
/// - `DuplicateBag`: Keys can have multiple identical values.
///
/// **Note:** Most applications should use `Set` (the default). Only use other
/// types if you have specific requirements for ordering or duplicate values.
pub type TableType {
  /// Keys are unique. The order of keys is not fixed. This is the default.
  Set
  /// Keys are unique and kept in sorted order.
  OrderedSet
  /// A key can have more than one value. Identical objects are stored once.
  Bag
  /// A key can have more than one value, including identical objects.
  DuplicateBag
}

/// Access control for ETS tables
///
/// Determines which processes can read and write to the table.
///
/// ## Variants
///
/// - `Public`: Any process can read and write. **Recommended for most cases.**
/// - `Protected`: Owner can write, any process can read. Use for read-heavy workloads.
/// - `Private`: Only the owner process can read and write. Rarely needed.
///
/// **Note:** In Dream applications, `Public` is usually the right choice since
/// the table typically outlives individual request processes.
pub type Access {
  /// Any process can read and write. This is the default.
  Public
  /// Only the owner process can write. Any process can read.
  Protected
  /// Only the owner process can read and write.
  Private
}

/// Create a Set table type
///
/// Returns a `Set` table type, which is the default and recommended type for
/// most use cases. Keys are unique and insertion/lookup is fast.
///
/// ## Returns
///
/// A `Set` table type.
///
/// ## Example
///
/// ### Create a set table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L51-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn set_table() -> Result(table.Table(String, String), table.EtsError) {
///   config.new("doc_config_set")
///   |> config.table_type(config.table_type_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn table_type_set() -> TableType {
  Set
}

/// Create an OrderedSet table type
///
/// Returns an `OrderedSet` table type. Keys are unique and maintained in
/// sorted order. Use this when you need ordered iteration, but note that
/// insertions are slower than `Set`.
///
/// ## Returns
///
/// An `OrderedSet` table type.
///
/// ## Example
///
/// ### Create a leaderboard <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L59-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn leaderboard() -> Result(table.Table(String, String), table.EtsError) {
///   // Useful for leaderboards or sorted data
///   config.new("doc_config_leaderboard")
///   |> config.table_type(config.table_type_ordered_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn table_type_ordered_set() -> TableType {
  OrderedSet
}

/// Create a Bag table type
///
/// Returns a `Bag` table type. A key can have multiple different values.
/// This is rarely needed in most applications.
///
/// ## Returns
///
/// A `Bag` table type.
///
/// ## Example
///
/// ### Create a bag table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L246-L253"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn tag_bag() -> Result(table.Table(String, String), table.EtsError) {
///   // A bag keeps several different values under one key
///   config.new("doc_config_tags")
///   |> config.table_type(config.table_type_bag())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn table_type_bag() -> TableType {
  Bag
}

/// Create a DuplicateBag table type
///
/// Returns a `DuplicateBag` table type. A key can have multiple identical
/// values. This is rarely needed in most applications.
///
/// ## Returns
///
/// A `DuplicateBag` table type.
///
/// ## Example
///
/// ### Create a duplicate bag table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L255-L262"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn event_log() -> Result(table.Table(String, String), table.EtsError) {
///   // A duplicate bag also keeps identical values under one key
///   config.new("doc_config_events")
///   |> config.table_type(config.table_type_duplicate_bag())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn table_type_duplicate_bag() -> TableType {
  DuplicateBag
}

/// Create Public access mode
///
/// Returns `Public` access, allowing any process to read and write to the
/// table. **This is the recommended default** for most applications.
///
/// ## Returns
///
/// A `Public` access mode.
///
/// ## Example
///
/// ### Create a public table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L68-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn public_sessions() -> Result(table.Table(String, String), table.EtsError) {
///   config.new("doc_config_sessions")
///   |> config.access(config.access_public())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn access_public() -> Access {
  Public
}

/// Create Protected access mode
///
/// Returns `Protected` access. Only the owner process can write, but any
/// process can read. Use this for read-heavy workloads where you want to
/// control writes.
///
/// ## Returns
///
/// A `Protected` access mode.
///
/// ## Example
///
/// ### Create a protected table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L76-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn protected_settings() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Protected: only the owner can write, any process can read
///   config.new("doc_config_settings")
///   |> config.access(config.access_protected())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn access_protected() -> Access {
  Protected
}

/// Create Private access mode
///
/// Returns `Private` access. Only the owner process can read and write.
/// This is rarely needed in most applications.
///
/// ## Returns
///
/// A `Private` access mode.
///
/// ## Example
///
/// ### Create a private table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L264-L271"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn private_scratch() -> Result(table.Table(String, String), table.EtsError) {
///   // Private: only the owner process can read and write
///   config.new("doc_config_scratch")
///   |> config.access(config.access_private())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
pub fn access_private() -> Access {
  Private
}

/// Create a new table configuration with sensible defaults
///
/// This is the starting point for the builder pattern. After calling `new()`,
/// you must chain methods to specify key and value encoders, then call `create()`
/// to build the table.
///
/// ## Defaults
///
/// - **Table type**: `Set` - Keys are unique, fast operations
/// - **Access**: `Public` - Any process can read/write
/// - **Key position**: 1 (for tuple-based tables)
/// - **Read concurrency**: `False` - Enable with `read_concurrency(True)` if needed
/// - **Write concurrency**: `False` - Enable with `write_concurrency(True)` if needed
/// - **Compressed**: `False` - Can reduce memory for large values
/// - **Named table**: `True` - Table is registered by name
///
/// ## Parameters
///
/// - `name`: A unique name for the table. Must be unique across the application.
///
/// ## Returns
///
/// A new `TableConfig` with default settings. You must set key and value
/// encoders before calling `create()`.
///
/// ## Example
///
/// ### Create a table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L88-L93"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn new_users() -> Result(table.Table(String, String), table.EtsError) {
///   config.new("doc_config_new_users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## See Also
///
/// - `create()` - Create the table after configuration
/// - `key_string()` - Set string keys
/// - `value_string()` - Set string values
pub fn new(name: String) -> TableConfig(k, v) {
  TableConfig(
    name: name,
    table_type: Set,
    access: Public,
    read_concurrency: False,
    write_concurrency: False,
    compressed: False,
    key_encoder: option.None,
    key_decoder: option.None,
    value_encoder: option.None,
    value_decoder: option.None,
  )
}

/// Set the table type
///
/// Configures how the table handles keys and ordering. The default is `Set`,
/// which is appropriate for most use cases.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `type_`: The table type to use (Set, OrderedSet, Bag, or DuplicateBag)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Create a sorted table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L59-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn leaderboard() -> Result(table.Table(String, String), table.EtsError) {
///   // Useful for leaderboards or sorted data
///   config.new("doc_config_leaderboard")
///   |> config.table_type(config.table_type_ordered_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## Performance Notes
///
/// - `Set`: Fastest for most operations (default)
/// - `OrderedSet`: Slower insertions but supports ordered iteration
/// - `Bag` / `DuplicateBag`: Rarely needed, use only for specific use cases
pub fn table_type(
  config: TableConfig(k, v),
  type_: TableType,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    _,
    access,
    read_concurrency,
    write_concurrency,
    compressed,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: type_,
    access: access,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set the access mode
///
/// Controls which processes can read and write to the table. The default is
/// `Public`, which allows any process to access the table.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `access_mode`: The access mode (Public, Protected, or Private)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Create a protected table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L76-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn protected_settings() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Protected: only the owner can write, any process can read
///   config.new("doc_config_settings")
///   |> config.access(config.access_protected())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## Access Modes
///
/// - **Public**: Any process can read/write (recommended)
/// - **Protected**: Owner writes, anyone reads
/// - **Private**: Only owner can read/write (rarely needed)
pub fn access(
  config: TableConfig(k, v),
  access_mode: Access,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    _,
    read_concurrency,
    write_concurrency,
    compressed,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access_mode,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable read concurrency
///
/// Optimizes the table for concurrent read operations. Enable this if
/// multiple processes will be reading from the table simultaneously.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable read concurrency, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Optimize for readers <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L95-L102"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn read_heavy_cache() -> Result(table.Table(String, String), table.EtsError) {
///   // Optimize for many simultaneous readers
///   config.new("doc_config_read_heavy")
///   |> config.read_concurrency(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## When to Use
///
/// - **Enable**: High read traffic from multiple processes
/// - **Disable**: Single-threaded access or write-heavy workloads
///
/// ## Performance Impact
///
/// - **Pro**: Significantly improves concurrent read performance
/// - **Con**: Slightly increases memory usage and write overhead
pub fn read_concurrency(
  config: TableConfig(k, v),
  enabled: Bool,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    _,
    write_concurrency,
    compressed,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    read_concurrency: enabled,
    write_concurrency: write_concurrency,
    compressed: compressed,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable write concurrency
///
/// Optimizes the table for concurrent write operations. Enable this if
/// multiple processes will be writing to the table simultaneously.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable write concurrency, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Optimize for writers <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L104-L114"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn write_heavy_metrics() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Optimize for many simultaneous writers
///   config.new("doc_config_metrics")
///   |> config.write_concurrency(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## When to Use
///
/// - **Enable**: High write traffic from multiple processes
/// - **Disable**: Single-threaded access or read-heavy workloads
///
/// ## Performance Impact
///
/// - **Pro**: Improves concurrent write performance
/// - **Con**: May increase memory usage slightly
///
/// ## Note
///
/// Write concurrency uses fine-grained locking. Best results when keys
/// are well-distributed across the keyspace.
pub fn write_concurrency(
  config: TableConfig(k, v),
  enabled: Bool,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    read_concurrency,
    _,
    compressed,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    read_concurrency: read_concurrency,
    write_concurrency: enabled,
    compressed: compressed,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable table compression
///
/// Compresses table data to reduce memory usage. This trades CPU time for
/// memory space. Only consider this for tables with large values.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable compression, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Compress values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L116-L126"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn compressed_documents() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Compress large JSON values
///   config.new("doc_config_documents")
///   |> config.compressed(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## When to Use
///
/// - **Enable**: Storing large values (e.g., JSON documents, HTML)
/// - **Disable**: Small values or performance-critical code (default)
///
/// ## Trade-offs
///
/// - **Pro**: Reduces memory usage (especially for large, compressible data)
/// - **Con**: Slower read/write operations due to compression overhead
/// - **Note**: Only worth it if values are large and compressible
pub fn compressed(
  config: TableConfig(k, v),
  enabled: Bool,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    read_concurrency,
    write_concurrency,
    _,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: enabled,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set key encoder and decoder
///
/// Configures custom encoding/decoding functions for keys. This is required
/// for creating a table - you must specify how to convert keys to/from
/// Erlang's dynamic types.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `encoder`: Function to convert keys to `Dynamic` for storage
/// - `decoder`: Decoder to convert `Dynamic` back to keys
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Use a built-in key encoder <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L128-L137"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn builtin_key_encoder() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Using built-in encoders
///   config.new("doc_config_key_builtin")
///   |> config.key(encoders.string_encoder, encoders.string_decoder())
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## Custom Encoders
///
/// For custom types, provide your own encoder/decoder:
///
/// ### Use a custom key type <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L139-L161"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub type UserId {
///   UserId(Int)
/// }
///
/// pub fn encode_user_id(id: UserId) -> dynamic.Dynamic {
///   let UserId(number) = id
///   dynamic.int(number)
/// }
///
/// pub fn decode_user_id() -> decode.Decoder(UserId) {
///   decode.int |> decode.map(UserId)
/// }
///
/// pub fn custom_key_encoder() -> Result(option.Option(String), table.EtsError) {
///   use users <- result.try(
///     config.new("doc_config_key_custom")
///     |> config.key(encode_user_id, decode_user_id())
///     |> config.value_string()
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(users, UserId(7), "Ada"))
///   operations.get(users, UserId(7))
/// }
/// ```
///
/// ## See Also
///
/// - `key_string()` - Convenience function for string keys
/// - `value()` - Set value encoder/decoder
pub fn key(
  config: TableConfig(k, v),
  encoder: fn(k) -> dynamic.Dynamic,
  decoder: decode.Decoder(k),
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    read_concurrency,
    write_concurrency,
    compressed,
    _,
    _,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    key_encoder: option.Some(encoder),
    key_decoder: option.Some(decoder),
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set value encoder and decoder
///
/// Configures custom encoding/decoding functions for values. This is required
/// for creating a table - you must specify how to convert values to/from
/// Erlang's dynamic types.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `encoder`: Function to convert values to `Dynamic` for storage
/// - `decoder`: Decoder to convert `Dynamic` back to values
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ### Use a built-in value encoder <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L163-L172"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn builtin_value_encoder() -> Result(
///   table.Table(String, String),
///   table.EtsError,
/// ) {
///   // Using built-in encoders
///   config.new("doc_config_value_builtin")
///   |> config.key_string()
///   |> config.value(encoders.string_encoder, encoders.string_decoder())
///   |> config.create()
/// }
/// ```
///
/// ## Custom Encoders
///
/// For custom types like JSON or complex structures:
///
/// ### Store a custom type as JSON <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L174-L210"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub type User {
///   User(name: String, age: Int)
/// }
///
/// pub fn encode_user(user: User) -> dynamic.Dynamic {
///   json.object([
///     #("name", json.string(user.name)),
///     #("age", json.int(user.age)),
///   ])
///   |> json.to_string
///   |> dynamic.string
/// }
///
/// pub fn decode_user() -> decode.Decoder(User) {
///   use json_text <- decode.then(decode.string)
///   case json.parse(json_text, user_from_json()) {
///     Ok(user) -> decode.success(user)
///     Error(_) -> decode.failure(User("", 0), "User JSON")
///   }
/// }
///
/// fn user_from_json() -> decode.Decoder(User) {
///   use name <- decode.field("name", decode.string)
///   use age <- decode.field("age", decode.int)
///   decode.success(User(name: name, age: age))
/// }
///
/// pub fn custom_value_encoder() -> Result(option.Option(User), table.EtsError) {
///   use users <- result.try(
///     config.new("doc_config_value_custom")
///     |> config.key_string()
///     |> config.value(encode_user, decode_user())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(users, "ada", User("Ada", 36)))
///   operations.get(users, "ada")
/// }
/// ```
///
/// ## See Also
///
/// - `value_string()` - Convenience function for string values
/// - `key()` - Set key encoder/decoder
pub fn value(
  config: TableConfig(k, v),
  encoder: fn(v) -> dynamic.Dynamic,
  decoder: decode.Decoder(v),
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    read_concurrency,
    write_concurrency,
    compressed,
    key_encoder,
    key_decoder,
    _,
    _,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: option.Some(encoder),
    value_decoder: option.Some(decoder),
  )
}

/// Convenience: Set string key encoding
///
/// Configures the table to use string keys. This is a convenience function
/// that calls `key()` with built-in string encoders.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration with string key encoding.
///
/// ## Example
///
/// ### Create a table with String keys <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L88-L93"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn new_users() -> Result(table.Table(String, String), table.EtsError) {
///   config.new("doc_config_new_users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## See Also
///
/// - `key()` - For custom key types
/// - `value_string()` - For string values
pub fn key_string(config: TableConfig(String, v)) -> TableConfig(String, v) {
  config
  |> key(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Set string value encoding
///
/// Configures the table to use string values. This is a convenience function
/// that calls `value()` with built-in string encoders.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration with string value encoding.
///
/// ## Example
///
/// ### Create a table with String values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L88-L93"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn new_users() -> Result(table.Table(String, String), table.EtsError) {
///   config.new("doc_config_new_users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// }
/// ```
///
/// ## See Also
///
/// - `value()` - For custom value types
/// - `key_string()` - For string keys
pub fn value_string(config: TableConfig(k, String)) -> TableConfig(k, String) {
  config
  |> value(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Configure as counter table (String keys, Int values)
///
/// Configures the table for use as a counter with string keys and integer
/// values. This is a convenience function that sets both key and value
/// encoders appropriately.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration ready for use as a counter.
///
/// ## Example
///
/// ### Create a counter table <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L212-L222"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn counter_table() -> Result(Int, table.EtsError) {
///   // Create a counter table
///   use counter <- result.try(
///     config.new("doc_config_counter")
///     |> config.counter()
///     |> config.create(),
///   )
///
///   // Use with increment helpers
///   helpers.increment(counter, "homepage")
/// }
/// ```
///
/// ## See Also
///
/// - `helpers.new_counter()` - Even simpler counter creation
/// - `helpers.increment()` - Increment counter values
/// - `helpers.decrement()` - Decrement counter values
pub fn counter(config: TableConfig(String, Int)) -> TableConfig(String, Int) {
  config
  |> key_string()
  |> value(encoders.int_encoder, encoders.int_decoder())
}

/// Create the table from configuration
///
/// Validates the configuration and creates the ETS table. This is the final
/// step in the builder pattern - it actually creates the table in memory.
///
/// ## Parameters
///
/// - `config`: The table configuration with all settings applied
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(InvalidKey)`: Key encoder/decoder not set
/// - `Error(InvalidValue)`: Value encoder/decoder not set
/// - `Error(OperationFailed("ETS rejected the table name: system_limit"))`:
///   The name has more than 255 characters. The text after the colon is the
///   reason that ETS gave
///
/// ## Example
///
/// ### Create tables <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_config.gleam#L224-L244"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn create_tables() -> Result(List(String), table.EtsError) {
///   // Create a simple table
///   use users <- result.try(
///     config.new("doc_config_create_users")
///     |> config.key_string()
///     |> config.value_string()
///     |> config.create(),
///   )
///
///   // Create with custom settings
///   use cache <- result.try(
///     config.new("doc_config_create_cache")
///     |> config.read_concurrency(True)
///     |> config.write_concurrency(True)
///     |> config.key_string()
///     |> config.value_string()
///     |> config.create(),
///   )
///
///   Ok([table.table_name(users), table.table_name(cache)])
/// }
/// ```
///
/// ## Errors
///
/// This function will return an error if:
///
/// 1. A table with the same name already exists
/// 2. Key encoder/decoder was not configured
/// 3. Value encoder/decoder was not configured
/// 4. ETS rejects the table options (`OperationFailed`)
///
/// ## See Also
///
/// - `new()` - Start the builder
/// - `key_string()` / `value_string()` - Common encoder shortcuts
pub fn create(
  config: TableConfig(k, v),
) -> Result(table.Table(k, v), table.EtsError) {
  use validated_config <- result.try(validate_config(config))
  use options <- result.try(build_ets_options(validated_config))
  create_table_with_options(validated_config, options)
}

// Private helper functions

fn validate_config(
  config: TableConfig(k, v),
) -> Result(TableConfig(k, v), table.EtsError) {
  let TableConfig(
    _,
    _,
    _,
    _,
    _,
    _,
    key_encoder,
    _key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  case key_encoder {
    option.None -> Error(table.InvalidKey)
    option.Some(_) ->
      validate_value_encoding(config, value_encoder, value_decoder)
  }
}

fn validate_value_encoding(
  config: TableConfig(k, v),
  value_encoder: option.Option(fn(v) -> dynamic.Dynamic),
  _value_decoder: option.Option(decode.Decoder(v)),
) -> Result(TableConfig(k, v), table.EtsError) {
  case value_encoder {
    option.None -> Error(table.InvalidValue)
    option.Some(_) -> Ok(config)
  }
}

fn build_ets_options(
  config: TableConfig(k, v),
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  let TableConfig(
    _,
    table_type,
    access,
    read_concurrency,
    write_concurrency,
    compressed,
    _,
    _,
    _,
    _,
  ) = config

  let type_option = table_type_to_atom(table_type)
  let access_option = access_to_atom(access)
  let base_options = [type_option, access_option]

  let options_with_read =
    add_read_concurrency_option(read_concurrency, base_options)
  let options_with_write =
    add_write_concurrency_option(write_concurrency, options_with_read)
  let options_with_compressed =
    add_compressed_option(compressed, options_with_write)
  let options_with_named = [
    atom.create("named_table") |> atom_to_dynamic,
    ..options_with_compressed
  ]
  Ok(options_with_named)
}

fn table_type_to_atom(table_type: TableType) -> dynamic.Dynamic {
  case table_type {
    Set -> atom.create("set") |> atom_to_dynamic
    OrderedSet -> atom.create("ordered_set") |> atom_to_dynamic
    Bag -> atom.create("bag") |> atom_to_dynamic
    DuplicateBag -> atom.create("duplicate_bag") |> atom_to_dynamic
  }
}

fn access_to_atom(access: Access) -> dynamic.Dynamic {
  case access {
    Public -> atom.create("public") |> atom_to_dynamic
    Protected -> atom.create("protected") |> atom_to_dynamic
    Private -> atom.create("private") |> atom_to_dynamic
  }
}

fn add_read_concurrency_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [create_concurrency_tuple("read_concurrency", True), ..options]
    False -> options
  }
}

fn add_write_concurrency_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [create_concurrency_tuple("write_concurrency", True), ..options]
    False -> options
  }
}

fn add_compressed_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [atom.create("compressed") |> atom_to_dynamic, ..options]
    False -> options
  }
}

fn create_concurrency_tuple(
  option_name: String,
  value: Bool,
) -> dynamic.Dynamic {
  let key_atom = atom.create(option_name)
  internal.to_dynamic(#(key_atom, value))
}

fn atom_to_dynamic(a: atom.Atom) -> dynamic.Dynamic {
  internal.to_dynamic(a)
}

fn create_table_with_options(
  config: TableConfig(k, v),
  options: List(dynamic.Dynamic),
) -> Result(table.Table(k, v), table.EtsError) {
  let TableConfig(
    name,
    _,
    _,
    _,
    _,
    _,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  let assert option.Some(encoder_k) = key_encoder
  let assert option.Some(decoder_k) = key_decoder
  let assert option.Some(encoder_v) = value_encoder
  let assert option.Some(decoder_v) = value_decoder

  internal.new_table(name, options)
  |> result.map(table.new_table(
    _,
    name,
    encoder_k,
    decoder_k,
    encoder_v,
    decoder_v,
  ))
  |> result.map_error(new_table_error_to_ets_error)
}

fn new_table_error_to_ets_error(
  error: internal.NewTableError,
) -> table.EtsError {
  case error {
    internal.NameInUse -> table.TableAlreadyExists
    internal.OptionsRejected(message) -> table.OperationFailed(message)
  }
}
