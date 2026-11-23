# Custom types

This guide shows how to store your own types in a table. You give the table an encoder and a decoder for the type, for example with JSON or tuples.

## Store your own types using JSON encoding

Set the value type with `config.value(config, encoder, decoder)`. Set a custom key type with `config.key(config, encoder, decoder)`. The snippet uses `gleam_json`. A project that stores JSON values needs its own `gleam_json` dependency, because dream_ets does not depend on it.

### Store a user as JSON <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/custom_types.gleam#L5-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string

pub type User {
  User(name: String, email: String)
}

fn encode_user(user: User) -> dynamic.Dynamic {
  json.object([
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string
  |> dynamic.string
}

fn decode_user() -> decode.Decoder(User) {
  decode.string
  |> decode.then(fn(json_text) {
    case json.parse(json_text, user_from_json()) {
      Ok(user) -> decode.success(user)
      Error(error) ->
        decode.failure(User("", ""), "User JSON: " <> string.inspect(error))
    }
  })
}

fn user_from_json() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(name: name, email: email))
}

pub fn store_custom_type() -> Result(String, table.EtsError) {
  use users <- result.try(
    config.new("users")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )

  let user = User(name: "Alice", email: "alice@example.com")
  use _ <- result.try(operations.set(users, "alice", user))

  use retrieved <- result.try(operations.get(users, "alice"))

  case retrieved {
    option.Some(stored_user) ->
      Ok(stored_user.name <> " <" <> stored_user.email <> ">")
    option.None -> Error(table.OperationFailed("User not found"))
  }
}
```

## Functions

- `config.key(config, encoder, decoder)` - Set custom key encoding
- `config.value(config, encoder, decoder)` - Set custom value encoding

If a stored value does not decode, the operation returns `DecodeError(details)`. Read the error handling guide.

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
