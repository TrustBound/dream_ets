//// Guide: Getting started, step 2
////
//// Three processes write to one table at the same time. The process that
//// started them reads every key afterwards.

import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string

pub fn write_from_three_processes(
  names: Table(String, String),
) -> Result(List(String), EtsError) {
  let finished = process.new_subject()
  let users = ["ada", "grace", "linus"]
  list.each(users, fn(user) {
    process.spawn(fn() {
      // The Table value works in any process. It is only a reference.
      process.send(finished, operations.set(names, "user:" <> user, user))
    })
  })
  // Wait for one result from each process
  use _ <- result.try(
    list.try_map(users, fn(_) { process.receive_forever(finished) }),
  )
  use keys <- result.map(operations.keys(names))
  list.sort(keys, string.compare)
}
