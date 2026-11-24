//// Doc comments: dream_ets/operations
////
//// The examples in the doc comments of the operations module.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/erlang/atom
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn crud() -> Result(option.Option(String), table.EtsError) {
  // Create table
  use cache <- result.try(helpers.new_string_table("doc_operations_crud"))

  // Basic CRUD
  use _ <- result.try(operations.set(cache, "user:123", "Alice"))
  use _ <- result.try(operations.get(cache, "user:123"))
  use _ <- result.try(operations.delete(cache, "user:123"))
  operations.get(cache, "user:123")
}

pub fn set_twice(
  users: table.Table(String, String),
) -> Result(Nil, table.EtsError) {
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  // In a set table, this replaces the existing value
  operations.set(users, "user:123", "Bob")
}

pub fn describe_user(
  users: table.Table(String, String),
  key: String,
) -> String {
  case operations.get(users, key) {
    Ok(option.Some(name)) -> "Found: " <> name
    Ok(option.None) -> "User not found"
    Error(error) -> "Lookup failed: " <> string.inspect(error)
  }
}

pub fn remove_user(
  users: table.Table(String, String),
) -> Result(Nil, table.EtsError) {
  operations.delete(users, "user:123")
}

pub fn drop_table(
  users: table.Table(String, String),
) -> Result(Nil, table.EtsError) {
  operations.delete_table(users)
}

pub fn describe_size(users: table.Table(String, String)) -> String {
  case operations.size(users) {
    Ok(count) -> "Table has " <> int.to_string(count) <> " entries"
    Error(error) -> "Size failed: " <> string.inspect(error)
  }
}

pub fn list_keys(users: table.Table(String, String)) -> List(String) {
  case operations.keys(users) {
    Ok(all_keys) -> list.map(all_keys, fn(key) { "Key: " <> key })
    Error(error) -> ["Keys failed: " <> string.inspect(error)]
  }
}

pub fn count_characters(users: table.Table(String, String)) -> Int {
  case operations.values(users) {
    Ok(all_values) ->
      list.fold(all_values, 0, fn(total, value) { total + string.length(value) })
    Error(_) -> 0
  }
}

pub fn list_pairs(users: table.Table(String, String)) -> List(String) {
  case operations.to_list(users) {
    Ok(pairs) -> list.map(pairs, fn(pair) { pair.0 <> " => " <> pair.1 })
    Error(error) -> ["List failed: " <> string.inspect(error)]
  }
}

pub fn create_user(users: table.Table(String, String)) -> String {
  case operations.insert_new(users, "user:123", "Alice") {
    Ok(True) -> "User created"
    Ok(False) -> "User already exists"
    Error(error) -> "Insert failed: " <> string.inspect(error)
  }
}

pub fn register_user(
  users: table.Table(String, String),
  user_id: String,
  name: String,
) -> Result(String, String) {
  case operations.insert_new(users, user_id, name) {
    Ok(True) -> Ok("User registered")
    Ok(False) -> Error("User ID already taken")
    Error(error) -> Error("Database error: " <> string.inspect(error))
  }
}

pub fn acquire_lock(
  locks: table.Table(String, String),
  resource_id: String,
  owner_id: String,
) -> Result(String, String) {
  case operations.insert_new(locks, resource_id, owner_id) {
    Ok(True) -> Ok("Lock acquired")
    Ok(False) -> Error("Resource locked by another process")
    Error(error) -> Error("Lock system error: " <> string.inspect(error))
  }
}

pub fn take_job(jobs: table.Table(String, String)) -> String {
  case operations.take(jobs, "job:123") {
    // The job is now removed from the queue
    Ok(option.Some(job)) -> "Processing " <> job
    Ok(option.None) -> "Job not found"
    Error(error) -> "Take failed: " <> string.inspect(error)
  }
}

pub fn claim_next_job(
  queue: table.Table(String, String),
  worker_id: String,
) -> String {
  case operations.take(queue, "next_job") {
    // This worker claimed the job atomically
    Ok(option.Some(job)) -> worker_id <> " claimed " <> job
    // No jobs available
    Ok(option.None) -> worker_id <> " found no job"
    Error(error) -> "Queue error: " <> string.inspect(error)
  }
}

pub fn evict_entry(
  cache: table.Table(String, String),
  key: String,
) -> Result(String, String) {
  case operations.take(cache, key) {
    Ok(option.Some(old_value)) -> Ok(old_value)
    Ok(option.None) -> Error("Key not in cache")
    Error(error) -> Error("Cache error: " <> string.inspect(error))
  }
}

pub fn use_token(
  tokens: table.Table(String, String),
  token_id: String,
) -> Result(String, String) {
  case operations.take(tokens, token_id) {
    // A token can be used only once
    Ok(option.Some(token_data)) -> Ok(token_data)
    Ok(option.None) -> Error("Invalid or already used token")
    Error(error) -> Error("Token system error: " <> string.inspect(error))
  }
}

// Race condition: another process can change the value between get and delete
pub fn get_then_delete(
  cache: table.Table(String, String),
  key: String,
) -> Result(option.Option(String), table.EtsError) {
  use value <- result.try(operations.get(cache, key))
  use _ <- result.try(operations.delete(cache, key))
  Ok(value)
}

// Atomic: get and delete in one operation
pub fn take_value(
  cache: table.Table(String, String),
  key: String,
) -> Result(option.Option(String), table.EtsError) {
  operations.take(cache, key)
}

pub fn replace_value(
  users: table.Table(String, String),
) -> Result(option.Option(String), table.EtsError) {
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  // Position 2 is the value in the {key, value} object
  use _ <- result.try(operations.update_element(
    users,
    "user:123",
    2,
    dynamic.string("Bob"),
  ))
  operations.get(users, "user:123")
}

pub fn clear_cache(
  cache: table.Table(String, String),
) -> Result(Int, table.EtsError) {
  use _ <- result.try(operations.set(cache, "a", "1"))
  use _ <- result.try(operations.delete_all_objects(cache))
  // The table still exists, and it is empty
  operations.size(cache)
}

pub fn match_pairs(
  users: table.Table(String, String),
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  // The pattern {'$1', '$2'} binds the key and the value of each object
  let pattern =
    dynamic.array([
      atom.to_dynamic(atom.create("$1")),
      atom.to_dynamic(atom.create("$2")),
    ])
  operations.match(users, pattern)
}

pub fn match_alice(
  users: table.Table(String, String),
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  // The pattern {'_', <<"Alice">>} matches every object with the value Alice
  let pattern =
    dynamic.array([atom.to_dynamic(atom.create("_")), dynamic.string("Alice")])
  operations.match_object(users, pattern)
}

pub fn select_values(
  users: table.Table(String, String),
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  // [{{'$1', '$2'}, [], ['$2']}] returns the value of each object
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
  operations.select(users, match_spec)
}

pub fn save_and_load(
  users: table.Table(String, String),
  filename: String,
) -> Result(option.Option(String), table.EtsError) {
  use _ <- result.try(operations.set(users, "user:123", "Alice"))
  use _ <- result.try(operations.save_to_file(users, filename))
  use _ <- result.try(operations.delete_table(users))
  use _ <- result.try(operations.load_from_file(filename))
  // The loaded table has the same name, so `users` finds it again
  operations.get(users, "user:123")
}

pub fn tags_of_post(
  tags: table.Table(String, String),
) -> Result(List(String), table.EtsError) {
  // `tags` is a bag table, so one key can have several values
  use _ <- result.try(operations.set(tags, "post-1", "gleam"))
  use _ <- result.try(operations.set(tags, "post-1", "erlang"))
  operations.get_all(tags, "post-1")
}

pub fn remove_tags(
  tags: table.Table(String, String),
) -> Result(List(String), table.EtsError) {
  // Read and remove every value of the key in one operation
  operations.take_all(tags, "post-1")
}
