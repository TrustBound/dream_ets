//// Runs a function in a second process, for the tests that use a table
//// from a process that does not own it.

import gleam/erlang/process

/// Runs `work` in a new process and returns its result. Returns
/// `Error("timeout")` when the process sends no result within one second.
pub fn run(work: fn() -> a) -> Result(a, String) {
  let reply_to = process.new_subject()
  process.spawn_unlinked(fn() { process.send(reply_to, work()) })
  process.receive(reply_to, 1000)
  |> map_timeout
}

fn map_timeout(received: Result(a, Nil)) -> Result(a, String) {
  case received {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error("timeout")
  }
}
