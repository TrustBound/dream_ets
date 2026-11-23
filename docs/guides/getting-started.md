# Getting started

This guide shows how to add dream_ets to a Gleam project and create a first table. It then points to the guides for each task.

## Install

Add the package as a dependency:

```bash
gleam add dream_ets
```

dream_ets has no dependency on Dream or on a framework. You can use it in any Gleam project.

## Create a first table

Create a table with the builder pattern in `dream_ets/config`: start with `config.new(name)`, set the key and value types, and call `config.create()`. Then store and read values with `dream_ets/operations`. Each operation returns a `Result`.

### Creating a Table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/creating_tables.gleam#L5-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn create_string_table() -> Result(String, table.EtsError) {
  // Create a table using the builder pattern
  use cache <- result.try(
    config.new("user_cache")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  // Use it
  use _ <- result.try(operations.set(cache, "alice", "Alice"))
  use value <- result.try(operations.get(cache, "alice"))

  case value {
    option.Some(name) -> Ok(name)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

## Next steps

- To set the table type, access and concurrency options, read the table configuration guide.
- To store, read and list values, read the reading and writing guide.
- To store your own types, read the custom types guide.

## See also

- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
