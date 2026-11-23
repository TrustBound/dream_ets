//// Guide: Getting started, testing
////
//// Tests `greet` from step 3 with tables made for each test.

import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_getting_started_tables.{Tables, greet}

pub fn tests() -> TestSuite {
  describe("greet", [
    it("greets a known user by name", fn() {
      // Arrange
      // Each test gets tables with names of its own
      let assert Ok(names) =
        config.new("greet_test_known_names")
        |> config.key_string()
        |> config.value_string()
        |> config.create()
      let assert Ok(page_views) = helpers.new_counter("greet_test_known_views")
      let assert Ok(Nil) = operations.set(names, "user:1", "Alice")
      let tables = Tables(names: names, page_views: page_views)

      // Act
      let greeting = greet(tables, "user:1")

      // Assert
      greeting
      |> should
      |> be_equal(Ok("Hello, Alice. Views of this page: 1"))
      |> or_fail_with("Expected a greeting for Alice")
    }),
    it("greets an unknown user as a stranger", fn() {
      // Arrange
      let assert Ok(names) =
        helpers.new_string_table("greet_test_unknown_names")
      let assert Ok(page_views) =
        helpers.new_counter("greet_test_unknown_views")
      let tables = Tables(names: names, page_views: page_views)

      // Act
      let greeting = greet(tables, "user:2")

      // Assert
      greeting
      |> should
      |> be_equal(Ok("Hello, stranger. Views of this page: 1"))
      |> or_fail_with("Expected a greeting for a stranger")
    }),
  ])
}
