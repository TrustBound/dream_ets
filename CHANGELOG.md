# Changelog

All notable changes to `dream_ets` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-11-26

### Added

- `table.to_error(error)` maps an `EtsError` to `dream_errors.Error(EtsError)`, the error type that the Dream packages share. `TableNotFound` gives `NotFound`, `TableAlreadyExists` gives `Conflict`, `InvalidKey` and `InvalidValue` give `Invalid`, and `DecodeError` and `OperationFailed` give `Failed`. Each one keeps the `EtsError` as the cause, except `NotFound`, which has no cause. The message is text for developers and logs.
- `dream_errors` (`>= 1.0.0 and < 2.0.0`) is a new dependency.

### Documentation

- The Settings and errors reference shows the mapping of each `EtsError`, and the Getting started guide links to it.

### Testing

- 344 tests, 0 failed, in 0.39 to 0.60 seconds over two runs, with the coverage report on (380/380 lines of `src/`, 100%). Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, OTP 29, Gleam 1.19.2.

## [3.0.0] - 2026-11-24

### Fixed

- `helpers.increment`, `increment_by`, `decrement` and `decrement_by` are
  atomic, as their docs said. Each one was a `get` followed by a `set`, so
  concurrent callers lost updates: 10 processes that each called
  `increment` 1000 times on one key gave counts from 1000 to 1702 in test
  runs, not 10000.
  Each one is now one `ets:update_counter/4` call, and the same test gives
  exactly 10000. A missing key still starts at 0, and a value that is not an
  `Int` still gives a `DecodeError` and stays unchanged.
- `operations.size` returns the number of stored objects, as its docs said.
  It counted keys, so a bag or duplicate_bag key with two values counted as
  1. It now reads the count from `ets:info`, in constant time, and no longer
  walks the table.
- The doc comment of `operations.set` said that it updates the value of an
  existing key. That is true for `set` and `ordered_set` tables only. It now
  says that `set` adds a value in a `bag` table (once per distinct value) and
  in a `duplicate_bag` table (always).
- `keys`, `values` and `to_list` return rows in ETS order. An `ordered_set`
  table gives its keys in ascending order. Before, the rows came in reverse
  order: an ordered table with the keys a, b, c gave `["c", "b", "a"]`.
- `get` and `take` on a bag table key with more than one value return
  `Error(OperationFailed("the key has 2 values, use get_all"))` (or
  `take_all`), and `take` leaves the values in the table. Before, they
  returned a `DecodeError`, and `take` removed the values. `values` and
  `to_list` now return every value of such a key.
- `config.create` with a table name of more than 255 characters returns
  `Error(OperationFailed("ETS rejected the table name: system_limit"))`.
  Before, it crashed the calling process.

- An operation on a table that was deleted raised the ETS `badarg` error and
  crashed the calling process, although the docs and `EtsError` said it
  returns `Error(TableNotFound)`. The FFI now catches `badarg`, checks that
  the table is gone, and returns `Error(TableNotFound)`. This applies to
  `set`, `get`, `delete`, `member`, `delete_table` (on a table that is
  already deleted), `size`, `keys`, `values`, `to_list`, `insert_new`,
  `take`, `update_element`, `delete_all_objects`, `match`, `match_object`,
  `select`, `save_to_file` (it returned `Error(OperationFailed("badtab"))`)
  and the counter helpers `increment`, `increment_by`, `decrement` and
  `decrement_by`. A `badarg` with another cause, on a table that exists (for
  example a bad match specification), now returns `OperationFailed` (see
  Changed).

### Added

- `operations.get_all(table, key)` returns every value of a key, and
  `operations.take_all(table, key)` returns and removes them in one ETS
  operation. A bag or duplicate_bag table can have several values for one
  key. Both work on every table type.

### Breaking Changes

- `operations.update_element()` returns `Result(Bool, EtsError)`: `Ok(True)`
  when it changed the element, and `Ok(False)` when the key is not in the
  table. Before, it returned `Ok(Nil)`, and `Error(TableNotFound)` for a
  missing key in a table that exists.
- `config.keypos()` is removed. A table stores `{key, value}` with the key
  first. Any other key position made `keys` and the other operations return
  wrong results.
- The `EtsError` constructors `EncodeError`, `EmptyTable` and `EndOfTable`
  are removed. No function returned them.
- `gleam_json` is no longer a dependency of the package. No source file used
  it. A project that stores JSON values needs its own `gleam_json`
  dependency.
- In `dream_ets/internal`, `lookup` and `take` return a list of objects,
  `take_one` is new, `update_element` returns `Result(Bool, _)`, and
  `EtsFfiError` has `SeveralObjects(Int)` in place of `NotFound`.

- `operations.member()` now returns `Result(Bool, EtsError)` instead of
  `Bool`, so that a deleted table is `Error(TableNotFound)` and not `False`.
- `operations.match()`, `operations.match_object()` and `operations.select()`
  now return `Result(List(Dynamic), EtsError)` instead of `List(Dynamic)`.
- In the `dream_ets/internal` module, `EtsFfiError` has a new
  `TableNotFound` variant, and `insert`, `delete_table`, `delete_key`,
  `delete_object`, `delete_all_objects`, `member`, `insert_new`, `match`,
  `match_object` and `select` (and their `ets_*` FFI functions) now return
  `Result(_, EtsFfiError)`.

**Upgrading:** where you used the `Bool` from `member()`, match on
`Ok(True)`, `Ok(False)` and `Error(_)`, or use it with
`use exists <- result.try(operations.member(table, key))`. Where you used the
list from `match()`, `match_object()` or `select()`, handle the `Result` in
the same way. Code that matched on `EtsFfiError` must handle
`TableNotFound`.
Where you matched `Ok(Nil)` from `update_element()`, match `Ok(True)` and
`Ok(False)`. Remove calls to `config.keypos()`. Remove `case` branches for
`EncodeError`, `EmptyTable` and `EndOfTable`. Code that relied on the reverse
order of `keys()`, `values()` or `to_list()` on an `ordered_set` table now
gets ascending order. On a bag table, read a key with `get_all()` and
`take_all()`. On a bag or duplicate_bag table, `size()` now counts every
value, not every key. The counter helpers now refuse a bag or duplicate_bag
table, and a table that does not store its values as plain integers, with
`Error(OperationFailed("ETS refused the operation: badarg"))`.

### Documentation

- The counting guide shows exact counts from many processes with
  `helpers.increment`, a counter process for a design with one writer, and
  a quota that many processes cannot overspend. The steps that showed lost
  increments are removed.
- Thirteen old snippets that no document showed any more are removed, with
  their tests.

- The `member()` and `insert_new()` doc comment examples are now tested
  snippets, and the README's error-handling example has a test for its
  `TableNotFound` branch.

### Testing

- 337 tests, 0 failed, in 0.44 to 0.64 seconds over three runs, with the coverage report on (373/373 lines of `src/`, 100%). Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, OTP 29, Gleam 1.19.2.

### Changed

- Moved to its own repository.
- The package has five task guides and one reference page in
  `docs/guides/`: getting started, caching data in memory, counting events,
  locks and work queues, saving a table to disk, and a settings and errors
  reference. Each guide walks through one task with tested code, its
  failure cases, a test of the reader's own code and common pitfalls. The
  README is short and links to them, and HexDocs shows the guides.
- Rejected table options and refused operations now return
  `OperationFailed` instead of crashing the caller. When ETS rejects the
  name of `config.create` (a name of more than 255 characters), the result
  is `Error(OperationFailed("ETS rejected the table name: system_limit"))`,
  with the reason that ETS gave. When ETS refuses an operation on a table that
  exists (for example a write to a protected table, or any operation on a
  private table, from a process that does not own it), the operations and
  the counter helpers return
  `Error(OperationFailed("ETS refused the operation: badarg"))`. In the
  `dream_ets/internal` module, `new_table` now returns
  `Result(EtsTableRef, NewTableError)`.

## [2.0.0] - 2025-12-08

### Breaking Changes

- `operations.keys()` now returns `Result(List(k), EtsError)` instead of `List(k)`
- `operations.values()` now returns `Result(List(v), EtsError)` instead of `List(v)`
- `operations.to_list()` now returns `Result(List(#(k,v)), EtsError)` instead of `List(#(k,v))`
- `operations.size()` now returns `Result(Int, EtsError)` instead of `Int`

**Migration Guide:**

```gleam
// Before (1.x):
let all_keys = operations.keys(table)

// After (2.x):
case operations.keys(table) {
  Ok(all_keys) -> use_keys(all_keys)
  Error(err) -> handle_error(err)
}
```

### Fixed

- **Critical:** Fixed `save_to_file()` FFI bug - filenames now properly converted from binary to charlist
- **Critical:** Fixed `load_from_file()` FFI bug - same charlist conversion issue
- **Critical:** Fixed `update_element()` FFI bug - now returns `{ok, nil}` instead of `ok`
- **Critical:** Fixed error handling in `keys()`, `values()`, `to_list()` - no more panics on decode errors
- Fixed error mapping in table creation to handle all `EtsFfiError` variants
- Fixed `ets_first()` FFI to return `empty_table` instead of `empty`

### Added

- **Documentation:** World-class hexdocs for every public function and type
- **Documentation:** Comprehensive examples showing real-world patterns (locks, queues, caching)
- **Documentation:** Performance notes and concurrency guidance throughout
- **Tests:** 100% test coverage of public API (77 tests across 10 suites)
- **Tests:** New test suites for persistence, encoders, helpers, advanced operations
- **Tests:** 9 verified, tested code snippets ready for documentation
- **Examples:** Custom type encoding with JSON
- **Examples:** Preventing duplicates with `insert_new()`
- **Examples:** Atomic operations for work queues
- Complete test coverage for:
  - `save_to_file()` / `load_from_file()` (previously untested!)
  - `update_element()`, `match()`, `match_object()`, `select()` (previously untested!)
  - Bool and float encoders (previously untested!)
  - Config options: `keypos()`, `table_type_bag()`, `table_type_duplicate_bag()` (previously untested!)

### Improved

- README completely rewritten with tested examples and proper error handling
- All error paths now properly handled - no more `Error(_)` patterns
- Better error messages for concurrent operations (e.g., "Key disappeared during iteration")
- Documentation examples now use proper Result-based error handling

### Internal

- Added `map_internal_error_to_ets()` helper for consistent error mapping
- Refactored collection functions to handle errors properly without panic
- Added `format_error()` in FFI to convert Erlang errors to strings

## [1.0.2] - 2025-11-21

### Changed

- Added HexDocs documentation badge to README

## [1.0.1] - 2025-11-22

### Fixed

- Fixed logo display on hex.pm by using full GitHub URL
- Added Dream logo to README

## [1.0.0] - 2025-11-21

### Added

- Initial stable release
- Type-safe ETS table interface
- Builder pattern for table configuration
- CRUD operations:
  - `operations.set()` - Insert or update key-value pair
  - `operations.get()` - Lookup value by key
  - `operations.delete()` - Delete key
  - `operations.member()` - Check if key exists
  - `operations.insert_new()` - Insert only if key doesn't exist
  - `operations.take()` - Get and delete atomically
- Collection operations:
  - `operations.keys()` - Get all keys
  - `operations.values()` - Get all values
  - `operations.to_list()` - Get all key-value pairs
  - `operations.size()` - Get table size
- Counter helpers:
  - `helpers.increment()` - Increment counter
  - `helpers.increment_by()` - Increment by amount
  - `helpers.decrement()` - Decrement counter
  - `helpers.decrement_by()` - Decrement by amount
- Convenience functions:
  - `ets.new_counter()` - Create counter table
  - `ets.new_string_table()` - Create string-to-string table
- Table persistence:
  - `operations.save_to_file()` - Save table to disk
  - `operations.load_from_file()` - Load table from disk
- Advanced features:
  - Pattern matching (`operations.match()`)
  - Match objects (`operations.match_object()`)
  - Select with match specifications (`operations.select()`)
