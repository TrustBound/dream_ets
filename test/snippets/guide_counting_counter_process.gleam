//// Guide: Counting events, step 4
////
//// One process owns the counter table and does every write. Any process
//// can read the counts.

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
