//// Guide: Locks and work queues, step 4
////
//// An outbox in a duplicate_bag table. Many messages wait under one user
//// key, and a sender takes them all at once.

import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/result

pub fn create_outbox(name: String) -> Result(Table(String, String), EtsError) {
  config.new(name)
  // One key can hold many values, also identical ones
  |> config.table_type(config.table_type_duplicate_bag())
  |> config.key_string()
  |> config.value_string()
  |> config.create()
}

/// Adds a message. In a bag table, `set` adds a value. It does not
/// replace the values that are there.
pub fn queue_message(
  outbox: Table(String, String),
  user_id: String,
  message: String,
) -> Result(Nil, EtsError) {
  operations.set(outbox, user_id, message)
}

/// Removes and returns every waiting message of the user, in one step.
pub fn take_messages(
  outbox: Table(String, String),
  user_id: String,
) -> Result(List(String), EtsError) {
  operations.take_all(outbox, user_id)
}

pub fn three_messages_for_ada() -> Result(List(String), EtsError) {
  use outbox <- result.try(create_outbox("user_outbox"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Welcome"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Your invoice"))
  use Nil <- result.try(queue_message(outbox, "user:ada", "Your invoice"))
  take_messages(outbox, "user:ada")
}
