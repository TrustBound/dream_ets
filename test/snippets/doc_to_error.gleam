//// Doc comment: table.to_error
////
//// Maps the error of a lookup to the shared error of the Dream packages.

import dream_errors
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn find_name(
  users: table.Table(String, String),
  user_id: String,
) -> Result(option.Option(String), dream_errors.Error(table.EtsError)) {
  operations.get(users, user_id)
  |> result.map_error(table.to_error)
}

pub fn find_name_in_deleted_table() -> Result(
  option.Option(String),
  dream_errors.Error(table.EtsError),
) {
  let assert Ok(users) = helpers.new_string_table("doc_to_error_users")
  let assert Ok(Nil) = operations.delete_table(users)
  find_name(users, "user:123")
}
