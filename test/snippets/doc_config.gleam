//// Doc comments: dream_ets/config
////
//// The examples in the doc comments of the config module.

import dream_ets/config
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result

pub fn quick_start() -> Result(List(String), table.EtsError) {
  // Create a simple string-to-string table
  use users <- result.try(
    config.new("doc_config_users")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Create a counter table (String keys, Int values)
  use counter <- result.try(
    config.new("doc_config_page_views")
    |> config.counter()
    |> config.create(),
  )

  // Create with custom configuration
  use cache <- result.try(
    config.new("doc_config_cache")
    |> config.table_type(config.table_type_set())
    |> config.access(config.access_public())
    |> config.read_concurrency(True)
    |> config.write_concurrency(False)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  Ok([
    table.table_name(users),
    table.table_name(counter),
    table.table_name(cache),
  ])
}

pub fn set_table() -> Result(table.Table(String, String), table.EtsError) {
  config.new("doc_config_set")
  |> config.table_type(config.table_type_set())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn leaderboard() -> Result(table.Table(String, String), table.EtsError) {
  // Useful for leaderboards or sorted data
  config.new("doc_config_leaderboard")
  |> config.table_type(config.table_type_ordered_set())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn public_sessions() -> Result(table.Table(String, String), table.EtsError) {
  config.new("doc_config_sessions")
  |> config.access(config.access_public())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn protected_settings() -> Result(
  table.Table(String, String),
  table.EtsError,
) {
  // Protected: only the owner can write, any process can read
  config.new("doc_config_settings")
  |> config.access(config.access_protected())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn new_users() -> Result(table.Table(String, String), table.EtsError) {
  config.new("doc_config_new_users")
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn read_heavy_cache() -> Result(table.Table(String, String), table.EtsError) {
  // Optimize for many simultaneous readers
  config.new("doc_config_read_heavy")
  |> config.read_concurrency(True)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn write_heavy_metrics() -> Result(
  table.Table(String, String),
  table.EtsError,
) {
  // Optimize for many simultaneous writers
  config.new("doc_config_metrics")
  |> config.write_concurrency(True)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn compressed_documents() -> Result(
  table.Table(String, String),
  table.EtsError,
) {
  // Compress large JSON values
  config.new("doc_config_documents")
  |> config.compressed(True)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn builtin_key_encoder() -> Result(
  table.Table(String, String),
  table.EtsError,
) {
  // Using built-in encoders
  config.new("doc_config_key_builtin")
  |> config.key(encoders.string_encoder, encoders.string_decoder())
  |> config.value_string()
  |> config.create()
}

pub type UserId {
  UserId(Int)
}

pub fn encode_user_id(id: UserId) -> dynamic.Dynamic {
  let UserId(number) = id
  dynamic.int(number)
}

pub fn decode_user_id() -> decode.Decoder(UserId) {
  decode.int |> decode.map(UserId)
}

pub fn custom_key_encoder() -> Result(option.Option(String), table.EtsError) {
  use users <- result.try(
    config.new("doc_config_key_custom")
    |> config.key(encode_user_id, decode_user_id())
    |> config.value_string()
    |> config.create(),
  )
  use _ <- result.try(operations.set(users, UserId(7), "Ada"))
  operations.get(users, UserId(7))
}

pub fn builtin_value_encoder() -> Result(
  table.Table(String, String),
  table.EtsError,
) {
  // Using built-in encoders
  config.new("doc_config_value_builtin")
  |> config.key_string()
  |> config.value(encoders.string_encoder, encoders.string_decoder())
  |> config.create()
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

pub fn custom_value_encoder() -> Result(option.Option(User), table.EtsError) {
  use users <- result.try(
    config.new("doc_config_value_custom")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )
  use _ <- result.try(operations.set(users, "ada", User("Ada", 36)))
  operations.get(users, "ada")
}

pub fn counter_table() -> Result(Int, table.EtsError) {
  // Create a counter table
  use counter <- result.try(
    config.new("doc_config_counter")
    |> config.counter()
    |> config.create(),
  )

  // Use with increment helpers
  helpers.increment(counter, "homepage")
}

pub fn create_tables() -> Result(List(String), table.EtsError) {
  // Create a simple table
  use users <- result.try(
    config.new("doc_config_create_users")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Create with custom settings
  use cache <- result.try(
    config.new("doc_config_create_cache")
    |> config.read_concurrency(True)
    |> config.write_concurrency(True)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  Ok([table.table_name(users), table.table_name(cache)])
}

pub fn tag_bag() -> Result(table.Table(String, String), table.EtsError) {
  // A bag keeps several different values under one key
  config.new("doc_config_tags")
  |> config.table_type(config.table_type_bag())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn event_log() -> Result(table.Table(String, String), table.EtsError) {
  // A duplicate bag also keeps identical values under one key
  config.new("doc_config_events")
  |> config.table_type(config.table_type_duplicate_bag())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn private_scratch() -> Result(table.Table(String, String), table.EtsError) {
  // Private: only the owner process can read and write
  config.new("doc_config_scratch")
  |> config.access(config.access_private())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}
