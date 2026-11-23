# Table configuration

This guide shows how to build a table with the builder pattern in `dream_ets/config`, and how to set its options for your workload.

## The builder pattern

The configuration follows the builder pattern:

1. Start with `config.new(name)` to create a config.
2. Chain configuration functions to change settings.
3. Set the key and value encoders (required).
4. Call `config.create()` to build the table.

The `dream_ets/helpers` module has shortcuts for the most common tables.

## Table creation functions

- `config.new(name)` - Create table configuration
- `config.key_string(config)` - Set string keys
- `config.value_string(config)` - Set string values
- `config.key(config, encoder, decoder)` - Set custom key encoding
- `config.value(config, encoder, decoder)` - Set custom value encoding
- `config.counter(config)` - Configure counter table (String keys, Int values)
- `config.create(config)` - Create table from configuration
- `helpers.new_counter(name)` - Convenience: create counter table
- `helpers.new_string_table(name)` - Convenience: create string table

For `config.key` and `config.value`, read the custom types guide. For counter tables, read the counters guide.

## Optimize a table for your workload

### Enable read concurrency <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/table_configuration.gleam#L5-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn configure_table() -> Result(String, table.EtsError) {
  // Create table with read concurrency enabled
  // Use this when multiple processes will read simultaneously
  use cache <- result.try(
    config.new("cache")
    |> config.read_concurrency(True)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  use _ <- result.try(operations.set(cache, "key", "value"))
  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(stored_value) -> Ok(stored_value)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

## Configuration options

- `read_concurrency(Bool)` - Optimize for concurrent reads
- `write_concurrency(Bool)` - Optimize for concurrent writes
- `compressed(Bool)` - Compress data to save memory
- `table_type(Set | OrderedSet | Bag | DuplicateBag)` - Key handling
- `access(Public | Protected | Private)` - Process access control

## Performance notes

- **Concurrency** - Enable `read_concurrency` for read-heavy workloads
- **Compression** - Enable for large values to trade CPU for memory

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
