//// Guide: Counting events, step 5
////
//// A daily quota of API credits. A request spends credits first and checks
//// the new total afterwards, so many processes cannot spend more than the
//// quota together.

import dream_ets/helpers
import dream_ets/table.{type EtsError, type Table}
import gleam/int
import gleam/result

pub const daily_credits = 100

pub type SpendError {
  /// The user has fewer credits left than the request costs.
  NotEnoughCredits(left: Int)
  StorageFailed(EtsError)
}

/// Spends `cost` credits and returns the credits that are left.
pub fn spend(
  spent: Table(String, Int),
  user_id: String,
  cost: Int,
) -> Result(Int, SpendError) {
  // Spend first: the new total includes every request that came before
  use total <- result.try(
    helpers.increment_by(spent, user_id, cost)
    |> result.map_error(StorageFailed),
  )
  case total > daily_credits {
    False -> Ok(daily_credits - total)
    True -> give_back(spent, user_id, cost, total)
  }
}

fn give_back(
  spent: Table(String, Int),
  user_id: String,
  cost: Int,
  total: Int,
) -> Result(Int, SpendError) {
  // Put the credits back, then report what was left before this request.
  // Other refused requests can still hold credits for a moment, so the
  // number can be below zero. Report 0 then.
  use _ <- result.try(
    helpers.decrement_by(spent, user_id, cost)
    |> result.map_error(StorageFailed),
  )
  Error(NotEnoughCredits(left: int.max(0, daily_credits - total + cost)))
}

/// Gives one credit back, for example for a request that failed.
pub fn refund_one(
  spent: Table(String, Int),
  user_id: String,
) -> Result(Int, EtsError) {
  helpers.decrement(spent, user_id)
}
