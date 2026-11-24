//// Guide: Locks and work queues, step 2
////
//// Five processes try to take the same lock at the same time.

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
