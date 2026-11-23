# Error handling

This guide lists the errors that dream_ets returns and shows how to handle each result of a lookup.

## Errors

All operations that take a table return `Result` types. Common errors:

- `TableNotFound` - Table was deleted. Every operation on a deleted table returns this error and does not crash the calling process.
- `TableAlreadyExists` - Tried to create duplicate table
- `InvalidKey` / `InvalidValue` - Encoding/decoding failed
- `DecodeError(details)` - Failed to decode data (corruption or encoder mismatch)
- `OperationFailed(message)` - General operation failure

## Handle a lookup

### Handle each lookup result <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/error_handling.gleam#L16-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  case operations.get(users, key) {
    Ok(option.Some(user)) -> "Found " <> user
    Ok(option.None) -> "No user for " <> key
    Error(table.DecodeError(error)) ->
      "Stored data is corrupt: expected "
      <> error.expected
      <> ", found "
      <> error.found
    Error(table.TableNotFound) -> "The table was deleted"
    Error(other) -> "Lookup failed: " <> string.inspect(other)
  }
```

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
