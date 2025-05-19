.PHONY: test test-unit test-integration test-distributed test-all compile clean

# Default task
all: compile test

# Compilation
compile:
	mix compile

# Testing
test: compile
	mix test --exclude distributed --exclude slow

test-unit: compile
	mix test test/unit --exclude distributed --exclude slow

test-integration: compile
	mix test test/integration --exclude distributed

test-distributed: compile
	ENABLE_DISTRIBUTED_TESTS=true mix test --include distributed

test-all: compile
	ENABLE_DISTRIBUTED_TESTS=true mix test --include distributed --include slow

# CI testing
test-ci: compile
	mix test --exclude distributed

# Generate documentation
docs:
	mix docs

# Clean up
clean:
	mix clean
	rm -rf _build
	rm -rf deps
	rm -rf doc

# Run static code analysis
lint:
	mix format --check-formatted
	mix credo --strict
	mix dialyzer

# Format code
format:
	mix format

# Print help
help:
	@echo "Available targets:"
	@echo "  all             - Compile and run tests (default target)"
	@echo "  compile         - Compile the project"
	@echo "  test            - Run basic tests"
	@echo "  test-unit       - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-distributed - Run distributed tests"
	@echo "  test-all        - Run all tests including slow ones"
	@echo "  test-ci         - Run tests for CI pipeline"
	@echo "  docs            - Generate documentation"
	@echo "  clean           - Clean all build artifacts"
	@echo "  lint            - Run static code analysis"
	@echo "  format          - Format code according to style guide"