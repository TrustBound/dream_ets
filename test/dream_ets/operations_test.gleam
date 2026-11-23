//// Tests for `dream_ets/operations`.
////
//// The bulk and match tests use ordered_set tables, so that ETS returns the
//// objects in key order. On a deleted table, each operation must return
//// `Error(TableNotFound)` and must not crash the calling process. When ETS
//// holds data that the decoders of the table cannot read, the operations
//// return `DecodeError`.

import dream_ets/config
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{DecodeError, OperationFailed, TableNotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/deleted_table.{deleted_string_table}
import fixtures/guarded_table.{private_string_table, protected_string_table}
import fixtures/key_only_file
import fixtures/other_process
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/function
import gleam/option
import gleam/result
import gleam/string

pub fn tests() -> TestSuite {
  describe("dream_ets/operations", [
    group("set", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_set"))

          // Act
          operations.set(deleted, "key", "value")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("set on a deleted table should return TableNotFound")
      }),
      it("returns Ok for a new key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_set_new"))

          // Act
          operations.set(strings, "key1", "value1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should set the value")
      }),
      it("replaces the value of an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_set_update"))
          use _ <- result.try(operations.set(strings, "key1", "original"))

          // Act
          use _ <- result.try(operations.set(strings, "key1", "updated"))
          operations.get(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("updated")))
        |> or_fail_with("Should replace the value")
      }),
    ]),
    group("get", [
      it("returns a value that another process set in a public table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(
            helpers.new_string_table("concurrency_public")
            |> result.replace_error("create failed"),
          )
          use set_result <- result.try(
            other_process.run(fn() { operations.set(strings, "from", "child") }),
          )
          use _ <- result.try(set_result |> result.replace_error("set failed"))

          // Act
          operations.get(strings, "from")
          |> result.replace_error("get failed")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("child")))
        |> or_fail_with("Should read the value that the child process set")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_get"))

          // Act
          operations.get(deleted, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("get on a deleted table should return TableNotFound")
      }),
      it("returns None for a missing key in an empty table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("errors_get"))

          // Act
          operations.get(strings, "nonexistent")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should return None")
      }),
      it("returns the value of an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_get_existing"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.get(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value1")))
        |> or_fail_with("Should return the value")
      }),
      it("returns None for a missing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_get_missing"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.get(strings, "nonexistent")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should return None")
      }),
      it("returns an Int value as an Int", fn() {
        // Arrange
        let config_value =
          config.new("types_int_value")
          |> config.key_string()
          |> config.value(encoders.int_encoder, encoders.int_decoder())

        // Act
        let result = {
          use ints <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(ints, "key1", 42))
          operations.get(ints, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(42)))
        |> or_fail_with("Should return 42")
      }),
      it("returns DecodeError for a bag key with two values", fn() {
        // Arrange
        let config_value =
          config.new("types_bag_get")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_bag())

        // Act
        let result = {
          use bag <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(bag, "key", "first"))
          use _ <- result.try(operations.set(bag, "key", "second"))
          operations.get(bag, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(DecodeError(decode.DecodeError("String", "Array", []))),
        )
        |> or_fail_with("Should fail to decode the list of two objects")
      }),
      it("returns DecodeError for a loaded object that has no value", fn() {
        // Arrange
        let filename = "build/types_key_only_get.ets"
        key_only_file.write("types_key_only_get", "key", filename)
        let config_value =
          config.new("types_key_only_get")
          |> config.key_string()
          |> config.value_string()
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.delete_table(strings))
          use _ <- result.try(operations.load_from_file(filename))

          // Act
          operations.get(strings, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(DecodeError(decode.DecodeError("Field", "Nothing", ["1"]))),
        )
        |> or_fail_with("Should fail to read the value of the object")
      }),
    ]),
    group("delete", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_delete"))

          // Act
          operations.delete(deleted, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("delete on a deleted table should return TableNotFound")
      }),
      it("returns Ok for a missing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("errors_delete"))

          // Act
          operations.delete(strings, "nonexistent")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should succeed for a missing key")
      }),
      it("removes an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_delete"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          use _ <- result.try(operations.delete(strings, "key1"))
          operations.get(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should remove the key")
      }),
    ]),
    group("member", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_member"))

          // Act
          operations.member(deleted, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("member on a deleted table should return TableNotFound")
      }),
      it("returns True for an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_member_true"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.member(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(True))
        |> or_fail_with("Should find the key")
      }),
      it("returns False for a missing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_member_false"))

          // Act
          operations.member(strings, "nonexistent")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("Should not find the key")
      }),
    ]),
    group("delete_table", [
      it("returns TableNotFound when the table is already deleted", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_delete_table"))

          // Act
          operations.delete_table(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "delete_table on a deleted table should return TableNotFound",
        )
      }),
      it("returns Ok for an existing table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_drop"))

          // Act
          operations.delete_table(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should delete the table")
      }),
      it("removes the table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_drop_gone"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          use _ <- result.try(operations.delete_table(strings))
          operations.get(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("Should not find the deleted table")
      }),
    ]),
    group("size", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_size"))

          // Act
          operations.size(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("size on a deleted table should return TableNotFound")
      }),
      it("returns the number of objects", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_size"))
          use _ <- result.try(operations.set(strings, "a", "1"))
          use _ <- result.try(operations.set(strings, "b", "2"))
          use _ <- result.try(operations.set(strings, "c", "3"))

          // Act
          operations.size(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(3))
        |> or_fail_with("Should count three objects")
      }),
      it("returns 0 for an empty table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_size_empty"))

          // Act
          operations.size(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(0))
        |> or_fail_with("Should count no objects")
      }),
    ]),
    group("keys", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_keys"))

          // Act
          operations.keys(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("keys on a deleted table should return TableNotFound")
      }),
      it("returns every key, last key first", fn() {
        // Arrange
        let config_value =
          config.new("ops_keys")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "a", "1"))
          use _ <- result.try(operations.set(strings, "b", "2"))
          use _ <- result.try(operations.set(strings, "c", "3"))

          // Act
          operations.keys(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["c", "b", "a"]))
        |> or_fail_with("Should return every key")
      }),
      it("returns an empty list for an empty table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_keys_empty"))

          // Act
          operations.keys(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([]))
        |> or_fail_with("Should return no keys")
      }),
      it("returns typed keys", fn() {
        // Arrange
        let config_value =
          config.new("types_keys")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result = {
          use numbers <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(numbers, 1, "one"))
          use _ <- result.try(operations.set(numbers, 2, "two"))
          operations.keys(numbers)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([2, 1]))
        |> or_fail_with("Should return both Int keys, last key first")
      }),
      it("returns DecodeError when the first key does not decode", fn() {
        // Arrange: with key position 2, ETS uses the String value as the key
        let config_value =
          config.new("types_keys_first_bad")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value_string()
          |> config.keypos(2)

        // Act
        let result = {
          use numbers <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(numbers, 1, "one"))
          operations.keys(numbers)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(DecodeError(decode.DecodeError("Int", "String", []))))
        |> or_fail_with("Should fail to decode the String key")
      }),
      it("returns DecodeError when a later key does not decode", fn() {
        // Arrange: with key position 2, ETS uses the value as the key. In
        // an ordered_set the Int key 1 comes before the String key "x".
        let config_value =
          config.new("types_keys_later_bad")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value(function.identity, decode.dynamic)
          |> config.keypos(2)
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result = {
          use mixed <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(mixed, 10, dynamic.int(1)))
          use _ <- result.try(operations.set(mixed, 20, dynamic.string("x")))
          operations.keys(mixed)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(DecodeError(decode.DecodeError("Int", "String", []))))
        |> or_fail_with("Should fail to decode the second key")
      }),
    ]),
    group("values", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_values"))

          // Act
          operations.values(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("values on a deleted table should return TableNotFound")
      }),
      it("returns every value, last key first", fn() {
        // Arrange
        let config_value =
          config.new("ops_values")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "a", "1"))
          use _ <- result.try(operations.set(strings, "b", "2"))

          // Act
          operations.values(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["2", "1"]))
        |> or_fail_with("Should return every value")
      }),
      it("returns typed values", fn() {
        // Arrange
        let config_value =
          config.new("types_values")
          |> config.key(encoders.int_encoder, encoders.int_decoder())
          |> config.value(encoders.float_encoder, encoders.float_decoder())
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result = {
          use prices <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(prices, 1, 1.5))
          use _ <- result.try(operations.set(prices, 2, 2.5))
          operations.values(prices)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([2.5, 1.5]))
        |> or_fail_with("Should return both Float values, last key first")
      }),
      it("returns OperationFailed when a listed key is not found", fn() {
        // Arrange: the key decoder changes the key, so a lookup with the
        // decoded key finds nothing
        let config_value =
          config.new("types_values_missing")
          |> config.key(
            encoders.string_encoder,
            decode.map(decode.string, string.uppercase),
          )
          |> config.value_string()

        // Act
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "a", "value"))
          operations.values(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          )),
        )
        |> or_fail_with("Should report the missing key")
      }),
    ]),
    group("to_list", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_to_list"))

          // Act
          operations.to_list(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "to_list on a deleted table should return TableNotFound",
        )
      }),
      it("returns every pair, last key first", fn() {
        // Arrange
        let config_value =
          config.new("ops_to_list")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "a", "1"))
          use _ <- result.try(operations.set(strings, "b", "2"))

          // Act
          operations.to_list(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([#("b", "2"), #("a", "1")]))
        |> or_fail_with("Should return every pair")
      }),
      it("returns typed pairs", fn() {
        // Arrange
        let config_value =
          config.new("types_pairs")
          |> config.key_string()
          |> config.value(encoders.bool_encoder, encoders.bool_decoder())
          |> config.table_type(config.table_type_ordered_set())

        // Act
        let result = {
          use flags <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(flags, "a", True))
          use _ <- result.try(operations.set(flags, "b", False))
          operations.to_list(flags)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([#("b", False), #("a", True)]))
        |> or_fail_with("Should return both pairs, last key first")
      }),
      it("returns OperationFailed when a listed key is not found", fn() {
        // Arrange: the key decoder changes the key, so a lookup with the
        // decoded key finds nothing
        let config_value =
          config.new("types_to_list_missing")
          |> config.key(
            encoders.string_encoder,
            decode.map(decode.string, string.uppercase),
          )
          |> config.value_string()

        // Act
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "a", "value"))
          operations.to_list(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(OperationFailed(
            "Key disappeared during iteration (concurrent delete?)",
          )),
        )
        |> or_fail_with("Should report the missing key")
      }),
    ]),
    group("insert_new", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_insert_new"))

          // Act
          operations.insert_new(deleted, "key", "value")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "insert_new on a deleted table should return TableNotFound",
        )
      }),
      it("returns True for a new key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_insert_new"))

          // Act
          operations.insert_new(strings, "key1", "value1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(True))
        |> or_fail_with("Should insert the new key")
      }),
      it("returns False for an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table(
            "ops_insert_existing",
          ))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.insert_new(strings, "key1", "value2")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("Should not insert an existing key")
      }),
      it("keeps the value of an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_insert_keep"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          use _ <- result.try(operations.insert_new(strings, "key1", "value2"))
          operations.get(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value1")))
        |> or_fail_with("Should keep the first value")
      }),
    ]),
    group("take", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_take"))

          // Act
          operations.take(deleted, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("take on a deleted table should return TableNotFound")
      }),
      it("returns the value of an existing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_take_value"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.take(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value1")))
        |> or_fail_with("Should return the value")
      }),
      it("removes the key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_take_removes"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          use _ <- result.try(operations.take(strings, "key1"))
          operations.member(strings, "key1")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(False))
        |> or_fail_with("Should remove the key")
      }),
      it("returns None for a missing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_take_missing"))

          // Act
          operations.take(strings, "nonexistent")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should return None")
      }),
      it("returns DecodeError for a bag key with two values", fn() {
        // Arrange
        let config_value =
          config.new("types_bag_take")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_bag())

        // Act
        let result = {
          use bag <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(bag, "key", "first"))
          use _ <- result.try(operations.set(bag, "key", "second"))
          operations.take(bag, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(DecodeError(decode.DecodeError("String", "Array", []))),
        )
        |> or_fail_with("Should fail to decode the list of two objects")
      }),
      it("returns DecodeError for a loaded object that has no value", fn() {
        // Arrange
        let filename = "build/types_key_only_take.ets"
        key_only_file.write("types_key_only_take", "key", filename)
        let config_value =
          config.new("types_key_only_take")
          |> config.key_string()
          |> config.value_string()
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.delete_table(strings))
          use _ <- result.try(operations.load_from_file(filename))

          // Act
          operations.take(strings, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(DecodeError(decode.DecodeError("Field", "Nothing", ["1"]))),
        )
        |> or_fail_with("Should fail to read the value of the object")
      }),
    ]),
    group("update_element", [
      it("returns Ok for an existing key", fn() {
        // Arrange
        let config_value =
          config.new("advanced_update_result")
          |> config.key_string()
          |> config.value_string()
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "key", "original"))

          // Act: position 2 is the value in the {key, value} object
          operations.update_element(strings, "key", 2, dynamic.string("new"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should update the element")
      }),
      it("replaces the value of an existing key", fn() {
        // Arrange
        let config_value =
          config.new("advanced_update_value")
          |> config.key_string()
          |> config.value_string()
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "key", "original"))

          // Act
          use _ <- result.try(operations.update_element(
            strings,
            "key",
            2,
            dynamic.string("new"),
          ))
          operations.get(strings, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("new")))
        |> or_fail_with("Should store the new value")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_update"))

          // Act
          operations.update_element(deleted, "key", 2, dynamic.string("value"))
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "update_element on a deleted table should return TableNotFound",
        )
      }),
      it("returns TableNotFound for a missing key", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("errors_update"))

          // Act
          operations.update_element(
            strings,
            "nonexistent",
            2,
            dynamic.string("value"),
          )
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("Should return TableNotFound for a missing key")
      }),
    ]),
    group("delete_all_objects", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_delete_all"))

          // Act
          operations.delete_all_objects(deleted)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "delete_all_objects on a deleted table should return TableNotFound",
        )
      }),
      it("removes every object", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("ops_delete_all"))
          use _ <- result.try(operations.set(strings, "a", "1"))
          use _ <- result.try(operations.set(strings, "b", "2"))

          // Act
          use _ <- result.try(operations.delete_all_objects(strings))
          operations.size(strings)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(0))
        |> or_fail_with("Should leave an empty table")
      }),
    ]),
    group("match", [
      it("returns the bound variables of each matching object", fn() {
        // Arrange
        let config_value =
          config.new("advanced_match")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let pattern =
          dynamic.array([
            atom.to_dynamic(atom.create("$1")),
            atom.to_dynamic(atom.create("$2")),
          ])
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "key1", "value1"))
          use _ <- result.try(operations.set(strings, "key2", "value2"))

          // Act
          operations.match(strings, pattern)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Ok([
            dynamic.list([dynamic.string("key1"), dynamic.string("value1")]),
            dynamic.list([dynamic.string("key2"), dynamic.string("value2")]),
          ]),
        )
        |> or_fail_with("Should return the key and value of each object")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_match"))

          // Act
          operations.match(
            deleted,
            dynamic.array([dynamic.string("$1"), dynamic.string("$2")]),
          )
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("match on a deleted table should return TableNotFound")
      }),
    ]),
    group("match_object", [
      it("returns each matching object", fn() {
        // Arrange
        let config_value =
          config.new("advanced_match_object")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let pattern =
          dynamic.array([
            atom.to_dynamic(atom.create("_")),
            dynamic.string("value2"),
          ])
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "key1", "value1"))
          use _ <- result.try(operations.set(strings, "key2", "value2"))

          // Act
          operations.match_object(strings, pattern)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Ok([dynamic.array([dynamic.string("key2"), dynamic.string("value2")])]),
        )
        |> or_fail_with("Should return only the object with value2")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_match_object"))

          // Act
          operations.match_object(
            deleted,
            dynamic.array([dynamic.string("$1"), dynamic.string("$2")]),
          )
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "match_object on a deleted table should return TableNotFound",
        )
      }),
    ]),
    group("select", [
      it("returns the result expression of each matching object", fn() {
        // Arrange
        let config_value =
          config.new("advanced_select")
          |> config.key_string()
          |> config.value_string()
          |> config.table_type(config.table_type_ordered_set())
        let match_spec =
          dynamic.list([
            dynamic.array([
              dynamic.array([
                atom.to_dynamic(atom.create("$1")),
                atom.to_dynamic(atom.create("$2")),
              ]),
              dynamic.list([]),
              dynamic.list([atom.to_dynamic(atom.create("$2"))]),
            ]),
          ])
        let result = {
          use strings <- result.try(config.create(config_value))
          use _ <- result.try(operations.set(strings, "key1", "value1"))
          use _ <- result.try(operations.set(strings, "key2", "value2"))

          // Act
          operations.select(strings, match_spec)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([dynamic.string("value1"), dynamic.string("value2")]))
        |> or_fail_with("Should return the value of each object")
      }),
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_select"))

          // Act
          operations.select(deleted, dynamic.list([]))
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with("select on a deleted table should return TableNotFound")
      }),
    ]),
    group("save_to_file", [
      it("returns TableNotFound for a deleted table", fn() {
        // Arrange
        let result = {
          use deleted <- result.try(deleted_string_table("deleted_save"))

          // Act
          operations.save_to_file(deleted, "/tmp/dream_ets_deleted_table.ets")
        }

        // Assert
        result
        |> should
        |> be_equal(Error(TableNotFound))
        |> or_fail_with(
          "save_to_file on a deleted table should return TableNotFound",
        )
      }),
      it("returns OperationFailed when the directory does not exist", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("errors_save_dir"))

          // Act
          operations.save_to_file(strings, "/nonexistent_dream_ets/table.ets")
        }

        // Assert
        result
        |> should
        |> be_equal(
          Error(OperationFailed(
            "{file_error,\"/nonexistent_dream_ets/table.ets\",enoent}",
          )),
        )
        |> or_fail_with("Should report the missing directory")
      }),
      it("returns OperationFailed for a private table of another process", fn() {
        // Arrange
        let config_value =
          config.new("errors_save_private")
          |> config.key_string()
          |> config.value_string()
          |> config.access(config.access_private())
        let result = {
          use private <- result.try(
            config.create(config_value)
            |> result.replace_error("create failed"),
          )

          // Act
          other_process.run(fn() {
            operations.save_to_file(private, "build/errors_save_private.ets")
          })
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error(OperationFailed("badtab"))))
        |> or_fail_with("Should report that the table cannot be read")
      }),
      it("returns Ok when the file is written", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("persist_save"))
          use _ <- result.try(operations.set(strings, "key1", "value1"))

          // Act
          operations.save_to_file(strings, "build/persist_save.ets")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should save the table")
      }),
      it("keeps the data in the table", fn() {
        // Arrange
        let result = {
          use strings <- result.try(helpers.new_string_table("persist_keep"))
          use _ <- result.try(operations.set(strings, "important", "data"))

          // Act
          use _ <- result.try(operations.save_to_file(
            strings,
            "build/persist_keep.ets",
          ))
          operations.get(strings, "important")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("data")))
        |> or_fail_with("Should keep the data after the save")
      }),
    ]),
    group("load_from_file", [
      it("returns OperationFailed when the file does not exist", fn() {
        // Arrange
        let filename = "/nonexistent_dream_ets/table.ets"

        // Act
        let result = operations.load_from_file(filename)

        // Assert
        result
        |> should
        |> be_equal(
          Error(OperationFailed(
            "{read_error,{file_error,\"/nonexistent_dream_ets/table.ets\",enoent}}",
          )),
        )
        |> or_fail_with("Should report the missing file")
      }),
      it("returns OperationFailed when the table name is in use", fn() {
        // Arrange
        let filename = "build/errors_load_in_use.ets"
        let result = {
          use strings <- result.try(helpers.new_string_table(
            "errors_load_in_use",
          ))
          use _ <- result.try(operations.save_to_file(strings, filename))

          // Act
          operations.load_from_file(filename)
          |> result.replace(Nil)
        }

        // Assert
        result
        |> should
        |> be_equal(Error(OperationFailed("cannot_create_table")))
        |> or_fail_with("Should report that the table already exists")
      }),
      it("restores the saved data under the table name", fn() {
        // Arrange
        let filename = "build/persist_load.ets"
        let result = {
          use strings <- result.try(helpers.new_string_table("persist_load"))
          use _ <- result.try(operations.set(strings, "loaded", "value"))
          use _ <- result.try(operations.save_to_file(strings, filename))
          use _ <- result.try(operations.delete_table(strings))

          // Act
          use _loaded <- result.try(operations.load_from_file(filename))

          // A named table is found by its name, so the first handle reads the
          // loaded table
          operations.get(strings, "loaded")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value")))
        |> or_fail_with("Should restore the saved value")
      }),
    ]),
    group("refused operations", [
      it(
        "set returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_set")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.set(protected, "key", "value") })
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
        "get returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_get")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.get(private, "key") })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "delete returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_delete")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.delete(protected, "key") })
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
        "member returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_member")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.member(private, "key") })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "delete_table returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_delete_table")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.delete_table(protected) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused delete")
        },
      ),
      it(
        "size returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_size")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.size(private) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "keys returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_keys")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.keys(private) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "values returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_values")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.values(private) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "to_list returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_to_list")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.to_list(private) })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "insert_new returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_insert_new")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() {
              operations.insert_new(protected, "key", "value")
            })
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
        "take returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_take")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.take(protected, "key") })
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
        "update_element returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_update_element")
              |> result.replace_error("create failed"),
            )
            use _ <- result.try(
              operations.set(protected, "key", "old")
              |> result.replace_error("set failed"),
            )

            // Act
            other_process.run(fn() {
              operations.update_element(
                protected,
                "key",
                2,
                dynamic.string("new"),
              )
            })
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
        "delete_all_objects returns OperationFailed for a protected table of another process",
        fn() {
          // Arrange
          let result = {
            use protected <- result.try(
              protected_string_table("refused_delete_all")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() { operations.delete_all_objects(protected) })
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
        "match returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_match")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() {
              operations.match(
                private,
                dynamic.array([
                  atom.to_dynamic(atom.create("$1")),
                  atom.to_dynamic(atom.create("$2")),
                ]),
              )
            })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "match_object returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_match_object")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() {
              operations.match_object(
                private,
                dynamic.array([
                  atom.to_dynamic(atom.create("$1")),
                  atom.to_dynamic(atom.create("$2")),
                ]),
              )
            })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
      it(
        "select returns OperationFailed for a private table of another process",
        fn() {
          // Arrange
          let result = {
            use private <- result.try(
              private_string_table("refused_select")
              |> result.replace_error("create failed"),
            )

            // Act
            other_process.run(fn() {
              operations.select(private, dynamic.list([]))
            })
          }

          // Assert
          result
          |> should
          |> be_equal(
            Ok(Error(OperationFailed("ETS refused the operation: badarg"))),
          )
          |> or_fail_with("Should return OperationFailed for a refused read")
        },
      ),
    ]),
  ])
}
