//// Tests for `dream_ets/helpers`: the table functions and the counter
//// functions.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{OperationFailed, TableAlreadyExists, TableNotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/deleted_table.{deleted_counter}
import fixtures/ets_info.{table_info}
import fixtures/guarded_table.{protected_counter}
import fixtures/other_process
import gleam/option
import gleam/result
import matchers/extract_table_name.{extract_table_name}

pub fn tests() -> TestSuite {
  describe("dream_ets/helpers", [
    group("new_counter", [
      it("creates a table with the given name", fn() {
        // Arrange
        let name = "counter_new_name"

        // Act
        let result = helpers.new_counter(name)

        // Assert
        result
        |> should
        |> extract_table_name()
        |> be_equal("counter_new_name")
        |> or_fail_with("Should have the given name")
      }),
      it("creates a set table", fn() {
        // Arrange
        let name = "counter_new_type"

        // Act
        let result =
          helpers.new_counter(name)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("set"))
        |> or_fail_with("Should create a set table")
      }),
      it("stores Int values under String keys", fn() {
        // Arrange
        let name = "counter_new_values"

        // Act
        let result = {
          use counter <- result.try(helpers.new_counter(name))
          use _ <- result.try(operations.set(counter, "hits", 12))
          operations.get(counter, "hits")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(12)))
        |> or_fail_with("Should return the stored Int")
      }),
    ]),
    group("new_string_table", [
      it("creates a table with the given name", fn() {
        // Arrange
        let name = "helpers_string_name"

        // Act
        let result = helpers.new_string_table(name)

        // Assert
        result
        |> should
        |> extract_table_name()
        |> be_equal("helpers_string_name")
        |> or_fail_with("Should have the given name")
      }),
      it("stores String values under String keys", fn() {
        // Arrange
        let name = "helpers_string_values"

        // Act
        let result = {
          use strings <- result.try(helpers.new_string_table(name))
          use _ <- result.try(operations.set(strings, "key", "value"))
          operations.get(strings, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value")))
        |> or_fail_with("Should return the stored String")
      }),
      it("returns TableAlreadyExists when the name is in use", fn() {
        // Arrange
        let name = "helpers_string_duplicate"

        // Act
        let result = {
          use _first <- result.try(helpers.new_string_table(name))
          helpers.new_string_table(name)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableAlreadyExists))
        |> or_fail_with("Should return TableAlreadyExists")
      }),
    ]),
    group("increment", [
      it("returns 1 for a new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_inc_new"))

          // Act
          helpers.increment(counter, "new_key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(1))
        |> or_fail_with("Should start the count at 1")
      }),
      it("stores 1 for a new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_inc_stored"))

          // Act
          use _ <- result.try(helpers.increment(counter, "new_key"))
          operations.get(counter, "new_key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(1)))
        |> or_fail_with("Should store 1")
      }),
      it("adds 1 to an existing key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_inc_existing"))
          use _ <- result.try(operations.set(counter, "key1", 5))

          // Act
          helpers.increment(counter, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(6))
        |> or_fail_with("Should increment 5 to 6")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_counter("deleted_increment"))

          // Act
          helpers.increment(deleted, "hits")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "increment on a deleted table should return TableNotFound",
        )
      }),
    ]),
    group("increment_by", [
      it("adds the amount to an existing key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_inc_by"))
          use _ <- result.try(operations.set(counter, "score", 10))

          // Act
          helpers.increment_by(counter, "score", 5)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(15))
        |> or_fail_with("Should add 5 to 10")
      }),
      it("starts a new key at the amount", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_inc_by_new"))

          // Act
          helpers.increment_by(counter, "score", 5)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(5))
        |> or_fail_with("Should start the count at 5")
      }),
    ]),
    group("decrement", [
      it("subtracts 1 from an existing key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_dec_existing"))
          use _ <- result.try(operations.set(counter, "key1", 10))

          // Act
          helpers.decrement(counter, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(9))
        |> or_fail_with("Should decrement 10 to 9")
      }),
      it("returns -1 for a new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_dec_new"))

          // Act
          helpers.decrement(counter, "new_key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(-1))
        |> or_fail_with("Should start the count at -1")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_counter("deleted_decrement"))

          // Act
          helpers.decrement(deleted, "hits")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "decrement on a deleted table should return TableNotFound",
        )
      }),
    ]),
    group("decrement_by", [
      it("subtracts the amount from an existing key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_dec_by"))
          use _ <- result.try(operations.set(counter, "score", 20))

          // Act
          helpers.decrement_by(counter, "score", 7)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(13))
        |> or_fail_with("Should subtract 7 from 20")
      }),
      it("starts a new key at the negative amount", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter("counter_dec_by_new"))

          // Act
          helpers.decrement_by(counter, "score", 7)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(-7))
        |> or_fail_with("Should start the count at -7")
      }),
      it("stores the negative amount for a new key", fn() {
        // Arrange
        let result = {
          use counter <- result.try(helpers.new_counter(
            "counter_dec_by_new_stored",
          ))

          // Act
          use _ <- result.try(helpers.decrement_by(counter, "score", 7))
          operations.get(counter, "score")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(-7)))
        |> or_fail_with("Should store -7")
      }),
    ]),
    group("refused operations", [
      it(
        "increment returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use counter <- result.try(
              protected_counter("refused_increment")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { helpers.increment(counter, "hits") })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused write")
        },
      ),
      it(
        "increment_by returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use counter <- result.try(
              protected_counter("refused_increment_by")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { helpers.increment_by(counter, "hits", 5) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused write")
        },
      ),
      it(
        "decrement returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use counter <- result.try(
              protected_counter("refused_decrement")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { helpers.decrement(counter, "hits") })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused write")
        },
      ),
      it(
        "decrement_by returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use counter <- result.try(
              protected_counter("refused_decrement_by")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { helpers.decrement_by(counter, "hits", 5) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused write")
        },
      ),
    ]),
  ])
}
