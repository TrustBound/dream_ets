//// Tests for the snippets of the caching guide
//// (docs/guides/caching.md). Each test runs a snippet and asserts the
//// exact value that the guide shows. The output that the guide shows is
//// compared with the files in test/outputs.

import dream_ets/encoders
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/output_file
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import snippets/guide_caching_entry.{Profile, create_profile_cache}
import snippets/guide_caching_lookup.{lookup, remember}
import snippets/guide_caching_maintenance
import snippets/guide_caching_read_through.{get_profile}
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
    it("step 2: lookup gives the output that the guide shows", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_lookup")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let fresh = lookup(cache, "user:1", 1200)
      let stale = lookup(cache, "user:1", 1300)

      // Assert
      output_file.calls([
        #("lookup(cache, \"user:1\", 1200)", string.inspect(fresh)),
        #("lookup(cache, \"user:1\", 1300)", string.inspect(stale)),
      ])
      |> should
      |> be_equal(output_file.read("guide_caching_lookup"))
      |> or_fail_with("Expected the output of guide_caching_lookup.txt")
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
      output_file.value(found)
      |> should
      |> be_equal(output_file.read("guide_caching_decode_error"))
      |> or_fail_with("Expected the output of guide_caching_decode_error.txt")
    }),
    it("step 3: get_profile gives the output that the guide shows", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("guide_cache_read_through")
      let assert Ok(empty) = create_profile_cache("guide_cache_read_empty")

      // Act
      let loaded = get_profile(cache, "user:1", 1000, load_ada)
      let cached = get_profile(cache, "user:1", 1100, database_down)
      let failed = get_profile(empty, "user:1", 1000, database_down)

      // Assert
      output_file.calls([
        #(
          "get_profile(cache, \"user:1\", 1000, load_ada)",
          string.inspect(loaded),
        ),
        #(
          "get_profile(cache, \"user:1\", 1100, database_down)",
          string.inspect(cached),
        ),
        #(
          "get_profile(empty, \"user:1\", 1000, database_down)",
          string.inspect(failed),
        ),
      ])
      |> should
      |> be_equal(output_file.read("guide_caching_read_through"))
      |> or_fail_with("Expected the output of guide_caching_read_through.txt")
    }),
    it(
      "step 4: the maintenance functions give the output that the guide shows",
      fn() {
        // Arrange
        let cache = two_profiles("guide_cache_maintenance")

        // Act
        let user_ids = guide_caching_maintenance.cached_user_ids(cache)
        let two_entries = guide_caching_maintenance.entry_count(cache)
        let assert Ok(Nil) = guide_caching_maintenance.forget(cache, "user:1")
        let one_entry = guide_caching_maintenance.entry_count(cache)
        let assert Ok(Nil) = guide_caching_maintenance.clear(cache)
        let no_entries = guide_caching_maintenance.entry_count(cache)

        // Assert
        output_file.calls([
          #("cached_user_ids(cache)", string.inspect(user_ids)),
          #("entry_count(cache)", string.inspect(two_entries)),
          #(
            "forget(cache, \"user:1\") then entry_count(cache)",
            string.inspect(one_entry),
          ),
          #("clear(cache) then entry_count(cache)", string.inspect(no_entries)),
        ])
        |> should
        |> be_equal(output_file.read("guide_caching_maintenance"))
        |> or_fail_with("Expected the output of guide_caching_maintenance.txt")
      },
    ),
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
