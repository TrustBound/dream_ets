//// Tests for `dream_ets/encoders`.

import dream_ets/encoders
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/dynamic
import gleam/dynamic/decode

pub fn tests() -> TestSuite(Nil) {
  describe("dream_ets/encoders", [
    group("string_encoder", [
      it("encodes a String as a dynamic String", fn() {
        // Arrange
        let text = "hello"

        // Act
        let result = encoders.string_encoder(text)

        // Assert
        result
        |> should
        |> be_equal(dynamic.string("hello"))
        |> or_fail_with("Should encode the String unchanged")
      }),
    ]),
    group("string_decoder", [
      it("decodes a dynamic String", fn() {
        // Arrange
        let data = dynamic.string("hello")

        // Act
        let result = decode.run(data, encoders.string_decoder())

        // Assert
        result
        |> should
        |> be_equal(Ok("hello"))
        |> or_fail_with("Should decode the String")
      }),
      it("rejects a dynamic Int", fn() {
        // Arrange
        let data = dynamic.int(1)

        // Act
        let result = decode.run(data, encoders.string_decoder())

        // Assert
        result
        |> should
        |> be_equal(Error([decode.DecodeError("String", "Int", [])]))
        |> or_fail_with("Should reject the Int")
      }),
    ]),
    group("int_encoder", [
      it("encodes an Int as a dynamic Int", fn() {
        // Arrange
        let number = 42

        // Act
        let result = encoders.int_encoder(number)

        // Assert
        result
        |> should
        |> be_equal(dynamic.int(42))
        |> or_fail_with("Should encode the Int unchanged")
      }),
    ]),
    group("int_decoder", [
      it("decodes a dynamic Int", fn() {
        // Arrange
        let data = dynamic.int(42)

        // Act
        let result = decode.run(data, encoders.int_decoder())

        // Assert
        result
        |> should
        |> be_equal(Ok(42))
        |> or_fail_with("Should decode the Int")
      }),
      it("rejects a dynamic String", fn() {
        // Arrange
        let data = dynamic.string("42")

        // Act
        let result = decode.run(data, encoders.int_decoder())

        // Assert
        result
        |> should
        |> be_equal(Error([decode.DecodeError("Int", "String", [])]))
        |> or_fail_with("Should reject the String")
      }),
    ]),
    group("bool_encoder", [
      it("encodes a Bool as a dynamic Bool", fn() {
        // Arrange
        let flag = True

        // Act
        let result = encoders.bool_encoder(flag)

        // Assert
        result
        |> should
        |> be_equal(dynamic.bool(True))
        |> or_fail_with("Should encode the Bool unchanged")
      }),
    ]),
    group("bool_decoder", [
      it("decodes a dynamic Bool", fn() {
        // Arrange
        let data = dynamic.bool(False)

        // Act
        let result = decode.run(data, encoders.bool_decoder())

        // Assert
        result
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("Should decode the Bool")
      }),
      it("rejects a dynamic Int", fn() {
        // Arrange
        let data = dynamic.int(1)

        // Act
        let result = decode.run(data, encoders.bool_decoder())

        // Assert
        result
        |> should
        |> be_equal(Error([decode.DecodeError("Bool", "Int", [])]))
        |> or_fail_with("Should reject the Int")
      }),
    ]),
    group("float_encoder", [
      it("encodes a Float as a dynamic Float", fn() {
        // Arrange
        let number = 3.5

        // Act
        let result = encoders.float_encoder(number)

        // Assert
        result
        |> should
        |> be_equal(dynamic.float(3.5))
        |> or_fail_with("Should encode the Float unchanged")
      }),
    ]),
    group("float_decoder", [
      it("decodes a dynamic Float", fn() {
        // Arrange
        let data = dynamic.float(3.5)

        // Act
        let result = decode.run(data, encoders.float_decoder())

        // Assert
        result
        |> should
        |> be_equal(Ok(3.5))
        |> or_fail_with("Should decode the Float")
      }),
      it("rejects a dynamic Int", fn() {
        // Arrange
        let data = dynamic.int(3)

        // Act
        let result = decode.run(data, encoders.float_decoder())

        // Assert
        result
        |> should
        |> be_equal(Error([decode.DecodeError("Float", "Int", [])]))
        |> or_fail_with("Should reject the Int")
      }),
    ]),
  ])
}
