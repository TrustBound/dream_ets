//// Test entry point. Runs every suite with the dream_test runner and
//// measures the line coverage of `src/`.

import doc_snippets_test
import dream_ets/config_test
import dream_ets/encoders_test
import dream_ets/guide_caching_test
import dream_ets/guide_counting_test
import dream_ets/guide_getting_started_test
import dream_ets/guide_locks_test
import dream_ets/guide_saving_test
import dream_ets/helpers_test
import dream_ets/operations_test
import dream_ets/table_test
import dream_test/coverage
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import snippets/guide_caching_testing
import snippets/guide_counting_testing
import snippets/guide_getting_started_testing
import snippets/guide_locks_testing
import snippets/guide_saving_testing
import snippets_test

pub fn main() {
  runner.new([
    config_test.tests(),
    encoders_test.tests(),
    helpers_test.tests(),
    operations_test.tests(),
    table_test.tests(),
    snippets_test.tests(),
    doc_snippets_test.tests(),
    guide_getting_started_test.tests(),
    guide_getting_started_testing.tests(),
    guide_caching_test.tests(),
    guide_caching_testing.tests(),
    guide_counting_test.tests(),
    guide_counting_testing.tests(),
    guide_locks_test.tests(),
    guide_locks_testing.tests(),
    guide_saving_test.tests(),
    guide_saving_testing.tests(),
  ])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(
    coverage.new()
    |> coverage.show_missing()
    |> coverage.minimum_percent(100.0)
    |> coverage.json_path("build/coverage/coverage.json"),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
