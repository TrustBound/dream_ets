//// Guide: Getting started, failure cases
////
//// Turns each result of a lookup into a message for a log.

import dream_ets/operations
import dream_ets/table.{
  type Table, DecodeError, InvalidKey, InvalidValue, OperationFailed,
  TableAlreadyExists, TableNotFound,
}
import gleam/option.{None, Some}

pub fn describe_lookup(names: Table(String, String), key: String) -> String {
  case operations.get(names, key) {
    Ok(Some(name)) -> "Found " <> name
    Ok(None) -> "No name for " <> key
    Error(TableNotFound) -> "The table is gone. Did its owner process stop?"
    Error(DecodeError(error)) ->
      "The stored value is not a " <> error.expected <> ": " <> error.found
    Error(OperationFailed(reason)) -> "ETS refused the lookup: " <> reason
    // `create` returns these three. A lookup never does.
    Error(TableAlreadyExists) | Error(InvalidKey) | Error(InvalidValue) ->
      "Unexpected error"
  }
}
