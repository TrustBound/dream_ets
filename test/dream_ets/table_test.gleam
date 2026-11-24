//// Tests for `dream_ets/table`.

import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
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
  ])
}
