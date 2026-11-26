//// Built-in encoders and decoders for common types
////
//// This module provides pre-built encoder and decoder functions for Gleam's
//// primitive types. These functions handle the conversion between Gleam types
//// and Erlang's dynamic types for ETS storage.
////
//// ## Quick Start
////
//// ### Create tables with encoders <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L15-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn create_with_encoders() -> Result(
////   #(option.Option(String), option.Option(Int)),
////   table.EtsError,
//// ) {
////   // Use convenience functions (recommended)
////   use cache <- result.try(
////     config.new("doc_encoders_cache")
////     |> config.key_string()
////     |> config.value_string()
////     |> config.create(),
////   )
////
////   // Or use encoders directly for custom configuration
////   use scores <- result.try(
////     config.new("doc_encoders_scores")
////     |> config.key(encoders.string_encoder, encoders.string_decoder())
////     |> config.value(encoders.int_encoder, encoders.int_decoder())
////     |> config.create(),
////   )
////
////   use _ <- result.try(operations.set(cache, "greeting", "hello"))
////   use _ <- result.try(operations.set(scores, "alice", 10))
////   use greeting <- result.try(operations.get(cache, "greeting"))
////   use score <- result.try(operations.get(scores, "alice"))
////   Ok(#(greeting, score))
//// }
//// ```
////
//// ## Built-in Types
////
//// This module provides encoders/decoders for:
////
//// - `String` - Text data
//// - `Int` - Integer numbers
//// - `Float` - Floating-point numbers
//// - `Bool` - Boolean values
////
//// ## Custom Types
////
//// For complex or custom types, you'll need to write your own encoders/decoders.
//// Common patterns:
////
//// ### JSON Encoding <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L42-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub type User {
////   User(name: String, age: Int)
//// }
////
//// pub fn encode_user(user: User) -> dynamic.Dynamic {
////   json.object([
////     #("name", json.string(user.name)),
////     #("age", json.int(user.age)),
////   ])
////   |> json.to_string
////   |> dynamic.string
//// }
////
//// pub fn decode_user() -> decode.Decoder(User) {
////   use json_text <- decode.then(decode.string)
////   case json.parse(json_text, user_from_json()) {
////     Ok(user) -> decode.success(user)
////     Error(_) -> decode.failure(User("", 0), "User JSON")
////   }
//// }
////
//// fn user_from_json() -> decode.Decoder(User) {
////   use name <- decode.field("name", decode.string)
////   use age <- decode.field("age", decode.int)
////   decode.success(User(name: name, age: age))
//// }
////
//// pub fn store_user() -> Result(option.Option(User), table.EtsError) {
////   use users <- result.try(
////     config.new("doc_encoders_users")
////     |> config.key_string()
////     |> config.value(encode_user, decode_user())
////     |> config.create(),
////   )
////   use _ <- result.try(operations.set(users, "ada", User("Ada", 36)))
////   operations.get(users, "ada")
//// }
//// ```
////
//// ### Tuple Encoding <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L80-L103"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub type Point {
////   Point(x: Int, y: Int)
//// }
////
//// pub fn encode_point(point: Point) -> dynamic.Dynamic {
////   dynamic.array([dynamic.int(point.x), dynamic.int(point.y)])
//// }
////
//// pub fn decode_point() -> decode.Decoder(Point) {
////   use x <- decode.field(0, decode.int)
////   use y <- decode.field(1, decode.int)
////   decode.success(Point(x: x, y: y))
//// }
////
//// pub fn store_point() -> Result(option.Option(Point), table.EtsError) {
////   use points <- result.try(
////     config.new("doc_encoders_points")
////     |> config.key_string()
////     |> config.value(encode_point, decode_point())
////     |> config.create(),
////   )
////   use _ <- result.try(operations.set(points, "origin", Point(0, 0)))
////   operations.get(points, "origin")
//// }
//// ```

import dream_ets/internal.{to_dynamic}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder, bool, float, int, string}

/// Encode a string to Dynamic
///
/// Converts a Gleam `String` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `s`: The string to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the string.
///
/// ## Example
///
/// ### Use String keys and values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L105-L114"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn string_table() -> Result(option.Option(String), table.EtsError) {
///   use users <- result.try(
///     config.new("doc_encoders_strings")
///     |> config.key(encoders.string_encoder, encoders.string_decoder())
///     |> config.value(encoders.string_encoder, encoders.string_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   operations.get(users, "user:123")
/// }
/// ```
///
/// ## See Also
///
/// - `string_decoder()` - Decode strings from storage
/// - `config.key_string()` - Convenience function for string keys
pub fn string_encoder(s: String) -> Dynamic {
  to_dynamic(s)
}

/// Decode a string from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `String`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `String`.
///
/// ## Example
///
/// ### Use String keys and values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L105-L114"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn string_table() -> Result(option.Option(String), table.EtsError) {
///   use users <- result.try(
///     config.new("doc_encoders_strings")
///     |> config.key(encoders.string_encoder, encoders.string_decoder())
///     |> config.value(encoders.string_encoder, encoders.string_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(users, "user:123", "Alice"))
///   operations.get(users, "user:123")
/// }
/// ```
///
/// ## See Also
///
/// - `string_encoder()` - Encode strings for storage
/// - `config.value_string()` - Convenience function for string values
pub fn string_decoder() -> Decoder(String) {
  string
}

/// Encode an integer to Dynamic
///
/// Converts a Gleam `Int` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `i`: The integer to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the integer.
///
/// ## Example
///
/// ### Store Int values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L116-L125"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn int_table() -> Result(option.Option(Int), table.EtsError) {
///   use scores <- result.try(
///     config.new("doc_encoders_ints")
///     |> config.key_string()
///     |> config.value(encoders.int_encoder, encoders.int_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(scores, "player1", 42))
///   operations.get(scores, "player1")
/// }
/// ```
///
/// ## See Also
///
/// - `int_decoder()` - Decode integers from storage
/// - `config.counter()` - Convenience for counter tables
pub fn int_encoder(i: Int) -> Dynamic {
  to_dynamic(i)
}

/// Decode an integer from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Int`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Int`.
///
/// ## Example
///
/// ### Store Int values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L116-L125"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn int_table() -> Result(option.Option(Int), table.EtsError) {
///   use scores <- result.try(
///     config.new("doc_encoders_ints")
///     |> config.key_string()
///     |> config.value(encoders.int_encoder, encoders.int_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(scores, "player1", 42))
///   operations.get(scores, "player1")
/// }
/// ```
///
/// ## See Also
///
/// - `int_encoder()` - Encode integers for storage
pub fn int_decoder() -> Decoder(Int) {
  int
}

/// Encode a boolean to Dynamic
///
/// Converts a Gleam `Bool` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `b`: The boolean to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the boolean.
///
/// ## Example
///
/// ### Store Bool values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L127-L136"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn bool_table() -> Result(option.Option(Bool), table.EtsError) {
///   use flags <- result.try(
///     config.new("doc_encoders_bools")
///     |> config.key_string()
///     |> config.value(encoders.bool_encoder, encoders.bool_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(flags, "dark_mode", True))
///   operations.get(flags, "dark_mode")
/// }
/// ```
///
/// ## See Also
///
/// - `bool_decoder()` - Decode booleans from storage
pub fn bool_encoder(b: Bool) -> Dynamic {
  to_dynamic(b)
}

/// Decode a boolean from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Bool`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Bool`.
///
/// ## Example
///
/// ### Store Bool values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L127-L136"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn bool_table() -> Result(option.Option(Bool), table.EtsError) {
///   use flags <- result.try(
///     config.new("doc_encoders_bools")
///     |> config.key_string()
///     |> config.value(encoders.bool_encoder, encoders.bool_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(flags, "dark_mode", True))
///   operations.get(flags, "dark_mode")
/// }
/// ```
///
/// ## See Also
///
/// - `bool_encoder()` - Encode booleans for storage
pub fn bool_decoder() -> Decoder(Bool) {
  bool
}

/// Encode a float to Dynamic
///
/// Converts a Gleam `Float` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `f`: The float to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the float.
///
/// ## Example
///
/// ### Store Float values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L138-L147"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn float_table() -> Result(option.Option(Float), table.EtsError) {
///   use prices <- result.try(
///     config.new("doc_encoders_floats")
///     |> config.key_string()
///     |> config.value(encoders.float_encoder, encoders.float_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(prices, "widget", 9.99))
///   operations.get(prices, "widget")
/// }
/// ```
///
/// ## See Also
///
/// - `float_decoder()` - Decode floats from storage
pub fn float_encoder(f: Float) -> Dynamic {
  to_dynamic(f)
}

/// Decode a float from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Float`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Float`.
///
/// ## Example
///
/// ### Store Float values <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_encoders.gleam#L138-L147"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn float_table() -> Result(option.Option(Float), table.EtsError) {
///   use prices <- result.try(
///     config.new("doc_encoders_floats")
///     |> config.key_string()
///     |> config.value(encoders.float_encoder, encoders.float_decoder())
///     |> config.create(),
///   )
///   use _ <- result.try(operations.set(prices, "widget", 9.99))
///   operations.get(prices, "widget")
/// }
/// ```
///
/// ## See Also
///
/// - `float_encoder()` - Encode floats for storage
pub fn float_decoder() -> Decoder(Float) {
  float
}
