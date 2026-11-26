//// Tests of the snippets that the docs show and that no other test module
//// runs. Each test checks the exact result of one snippet.

import dream_errors.{NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/custom_types
import snippets/doc_insert_new_race
import snippets/doc_member
import snippets/doc_to_error.{find_name_in_deleted_table}

pub fn tests() -> TestSuite {
  describe("snippets", [
    it("custom types returns the stored user", fn() {
      // Act
      let result = custom_types.store_custom_type()

      // Assert
      result
      |> should
      |> be_equal(Ok("Alice <alice@example.com>"))
      |> or_fail_with("Should return the stored user")
    }),
    it("member doc describes each member result", fn() {
      // Act
      let result = doc_member.describe_users_before_and_after_delete()

      // Assert
      result
      |> should
      |> be_equal(
        Ok([
          "user:123 exists",
          "user:456 does not exist",
          "The table was deleted",
        ]),
      )
      |> or_fail_with("Should describe each member result")
    }),
    it("insert_new doc inserts once each way", fn() {
      // Act
      let result = doc_insert_new_race.insert_twice_each_way()

      // Assert
      result
      |> should
      |> be_equal(Ok([True, False, True, False]))
      |> or_fail_with("Should insert only the first time")
    }),
    it("to_error doc maps a lookup on a deleted table to NotFound", fn() {
      // Act
      let result = find_name_in_deleted_table()

      // Assert
      result
      |> should
      |> be_equal(
        Error(NotFound("the ETS table does not exist, or it was deleted")),
      )
      |> or_fail_with("Should map the lookup error to NotFound")
    }),
  ])
}
