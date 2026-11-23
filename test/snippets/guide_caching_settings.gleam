//// Guide: Caching data in memory, step 5
////
//// A profile cache for a server where many processes read at the same time.

import dream_ets/config
import dream_ets/table.{type EtsError, type Table}
import snippets/guide_caching_entry.{type Entry, encode_entry, entry_decoder}

pub fn create_busy_profile_cache(
  name: String,
) -> Result(Table(String, Entry), EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  // Many request processes read at the same time
  |> config.read_concurrency(True)
  // Any process can write, so every request handler can fill the cache
  |> config.access(config.access_public())
  |> config.create()
}
