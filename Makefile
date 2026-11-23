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

# Format check, build, tests, docs build and snippet check (what CI runs)
check:
	@sh scripts/check.sh

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
