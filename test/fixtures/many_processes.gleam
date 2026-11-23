//// Runs one function in many processes at the same time, for the tests of
//// operations that many processes use on one key.

import gleam/erlang/process
import gleam/list

/// Starts `count` processes. Process `index` (0 to `count - 1`) runs
/// `work(index)` and sends its result back. Waits for the result of each
/// process. Returns `Ok(Nil)` when each `work` returned `Ok`, the first
/// error of a `work` as `Error("work failed")`, and `Error("timeout")` when
/// a process sends no result within ten seconds.
pub fn run_each(
  count: Int,
  work: fn(Int) -> Result(a, e),
) -> Result(Nil, String) {
  let finished = process.new_subject()
  let indexes = indexes_below(count, [])
  list.each(indexes, fn(index) {
    process.spawn_unlinked(fn() { process.send(finished, work(index)) })
  })
  list.try_each(indexes, fn(_) { wait_for(finished) })
}

/// Runs `step` `times` times in the calling process, and stops at the first
/// error.
pub fn repeat(times: Int, step: fn() -> Result(a, e)) -> Result(Nil, e) {
  list.try_each(list.repeat(Nil, times), fn(_) { step() })
}

fn wait_for(finished: process.Subject(Result(a, e))) -> Result(Nil, String) {
  case process.receive(finished, 10_000) {
    Ok(Ok(_)) -> Ok(Nil)
    Ok(Error(_)) -> Error("work failed")
    Error(Nil) -> Error("timeout")
  }
}

fn indexes_below(count: Int, collected: List(Int)) -> List(Int) {
  case count <= 0 {
    True -> collected
    False -> indexes_below(count - 1, [count - 1, ..collected])
  }
}
