# dream_ets 3.1.0 Release Notes

**Release Date:** 2026-11-26

This release adds `table.to_error`. It maps an `EtsError` to `dream_errors.Error`, the error type that the Dream packages share. An app that uses several Dream packages can then handle their errors with one type.

It is a minor version: it only adds a function and a dependency.

## Key Highlights

- **`table.to_error`**: maps each `EtsError` to `dream_errors.Error`, and keeps the `EtsError` as the cause
- **New dependency**: `dream_errors`, a small package with the shared error type and no other dependency than `gleam_stdlib`

## What's New

### `table.to_error`

`table.to_error(error)` gives a `dream_errors.Error(EtsError)`:

- `TableNotFound` gives `NotFound`
- `TableAlreadyExists` gives `Conflict`
- `InvalidKey` and `InvalidValue` give `Invalid`
- `DecodeError` and `OperationFailed` give `Failed`

Each error keeps the `EtsError` as the cause, except `NotFound`, which has no cause. The message is text for developers and logs. Do not show it to the users of an app.

#### Map a lookup error to the shared error <a href="https://github.com/TrustBound/dream_ets/blob/3.1.0/test/snippets/doc_to_error.gleam#L12-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn find_name(
  users: Table(String, String),
  user_id: String,
) -> Result(Option(String), Error(EtsError)) {
  get(users, user_id)
  |> map_error(to_error)
}
```

## Testing

- 344 tests run, 0 failed, in 0.39 to 0.60 seconds over two runs with the coverage report on, and 100% line coverage of `src/` (380/380 lines) (Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, OTP 29, Gleam 1.19.2)

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream_ets = ">= 3.1.0 and < 4.0.0"
```

Then run:

```bash
gleam deps update dream_ets
```

### Migration Guide

No code changes. Every function of 3.0.0 works as before.

## Documentation

- [dream_ets](https://hexdocs.pm/dream_ets) - v3.1.0
- [README](https://github.com/TrustBound/dream_ets/blob/main/README.md)
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md#the-shared-error-type)
- [Changelog](https://github.com/TrustBound/dream_ets/blob/main/CHANGELOG.md)

## Community

- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream_ets/issues)
- [Contributing Guide](https://github.com/TrustBound/dream_ets/blob/main/CONTRIBUTING.md)
