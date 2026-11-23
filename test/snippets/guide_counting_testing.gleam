//// Guide: Counting events, testing
////
//// Tests the counter process from step 4 and the quota from step 5 with
//// many processes at once.

import dream_ets/helpers
import dream_ets/operations
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/list
import gleam/option.{Some}
import gleam/result
import snippets/guide_counting_counter_process as counter
import snippets/guide_counting_quota as quota

pub fn tests() -> TestSuite {
  describe("counting from many processes", [
    it("counts every increment from ten processes", fn() {
      // Arrange
      let assert Ok(views) = counter.start("counter_test_ten_processes")
      let finished = process.new_subject()
      let workers = list.repeat(Nil, 10)

      // Act
      list.each(workers, fn(_) {
        process.spawn(fn() {
          let added =
            list.try_each(list.repeat(Nil, 100), fn(_) {
              counter.increment(views, "/")
            })
          process.send(finished, added)
        })
      })
      let assert Ok(_) =
        list.try_map(workers, fn(_) { process.receive_forever(finished) })

      // Assert
      counter.count(views, "/")
      |> should
      |> be_equal(Ok(1000))
      |> or_fail_with("Expected 10 times 100 increments")
    }),
    it("never spends more than the quota from ten processes", fn() {
      // Arrange
      let assert Ok(spent) = helpers.new_counter("quota_test_ten_processes")
      let finished = process.new_subject()
      let workers = list.repeat(Nil, 10)

      // Act: 10 processes try to spend 1 credit 20 times each
      list.each(workers, fn(_) {
        process.spawn(fn() {
          let accepted =
            list.count(list.repeat(Nil, 20), fn(_) {
              result.is_ok(quota.spend(spent, "user:1", 1))
            })
          process.send(finished, accepted)
        })
      })
      let accepted =
        list.fold(workers, 0, fn(total, _) {
          total + process.receive_forever(finished)
        })

      // Assert
      #(accepted, operations.get(spent, "user:1"))
      |> should
      |> be_equal(#(100, Ok(Some(100))))
      |> or_fail_with("Expected exactly 100 credits spent")
    }),
  ])
}
