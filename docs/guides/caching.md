# Caching data in memory

Some data is slow to get and fast to go stale: a user profile from the database, a response from a partner API, a page that takes 200 ms to render. If every request fetches it again, your program spends most of its time waiting. A cache in an ETS table keeps the last answer in memory, where every request process can read it in microseconds. This guide builds a profile cache step by step: your own type in a table, entries that expire, a read that loads on a miss, and the settings for a busy server.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Store your own type](#step-1-store-your-own-type)
- [Step 2: Expire old entries](#step-2-expire-old-entries)
- [Step 3: Load on a miss](#step-3-load-on-a-miss)
- [Step 4: Remove, list and clear entries](#step-4-remove-list-and-clear-entries)
- [Step 5: Set up the table for many readers](#step-5-set-up-the-table-for-many-readers)
- [Which encoding to use](#which-encoding-to-use)
- [When something goes wrong](#when-something-goes-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you will:

- Store a custom `Profile` type in a table, with an encoder and a decoder.
- Give each entry a time to live, and treat a stale entry as a miss.
- Read a profile from the cache, and load it from the slow source when it is not there.
- Remove one entry when its source changes, list the entries and clear the cache.
- Turn on the table settings that help when many processes read at the same time.
- Handle an entry that an older version of your program stored.

## Before you start

You need the package, and a table that lives as long as your program. If you have not made one yet, read [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md) first, because a table goes away with the process that created it.

```sh
gleam add dream_ets
```

The examples are modules that import each other, as they would in your project. Each one says which earlier step it builds on.

The cache functions take the current time, `now`, in seconds, as a parameter. In your program, pass the real time, for example from the `gleam_time` package. In tests, pass fixed numbers. That keeps the code free of hidden clocks, and makes expiry easy to test.

## Step 1: Store your own type

ETS stores Erlang terms. To store a Gleam type, give the table two functions: an encoder that turns your value into a `Dynamic`, and a decoder that turns it back. The cache stores an `Entry`: the `Profile`, and the time at which it becomes stale.

The fastest encoding is an Erlang tuple. ETS copies the tuple as it is, with no text to parse on each read:

### A cache table for profiles <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_entry.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/table.{type EtsError, type Table}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}

pub type Profile {
  Profile(name: String, plan: String)
}

/// A cached profile, and the time in seconds at which it becomes stale.
pub type Entry {
  Entry(profile: Profile, expires_at: Int)
}

pub fn create_profile_cache(
  name: String,
) -> Result(Table(String, Entry), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  |> config.create()
}

/// Stores an entry as the tuple {Name, Plan, ExpiresAt}.
pub fn encode_entry(entry: Entry) -> Dynamic {
  dynamic.array([
    dynamic.string(entry.profile.name),
    dynamic.string(entry.profile.plan),
    dynamic.int(entry.expires_at),
  ])
}

pub fn entry_decoder() -> Decoder(Entry) {
  use name <- decode.field(0, decode.string)
  use plan <- decode.field(1, decode.string)
  use expires_at <- decode.field(2, decode.int)
  decode.success(Entry(Profile(name: name, plan: plan), expires_at: expires_at))
}
```

Here is how the two directions fit:

- `encode_entry` builds the tuple `{<<"Ada">>, <<"pro">>, 1300}` with `dynamic.array`, which is a tuple on the Erlang target.
- `entry_decoder` reads the three fields back by position, with `decode.field(0, ...)`, `decode.field(1, ...)` and `decode.field(2, ...)`.
- `config.value(encode_entry, entry_decoder())` gives the table both. The result is a `Table(String, Entry)`, and the compiler checks every `set` and `get` against those types.

Keep the encoder and the decoder next to each other, and change them together. If they disagree, every read returns a `DecodeError`.

## Step 2: Expire old entries

A cache must forget, or it serves old data forever. Store the time at which each entry goes stale, and check it on each read:

### Store a profile and read it while it is fresh <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_lookup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table, DecodeError}
import gleam/option.{type Option, None, Some}
import gleam/result
import snippets/guide_caching_entry.{type Entry, type Profile, Entry}

const time_to_live_seconds = 300

pub fn remember(
  cache: Table(String, Entry),
  user_id: String,
  profile: Profile,
  now: Int,
) -> Result(Nil, EtsError) {
  let entry = Entry(profile: profile, expires_at: now + time_to_live_seconds)
  operations.set(cache, user_id, entry)
}

/// Returns the profile while it is fresh. A stale entry, or an entry that
/// does not decode, is removed and counts as a miss.
pub fn lookup(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
) -> Result(Option(Profile), EtsError) {
  case operations.get(cache, user_id) {
    Ok(Some(entry)) if entry.expires_at > now -> Ok(Some(entry.profile))
    Ok(Some(_stale)) | Error(DecodeError(_)) ->
      operations.delete(cache, user_id) |> result.replace(None)
    Ok(None) -> Ok(None)
    Error(error) -> Error(error)
  }
}
```

With an entry remembered at `now` 1000, it expires at 1300:

### What lookup returns before and after 1300 <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_caching_lookup.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
lookup(cache, "user:1", 1200)  -> Ok(Some(Profile("Ada", "pro")))
lookup(cache, "user:1", 1300)  -> Ok(None)
```

A few things to notice:

- `lookup` removes a stale entry when it finds one. After the second call above, `operations.member(cache, "user:1")` returns `Ok(False)`. So entries that nobody reads again stay in the table until you clear them ([Step 4](#step-4-remove-list-and-clear-entries)).
- An entry that does not decode counts as a miss too. That is the safe choice for a cache: the next step loads a fresh copy, and the cache heals itself. The [failure section](#when-something-goes-wrong) shows where such entries come from.
- Every other error, such as `TableNotFound`, goes back to the caller. A missing table is a bug in your program, not a cache miss.

## Step 3: Load on a miss

Now put the cache in front of the slow source. On a hit, return the cached profile. On a miss, load it, remember it, and return it:

### Read through the cache <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_read_through.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/table.{type EtsError, type Table}
import gleam/option.{None, Some}
import gleam/result
import snippets/guide_caching_entry.{type Entry, type Profile}
import snippets/guide_caching_lookup.{lookup, remember}

pub type CacheError {
  /// The cache table refused the operation.
  CacheFailed(EtsError)
  /// The slow source could not load the profile.
  LoadFailed(String)
}

pub fn get_profile(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
  load: fn(String) -> Result(Profile, String),
) -> Result(Profile, CacheError) {
  use cached <- result.try(
    lookup(cache, user_id, now) |> result.map_error(CacheFailed),
  )
  case cached {
    Some(profile) -> Ok(profile)
    None -> load_and_remember(cache, user_id, now, load)
  }
}

fn load_and_remember(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
  load: fn(String) -> Result(Profile, String),
) -> Result(Profile, CacheError) {
  use profile <- result.try(load(user_id) |> result.map_error(LoadFailed))
  remember(cache, user_id, profile, now)
  |> result.replace(profile)
  |> result.map_error(CacheFailed)
}
```

`get_profile` takes the loader as a function, so your program passes the real database call and your tests pass a stub. Here is what it returns, with `load_ada` a loader that returns Ada's profile and `database_down` a loader that returns `Error("database is down")`:

### What get_profile returns <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_caching_read_through.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
get_profile(cache, "user:1", 1000, load_ada)       -> Ok(Profile("Ada", "pro"))
get_profile(cache, "user:1", 1100, database_down)  -> Ok(Profile("Ada", "pro"))
get_profile(empty, "user:1", 1000, database_down)  -> Error(LoadFailed("database is down"))
```

The second line is the point of a cache: the database is down, but the profile was loaded at 1000 and is still fresh at 1100, so the request still gets its answer.

`CacheError` keeps the two failures apart: `CacheFailed` when the table refused, and `LoadFailed` when the source did. Your handler can answer a `LoadFailed` with a 503, and log a `CacheFailed` as a bug.

## Step 4: Remove, list and clear entries

When a profile changes in the database, remove its entry, so that the next read loads the new version. You will also want to see what is in the cache, and to empty it:

### Remove, list and clear entries <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_maintenance.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/list
import gleam/result
import gleam/string
import snippets/guide_caching_entry.{type Entry, type Profile}

/// Call this when a profile changes in the slow source.
pub fn forget(
  cache: Table(String, Entry),
  user_id: String,
) -> Result(Nil, EtsError) {
  operations.delete(cache, user_id)
}

/// The user ids in the cache, sorted. Reads the whole table.
pub fn cached_user_ids(
  cache: Table(String, Entry),
) -> Result(List(String), EtsError) {
  use user_ids <- result.map(operations.keys(cache))
  list.sort(user_ids, string.compare)
}

/// The profiles in the cache, stale ones too. Reads the whole table.
pub fn cached_profiles(
  cache: Table(String, Entry),
) -> Result(List(Profile), EtsError) {
  use entries <- result.map(operations.values(cache))
  list.map(entries, fn(entry) { entry.profile })
}

pub fn entry_count(cache: Table(String, Entry)) -> Result(Int, EtsError) {
  operations.size(cache)
}

/// Removes every entry and keeps the table.
pub fn clear(cache: Table(String, Entry)) -> Result(Nil, EtsError) {
  operations.delete_all_objects(cache)
}
```

With two profiles cached, for `user:1` and `user:2`:

### What the maintenance functions return <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_caching_maintenance.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
cached_user_ids(cache)                           -> Ok(["user:1", "user:2"])
entry_count(cache)                               -> Ok(2)
forget(cache, "user:1") then entry_count(cache)  -> Ok(1)
clear(cache) then entry_count(cache)             -> Ok(0)
```

`cached_profiles(cache)` returns both profiles, in the order of the table. A `set` table has no fixed order, so sort the list if you show it.

Know what each of these costs:

- `operations.delete` and `operations.get` touch one key. They take the same short time on a table of ten entries or ten million.
- `operations.keys`, `operations.values` and `operations.to_list` walk the whole table, and build a list of all of it. On a large table, call them from an admin page or a report, not from each request.
- `operations.size` reads the count that ETS keeps for the table. It takes the same short time on any size of table.
- `operations.delete_all_objects` empties the table and keeps it, so the `Table` value stays valid. `operations.delete_table` removes the table itself. After that, every operation returns `Error(TableNotFound)`.

## Step 5: Set up the table for many readers

A cache in a web server is read by many request processes at the same time, and written much less often. Tell ETS so when you create the table:

### A profile cache for many readers <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_settings.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/table.{type EtsError, type Table}
import snippets/guide_caching_entry.{type Entry, encode_entry, entry_decoder}

pub fn create_busy_profile_cache(
  name: String,
) -> Result(Table(String, Entry), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  // Many request processes read at the same time
  |> config.read_concurrency(True)
  // Any process can write, so every request handler can fill the cache
  |> config.access(config.access_public())
  |> config.create()
}
```

It stores and reads profiles exactly as before: `remember` then `lookup` returns `Ok(Some(Profile(name: "Ada", plan: "pro")))`.

Each setting is a trade, so choose by what your table does:

| Your situation | Use | Why |
|:---|:---|:---|
| Many processes read at the same time, writes are rare | `config.read_concurrency(True)` | Readers do not wait for each other. Writes cost a little more. |
| Many processes write at the same time, to different keys | `config.write_concurrency(True)` | Writers to different keys do not wait for each other. It helps most when the keys spread out. |
| Large values that compress well, such as HTML or JSON text | `config.compressed(True)` | The table uses less memory. Each read and write costs more CPU. |
| Any process may write, such as request handlers that fill the cache | `config.access(config.access_public())` | This is the default. The line above only makes the choice visible. |
| Only the owner writes, every process reads | `config.access(config.access_protected())` | Writes from other processes return `Error(OperationFailed(...))`. [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md) uses this. |

The [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md) lists every setting with its default.

## Which encoding to use

The tuple encoding of Step 1 is the fastest, but it is not the only way. Pick by what you already have:

| Your situation | Use | Why |
|:---|:---|:---|
| A type with a few fields | A tuple, as in [Step 1](#step-1-store-your-own-type) | No text to build or parse. ETS copies the term as it is. |
| A type that already has JSON encoders and decoders | A JSON string, with `json.to_string` and `json.parse` | You reuse code you have. Each read parses the text again. |
| `String`, `Int`, `Float` or `Bool` | The functions in `dream_ets/encoders` | They are built in. |

Here is the JSON way. dream_ets does not depend on `gleam_json`, so add it to your project first with `gleam add gleam_json`:

### Store a user as a JSON string <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/custom_types.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string

pub type User {
  User(name: String, email: String)
}

fn encode_user(user: User) -> dynamic.Dynamic {
  json.object([
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string
  |> dynamic.string
}

fn decode_user() -> decode.Decoder(User) {
  decode.string
  |> decode.then(fn(json_text) {
    case json.parse(json_text, user_from_json()) {
      Ok(user) -> decode.success(user)
      Error(error) ->
        decode.failure(User("", ""), "User JSON: " <> string.inspect(error))
    }
  })
}

fn user_from_json() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(name: name, email: email))
}

pub fn store_custom_type() -> Result(String, table.EtsError) {
  use users <- result.try(
    config.new("users")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )

  let user = User(name: "Alice", email: "alice@example.com")
  use _ <- result.try(operations.set(users, "alice", user))

  use retrieved <- result.try(operations.get(users, "alice"))

  case retrieved {
    option.Some(stored_user) ->
      Ok(stored_user.name <> " <" <> stored_user.email <> ">")
    option.None -> Error(table.OperationFailed("User not found"))
  }
}
```

`store_custom_type()` returns `Ok("Alice <alice@example.com>")`. The decoder first reads a `String`, then parses it as JSON. If the text is not valid JSON for a `User`, `decode.failure` turns that into a `DecodeError`, so the table never hands you a broken `User`.

Keys can have their own type too. Use `config.key(encoder, decoder)` in the same way.

## When something goes wrong

The failure you will meet most in a cache is an entry that does not decode. A `DecodeError` means the stored term does not match the decoder of the table. In a cache, it comes from:

- A deploy that changed the encoding while the table kept running, for example after a hot code upgrade.
- A table that was loaded from a file that an older version of the program saved ([Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md)).
- Two `Table` values with different types for one ETS table.

When an older version stored a plain `String` where the cache now expects an `Entry` tuple, `operations.get(cache, "user:1")` returns:

### The error for an entry in an old format <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_caching_decode_error.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Error(DecodeError(DecodeError("Indexable", "String", [])))
```

The decoder wanted something it could read by position (a tuple), and found a `String`. `lookup` from Step 2 turns this into a miss, deletes the entry, and returns `Ok(None)`, so `get_profile` loads a fresh profile. In a table where the data is not a copy of something else, do not delete it. Log the error, and fix the encoder or the data.

The other errors are the ones every table has: `TableNotFound` when the owner process stopped, and `OperationFailed` when the access setting refuses a process. [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#when-something-goes-wrong) shows how to handle each one.

## Test your code

Because `lookup` and `get_profile` take the time and the loader as parameters, a test controls both. Make a table with a name of its own, put an entry in it at a fixed time, and read at another time. Tests often run at the same time, and table names are global, so each test gets its own table name. This module uses [dream_test](https://hexdocs.pm/dream_test), which [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#test-your-code) shows how to add:

### Test the cache with fixed times and a stub loader <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_caching_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guide_caching_entry.{type Profile, Profile, create_profile_cache}
import snippets/guide_caching_lookup.{lookup, remember}
import snippets/guide_caching_read_through.{get_profile}

fn database_down(_user_id: String) -> Result(Profile, String) {
  Error("database is down")
}

pub fn tests() -> TestSuite {
  let ada = Profile(name: "Ada", plan: "pro")
  describe("profile cache", [
    it("misses an entry after its time to live", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("cache_test_expired")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let found = lookup(cache, "user:1", 1300)

      // Assert
      found
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("Expected a miss at 1300")
    }),
    it("serves a fresh entry when the source is down", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("cache_test_source_down")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let profile = get_profile(cache, "user:1", 1100, database_down)

      // Assert
      profile
      |> should
      |> be_equal(Ok(ada))
      |> or_fail_with("Expected the cached profile")
    }),
  ])
}
```

The first test checks expiry without a clock. The second one checks that a fresh entry still answers when the source fails. The stub loader `database_down` would make the test fail if `get_profile` called it.

To test the decode path, write an old entry through a second view of the same table. `table.new_table(table.table_ref(cache), name, ...)` with the `String` encoders gives you that view. Then `lookup` must return `Ok(None)`.

## Common pitfalls

**A cache that only grows.** *Symptom:* memory use climbs for days. *Fix:* `lookup` removes stale entries only when something reads them. Clear the table now and then with `operations.delete_all_objects`, or remove the stale entries on a timer with `operations.to_list` and `operations.delete`.

**Many processes load the same key at once.** *Symptom:* when a popular entry expires, the database gets the same query from every request at the same moment. *Fix:* `get_profile` does not stop two processes from loading the same miss. If that load is expensive, let only one process load it, with a lock from [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md), and let the others use the old entry or wait.

**Calling `keys`, `values` or `to_list` on each request.** *Symptom:* requests get slower as the cache grows. *Fix:* these walk the whole table. If you only need the number of entries, call `operations.size`, which does not walk the table.

**Changing the encoder without a plan for old entries.** *Symptom:* `DecodeError` after a deploy. *Fix:* treat a decode failure as a miss, as `lookup` does, or clear the table when the new version starts.

**JSON for every read.** *Symptom:* a hot cache uses a lot of CPU. *Fix:* each read of a JSON value parses the text. Use the tuple encoding for values you read often.

## Where to go next

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): table owners, errors and tests.
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md): count hits and misses of your cache.
- [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md): let only one process load a missing entry.
- [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md): keep a warm cache across restarts.
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): every table setting with its default.
- [API reference on HexDocs](https://hexdocs.pm/dream_ets/dream_ets/operations.html): `set`, `get`, `delete`, `keys`, `values`, `to_list`, `size` and the rest.
