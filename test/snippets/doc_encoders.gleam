//// Doc comments: dream_ets/encoders
////
//// The examples in the doc comments of the encoders module.

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result

pub fn create_with_encoders() -> Result(
  #(option.Option(String), option.Option(Int)),
  table.EtsError,
) {
  // Use convenience functions (recommended)
  use cache <- result.try(
    config.new("doc_encoders_cache")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Or use encoders directly for custom configuration
  use scores <- result.try(
    config.new("doc_encoders_scores")
    |> config.key(encoders.string_encoder, encoders.string_decoder())
    |> config.value(encoders.int_encoder, encoders.int_decoder())
    |> config.create(),
  )

  use _ <- result.try(operations.set(cache, "greeting", "hello"))
  use _ <- result.try(operations.set(scores, "alice", 10))
  use greeting <- result.try(operations.get(cache, "greeting"))
  use score <- result.try(operations.get(scores, "alice"))
  Ok(#(greeting, score))
}

pub type User {
  User(name: String, age: Int)
}

pub fn encode_user(user: User) -> dynamic.Dynamic {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
  ])
  |> json.to_string
  |> dynamic.string
}

pub fn decode_user() -> decode.Decoder(User) {
  use json_text <- decode.then(decode.string)
  case json.parse(json_text, user_from_json()) {
    Ok(user) -> decode.success(user)
    Error(_) -> decode.failure(User("", 0), "User JSON")
  }
}

fn user_from_json() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(User(name: name, age: age))
}

pub fn store_user() -> Result(option.Option(User), table.EtsError) {
  use users <- result.try(
    config.new("doc_encoders_users")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )
  use _ <- result.try(operations.set(users, "ada", User("Ada", 36)))
  operations.get(users, "ada")
}

pub type Point {
  Point(x: Int, y: Int)
}

pub fn encode_point(point: Point) -> dynamic.Dynamic {
  dynamic.array([dynamic.int(point.x), dynamic.int(point.y)])
}

pub fn decode_point() -> decode.Decoder(Point) {
  use x <- decode.field(0, decode.int)
  use y <- decode.field(1, decode.int)
  decode.success(Point(x: x, y: y))
}

pub fn store_point() -> Result(option.Option(Point), table.EtsError) {
  use points <- result.try(
    config.new("doc_encoders_points")
    |> config.key_string()
    |> config.value(encode_point, decode_point())
    |> config.create(),
  )
  use _ <- result.try(operations.set(points, "origin", Point(0, 0)))
  operations.get(points, "origin")
}

pub fn string_table() -> Result(option.Option(String), table.EtsError) {
  use users <- result.try(
    config.new("doc_encoders_strings")
    |> config.key(encoders.string_encoder, encoders.string_decoder())
    |> config.value(encoders.string_encoder, encoders.string_decoder())
    |> config.create(),
  )
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  operations.get(users, "user:123")
}

pub fn int_table() -> Result(option.Option(Int), table.EtsError) {
  use scores <- result.try(
    config.new("doc_encoders_ints")
    |> config.key_string()
    |> config.value(encoders.int_encoder, encoders.int_decoder())
    |> config.create(),
  )
  use _ <- result.try(operations.set(scores, "player1", 42))
  operations.get(scores, "player1")
}

pub fn bool_table() -> Result(option.Option(Bool), table.EtsError) {
  use flags <- result.try(
    config.new("doc_encoders_bools")
    |> config.key_string()
    |> config.value(encoders.bool_encoder, encoders.bool_decoder())
    |> config.create(),
  )
  use _ <- result.try(operations.set(flags, "dark_mode", True))
  operations.get(flags, "dark_mode")
}

pub fn float_table() -> Result(option.Option(Float), table.EtsError) {
  use prices <- result.try(
    config.new("doc_encoders_floats")
    |> config.key_string()
    |> config.value(encoders.float_encoder, encoders.float_decoder())
    |> config.create(),
  )
  use _ <- result.try(operations.set(prices, "widget", 9.99))
  operations.get(prices, "widget")
}
