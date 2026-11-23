//// Tests for the snippets of the locks and work queues guide
//// (docs/guides/locks-and-queues.md). Each test runs a snippet and asserts
//// the exact value that the guide shows.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/other_process
import gleam/list
import gleam/option.{None}
import snippets/guide_locks_lock.{is_locked, try_lock}
import snippets/guide_locks_outbox
import snippets/guide_locks_queue
import snippets/guide_locks_race
import snippets/guide_locks_workers

pub fn tests() -> TestSuite {
  describe("locks and work queues guide", [
    it("step 1: the first try_lock gets the lock", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("guide_locks_first")

      // Act
      let locked = try_lock(locks, "report:42", "worker:1")

      // Assert
      locked
      |> should
      |> be_equal(Ok(True))
      |> or_fail_with("Expected the lock")
    }),
    it("step 1: a second owner does not get a held lock", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("guide_locks_second")
      let assert Ok(True) = try_lock(locks, "report:42", "worker:1")

      // Act
      let locked = try_lock(locks, "report:42", "worker:2")

      // Assert
      locked
      |> should
      |> be_equal(Ok(False))
      |> or_fail_with("Expected no lock for worker:2")
    }),
    it("step 2: one of five racing processes gets the lock", fn() {
      // Act
      let assert Ok(winners) = guide_locks_race.five_processes_race()

      // Assert
      list.length(winners)
      |> should
      |> be_equal(1)
      |> or_fail_with("Expected exactly one owner")
    }),
    it("failures: a lock stays when its holder stops", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("guide_locks_crashed")
      let assert Ok(Ok(True)) =
        other_process.run(fn() { try_lock(locks, "report:42", "worker:1") })

      // Act
      let locked = is_locked(locks, "report:42")

      // Assert
      locked
      |> should
      |> be_equal(Ok(True))
      |> or_fail_with("Expected the lock to stay")
    }),
    it("step 3: three workers claim each of ten jobs once", fn() {
      // Act
      let claimed = guide_locks_workers.three_workers_empty_the_queue()

      // Assert
      claimed
      |> should
      |> be_equal(
        Ok([
          "job:001", "job:002", "job:003", "job:004", "job:005", "job:006",
          "job:007", "job:008", "job:009", "job:010",
        ]),
      )
      |> or_fail_with("Expected each job once")
    }),
    it("step 3: claim_next takes the oldest job", fn() {
      // Arrange
      let assert Ok(queue) =
        guide_locks_queue.create_queue("guide_queue_oldest")
      let assert Ok(Nil) =
        guide_locks_queue.add_job(queue, "job:002", "send email 2")
      let assert Ok(Nil) =
        guide_locks_queue.add_job(queue, "job:001", "send email 1")

      // Act
      let next = guide_locks_queue.claim_next(queue)

      // Assert
      next
      |> should
      |> be_equal(Ok(option.Some(#("job:001", "send email 1"))))
      |> or_fail_with("Expected job:001")
    }),
    it("step 3: claim_next returns None for an empty queue", fn() {
      // Arrange
      let assert Ok(queue) = guide_locks_queue.create_queue("guide_queue_empty")

      // Act
      let next = guide_locks_queue.claim_next(queue)

      // Assert
      next
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("Expected no job")
    }),
    it("step 4: take_messages returns every message of the user", fn() {
      // Act
      let messages = guide_locks_outbox.three_messages_for_ada()

      // Assert
      messages
      |> should
      |> be_equal(Ok(["Welcome", "Your invoice", "Your invoice"]))
      |> or_fail_with("Expected the three messages")
    }),
    it("step 4: get refuses a key with several values", fn() {
      // Arrange
      let assert Ok(outbox) =
        guide_locks_outbox.create_outbox("guide_outbox_get")
      let assert Ok(Nil) =
        guide_locks_outbox.queue_message(outbox, "user:ada", "Welcome")
      let assert Ok(Nil) =
        guide_locks_outbox.queue_message(outbox, "user:ada", "Your invoice")

      // Act
      let message = operations.get(outbox, "user:ada")

      // Assert
      message
      |> should
      |> be_equal(
        Error(table.OperationFailed("the key has 2 values, use get_all")),
      )
      |> or_fail_with("Expected the several values error")
    }),
    it("failures: size counts every message of every user", fn() {
      // Arrange
      let assert Ok(outbox) =
        guide_locks_outbox.create_outbox("guide_outbox_size")
      let assert Ok(Nil) =
        guide_locks_outbox.queue_message(outbox, "user:ada", "Welcome")
      let assert Ok(Nil) =
        guide_locks_outbox.queue_message(outbox, "user:ada", "Your invoice")
      let two_messages = operations.size(outbox)
      let assert Ok(Nil) =
        guide_locks_outbox.queue_message(outbox, "user:bob", "Welcome")

      // Act
      let three_messages = operations.size(outbox)

      // Assert
      #(two_messages, three_messages)
      |> should
      |> be_equal(#(Ok(2), Ok(3)))
      |> or_fail_with("Expected each message to count")
    }),
  ])
}
