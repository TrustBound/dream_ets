# dream_ets 3.0.0 Release Notes

**Release Date:** not released yet (draft)

This release makes `dream_ets` return an error where it crashed the calling process before, and makes its results agree with what ETS does. An operation on a deleted table returns `Error(TableNotFound)`. An ordered table gives its keys in order. A bag table key with several values can be read in full.

It is a major version because several functions now return a `Result`. Read the Migration Guide before you upgrade. The package also moved to its own repository.

## Key Highlights

- **A deleted table is an error, not a crash**: every operation returns `Error(TableNotFound)` for a table that was deleted
- **`member`, `match`, `match_object` and `select` return a `Result` (breaking)**: a deleted table is no longer the same as "not found"
- **`update_element` says if it changed something (breaking)**: `Ok(True)` when it changed the element, `Ok(False)` when the key is not in the table
- **Counters are atomic**: `increment`, `increment_by`, `decrement` and `decrement_by` lose no update when many processes count one key
- **Bag tables work**: new `get_all` and `take_all` return every value of a key, and `size` counts every value
- **Rows come in ETS order**: an `ordered_set` table gives its keys in ascending order
- **Its own repository**: `dream_ets` now lives at [TrustBound/dream_ets](https://github.com/TrustBound/dream_ets), with its own version and its own releases

## What's New

### `get_all` and `take_all`

`operations.get_all(table, key)` returns every value of a key. `operations.take_all(table, key)` returns and removes them in one ETS operation. A bag or duplicate_bag table can have several values for one key. Both functions work on every table type.

### Refused Operations Return `OperationFailed`

Rejected table options and refused operations now return `OperationFailed` and no longer crash the caller:

- When ETS rejects the name of `config.create` (a name of more than 255 characters), the result is `Error(OperationFailed("ETS rejected the table name: system_limit"))`
- When ETS refuses an operation on a table that exists, the result is `Error(OperationFailed("ETS refused the operation: badarg"))`. Examples are a write to a protected table, or any operation on a private table, from a process that does not own it. This applies to the operations and to the counter helpers

### Its Own Repository

`dream_ets` moved out of the Dream repository. It has its own version, its own changelog and its own release workflow. The package name on Hex and the module names are the same as before.

### Guides

The package has five task guides and one reference page in [`docs/guides/`](https://github.com/TrustBound/dream_ets/tree/main/docs/guides). Each guide walks through one task from start to finish: getting started, caching data in memory, counting events, locks and work queues, and saving a table to disk. Each one has tested code, its failure cases, a test of your own code and common pitfalls. The settings and errors reference lists every table setting and every error. The README is short and links to them, and HexDocs shows the guides.

## Bug Fixes

### The Counter Helpers Are Atomic

`helpers.increment`, `increment_by`, `decrement` and `decrement_by` said that they are atomic, but each one was a `get` followed by a `set`. When many processes changed one key at the same time, updates got lost without an error: 10 processes that each called `increment` 1000 times gave counts from 1000 to 1702 in test runs, not 10000. Each helper is now one `ets:update_counter/4` call, and the same test gives exactly 10000 on every run. A missing key still starts at 0. A value that is not an `Int` still gives a `DecodeError` and stays unchanged.

### `size` Counts Every Stored Value

`operations.size` counted keys, not stored key-value pairs. In a bag or duplicate_bag table, a key with two values counted as 1. It now returns the number of objects that ETS keeps for the table, so that key counts as 2. It reads the count in constant time and no longer walks the table.

### The `set` Docs Name Each Table Type

The doc comment of `operations.set` said that a second `set` of a key updates the value. That is true for `set` and `ordered_set` tables. In a `bag` table, `set` adds a value that the key does not have yet. In a `duplicate_bag` table, `set` always adds the value. The doc comment now says this. The behavior did not change.

### An Operation on a Deleted Table Returns `TableNotFound`

An operation on a table that was deleted raised the ETS `badarg` error and crashed the calling process. The docs and `EtsError` said that it returns `Error(TableNotFound)`. Each operation now does that. This applies to `set`, `get`, `delete`, `member`, `delete_table` (on a table that is already deleted), `size`, `keys`, `values`, `to_list`, `insert_new`, `take`, `update_element`, `delete_all_objects`, `match`, `match_object`, `select`, `save_to_file` and the counter helpers `increment`, `increment_by`, `decrement` and `decrement_by`.

#### Check a key and handle a deleted table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/doc_member.gleam#L5-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result
import gleam/string

pub fn describe_user(
  users: table.Table(String, String),
  user_id: String,
) -> String {
  case operations.member(users, user_id) {
    Ok(True) -> user_id <> " exists"
    Ok(False) -> user_id <> " does not exist"
    Error(table.TableNotFound) -> "The table was deleted"
    Error(other) -> "Check failed: " <> string.inspect(other)
  }
}
```

### Rows Come in ETS Order

`keys`, `values` and `to_list` return rows in ETS order. An `ordered_set` table gives its keys in ascending order. Before, the rows came in reverse order: an ordered table with the keys a, b, c gave `["c", "b", "a"]`.

### A Bag Table Key With Several Values

`get` and `take` on a bag table key with more than one value return `Error(OperationFailed("the key has 2 values, use get_all"))` (or `take_all`), and `take` leaves the values in the table. Before, they returned a `DecodeError`, and `take` removed the values. `values` and `to_list` now return every value of such a key.

### A Table Name That Is Too Long

`config.create` with a table name of more than 255 characters returns `Error(OperationFailed("ETS rejected the table name: system_limit"))`. Before, it crashed the calling process.

## Testing

- 337 tests run, 0 failed, in 0.44 to 0.64 seconds over three runs with the coverage report on, and 100% line coverage of `src/` (373/373 lines) (Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, OTP 29, Gleam 1.19.2)

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream_ets = ">= 3.0.0 and < 4.0.0"
```

Then run:

```bash
gleam deps update dream_ets
```

### Migration Guide

Each step applies only if your code uses what the step names.

#### 1. `operations.member()`

`member()` returns `Result(Bool, EtsError)`, not `Bool`. A deleted table is `Error(TableNotFound)` and not `False`. Match on `Ok(True)`, `Ok(False)` and `Error(_)`, as the example under "Bug Fixes" shows, or write `use exists <- result.try(operations.member(table, key))`.

#### 2. `operations.match()`, `operations.match_object()` and `operations.select()`

Each returns `Result(List(Dynamic), EtsError)`, not `List(Dynamic)`. Handle the `Result` in the same way as for `member()`.

#### 3. `operations.update_element()`

It returns `Result(Bool, EtsError)`: `Ok(True)` when it changed the element, and `Ok(False)` when the key is not in the table. Before, it returned `Ok(Nil)`, and `Error(TableNotFound)` for a missing key in a table that exists. Where you matched `Ok(Nil)`, match `Ok(True)` and `Ok(False)`.

#### 4. `config.keypos()`

`config.keypos()` is removed. A table stores `{key, value}` with the key first. Any other key position made `keys` and the other operations return wrong results. Remove the call.

#### 5. `EncodeError`, `EmptyTable` and `EndOfTable`

These `EtsError` constructors are removed. No function returned them. Remove the `case` branches for them.

#### 6. Your project stores JSON values

`gleam_json` is no longer a dependency of the package, because no source file used it. Add `gleam_json` to your own dependencies if your project needs it.

#### 7. Your code relies on the order of `keys()`, `values()` or `to_list()`

On an `ordered_set` table these now give ascending order, not the reverse.

#### 8. Bag tables

Read a key that can have several values with `get_all()` and `take_all()`.

#### 9. `size()` on a bag or duplicate_bag table

`size()` now counts every value. With two values under one key, it returns `Ok(2)`, not `Ok(1)`. To count the keys of such a table, use `list.length` on the result of `keys()`. On a `set` or `ordered_set` table, the result is the same as before.

#### 10. Counter helpers on a table that is not a counter table

`increment`, `increment_by`, `decrement` and `decrement_by` now need a `set` or `ordered_set` table that stores its values as plain integers, as `helpers.new_counter` and `config.counter()` make. On a bag or duplicate_bag table, or on a table whose value encoder stores an `Int` in another form, they return `Error(OperationFailed("ETS refused the operation: badarg"))`. Before, they read and wrote the value through the encoders of the table.

#### 11. Code that uses `dream_ets/internal`

- `update_counter` and `size` (and their `ets_update_counter` and `ets_size` FFI functions) are new

- `EtsFfiError` has a new `TableNotFound` variant, and `SeveralObjects(Int)` in place of `NotFound`
- `insert`, `delete_table`, `delete_key`, `delete_object`, `delete_all_objects`, `member`, `insert_new`, `match`, `match_object` and `select` (and their `ets_*` FFI functions) return `Result(_, EtsFfiError)`
- `lookup` and `take` return a list of objects, `take_one` is new, and `update_element` returns `Result(Bool, _)`
- `new_table` returns `Result(EtsTableRef, NewTableError)`

## Documentation

- [dream_ets](https://hexdocs.pm/dream_ets) - v3.0.0
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md)
- [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md)
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md)
- [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md)
- [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md)
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md)
- [Changelog](https://github.com/TrustBound/dream_ets/blob/main/CHANGELOG.md)

## Community

- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream_ets/issues)
- [Contributing Guide](https://github.com/TrustBound/dream_ets/blob/main/CONTRIBUTING.md)
