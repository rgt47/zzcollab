# ZZCOLLAB Testing Framework

This directory contains the complete test suite for the ZZCOLLAB research collaboration framework.

## Overview

ZZCOLLAB uses a comprehensive multi-layer testing approach:

1. **R Package Tests** (testthat) - Unit tests for R functions
2. **Shell Script Tests** (BATS) - Behavioral tests for bash modules
3. **Integration Tests** (planned) - End-to-end workflow validation

## Test Structure

```
tests/
├── testthat/               # R package tests
│   ├── test-config.R       # Configuration functions
│   ├── test-project.R      # Project initialization
│   ├── test-help.R         # Help system
│   ├── test-git.R          # Git integration
│   └── test-utils.R        # Utility functions
├── shell/                  # Shell script tests (BATS)
│   ├── test-config.bats    # Config module (31/32 passing)
│   └── [more .bats files]  # Additional module tests
├── fixtures/               # Test data and mocks (planned)
├── integration/            # End-to-end tests (planned)
├── run-all-tests.sh        # Main test runner
└── README.md               # This file
```

## Running Tests

### All Tests

```bash
# Run complete test suite
./tests/run-all-tests.sh

# Verbose output
./tests/run-all-tests.sh --verbose

# With coverage report
./tests/run-all-tests.sh --coverage
```

### R Package Tests Only

```bash
# From project root
Rscript -e 'devtools::test()'

# Or using R CMD check
R CMD check .

# With coverage
Rscript -e 'covr::package_coverage()'
```

### Shell Script Tests Only

```bash
# All BATS tests
bats tests/shell/*.bats

# Specific module
bats tests/shell/test-config.bats

# Verbose output
bats -t tests/shell/test-config.bats
```

## Installation Requirements

### R Testing

```r
# Install testing packages
install.packages(c("testthat", "devtools", "covr"))
```

### Shell Testing

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# Manual installation
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Test Coverage

### Current Status

- **R Package Tests**: 5 test files, ~60 tests
  - test-config.R: Configuration system validation
  - test-project.R: Project initialization and management
  - test-help.R: Help system and topics
  - test-git.R: Git integration functions
  - test-utils.R: Utility function validation

- **Shell Script Tests**: 1 test file, 32 tests (31 passing)
  - test-config.bats: Config module (96.9% pass rate)

### Coverage Goals

From `docs/TESTING_GUIDE.md`:
- Target: >90% code coverage
- Critical paths: 100% coverage
- CI/CD: Automated test execution on all commits

## Writing Tests

### R Package Tests (testthat)

Create new test files in `tests/testthat/` with format `test-{module}.R`:

```r
# tests/testthat/test-example.R
test_that("function validates input", {
  expect_error(my_function(), "required")
  expect_error(my_function(NULL), "NULL")
})

test_that("function returns expected output", {
  result <- my_function("input")
  expect_type(result, "character")
  expect_length(result, 1)
})
```

### Shell Script Tests (BATS)

Create new test files in `tests/shell/` with format `test-{module}.bats`:

```bash
#!/usr/bin/env bats
# tests/shell/test-example.bats

setup() {
    # Runs before each test
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../.."
    source "${SCRIPT_DIR}/modules/example.sh"
}

teardown() {
    # Runs after each test
    rm -rf /tmp/test_*
}

@test "function validates input" {
    run my_function
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "required" ]]
}

@test "function returns expected output" {
    run my_function "input"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "success" ]]
}
```

## Test Patterns

### Testing Configuration

```r
# R tests
test_that("config loads from file", {
  config <- get_config("key")
  expect_type(config, "character")
})
```

```bash
# BATS tests
@test "config loads from file" {
    result=$(get_config_value "key")
    [[ "${result}" != "" ]]
}
```

### Testing Error Handling

```r
# R tests
test_that("function handles errors", {
  expect_error(function_name(), "expected error")
})
```

```bash
# BATS tests
@test "function handles errors" {
    run function_name
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "expected error" ]]
}
```

### Testing File Operations

```r
# R tests with temp files
test_that("creates file correctly", {
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE))

  create_file(file.path(temp_dir, "test.txt"))
  expect_true(file.exists(file.path(temp_dir, "test.txt")))
})
```

```bash
# BATS tests with temp files
@test "creates file correctly" {
    temp_file=$(mktemp)
    create_file "${temp_file}"
    [ -f "${temp_file}" ]
    rm -f "${temp_file}"
}
```

## CI/CD Integration

### GitHub Actions Workflow

Tests run automatically on:
- All pull requests
- Pushes to main branch
- Manual workflow dispatch

See `.github/workflows/r-package.yml` for R package checks.

### Adding Shell Tests to CI/CD

```yaml
# .github/workflows/shell-tests.yml
name: Shell Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install BATS
        run: sudo apt-get install -y bats
      - name: Run shell tests
        run: bats tests/shell/*.bats
```

## Troubleshooting

### BATS Tests Fail with "readonly variable"

The modules use `readonly` for config paths. Set environment variables BEFORE sourcing:

```bash
setup() {
    export ZZCOLLAB_CONFIG_USER_DIR="/tmp/test"
    source "${SCRIPT_DIR}/modules/config.sh"
}
```

### R Tests Can't Find Functions

Ensure package is loaded:

```r
library(zzcollab)  # Or use devtools::load_all()
```

### Tests Timeout

Increase timeout in test runner or CI/CD config:

```yaml
timeout-minutes: 30
```

## Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up temp files/directories
3. **Mocking**: Mock external dependencies (Docker, git, network)
4. **Fast**: Keep unit tests fast (<1s each)
5. **Clear**: Test names should describe what they test
6. **Coverage**: Aim for >90% code coverage
7. **Edge Cases**: Test error conditions and edge cases

## Known Issues

- `test-config.bats` test 21 (config_list): Command substitution issue in BATS environment (31/32 passing)
- Integration tests not yet implemented
- Test fixtures directory not yet created

## Future Work

1. **Shell Module Tests**: Complete BATS tests for all 17 modules
2. **Integration Tests**: End-to-end workflow validation
3. **Test Fixtures**: Reusable test data and mocks
4. **Performance Tests**: Benchmark critical operations
5. **Security Tests**: Validate dotfiles handling, permissions
6. **Coverage Reporting**: Automated coverage badges

## References

- [TESTING_GUIDE.md](../docs/TESTING_GUIDE.md) - Comprehensive testing philosophy
- [testthat documentation](https://testthat.r-lib.org/)
- [BATS documentation](https://bats-core.readthedocs.io/)
- [covr package](https://covr.r-lib.org/)

---

Last updated: 2025-10-12
