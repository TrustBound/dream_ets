//// Guide: Caching data in memory, testing
////
//// Tests `lookup` from step 2 and `get_profile` from step 3 with fixed
//// times and a stub loader.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guide_caching_entry.{type Profile, Profile, create_profile_cache}
import snippets/guide_caching_lookup.{lookup, remember}
import snippets/guide_caching_read_through.{get_profile}

fn database_down(_user_id: String) -> Result(Profile, String) {
  Error("database is down")
}

pub fn tests() -> TestSuite {
  let ada = Profile(name: "Ada", plan: "pro")
  describe("profile cache", [
    it("misses an entry after its time to live", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("cache_test_expired")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let found = lookup(cache, "user:1", 1300)

      // Assert
      found
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("Expected a miss at 1300")
    }),
    it("serves a fresh entry when the source is down", fn() {
      // Arrange
      let assert Ok(cache) = create_profile_cache("cache_test_source_down")
      let assert Ok(Nil) = remember(cache, "user:1", ada, 1000)

      // Act
      let profile = get_profile(cache, "user:1", 1100, database_down)

      // Assert
      profile
      |> should
      |> be_equal(Ok(ada))
      |> or_fail_with("Expected the cached profile")
    }),
  ])
}
