//// Guide: Caching data in memory, step 1
////
//// A cache table for user profiles. Each entry is stored as an Erlang
//// tuple, with the time at which it becomes stale.

import dream_ets/config
import dream_ets/table.{type EtsError, type Table}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}

pub type Profile {
  Profile(name: String, plan: String)
}

/// A cached profile, and the time in seconds at which it becomes stale.
pub type Entry {
  Entry(profile: Profile, expires_at: Int)
}

pub fn create_profile_cache(
  name: String,
) -> Result(Table(String, Entry), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  |> config.create()
}

/// Stores an entry as the tuple {Name, Plan, ExpiresAt}.
pub fn encode_entry(entry: Entry) -> Dynamic {
  dynamic.array([
    dynamic.string(entry.profile.name),
    dynamic.string(entry.profile.plan),
    dynamic.int(entry.expires_at),
  ])
}

pub fn entry_decoder() -> Decoder(Entry) {
  use name <- decode.field(0, decode.string)
  use plan <- decode.field(1, decode.string)
  use expires_at <- decode.field(2, decode.int)
  decode.success(Entry(Profile(name: name, plan: plan), expires_at: expires_at))
}
