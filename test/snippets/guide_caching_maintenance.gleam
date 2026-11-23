//// Guide: Caching data in memory, step 4
////
//// Removes one entry when its source changes, counts and lists the
//// entries, and clears the whole cache.

import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/list
import gleam/result
import gleam/string
import snippets/guide_caching_entry.{type Entry, type Profile}

/// Call this when a profile changes in the slow source.
pub fn forget(
  cache: Table(String, Entry),
  user_id: String,
) -> Result(Nil, EtsError) {
  operations.delete(cache, user_id)
}

/// The user ids in the cache, sorted. Reads the whole table.
pub fn cached_user_ids(
  cache: Table(String, Entry),
) -> Result(List(String), EtsError) {
  use user_ids <- result.map(operations.keys(cache))
  list.sort(user_ids, string.compare)
}

/// The profiles in the cache, stale ones too. Reads the whole table.
pub fn cached_profiles(
  cache: Table(String, Entry),
) -> Result(List(Profile), EtsError) {
  use entries <- result.map(operations.values(cache))
  list.map(entries, fn(entry) { entry.profile })
}

pub fn entry_count(cache: Table(String, Entry)) -> Result(Int, EtsError) {
  operations.size(cache)
}

/// Removes every entry and keeps the table.
pub fn clear(cache: Table(String, Entry)) -> Result(Nil, EtsError) {
  operations.delete_all_objects(cache)
}
