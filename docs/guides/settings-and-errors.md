# Settings and errors reference

This page lists every table setting with its default, every error with the functions that return it, and the low-level functions that the guides do not use. The guides explain when to use each one. Each function has its full documentation, with tested examples, on [HexDocs](https://hexdocs.pm/dream_ets).

## Table of Contents

- [Table settings](#table-settings)
- [Table types](#table-types)
- [Access modes](#access-modes)
- [Key and value types](#key-and-value-types)
- [Errors](#errors)
- [What each operation costs](#what-each-operation-costs)
- [Low-level functions](#low-level-functions)

## Table settings

Start with `config.new(name)`, add settings, and finish with `config.create()`. The order of the settings does not matter.

| Setting | Default | What it does |
|:---|:---|:---|
| `config.new(name)` | (required) | The name of the table. It must be unique in the Erlang node, and at most 255 characters. Every table is a named table. |
| `config.key_string()`, `config.key(encoder, decoder)` | (required) | How keys are stored and read. Without it, `create` returns `Error(InvalidKey)`. |
| `config.value_string()`, `config.value(encoder, decoder)` | (required) | How values are stored and read. Without it, `create` returns `Error(InvalidValue)`. |
| `config.counter()` | | Sets `String` keys and `Int` values, for the counter helpers. |
| `config.table_type(type)` | `config.table_type_set()` | How the table handles keys. See [Table types](#table-types). |
| `config.access(mode)` | `config.access_public()` | Which processes can read and write. See [Access modes](#access-modes). |
| `config.read_concurrency(Bool)` | `False` | Lets many processes read at the same time without waiting for each other. Writes cost a little more. |
| `config.write_concurrency(Bool)` | `False` | Lets processes write to different keys at the same time. It helps most when the keys spread out. |
| `config.compressed(Bool)` | `False` | Stores values compressed. The table uses less memory, and each read and write costs more CPU. |

Two helpers create the most common tables with the default settings:

| Helper | Same as |
|:---|:---|
| `helpers.new_string_table(name)` | `config.new(name) \|> config.key_string() \|> config.value_string() \|> config.create()` |
| `helpers.new_counter(name)` | `config.new(name) \|> config.counter() \|> config.create()` |

## Table types

| Function | ETS type | Keys | Use it for |
|:---|:---|:---|:---|
| `config.table_type_set()` | `set` | One value per key. The order of keys is not fixed. | Most tables: caches, settings, counters, locks. |
| `config.table_type_ordered_set()` | `ordered_set` | One value per key. `keys`, `values` and `to_list` return them in ascending key order. | Queues, leaderboards, anything you read in order. Inserts cost a little more than in a `set`. |
| `config.table_type_bag()` | `bag` | Many values per key. Identical values are stored one time. `set` adds a value. | Tags of a post, members of a group. |
| `config.table_type_duplicate_bag()` | `duplicate_bag` | Many values per key, identical ones too. `set` adds a value. | Events or messages, where the same value can come two times. |

In a `bag` or `duplicate_bag` table, `get` and `take` return `Error(OperationFailed("the key has 2 values, use get_all"))` (or `take_all`) for a key with more than one value. `size` counts every value, so a key with two values counts as 2.

## Access modes

The owner of a table is the process that created it, or the one that loaded it from a file. When the owner stops, ETS deletes the table.

| Function | Owner | Other processes | Use it for |
|:---|:---|:---|:---|
| `config.access_public()` | Reads and writes | Read and write | Tables that many processes change, such as a cache. This is the default. |
| `config.access_protected()` | Reads and writes | Read only | A table that one process maintains, such as the counter process of [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md#step-4-let-only-one-process-write). |
| `config.access_private()` | Reads and writes | Nothing | Scratch data of one process. |

An operation that the access mode does not allow returns `Error(OperationFailed("ETS refused the operation: badarg"))`.

## Key and value types

`dream_ets/encoders` has an encoder and a decoder for each built-in type. Give them to `config.key` and `config.value`.

| Type | Encoder | Decoder |
|:---|:---|:---|
| `String` | `encoders.string_encoder` | `encoders.string_decoder()` |
| `Int` | `encoders.int_encoder` | `encoders.int_decoder()` |
| `Float` | `encoders.float_encoder` | `encoders.float_decoder()` |
| `Bool` | `encoders.bool_encoder` | `encoders.bool_decoder()` |

For your own types, write an encoder to `Dynamic` and a `Decoder`, as [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md#step-1-store-your-own-type) shows.

## Errors

Every function returns `Result(_, EtsError)`. Nothing crashes the calling process.

| Error | What it means | Returned by |
|:---|:---|:---|
| `TableNotFound` | The table does not exist: it was deleted, or its owner process stopped. | Every operation on a table, the counter helpers, `save_to_file` |
| `TableAlreadyExists` | A table with this name exists in the node. | `config.create`, `helpers.new_string_table`, `helpers.new_counter` |
| `InvalidKey` | The configuration has no key encoder. | `config.create` |
| `InvalidValue` | The configuration has no value encoder. | `config.create` |
| `DecodeError(error)` | A stored key or value does not decode with the decoder of the table. `error.expected` and `error.found` say what the decoder wanted and what it found. | `get`, `get_all`, `take`, `take_all`, `keys`, `values`, `to_list`, the counter helpers |
| `OperationFailed(reason)` | ETS refused the operation. The reason is in the text. | See below |

The texts of `OperationFailed` that you will meet:

| Text | Cause | Returned by |
|:---|:---|:---|
| `ETS refused the operation: badarg` | The access mode does not allow this process, or a match pattern or match specification is not valid. | Every operation on a table |
| `the key has 2 values, use get_all` (or `take_all`) | `get` or `take` on a key with several values in a bag table. The number is the count of values. | `get`, `take` |
| `ETS rejected the table name: system_limit` | The name has more than 255 characters. | `config.create` |
| `{file_error,"<path>",enoent}` | The directory of the path does not exist. | `save_to_file` |
| `{read_error,{file_error,"<path>",enoent}}` | The file does not exist. | `load_from_file` |
| `cannot_create_table` | A table with the name in the file exists already. | `load_from_file` |

[Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#when-something-goes-wrong) shows a function that handles each error of a lookup.

### The shared error type

`table.to_error` maps an `EtsError` to `dream_errors.Error(EtsError)`, the error type that the Dream packages share. An app can then handle the errors of several packages with one type. The `EtsError` stays whole as the cause, except for `NotFound`, which has no cause.

| `EtsError` | `dream_errors.Error` | Message |
|:---|:---|:---|
| `TableNotFound` | `NotFound` | `the ETS table does not exist, or it was deleted` |
| `TableAlreadyExists` | `Conflict` | `an ETS table with this name exists` |
| `InvalidKey` | `Invalid` | `the table configuration has no key encoder` |
| `InvalidValue` | `Invalid` | `the table configuration has no value encoder` |
| `DecodeError(error)` | `Failed` | `a key or value in the ETS table does not decode with the decoder of the table` |
| `OperationFailed(reason)` | `Failed` | `the ETS operation failed: ` and the reason |

The message is text for developers and logs. Do not show it to the users of an app.

## What each operation costs

| Operations | Cost |
|:---|:---|
| `set`, `get`, `get_all`, `delete`, `member`, `insert_new`, `take`, `take_all`, `update_element` | One key. The time does not grow with the size of a `set` table. In an `ordered_set`, it grows with the logarithm of the size. |
| `size` | Constant. ETS keeps the count of objects, and `size` reads it. |
| `increment`, `increment_by`, `decrement`, `decrement_by` | One key, in one ETS operation. |
| `keys`, `values`, `to_list` | The whole table. They build a list of every key. |
| `match`, `match_object`, `select` | The whole table, unless the pattern fixes the key. |
| `delete_all_objects`, `delete_table` | The whole table, in one ETS operation. |
| `save_to_file`, `load_from_file` | The whole table, written to or read from a file. |

## Low-level functions

These functions give you ETS features that the typed API does not cover. They take and return `Dynamic` values, so the compiler cannot check them. Each one has a tested example on HexDocs.

| Function | What it does |
|:---|:---|
| [`operations.match(table, pattern)`](https://hexdocs.pm/dream_ets/dream_ets/operations.html#match) | Returns the bound variables (`'$1'`, `'$2'`, ...) of each entry that matches an Erlang match pattern. |
| [`operations.match_object(table, pattern)`](https://hexdocs.pm/dream_ets/dream_ets/operations.html#match_object) | Returns each whole `{key, value}` entry that matches an Erlang match pattern. |
| [`operations.select(table, match_spec)`](https://hexdocs.pm/dream_ets/dream_ets/operations.html#select) | Runs an Erlang match specification, for queries with conditions. |
| [`operations.update_element(table, key, position, value)`](https://hexdocs.pm/dream_ets/dream_ets/operations.html#update_element) | Replaces one element of the stored `{key, value}` tuple in place. Position 2 is the value. Returns `Ok(False)` when the key is not there. |
| [`table.table_name(table)`](https://hexdocs.pm/dream_ets/dream_ets/table.html#table_name) | The name that the `Table` value carries. |
| [`table.table_ref(table)`](https://hexdocs.pm/dream_ets/dream_ets/table.html#table_ref) | The raw ETS reference of the table. |
| [`table.new_table(ref, name, ...)`](https://hexdocs.pm/dream_ets/dream_ets/table.html#new_table) | Makes a typed `Table` from a raw reference, for example after `load_from_file`. [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md#step-2-load-the-table-at-start-up) uses it. |
| [`table.encode_key`](https://hexdocs.pm/dream_ets/dream_ets/table.html#encode_key), [`table.decode_key`](https://hexdocs.pm/dream_ets/dream_ets/table.html#decode_key), [`table.encode_value`](https://hexdocs.pm/dream_ets/dream_ets/table.html#encode_value), [`table.decode_value`](https://hexdocs.pm/dream_ets/dream_ets/table.html#decode_value) | Run the encoders and decoders of a table by hand, for example to build a match pattern with a typed key. |
