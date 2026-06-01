# Shell Unit Testing Framework for zzcollab

**Status:** Framework in use; suite reconciled with current modules
**Created:** December 5, 2025
**Updated:** 2026-05-31

## Overview

A shell unit testing framework provides coverage for zzcollab's Bash
components. This framework provides:

- **Test Helpers** (`test_helpers.sh`) - Common test utilities
- **Test Suites** - Unit tests for the framework modules:
  - `test-core.sh` - Tests for core.sh
  - `test-cli.sh` - Tests for cli.sh
  - `test-config.sh` - Tests for config.sh
  - `test-docker.sh` - Tests for docker.sh
  - `test-profiles.sh` - Tests for profiles.sh
  - `test-docs.sh` - Documentation checks
  - `test-integration.sh` - Cross-module integration tests
- **Test Runner** (`run_all_tests.sh`) - Unified test execution
- **Makefile Integration** - `make shell-test` target

## Files

```
tests/shell/
├── test_helpers.sh          # Test utilities and assertions
├── test-core.sh             # core.sh tests
├── test-cli.sh              # cli.sh tests
├── test-config.sh           # config.sh tests
├── test-docker.sh           # docker.sh tests
├── test-profiles.sh         # profiles.sh tests
├── test-docs.sh             # documentation tests
├── test-integration.sh      # integration tests
└── run_all_tests.sh         # Test runner script
```

## Test Coverage

### core.sh Module Tests (14 tests)
- Package name validation (valid names, dots, invalid-character
  stripping, leading-letter rule, empty input)
- Command existence checks (`command_exists`)
- Logging system (error, success, info) and verbosity gating
- Safe directory creation (`safe_mkdir`, including nested paths)

### cli.sh Module Tests (19 tests)
- Argument requirement validation (`require_arg`)
- Team name validation (format, length, reserved names)
- Project name validation
- Base image validation (Docker Hub, custom registries, tags)
- R version validation (semantic versioning)
- Bundle name validation
- Integration tests (all args together)

## Running Tests

### Run All Tests
```bash
make shell-test              # Run all tests
make shell-test-verbose      # Run with detailed output
```

### Run Individual Test Suites
```bash
make shell-test-core         # Test core.sh only
make shell-test-cli          # Test cli.sh only
```

### Run Tests Directly
```bash
bash tests/shell/run_all_tests.sh           # All tests
bash tests/shell/run_all_tests.sh --verbose # Verbose output
bash tests/shell/test-core.sh               # core.sh only
bash tests/shell/test-cli.sh                # cli.sh only
bash tests/shell/test-docker.sh             # docker.sh only
```

## Test Framework Features

### Assertion Functions
- `assert_success $cmd` - Command should succeed
- `assert_failure $cmd` - Command should fail
- `assert_equals $expected $actual` - String equality
- `assert_contains $haystack $needle` - Substring check
- `assert_file_exists $path` - File existence
- `assert_file_not_exists $path` - File non-existence

### Setup/Teardown
- `setup_test` - Initialize test environment with temp directory
- `teardown_test` - Clean up temporary files
- `setup_test_logging` - Configure logging for tests

### Fixture Helpers
- `create_test_description $path $name` - Create DESCRIPTION file
- `create_test_r_file $path "packages"` - Create R file with imports
- `create_test_renv_lock $path "packages"` - Create renv.lock

### Output Capture
- `capture_output $cmd` - Capture stdout
- `capture_stderr $cmd` - Capture stderr
- `CAPTURED_OUTPUT` - Variable with captured output

## Current Test Results

The framework is currently set up and ready to provide comprehensive coverage. Tests are organized into logical groups:

### Test Organization
Each test file contains:
1. **Setup** - Function test environment
2. **Test Cases** - Individual test functions
3. **Teardown** - Clean up test artifacts
4. **Test Runner** - Execute all tests and report results

## Next Steps for Test Enhancement

### Phase 1: Core Functionality (Ready)
- Logging system tests
- Error handling tests
- CLI argument validation tests
- File operation tests

### Phase 2: Integration Tests (Ready to implement)
- Docker integration tests
- Full workflow validation
- Error recovery tests
- End-to-end scenarios

### Phase 3: Performance Tests (Future)
- Module loading performance
- Docker build performance
- Validation speed benchmarks

## Example Test Output

```bash
$ make shell-test
Running shell unit tests...
==========================================
Shell Unit Test Runner
==========================================

PASS test_log_error_always_outputs
PASS test_validate_package_name_valid
PASS test_require_arg_with_value
FAIL test_validate_team_name_too_short
...

==========================================
Test Summary
==========================================
Total Passed: 117
Total Failed: 2

Failed Test Suites:
  test-cli
==========================================

Some tests failed
```

## Architecture

### Test Execution Flow
```
make shell-test
    ↓
run_all_tests.sh
    ↓
    ├─ test-core.sh
    │  ├─ test_log_error_always_outputs
    │  ├─ test_validate_package_name_valid
    │  └─ ...
    ├─ test-cli.sh
    │  ├─ test_require_arg_with_value
    │  └─ ...
    └─ test-docker.sh
       ├─ ...
       └─ ...
    ↓
Results Summary
```

### Module Sourcing Strategy
Tests source module files directly via the `load_module_for_testing`
helper (there is no production module-loading or dependency-resolution
system to exercise):
1. Source only the required files (for example, core.sh, constants.sh)
2. Set up a minimal test environment
3. Test individual functions in isolation
4. Provide fixture data as needed

## Benefits

✅ **Zero Host Dependencies** - No need for external testing framework
✅ **Pure Bash** - Works anywhere bash runs
✅ **Fast Execution** - Typically completes in <2 seconds
✅ **Clear Output** - Easy to understand pass/fail results
✅ **Maintainable** - Simple assertion helpers
✅ **Extensible** - Easy to add more tests
✅ **CI/CD Ready** - Returns proper exit codes

## Known Limitations

1. **Module Dependency Complexity** - Some tests may require careful setup of module state
2. **Docker Integration** - Docker-specific tests need Docker runtime
3. **External Commands** - Tests depending on `yq`, `jq` require those tools installed
4. **Mock Support** - Framework uses actual files/commands (not mocked)

## Future Enhancements

### Mock Support
Add mock function support for:
- `docker run`
- `yq eval`
- `jq` queries
- File I/O operations

### CI/CD Integration
- GitHub Actions workflow for test automation
- Test coverage reporting
- Failure notification

### Performance Profiling
- Time individual test execution
- Identify slow tests
- Performance regression detection

### Additional Test Suites
- `test-error-handling.sh` - Error recovery tests
- `test-github.sh` - GitHub integration helpers
- `test-doctor.sh` - Environment diagnostics

## Contributing Tests

### Test Template
```bash
test_my_feature_success() {
    # Setup
    setup_test
    load_module_for_testing "my-module.sh"

    # Test
    assert_success my_function "$arg1" "$arg2"

    # Teardown
    teardown_test
}
```

### Naming Conventions
- Test files: `test-modulename.sh`
- Test functions: `test_feature_scenario`
- Helper scripts: lowercase with underscores
- Constants: UPPERCASE_WITH_UNDERSCORES

## Troubleshooting

### Tests Not Running
```bash
# Make sure scripts are executable
chmod +x tests/shell/*.sh

# Check for syntax errors
bash -n tests/shell/test-core.sh

# Run with verbose error reporting
bash -x tests/shell/test-core.sh
```

### Module Loading Failures
- Verify constants.sh defines required variables
- Check module dependencies are sourced in correct order
- Review module load error messages

### Assertion Failures
- Check expected vs actual values carefully
- Use `--verbose` flag to see detailed output
- Review test setup for proper initialization

## References

- **Test Framework**: Pure Bash (no external dependencies)
- **Similar Tools**: bats, shunit2, shtab
- **Documentation**: This file explains all features
- **Examples**: See individual test files (test-core.sh, etc.)

---

**Testing Framework Created:** December 5, 2025
**Updated:** 2026-05-31 (suite reconciled with current 8-module layout)
**Status:** In use for unit and integration testing
**Coverage:** core, cli, config, docker, profiles, docs, integration suites
