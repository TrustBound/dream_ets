# Getting started

Your program needs data that every process can read and write fast: a cache, a count, a list of sessions, a lock. A database is too slow for that, and a single process that holds the data becomes a queue that every request waits in. Erlang's ETS (Erlang Term Storage) gives you tables in memory that any process can use at the same time. dream_ets puts Gleam types on them, so a table of `String` keys and `Int` values only takes a `String` and only gives back an `Int`. This guide takes you from an empty project to tables that a real program creates at start-up and uses from many processes.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Create a table and read a value back](#step-1-create-a-table-and-read-a-value-back)
- [Step 2: Use the table from other processes](#step-2-use-the-table-from-other-processes)
- [Step 3: Keep the table alive](#step-3-keep-the-table-alive)
- [Step 4: Choose the key and value types](#step-4-choose-the-key-and-value-types)
- [When something goes wrong](#when-something-goes-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you will:

- Create a typed table, store a value and read it back.
- Write to one table from several processes at the same time.
- Create the tables of a program at start-up, so that they live as long as the program.
- Make a table with `Int` keys and `Float` values.
- Turn each error of a lookup into a message for your log.
- Test code that uses a table.

## Before you start

Add the package to your project:

```sh
gleam add dream_ets
```

ETS is part of the Erlang runtime, so dream_ets runs on the Erlang target only. It needs no other service and no framework.

Each example in this guide is a complete module. Put it in `src/`, call its public function from `main` or from a test, and you get the value that the guide shows.

## Step 1: Create a table and read a value back

You create a table with the builder in `dream_ets/config`. Start with `config.new(name)`, say how to store the keys and the values, and call `config.create()`. Then use the functions in `dream_ets/operations` to store and read values:

### Create a table and read a value back <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_first_table.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/option.{type Option}
import gleam/result

pub fn first_table() -> Result(Option(String), EtsError) {
  use names <- result.try(
    config.new("user_names")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  use Nil <- result.try(operations.set(names, "user:1", "Alice"))
  operations.get(names, "user:1")
}
```

`first_table()` returns `Ok(Some("Alice"))`.

Here is what each part does:

- `config.new("user_names")` starts a configuration. The name is the name of the ETS table, and it must be unique in the whole Erlang node.
- `config.key_string()` and `config.value_string()` make this a `Table(String, String)`. The compiler now refuses `operations.set(names, 1, "Alice")`, because `1` is not a `String`.
- `config.create()` makes the table. It returns a `Result`, because ETS can refuse, for example when a table with that name exists already.
- `operations.set` stores the value under the key. If the key has a value already, `set` replaces it. (This table is a `set`, the default type. A `bag` table adds the value instead, as the [reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md#table-types) shows.)
- `operations.get` returns `Ok(Some(value))` for a stored key, and `Ok(None)` for a key that is not in the table. `get(names, "user:2")` returns `Ok(None)`.

Every operation returns a `Result(_, EtsError)`. The [failure section](#when-something-goes-wrong) shows each error.

Two more operations that you will use all the time: `operations.delete(table, key)` removes a key, and does nothing when the key is not there. `operations.member(table, key)` returns `Ok(True)` or `Ok(False)` without reading the value.

## Step 2: Use the table from other processes

A `Table` value is only a reference to the ETS table. You can pass it to any process, and every process reads and writes the same data. This function starts three processes that each write one key at the same time:

### Write to one table from three processes <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_share.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string

pub fn write_from_three_processes(
  names: Table(String, String),
) -> Result(List(String), EtsError) {
  let finished = process.new_subject()
  let users = ["ada", "grace", "linus"]
  list.each(users, fn(user) {
    process.spawn(fn() {
      // The Table value works in any process. It is only a reference.
      process.send(finished, operations.set(names, "user:" <> user, user))
    })
  })
  // Wait for one result from each process
  use _ <- result.try(
    list.try_map(users, fn(_) { process.receive_forever(finished) }),
  )
  use keys <- result.map(operations.keys(names))
  list.sort(keys, string.compare)
}
```

`write_from_three_processes(names)` returns `Ok(["user:ada", "user:grace", "user:linus"])`.

Each `set` is one ETS operation, so writes from different processes never mix up a value. The order of keys in the table is not fixed, so the function sorts them before it returns them.

## Step 3: Keep the table alive

Every ETS table has an owner: the process that created it. **When the owner process stops, ETS deletes the table**, with all its data. This catches people out, because a table works fine until the process that made it finishes. Here is a table created in a process that stops right away:

### A table goes away with its owner <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_owner.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process
import gleam/option.{type Option}

/// Wrong: creates the table in a process that stops right afterwards.
pub fn create_in_short_process() -> Result(Option(String), EtsError) {
  let created = process.new_subject()
  process.spawn(fn() {
    process.send(created, helpers.new_string_table("short_lived_names"))
  })
  case process.receive_forever(created) {
    Ok(names) -> read_after_owner_stopped(names)
    Error(error) -> Error(error)
  }
}

fn read_after_owner_stopped(
  names: Table(String, String),
) -> Result(Option(String), EtsError) {
  // Give the owner time to stop
  process.sleep(50)
  operations.get(names, "user:1")
}
```

`create_in_short_process()` returns `Error(TableNotFound)`. The table existed, but its owner stopped, and the table went with it.

So create your tables in a process that runs as long as your program does. The usual place is `main`, before you start your web server or your workers. Create them all in one function, keep them in a record, and pass the record to the code that needs them:

### Create the tables of a program at start-up <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_tables.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

In `main`, call `create_tables()` one time and pass `tables` to your request handlers or workers. Make sure that `main` does not return while the program runs. The handlers run in their own processes, and that is fine: they only use the tables, they do not own them.

After two calls of `greet(tables, "user:1")`, with `Alice` stored for `user:1`, the second call returns `Ok("Hello, Alice. Views of this page: 2")`. The [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md) guide explains `helpers.increment`, which stays exact when many processes count the same page at the same time.

If a supervised process owns a table and the supervisor restarts it, the new process starts with no table. Create the table again in the new process, or keep the table in a process that does not restart.

## Step 4: Choose the key and value types

`key_string()` and `value_string()` are shortcuts. For other types, give `config.key` and `config.value` an encoder (a function from your type to `Dynamic`) and a decoder (a `Decoder` back to your type). `dream_ets/encoders` has both for `String`, `Int`, `Float` and `Bool`:

### A table of prices by product id <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_types.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/option.{type Option}
import gleam/result

pub fn create_prices() -> Result(Table(Int, Float), EtsError) {
  config.new("product_prices")
  |> config.key(encoders.int_encoder, encoders.int_decoder())
  |> config.value(encoders.float_encoder, encoders.float_decoder())
  |> config.create()
}

pub fn price_of_product_42() -> Result(Option(Float), EtsError) {
  use prices <- result.try(create_prices())
  use Nil <- result.try(operations.set(prices, 42, 9.99))
  operations.get(prices, 42)
}
```

`price_of_product_42()` returns `Ok(Some(9.99))`.

Pick the shortest way that gives you the types you need:

| Your table | Use | Why |
|:---|:---|:---|
| `String` keys, `String` values | `helpers.new_string_table(name)` | One call, with the default settings. |
| `String` keys, `Int` counts | `helpers.new_counter(name)` | One call, and it works with `helpers.increment`. |
| Built-in types with other settings | `config.new(name)` with `key_string()`, `value_string()` or `counter()` | The builder also takes the settings that the [reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md) lists. |
| `Int`, `Float` or `Bool` keys or values | `config.key` and `config.value` with `encoders.int_encoder`, `encoders.float_encoder`, `encoders.bool_encoder` and their decoders | The encoders store the value as the Erlang term of the same type. |
| Your own type | `config.value` with your own encoder and decoder | The [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md) guide shows how. |

The encoder runs on each write and the decoder on each read. A decoder that fails gives you a `DecodeError` instead of a wrong value.

## When something goes wrong

Every function returns `Error` instead of crashing your process. This function turns each result of a lookup into a message for your log:

### Turn each result of a lookup into a message <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_errors.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_ets/table.{
  type Table, DecodeError, InvalidKey, InvalidValue, OperationFailed,
  TableAlreadyExists, TableNotFound,
}
import gleam/option.{None, Some}

pub fn describe_lookup(names: Table(String, String), key: String) -> String {
  case operations.get(names, key) {
    Ok(Some(name)) -> "Found " <> name
    Ok(None) -> "No name for " <> key
    Error(TableNotFound) -> "The table is gone. Did its owner process stop?"
    Error(DecodeError(error)) ->
      "The stored value is not a " <> error.expected <> ": " <> error.found
    Error(OperationFailed(reason)) -> "ETS refused the lookup: " <> reason
    // `create` returns these three. A lookup never does.
    Error(TableAlreadyExists) | Error(InvalidKey) | Error(InvalidValue) ->
      "Unexpected error"
  }
}
```

Here is what each error means, and what you will see:

- `TableNotFound`: the table does not exist. Either your code deleted it with `operations.delete_table`, or its owner process stopped ([Step 3](#step-3-keep-the-table-alive)). On a deleted table, the message is `The table is gone. Did its owner process stop?`.
- `DecodeError(error)`: the stored value does not decode with the decoder of the table. That happens when two `Table` values with different types point to one ETS table, or when a table is loaded from a file that an older version of your program saved. For an `Int` in a table of `String` values, the message is `The stored value is not a String: Int`.
- `OperationFailed(reason)`: ETS refused the operation. The usual reason is access: another process reads a `private` table, or writes a `protected` one. The message is then `ETS refused the lookup: ETS refused the operation: badarg`.
- `TableAlreadyExists`: `config.create` found a table with the same name. Create each table one time, and give each one its own name.
- `InvalidKey` and `InvalidValue`: `config.create` got a configuration with no key encoder or no value encoder. Add `key_string()`, `value_string()`, `key(...)` or `value(...)`.

The [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md) lists which function returns which error.

## Test your code

Write your functions so that they take a table as a parameter, as `greet` does. Then each test can make its own tables, put the data it needs in them, and call your function. Tests often run at the same time, and table names are global to the Erlang node, so give each test's tables their own names.

This test module uses [dream_test](https://hexdocs.pm/dream_test). Add it as a dev dependency first, with the same version range that this package tests with. These are the lines of this package's own `gleam.toml`:

### The dream_test dev dependency <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/gleam.toml#L25-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
[dev-dependencies]
dream_test = ">= 3.0.0 and < 4.0.0"
```

### Test greet with tables made for each test <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_getting_started_tables.{Tables, greet}

pub fn tests() -> TestSuite {
  describe("greet", [
    it("greets a known user by name", fn() {
      // Arrange
      // Each test gets tables with names of its own
      let assert Ok(names) =
        config.new("greet_test_known_names")
        |> config.key_string()
        |> config.value_string()
        |> config.create()
      let assert Ok(page_views) = helpers.new_counter("greet_test_known_views")
      let assert Ok(Nil) = operations.set(names, "user:1", "Alice")
      let tables = Tables(names: names, page_views: page_views)

      // Act
      let greeting = greet(tables, "user:1")

      // Assert
      greeting
      |> should
      |> be_equal(Ok("Hello, Alice. Views of this page: 1"))
      |> or_fail_with("Expected a greeting for Alice")
    }),
    it("greets an unknown user as a stranger", fn() {
      // Arrange
      let assert Ok(names) =
        helpers.new_string_table("greet_test_unknown_names")
      let assert Ok(page_views) =
        helpers.new_counter("greet_test_unknown_views")
      let tables = Tables(names: names, page_views: page_views)

      // Act
      let greeting = greet(tables, "user:2")

      // Assert
      greeting
      |> should
      |> be_equal(Ok("Hello, stranger. Views of this page: 1"))
      |> or_fail_with("Expected a greeting for a stranger")
    }),
  ])
}
```

Each test builds a `Tables` record from tables with names of its own, so the two tests cannot see each other's data. When a test ends, its process stops, and ETS deletes the tables that it owns.

Run the tests with `gleam test`. CI runs the tests of this package with the same command:

### Run the tests <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/scripts/check.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
gleam test
```

## Common pitfalls

**Creating a table in a short-lived process.** *Symptom:* the table works for a moment, then every operation returns `Error(TableNotFound)`. *Fix:* the owner process stopped. Create the table in `main` or in another process that runs as long as the program, as in [Step 3](#step-3-keep-the-table-alive).

**Creating the same table two times.** *Symptom:* `config.create` returns `Error(TableAlreadyExists)`, often in tests or after a restart. *Fix:* create each table one time and pass the `Table` value around. In tests, give each test its own table names.

**Table names from user input.** *Symptom:* memory grows, or `config.create` returns `Error(OperationFailed("ETS rejected the table name: system_limit"))`. *Fix:* each table name becomes an Erlang atom, and the runtime never frees atoms. A name also cannot be longer than 255 characters. Use a fixed set of tables, and put user data in the keys.

**Expecting the keys in order.** *Symptom:* `operations.keys` or `operations.to_list` returns the keys in a different order than you stored them. *Fix:* a `set` table has no order. Sort the list, or use an `ordered_set` table, which returns its keys in ascending order.

**Expecting the data to survive a restart.** *Symptom:* every table is empty after the program starts again. *Fix:* ETS keeps data in memory only. Save the tables you need, as [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md) shows.

**Expecting other nodes to see the table.** *Symptom:* a value that one node stores is not there on another node of your cluster. *Fix:* an ETS table belongs to one Erlang node. Each node has its own tables.

## Where to go next

- [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md): store your own types, expire old entries and load values on a miss.
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md): count page views from many processes, spend quotas, and let only one process write.
- [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md): let only one process do a job, and share work between workers.
- [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md): keep a table across restarts.
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): every table setting with its default, and every error.
- [API reference on HexDocs](https://hexdocs.pm/dream_ets): `config`, `operations`, `helpers`, `encoders` and `table`.
