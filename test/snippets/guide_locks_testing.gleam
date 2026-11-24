//// Guide: Locks and work queues, testing
////
//// Tests `unlock` from step 1.

import dream_ets/helpers
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guide_locks_lock.{is_locked, try_lock, unlock}

pub fn tests() -> TestSuite {
  describe("unlock", [
    it("keeps a lock that another owner holds", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("unlock_test_other")
      let assert Ok(True) = try_lock(locks, "report:42", "worker:1")

      // Act
      let assert Ok(False) = unlock(locks, "report:42", "worker:2")

      // Assert
      is_locked(locks, "report:42")
      |> should
      |> be_equal(Ok(True))
      |> or_fail_with("The lock of worker:1 should stay")
    }),
    it("releases the lock of its owner", fn() {
      // Arrange
      let assert Ok(locks) = helpers.new_string_table("unlock_test_owner")
      let assert Ok(True) = try_lock(locks, "report:42", "worker:1")

      // Act
      let assert Ok(True) = unlock(locks, "report:42", "worker:1")

      // Assert
      is_locked(locks, "report:42")
      |> should
      |> be_equal(Ok(False))
      |> or_fail_with("The lock should be free")
    }),
  ])
}
