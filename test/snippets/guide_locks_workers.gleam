//// Guide: Locks and work queues, step 3
////
//// Three workers empty a queue of ten jobs at the same time.

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
