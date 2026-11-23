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
- ✅ **Atomic operations** - `insert_new()`, `take()` for race-free operations
- ✅ **Custom types** - Store any type with custom encoders (JSON, tuples, etc.)
- ✅ **Pattern matching** - Advanced ETS queries and match specifications
- ✅ **Table persistence** - Save/load tables to disk
- ✅ **100% tested** - Comprehensive test coverage with verified examples
- ✅ **Zero dependencies** - No Dream or framework requirements

## Installation

```bash
gleam add dream_ets
```

## Quick Start

### Creating a Table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/creating_tables.gleam#L5-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/docs/guides/getting-started.md#creating-a-table-"><img align="right" alt="Guide" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

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

## Guides

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): install the package and create a first table
- [Table configuration](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/table-configuration.md): build a table with the config builder and set its options
- [Reading and writing](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/reading-and-writing.md): store, read, delete and list values, and run low-level queries
- [Custom types](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/custom-types.md): store your own types with custom encoders, such as JSON
- [Atomic operations](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/atomic-operations.md): use `insert_new` and `take` for race-free locks and queues
- [Counters](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counters.md): count events with counter tables
- [Persistence](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/persistence.md): save a table to disk and load it again
- [Error handling](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/error-handling.md): handle each `EtsError` that an operation returns

## API Reference

The full API reference is on [HexDocs](https://hexdocs.pm/dream_ets). Each guide lists the functions it uses.

## Design Principles

This module follows [Dream's design principles](https://github.com/TrustBound/dream/blob/release/3.0.0/docs/reference/design-principles.md).

## All Examples Are Tested

Every code example in this README and in the guides comes from `test/snippets/` and is verified by our test suite. You can run them yourself:

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
