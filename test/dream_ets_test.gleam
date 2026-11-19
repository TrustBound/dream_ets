//// Test entry point. Runs every suite with the dream_test runner and
//// measures the line coverage of `src/`.

import doc_snippets_test
import dream_ets/config_test
import dream_ets/encoders_test
import dream_ets/helpers_test
import dream_ets/operations_test
import dream_ets/table_test
import dream_test/coverage
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
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
