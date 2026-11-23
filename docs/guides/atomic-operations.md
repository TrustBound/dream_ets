# Atomic operations

This guide shows the operations that check and change a table in one ETS operation. Use them for race-free locks, registrations and queues.

## Preventing duplicates

Use `insert_new()` for atomic "check and insert" operations:

### Register a username once <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/insert_new.gleam#L5-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result

pub fn register_user() -> Result(Bool, table.EtsError) {
  use registrations <- result.try(helpers.new_string_table("registrations"))

  // Try to register username
  use registered <- result.try(operations.insert_new(
    registrations,
    "alice",
    "alice@example.com",
  ))

  case registered {
    True -> {
      // Username available - registration succeeded
      Ok(True)
    }
    False -> {
      // Username already taken
      Ok(False)
    }
  }
}
```

## Take and remove a value

### Atomic Operations <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/advanced_operations.gleam#L5-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn atomic_take() -> Result(String, table.EtsError) {
  use queue <- result.try(helpers.new_string_table("jobs"))

  // Add a job
  use _ <- result.try(operations.set(queue, "job:123", "send_email"))

  // Take and remove atomically
  use job <- result.try(operations.take(queue, "job:123"))

  case job {
    option.Some(task) -> Ok(task)
    option.None -> Error(table.OperationFailed("Job not found"))
  }
}
```

## Example: distributed locks

### Distributed Locks <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/distributed_locks.gleam#L16-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  case operations.insert_new(locks, resource_id, owner_id) {
    Ok(True) -> Ok("Lock acquired")
    Ok(False) -> Error("Resource already locked")
    Error(error) -> Error("Lock system error: " <> string.inspect(error))
  }
```

## Example: a work queue

### Work Queue <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/work_queue.gleam#L13-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  case operations.take(queue, "next_job") {
    Ok(option.Some(job)) -> "Claimed " <> job
    Ok(option.None) -> "No jobs waiting"
    Error(error) -> "Queue error: " <> string.inspect(error)
  }
```

## Functions

- `operations.insert_new(table, key, value)` - Insert only if key does not exist (atomic)
- `operations.take(table, key)` - Get and remove atomically (for queues)
- `operations.take_all(table, key)` - Get and remove every value of a key atomically, for bag tables

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
