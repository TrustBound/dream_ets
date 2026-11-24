//// Guide: Caching data in memory, step 2
////
//// Stores a profile for a number of seconds, and reads it back only while
//// it is fresh.

import dream_ets/operations
import dream_ets/table.{type EtsError, type Table, DecodeError}
import gleam/option.{type Option, None, Some}
import gleam/result
import snippets/guide_caching_entry.{type Entry, type Profile, Entry}

const time_to_live_seconds = 300

pub fn remember(
  cache: Table(String, Entry),
  user_id: String,
  profile: Profile,
  now: Int,
) -> Result(Nil, EtsError) {
  let entry = Entry(profile: profile, expires_at: now + time_to_live_seconds)
  operations.set(cache, user_id, entry)
}

/// Returns the profile while it is fresh. A stale entry, or an entry that
/// does not decode, is removed and counts as a miss.
pub fn lookup(
  cache: Table(String, Entry),
  user_id: String,
  now: Int,
) -> Result(Option(Profile), EtsError) {
  case operations.get(cache, user_id) {
    Ok(Some(entry)) if entry.expires_at > now -> Ok(Some(entry.profile))
    Ok(Some(_stale)) | Error(DecodeError(_)) ->
      operations.delete(cache, user_id) |> result.replace(None)
    Ok(None) -> Ok(None)
    Error(error) -> Error(error)
  }
}
