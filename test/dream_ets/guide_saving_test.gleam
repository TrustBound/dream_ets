//// Tests for the snippets of the saving guide
//// (docs/guides/saving-to-disk.md). Each test runs a snippet and asserts
//// the exact value that the guide shows.

import dream_ets/config
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/ets_info.{table_info}
import fixtures/other_process
import gleam/option.{Some}
import snippets/guide_saving_load
import snippets/guide_saving_restart
import snippets/guide_saving_save

pub fn tests() -> TestSuite {
  describe("saving guide", [
    it("step 1: save_settings writes the file", fn() {
      // Act
      let saved =
        guide_saving_save.save_settings(
          "guide_saving_step_1",
          "build/guide_saving_step_1.ets",
        )

      // Assert
      saved
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("Expected the file to be written")
    }),
    it("step 1: a loaded table keeps the settings it was saved with", fn() {
      // Arrange
      let name = "guide_saving_keeps_access"
      let path = "build/guide_saving_keeps_access.ets"
      let assert Ok(Ok(Nil)) =
        other_process.run(fn() {
          let assert Ok(settings) =
            config.new(name)
            |> config.access(config.access_protected())
            |> config.key_string()
            |> config.value_string()
            |> config.create()
          operations.save_to_file(settings, path)
        })
      let assert Ok(settings) = guide_saving_load.load_settings(name, path)

      // Act
      let access = table_info(settings, "protection")

      // Assert
      access
      |> should
      |> be_equal("protected")
      |> or_fail_with("Expected the saved access mode")
    }),
    it("step 1: a second save replaces the file", fn() {
      // Arrange
      let name = "guide_saving_replace"
      let path = "build/guide_saving_replace.ets"
      let assert Ok(Ok(Nil)) =
        other_process.run(fn() {
          let assert Ok(settings) = helpers.new_string_table(name)
          let assert Ok(Nil) = operations.set(settings, "theme", "dark")
          let assert Ok(Nil) = operations.save_to_file(settings, path)
          let assert Ok(Nil) = operations.set(settings, "theme", "light")
          operations.save_to_file(settings, path)
        })
      let assert Ok(settings) = guide_saving_load.load_settings(name, path)

      // Act
      let theme = operations.get(settings, "theme")

      // Assert
      theme
      |> should
      |> be_equal(Ok(Some("light")))
      |> or_fail_with("Expected the value of the second save")
    }),
    it("step 2: the name argument only labels the loaded table", fn() {
      // Arrange
      let path = "build/guide_saving_label.ets"
      let assert Ok(Ok(Nil)) =
        other_process.run(fn() {
          guide_saving_save.save_settings("guide_saving_label", path)
        })
      let assert Ok(settings) =
        guide_saving_load.load_settings("another_label", path)

      // Act
      let theme = operations.get(settings, "theme")

      // Assert
      theme
      |> should
      |> be_equal(Ok(Some("dark")))
      |> or_fail_with("Expected the table of the file name to answer")
    }),
    it("step 2: load_settings reads a saved value", fn() {
      // Arrange
      let path = "build/guide_saving_step_2.ets"
      // The table of the other process goes away when that process stops
      let assert Ok(Ok(Nil)) =
        other_process.run(fn() {
          guide_saving_save.save_settings("guide_saving_step_2", path)
        })
      let assert Ok(settings) =
        guide_saving_load.load_settings("guide_saving_step_2", path)

      // Act
      let theme = operations.get(settings, "theme")

      // Assert
      theme
      |> should
      |> be_equal(Ok(Some("dark")))
      |> or_fail_with("Expected the saved theme")
    }),
    it("step 2: load_settings refuses a table that exists", fn() {
      // Arrange
      let name = "guide_saving_exists"
      let path = "build/guide_saving_exists.ets"
      let assert Ok(Nil) = guide_saving_save.save_settings(name, path)

      // Act
      let loaded = guide_saving_load.load_settings(name, path)

      // Assert
      loaded
      |> should
      |> be_equal(Error(table.OperationFailed("cannot_create_table")))
      |> or_fail_with("Expected cannot_create_table")
    }),
    it("step 2: load_settings reports a missing file", fn() {
      // Act
      let loaded =
        guide_saving_load.load_settings(
          "guide_saving_missing",
          "build/no_such_settings.ets",
        )

      // Assert
      loaded
      |> should
      |> be_equal(
        Error(table.OperationFailed(
          "{read_error,{file_error,\"build/no_such_settings.ets\",enoent}}",
        )),
      )
      |> or_fail_with("Expected the enoent error")
    }),
    it("step 3: a value survives a restart", fn() {
      // Act
      let theme =
        guide_saving_restart.survive_a_restart("build/guide_saving_restart.ets")

      // Assert
      theme
      |> should
      |> be_equal(Ok(Some("dark")))
      |> or_fail_with("Expected the theme after the restart")
    }),
    it("failures: save_to_file reports a missing directory", fn() {
      // Act
      let saved = guide_saving_restart.save_to_missing_directory()

      // Assert
      saved
      |> should
      |> be_equal(
        Error(table.OperationFailed(
          "{file_error,\"/no/such/directory/settings.ets\",enoent}",
        )),
      )
      |> or_fail_with("Expected the enoent error")
    }),
    it(
      "failures: a loaded table goes away with the process that loaded it",
      fn() {
        // Arrange
        let name = "guide_saving_loader_owner"
        let path = "build/guide_saving_loader_owner.ets"
        let assert Ok(Ok(Nil)) =
          other_process.run(fn() { guide_saving_save.save_settings(name, path) })
        let assert Ok(Ok(settings)) =
          other_process.run(fn() { guide_saving_load.load_settings(name, path) })

        // Act
        let theme = operations.get(settings, "theme")

        // Assert
        theme
        |> should
        |> be_equal(Error(table.TableNotFound))
        |> or_fail_with("Expected TableNotFound")
      },
    ),
    it("failures: the types come from your code, not the file", fn() {
      // Arrange
      let name = "guide_saving_wrong_types"
      let path = "build/guide_saving_wrong_types.ets"
      let assert Ok(Ok(Nil)) =
        other_process.run(fn() {
          let assert Ok(counts) = helpers.new_counter(name)
          let assert Ok(_) = helpers.increment(counts, "theme")
          operations.save_to_file(counts, path)
        })
      let assert Ok(settings) = guide_saving_load.load_settings(name, path)

      // Act
      let assert Error(table.DecodeError(error)) =
        operations.get(settings, "theme")

      // Assert
      #(error.expected, error.found)
      |> should
      |> be_equal(#("String", "Int"))
      |> or_fail_with("Expected a String decoder to find an Int")
    }),
  ])
}
