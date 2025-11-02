#!/usr/bin/env bash

# FUB Service and Container Monitor Module
# Detection and protection of running services and containers

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Service monitor constants
readonly SERVICE_MONITOR_VERSION="1.0.0"
readonly SERVICE_MONITOR_DESCRIPTION="Service and container detection and protection"

# Critical system services (should not be stopped)
declare -a CRITICAL_SYSTEM_SERVICES=(
    "systemd-journald" "systemd-logind" "systemd-udevd"
    "dbus" "networkd-dispatcher" "resolved"
    "cron" "atd" "sshd" "getty"
    "kernel" "init"
)

# Important user services (warn before stopping)
declare -a IMPORTANT_USER_SERVICES=(
    "docker" "containerd" "podman" "kubelet"
    "mysql" "mariadb" "postgresql" "redis"
    "nginx" "apache2" "httpd" "caddy"
    "php-fpm" "node" "python" "java"
)

# Database services (require careful handling)
declare -a DATABASE_SERVICES=(
    "mysql" "mysqld" "mariadb" "postgresql" "postgres"
    "mongodb" "mongod" "redis-server" "redis"
    "elasticsearch" "influxdb" "cassandra"
)

# Web services
declare -a WEB_SERVICES=(
    "nginx" "apache2" "httpd" "caddy" "lighttpd"
    "tomcat" "jetty" "wildfly" "jboss"
)

# Initialize service monitor module
init_service_monitor() {
    log_info "Initializing service monitor module v$SERVICE_MONITOR_VERSION"
    log_debug "Service monitor module initialized"
}

# Check if service is active using multiple methods
is_service_active() {
    local service="$1"

    # Try systemd first
    if command_exists systemctl; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            return 0
        fi
    fi

    # Try service command
    if command_exists service; then
        if service "$service" status >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Try process checking
    if pgrep -f "$service" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Get service details
get_service_details() {
    local service="$1"
    local details=""

    # Try systemctl for detailed info
    if command_exists systemctl; then
        if systemctl list-unit-files | grep -q "^$service.service"; then
            local enabled_status
            enabled_status=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
            local active_status
            active_status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            details="enabled=$enabled_status, active=$active_status"
        fi
    fi

    echo "$details"
}

# Detect running system services
detect_system_services() {
    print_section "Detecting System Services"

    local critical_running=0
    local important_running=0
    local other_services=0

    # Check critical system services
    print_info "Checking critical system services..."
    for service in "${CRITICAL_SYSTEM_SERVICES[@]}"; do
        if is_service_active "$service"; then
            ((critical_running++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                local details
                details=$(get_service_details "$service")
                print_indented 2 "$(format_status "success" "$service ($details)")"
            fi
        fi
    done

    # Check important user services
    print_info "Checking important user services..."
    for service in "${IMPORTANT_USER_SERVICES[@]}"; do
        if is_service_active "$service"; then
            ((important_running++))
            local details
            details=$(get_service_details "$service")
            print_indented 2 "$(format_status "warning" "$service ($details)")"
        fi
    done

    # Get other active services (systemd)
    if command_exists systemctl; then
        local other_count
        other_count=$(systemctl list-units --type=service --state=active --no-legend | wc -l)
        other_services=$((other_count - critical_running - important_running))
    fi

    # Report findings
    print_success "Critical system services: $critical_running"
    print_warning "Important user services: $important_running"
    print_info "Other active services: $other_services"

    # Export for other modules
    export FUB_CRITICAL_SERVICES="$critical_running"
    export FUB_IMPORTANT_SERVICES="$important_running"
    export FUB_OTHER_SERVICES="$other_services"

    return 0
}

# Detect database services specifically
detect_database_services() {
    print_section "Detecting Database Services"

    local db_services_running=0
    local -a active_db_services

    for db_service in "${DATABASE_SERVICES[@]}"; do
        if is_service_active "$db_service"; then
            ((db_services_running++))
            active_db_services+=("$db_service")
            print_indented 2 "$(format_status "warning" "$db_service")"
        fi
    done

    # Check for database processes that might not be registered as services
    local db_processes
    db_processes=$(pgrep -f "mysqld\|postgres\|mongod\|redis-server" 2>/dev/null | wc -l || echo "0")
    if [[ $db_processes -gt $db_services_running ]]; then
        print_info "Additional database processes detected: $((db_processes - db_services_running))"
    fi

    if [[ $db_services_running -gt 0 ]]; then
        print_warning "Database services detected: $db_services_running"
        print_warning "Database cleanup requires special handling"
        export FUB_DB_SERVICES="${active_db_services[*]}"
    else
        print_success "No database services detected"
        export FUB_DB_SERVICES=""
    fi

    return 0
}

# Detect web services
detect_web_services() {
    print_section "Detecting Web Services"

    local web_services_running=0
    local -a active_web_services

    for web_service in "${WEB_SERVICES[@]}"; do
        if is_service_active "$web_service"; then
            ((web_services_running++))
            active_web_services+=("$web_service")
            print_indented 2 "$(format_status "warning" "$web_service")"
        fi
    done

    # Check for common web server ports
    local -a web_ports=(80 443 8080 8443 3000 5000 8000 9000)
    local ports_in_use=0

    for port in "${web_ports[@]}"; do
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            ((ports_in_use++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 4 "$(format_status "info" "Port $port in use")"
            fi
        fi
    done

    if [[ $web_services_running -gt 0 ]] || [[ $ports_in_use -gt 0 ]]; then
        print_warning "Web services detected: $web_services_running"
        print_info "Web server ports in use: $ports_in_use"
        export FUB_WEB_SERVICES="${active_web_services[*]}"
    else
        print_success "No web services detected"
        export FUB_WEB_SERVICES=""
    fi

    return 0
}

# Detect Docker containers
detect_docker_containers() {
    print_section "Detecting Docker Containers"

    local containers_running=0
    local containers_total=0
    local containers_paused=0

    if command_exists docker; then
        # Check if Docker daemon is running
        if ! docker info >/dev/null 2>&1; then
            print_info "Docker daemon is not running"
            return 0
        fi

        # Get container statistics
        containers_total=$(docker ps -a --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")
        containers_running=$(docker ps --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")
        containers_paused=$(docker ps --filter "status=paused" --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")

        if [[ $containers_total -gt 0 ]]; then
            print_info "Total Docker containers: $containers_total"
            print_warning "Running containers: $containers_running"

            if [[ $containers_paused -gt 0 ]]; then
                print_info "Paused containers: $containers_paused"
            fi

            # Show important containers if verbose
            if [[ "$SAFETY_VERBOSE" == "true" ]] && [[ $containers_running -gt 0 ]]; then
                print_indented 2 "$(format_status "info" "Running containers:")"
                docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | while IFS= read -r line; do
                    print_indented 4 "$line"
                done
            fi

            # Check for important container types
            local db_containers
            db_containers=$(docker ps --format "{{.Image}}" 2>/dev/null | grep -i "mysql\|postgres\|mongo\|redis" | wc -l || echo "0")
            if [[ $db_containers -gt 0 ]]; then
                print_warning "Database containers running: $db_containers"
            fi
        else
            print_success "No Docker containers detected"
        fi
    else
        print_info "Docker is not installed"
    fi

    # Export container counts
    export FUB_DOCKER_CONTAINERS="$containers_running"
    export FUB_DOCKER_TOTAL="$containers_total"

    return 0
}

# Detect Podman containers
detect_podman_containers() {
    print_section "Detecting Podman Containers"

    local containers_running=0
    local containers_total=0

    if command_exists podman; then
        # Get container statistics
        containers_total=$(podman ps -a --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")
        containers_running=$(podman ps --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")

        if [[ $containers_total -gt 0 ]]; then
            print_info "Total Podman containers: $containers_total"
            print_warning "Running containers: $containers_running"

            # Show important containers if verbose
            if [[ "$SAFETY_VERBOSE" == "true" ]] && [[ $containers_running -gt 0 ]]; then
                print_indented 2 "$(format_status "info" "Running containers:")"
                podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | while IFS= read -r line; do
                    print_indented 4 "$line"
                done
            fi
        else
            print_success "No Podman containers detected"
        fi
    else
        print_info "Podman is not installed"
    fi

    # Export container counts
    export FUB_PODMAN_CONTAINERS="$containers_running"
    export FUB_PODMAN_TOTAL="$containers_total"

    return 0
}

# Detect development servers
detect_development_servers() {
    print_section "Detecting Development Servers"

    local dev_servers=0
    local -a detected_servers

    # Common development server processes
    local -a dev_server_patterns=(
        "node.*server" "npm.*start" "yarn.*start" "python.*-m.*http.server"
        "python.*manage.py.*runserver" "flask.*run" "django.*runserver"
        "webpack.*serve" "parcel.*serve" "vite" "next.*dev"
        "rails.*server" "php.*-S" "python.*app.py" "go.*run"
        "live-server" "browser-sync" "http-server"
    )

    for pattern in "${dev_server_patterns[@]}"; do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            local process_count
            process_count=$(pgrep -f "$pattern" | wc -l)
            detected_servers+=("$pattern:$process_count")
            ((dev_servers += process_count))

            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "$pattern: $process_count processes")"
            fi
        fi
    done

    # Check for common development server ports
    local -a dev_ports=(3000 3001 4000 5000 5001 6000 7000 8000 8001 8080 8081 9000 9001)
    local dev_ports_in_use=0

    for port in "${dev_ports[@]}"; do
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            ((dev_ports_in_use++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 4 "$(format_status "info" "Dev port $port in use")"
            fi
        fi
    done

    if [[ $dev_servers -gt 0 ]] || [[ $dev_ports_in_use -gt 0 ]]; then
        print_warning "Development servers detected: $dev_servers processes"
        print_info "Development ports in use: $dev_ports_in_use"
        export FUB_DEV_SERVERS="$dev_servers"
    else
        print_success "No development servers detected"
        export FUB_DEV_SERVERS="0"
    fi

    return 0
}

# Analyze service impact
analyze_service_impact() {
    print_section "Analyzing Service Impact"

    local impact_score=0
    local impact_details=()

    # Database services have high impact
    if [[ -n "$FUB_DB_SERVICES" ]]; then
        impact_score=$((impact_score + 30))
        impact_details+=("Database services: ${#FUB_DB_SERVICES[@]}")
    fi

    # Web services have medium impact
    if [[ -n "$FUB_WEB_SERVICES" ]]; then
        impact_score=$((impact_score + 20))
        impact_details+=("Web services: ${#FUB_WEB_SERVICES[@]}")
    fi

    # Containers have medium impact
    if [[ $FUB_DOCKER_CONTAINERS -gt 0 ]] || [[ $FUB_PODMAN_CONTAINERS -gt 0 ]]; then
        local total_containers=$((FUB_DOCKER_CONTAINERS + FUB_PODMAN_CONTAINERS))
        impact_score=$((impact_score + 15))
        impact_details+=("Running containers: $total_containers")
    fi

    # Development servers have low impact
    if [[ $FUB_DEV_SERVERS -gt 0 ]]; then
        impact_score=$((impact_score + 10))
        impact_details+=("Development servers: $FUB_DEV_SERVERS")
    fi

    # Important services have medium impact
    if [[ $FUB_IMPORTANT_SERVICES -gt 0 ]]; then
        impact_score=$((impact_score + 25))
        impact_details+=("Important services: $FUB_IMPORTANT_SERVICES")
    fi

    # Report impact analysis
    print_info "Service impact score: $impact_score"

    if [[ $impact_score -gt 50 ]]; then
        print_error "HIGH IMPACT: Many critical services detected"
        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Proceed despite high service impact?" "Cleanup may affect critical services"; then
                print_info "Cleanup cancelled - high service impact"
                return 1
            fi
        fi
    elif [[ $impact_score -gt 25 ]]; then
        print_warning "MEDIUM IMPACT: Several services detected"
        print_info "Proceed with caution"
    else
        print_success "LOW IMPACT: Minimal service impact expected"
    fi

    if [[ ${#impact_details[@]} -gt 0 ]] && [[ "$SAFETY_VERBOSE" == "true" ]]; then
        print_info "Impact details:"
        for detail in "${impact_details[@]}"; do
            print_indented 2 "$detail"
        done
    fi

    return 0
}

# Create service backup
create_service_backup() {
    if [[ "$SAFETY_BACKUP_IMPORTANT" != "true" ]]; then
        return 0
    fi

    print_section "Creating Service Backup"

    local backup_dir="/tmp/fub_service_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    local backed_up_services=0

    # Backup service configurations
    if command_exists systemctl; then
        # List enabled services
        systemctl list-unit-files --state=enabled --type=service --no-legend | awk '{print $1}' > "$backup_dir/enabled_services.txt"

        # Backup important service configurations
        local -a important_service_configs=(
            "/etc/docker" "/etc/containers" "/etc/mysql" "/etc/postgresql"
            "/etc/nginx" "/etc/apache2" "/etc/httpd" "/etc/redis"
        )

        for config_dir in "${important_service_configs[@]}"; do
            if [[ -d "$config_dir" ]]; then
                local backup_path="$backup_dir$(dirname "$config_dir")"
                mkdir -p "$backup_path"
                if cp -r "$config_dir" "$backup_dir$config_dir" 2>/dev/null; then
                    ((backed_up_services++))
                    if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "success" "Backed up: $config_dir")"
                    fi
                fi
            fi
        done
    fi

    # Report backup summary
    if [[ $backed_up_services -gt 0 ]]; then
        print_success "Service backup created: $backup_dir"
        print_info "Backed up configurations: $backed_up_services"
        print_info "Backup will be kept for 24 hours"

        # Schedule cleanup of backup directory
        echo "find '$backup_dir' -type f -mtime +1 -delete 2>/dev/null; find '$backup_dir' -type d -empty -delete 2>/dev/null" | at now + 24 hours 2>/dev/null || true
    else
        rmdir "$backup_dir" 2>/dev/null || true
        print_info "No service configurations required backup"
    fi

    return 0
}

# Perform comprehensive service monitoring
perform_service_monitoring() {
    print_header "Service and Container Monitoring"
    print_info "Detecting and analyzing running services and containers"

    local monitoring_failed=false

    # Initialize module
    init_service_monitor

    # Run all service detection checks
    if ! detect_system_services; then
        monitoring_failed=true
    fi

    if ! detect_database_services; then
        monitoring_failed=true
    fi

    if ! detect_web_services; then
        monitoring_failed=true
    fi

    if ! detect_docker_containers; then
        monitoring_failed=true
    fi

    if ! detect_podman_containers; then
        monitoring_failed=true
    fi

    if ! detect_development_servers; then
        monitoring_failed=true
    fi

    # Analyze impact
    if ! analyze_service_impact; then
        monitoring_failed=true
    fi

    # Create backup if requested and no failures
    if [[ "$monitoring_failed" != "true" ]]; then
        create_service_backup
    fi

    if [[ "$monitoring_failed" == "true" ]]; then
        print_error "Service monitoring failed"
        return 1
    else
        print_success "Service monitoring completed"
        return 0
    fi
}

# Show service monitor help
show_service_monitor_help() {
    cat << EOF
${BOLD}${CYAN}Service and Container Monitor Module${RESET}
${ITALIC}Detection and protection of running services and containers${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source service-monitor.sh${RESET}
    ${GREEN}perform_service_monitoring${RESET}

${BOLD}Functions:${RESET}
    ${YELLOW}detect_system_services${RESET}         Detect critical and important system services
    ${YELLOW}detect_database_services${RESET}        Detect database services specifically
    ${YELLOW}detect_web_services${RESET}             Detect web server services
    ${YELLOW}detect_docker_containers${RESET}        Detect running Docker containers
    ${YELLOW}detect_podman_containers${RESET}        Detect running Podman containers
    ${YELLOW}detect_development_servers${RESET}      Detect development server processes
    ${YELLOW}analyze_service_impact${RESET}          Analyze potential impact of cleanup
    ${YELLOW}create_service_backup${RESET}           Backup service configurations
    ${YELLOW}perform_service_monitoring${RESET}      Run all service detection

${BOLD}Service Categories:${RESET}
    • Critical: System services that should never be stopped
    • Important: User services that require careful handling
    • Database: Database services requiring special procedures
    • Web: Web servers and related services
    • Development: Development servers and tools

${BOLD}Container Support:${RESET}
    • Docker containers and images
    • Podman containers and images
    • Container status and resource usage
    • Database container detection

${BOLD}Impact Analysis:${RESET}
    • Calculates potential impact of cleanup operations
    • Provides risk assessment based on running services
    • Recommends caution levels for different scenarios

EOF
}

# Export functions for use in other scripts
export -f init_service_monitor is_service_active get_service_details
export -f detect_system_services detect_database_services detect_web_services
export -f detect_docker_containers detect_podman_containers detect_development_servers
export -f analyze_service_impact create_service_backup perform_service_monitoring
export -f show_service_monitor_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    perform_service_monitoring
fi