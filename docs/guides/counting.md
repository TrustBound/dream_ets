# Counting events

You want numbers about your running program: page views per path, API calls per user, failed logins per address. Each event adds one to a count, and the counts must be cheap to update and easy to read. A counter table in ETS does that in memory. This guide starts with a counter in one process, counts from many processes at the same time, lets only one process write when your design needs that, and ends with a quota that many processes can share and cannot overspend.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Count page views](#step-1-count-page-views)
- [Step 2: Read the counts](#step-2-read-the-counts)
- [Step 3: Count from many processes](#step-3-count-from-many-processes)
- [Step 4: Let only one process write](#step-4-let-only-one-process-write)
- [Step 5: Spend a quota without overspending](#step-5-spend-a-quota-without-overspending)
- [Which way to count](#which-way-to-count)
- [When something goes wrong](#when-something-goes-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you will:

- Count page views with a counter table.
- Read one count, and build a sorted report of all counts.
- Count one key from ten processes at the same time, and get the exact total.
- Build a counter process that is the only writer of its table, while any process reads it.
- Spend credits from a daily quota, refuse a request that costs too much, and stay inside the quota when many processes spend at once.
- Test the counter and the quota with many processes at once.

## Before you start

Add the package:

```sh
gleam add dream_ets
```

A table lives as long as the process that created it. Create your counters in a process that runs as long as your program, as [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#step-3-keep-the-table-alive) explains. Each example below is a complete module that you can call from `main` or from a test.

## Step 1: Count page views

A counter table has `String` keys and `Int` values. `helpers.new_counter(name)` creates one, and `helpers.increment(table, key)` adds one to a key:

### Count page views and read the counts <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_counting_page_views.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn count_three_views() -> Result(Int, EtsError) {
  use views <- result.try(helpers.new_counter("page_views_by_path"))
  use _ <- result.try(helpers.increment(views, "/"))
  use _ <- result.try(helpers.increment(views, "/about"))
  helpers.increment(views, "/")
}

/// The count of one path. A path with no views has no key, so it is 0.
pub fn views_of(
  views: Table(String, Int),
  path: String,
) -> Result(Int, EtsError) {
  use count <- result.map(operations.get(views, path))
  option.unwrap(count, 0)
}

/// Every path with its count, sorted by path.
pub fn report(
  views: Table(String, Int),
) -> Result(List(#(String, Int)), EtsError) {
  use pairs <- result.map(operations.to_list(views))
  list.sort(pairs, fn(left, right) { string.compare(left.0, right.0) })
}
```

`count_three_views()` returns `Ok(2)`: the count of `/` after its second view.

A few things to know about `increment`:

- It returns the new count, so you can log it or act on it at once.
- A key that has no count yet starts at 0, so the first `increment` returns `Ok(1)`. You do not create keys before you count them.
- `helpers.increment_by(table, key, amount)` adds any amount, and `helpers.decrement` and `helpers.decrement_by` subtract. A count can go below zero.
- The read, the addition and the write are one ETS operation (`ets:update_counter`). [Step 3](#step-3-count-from-many-processes) shows what that gives you.

`helpers.new_counter(name)` is the same as `config.new(name) |> config.counter() |> config.create()`. Use the builder form when you need a setting such as `write_concurrency`.

## Step 2: Read the counts

The module in Step 1 also has two readers. `views_of` reads one count, and turns a missing key into 0. `report` reads every count and sorts them by path:

```text
views_of(views, "/pricing")  -> Ok(0)
report(views)                -> Ok([#("/", 2), #("/about", 1)])
```

`report` uses `operations.to_list`, which walks the whole table. That is fine for an admin page. Do not call it on each request of a large table.

## Step 3: Count from many processes

A web server handles each request in its own process, so many processes count the same page at the same time. Each `increment` is one ETS operation, so no process can write between the read and the write of another. Every increment counts.

This function starts ten processes. Each one adds one to the same key 1000 times, at the same time as the others:

### Ten processes increment one key at the same time <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_counting_many_processes.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError}
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/result

pub fn count_from_ten_processes() -> Result(Option(Int), EtsError) {
  use hits <- result.try(helpers.new_counter("hits_from_ten_processes"))
  let finished = process.new_subject()
  let workers = list.repeat(Nil, 10)
  list.each(workers, fn(_) {
    process.spawn(fn() {
      let added =
        list.try_each(list.repeat(Nil, 1000), fn(_) {
          helpers.increment(hits, "/")
        })
      process.send(finished, added)
    })
  })
  // Wait until each process reports that its 1000 increments are done
  use _ <- result.try(
    list.try_map(workers, fn(_) { process.receive_forever(finished) }),
  )
  operations.get(hits, "/")
}
```

`count_from_ten_processes()` returns `Ok(Some(10000))`: 10 processes times 1000 increments. The result is the same on every run.

Here is how it works:

- Each process sends the result of its 1000 increments to the `finished` subject when it is done.
- The function waits for one message from each of the ten processes before it reads the count. Then every increment is done, and the count is final.
- `process.spawn` links each process to the caller. If a process crashes, the caller crashes too, so the wait cannot go on forever.

No lock and no extra process is necessary. Any process that has the `Table` value can count.

## Step 4: Let only one process write

Sometimes only one part of your program may change the counts. Maybe the counts come from one source of events, or a bug in other code must not be able to reset them. Then let one process own the table, and let it be the only writer. Every other process sends it a message for each increment, and reads the table directly.

ETS has an access mode made for this: `protected`. The owner process writes, and every process reads. If you create the table inside the counter process, ETS itself refuses writes from any other process, so no code can skip the counter by mistake:

### A counter process that owns the table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_counting_counter_process.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process.{type Subject}
import gleam/option
import gleam/result

pub opaque type Counter {
  Counter(inbox: Subject(Message), counts: Table(String, Int))
}

type Message {
  Increment(key: String, reply_to: Subject(Result(Int, EtsError)))
}

/// Starts the counter process. It creates the table, so it owns it.
pub fn start(table_name: String) -> Result(Counter, EtsError) {
  let started = process.new_subject()
  process.spawn(fn() {
    let inbox = process.new_subject()
    let created =
      config.new(table_name)
      // Only the owner can write. Every process can read.
      |> config.access(config.access_protected())
      |> config.counter()
      |> config.create()
    process.send(started, result.map(created, Counter(inbox, _)))
    case created {
      Ok(counts) -> serve(inbox, counts)
      Error(_) -> Nil
    }
  })
  process.receive_forever(started)
}

fn serve(inbox: Subject(Message), counts: Table(String, Int)) -> Nil {
  let Increment(key, reply_to) = process.receive_forever(inbox)
  // Only this process can write to the table
  process.send(reply_to, helpers.increment(counts, key))
  serve(inbox, counts)
}

/// Adds one to `key` and returns the new count. Waits at most one second.
pub fn increment(counter: Counter, key: String) -> Result(Int, EtsError) {
  process.call(counter.inbox, 1000, Increment(key, _))
}

/// Reads a count straight from the table, in the calling process.
pub fn count(counter: Counter, key: String) -> Result(Int, EtsError) {
  use value <- result.map(operations.get(counter.counts, key))
  option.unwrap(value, 0)
}

/// The table, for code that only reads it.
pub fn counts(counter: Counter) -> Table(String, Int) {
  counter.counts
}
```

Here is how it works:

- `start` spawns the counter process. That process creates the table, so it owns it, and sends the `Counter` back. If `create` fails, `start` returns the error.
- `increment` sends an `Increment` message with `process.call` and waits for the new count. The counter process runs `helpers.increment` on its own table.
- `count` reads the table in the calling process. It does not send a message, so reads stay fast while the counter is busy.
- `process.spawn` links the counter process to the process that calls `start`. Call `start` from `main`, so that the counter lives as long as your program.

With this counter, ten processes that each call `increment` 100 times give a count of exactly 1000. The [test](#test-your-code) below checks it.

Every increment is now a message and a reply, so it costs more than a direct `helpers.increment`. Use a counter process when one writer is a rule of your design, not to make the count exact: [Step 3](#step-3-count-from-many-processes) is exact without it.

## Step 5: Spend a quota without overspending

Counts also make quotas. Here each user can spend 100 credits a day. A request adds its cost, and if the total goes over the limit, the request gives the credits back and fails:

### Spend credits from a daily quota <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_counting_quota.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/table.{type EtsError, type Table}
import gleam/int
import gleam/result

pub const daily_credits = 100

pub type SpendError {
  /// The user has fewer credits left than the request costs.
  NotEnoughCredits(left: Int)
  StorageFailed(EtsError)
}

/// Spends `cost` credits and returns the credits that are left.
pub fn spend(
  spent: Table(String, Int),
  user_id: String,
  cost: Int,
) -> Result(Int, SpendError) {
  // Spend first: the new total includes every request that came before
  use total <- result.try(
    helpers.increment_by(spent, user_id, cost)
    |> result.map_error(StorageFailed),
  )
  case total > daily_credits {
    False -> Ok(daily_credits - total)
    True -> give_back(spent, user_id, cost, total)
  }
}

fn give_back(
  spent: Table(String, Int),
  user_id: String,
  cost: Int,
  total: Int,
) -> Result(Int, SpendError) {
  // Put the credits back, then report what was left before this request.
  // Other refused requests can still hold credits for a moment, so the
  // number can be below zero. Report 0 then.
  use _ <- result.try(
    helpers.decrement_by(spent, user_id, cost)
    |> result.map_error(StorageFailed),
  )
  Error(NotEnoughCredits(left: int.max(0, daily_credits - total + cost)))
}

/// Gives one credit back, for example for a request that failed.
pub fn refund_one(
  spent: Table(String, Int),
  user_id: String,
) -> Result(Int, EtsError) {
  helpers.decrement(spent, user_id)
}
```

For a new user:

```text
spend(spent, "user:1", 30)   -> Ok(70)
spend(spent, "user:1", 80)   -> Error(NotEnoughCredits(left: 70))
refund_one(spent, "user:1")  -> Ok(29)
```

After the refused request, the count is back at 30, because `give_back` subtracted the 80 again.

The order of `spend` is what keeps the quota safe when many processes spend at the same time. Compare the two ways to write it:

- **Check, then spend.** Read the total with `operations.get`, compare it with the limit, then add the cost. This is not safe. Two processes can both read 90, both see room for 10 more, and both spend. The total is then 110. Each call is one ETS operation, but the read and the write are two calls, and another process can spend between them.
- **Spend, then check.** Add the cost with `helpers.increment_by`, which returns the new total in the same ETS operation. Every request that came before is in that total, so the check sees all of them. If the total is over the limit, give the cost back. This is what `spend` does.

With "spend, then check", the accepted requests never add up to more than 100. Ten processes that each try to spend 1 credit 20 times get exactly 100 credits accepted, and the count ends at 100. The [test](#test-your-code) below checks it.

While a refused request holds its credits, before it gives them back, the total is over 100 for a moment. Another request in that moment is refused too, and its `left` can come out below zero. `give_back` reports 0 then. A request that is refused in this way can try again.

To start a new day, empty the table with `operations.delete_all_objects(spent)`.

## Which way to count

| Your situation | Use | Why |
|:---|:---|:---|
| One process or many processes count, and the count must be exact | `helpers.increment` on a counter table | Each increment is one ETS operation, so no increment gets lost. Any process reads directly. |
| Only one process may change the counts | A counter process, as in [Step 4](#step-4-let-only-one-process-write) | The table is `protected`, so ETS refuses writes from every other process. |
| A count must not go over a limit | `helpers.increment_by`, then check the new total, as in [Step 5](#step-5-spend-a-quota-without-overspending) | The new total includes every request before, so the check cannot miss one. |
| You read a count, decide, and then write a new value with `set` | Do not, if other processes write the same key | Another process can write between your `get` and your `set`, and its change is lost. |

## When something goes wrong

**The counter process stopped.** Then its table is gone, and `count` returns `Error(TableNotFound)`. `increment` panics, because `process.call` panics when the process it calls has stopped. Start the counter from `main`, or from a supervisor that starts it again, and know that a restart starts at zero.

**Another process writes to the table directly.** A process that calls `helpers.increment(counter.counts(views), "/")` gets `Error(OperationFailed("ETS refused the operation: badarg"))`, because the table is `protected`. That error is the point of the design: change that code to call `counter.increment`.

**A count goes below zero.** `helpers.decrement` does not stop at zero. If a count must not go negative, subtract first and check the new value, as `spend` does with its limit.

**The value is not an `Int`.** A counter table decodes its values as `Int`. A table that another part of your program filled with other values returns `Error(DecodeError(...))` from `increment`, and does not change the value.

**The table is a bag.** ETS can only add to the value of a key that has one value. On a `bag` or `duplicate_bag` table, `increment` returns `Error(OperationFailed("ETS refused the operation: badarg"))`. Create counters with `helpers.new_counter` or `config.counter()`, which make a `set` table.

## Test your code

The tests that matter for counters are the concurrent ones: start many processes, let each count or spend, wait for all of them, and check the exact total. This test module uses [dream_test](https://hexdocs.pm/dream_test), which [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#test-your-code) shows how to add:

### Test the counter and the quota with ten processes <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_counting_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/list
import gleam/option.{Some}
import gleam/result
import snippets/guide_counting_counter_process as counter
import snippets/guide_counting_quota as quota

pub fn tests() -> TestSuite {
  describe("counting from many processes", [
    it("counts every increment from ten processes", fn() {
      // Arrange
      let assert Ok(views) = counter.start("counter_test_ten_processes")
      let finished = process.new_subject()
      let workers = list.repeat(Nil, 10)

      // Act
      list.each(workers, fn(_) {
        process.spawn(fn() {
          let added =
            list.try_each(list.repeat(Nil, 100), fn(_) {
              counter.increment(views, "/")
            })
          process.send(finished, added)
        })
      })
      let assert Ok(_) =
        list.try_map(workers, fn(_) { process.receive_forever(finished) })

      // Assert
      counter.count(views, "/")
      |> should
      |> be_equal(Ok(1000))
      |> or_fail_with("Expected 10 times 100 increments")
    }),
    it("never spends more than the quota from ten processes", fn() {
      // Arrange
      let assert Ok(spent) = helpers.new_counter("quota_test_ten_processes")
      let finished = process.new_subject()
      let workers = list.repeat(Nil, 10)

      // Act: 10 processes try to spend 1 credit 20 times each
      list.each(workers, fn(_) {
        process.spawn(fn() {
          let accepted =
            list.count(list.repeat(Nil, 20), fn(_) {
              result.is_ok(quota.spend(spent, "user:1", 1))
            })
          process.send(finished, accepted)
        })
      })
      let accepted =
        list.fold(workers, 0, fn(total, _) {
          total + process.receive_forever(finished)
        })

      // Assert
      #(accepted, operations.get(spent, "user:1"))
      |> should
      |> be_equal(#(100, Ok(Some(100))))
      |> or_fail_with("Expected exactly 100 credits spent")
    }),
  ])
}
```

Each worker sends back its result, and each test waits for all ten workers before it reads the count. Because `increment` and `spend` return only when their ETS operations are done, every change is in the table when the worker reports back. Thus the expected values are exact: 1000 increments, and 100 accepted credits with a final count of 100.

## Common pitfalls

**Your own read, then write.** *Symptom:* counts or balances are lower or higher than the logs say, with no error. *Fix:* `operations.get` followed by `operations.set` is two ETS operations, and another process can write between them. Use `helpers.increment_by` and check the value that it returns, as in [Step 5](#step-5-spend-a-quota-without-overspending).

**Counting events with `size`.** *Symptom:* a count of events is too low. *Fix:* `operations.size` counts the objects in the table, one per key in a counter table. Store a count under a key, and increment it.

**A counter table in a request handler.** *Symptom:* counts reset to zero, or `Error(TableNotFound)`. *Fix:* the table belongs to the process that created it. Create it at start-up.

**Reading every count on each request.** *Symptom:* requests get slower as the number of keys grows. *Fix:* `operations.to_list` walks the whole table. Read one key with `operations.get`, and build reports less often.

**Counts that must survive a restart.** *Symptom:* every count is zero after a deploy. *Fix:* ETS keeps counts in memory only. Save the table, as [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md) shows, or write the totals to a database now and then.

## Where to go next

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): table owners, errors and tests.
- [Locks and work queues](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/locks-and-queues.md): other operations that ETS does in one step, such as `insert_new` and `take`.
- [Saving a table to disk](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/saving-to-disk.md): keep counts across restarts.
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): access modes and every error.
- [API reference on HexDocs](https://hexdocs.pm/dream_ets/dream_ets/helpers.html): `new_counter`, `increment`, `increment_by`, `decrement` and `decrement_by`.
