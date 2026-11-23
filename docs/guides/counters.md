# Counters

This guide shows how to count events with a counter table. A counter table has String keys and Int values.

## Create a counter and increment it

Create a counter table with `helpers.new_counter(name)`, or with `config.counter(config)` in the builder.

### Counter Tables <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/counter_tables.gleam#L5-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/table
import gleam/result

pub fn increment_page_views() -> Result(Int, table.EtsError) {
  use counter <- result.try(helpers.new_counter("page_views"))

  // Track multiple page views
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use count <- result.try(helpers.increment(counter, "homepage"))

  Ok(count)
}
```

## Example: page view analytics

### Page View Analytics <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/page_view_analytics.gleam#L10-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  use counter <- result.try(helpers.new_counter("analytics"))
  use views <- result.try(helpers.increment(counter, "homepage"))
```

## Functions

- `helpers.new_counter(name)` - Convenience: create counter table
- `config.counter(config)` - Configure counter table (String keys, Int values)
- `helpers.increment(counter, key)` - Increment by 1
- `helpers.increment_by(counter, key, amount)` - Increment by amount
- `helpers.decrement(counter, key)` - Decrement by 1
- `helpers.decrement_by(counter, key, amount)` - Decrement by amount

## See also

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
