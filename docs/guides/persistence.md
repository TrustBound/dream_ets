# Persistence

This guide shows how to save a table to disk and load it again.

## Save a table to disk

### Persistence <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/table_persistence.gleam#L5-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn save_to_disk() -> Result(String, table.EtsError) {
  use data <- result.try(helpers.new_string_table("data"))

  use _ <- result.try(operations.set(data, "key", "important data"))

  // Save to disk
  use _ <- result.try(operations.save_to_file(data, "/tmp/dream_ets_backup.ets"))

  // Verify it's still there
  use value <- result.try(operations.get(data, "key"))

  case value {
    option.Some(data) -> Ok(data)
    option.None -> Error(table.OperationFailed("Data lost"))
  }
}
```

## Functions

- `operations.save_to_file(table, filename)` - Save table to disk
- `operations.load_from_file(filename)` - Load table from disk

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
