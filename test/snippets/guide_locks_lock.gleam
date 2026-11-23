//// Guide: Locks and work queues, step 1
////
//// A lock that only one owner can hold at a time.

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
