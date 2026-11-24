//// Tests for the snippets that the doc comments in `src/` show.
//// Each test checks the exact result of one snippet function.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import fixtures/bag_table
import fixtures/ets_info.{table_info}
import gleam/dynamic
import gleam/option
import gleam/result
import snippets/doc_config
import snippets/doc_encoders
import snippets/doc_helpers
import snippets/doc_operations
import snippets/doc_table

pub fn tests() -> TestSuite {
  describe("doc snippets", [
    group("encoders", [
      it("create_with_encoders stores in both tables", fn() {
        // Act
        let result = doc_encoders.create_with_encoders()

        // Assert
        result
        |> should
        |> be_equal(Ok(#(option.Some("hello"), option.Some(10))))
        |> or_fail_with("Should read both values")
      }),
      it("store_user returns the stored user", fn() {
        // Act
        let result = doc_encoders.store_user()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(doc_encoders.User("Ada", 36))))
        |> or_fail_with("Should read the user")
      }),
      it("store_point returns the stored point", fn() {
        // Act
        let result = doc_encoders.store_point()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(doc_encoders.Point(0, 0))))
        |> or_fail_with("Should read the point")
      }),
      it("string_table returns the stored String", fn() {
        // Act
        let result = doc_encoders.string_table()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Alice")))
        |> or_fail_with("Should read the String")
      }),
      it("int_table returns the stored Int", fn() {
        // Act
        let result = doc_encoders.int_table()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(42)))
        |> or_fail_with("Should read the Int")
      }),
      it("bool_table returns the stored Bool", fn() {
        // Act
        let result = doc_encoders.bool_table()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(True)))
        |> or_fail_with("Should read the Bool")
      }),
      it("float_table returns the stored Float", fn() {
        // Act
        let result = doc_encoders.float_table()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(9.99)))
        |> or_fail_with("Should read the Float")
      }),
    ]),
    group("table", [
      it("same_table_after_load returns True", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table("doc_table_same_ref"))

          // Act
          doc_table.same_table_after_load(cache, "build/doc_table_same_ref.ets")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(True))
        |> or_fail_with("Should find the same reference after the load")
      }),
      it("cache_name returns the table name", fn() {
        // Act
        let result = doc_table.cache_name()

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_table_named"))
        |> or_fail_with("Should return the name of the table")
      }),
      it("stored_key encodes the key as a String", fn() {
        // Arrange
        let result = {
          use cache <- result.map(helpers.new_string_table("doc_table_key_enc"))

          // Act
          doc_table.stored_key(cache)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(dynamic.string("user:123")))
        |> or_fail_with("Should encode the key as a dynamic String")
      }),
      it("read_key decodes the key", fn() {
        // Arrange
        let result = {
          use cache <- result.map(helpers.new_string_table("doc_table_key_dec"))

          // Act
          doc_table.read_key(cache)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("user:123")))
        |> or_fail_with("Should decode the key")
      }),
      it("stored_value encodes the value as a String", fn() {
        // Arrange
        let result = {
          use cache <- result.map(helpers.new_string_table(
            "doc_table_value_enc",
          ))

          // Act
          doc_table.stored_value(cache)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(dynamic.string("Alice")))
        |> or_fail_with("Should encode the value as a dynamic String")
      }),
      it("read_value decodes the value", fn() {
        // Arrange
        let result = {
          use cache <- result.map(helpers.new_string_table(
            "doc_table_value_dec",
          ))

          // Act
          doc_table.read_value(cache)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("Alice")))
        |> or_fail_with("Should decode the value")
      }),
      it("typed_view reads the loaded table", fn() {
        // Arrange
        let filename = "build/doc_table_loaded.ets"
        let result = {
          use users <- result.try(helpers.new_string_table("doc_table_loaded"))
          use _ <- result.try(operations.set(users, "user:123", "Alice"))
          use _ <- result.try(operations.save_to_file(users, filename))
          use _ <- result.try(operations.delete_table(users))

          // Act
          doc_table.typed_view(filename)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Alice")))
        |> or_fail_with("Should read Alice from the loaded table")
      }),
      it("create_tables returns both table names", fn() {
        // Act
        let result = doc_table.create_tables()

        // Assert
        result
        |> should
        |> be_equal(Ok(#("doc_table_cache", "doc_table_counts")))
        |> or_fail_with("Should name both tables")
      }),
      it("typed_operations returns the stored value", fn() {
        // Act
        let result = doc_table.typed_operations()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Alice")))
        |> or_fail_with("Should read the value")
      }),
    ]),
    group("helpers", [
      it("quick_start counts one view and names the cache", fn() {
        // Act
        let result = doc_helpers.quick_start()

        // Assert
        result
        |> should
        |> be_equal(Ok(#(1, "doc_helpers_user_cache")))
        |> or_fail_with("Should count one view")
      }),
      it("count_page_views counts each page", fn() {
        // Act
        let result = doc_helpers.count_page_views()

        // Assert
        result
        |> should
        |> be_equal(Ok([1, 2, 1]))
        |> or_fail_with("Should count each page")
      }),
      it("counter_with_builder names the counter", fn() {
        // Act
        let result = doc_helpers.counter_with_builder()

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_helpers_counter_builder"))
        |> or_fail_with("Should name the counter")
      }),
      it("cache_user returns the cached user", fn() {
        // Act
        let result = doc_helpers.cache_user()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Alice")))
        |> or_fail_with("Should read the user")
      }),
      it("string_table_with_builder names the cache", fn() {
        // Act
        let result = doc_helpers.string_table_with_builder()

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_helpers_cache_builder"))
        |> or_fail_with("Should name the cache")
      }),
      it("count_requests counts to 3", fn() {
        // Act
        let result = doc_helpers.count_requests()

        // Assert
        result
        |> should
        |> be_equal(Ok([1, 2, 3]))
        |> or_fail_with("Should count to 3")
      }),
      it("add_points adds and subtracts", fn() {
        // Act
        let result = doc_helpers.add_points()

        // Assert
        result
        |> should
        |> be_equal(Ok([10, 20, 15]))
        |> or_fail_with("Should add and subtract")
      }),
      it("use_widgets decrements twice", fn() {
        // Act
        let result = doc_helpers.use_widgets()

        // Assert
        result
        |> should
        |> be_equal(Ok([99, 98]))
        |> or_fail_with("Should decrement twice")
      }),
      it("deduct_api_calls deducts two batches", fn() {
        // Act
        let result = doc_helpers.deduct_api_calls()

        // Assert
        result
        |> should
        |> be_equal(Ok([900, 850]))
        |> or_fail_with("Should deduct both batches")
      }),
    ]),
    group("config", [
      it("tag_bag creates a bag table", fn() {
        // Act
        let result = doc_config.tag_bag() |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("bag"))
        |> or_fail_with("Should create a bag table")
      }),
      it("event_log creates a duplicate_bag table", fn() {
        // Act
        let result = doc_config.event_log() |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("duplicate_bag"))
        |> or_fail_with("Should create a duplicate_bag table")
      }),
      it("private_scratch creates a private table", fn() {
        // Act
        let result =
          doc_config.private_scratch()
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("private"))
        |> or_fail_with("Should create a private table")
      }),
      it("quick_start names the three tables", fn() {
        // Act
        let result = doc_config.quick_start()

        // Assert
        result
        |> should
        |> be_equal(
          Ok(["doc_config_users", "doc_config_page_views", "doc_config_cache"]),
        )
        |> or_fail_with("Should name the three tables")
      }),
      it("set_table creates a set table", fn() {
        // Act
        let result = doc_config.set_table() |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("set"))
        |> or_fail_with("Should create a set table")
      }),
      it("leaderboard creates an ordered_set table", fn() {
        // Act
        let result =
          doc_config.leaderboard() |> result.map(table_info(_, "type"))

        // Assert
        result
        |> should
        |> be_equal(Ok("ordered_set"))
        |> or_fail_with("Should create an ordered_set table")
      }),
      it("public_sessions creates a public table", fn() {
        // Act
        let result =
          doc_config.public_sessions()
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("public"))
        |> or_fail_with("Should create a public table")
      }),
      it("protected_settings creates a protected table", fn() {
        // Act
        let result =
          doc_config.protected_settings()
          |> result.map(table_info(_, "protection"))

        // Assert
        result
        |> should
        |> be_equal(Ok("protected"))
        |> or_fail_with("Should create a protected table")
      }),
      it("new_users names the table", fn() {
        // Act
        let result = doc_config.new_users() |> result.map(table.table_name)

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_config_new_users"))
        |> or_fail_with("Should name the table")
      }),
      it("read_heavy_cache turns read concurrency on", fn() {
        // Act
        let result =
          doc_config.read_heavy_cache()
          |> result.map(table_info(_, "read_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn read concurrency on")
      }),
      it("write_heavy_metrics turns write concurrency on", fn() {
        // Act
        let result =
          doc_config.write_heavy_metrics()
          |> result.map(table_info(_, "write_concurrency"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn write concurrency on")
      }),
      it("compressed_documents turns compression on", fn() {
        // Act
        let result =
          doc_config.compressed_documents()
          |> result.map(table_info(_, "compressed"))

        // Assert
        result
        |> should
        |> be_equal(Ok("true"))
        |> or_fail_with("Should turn compression on")
      }),
      it("builtin_key_encoder names the table", fn() {
        // Act
        let result =
          doc_config.builtin_key_encoder() |> result.map(table.table_name)

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_config_key_builtin"))
        |> or_fail_with("Should name the table")
      }),
      it("custom_key_encoder returns the value for the UserId key", fn() {
        // Act
        let result = doc_config.custom_key_encoder()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Ada")))
        |> or_fail_with("Should read the value")
      }),
      it("builtin_value_encoder names the table", fn() {
        // Act
        let result =
          doc_config.builtin_value_encoder() |> result.map(table.table_name)

        // Assert
        result
        |> should
        |> be_equal(Ok("doc_config_value_builtin"))
        |> or_fail_with("Should name the table")
      }),
      it("custom_value_encoder returns the stored user", fn() {
        // Act
        let result = doc_config.custom_value_encoder()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some(doc_config.User("Ada", 36))))
        |> or_fail_with("Should read the user")
      }),
      it("counter_table counts one view", fn() {
        // Act
        let result = doc_config.counter_table()

        // Assert
        result
        |> should
        |> be_equal(Ok(1))
        |> or_fail_with("Should count one view")
      }),
      it("create_tables names both tables", fn() {
        // Act
        let result = doc_config.create_tables()

        // Assert
        result
        |> should
        |> be_equal(Ok(["doc_config_create_users", "doc_config_create_cache"]))
        |> or_fail_with("Should name both tables")
      }),
    ]),
    group("operations", [
      it("crud leaves no value after the delete", fn() {
        // Act
        let result = doc_operations.crud()

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should delete the value")
      }),
      it("set_twice stores the second value", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_set_twice"))

          // Act
          use _ <- result.try(doc_operations.set_twice(users))
          operations.get(users, "user:123")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Bob")))
        |> or_fail_with("Should store Bob")
      }),
      it("describe_user describes a found user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_describe_found",
          ))
          use _ <- result.try(operations.set(users, "user:123", "Alice"))

          // Act
          Ok(doc_operations.describe_user(users, "user:123"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Found: Alice"))
        |> or_fail_with("Should find Alice")
      }),
      it("describe_user describes a missing user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_describe_missing",
          ))

          // Act
          Ok(doc_operations.describe_user(users, "user:123"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("User not found"))
        |> or_fail_with("Should not find the user")
      }),
      it("describe_user describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_describe_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.describe_user(users, "user:123"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Lookup failed: TableNotFound"))
        |> or_fail_with("Should report the deleted table")
      }),
      it("remove_user deletes the user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_remove"))
          use _ <- result.try(operations.set(users, "user:123", "Alice"))

          // Act
          use _ <- result.try(doc_operations.remove_user(users))
          operations.get(users, "user:123")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.None))
        |> or_fail_with("Should delete the user")
      }),
      it("drop_table deletes the table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_drop"))

          // Act
          doc_operations.drop_table(users)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should delete the table")
      }),
      it("describe_size counts the entries", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_size"))
          use _ <- result.try(operations.set(users, "a", "1"))
          use _ <- result.try(operations.set(users, "b", "2"))

          // Act
          Ok(doc_operations.describe_size(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Table has 2 entries"))
        |> or_fail_with("Should count two entries")
      }),
      it("describe_size describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_size_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.describe_size(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Size failed: TableNotFound"))
        |> or_fail_with("Should report the deleted table")
      }),
      it("list_keys labels each key", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_keys"))
          use _ <- result.try(operations.set(users, "a", "1"))

          // Act
          Ok(doc_operations.list_keys(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["Key: a"]))
        |> or_fail_with("Should label the key")
      }),
      it("list_keys describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_keys_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.list_keys(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["Keys failed: TableNotFound"]))
        |> or_fail_with("Should report the deleted table")
      }),
      it("count_characters adds the value lengths", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_values"))
          use _ <- result.try(operations.set(users, "a", "Ada"))
          use _ <- result.try(operations.set(users, "g", "Grace"))

          // Act
          Ok(doc_operations.count_characters(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(8))
        |> or_fail_with("Should count 8 characters")
      }),
      it("count_characters returns 0 for a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_values_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.count_characters(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(0))
        |> or_fail_with("Should count no characters")
      }),
      it("list_pairs shows each pair", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_pairs"))
          use _ <- result.try(operations.set(users, "a", "1"))

          // Act
          Ok(doc_operations.list_pairs(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["a => 1"]))
        |> or_fail_with("Should show the pair")
      }),
      it("list_pairs describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_pairs_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.list_pairs(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["List failed: TableNotFound"]))
        |> or_fail_with("Should report the deleted table")
      }),
      it("create_user creates a new user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_create"))

          // Act
          Ok(doc_operations.create_user(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("User created"))
        |> or_fail_with("Should create the user")
      }),
      it("create_user finds an existing user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_create_existing",
          ))
          use _ <- result.try(operations.set(users, "user:123", "Alice"))

          // Act
          Ok(doc_operations.create_user(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("User already exists"))
        |> or_fail_with("Should find the user")
      }),
      it("create_user describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_create_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.create_user(users))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Insert failed: TableNotFound"))
        |> or_fail_with("Should report the deleted table")
      }),
      it("register_user registers a new user", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_register"))

          // Act
          Ok(doc_operations.register_user(users, "user:1", "Ada"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("User registered")))
        |> or_fail_with("Should register the user")
      }),
      it("register_user rejects a taken user ID", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_register_taken",
          ))
          use _ <- result.try(operations.set(users, "user:1", "Ada"))

          // Act
          Ok(doc_operations.register_user(users, "user:1", "Grace"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("User ID already taken")))
        |> or_fail_with("Should reject the taken ID")
      }),
      it("register_user describes a deleted table", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_register_deleted",
          ))
          use _ <- result.try(operations.delete_table(users))

          // Act
          Ok(doc_operations.register_user(users, "user:1", "Ada"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Database error: TableNotFound")))
        |> or_fail_with("Should report the deleted table")
      }),
      it("acquire_lock gives a free lock", fn() {
        // Arrange
        let result = {
          use locks <- result.try(helpers.new_string_table("doc_ops_lock"))

          // Act
          Ok(doc_operations.acquire_lock(locks, "file:1", "worker_a"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("Lock acquired")))
        |> or_fail_with("Should give the lock")
      }),
      it("acquire_lock rejects a held lock", fn() {
        // Arrange
        let result = {
          use locks <- result.try(helpers.new_string_table("doc_ops_lock_held"))
          use _ <- result.try(operations.set(locks, "file:1", "worker_a"))

          // Act
          Ok(doc_operations.acquire_lock(locks, "file:1", "worker_b"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Resource locked by another process")))
        |> or_fail_with("Should reject the second owner")
      }),
      it("acquire_lock describes a deleted table", fn() {
        // Arrange
        let result = {
          use locks <- result.try(helpers.new_string_table(
            "doc_ops_lock_deleted",
          ))
          use _ <- result.try(operations.delete_table(locks))

          // Act
          Ok(doc_operations.acquire_lock(locks, "file:1", "worker_a"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Lock system error: TableNotFound")))
        |> or_fail_with("Should report the deleted table")
      }),
      it("take_job processes the job", fn() {
        // Arrange
        let result = {
          use jobs <- result.try(helpers.new_string_table("doc_ops_take_job"))
          use _ <- result.try(operations.set(jobs, "job:123", "send_email"))

          // Act
          Ok(doc_operations.take_job(jobs))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Processing send_email"))
        |> or_fail_with("Should process the job")
      }),
      it("take_job finds no job", fn() {
        // Arrange
        let result = {
          use jobs <- result.try(helpers.new_string_table(
            "doc_ops_take_job_missing",
          ))

          // Act
          Ok(doc_operations.take_job(jobs))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Job not found"))
        |> or_fail_with("Should find no job")
      }),
      it("take_job describes a deleted table", fn() {
        // Arrange
        let result = {
          use jobs <- result.try(helpers.new_string_table(
            "doc_ops_take_job_deleted",
          ))
          use _ <- result.try(operations.delete_table(jobs))

          // Act
          Ok(doc_operations.take_job(jobs))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Take failed: TableNotFound"))
        |> or_fail_with("Should report the deleted table")
      }),
      it("claim_next_job claims the job", fn() {
        // Arrange
        let result = {
          use queue <- result.try(helpers.new_string_table("doc_ops_claim"))
          use _ <- result.try(operations.set(queue, "next_job", "send_email"))

          // Act
          Ok(doc_operations.claim_next_job(queue, "worker_1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("worker_1 claimed send_email"))
        |> or_fail_with("Should claim the job")
      }),
      it("claim_next_job finds no job", fn() {
        // Arrange
        let result = {
          use queue <- result.try(helpers.new_string_table(
            "doc_ops_claim_empty",
          ))

          // Act
          Ok(doc_operations.claim_next_job(queue, "worker_1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("worker_1 found no job"))
        |> or_fail_with("Should find no job")
      }),
      it("claim_next_job describes a deleted table", fn() {
        // Arrange
        let result = {
          use queue <- result.try(helpers.new_string_table(
            "doc_ops_claim_deleted",
          ))
          use _ <- result.try(operations.delete_table(queue))

          // Act
          Ok(doc_operations.claim_next_job(queue, "worker_1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok("Queue error: TableNotFound"))
        |> or_fail_with("Should report the deleted table")
      }),
      it("evict_entry returns the old value", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table("doc_ops_evict"))
          use _ <- result.try(operations.set(cache, "key", "old"))

          // Act
          Ok(doc_operations.evict_entry(cache, "key"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("old")))
        |> or_fail_with("Should return the old value")
      }),
      it("evict_entry rejects a missing key", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table(
            "doc_ops_evict_missing",
          ))

          // Act
          Ok(doc_operations.evict_entry(cache, "key"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Key not in cache")))
        |> or_fail_with("Should reject the missing key")
      }),
      it("evict_entry describes a deleted table", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table(
            "doc_ops_evict_deleted",
          ))
          use _ <- result.try(operations.delete_table(cache))

          // Act
          Ok(doc_operations.evict_entry(cache, "key"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Cache error: TableNotFound")))
        |> or_fail_with("Should report the deleted table")
      }),
      it("use_token returns the token data", fn() {
        // Arrange
        let result = {
          use tokens <- result.try(helpers.new_string_table("doc_ops_token"))
          use _ <- result.try(operations.set(tokens, "t1", "reset:ada"))

          // Act
          Ok(doc_operations.use_token(tokens, "t1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Ok("reset:ada")))
        |> or_fail_with("Should return the token data")
      }),
      it("use_token rejects a used token", fn() {
        // Arrange
        let result = {
          use tokens <- result.try(helpers.new_string_table(
            "doc_ops_token_used",
          ))

          // Act
          Ok(doc_operations.use_token(tokens, "t1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Invalid or already used token")))
        |> or_fail_with("Should reject the token")
      }),
      it("use_token describes a deleted table", fn() {
        // Arrange
        let result = {
          use tokens <- result.try(helpers.new_string_table(
            "doc_ops_token_deleted",
          ))
          use _ <- result.try(operations.delete_table(tokens))

          // Act
          Ok(doc_operations.use_token(tokens, "t1"))
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(Error("Token system error: TableNotFound")))
        |> or_fail_with("Should report the deleted table")
      }),
      it("get_then_delete returns the value", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table("doc_ops_get_delete"))
          use _ <- result.try(operations.set(cache, "key", "value"))

          // Act
          doc_operations.get_then_delete(cache, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value")))
        |> or_fail_with("Should return the value")
      }),
      it("take_value returns the value", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table("doc_ops_take_value"))
          use _ <- result.try(operations.set(cache, "key", "value"))

          // Act
          doc_operations.take_value(cache, "key")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("value")))
        |> or_fail_with("Should return the value")
      }),
      it("replace_value stores the new value", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_replace"))

          // Act
          doc_operations.replace_value(users)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Bob")))
        |> or_fail_with("Should store Bob")
      }),
      it("clear_cache leaves an empty table", fn() {
        // Arrange
        let result = {
          use cache <- result.try(helpers.new_string_table("doc_ops_clear"))

          // Act
          doc_operations.clear_cache(cache)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(0))
        |> or_fail_with("Should leave no objects")
      }),
      it("match_pairs returns the key and value of each object", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_match"))
          use _ <- result.try(operations.set(users, "user:1", "Ada"))

          // Act
          doc_operations.match_pairs(users)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Ok([dynamic.list([dynamic.string("user:1"), dynamic.string("Ada")])]),
        )
        |> or_fail_with("Should bind the key and the value")
      }),
      it("match_alice returns only the objects with Alice", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table(
            "doc_ops_match_object",
          ))
          use _ <- result.try(operations.set(users, "user:1", "Alice"))
          use _ <- result.try(operations.set(users, "user:2", "Bob"))

          // Act
          doc_operations.match_alice(users)
        }

        // Assert
        result
        |> should
        |> be_equal(
          Ok([
            dynamic.array([dynamic.string("user:1"), dynamic.string("Alice")]),
          ]),
        )
        |> or_fail_with("Should return only Alice")
      }),
      it("select_values returns each value", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_select"))
          use _ <- result.try(operations.set(users, "user:1", "Ada"))

          // Act
          doc_operations.select_values(users)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok([dynamic.string("Ada")]))
        |> or_fail_with("Should return the value")
      }),
      it("save_and_load restores the saved value", fn() {
        // Arrange
        let result = {
          use users <- result.try(helpers.new_string_table("doc_ops_save_load"))

          // Act
          doc_operations.save_and_load(users, "build/doc_ops_save_load.ets")
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(option.Some("Alice")))
        |> or_fail_with("Should restore Alice")
      }),
      it("tags_of_post returns both tags", fn() {
        // Arrange
        let result = {
          use tags <- result.try(bag_table.bag_string_table("doc_ops_tags"))

          // Act
          doc_operations.tags_of_post(tags)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["gleam", "erlang"]))
        |> or_fail_with("Should return both tags of the post")
      }),
      it("remove_tags returns the tags that it removed", fn() {
        // Arrange
        let result = {
          use tags <- result.try(bag_table.bag_string_table("doc_ops_remove"))
          use _ <- result.try(doc_operations.tags_of_post(tags))

          // Act
          doc_operations.remove_tags(tags)
        }

        // Assert
        result
        |> should
        |> be_equal(Ok(["gleam", "erlang"]))
        |> or_fail_with("Should return both tags")
      }),
    ]),
  ])
}
