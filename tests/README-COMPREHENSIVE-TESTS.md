# FUB Comprehensive Test Suite

This document describes the comprehensive testing suite for the FUB (Filesystem Utility and Cleaner) project, which provides extensive test coverage for all system components and features.

## Overview

The FUB comprehensive test suite consists of multiple test categories that ensure system reliability, performance, safety, and compatibility across different Ubuntu environments.

## Test Categories

### 1. Unit Tests (`test-interactive-ui.sh`, `test-dependencies-system.sh`, `test-common.sh`)
- **Purpose**: Test individual components and functions in isolation
- **Coverage**:
  - Interactive UI components (menus, themes, navigation)
  - Dependency management system
  - Core utility functions
  - Configuration management
- **Execution Time**: ~2-5 minutes
- **Requirements**: Basic shell environment, mock tools

### 2. Integration Tests (`test-system-integration.sh`, `test-integration-suite.sh`)
- **Purpose**: Test interactions between different system components
- **Coverage**:
  - Safety system integration with cleanup operations
  - Monitoring system integration
  - UI system integration
  - Cross-component error handling
- **Execution Time**: ~5-10 minutes
- **Requirements**: Mock environment, isolated test space

### 3. Performance Tests (`test-performance-enhanced.sh`, `test-performance-regression.sh`)
- **Purpose**: Measure system performance and detect regressions
- **Coverage**:
  - UI component performance benchmarks
  - Memory usage monitoring
  - Load testing with large datasets
  - Performance regression detection
- **Execution Time**: ~10-15 minutes
- **Requirements**: Sufficient disk space, memory monitoring tools

### 4. Ubuntu Integration Tests (`test-ubuntu-integration.sh`)
- **Purpose**: Test compatibility with real Ubuntu systems
- **Coverage**:
  - Package manager integration (apt, dpkg)
  - Service management (systemd)
  - Filesystem operations
  - Ubuntu version compatibility (20.04, 22.04, 24.04, 24.10)
- **Execution Time**: ~5-8 minutes
- **Requirements**: Ubuntu system, optional sudo access

### 5. Safety Tests (`test-safety-validation.sh`, `test-safety-framework.sh`)
- **Purpose**: Validate all safety mechanisms and protections
- **Coverage**:
  - Pre-flight safety checks
  - Protected directory detection
  - Backup and restore functionality
  - Dangerous operation prevention
- **Execution Time**: ~3-5 minutes
- **Requirements**: Test environment with file creation capabilities

### 6. User Acceptance Tests (`test-user-acceptance.sh`)
- **Purpose**: Validate real-world usage scenarios and user workflows
- **Coverage**:
  - End-to-end functionality verification
  - User workflow validation
  - Interactive UI usability testing
  - Real-world scenario testing
- **Execution Time**: ~5-10 minutes
- **Requirements**: Full system environment, user interaction simulation

## Quick Start

### Run All Tests
```bash
# Run comprehensive test suite
./tests/test-comprehensive-suite.sh

# Run with options
./tests/test-comprehensive-suite.sh --fail-fast --timeout 1800
```

### Run Individual Test Categories
```bash
# Run only unit tests
./tests/test-comprehensive-suite.sh --unit-only

# Run only integration tests
./tests/test-comprehensive-suite.sh --integration-only

# Skip Ubuntu tests (useful on non-Ubuntu systems)
./tests/test-comprehensive-suite.sh --no-ubuntu
```

### Run Individual Test Files
```bash
# Run specific test file
./tests/test-interactive-ui.sh

# Run with test framework
./tests/test-framework.sh && ./tests/test-interactive-ui.sh
```

## Command Line Options

- `--unit-only`: Run only unit tests
- `--integration-only`: Run only integration tests
- `--fail-fast`: Stop on first test failure
- `--no-ubuntu`: Skip Ubuntu integration tests
- `--timeout SECONDS`: Set test timeout (default: 3600)
- `--results-dir DIR`: Set results directory
- `--help, -h`: Show help message

## Test Results

### Results Location
Test results are stored in `/path/to/fub/test-results/`:
- `comprehensive_results_YYYYMMDD_HHMMSS.json`: Detailed test results
- `comprehensive_execution_YYYYMMDD_HHMMSS.log`: Execution log
- `performance/`: Performance test reports and baselines
- `ubuntu_test_results.json`: Ubuntu-specific test results

### Result Interpretation
- **Success Rate > 95%**: System is production ready
- **Success Rate 80-95%**: System needs minor fixes
- **Success Rate < 80%**: System has significant issues

### Sample Output
```
🏁 FUB Comprehensive Test Suite - Final Results
═══════════════════════════════════════════════════════════════

📊 Test Suite Breakdown:
   🔬 Unit Tests:        45/45 passed
   🔧 Integration Tests: 12/12 passed
   ⚡ Performance Tests: 8/8 passed
   🐧 Ubuntu Tests:      15/15 passed
   🛡️  Safety Tests:      18/18 passed
   👥 User Acceptance:    10/10 passed

📈 Overall Results:
   Total Tests:   108
   Passed:        108
   Failed:        0
   Success Rate:  100%
   Execution Time: 245s

🎉 ALL TESTS PASSED! System is ready for deployment.
```

## Environment Requirements

### Minimum Requirements
- Bash 4.0+
- Basic Unix tools (find, grep, sed, awk)
- 1GB available disk space
- 512MB available RAM

### Ubuntu-Specific Requirements
- Ubuntu 20.04+ (for Ubuntu integration tests)
- Optional: sudo access (for elevated privilege tests)
- apt, dpkg, systemctl commands

### Optional Dependencies
- gum: For enhanced UI testing (automatically mocked if missing)
- jq: For JSON report processing
- bc: For performance calculations
- curl/wget: For dependency testing

## Configuration

### Test Configuration
Test behavior can be modified through environment variables:

```bash
# Set test mode
export FUB_TEST_MODE="true"
export FUB_COMPREHENSIVE_TEST="true"

# Configure timeouts
export FUB_TEST_TIMEOUT="1800"

# Set results directory
export FUB_TEST_RESULTS_DIR="/custom/results/path"

# Enable verbose output
export FUB_TEST_VERBOSE="true"
```

### Performance Baselines
Performance baselines are automatically created and stored in:
- `${FUB_TEST_RESULTS_DIR}/performance/performance-baseline.json`

To update baselines:
```bash
# Force new baseline creation
export FUB_PERFORMANCE_BASELINE_UPDATE="true"
./tests/test-performance-enhanced.sh
```

## Continuous Integration

### GitHub Actions Example
```yaml
name: FUB Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run Comprehensive Tests
      run: |
        chmod +x tests/test-comprehensive-suite.sh
        ./tests/test-comprehensive-suite.sh --fail-fast
    - name: Upload Test Results
      uses: actions/upload-artifact@v2
      with:
        name: test-results
        path: test-results/
```

### Jenkins Pipeline Example
```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh 'chmod +x tests/test-comprehensive-suite.sh'
                sh './tests/test-comprehensive-suite.sh --fail-fast --timeout 1800'
            }
            post {
                always {
                    publishTestResults testResultsPattern: 'test-results/**/*.json'
                    archiveArtifacts artifacts: 'test-results/**/*'
                }
            }
        }
    }
}
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   chmod +x tests/test-*.sh
   ```

2. **Missing Dependencies**
   ```bash
   # Install missing tools
   sudo apt-get install jq bc curl

   # Or run with minimal requirements
   ./tests/test-comprehensive-suite.sh --no-ubuntu
   ```

3. **Timeout Issues**
   ```bash
   # Increase timeout
   ./tests/test-comprehensive-suite.sh --timeout 7200
   ```

4. **Disk Space Issues**
   ```bash
   # Clean up test data
   rm -rf /tmp/fub-test-*

   # Use custom results directory
   ./tests/test-comprehensive-suite.sh --results-dir /mnt/storage/test-results
   ```

### Debug Mode
Enable detailed logging:
```bash
export FUB_TEST_DEBUG="true"
export FUB_TEST_VERBOSE="true"
./tests/test-comprehensive-suite.sh
```

### Isolated Testing
Run tests in isolated environment:
```bash
# Create isolated test environment
mkdir -p /tmp/fub-isolated
cd /tmp/fub-isolated
git clone /path/to/fub .
cd fub
./tests/test-comprehensive-suite.sh
```

## Contributing

### Adding New Tests
1. Create test file following naming convention: `test-{module}.sh`
2. Source test framework: `source "${TEST_DIR}/test-framework.sh"`
3. Implement `main_test()` function
4. Add to comprehensive suite in `test-comprehensive-suite.sh`
5. Update documentation

### Test Structure Template
```bash
#!/usr/bin/env bash

# Test Description
# Brief description of what this test covers

set -euo pipefail

# Source test framework
source "${TEST_DIR}/test-framework.sh"

# Setup and teardown functions
setup_test() { ... }
teardown_test() { ... }

# Test functions
test_feature_1() { ... }
test_feature_2() { ... }

# Main test function
main_test() {
    setup_test
    print_test_header "Test Suite Name"
    run_test "test_feature_1"
    run_test "test_feature_2"
    teardown_test
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    main_test
    print_test_summary
fi
```

## Best Practices

1. **Run Tests Before Committing**: Always run the test suite before committing changes
2. **Use Mock Environment**: Tests should use mock environments when possible
3. **Test Edge Cases**: Include error conditions and edge cases in tests
4. **Maintain Test Isolation**: Tests should not depend on each other
5. **Update Documentation**: Keep test documentation up to date
6. **Monitor Performance**: Regularly check performance test results
7. **Review Safety Tests**: Pay special attention to safety test failures

## Support

For issues with the test suite:
1. Check this documentation
2. Review test execution logs
3. Run individual test files to isolate issues
4. Check system requirements and dependencies
5. Create GitHub issue with detailed information

## License

This test suite is part of the FUB project and follows the same license terms.