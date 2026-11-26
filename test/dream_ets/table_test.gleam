//// Tests for `dream_ets/table`.

import dream_errors.{Conflict, Failed, Invalid, NotFound}
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{
  DecodeError, InvalidKey, InvalidValue, OperationFailed, TableAlreadyExists,
  TableNotFound, to_error,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/option
import gleam/result

pub fn tests() -> TestSuite {
  describe("dream_ets/table", [
    group("table_ref", [
      it("gives a reference that reaches the objects of the table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("table_ref"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          let copy =
            table.new_table(
              table.table_ref(strings),
              "table_ref",
              encoders.string_encoder,
              encoders.string_decoder(),
              encoders.string_encoder,
              encoders.string_decoder(),
            )
          operations.get(copy, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value1")))
        |> or_fail_with("Should read the object through the reference")
      }),
    ]),
    group("table_name", [
      it("returns the name of the table", fn() {
        // Arrange
        let created = helpers.new_string_table("table_name")

        // Act
        let result = created |> result.map(table.table_name)

        // Assert
        result
        |> should
        |> be_equal(Ok("table_name"))
        |> or_fail_with("Should return the name given at creation")
      }),
    ]),
    group("encode_key", [
      it("encodes a key with the key encoder of the table", fn() {
        // Arrange
        let created = helpers.new_string_table("table_encode_key")

        // Act
        let result = created |> result.map(table.encode_key(_, "key1"))

        // Assert
        result
        |> should
        |> be_equal(Ok(dynamic.string("key1")))
        |> or_fail_with("Should encode the key as a dynamic String")
      }),
    ]),
    group("decode_key", [
      it("decodes a key with the key decoder of the table", fn() {
        // Arrange
        let created = helpers.new_string_table("table_decode_key")

        // Act
        let result =
          created
          |> result.map(table.decode_key(_, dynamic.string("key1")))

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("key1")))
        |> or_fail_with("Should decode the key")
      }),
      it("returns the first decode error for a key of another type", fn() {
        // Arrange
        let created = helpers.new_string_table("table_decode_key_error")

        // Act
        let result =
          created
          |> result.map(table.decode_key(_, dynamic.int(1)))

        // Assert
        result
        |> should
        |> be_equal(Ok(Error(decode.DecodeError("String", "Int", []))))
        |> or_fail_with("Should return the decode error of the key")
      }),
    ]),
    group("encode_value", [
      it("encodes a value with the value encoder of the table", fn() {
        // Arrange
        let created = helpers.new_counter("table_encode_value")

        // Act
        let result = created |> result.map(table.encode_value(_, 42))

        // Assert
        result
        |> should
        |> be_equal(Ok(dynamic.int(42)))
        |> or_fail_with("Should encode the value as a dynamic Int")
      }),
    ]),
    group("decode_value", [
      it("decodes a value with the value decoder of the table", fn() {
        // Arrange
        let created = helpers.new_counter("table_decode_value")

        // Act
        let result =
          created
          |> result.map(table.decode_value(_, dynamic.int(42)))

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok(42)))
        |> or_fail_with("Should decode the value")
      }),
      it("returns the first decode error for a value of another type", fn() {
        // Arrange
        let created = helpers.new_counter("table_decode_value_error")

        // Act
        let result =
          created
          |> result.map(table.decode_value(_, dynamic.string("x")))

        // Assert
        result
        |> should
        |> be_equal(Ok(Error(decode.DecodeError("Int", "String", []))))
        |> or_fail_with("Should return the decode error of the value")
      }),
    ]),
    group("new_table", [
      it("builds a table with the given name", fn() {
        // Arrange
        let created = helpers.new_string_table("table_new_table")

        // Act
        let result =
          created
          |> result.map(fn(strings) {
            table.new_table(
              table.table_ref(strings),
              "other_name",
              encoders.string_encoder,
              encoders.string_decoder(),
              encoders.string_encoder,
              encoders.string_decoder(),
            )
            |> table.table_name
          })

        // Assert
        result
        |> should
        |> be_equal(Ok("other_name"))
        |> or_fail_with("Should keep the given name")
      }),
    ]),
    group("to_error", [
      it("maps TableNotFound to NotFound", fn() {
        // Arrange
        let error = TableNotFound

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(NotFound("the ETS table does not exist, or it was deleted"))
        |> or_fail_with("Should map TableNotFound to NotFound")
      }),
      it("maps TableAlreadyExists to Conflict", fn() {
        // Arrange
        let error = TableAlreadyExists

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(Conflict(
          "an ETS table with this name exists",
          TableAlreadyExists,
        ))
        |> or_fail_with("Should map TableAlreadyExists to Conflict")
      }),
      it("maps InvalidKey to Invalid", fn() {
        // Arrange
        let error = InvalidKey

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(Invalid(
          "the table configuration has no key encoder",
          InvalidKey,
        ))
        |> or_fail_with("Should map InvalidKey to Invalid")
      }),
      it("maps InvalidValue to Invalid", fn() {
        // Arrange
        let error = InvalidValue

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(Invalid(
          "the table configuration has no value encoder",
          InvalidValue,
        ))
        |> or_fail_with("Should map InvalidValue to Invalid")
      }),
      it("maps DecodeError to Failed", fn() {
        // Arrange
        let error = DecodeError(decode.DecodeError("Int", "String", []))

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(Failed(
          "a key or value in the ETS table does not decode with the decoder of the table",
          DecodeError(decode.DecodeError("Int", "String", [])),
        ))
        |> or_fail_with("Should map DecodeError to Failed")
      }),
      it("maps OperationFailed to Failed with the reason", fn() {
        // Arrange
        let error = OperationFailed("ETS refused the operation: badarg")

        // Act
        let result = to_error(error)

        // Assert
        result
        |> should
        |> be_equal(Failed(
          "the ETS operation failed: ETS refused the operation: badarg",
          OperationFailed("ETS refused the operation: badarg"),
        ))
        |> or_fail_with("Should map OperationFailed to Failed")
      }),
    ]),
  ])
}
