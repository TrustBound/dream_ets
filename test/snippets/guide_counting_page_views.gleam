//// Guide: Counting events, step 1 and step 2
////
//// Counts page views in one process, and reads the counts for a report.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub fn count_three_views() -> Result(Int, EtsError) {
  use views <- result.try(helpers.new_counter("page_views_by_path"))
  use _ <- result.try(helpers.increment(views, "/"))
  use _ <- result.try(helpers.increment(views, "/about"))
  helpers.increment(views, "/")
}

/// The count of one path. A path with no views has no key, so it is 0.
pub fn views_of(
  views: Table(String, Int),
  path: String,
) -> Result(Int, EtsError) {
  use count <- result.map(operations.get(views, path))
  option.unwrap(count, 0)
}

/// Every path with its count, sorted by path.
pub fn report(
  views: Table(String, Int),
) -> Result(List(#(String, Int)), EtsError) {
  use pairs <- result.map(operations.to_list(views))
  list.sort(pairs, fn(left, right) { string.compare(left.0, right.0) })
}
