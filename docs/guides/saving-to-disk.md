# Saving a table to disk

ETS keeps everything in memory. When your program stops, for a deploy or a crash, every table is gone. For a cache that is fine: it fills again. For settings that an admin changed, a list of blocked addresses, or a cache that takes an hour to warm, you want the data back after a restart. dream_ets can write a table to a file and load it again. This guide saves a table, loads it at start-up with its Gleam types, starts empty on the very first run, and covers the ways a load fails.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Save a table to a file](#step-1-save-a-table-to-a-file)
- [Step 2: Load the table at start-up](#step-2-load-the-table-at-start-up)
- [Step 3: Keep a value across a restart](#step-3-keep-a-value-across-a-restart)
- [When to save](#when-to-save)
- [When something goes wrong](#when-something-goes-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you will:

- Write every entry of a table to a file.
- Load the file at start-up, and give the loaded table its key and value types.
- Start with an empty table when no file exists yet.
- Keep a value across a stop and a start of the program.
- Handle a missing directory, a missing file, a table that exists already, and a file with the wrong types.

## Before you start

Add the package:

```sh
gleam add dream_ets
```

Choose a directory for the files that your program can write to, and that survives a deploy. The examples write under `build/` so that you can run them in a project as they are.

A loaded table belongs to the process that loads it, the same as a created one. Load your tables in `main`, as [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#step-3-keep-the-table-alive) explains.

## Step 1: Save a table to a file

`operations.save_to_file(table, path)` writes every entry of the table to the file, and returns `Ok(Nil)`:

### Save a table to a file <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_saving_save.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/result

pub fn save_settings(name: String, path: String) -> Result(Nil, EtsError) {
  use settings <- result.try(
    config.new(name)
    |> config.key_string()
    |> config.value_string()
    |> config.create(),
  )
  use Nil <- result.try(operations.set(settings, "theme", "dark"))
  use Nil <- result.try(operations.set(settings, "language", "en"))
  operations.save_to_file(settings, path)
}
```

`save_settings("site_settings", "build/settings.ets")` returns `Ok(Nil)`, and the file holds both entries.

The file uses the Erlang `ets:tab2file` format. It stores the table name, the table settings (such as its type and access mode), and each entry as an Erlang term. It does not store your Gleam types, or your encoders and decoders. If the file exists, `save_to_file` replaces it.

## Step 2: Load the table at start-up

`operations.load_from_file(path)` reads the file and creates the table again, with the name and the entries it had. It returns a raw table reference, because the file does not know your Gleam types. `table.new_table` gives the loaded table its types:

### Load a saved table, or start empty <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_saving_load.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table, OperationFailed}
import gleam/result
import gleam/string

/// Loads the file and gives the table its key and value types.
pub fn load_settings(
  name: String,
  path: String,
) -> Result(Table(String, String), EtsError) {
  use table_ref <- result.map(operations.load_from_file(path))
  // The file holds the entries, but not the Gleam types. Give them here.
  table.new_table(
    table_ref,
    // The name only labels the value. The file sets the real name.
    name,
    encoders.string_encoder,
    encoders.string_decoder(),
    encoders.string_encoder,
    encoders.string_decoder(),
  )
}

/// Loads the file, or creates an empty table when the file does not exist.
pub fn load_or_create_settings(
  name: String,
  path: String,
) -> Result(Table(String, String), EtsError) {
  case load_settings(name, path) {
    Ok(settings) -> Ok(settings)
    // On the first start there is no file yet
    Error(OperationFailed(reason)) ->
      case string.contains(reason, "enoent") {
        True -> create_settings(name)
        False -> Error(OperationFailed(reason))
      }
    Error(error) -> Error(error)
  }
}

fn create_settings(name: String) -> Result(Table(String, String), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}
```

There are two functions here, for two jobs:

- `load_settings` loads the file and returns a `Table(String, String)`. Give `table.new_table` the same encoders and decoders that the table had when you saved it. The `name` argument only sets what `table.table_name` returns. The table keeps the name it has in the file.
- `load_or_create_settings` is what you call from `main`. On the very first run there is no file, so it creates an empty table instead. Any other error goes back to the caller, because a file that exists but does not load needs a person to look at it.

`load_from_file` reports a missing file as `OperationFailed` with the Erlang reason in the text, such as `{read_error,{file_error,"build/settings.ets",enoent}}`. `enoent` is the Erlang code for "no such file". There is no separate error for it, so `load_or_create_settings` looks for that code in the message.

## Step 3: Keep a value across a restart

Now put the pieces together. This function stores a value, saves, deletes the table as a stop of the program would, and loads again:

### Keep a value across a restart <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_saving_restart.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/option.{type Option}
import gleam/result
import snippets/guide_saving_load.{load_or_create_settings}

pub fn survive_a_restart(path: String) -> Result(Option(String), EtsError) {
  use before <- result.try(load_or_create_settings("restart_settings", path))
  use Nil <- result.try(operations.set(before, "theme", "dark"))
  use Nil <- result.try(operations.save_to_file(before, path))
  // The program stops, and its tables go with it
  use Nil <- result.try(operations.delete_table(before))
  use after <- result.try(load_or_create_settings("restart_settings", path))
  operations.get(after, "theme")
}

/// Saves a table to a directory that does not exist.
pub fn save_to_missing_directory() -> Result(Nil, EtsError) {
  use settings <- result.try(helpers.new_string_table("unsaved_settings"))
  operations.save_to_file(settings, "/no/such/directory/settings.ets")
}
```

`survive_a_restart("build/restart_settings.ets")` returns `Ok(Some("dark"))`. The value came back from the file, into a new table with the same name.

In a real program, the delete happens on its own: the program stops, and its tables go with it. The next start calls `load_or_create_settings` from `main`, and gets the data back.

## When to save

A table is only as fresh as its last save. Pick when to save by how much data you can lose:

| Your situation | Save | Why |
|:---|:---|:---|
| Data changes rarely, such as settings that an admin edits | After each change | Nothing is lost. Each save writes the whole table, which is cheap for a small one. |
| Data changes often, and losing a few minutes is fine, such as a warm cache | On a timer, for example every five minutes, from a process that you start in `main` | The cost of a save does not grow with the number of changes. |
| The program stops in a planned way | Also before it stops | A deploy then loses nothing that changed since the last timed save. |
| Every change must survive a crash | Do not use ETS for it | A crash loses what changed since the last save. Use a database. |

`save_to_file` writes the whole table each time, so a save of a large table takes a while. Call it from a process that can wait, not from a request handler.

## When something goes wrong

Each failure comes back as an `EtsError`. Here is what you will see:

| What happened | What you get |
|:---|:---|
| The directory of the path does not exist | `save_to_file` returns `Error(OperationFailed("{file_error,\"/no/such/directory/settings.ets\",enoent}"))` |
| The file does not exist | `load_from_file` returns `Error(OperationFailed("{read_error,{file_error,\"build/no_such_settings.ets\",enoent}}"))` |
| A table with the name in the file exists already | `load_from_file` returns `Error(OperationFailed("cannot_create_table"))` |
| The table to save was deleted | `save_to_file` returns `Error(TableNotFound)` |
| The file holds other types than your decoders read | `load_from_file` succeeds, and each read returns `Error(DecodeError(...))` |

The last one is the quiet failure. When the file came from a counter table and you load it as a table of `String` values, `operations.get(settings, "theme")` returns a `DecodeError` whose `expected` is `"String"` and whose `found` is `"Int"`. The load itself cannot check this, because the file has no Gleam types. Keep one file per table, and change the file name when you change the types that a table stores.

`cannot_create_table` means you created the table before you loaded it. Load first, and create only when there is no file, as `load_or_create_settings` does.

## Test your code

Test your start-up code with files under `build/`, and with a name of its own for each test's table. Tests often run at the same time, and table names are global. This test module uses [dream_test](https://hexdocs.pm/dream_test), which [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#test-your-code) shows how to add:

### Test the first start with no file <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_saving_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_saving_load.{load_or_create_settings}

pub fn tests() -> TestSuite {
  describe("load_or_create_settings", [
    it("starts with an empty table when the file does not exist", fn() {
      // Arrange
      let path = "build/no_settings_file.ets"

      // Act
      let assert Ok(settings) =
        load_or_create_settings("settings_test_missing", path)

      // Assert
      operations.size(settings)
      |> should
      |> be_equal(Ok(0))
      |> or_fail_with("Expected an empty table")
    }),
  ])
}
```

To test a load of saved data, save it from another process and let that process stop, so that the table is gone before you load. Otherwise the load finds the table and returns `cannot_create_table`. Step 3 does the same with `delete_table`.

## Common pitfalls

**Creating the table, then loading.** *Symptom:* `Error(OperationFailed("cannot_create_table"))` on every start after the first. *Fix:* load first, and create only when the file does not exist.

**Loading in a short-lived process.** *Symptom:* the loaded data is there for a moment, then every operation returns `Error(TableNotFound)`. *Fix:* the process that loads the table owns it. Load in `main`.

**Saving on each request.** *Symptom:* requests get slower as the table grows. *Fix:* each save writes the whole table. Save on a timer from a process of its own.

**Changing the types of a saved table.** *Symptom:* `DecodeError` on reads after a deploy. *Fix:* the file keeps the old terms. Use a new file name for the new types, or clear the table after the load.

**Writing to a temporary directory.** *Symptom:* the data is gone after the machine restarts. *Fix:* many systems empty `/tmp` at boot. Save to a directory that your deploy keeps.

## Where to go next

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): table owners, errors and tests.
- [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md): what to do with entries that no longer decode.
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md): counts that you may want to keep across restarts.
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): every error and the functions that return it.
- [API reference on HexDocs](https://hexdocs.pm/dream_ets/dream_ets/operations.html): `save_to_file`, `load_from_file` and `table.new_table`.
