//// Tests for the snippets of the counting guide
//// (docs/guides/counting.md). Each test runs a snippet and asserts the
//// exact value that the guide shows. The output that the guide shows is
//// compared with the files in test/outputs.

import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/other_process
import fixtures/output_file
import gleam/option.{Some}
import gleam/string
import snippets/guide_counting_counter_process as counter
import snippets/guide_counting_many_processes
import snippets/guide_counting_page_views
import snippets/guide_counting_quota.{NotEnoughCredits}

pub fn tests() -> TestSuite {
  describe("counting guide", [
    it("step 1: count_three_views returns the count of /", fn() {
      // Act
      let views = guide_counting_page_views.count_three_views()

      // Assert
      views
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("Expected two views of /")
    }),
    it("step 2: the readers give the output that the guide shows", fn() {
      // Arrange
      let assert Ok(views) = helpers.new_counter("guide_count_readers")
      let assert Ok(_) = helpers.increment(views, "/about")
      let assert Ok(_) = helpers.increment(views, "/")
      let assert Ok(_) = helpers.increment(views, "/")

      // Act
      let pricing = guide_counting_page_views.views_of(views, "/pricing")
      let report = guide_counting_page_views.report(views)

      // Assert
      output_file.calls([
        #("views_of(views, \"/pricing\")", string.inspect(pricing)),
        #("report(views)", string.inspect(report)),
      ])
      |> should
      |> be_equal(output_file.read("guide_counting_readers"))
      |> or_fail_with("Expected the output of guide_counting_readers.txt")
    }),
    it(
      "step 5: spend and refund_one give the output that the guide shows",
      fn() {
        // Arrange
        let assert Ok(spent) = helpers.new_counter("guide_count_quota")

        // Act
        let first = guide_counting_quota.spend(spent, "user:1", 30)
        let refused = guide_counting_quota.spend(spent, "user:1", 80)
        let refunded = guide_counting_quota.refund_one(spent, "user:1")

        // Assert
        output_file.calls([
          #("spend(spent, \"user:1\", 30)", string.inspect(first)),
          #("spend(spent, \"user:1\", 80)", string.inspect(refused)),
          #("refund_one(spent, \"user:1\")", string.inspect(refunded)),
        ])
        |> should
        |> be_equal(output_file.read("guide_counting_quota"))
        |> or_fail_with("Expected the output of guide_counting_quota.txt")
      },
    ),
    it("step 5: a refused spend gives its credits back", fn() {
      // Arrange
      let assert Ok(spent) = helpers.new_counter("guide_count_give_back")
      let assert Ok(_) = guide_counting_quota.spend(spent, "user:1", 30)
      let assert Error(_) = guide_counting_quota.spend(spent, "user:1", 80)

      // Act
      let total = operations.get(spent, "user:1")

      // Assert
      total
      |> should
      |> be_equal(Ok(Some(30)))
      |> or_fail_with("Expected 30 credits spent")
    }),
    it("step 5: a refused spend never reports fewer than 0 credits", fn() {
      // Arrange
      let assert Ok(spent) = helpers.new_counter("guide_count_left_zero")
      let assert Ok(Nil) = operations.set(spent, "user:1", 120)

      // Act
      let left = guide_counting_quota.spend(spent, "user:1", 10)

      // Assert
      left
      |> should
      |> be_equal(Error(NotEnoughCredits(left: 0)))
      |> or_fail_with("Expected NotEnoughCredits with 0 left")
    }),
    it("step 3: ten processes that increment 1000 times each give 10000", fn() {
      // Act
      let hits = guide_counting_many_processes.count_from_ten_processes()

      // Assert
      hits
      |> should
      |> be_equal(Ok(Some(10_000)))
      |> or_fail_with("Expected every increment to count")
    }),
    it("step 4: another process reads a count", fn() {
      // Arrange
      let assert Ok(views) = counter.start("guide_count_process_read")
      let assert Ok(_) = counter.increment(views, "/")

      // Act
      let count = other_process.run(fn() { counter.count(views, "/") })

      // Assert
      count
      |> should
      |> be_equal(Ok(Ok(1)))
      |> or_fail_with("Expected the count from another process")
    }),
    it("step 4: a direct write from another process is refused", fn() {
      // Arrange
      let assert Ok(views) = counter.start("guide_count_process_refused")

      // Act
      let written = helpers.increment(counter.counts(views), "/")

      // Assert
      written
      |> should
      |> be_equal(
        Error(table.OperationFailed("ETS refused the operation: badarg")),
      )
      |> or_fail_with("Expected the protected table to refuse the write")
    }),
    it("failures: increment on a value that is not an Int is refused", fn() {
      // Arrange
      let assert Ok(names) = helpers.new_string_table("guide_count_not_int")
      let assert Ok(Nil) = operations.set(names, "/", "many")
      let counts =
        table.new_table(
          table.table_ref(names),
          "guide_count_not_int",
          encoders.string_encoder,
          encoders.string_decoder(),
          encoders.int_encoder,
          encoders.int_decoder(),
        )

      // Act
      let assert Error(table.DecodeError(_)) = helpers.increment(counts, "/")

      // Assert
      operations.get(names, "/")
      |> should
      |> be_equal(Ok(Some("many")))
      |> or_fail_with("Expected the value to stay")
    }),
  ])
}
