# Reading and writing

This guide shows how to store, read, delete and list the values in a table. It also lists the low-level operations for ETS pattern matching and match specifications.

## Store and read a value

### Basic Operations <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/basic_operations.gleam#L5-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn store_and_retrieve() -> Result(String, table.EtsError) {
  use cache <- result.try(helpers.new_string_table("cache"))

  // Store a value
  use _ <- result.try(operations.set(cache, "greeting", "Hello, World!"))

  // Retrieve it
  use value <- result.try(operations.get(cache, "greeting"))

  case value {
    option.Some(greeting) -> Ok(greeting)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

## Type safety

Keys and values are typed at compile time. A table with string keys does not accept an integer key.

### Type Safety <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/type_safe_operations.gleam#L5-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn type_safe_storage() -> Result(String, table.EtsError) {
  // String table enforces types at compile time
  use cache <- result.try(helpers.new_string_table("cache"))

  // ✅ This works
  use _ <- result.try(operations.set(cache, "key", "value"))

  // ❌ This would be a compile error:
  // operations.set(cache, 123, "value")
  // Error: Expected String, found Int

  use value <- result.try(operations.get(cache, "key"))

  case value {
    option.Some(stored_value) -> Ok(stored_value)
    option.None -> Error(table.OperationFailed("Not found"))
  }
}
```

## Example: a session cache

### Session Cache <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/session_cache.gleam#L12-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  use sessions <- result.try(
    config.new("sessions")
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )

  use _ <- result.try(operations.set(sessions, "session:abc", "user:alice"))
```

## Basic operations

- `operations.set(table, key, value)` - Insert or update value
- `operations.get(table, key)` - Retrieve value (returns `Option`)
- `operations.get_all(table, key)` - Retrieve every value of a key, for bag tables → `Result(List(v), EtsError)`
- `operations.delete(table, key)` - Remove key-value pair
- `operations.member(table, key)` - Check if key exists (fast) → `Result(Bool, EtsError)`
- `operations.delete_table(table)` - Delete entire table
- `operations.delete_all_objects(table)` - Clear all entries

## Bulk operations

**Note:** These now return `Result` to handle decode errors properly:

- `operations.keys(table)` - Get all keys, in ascending order for an ordered_set table → `Result(List(k), EtsError)`
- `operations.values(table)` - Get all values → `Result(List(v), EtsError)`
- `operations.to_list(table)` - Get all pairs → `Result(List(#(k, v)), EtsError)`
- `operations.size(table)` - Count entries → `Result(Int, EtsError)`

## Advanced (low-level) operations

- `operations.update_element(table, key, pos, value)` - Update tuple element → `Result(Bool, EtsError)`, `Ok(False)` when the key is not in the table
- `operations.match(table, pattern)` - Pattern matching → `Result(List(Dynamic), EtsError)`
- `operations.match_object(table, pattern)` - Object matching → `Result(List(Dynamic), EtsError)`
- `operations.select(table, match_spec)` - SQL-like queries → `Result(List(Dynamic), EtsError)`

## Performance notes

- **Basic ops** (`set`, `get`, `delete`, `member`) - O(1) constant time
- **Bulk ops** (`keys`, `values`, `to_list`, `size`) - O(n) iterates entire table

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
