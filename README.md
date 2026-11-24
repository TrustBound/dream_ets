<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Ricky Moony and Lucy, a moon shaped mascot for Dream with the star shaped mascot for Gleam, each with cute cartoon eyes and a smile" width="200">

<b>Type-safe ETS (Erlang Term Storage) for Gleam</b>

</div>

<br />

<div align="center">
  <a href="https://hex.pm/packages/dream_ets"><img src="https://img.shields.io/hexpm/v/dream_ets" alt="Hex Package"></a>
  <a href="https://github.com/TrustBound/dream_ets/releases"><img src="https://img.shields.io/github/v/release/TrustBound/dream_ets?label=Release" alt="Latest Release"></a>
  <a href="https://hexdocs.pm/dream_ets"><img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs"></a>
  <a href="https://github.com/TrustBound/dream_ets/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/TrustBound/dream_ets/badges/coverage.json" alt="Coverage"></a>
  <a href="https://github.com/TrustBound/dream_ets/blob/main/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://gleam.run"><img src="https://img.shields.io/badge/gleam-%E2%9C%A8-ffaff3" alt="Gleam"></a>
</div>

<br />

# dream_ets

A standalone module that gives a type-safe interface to Erlang's ETS in-memory storage. It has a builder pattern for table configuration, type-safe operations, and `Result`-based error handling. It is built with the same quality standards as [Dream](https://github.com/TrustBound/dream), but it is completely independent. Use it in any Gleam project.

## Features

- ✅ **Type-safe** - Keys and values are typed at compile time
- ✅ **Result-based errors** - All operations return `Result` for explicit error handling
- ✅ **Builder pattern** - Composable, fluent table configuration
- ✅ **Atomic operations** - `insert_new()`, `take()` and the counter helpers for race-free operations
- ✅ **Custom types** - Store any type with custom encoders (JSON, tuples, etc.)
- ✅ **Pattern matching** - Advanced ETS queries and match specifications
- ✅ **Table persistence** - Save/load tables to disk
- ✅ **100% tested** - Comprehensive test coverage with verified examples
- ✅ **Few dependencies** - Only `gleam_stdlib` and `gleam_erlang`, no Dream or framework

## Installation

```bash
gleam add dream_ets
```

## Quick Start

### Create a table and read a value back <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_getting_started_first_table.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/docs/guides/getting-started.md#create-a-table-and-read-a-value-back-"><img align="right" alt="Guide: Getting started" title="Guide: Getting started" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

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

`first_table()` returns `Ok(Some("Alice"))`. The table lives as long as the process that created it, so a real program creates its tables in `main`. The [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md) guide shows how.

## Guides

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): create a table, use it from many processes, keep it alive, handle its errors and test your code
- [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md): store your own types, expire old entries, load on a miss and set up a table for many readers
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md): count page views, spend a quota, and keep counts exact when many processes count
- [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md): let only one process do a job, share a queue between workers and take batches with `insert_new`, `take` and `take_all`
- [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md): save a table, load it at start-up and handle the ways a load fails
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): every table setting with its default, every error, and the low-level functions

## API Reference

The full API reference is on [HexDocs](https://hexdocs.pm/dream_ets). The guides show each function where a task needs it.

## Design Principles

This module follows [Dream's design principles](https://github.com/TrustBound/dream/blob/release/3.0.0/docs/reference/design-principles.md).

## All Examples Are Tested

Every code example in this README and in the guides comes from `test/snippets/` and is verified by our test suite. You can run them yourself. CI runs the same command:

### Run the tests <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/scripts/check.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/docs/guides/getting-started.md#run-the-tests-"><img align="right" alt="Guide: Getting started" title="Guide: Getting started" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```bash
gleam test
```

See [test/snippets/](https://github.com/TrustBound/dream_ets/tree/main/test/snippets) for complete, runnable examples.

## About Dream

This module was originally built for the [Dream](https://github.com/TrustBound/dream) web toolkit, but it's completely standalone and can be used in any Gleam project. It follows Dream's design principles and will be maintained as part of the Dream ecosystem.

## License

MIT — see [LICENSE.md](https://github.com/TrustBound/dream_ets/blob/main/LICENSE.md)

---

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a> ❤️</sub>
</div>
