//// Tests for the snippets of the getting started guide
//// (docs/guides/getting-started.md). Each test runs a snippet and asserts
//// the exact value that the guide shows.

import dream_ets/config
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/other_process
import gleam/dynamic
import gleam/option.{Some}
import snippets/guide_getting_started_errors.{describe_lookup}
import snippets/guide_getting_started_first_table
import snippets/guide_getting_started_owner
import snippets/guide_getting_started_share
import snippets/guide_getting_started_tables
import snippets/guide_getting_started_types

pub fn tests() -> TestSuite {
  describe("getting started guide", [
    it("step 1: first_table reads back the stored name", fn() {
      // Act
      let name = guide_getting_started_first_table.first_table()

      // Assert
      name
      |> should
      |> be_equal(Ok(Some("Alice")))
      |> or_fail_with("Expected the name that was stored")
    }),
    it("step 1: get returns None for a key that is not stored", fn() {
      // Arrange
      let assert Ok(names) = helpers.new_string_table("guide_gs_missing_key")

      // Act
      let name = operations.get(names, "user:2")

      // Assert
      name
      |> should
      |> be_equal(Ok(option.None))
      |> or_fail_with("Expected no value")
    }),
    it("step 1: a second table with the same name is refused", fn() {
      // Arrange
      let assert Ok(_) = helpers.new_string_table("guide_gs_same_name")

      // Act
      let second = helpers.new_string_table("guide_gs_same_name")

      // Assert
      second
      |> should
      |> be_equal(Error(table.TableAlreadyExists))
      |> or_fail_with("Expected TableAlreadyExists")
    }),
    it("step 2: three processes write to one table", fn() {
      // Arrange
      let assert Ok(names) = helpers.new_string_table("guide_gs_share")

      // Act
      let keys = guide_getting_started_share.write_from_three_processes(names)

      // Assert
      keys
      |> should
      |> be_equal(Ok(["user:ada", "user:grace", "user:linus"]))
      |> or_fail_with("Expected the key of each process")
    }),
    it("step 3: a table goes away with its owner process", fn() {
      // Act
      let name = guide_getting_started_owner.create_in_short_process()

      // Assert
      name
      |> should
      |> be_equal(Error(table.TableNotFound))
      |> or_fail_with("Expected TableNotFound after the owner stopped")
    }),
    it("step 3: greet reads the tables made at start-up", fn() {
      // Arrange
      let assert Ok(tables) = guide_getting_started_tables.create_tables()
      let assert Ok(Nil) = operations.set(tables.names, "user:1", "Alice")
      let assert Ok(_) = guide_getting_started_tables.greet(tables, "user:1")

      // Act
      let greeting = guide_getting_started_tables.greet(tables, "user:1")

      // Assert
      greeting
      |> should
      |> be_equal(Ok("Hello, Alice. Views of this page: 2"))
      |> or_fail_with("Expected the second greeting")
    }),
    it("step 4: price_of_product_42 reads back the Float", fn() {
      // Act
      let price = guide_getting_started_types.price_of_product_42()

      // Assert
      price
      |> should
      |> be_equal(Ok(Some(9.99)))
      |> or_fail_with("Expected the stored price")
    }),
    it("failures: describe_lookup finds a stored name", fn() {
      // Arrange
      let assert Ok(names) = helpers.new_string_table("guide_gs_describe_found")
      let assert Ok(Nil) = operations.set(names, "user:1", "Alice")

      // Act
      let message = describe_lookup(names, "user:1")

      // Assert
      message
      |> should
      |> be_equal("Found Alice")
      |> or_fail_with("Expected the found message")
    }),
    it("failures: describe_lookup reports a missing key", fn() {
      // Arrange
      let assert Ok(names) =
        helpers.new_string_table("guide_gs_describe_missing")

      // Act
      let message = describe_lookup(names, "user:2")

      // Assert
      message
      |> should
      |> be_equal("No name for user:2")
      |> or_fail_with("Expected the missing message")
    }),
    it("failures: describe_lookup reports a deleted table", fn() {
      // Arrange
      let assert Ok(names) =
        helpers.new_string_table("guide_gs_describe_deleted")
      let assert Ok(Nil) = operations.delete_table(names)

      // Act
      let message = describe_lookup(names, "user:1")

      // Assert
      message
      |> should
      |> be_equal("The table is gone. Did its owner process stop?")
      |> or_fail_with("Expected the deleted table message")
    }),
    it("failures: describe_lookup reports a value that does not decode", fn() {
      // Arrange
      // This encoder stores an Int, but the decoder wants a String
      let assert Ok(names) =
        config.new("guide_gs_describe_decode")
        |> config.key_string()
        |> config.value(
          fn(_name: String) { dynamic.int(7) },
          encoders.string_decoder(),
        )
        |> config.create()
      let assert Ok(Nil) = operations.set(names, "user:1", "Alice")

      // Act
      let message = describe_lookup(names, "user:1")

      // Assert
      message
      |> should
      |> be_equal("The stored value is not a String: Int")
      |> or_fail_with("Expected the decode message")
    }),
    it("failures: describe_lookup reports a refused lookup", fn() {
      // Arrange
      let assert Ok(names) =
        config.new("guide_gs_describe_private")
        |> config.access(config.access_private())
        |> config.key_string()
        |> config.value_string()
        |> config.create()

      // Act
      let message = other_process.run(fn() { describe_lookup(names, "user:1") })

      // Assert
      message
      |> should
      |> be_equal(Ok(
        "ETS refused the lookup: ETS refused the operation: badarg",
      ))
      |> or_fail_with("Expected the refused message")
    }),
    it("failures: a config with no value encoder is refused", fn() {
      // Act
      let created =
        config.new("guide_gs_no_value")
        |> config.key_string()
        |> config.create()

      // Assert
      created
      |> should
      |> be_equal(Error(table.InvalidValue))
      |> or_fail_with("Expected InvalidValue")
    }),
  ])
}
