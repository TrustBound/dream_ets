//// Guide: Counting events, step 3
////
//// Ten processes increment one key 1000 times each, at the same time.

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
