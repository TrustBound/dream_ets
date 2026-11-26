//// Doc comment: table.to_error
////
//// Maps the error of a lookup to the shared error of the Dream packages.

import dream_errors.{type Error}
import dream_ets/helpers.{new_string_table}
import dream_ets/operations.{delete_table, get}
import dream_ets/table.{type EtsError, type Table, to_error}
import gleam/option.{type Option}
import gleam/result.{map_error}

pub fn find_name(
  users: Table(String, String),
  user_id: String,
) -> Result(Option(String), Error(EtsError)) {
  get(users, user_id)
  |> map_error(to_error)
}

pub fn find_name_in_deleted_table() -> Result(Option(String), Error(EtsError)) {
  let assert Ok(users) = new_string_table("doc_to_error_users")
  let assert Ok(Nil) = delete_table(users)
  find_name(users, "user:123")
}
