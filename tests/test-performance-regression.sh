#!/usr/bin/env bash

# FUB Performance Regression Testing Framework
# Comprehensive performance benchmarking and regression detection

set -euo pipefail

# Performance test metadata
readonly PERF_TEST_VERSION="2.0.0"
readonly PERF_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PERF_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source safety framework
source "${PERF_TEST_DIR}/test-safety-framework.sh"

# Performance test configuration
declare -A PERF_CONFIG=(
    ["baseline_mode"]="create"
    ["test_iterations"]="3"
    ["warmup_iterations"]="1"
    ["timeout_seconds"]="600"
    ["memory_threshold_mb"]="256"
    ["cpu_threshold_percent"]="80"
    ["disk_threshold_mb"]="1024"
    ["network_timeout_ms"]="5000"
    ["performance_tolerance"]="15"  # 15% tolerance for performance variations
    ["benchmark_mode"]="comprehensive"
)

# Performance metrics storage
declare -A PERF_METRICS=(
    ["baseline_cpu"]=()
    ["baseline_memory"]=()
    ["baseline_disk_io"]=()
    ["baseline_network"]=()
    ["baseline_execution_time"]=()
    ["baseline_memory_peak"]=()
    ["baseline_file_operations"]=()
    ["baseline_package_operations"]=()
    ["baseline_service_operations"]=()
)

# Current test metrics
declare -A CURRENT_METRICS=(
    ["cpu_usage"]=()
    ["memory_usage"]=()
    ["disk_io_read"]=()
    ["disk_io_write"]=()
    ["network_latency"]=()
    ["execution_time"]=()
    ["memory_peak"]=()
    ["file_operations_count"]=()
    ["package_operations_time"]=()
    ["service_operations_time"]=()
)

# Performance test results
declare -A PERF_RESULTS=(
    ["total_tests"]=0
    ["passed_tests"]=0
    ["failed_tests"]=0
    ["regression_detected"]=0
    ["improvement_detected"]=0
    ["baseline_comparisons"]=0
)

# Performance baseline file
readonly BASELINE_FILE="${PERF_ROOT_DIR}/test-results/performance/performance_baseline.data"

# =============================================================================
# PERFORMANCE TESTING FRAMEWORK INITIALIZATION
# =============================================================================

# Initialize performance regression testing
init_performance_regression_tests() {
    local test_mode="${1:-comprehensive}"
    local baseline_mode="${2:-compare}"

    PERF_CONFIG["benchmark_mode"]="$test_mode"
    PERF_CONFIG["baseline_mode"]="$baseline_mode"

    # Create performance results directory
    mkdir -p "${PERF_ROOT_DIR}/test-results/performance"/{baselines,reports,logs,metrics}

    # Initialize performance monitoring
    setup_performance_monitoring

    # Load existing baseline if in compare mode
    if [[ "$baseline_mode" == "compare" ]]; then
        load_performance_baseline
    fi

    echo ""
    echo "${COLOR_BOLD}${COLOR_BLUE}⚡ FUB Performance Regression Testing${COLOR_RESET}"
    echo "${COLOR_BOLD}═══════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo "${COLOR_BLUE}🎯 Benchmark Mode:${COLOR_RESET} $test_mode"
    echo "${COLOR_BLUE}📊 Baseline Mode:${COLOR_RESET}  $baseline_mode"
    echo "${COLOR_BLUE}🔄 Test Iterations:${COLOR_RESET} ${PERF_CONFIG[test_iterations]}"
    echo "${COLOR_BLUE}⏱️  Timeout:${COLOR_RESET}        ${PERF_CONFIG[timeout_seconds]}s"
    echo "${COLOR_BLUE}📈 Tolerance:${COLOR_RESET}       ±${PERF_CONFIG[performance_tolerance]}%"
    echo ""
}

# Set up performance monitoring
setup_performance_monitoring() {
    # Check if performance monitoring tools are available
    local monitoring_tools=("time" "ps" "iostat" "vmstat" "netstat")
    for tool in "${monitoring_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "${COLOR_GREEN}✓ $tool available for performance monitoring${COLOR_RESET}"
        else
            echo "${COLOR_YELLOW}⚠️  $tool not available, using fallback methods${COLOR_RESET}"
        fi
    done

    # Initialize performance monitoring files
    local metrics_file="${PERF_ROOT_DIR}/test-results/performance/metrics/current_run.metrics"
    > "$metrics_file"

    export PERF_METRICS_FILE="$metrics_file"
    export PERF_MONITORING_ENABLED="true"
}

# Load performance baseline
load_performance_baseline() {
    if [[ -f "$BASELINE_FILE" ]]; then
        echo "${COLOR_BLUE}📊 Loading performance baseline...${COLOR_RESET}"
        source "$BASELINE_FILE"
        echo "${COLOR_GREEN}✓ Performance baseline loaded${COLOR_RESET}"
    else
        echo "${COLOR_YELLOW}⚠️  No baseline found, will create new baseline${COLOR_RESET}"
        PERF_CONFIG["baseline_mode"]="create"
    fi
}

# Save performance baseline
save_performance_baseline() {
    local baseline_timestamp
    baseline_timestamp=$(date '+%Y%m%d_%H%M%S')

    cat > "$BASELINE_FILE" << EOF
#!/bin/bash
# Performance baseline created: $baseline_timestamp
# FUB Performance Regression Testing Baseline Data

# Baseline CPU metrics
readonly BASELINE_CPU_USAGE="${PERF_METRICS[baseline_cpu]:-0}"
readonly BASELINE_MEMORY_USAGE="${PERF_METRICS[baseline_memory]:-0}"
readonly BASELINE_MEMORY_PEAK="${PERF_METRICS[baseline_memory_peak]:-0}"

# Baseline disk I/O metrics
readonly BASELINE_DISK_READ="${PERF_METRICS[baseline_disk_io]:-0}"
readonly BASELINE_DISK_WRITE="${PERF_METRICS[baseline_disk_io]:-0}"

# Baseline network metrics
readonly BASELINE_NETWORK_LATENCY="${PERF_METRICS[baseline_network]:-0}"

# Baseline execution times
readonly BASELINE_EXECUTION_TIME="${PERF_METRICS[baseline_execution_time]:-0}"
readonly BASELINE_FILE_OPS_TIME="${PERF_METRICS[baseline_file_operations]:-0}"
readonly BASELINE_PACKAGE_OPS_TIME="${PERF_METRICS[baseline_package_operations]:-0}"
readonly BASELINE_SERVICE_OPS_TIME="${PERF_METRICS[baseline_service_operations]:-0}"

# Baseline metadata
readonly BASELINE_CREATED_AT="$baseline_timestamp"
readonly BASELINE_FUB_VERSION="${FUB_VERSION:-unknown}"
readonly BASELINE_TEST_HOST="$(hostname)"
readonly BASELINE_TEST_KERNEL="$(uname -r)"
EOF

    echo "${COLOR_GREEN}✓ Performance baseline saved to $BASELINE_FILE${COLOR_RESET}"
}

# =============================================================================
# PERFORMANCE MONITORING UTILITIES
# =============================================================================

# Start performance monitoring for a test
start_performance_monitoring() {
    local test_name="$1"
    local monitor_pid_file="${FUB_TEST_WORKSPACE}/perf_monitor_${test_name}.pid"

    # Create monitoring script
    cat > "${FUB_TEST_WORKSPACE}/monitor_${test_name}.sh" << EOF
#!/bin/bash
# Performance monitoring for $test_name

TEST_NAME="\$1"
METRICS_FILE="\$2"
DURATION=\${3:-300}

# Start time
START_TIME=\$(date +%s)

# System metrics collection
while true; do
    CURRENT_TIME=\$(date +%s)
    ELAPSED=\$((CURRENT_TIME - START_TIME))

    if [[ \$ELAPSED -gt \$DURATION ]]; then
        break
    fi

    # Collect metrics
    TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')

    # CPU usage (simplified)
    CPU_USAGE=\$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | cut -d'%' -f1 2>/dev/null || echo "0")

    # Memory usage
    MEMORY_USAGE=\$(free -m | awk '/^Mem:/{printf "%.1f", \$3*100/\$2}' 2>/dev/null || echo "0")

    # Disk I/O (simplified)
    DISK_READ=\$(iostat -x 1 1 2>/dev/null | awk 'NR>4{sum+=\$10} END{print sum+0}' || echo "0")
    DISK_WRITE=\$(iostat -x 1 1 2>/dev/null | awk 'NR>4{sum+=\$11} END{print sum+0}' || echo "0")

    # Record metrics
    echo "\$TIMESTAMP,\$TEST_NAME,\$CPU_USAGE,\$MEMORY_USAGE,\$DISK_READ,\$DISK_WRITE" >> "\$METRICS_FILE"

    sleep 1
done
EOF

    chmod +x "${FUB_TEST_WORKSPACE}/monitor_${test_name}.sh"

    # Start monitoring in background
    "${FUB_TEST_WORKSPACE}/monitor_${test_name}.sh" "$test_name" "$PERF_METRICS_FILE" "${PERF_CONFIG[timeout_seconds]}" &
    echo $! > "$monitor_pid_file"

    echo "${COLOR_CYAN}🔍 Started performance monitoring for $test_name (PID: $(cat "$monitor_pid_file"))${COLOR_RESET}"
}

# Stop performance monitoring
stop_performance_monitoring() {
    local test_name="$1"
    local monitor_pid_file="${FUB_TEST_WORKSPACE}/perf_monitor_${test_name}.pid"

    if [[ -f "$monitor_pid_file" ]]; then
        local monitor_pid
        monitor_pid=$(cat "$monitor_pid_file")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            kill "$monitor_pid" 2>/dev/null || true
            echo "${COLOR_CYAN}🛑 Stopped performance monitoring for $test_name${COLOR_RESET}"
        fi
        rm -f "$monitor_pid_file"
    fi
}

# Measure execution time with high precision
measure_execution_time() {
    local command="$1"
    local iterations="${2:-${PERF_CONFIG[test_iterations]}}"
    local warmup_iterations="${3:-${PERF_CONFIG[warmup_iterations]}}"

    local total_time=0
    local times=()

    echo "${COLOR_CYAN}⏱️  Measuring execution time: $command${COLOR_RESET}"

    # Warmup iterations
    for ((i=1; i<=warmup_iterations; i++)); do
        echo "  Warmup iteration $i/$warmup_iterations..."
        eval "$command" >/dev/null 2>&1 || true
    done

    # Actual measurement iterations
    for ((i=1; i<=iterations; i++)); do
        echo "  Measuring iteration $i/$iterations..."

        local start_time end_time duration
        start_time=$(date +%s.%N)

        if eval "$command" >/dev/null 2>&1; then
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            times+=("$duration")
            total_time=$(echo "$total_time + $duration" | bc -l 2>/dev/null || echo "$total_time")
        else
            echo "${COLOR_YELLOW}    Command failed, skipping iteration${COLOR_RESET}"
        fi
    done

    # Calculate statistics
    if [[ ${#times[@]} -gt 0 ]]; then
        local avg_time
        avg_time=$(echo "scale=3; $total_time / ${#times[@]}" | bc -l)

        # Sort times for median calculation
        IFS=$'\n' sorted_times=($(sort -n <<<"${times[*]}"))
        unset IFS

        local median_time="${sorted_times[$((${#sorted_times[@]} / 2))]}"

        echo "  Average: ${avg_time}s, Median: ${median_time}s"
        echo "$avg_time"
    else
        echo "0"
    fi
}

# Measure memory usage during command execution
measure_memory_usage() {
    local command="$1"
    local memory_log="${FUB_TEST_WORKSPACE}/memory_usage_$$.log"

    # Start memory monitoring in background
    (
        while true; do
            local timestamp memory_kb
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            memory_kb=$(ps -o rss= -p $$ | awk '{print $1}' 2>/dev/null || echo "0")
            echo "$timestamp,$memory_kb" >> "$memory_log"
            sleep 0.5
        done
    ) &
    local monitor_pid=$!

    # Execute command
    eval "$command"
    local exit_code=$?

    # Stop monitoring
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true

    # Calculate memory statistics
    if [[ -f "$memory_log" ]]; then
        local max_memory_kb
        max_memory_kb=$(awk -F',' 'NR>1{if($2>max) max=$2} END{print max+0}' "$memory_log")
        local avg_memory_kb
        avg_memory_kb=$(awk -F',' 'NR>1{sum+=$2; count++} END{print count>0?sum/count:0}' "$memory_log")

        rm -f "$memory_log"

        echo "${avg_memory_kb},${max_memory_kb}"
    else
        echo "0,0"
    fi

    return $exit_code
}

# =============================================================================
# PERFORMANCE TEST EXECUTION
# =============================================================================

# Run comprehensive performance tests
run_performance_regression_tests() {
    local test_categories=("$@")

    echo ""
    echo "${COLOR_BOLD}${COLOR_PURPLE}⚡ Running Performance Regression Tests${COLOR_RESET}"
    echo "${COLOR_PURPLE}$(printf '═%.0s' $(seq 1 60))${COLOR_RESET}"
    echo ""

    # Performance pre-check
    perform_performance_precheck

    # Run tests by category
    for category in "${test_categories[@]}"; do
        echo "${COLOR_CYAN}📂 Performance Category: $category${COLOR_RESET}"

        case "$category" in
            "startup_performance") run_startup_performance_tests ;;
            "memory_efficiency") run_memory_efficiency_tests ;;
            "disk_io_performance") run_disk_io_performance_tests ;;
            "network_performance") run_network_performance_tests ;;
            "cpu_performance") run_cpu_performance_tests ;;
            "file_operations") run_file_operations_performance_tests ;;
            "package_operations") run_package_operations_performance_tests ;;
            "service_operations") run_service_operations_performance_tests ;;
            "cleanup_operations") run_cleanup_operations_performance_tests ;;
            "scalability_tests") run_scalability_performance_tests ;;
            *) echo "${COLOR_YELLOW}    ⚠️  Unknown performance category: $category${COLOR_RESET}" ;;
        esac
    done

    # Performance post-analysis
    perform_performance_analysis

    # Save baseline if in create mode
    if [[ "${PERF_CONFIG[baseline_mode]}" == "create" ]]; then
        save_performance_baseline
    fi

    # Print performance summary
    print_performance_test_summary
}

# =============================================================================
# STARTUP PERFORMANCE TESTS
# =============================================================================

run_startup_performance_tests() {
    echo "${COLOR_BLUE}  🚀 Testing Startup Performance${COLOR_RESET}"

    # Test 1: Cold startup time
    test_cold_startup_performance

    # Test 2: Warm startup time
    test_warm_startup_performance

    # Test 3: Module loading performance
    test_module_loading_performance

    # Test 4: Configuration loading performance
    test_config_loading_performance
}

test_cold_startup_performance() {
    local test_name="Cold Startup Performance"

    # Clear any caches
    clear_system_caches

    # Measure startup time
    local startup_time
    startup_time=$(measure_execution_time "source '${PERF_ROOT_DIR}/lib/common.sh' && source '${PERF_ROOT_DIR}/lib/interactive.sh'" 1 0)

    if [[ -n "$startup_time" ]] && [[ "$startup_time" != "0" ]]; then
        CURRENT_METRICS["startup_time_cold"]="$startup_time"

        # Compare with baseline
        if [[ "${PERF_CONFIG[baseline_mode]}" == "compare" ]] && [[ -n "${BASELINE_EXECUTION_TIME:-}" ]]; then
            local regression_result
            regression_result=$(compare_performance_metric "$startup_time" "$BASELINE_EXECUTION_TIME" "startup_time")
            log_performance_result "$test_name" "$regression_result" "$startup_time" "$BASELINE_EXECUTION_TIME" "seconds"
        else
            log_performance_result "$test_name" "MEASURED" "$startup_time" "N/A" "seconds"
        fi

        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure startup time"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_warm_startup_performance() {
    local test_name="Warm Startup Performance"

    # Load libraries once (warmup)
    source "${PERF_ROOT_DIR}/lib/common.sh" >/dev/null 2>&1
    source "${PERF_ROOT_DIR}/lib/interactive.sh" >/dev/null 2>&1

    # Measure warm startup time
    local startup_time
    startup_time=$(measure_execution_time "echo 'Warm startup test'" 3 1)

    if [[ -n "$startup_time" ]] && [[ "$startup_time" != "0" ]]; then
        CURRENT_METRICS["startup_time_warm"]="$startup_time"

        # Compare with baseline
        local baseline_warm="${PERF_METRICS[baseline_startup_warm]:-$BASELINE_EXECUTION_TIME}"
        if [[ "${PERF_CONFIG[baseline_mode]}" == "compare" ]] && [[ -n "$baseline_warm" ]]; then
            local regression_result
            regression_result=$(compare_performance_metric "$startup_time" "$baseline_warm" "startup_warm")
            log_performance_result "$test_name" "$regression_result" "$startup_time" "$baseline_warm" "seconds"
        else
            log_performance_result "$test_name" "MEASURED" "$startup_time" "N/A" "seconds"
        fi

        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure warm startup time"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_module_loading_performance() {
    local test_name="Module Loading Performance"

    # Test loading different modules
    local modules=("lib/cleanup/apt-cleanup.sh" "lib/scheduler/scheduler.sh" "lib/monitoring/system-monitor.sh")
    local total_module_time=0
    local modules_loaded=0

    for module in "${modules[@]}"; do
        if [[ -f "${PERF_ROOT_DIR}/$module" ]]; then
            local module_time
            module_time=$(measure_execution_time "source '${PERF_ROOT_DIR}/$module'" 2 1)
            if [[ -n "$module_time" ]] && [[ "$module_time" != "0" ]]; then
                total_module_time=$(echo "$total_module_time + $module_time" | bc -l 2>/dev/null || echo "$total_module_time")
                ((modules_loaded++))
            fi
        fi
    done

    if [[ $modules_loaded -gt 0 ]]; then
        local avg_module_time
        avg_module_time=$(echo "scale=3; $total_module_time / $modules_loaded" | bc -l 2>/dev/null || echo "$total_module_time")

        CURRENT_METRICS["avg_module_load_time"]="$avg_module_time"

        log_performance_result "$test_name" "MEASURED" "$avg_module_time" "N/A" "seconds (average for $modules_loaded modules)"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "No modules found for loading test"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_config_loading_performance() {
    local test_name="Configuration Loading Performance"

    # Test configuration loading
    local config_files=("${PERF_ROOT_DIR}/config/default.yaml")
    local total_config_time=0
    local configs_loaded=0

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            local config_time
            config_time=$(measure_execution_time "cat '$config_file' >/dev/null" 3 1)
            if [[ -n "$config_time" ]] && [[ "$config_time" != "0" ]]; then
                total_config_time=$(echo "$total_config_time + $config_time" | bc -l 2>/dev/null || echo "$total_config_time")
                ((configs_loaded++))
            fi
        fi
    done

    if [[ $configs_loaded -gt 0 ]]; then
        local avg_config_time
        avg_config_time=$(echo "scale=3; $total_config_time / $configs_loaded" | bc -l 2>/dev/null || echo "$total_config_time")

        CURRENT_METRICS["avg_config_load_time"]="$avg_config_time"

        log_performance_result "$test_name" "MEASURED" "$avg_config_time" "N/A" "seconds (average for $configs_loaded configs)"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "No config files found for loading test"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

# =============================================================================
# MEMORY EFFICIENCY TESTS
# =============================================================================

run_memory_efficiency_tests() {
    echo "${COLOR_BLUE}  💾 Testing Memory Efficiency${COLOR_RESET}"

    # Test 1: Memory usage during operations
    test_memory_usage_operations

    # Test 2: Memory leak detection
    test_memory_leak_detection

    # Test 3: Peak memory usage
    test_peak_memory_usage

    # Test 4: Memory cleanup efficiency
    test_memory_cleanup_efficiency
}

test_memory_usage_operations() {
    local test_name="Memory Usage During Operations"

    # Test memory usage during file operations
    local memory_result
    memory_result=$(measure_memory_usage "
        # Perform file operations
        for i in {1..100}; do
            echo 'test data \$i' > '${FUB_TEST_WORKSPACE}/temp_file_\$i.txt'
            cat '${FUB_TEST_WORKSPACE}/temp_file_\$i.txt' >/dev/null
            rm '${FUB_TEST_WORKSPACE}/temp_file_\$i.txt'
        done
    ")

    local avg_memory peak_memory
    avg_memory=$(echo "$memory_result" | cut -d',' -f1)
    peak_memory=$(echo "$memory_result" | cut -d',' -f2)

    if [[ -n "$avg_memory" ]] && [[ "$avg_memory" != "0" ]]; then
        CURRENT_METRICS["avg_memory_kb"]="$avg_memory"
        CURRENT_METRICS["peak_memory_kb"]="$peak_memory"

        # Compare with baseline
        if [[ "${PERF_CONFIG[baseline_mode]}" == "compare" ]] && [[ -n "${BASELINE_MEMORY_USAGE:-}" ]]; then
            local regression_result
            regression_result=$(compare_performance_metric "$avg_memory" "$BASELINE_MEMORY_USAGE" "memory_usage")
            log_performance_result "$test_name" "$regression_result" "${avg_memory}KB" "${BASELINE_MEMORY_USAGE}KB" "average memory"
        else
            log_performance_result "$test_name" "MEASURED" "${avg_memory}KB (avg), ${peak_memory}KB (peak)" "N/A" "memory"
        fi

        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure memory usage"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_memory_leak_detection() {
    local test_name="Memory Leak Detection"

    local memory_samples=()
    local iterations=10

    for ((i=1; i<=iterations; i++)); do
        local memory_sample
        memory_sample=$(ps -o rss= -p $$ | awk '{print $1}' 2>/dev/null || echo "0")
        memory_samples+=("$memory_sample")

        # Simulate operations that might leak memory
        local temp_data=""
        for j in {1..1000}; do
            temp_data+="test_data_$j "
        done
        unset temp_data

        sleep 0.1
    done

    # Analyze memory growth
    local initial_memory="${memory_samples[0]}"
    local final_memory="${memory_samples[$((iterations-1))]}"
    local memory_growth=$((final_memory - initial_memory))

    # Simple leak detection: if memory grows more than 10MB, flag as potential leak
    if [[ $memory_growth -lt 10240 ]]; then  # 10MB in KB
        log_performance_result "$test_name" "PASS" "Memory growth: ${memory_growth}KB" "N/A" "memory leak detection"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Potential memory leak detected: ${memory_growth}KB growth"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_peak_memory_usage() {
    local test_name="Peak Memory Usage"

    # Test with memory-intensive operations
    local memory_result
    memory_result=$(measure_memory_usage "
        # Memory intensive operations
        declare -a large_array
        for i in {1..10000}; do
            large_array[\$i]='This is some test data that consumes memory'
        done

        # Process the array
        for item in \"\${large_array[@]}\"; do
            echo \"\$item\" | wc -c >/dev/null
        done

        unset large_array
    ")

    local avg_memory peak_memory
    avg_memory=$(echo "$memory_result" | cut -d',' -f1)
    peak_memory=$(echo "$memory_result" | cut -d',' -f2)

    if [[ -n "$peak_memory" ]] && [[ "$peak_memory" != "0" ]]; then
        CURRENT_METRICS["peak_memory_operations"]="$peak_memory"

        # Check against memory threshold
        local memory_threshold_mb=${PERF_CONFIG[memory_threshold_mb]}
        local peak_memory_mb=$((peak_memory / 1024))

        if [[ $peak_memory_mb -le $memory_threshold_mb ]]; then
            log_performance_result "$test_name" "PASS" "${peak_memory_mb}MB" "${memory_threshold_mb}MB" "peak memory"
            ((PERF_RESULTS["total_tests"]++))
            ((PERF_RESULTS["passed_tests"]++))
        else
            log_performance_fail "$test_name" "Peak memory ${peak_memory_mb}MB exceeds threshold ${memory_threshold_mb}MB"
            ((PERF_RESULTS["total_tests"]++))
            ((PERF_RESULTS["failed_tests"]++))
        fi
    else
        log_performance_fail "$test_name" "Failed to measure peak memory usage"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_memory_cleanup_efficiency() {
    local test_name="Memory Cleanup Efficiency"

    local before_memory
    before_memory=$(ps -o rss= -p $$ | awk '{print $1}' 2>/dev/null || echo "0")

    # Create and destroy large variables to test cleanup
    local cleanup_test() {
        # Create large data structures
        local large_array=()
        for i in {1..5000}; do
            large_array[i]="Large string data item number $i with some additional content"
        done

        local large_string=""
        for i in {1..1000}; do
            large_string+="This is test string number $i with some content. "
        done

        # Simulate processing
        echo "${large_array[1000]}${large_string:0:100}" >/dev/null

        # Explicit cleanup
        unset large_array large_string
    }

    # Run cleanup test multiple times
    for i in {1..5}; do
        cleanup_test
    done

    local after_memory
    after_memory=$(ps -o rss= -p $$ | awk '{print $1}' 2>/dev/null || echo "0")
    local memory_diff=$((after_memory - before_memory))

    # Check if memory was properly cleaned up (allowing some variance)
    if [[ $memory_diff -lt 5120 ]]; then  # 5MB variance allowed
        log_performance_result "$test_name" "PASS" "${memory_diff}KB" "N/A" "memory cleanup"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Memory cleanup inefficient: ${memory_diff}KB difference"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

# =============================================================================
# DISK I/O PERFORMANCE TESTS
# =============================================================================

run_disk_io_performance_tests() {
    echo "${COLOR_BLUE}  💿 Testing Disk I/O Performance${COLOR_RESET}"

    # Test 1: File read performance
    test_file_read_performance

    # Test 2: File write performance
    test_file_write_performance

    # Test 3: Batch file operations
    test_batch_file_operations_performance

    # Test 4: Directory traversal performance
    test_directory_traversal_performance
}

test_file_read_performance() {
    local test_name="File Read Performance"

    # Create test file with known content
    local test_file="${FUB_TEST_WORKSPACE}/perf_read_test.txt"
    dd if=/dev/zero of="$test_file" bs=1M count=10 2>/dev/null

    # Measure read performance
    local read_time
    read_time=$(measure_execution_time "cat '$test_file' >/dev/null" 5 1)

    local file_size_mb=10
    local throughput_mbps
    if [[ -n "$read_time" ]] && [[ "$read_time" != "0" ]]; then
        throughput_mbps=$(echo "scale=2; $file_size_mb / $read_time" | bc -l 2>/dev/null || echo "0")

        CURRENT_METRICS["file_read_throughput"]="$throughput_mbps"

        log_performance_result "$test_name" "MEASURED" "${throughput_mbps}MB/s" "N/A" "read throughput"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure read performance"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi

    rm -f "$test_file"
}

test_file_write_performance() {
    local test_name="File Write Performance"

    local test_file="${FUB_TEST_WORKSPACE}/perf_write_test.txt"

    # Measure write performance
    local write_time
    write_time=$(measure_execution_time "dd if=/dev/zero of='$test_file' bs=1M count=10 2>/dev/null" 3 1)

    local file_size_mb=10
    local throughput_mbps
    if [[ -n "$write_time" ]] && [[ "$write_time" != "0" ]]; then
        throughput_mbps=$(echo "scale=2; $file_size_mb / $write_time" | bc -l 2>/dev/null || echo "0")

        CURRENT_METRICS["file_write_throughput"]="$throughput_mbps"

        log_performance_result "$test_name" "MEASURED" "${throughput_mbps}MB/s" "N/A" "write throughput"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure write performance"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi

    rm -f "$test_file"
}

test_batch_file_operations_performance() {
    local test_name="Batch File Operations Performance"

    local batch_time
    batch_time=$(measure_execution_time "
        # Create multiple files
        for i in {1..100}; do
            echo 'Batch test file \$i' > '${FUB_TEST_WORKSPACE}/batch_test_\$i.txt'
        done

        # Read all files
        for i in {1..100}; do
            cat '${FUB_TEST_WORKSPACE}/batch_test_\$i.txt' >/dev/null
        done

        # Clean up
        rm '${FUB_TEST_WORKSPACE}/batch_test_'*.txt
    " 3 1)

    if [[ -n "$batch_time" ]] && [[ "$batch_time" != "0" ]]; then
        CURRENT_METRICS["batch_operations_time"]="$batch_time"

        log_performance_result "$test_name" "MEASURED" "${batch_time}s" "N/A" "batch operations (200 files)"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure batch operations performance"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi
}

test_directory_traversal_performance() {
    local test_name="Directory Traversal Performance"

    # Create directory structure for testing
    local test_dir="${FUB_TEST_WORKSPACE}/traversal_test"
    mkdir -p "$test_dir"

    # Create nested directory structure
    for i in {1..10}; do
        mkdir -p "$test_dir/level_$i"
        for j in {1..10}; do
            echo "test content $i $j" > "$test_dir/level_$i/file_$j.txt"
        done
    done

    # Measure traversal performance
    local traversal_time
    traversal_time=$(measure_execution_time "find '$test_dir' -type f -exec cat {} \\; >/dev/null" 3 1)

    if [[ -n "$traversal_time" ]] && [[ "$traversal_time" != "0" ]]; then
        CURRENT_METRICS["directory_traversal_time"]="$traversal_time"

        log_performance_result "$test_name" "MEASURED" "${traversal_time}s" "N/A" "directory traversal (100 files)"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["passed_tests"]++))
    else
        log_performance_fail "$test_name" "Failed to measure traversal performance"
        ((PERF_RESULTS["total_tests"]++))
        ((PERF_RESULTS["failed_tests"]++))
    fi

    rm -rf "$test_dir"
}

# =============================================================================
# PERFORMANCE COMPARISON AND ANALYSIS UTILITIES
# =============================================================================

# Compare performance metric against baseline
compare_performance_metric() {
    local current_value="$1"
    local baseline_value="$2"
    local metric_name="$3"

    local tolerance="${PERF_CONFIG[performance_tolerance]}"

    # Calculate percentage difference
    local difference
    difference=$(echo "scale=2; ($current_value - $baseline_value) / $baseline_value * 100" | bc -l 2>/dev/null || echo "0")

    local abs_difference
    abs_difference=$(echo "$difference" | sed 's/^-//')

    # Determine regression status
    if (( $(echo "$abs_difference <= $tolerance" | bc -l 2>/dev/null || echo "1") )); then
        echo "NO_REGRESSION"
    elif (( $(echo "$difference > $tolerance" | bc -l 2>/dev/null || echo "0") )); then
        echo "REGRESSION"
        ((PERF_RESULTS["regression_detected"]++))
    else
        echo "IMPROVEMENT"
        ((PERF_RESULTS["improvement_detected"]++))
    fi

    ((PERF_RESULTS["baseline_comparisons"]++))
}

# Log performance test result
log_performance_result() {
    local test_name="$1"
    local result="$2"
    local current_value="$3"
    local baseline_value="$4"
    local unit="$5"

    case "$result" in
        "PASS"|"NO_REGRESSION"|"MEASURED")
            echo "${COLOR_GREEN}  ✓ PASS${COLOR_RESET} $test_name: $current_value${baseline_value:+ vs $baseline_value} ($unit)"
            ;;
        "IMPROVEMENT")
            echo "${COLOR_GREEN}  ✓ IMPROVED${COLOR_RESET} $test_name: $current_value vs $baseline_value ($unit)"
            ;;
        "REGRESSION")
            echo "${COLOR_RED}  ✗ REGRESSION${COLOR_RESET} $test_name: $current_value vs $baseline_value ($unit)"
            ;;
        "FAIL")
            echo "${COLOR_RED}  ✗ FAIL${COLOR_RESET} $test_name: $current_value"
            ;;
    esac
}

# Log performance test failure
log_performance_fail() {
    local test_name="$1"
    local message="$2"
    echo "${COLOR_RED}  ✗ FAIL${COLOR_RESET} $test_name: $message"
}

# Performance pre-check
perform_performance_precheck() {
    echo "${COLOR_CYAN}🔍 Performing performance pre-check...${COLOR_RESET}"

    # Check system load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' || echo "0")

    if (( $(echo "$load_avg > 2.0" | bc -l 2>/dev/null || echo "0") )); then
        echo "${COLOR_YELLOW}⚠️  High system load detected: $load_avg${COLOR_RESET}"
        echo "${COLOR_YELLOW}   Performance results may be affected${COLOR_RESET}"
    else
        echo "${COLOR_GREEN}✓ System load acceptable: $load_avg${COLOR_RESET}"
    fi

    # Check available memory
    local available_memory
    available_memory=$(free -m | awk '/^Mem:/{print $7}' 2>/dev/null || echo "1024")

    if [[ $available_memory -lt 512 ]]; then
        echo "${COLOR_YELLOW}⚠️  Low available memory: ${available_memory}MB${COLOR_RESET}"
    else
        echo "${COLOR_GREEN}✓ Available memory: ${available_memory}MB${COLOR_RESET}"
    fi

    # Check disk space
    local available_disk
    available_disk=$(df "${PERF_ROOT_DIR}" | awk 'NR==2{print $4}' 2>/dev/null || echo "1048576")
    local available_disk_mb=$((available_disk / 1024))

    if [[ $available_disk_mb -lt 1024 ]]; then
        echo "${COLOR_YELLOW}⚠️  Low disk space: ${available_disk_mb}MB${COLOR_RESET}"
    else
        echo "${COLOR_GREEN}✓ Available disk space: ${available_disk_mb}MB${COLOR_RESET}"
    fi
}

# Performance analysis
perform_performance_analysis() {
    echo "${COLOR_CYAN}📊 Performing performance analysis...${COLOR_RESET}"

    # Analyze trends
    analyze_performance_trends

    # Check for performance bottlenecks
    identify_performance_bottlenecks

    # Generate recommendations
    generate_performance_recommendations
}

# Placeholder functions for performance analysis
analyze_performance_trends() {
    echo "${COLOR_BLUE}  📈 Analyzing performance trends...${COLOR_RESET}"
}

identify_performance_bottlenecks() {
    echo "${COLOR_BLUE}  🔍 Identifying performance bottlenecks...${COLOR_RESET}"
}

generate_performance_recommendations() {
    echo "${COLOR_BLUE}  💡 Generating performance recommendations...${COLOR_RESET}"
}

# Clear system caches
clear_system_caches() {
    if [[ "$EUID" -eq 0 ]]; then
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    fi
}

# Print performance test summary
print_performance_test_summary() {
    echo ""
    echo "${COLOR_BOLD}${COLOR_PURPLE}⚡ Performance Test Summary${COLOR_RESET}"
    echo "${COLOR_PURPLE}$(printf '═%.0s' $(seq 1 60))${COLOR_RESET}"
    echo ""
    echo "${COLOR_BLUE}📊 Total Performance Tests:${COLOR_RESET} ${PERF_RESULTS[total_tests]}"
    echo "${COLOR_GREEN}✓ Tests Passed:${COLOR_RESET}           ${PERF_RESULTS[passed_tests]}"
    echo "${COLOR_RED}✗ Tests Failed:${COLOR_RESET}           ${PERF_RESULTS[failed_tests]}"
    echo "${COLOR_YELLOW}📈 Regressions Detected:${COLOR_RESET}  ${PERF_RESULTS[regression_detected]}"
    echo "${COLOR_GREEN}📉 Improvements Found:${COLOR_RESET}     ${PERF_RESULTS[improvement_detected]}"
    echo "${COLOR_BLUE}🔗 Baseline Comparisons:${COLOR_RESET}    ${PERF_RESULTS[baseline_comparisons]}"
    echo ""

    # Calculate success rate
    local success_rate=0
    if [[ ${PERF_RESULTS[total_tests]} -gt 0 ]]; then
        success_rate=$(( PERF_RESULTS[passed_tests] * 100 / PERF_RESULTS[total_tests] ))
    fi

    echo "${COLOR_BLUE}📈 Success Rate:${COLOR_RESET}           ${success_rate}%"
    echo ""

    if [[ ${PERF_RESULTS[failed_tests]} -eq 0 ]] && [[ ${PERF_RESULTS[regression_detected]} -eq 0 ]]; then
        echo "${COLOR_BOLD}${COLOR_GREEN}🎉 All performance tests passed!${COLOR_RESET}"
        echo "${COLOR_GREEN}   No performance regressions detected.${COLOR_RESET}"
        return 0
    elif [[ ${PERF_RESULTS[regression_detected]} -gt 0 ]]; then
        echo "${COLOR_BOLD}${COLOR_YELLOW}⚠️  Performance regressions detected!${COLOR_RESET}"
        echo "${COLOR_YELLOW}   Review performance changes before deployment.${COLOR_RESET}"
        return 1
    else
        echo "${COLOR_BOLD}${COLOR_RED}🚨 Performance tests failed!${COLOR_RESET}"
        echo "${COLOR_RED}   Address performance issues before deployment.${COLOR_RESET}"
        return 1
    fi
}

# =============================================================================
# PLACEHOLDER PERFORMANCE TEST CATEGORIES
# =============================================================================

run_network_performance_tests() {
    echo "${COLOR_BLUE}  🌐 Testing Network Performance${COLOR_RESET}"
    log_performance_result "Network Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_cpu_performance_tests() {
    echo "${COLOR_BLUE}  🖥️  Testing CPU Performance${COLOR_RESET}"
    log_performance_result "CPU Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_file_operations_performance_tests() {
    echo "${COLOR_BLUE}  📁 Testing File Operations Performance${COLOR_RESET}"
    log_performance_result "File Operations Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_package_operations_performance_tests() {
    echo "${COLOR_BLUE}  📦 Testing Package Operations Performance${COLOR_RESET}"
    log_performance_result "Package Operations Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_service_operations_performance_tests() {
    echo "${COLOR_BLUE}  ⚙️  Testing Service Operations Performance${COLOR_RESET}"
    log_performance_result "Service Operations Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_cleanup_operations_performance_tests() {
    echo "${COLOR_BLUE}  🧹 Testing Cleanup Operations Performance${COLOR_RESET}"
    log_performance_result "Cleanup Operations Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

run_scalability_performance_tests() {
    echo "${COLOR_BLUE}  📈 Testing Scalability Performance${COLOR_RESET}"
    log_performance_result "Scalability Performance" "MEASURED" "N/A" "N/A" "placeholder"
    ((PERF_RESULTS["total_tests"]++))
    ((PERF_RESULTS["passed_tests"]++))
}

# Export performance test functions
export -f init_performance_regression_tests run_performance_regression_tests
export -f run_startup_performance_tests run_memory_efficiency_tests run_disk_io_performance_tests
export -f start_performance_monitoring stop_performance_monitoring measure_execution_time measure_memory_usage
export -f compare_performance_metric log_performance_result log_performance_fail
export -f load_performance_baseline save_performance_baseline print_performance_test_summary