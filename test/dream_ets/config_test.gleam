//// Tests for `dream_ets/config`.
////
//// The option tests read the options back from ETS with
//// `fixtures/ets_info`, so they check what `config.create` gave to ETS.

import dream_ets/config
import dream_ets/encoders
import dream_ets/operations
import dream_ets/table.{InvalidKey, InvalidValue, TableAlreadyExists}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/ets_info.{table_info}
import gleam/option
import gleam/result
import matchers/extract_table_name.{extract_table_name}

pub fn tests() -> TestSuite(Nil) {
  describe("dream_ets/config", [
    group("new", [
      it("creates a table with the given name", fn() {
        // Arrange
        let config_value =
          config.new("config_new_name")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = config.create(config_value)

        // Assert
        result
        |> should
        |> extract_table_name()
        |> be_equal("config_new_name")
        |> or_fail_with("Should have the given name")
      }),
      it("creates a named table", fn() {
        // Arrange
        let config_value =
          config.new("config_new_named")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "named_table"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should create a named table")
      }),
      it("uses the set table type by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_type")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("set"))
        |> or_fail_with("Should use the set type")
      }),
      it("uses public access by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_access")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("public"))
        |> or_fail_with("Should use public access")
      }),
      it("uses key position 1 by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_keypos")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "keypos"))

        // Assert
        result
        |> should
        |> be_equal(Ok("1"))
        |> or_fail_with("Should use key position 1")
      }),
      it("turns read concurrency off by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_read")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "read_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("false"))
        |> or_fail_with("Should turn read concurrency off")
      }),
      it("turns write concurrency off by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_write")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "write_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("false"))
        |> or_fail_with("Should turn write concurrency off")
      }),
      it("turns compression off by default", fn() {
        // Arrange
        let config_value =
          config.new("config_new_compressed")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "compressed"))

        // Assert
        result
        |> should
        |> be_equal(Ok("false"))
        |> or_fail_with("Should turn compression off")
      }),
    ]),
    group("table_type", [
      it("creates a set table", fn() {
        // Arrange
        let config_value =
          config.new("config_type_set")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_set())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("set"))
        |> or_fail_with("Should create a set table")
      }),
      it("creates an ordered_set table", fn() {
        // Arrange
        let config_value =
          config.new("config_type_ordered_set")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("ordered_set"))
        |> or_fail_with("Should create an ordered_set table")
      }),
      it("creates a bag table", fn() {
        // Arrange
        let config_value =
          config.new("config_type_bag")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_bag())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("bag"))
        |> or_fail_with("Should create a bag table")
      }),
      it("creates a duplicate_bag table", fn() {
        // Arrange
        let config_value =
          config.new("config_type_duplicate_bag")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_duplicate_bag())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("duplicate_bag"))
        |> or_fail_with("Should create a duplicate_bag table")
      }),
    ]),
    group("access", [
      it("creates a public table", fn() {
        // Arrange
        let config_value =
          config.new("config_access_public")
          |> config.key_string()
          |> config.value_string()
          |> config.access(config.access_public())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("public"))
        |> or_fail_with("Should create a public table")
      }),
      it("creates a protected table", fn() {
        // Arrange
        let config_value =
          config.new("config_access_protected")
          |> config.key_string()
          |> config.value_string()
          |> config.access(config.access_protected())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("protected"))
        |> or_fail_with("Should create a protected table")
      }),
      it("creates a private table", fn() {
        // Arrange
        let config_value =
          config.new("config_access_private")
          |> config.key_string()
          |> config.value_string()
          |> config.access(config.access_private())

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("private"))
        |> or_fail_with("Should create a private table")
      }),
    ]),
    group("keypos", [
      it("creates a table with the given key position", fn() {
        // Arrange
        let config_value =
          config.new("config_keypos")
          |> config.keypos(2)
          |> config.key_string()
          |> config.value_string()

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "keypos"))

        // Assert
        result
        |> should
        |> be_equal(Ok("2"))
        |> or_fail_with("Should use key position 2")
      }),
    ]),
    group("read_concurrency", [
      it("turns read concurrency on when write concurrency is also on", fn() {
        // Arrange
        let config_value =
          config.new("concurrency_both_read")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)
          |> config.write_concurrency(True)

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "read_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn read concurrency on")
      }),
      it("turns read concurrency on", fn() {
        // Arrange
        let config_value =
          config.new("config_read_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "read_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn read concurrency on")
      }),
    ]),
    group("write_concurrency", [
      it("turns write concurrency on when read concurrency is also on", fn() {
        // Arrange
        let config_value =
          config.new("concurrency_both_write")
          |> config.key_string()
          |> config.value_string()
          |> config.read_concurrency(True)
          |> config.write_concurrency(True)

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "write_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn write concurrency on")
      }),
      it("turns write concurrency on", fn() {
        // Arrange
        let config_value =
          config.new("config_write_concurrency")
          |> config.key_string()
          |> config.value_string()
          |> config.write_concurrency(True)

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "write_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn write concurrency on")
      }),
    ]),
    group("compressed", [
      it("turns compression on", fn() {
        // Arrange
        let config_value =
          config.new("config_compressed")
          |> config.key_string()
          |> config.value_string()
          |> config.compressed(True)

        // Act
        let result =
          config.create(config_value)
          |> result.map(table_info(_, "compressed"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn compression on")
      }),
    ]),
    group("key", [
      it("stores keys with the given encoder", fn() {
        // Arrange
        let config_value =
          config.new("config_key_custom")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value_string()

        // Act
        let result = {
          use created <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(created, 42, "answer"))
          operations.get(created, 42)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("answer")))
        |> or_fail_with("Should store the value under the Int key")
      }),
    ]),
    group("value", [
      it("stores values with the given encoder", fn() {
        // Arrange
        let config_value =
          config.new("config_value_custom")
          |> config.key_string()
          |> config.value(encoders.bool_encoder, encoders.bool_decoder())

        // Act
        let result = {
          use created <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(created, "enabled", True))
          operations.get(created, "enabled")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(True)))
        |> or_fail_with("Should store the Bool value")
      }),
    ]),
    group("key_string", [
      it("stores String keys", fn() {
        // Arrange
        let config_value =
          config.new("config_key_string")
          |> config.key_string()
          |> config.value(encoders.int_encoder, encoders.int_decoder())

        // Act
        let result = {
          use created <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(created, "visits", 3))
          operations.keys(created)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["visits"]))
        |> or_fail_with("Should return the String key")
      }),
    ]),
    group("value_string", [
      it("stores String values", fn() {
        // Arrange
        let config_value =
          config.new("config_value_string")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value_string()

        // Act
        let result = {
          use created <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(created, 1, "first"))
          operations.values(created)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["first"]))
        |> or_fail_with("Should return the String value")
      }),
    ]),
    group("counter", [
      it("stores Int values under String keys", fn() {
        // Arrange
        let config_value =
          config.new("config_counter")
          |> config.counter()

        // Act
        let result = {
          use created <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(created, "hits", 7))
          operations.to_list(created)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([#("hits", 7)]))
        |> or_fail_with("Should return the String key and the Int value")
      }),
    ]),
    group("create", [
      it("returns InvalidKey when the key encoder is missing", fn() {
        // Arrange
        let config_value = config.new("config_create_no_key")

        // Act
        let result = config.create(config_value)

        // Assert
        result
        |> should
        |> be_equal(Error(InvalidKey))
        |> or_fail_with("Should return InvalidKey")
      }),
      it("returns InvalidValue when the value encoder is missing", fn() {
        // Arrange
        let config_value =
          config.new("config_create_no_value")
          |> config.key_string()

        // Act
        let result = config.create(config_value)

        // Assert
        result
        |> should
        |> be_equal(Error(InvalidValue))
        |> or_fail_with("Should return InvalidValue")
      }),
      it("returns TableAlreadyExists when the name is in use", fn() {
        // Arrange
        let config_value =
          config.new("config_create_duplicate")
          |> config.key_string()
          |> config.value_string()

        // Act
        let result = {
          use _first <- result.try(config.create(config_value))
          config.create(config_value)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableAlreadyExists))
        |> or_fail_with("Should return TableAlreadyExists")
      }),
    ]),
  ])
}
