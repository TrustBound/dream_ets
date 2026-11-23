//// Tests for the snippets of the caching guide
//// (docs/guides/caching.md). Each test runs a snippet and asserts the
//// exact value that the guide shows.

import dream_ets/encoders
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import snippets/guide_caching_entry.{Profile, create_profile_cache}
import snippets/guide_caching_lookup.{lookup, remember}
import snippets/guide_caching_maintenance
import snippets/guide_caching_read_through.{LoadFailed, get_profile}
import snippets/guide_caching_settings

const ada = Profile(name: "Ada", plan: "pro")

fn load_ada(_user_id: String) -> Result(guide_caching_entry.Profile, String) {
  Ok(ada)
}

fn database_down(
  _user_id: String,
) -> Result(guide_caching_entry.Profile, String) {
  Error("database is down")
}

pub fn tests() -> TestSuite {
  describe("caching guide", [
    it("step 2: lookup returns a fresh profile", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_fresh")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let found = lookup(cache, "user:1", 1200)

      // Assert
      found
      |> should
      |> be_equal(Ok(Some(ada)))
      |> or_fail_with("Expected the profile before 1300")
    }),
    it("step 2: lookup misses a stale profile", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_stale")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let found = lookup(cache, "user:1", 1300)

      // Assert
      found
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("Expected a miss at 1300")
    }),
    it("step 2: lookup removes a stale profile", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_stale_removed")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)
      let assert Ok(None) = lookup(cache, "user:1", 1300)

      // Act
      let still_there = operations.member(cache, "user:1")

      // Assert
      still_there
      |> should
      |> be_equal(Ok(False))
      |> or_fail_with("Expected the stale entry to be gone")
    }),
    it("step 2: lookup misses an entry that does not decode", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_old_format")
      // An older version of the program stored a plain String
      let old_view =
        table.new_table(
          table.table_ref(cache),
          "guide_cache_old_format",
          encoders.string_encoder,
          encoders.string_decoder(),
          encoders.string_encoder,
          encoders.string_decoder(),
        )
      let assert Ok(Nil) = operations.set(old_view, "user:1", "Ada")

      // Act
      let found = lookup(cache, "user:1", 1000)

      // Assert
      found
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("Expected a miss for the old format")
    }),
    it("step 2: get returns DecodeError for an entry in an old format", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_decode_error")
      let old_view =
        table.new_table(
          table.table_ref(cache),
          "guide_cache_decode_error",
          encoders.string_encoder,
          encoders.string_decoder(),
          encoders.string_encoder,
          encoders.string_decoder(),
        )
      let assert Ok(Nil) = operations.set(old_view, "user:1", "Ada")

      // Act
      let found = operations.get(cache, "user:1")

      // Assert
      found
      |> should
      |> be_equal(
        Error(table.DecodeError(decode.DecodeError("Indexable", "String", []))),
      )
      |> or_fail_with("Expected a DecodeError")
    }),
    it("step 3: get_profile loads a profile on a miss", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_load")

      // Act
      let profile = get_profile(cache, "user:1", 1000, load_ada)

      // Assert
      profile
      |> should
      |> be_equal(Ok(ada))
      |> or_fail_with("Expected the loaded profile")
    }),
    it("step 3: get_profile serves a hit without the slow source", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_hit")
      let assert Ok(_) = get_profile(cache, "user:1", 1000, load_ada)

      // Act
      let profile = get_profile(cache, "user:1", 1100, database_down)

      // Assert
      profile
      |> should
      |> be_equal(Ok(ada))
      |> or_fail_with("Expected the cached profile")
    }),
    it("step 3: get_profile reports a failed load", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_load_failed")

      // Act
      let profile = get_profile(cache, "user:1", 1000, database_down)

      // Assert
      profile
      |> should
      |> be_equal(Error(LoadFailed("database is down")))
      |> or_fail_with("Expected LoadFailed")
    }),
    it("step 4: cached_user_ids lists the keys in order", fn() {
      // Arrange
      let cache = two_profiles("guide_cache_ids")

      // Act
      let user_ids = guide_caching_maintenance.cached_user_ids(cache)

      // Assert
      user_ids
      |> should
      |> be_equal(Ok(["user:1", "user:2"]))
      |> or_fail_with("Expected both user ids")
    }),
    it("step 4: cached_profiles lists the profiles", fn() {
      // Arrange
      let cache = two_profiles("guide_cache_profiles")

      // Act
      let assert Ok(profiles) = guide_caching_maintenance.cached_profiles(cache)

      // Assert
      list.sort(profiles, fn(left, right) {
        string.compare(left.name, right.name)
      })
      |> should
      |> be_equal([ada, Profile(name: "Grace", plan: "free")])
      |> or_fail_with("Expected both profiles")
    }),
    it("step 4: entry_count counts the entries", fn() {
      // Arrange
      let cache = two_profiles("guide_cache_count")

      // Act
      let count = guide_caching_maintenance.entry_count(cache)

      // Assert
      count
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("Expected two entries")
    }),
    it("step 4: forget removes one entry", fn() {
      // Arrange
      let cache = two_profiles("guide_cache_forget")
      let assert Ok(Nil) = guide_caching_maintenance.forget(cache, "user:1")

      // Act
      let count = guide_caching_maintenance.entry_count(cache)

      // Assert
      count
      |> should
      |> be_equal(Ok(1))
      |> or_fail_with("Expected one entry")
    }),
    it("step 4: clear removes every entry", fn() {
      // Arrange
      let cache = two_profiles("guide_cache_clear")
      let assert Ok(Nil) = guide_caching_maintenance.clear(cache)

      // Act
      let count = guide_caching_maintenance.entry_count(cache)

      // Assert
      count
      |> should
      |> be_equal(Ok(0))
      |> or_fail_with("Expected an empty cache")
    }),
    it("step 5: the busy cache stores and reads profiles", fn() {
      // Arrange
      let assert Ok(cache) =
        guide_caching_settings.create_busy_profile_cache("guide_cache_busy")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let found = lookup(cache, "user:1", 1000)

      // Assert
      found
      |> should
      |> be_equal(Ok(Some(ada)))
      |> or_fail_with("Expected the profile")
    }),
  ])
}

fn two_profiles(
  name: String,
) -> table.Table(String, guide_caching_entry.Entry) {
  let assert Ok(cache) = create_profile_cache(name)
  let assert Ok(Nil) = remember(cache, "user:2", Profile("Grace", "free"), 1000)
  let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)
  cache
}
