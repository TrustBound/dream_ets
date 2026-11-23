//// Guide: Caching data in memory, step 3
////
//// Reads a profile from the cache, and loads it from the slow source on a
//// miss.

import dream_ets/table.{type EtsError, type Table}
import gleam/option.{None, Some}
import gleam/result
import snippets/guide_caching_entry.{type Entry, type Profile}
import snippets/guide_caching_lookup.{lookup, remember}

pub type CacheError {
  /// The cache table refused the operation.
  CacheFailed(EtsError)
  /// The slow source could not load the profile.
  LoadFailed(String)
}

pub fn get_profile(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
  load: fn(String) -> Result(Profile, String),
) -> Result(Profile, CacheError) {
  use cached <- result.try(
    lookup(cache, user_id, now) |> result.map_error(CacheFailed),
  )
  case cached {
    Some(profile) -> Ok(profile)
    None -> load_and_remember(cache, user_id, now, load)
  }
}

fn load_and_remember(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
  load: fn(String) -> Result(Profile, String),
) -> Result(Profile, CacheError) {
  use profile <- result.try(load(user_id) |> result.map_error(LoadFailed))
  remember(cache, user_id, profile, now)
  |> result.replace(profile)
  |> result.map_error(CacheFailed)
}
