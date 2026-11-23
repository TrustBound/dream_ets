# Locks and work queues

Sometimes only one process may do a job: build tonight's report, charge a card, send a welcome email. And sometimes several workers share a pile of jobs, and each job must go to exactly one of them. If two processes check a table and then change it, both can see the same state and both can act. ETS has operations that check and change in one step, so no other process can come between. This guide uses them to build a lock, a work queue and an outbox, and tests that they hold up when processes race.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Take a lock](#step-1-take-a-lock)
- [Step 2: Race five processes for the lock](#step-2-race-five-processes-for-the-lock)
- [Step 3: Share a work queue between workers](#step-3-share-a-work-queue-between-workers)
- [Step 4: Take a batch of messages](#step-4-take-a-batch-of-messages)
- [Which operation to use](#which-operation-to-use)
- [When something goes wrong](#when-something-goes-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you will:

- Take and release a lock on a resource, so only one owner holds it.
- Prove that one of five racing processes gets the lock.
- Build a work queue that three workers empty, with each job claimed once.
- Collect messages for a user, and take them all in one step.
- Handle a lock whose holder crashed, and a key with several values.

## Before you start

Add the package:

```sh
gleam add dream_ets
```

Create your lock and queue tables at start-up, in a process that runs as long as your program, as [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#step-3-keep-the-table-alive) explains. All processes that share a lock or a queue must use the same table. Each example is a complete module.

## Step 1: Take a lock

A lock is a key in a table. The process that stores the key first holds the lock. The value says who holds it.

The obvious way, `member` to check and then `set` to store, is wrong. Two processes can both call `member`, both get `Ok(False)`, and both store the key. `operations.insert_new` does the check and the store in one ETS operation: it stores the key only if it is not there, and tells you which happened.

### Take, release and check a lock <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_lock.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/option.{Some}
import gleam/result

/// Takes the lock on `resource` for `owner`. Returns `Ok(False)` when
/// another owner holds it.
pub fn try_lock(
  locks: Table(String, String),
  resource: String,
  owner: String,
) -> Result(Bool, EtsError) {
  operations.insert_new(locks, resource, owner)
}

/// Releases the lock, but only when `owner` holds it. Returns `Ok(False)`
/// when `owner` does not hold the lock.
pub fn unlock(
  locks: Table(String, String),
  resource: String,
  owner: String,
) -> Result(Bool, EtsError) {
  use holder <- result.try(operations.get(locks, resource))
  case holder == Some(owner) {
    True -> operations.delete(locks, resource) |> result.replace(True)
    False -> Ok(False)
  }
}

pub fn is_locked(
  locks: Table(String, String),
  resource: String,
) -> Result(Bool, EtsError) {
  operations.member(locks, resource)
}
```

With an empty `locks` table:

### What the lock functions return <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_locks_lock.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
try_lock(locks, "report:42", "worker:1")  -> Ok(True)
try_lock(locks, "report:42", "worker:2")  -> Ok(False)
unlock(locks, "report:42", "worker:2")    -> Ok(False)
unlock(locks, "report:42", "worker:1")    -> Ok(True)
is_locked(locks, "report:42")             -> Ok(False)
```

Here is why each function is written this way:

- `try_lock` returns `Ok(False)` when someone else holds the lock. That is not an error: your code decides whether to wait, try later, or skip the job.
- `unlock` only removes the lock of its own owner. A worker that thinks it holds the lock, but does not, cannot release another worker's lock. `get` and then `delete` is safe here, because only the holder ever deletes its own lock.
- `is_locked` uses `operations.member`, which checks the key without reading the value.

## Step 2: Race five processes for the lock

The point of `insert_new` is what happens under a race. This function starts five processes that try to take the same lock at the same moment, and returns the owners that got it:

### Five processes race for one lock <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_race.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_ets/table.{type EtsError}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import snippets/guide_locks_lock.{try_lock}

/// Returns the owners that got the lock.
pub fn five_processes_race() -> Result(List(String), EtsError) {
  use locks <- result.try(helpers.new_string_table("report_locks"))
  let answers = process.new_subject()
  let owners =
    list.map([1, 2, 3, 4, 5], fn(n) { "worker:" <> int.to_string(n) })
  list.each(owners, fn(owner) {
    process.spawn(fn() {
      let locked = try_lock(locks, "report:42", owner)
      process.send(answers, result.map(locked, fn(got) { #(owner, got) }))
    })
  })
  use results <- result.map(
    list.try_map(owners, fn(_) { process.receive_forever(answers) }),
  )
  list.filter_map(results, fn(answer) {
    case answer {
      #(owner, True) -> Ok(owner)
      #(_, False) -> Error(Nil)
    }
  })
}
```

`five_processes_race()` returns a list with exactly one owner, for example `Ok(["worker:3"])`. Which worker wins changes from run to run. That only one wins does not.

## Step 3: Share a work queue between workers

A queue needs two things: an order, and a way for each job to go to one worker only. An `ordered_set` table gives the order: it keeps its keys sorted, and `operations.keys` returns them in ascending order. `operations.take` gives the rest: it reads a key and removes it in one ETS operation, so when two workers take the same job, one gets `Some(job)` and the other gets `None`.

### A work queue in an ordered table <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_queue.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/option.{type Option, None, Some}
import gleam/result

pub fn create_queue(name: String) -> Result(Table(String, String), EtsError) {
  config.new(name)
  // Keys stay sorted, so the oldest job id comes first
  |> config.table_type(config.table_type_ordered_set())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

pub fn add_job(
  queue: Table(String, String),
  job_id: String,
  job: String,
) -> Result(Nil, EtsError) {
  operations.set(queue, job_id, job)
}

/// Removes and returns the first job that no other worker took.
pub fn claim_next(
  queue: Table(String, String),
) -> Result(Option(#(String, String)), EtsError) {
  use job_ids <- result.try(operations.keys(queue))
  claim_first(queue, job_ids)
}

fn claim_first(
  queue: Table(String, String),
  job_ids: List(String),
) -> Result(Option(#(String, String)), EtsError) {
  case job_ids {
    [] -> Ok(None)
    [job_id, ..rest] -> {
      // take reads and removes in one step, so only one worker gets the job
      use taken <- result.try(operations.take(queue, job_id))
      claimed_or_next(queue, job_id, taken, rest)
    }
  }
}

fn claimed_or_next(
  queue: Table(String, String),
  job_id: String,
  taken: Option(String),
  rest: List(String),
) -> Result(Option(#(String, String)), EtsError) {
  case taken {
    Some(job) -> Ok(Some(#(job_id, job)))
    // Another worker took this job first. Try the next one.
    None -> claim_first(queue, rest)
  }
}
```

`claim_next` reads the job ids, then tries to take them in order. If another worker took the first job a moment earlier, `take` returns `None`, and `claim_next` tries the next id. With `job:002` and `job:001` in the queue, `claim_next(queue)` returns `Ok(Some(#("job:001", "send email 1")))`. On an empty queue, it returns `Ok(None)`.

Use job ids that sort in the order you want, such as a zero-padded number or a timestamp. Now let three workers empty a queue of ten jobs at the same time:

### Three workers empty the queue <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_workers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import snippets/guide_locks_queue.{add_job, claim_next, create_queue}

/// Returns every job id that the workers claimed, sorted.
pub fn three_workers_empty_the_queue() -> Result(List(String), EtsError) {
  use queue <- result.try(create_queue("email_jobs"))
  use _ <- result.try(
    list.try_each([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], fn(n) {
      let job_id = "job:" <> string.pad_start(int.to_string(n), 3, "0")
      add_job(queue, job_id, "send email " <> int.to_string(n))
    }),
  )
  let done = process.new_subject()
  let workers = ["worker:1", "worker:2", "worker:3"]
  list.each(workers, fn(_) {
    process.spawn(fn() { process.send(done, claim_all(queue, [])) })
  })
  use claimed <- result.map(
    list.try_map(workers, fn(_) { process.receive_forever(done) }),
  )
  claimed |> list.flatten |> list.sort(string.compare)
}

/// Claims jobs until the queue is empty. Returns the claimed job ids.
fn claim_all(
  queue: Table(String, String),
  claimed: List(String),
) -> Result(List(String), EtsError) {
  use next <- result.try(claim_next(queue))
  case next {
    Some(#(job_id, _job)) -> claim_all(queue, [job_id, ..claimed])
    None -> Ok(claimed)
  }
}
```

`three_workers_empty_the_queue()` returns every job id exactly once:

### What the three workers claim <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/outputs/guide_locks_workers.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Ok(["job:001", "job:002", "job:003", "job:004", "job:005", "job:006", "job:007", "job:008", "job:009", "job:010"])
```

Which worker got which job changes from run to run, but no job is missing and no job comes twice.

`claim_next` reads all the ids on each call, so it costs more as the queue grows. It suits a queue of hundreds or a few thousand jobs. For a queue that holds millions, use a real message queue.

## Step 4: Take a batch of messages

Sometimes you collect many values under one key and handle them together: the notifications for a user, sent as one digest email. A `set` table keeps one value per key, so a second `set` replaces the first. A `bag` or `duplicate_bag` table keeps them all:

### An outbox that collects messages per user <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_outbox.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/result

pub fn create_outbox(name: String) -> Result(Table(String, String), EtsError) {
  config.new(name)
  // One key can hold many values, also identical ones
  |> config.table_type(config.table_type_duplicate_bag())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

/// Adds a message. In a bag table, `set` adds a value. It does not
/// replace the values that are there.
pub fn queue_message(
  outbox: Table(String, String),
  user_id: String,
  message: String,
) -> Result(Nil, EtsError) {
  operations.set(outbox, user_id, message)
}

/// Removes and returns every waiting message of the user, in one step.
pub fn take_messages(
  outbox: Table(String, String),
  user_id: String,
) -> Result(List(String), EtsError) {
  operations.take_all(outbox, user_id)
}

pub fn three_messages_for_ada() -> Result(List(String), EtsError) {
  use outbox <- result.try(create_outbox("user_outbox"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Welcome"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Your invoice"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Your invoice"))
  take_messages(outbox, "user:ada")
}
```

`three_messages_for_ada()` returns `Ok(["Welcome", "Your invoice", "Your invoice"])`.

A few things are different in a bag table:

- `operations.set` adds a value. It does not replace the values that are there.
- A `duplicate_bag` keeps identical values, which is why "Your invoice" is there two times. A `bag` keeps each identical value one time.
- `operations.take_all` reads and removes every value of the key in one ETS operation, so a message queued by another process goes into this batch or the next one, never into both or neither.
- `operations.get_all` reads every value of a key and leaves them in the table.

## Which operation to use

| Your situation | Use | Why |
|:---|:---|:---|
| Store a key only if nobody else has, such as a lock or a unique username | `operations.insert_new` | Checks and stores in one step. Returns `Ok(False)` when the key is there. |
| Read a value and remove it, so nobody else gets it | `operations.take` | Reads and removes in one step. Returns `Ok(None)` when the key is gone. |
| Read and remove every value of a key in a bag table | `operations.take_all` | Reads and removes every value in one step. |
| Read every value of a key in a bag table | `operations.get_all` | `get` refuses a key with more than one value. |
| Check a key, then change it | Not `member` and then `set` | Another process can change the table between the two calls. |

## When something goes wrong

**The holder of a lock crashes.** The lock stays. ETS does not know which process a key belongs to. When a process takes `report:42` and then stops without `unlock`, `is_locked(locks, "report:42")` still returns `Ok(True)`, and every other worker gets `Ok(False)` forever. Release the lock on every path of your code. If the holder can crash in the middle, store an expiry time with the lock, and let a new owner take a lock whose time is past, as the cache entries of [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md#step-2-expire-old-entries) do.

**The owner of the table stops.** Then every lock and every job is gone, and each operation returns `Error(TableNotFound)`. Keep the table in a process that runs as long as your program.

**`get` or `take` on a key with several values.** In a bag table, these refuse instead of picking one value. With two messages for `user:ada`, `operations.get(outbox, "user:ada")` returns `Error(OperationFailed("the key has 2 values, use get_all"))`, and `take` returns the same error with `take_all` and leaves the values in the table. Use `get_all` and `take_all` on bag tables.

**`size` to count the messages of one user.** `operations.size` counts every message in the table, for all users. With two messages for `user:ada` and none for other users, `size(outbox)` returns `Ok(2)`. When a second user has a message, it returns `Ok(3)`. To count the messages of one user, use `list.length` on the result of `get_all`.

## Test your code

Test your lock and queue code in two ways: the single-process rules with plain calls, and the race with real processes, as Step 2 and Step 3 do. Here is a test module for `unlock`. It uses [dream_test](https://hexdocs.pm/dream_test), which [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md#test-your-code) shows how to add:

### Test that unlock only releases its own lock <a href="https://github.com/TrustBound/dream_ets/blob/3.0.0/test/snippets/guide_locks_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_ets/helpers
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_locks_lock.{is_locked, try_lock, unlock}

pub fn tests() -> TestSuite {
  describe("unlock", [
    it("keeps a lock that another owner holds", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("unlock_test_other")
      let assert Ok(True) = try_lock(locks, "report:42", "worker:1")

      // Act
      let assert Ok(False) = unlock(locks, "report:42", "worker:2")

      // Assert
      is_locked(locks, "report:42")
      |> should
      |> be_equal(Ok(True))
      |> or_fail_with("The lock of worker:1 should stay")
    }),
    it("releases the lock of its owner", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("unlock_test_owner")
      let assert Ok(True) = try_lock(locks, "report:42", "worker:1")

      // Act
      let assert Ok(True) = unlock(locks, "report:42", "worker:1")

      // Assert
      is_locked(locks, "report:42")
      |> should
      |> be_equal(Ok(False))
      |> or_fail_with("The lock should be free")
    }),
  ])
}
```

For a race test, assert what must be true in every run, not what happened in one. "Exactly one owner" and "each job once" hold in every run. "worker:3 wins" does not.

## Common pitfalls

**Check, then act.** *Symptom:* two workers do the same job now and then, mostly under load. *Fix:* `member` then `set`, or `get` then `delete`, lets another process act between the two calls. Use `insert_new` to claim and `take` to remove.

**A lock that never goes away.** *Symptom:* a job stops running after a crash, and its lock is still in the table. *Fix:* release in every path, and add an expiry time if the holder can crash.

**Locks across nodes.** *Symptom:* two nodes of a cluster both run the job. *Fix:* an ETS table belongs to one Erlang node. These locks keep processes on one node apart, not nodes. Use a lock that all nodes share, such as one in your database.

**`set` in a bag table.** *Symptom:* a key collects old values instead of holding the latest one. *Fix:* in a bag table, `set` adds a value. Use a `set` table for one value per key.

**A queue that grows without limit.** *Symptom:* `claim_next` gets slower over time. *Fix:* it reads every job id on each call. Keep the queue short, or move large queues out of ETS.

## Where to go next

- [Getting started](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/getting-started.md): table owners, errors and tests.
- [Counting events](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/counting.md): exact counts from many processes with `helpers.increment`, and a quota that cannot be overspent.
- [Caching data in memory](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/caching.md): store your own types, with expiry times.
- [Settings and errors reference](https://github.com/TrustBound/dream_ets/blob/main/docs/guides/settings-and-errors.md): table types and every error.
- [API reference on HexDocs](https://hexdocs.pm/dream_ets/dream_ets/operations.html): `insert_new`, `take`, `take_all`, `get_all` and `member`.
