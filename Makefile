# dream_ets Makefile

.PHONY: test build format check check-snippets docs clean

# Run the tests with coverage
test:
	@gleam test

# Build the package
build:
	@gleam build

# Format the code
format:
	@gleam format src test

# Run every check that CI runs: format, build, tests and docs
check:
	@gleam format --check src test
	@gleam build
	@gleam test
	@gleam docs build
	@gleam run -m dream_snippets

# Check that each code block in the docs matches a tested snippet
check-snippets:
	@gleam run -m dream_snippets

# Build the documentation
docs:
	@gleam docs build

# Remove build artifacts
clean:
	@gleam clean
	@rm -f erl_crash.dump
