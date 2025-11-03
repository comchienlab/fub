# FUB Monitoring System Tests

This directory contains comprehensive test coverage for the FUB monitoring system modules. The test suite ensures that all monitoring functionality works correctly and integrates properly with the existing FUB safety and cleanup systems.

## Test Coverage

### Unit Tests
- **`test-monitoring-system-analysis.sh`** - Tests system analysis functionality
- **`test-monitoring-performance-monitor.sh`** - Tests performance monitoring capabilities
- **`test-monitoring-history-tracking.sh`** - Tests historical data tracking
- **`test-monitoring-ui.sh`** - Tests user interface components
- **`test-monitoring-btop-integration.sh`** - Tests btop integration features
- **`test-monitoring-alert-system.sh`** - Tests alert system functionality

### Integration Tests
- **`test-monitoring-integration.sh`** - Tests integration between monitoring modules and safety/cleanup systems

### Performance Tests
- **`test-monitoring-performance-impact.sh`** - Validates that monitoring doesn't significantly impact system performance

### Scenario Tests
- **`test-monitoring-alert-scenarios.sh`** - Tests various alert system scenarios and edge cases

## Test Categories

### 1. Unit Tests
Unit tests validate individual module functionality in isolation:
- Module initialization
- Core function behavior
- Error handling
- Data validation
- Performance characteristics

### 2. Integration Tests
Integration tests verify that monitoring modules work together correctly:
- Pre/post-cleanup analysis workflow
- Performance monitoring during operations
- Alert system integration with monitoring components
- History tracking integration
- End-to-end monitoring workflows

### 3. Performance Impact Tests
Performance tests ensure monitoring doesn't degrade system performance:
- Individual component performance benchmarks
- Memory usage validation
- Concurrent operation performance
- Long-running monitoring stability
- System scalability testing

### 4. Alert Scenario Tests
Scenario tests cover real-world alert system usage:
- Threshold-based alerting
- Alert cooldown functionality
- Multiple concurrent alerts
- Alert escalation scenarios
- Alert recovery and acknowledgment
- System load testing
- Edge case handling

## Running Tests

### Quick Start
Run all monitoring tests:
```bash
./tests/test-monitoring-comprehensive.sh
```

### Run Specific Categories
```bash
# Run only unit tests
./tests/test-monitoring-comprehensive.sh --category unit

# Run only integration tests
./tests/test-monitoring-comprehensive.sh --category integration

# Run only performance tests
./tests/test-monitoring-comprehensive.sh --category performance

# Run only scenario tests
./tests/test-monitoring-comprehensive.sh --category scenarios
```

### Run Specific Test Files
```bash
# Run a specific unit test
./tests/test-monitoring-comprehensive.sh --test unit_system_analysis

# Run a specific integration test
./tests/test-monitoring-comprehensive.sh --test integration_safety
```

### Run Individual Test Files
```bash
# Run individual test files directly
./tests/test-monitoring-system-analysis.sh
./tests/test-monitoring-performance-monitor.sh
./tests/test-monitoring-alert-scenarios.sh
```

## Test Results

### Output Directory
Test results are saved to: `test-results/monitoring-YYYYMMDD_HHMMSS/`

### Result Structure
```
test-results/monitoring-YYYYMMDD_HHMMSS/
├── unit/                          # Unit test results
│   ├── test-monitoring-system-analysis.sh.out
│   ├── test-monitoring-performance-monitor.sh.out
│   └── ...
├── integration/                   # Integration test results
│   └── test-monitoring-integration.sh.out
├── performance/                   # Performance test results
│   └── test-monitoring-performance-impact.sh.out
├── scenarios/                     # Scenario test results
│   └── test-monitoring-alert-scenarios.sh.out
└── comprehensive-report.html      # HTML report (generated automatically)
```

### HTML Report
An HTML report is automatically generated containing:
- Overall test summary
- Per-category breakdowns
- Test execution details
- Success rates and statistics

## Test Framework

The monitoring tests use the FUB test framework (`tests/test-framework.sh`) which provides:
- Assertion functions (`assert_equals`, `assert_contains`, etc.)
- Test result tracking
- Colored output
- Error handling
- Performance measurement utilities

## System Requirements

### Required Commands
- `bash` - Shell interpreter
- `grep` - Pattern matching
- `awk` - Text processing
- `sed` - Stream editing
- `date` - Date/time utilities
- `ps` - Process information
- `free` - Memory information

### Optional Commands
- `bc` - Calculator for floating-point arithmetic
- `jq` - JSON processing (improves test accuracy)

## Test Configuration

### Environment Variables
- `FUB_CACHE_DIR` - Cache directory for test data
- `FUB_TEST_MODE` - Enables test-specific behavior
- `FUB_TEST_DIR` - Temporary test directory

### Performance Thresholds
Performance tests validate these criteria:
- System analysis: < 2.0 seconds average
- Metrics recording: < 1.0 second average
- Memory usage: < 10-20MB depending on operation
- Concurrent operations: > 10 operations/second

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   chmod +x tests/test-monitoring-*.sh
   ```

2. **Missing Commands**
   Install required packages:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install bc jq coreutils

   # macOS
   brew install bc jq
   ```

3. **Test Failures Due to System Load**
   Some tests may fail on heavily loaded systems. Run tests on a relatively idle system for best results.

4. **Cleanup Issues**
   If test files aren't cleaned up properly:
   ```bash
   rm -rf /tmp/fub-test-*
   ```

### Debug Mode
Run tests with verbose output:
```bash
# Enable verbose mode in individual tests
export TEST_VERBOSE=true
./tests/test-monitoring-system-analysis.sh

# Or run with the comprehensive runner
./tests/test-monitoring-comprehensive.sh --category unit
```

## Contributing

### Adding New Tests

1. **Create Test File**
   ```bash
   cp tests/test-monitoring-system-analysis.sh tests/test-monitoring-new-feature.sh
   ```

2. **Update Test Categories**
   Add your test to the appropriate category in `test-monitoring-comprehensive.sh`

3. **Follow Test Patterns**
   - Use the established test framework functions
   - Include comprehensive edge case testing
   - Add performance validation where appropriate
   - Document test scenarios clearly

4. **Update Documentation**
   Update this README with new test information.

### Test Best Practices

1. **Isolation**: Tests should not depend on each other
2. **Cleanup**: Always clean up temporary files and directories
3. **Mocking**: Use mocks for external dependencies
4. **Error Handling**: Test both success and failure scenarios
5. **Performance**: Validate performance characteristics
6. **Documentation**: Clear test descriptions and comments

## Continuous Integration

These tests are designed to run in CI/CD environments:

```yaml
# Example GitHub Actions workflow
- name: Run Monitoring Tests
  run: |
    ./tests/test-monitoring-comprehensive.sh --category unit
    ./tests/test-monitoring-comprehensive.sh --category integration
```

The test suite returns appropriate exit codes for CI integration:
- `0` - All tests passed
- `1` - Some tests failed

## License

These tests are part of the FUB project and follow the same licensing terms.