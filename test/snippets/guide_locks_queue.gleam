//// Guide: Locks and work queues, step 3
////
//// A work queue in an ordered_set table. Each job is claimed by one worker
//// only, even when workers claim at the same time.

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
