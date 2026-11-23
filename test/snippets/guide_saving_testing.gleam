//// Guide: Saving a table to disk, testing
////
//// Tests `load_or_create_settings` from step 2 with files under `build/`.

import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_saving_load.{load_or_create_settings}

pub fn tests() -> TestSuite {
  describe("load_or_create_settings", [
    it("starts with an empty table when the file does not exist", fn() {
      // Arrange
      let path = "build/no_settings_file.ets"

      // Act
      let assert Ok(settings) =
        load_or_create_settings("settings_test_missing", path)

      // Assert
      operations.size(settings)
      |> should
      |> be_equal(Ok(0))
      |> or_fail_with("Expected an empty table")
    }),
  ])
}
