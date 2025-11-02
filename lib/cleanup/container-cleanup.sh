#!/usr/bin/env bash

# FUB Container Cleanup Module
# Comprehensive cleanup for Docker, Podman, and container runtime resources

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Container cleanup constants
readonly CONTAINER_CLEANUP_VERSION="1.0.0"
readonly CONTAINER_CLEANUP_DESCRIPTION="Container runtime cleanup utilities"

# Container cleanup configuration
CONTAINER_DRY_RUN=false
CONTAINER_VERBOSE=false
CONTAINER_FORCE=false
CONTAINER_KEEP_IMAGES=3
CONTAINER_KEEP_VOLUMES=false
CONTAINER_PRUNE_UNUSED=true

# Initialize container cleanup module
init_container_cleanup() {
    log_info "Initializing container cleanup module v$CONTAINER_CLEANUP_VERSION"

    # Check for available container runtimes
    local runtimes=()
    command_exists docker && runtimes+=("docker")
    command_exists podman && runtimes+=("podman")

    if [[ ${#runtimes[@]} -eq 0 ]]; then
        log_debug "No container runtimes found"
    else
        log_debug "Found container runtimes: ${runtimes[*]}"
    fi

    log_debug "Container cleanup module initialized"
}

# Detect available container runtimes
detect_container_runtimes() {
    print_section "Detecting Container Runtimes"

    local -a detected_runtimes=()

    if command_exists docker; then
        detected_runtimes+=("docker")
        print_success "Docker detected"
    fi

    if command_exists podman; then
        detected_runtimes+=("podman")
        print_success "Podman detected"
    fi

    if [[ ${#detected_runtimes[@]} -eq 0 ]]; then
        print_info "No container runtimes found"
        return 1
    else
        print_info "Found ${#detected_runtimes[@]} container runtime(s): ${detected_runtimes[*]}"
        return 0
    fi
}

# Get Docker system information
get_docker_info() {
    local info_type="$1"

    if ! command_exists docker; then
        echo "0"
        return 1
    fi

    case "$info_type" in
        "containers")
            docker ps -a --format "table {{.Names}}" 2>/dev/null | tail -n +2 | wc -l || echo "0"
            ;;
        "running")
            docker ps --format "table {{.Names}}" 2>/dev/null | tail -n +2 | wc -l || echo "0"
            ;;
        "images")
            docker images --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | tail -n +2 | wc -l || echo "0"
            ;;
        "volumes")
            docker volume ls --format "table {{.Name}}" 2>/dev/null | tail -n +2 | wc -l || echo "0"
            ;;
        "networks")
            docker network ls --format "table {{.Name}}" 2>/dev/null | tail -n +2 | wc -l || echo "0"
            ;;
        "size")
            docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}" 2>/dev/null || echo "N/A"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# Get Podman system information
get_podman_info() {
    local info_type="$1"

    if ! command_exists podman; then
        echo "0"
        return 1
    fi

    case "$info_type" in
        "containers")
            podman ps -a --format "{{.Names}}" 2>/dev/null | wc -l || echo "0"
            ;;
        "running")
            podman ps --format "{{.Names}}" 2>/dev/null | wc -l || echo "0"
            ;;
        "images")
            podman images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | wc -l || echo "0"
            ;;
        "volumes")
            podman volume ls --format "{{.Name}}" 2>/dev/null | wc -l || echo "0"
            ;;
        "networks")
            podman network ls --format "{{.Name}}" 2>/dev/null | wc -l || echo "0"
            ;;
        "size")
            podman system df --format "{{.Type}}\t{{.TotalCount}}\t{{.Size}}" 2>/dev/null || echo "N/A"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# Show container system status
show_container_status() {
    print_section "Container System Status"

    if ! detect_container_runtimes; then
        return 1
    fi

    # Docker status
    if command_exists docker; then
        print_info "Docker Status:"
        local containers=$(get_docker_info "containers")
        local running=$(get_docker_info "running")
        local images=$(get_docker_info "images")
        local volumes=$(get_docker_info "volumes")
        local networks=$(get_docker_info "networks")

        print_indented 2 "Containers: $containers total, $running running"
        print_indented 2 "Images: $images"
        print_indented 2 "Volumes: $volumes"
        print_indented 2 "Networks: $networks"

        if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
            echo ""
            get_docker_info "size" | while IFS=$'\t' read -r type count size; do
                if [[ "$type" != "TYPE" ]]; then
                    print_indented 2 "$type: $count ($size)"
                fi
            done
        fi
    fi

    # Podman status
    if command_exists podman; then
        echo ""
        print_info "Podman Status:"
        local containers=$(get_podman_info "containers")
        local running=$(get_podman_info "running")
        local images=$(get_podman_info "images")
        local volumes=$(get_podman_info "volumes")
        local networks=$(get_podman_info "networks")

        print_indented 2 "Containers: $containers total, $running running"
        print_indented 2 "Images: $images"
        print_indented 2 "Volumes: $volumes"
        print_indented 2 "Networks: $networks"

        if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
            echo ""
            get_podman_info "size" | while IFS=$'\t' read -r type count size; do
                if [[ "$type" != "TYPE" ]]; then
                    print_indented 2 "$type: $count ($size)"
                fi
            done
        fi
    fi
}

# Clean Docker containers
cleanup_docker_containers() {
    if ! command_exists docker; then
        return 0
    fi

    print_section "Cleaning Docker Containers"

    local total_removed=0
    local total_freed=0

    # Remove stopped containers
    local stopped_containers
    stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null || true)

    if [[ -n "$stopped_containers" ]]; then
        local stopped_count
        stopped_count=$(echo "$stopped_containers" | wc -l)

        print_info "Found $stopped_count stopped containers"

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove $stopped_count stopped containers")"
        else
            local removed_count=0
            echo "$stopped_containers" | while read -r container; do
                if [[ -n "$container" ]]; then
                    if docker rm "$container" 2>/dev/null; then
                        ((removed_count++))
                        if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
                            print_indented 2 "Removed container: $container"
                        fi
                    fi
                fi
            done
            print_success "Removed $stopped_count stopped containers"
        fi
    else
        print_info "No stopped containers found"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Docker images
cleanup_docker_images() {
    if ! command_exists docker; then
        return 0
    fi

    print_section "Cleaning Docker Images"

    local total_removed=0
    local total_freed=0

    # Remove dangling images (untagged)
    local dangling_images
    dangling_images=$(docker images --filter "dangling=true" --format "{{.ID}}" 2>/dev/null || true)

    if [[ -n "$dangling_images" ]]; then
        local dangling_count
        dangling_count=$(echo "$dangling_images" | wc -l)

        print_info "Found $dangling_count dangling images"

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove $dangling_count dangling images")"
        else
            if docker rmi $(echo "$dangling_images") 2>/dev/null; then
                print_success "Removed $dangling_count dangling images"
            else
                print_warning "Failed to remove some dangling images"
            fi
        fi
    fi

    # Remove old images (keep latest N)
    local all_images
    all_images=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" 2>/dev/null | tail -n +2 || true)

    if [[ -n "$all_images" ]]; then
        # Group by repository and keep latest N images
        local -A repo_images
        while IFS=$'\t' read -r name image_id created_at; do
            if [[ -n "$name" && -n "$image_id" ]]; then
                local repo="${name%:*}"
                if [[ -n "${repo_images[$repo]:-}" ]]; then
                    repo_images[$repo]="${repo_images[$repo]}|$image_id:$created_at"
                else
                    repo_images[$repo]="$image_id:$created_at"
                fi
            fi
        done <<< "$all_images"

        for repo in "${!repo_images[@]}"; do
            IFS='|' read -ra images <<< "${repo_images[$repo]}"

            # Sort by creation date and remove old ones
            local sorted_images=($(printf '%s\n' "${images[@]}" | sort -r -k2 -t':'))

            if [[ ${#sorted_images[@]} -gt $CONTAINER_KEEP_IMAGES ]]; then
                local old_images=("${sorted_images[@]:$CONTAINER_KEEP_IMAGES}")

                for old_image in "${old_images[@]}"; do
                    local image_id="${old_image%:*}"
                    if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Would remove old image: $image_id")"
                    else
                        if docker rmi "$image_id" 2>/dev/null; then
                            ((total_removed++))
                            if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
                                print_indented 2 "Removed old image: $image_id"
                            fi
                        fi
                    fi
                done
            fi
        done
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Docker volumes
cleanup_docker_volumes() {
    if ! command_exists docker; then
        return 0
    fi

    print_section "Cleaning Docker Volumes"

    local total_removed=0
    local total_freed=0

    # Remove unused volumes
    local unused_volumes
    unused_volumes=$(docker volume ls --filter "dangling=true" --format "{{.Name}}" 2>/dev/null || true)

    if [[ -n "$unused_volumes" ]]; then
        local unused_count
        unused_count=$(echo "$unused_volumes" | wc -l)

        print_info "Found $unused_count unused volumes"

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove $unused_count unused volumes")"
        else
            if [[ "$CONTAINER_KEEP_VOLUMES" != "true" ]]; then
                local removed_count=0
                echo "$unused_volumes" | while read -r volume; do
                    if [[ -n "$volume" ]]; then
                        if docker volume rm "$volume" 2>/dev/null; then
                            ((removed_count++))
                            if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
                                print_indented 2 "Removed volume: $volume"
                            fi
                        fi
                    fi
                done
                print_success "Removed $unused_count unused volumes"
            else
                print_info "Skipping volume removal (--keep-volumes enabled)"
            fi
        fi
    else
        print_info "No unused volumes found"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Docker networks
cleanup_docker_networks() {
    if ! command_exists docker; then
        return 0
    fi

    print_section "Cleaning Docker Networks"

    local total_removed=0
    local total_freed=0

    # Remove unused networks (not connected to any containers)
    local unused_networks
    unused_networks=$(docker network ls --filter "dangling=true" --format "{{.Name}}" 2>/dev/null || true)

    if [[ -n "$unused_networks" ]]; then
        local unused_count
        unused_count=$(echo "$unused_networks" | wc -l)

        print_info "Found $unused_count unused networks"

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove $unused_count unused networks")"
        else
            local removed_count=0
            echo "$unused_networks" | while read -r network; do
                if [[ -n "$network" ]]; then
                    if docker network rm "$network" 2>/dev/null; then
                        ((removed_count++))
                        if [[ "$CONTAINER_VERBOSE" == "true" ]]; then
                            print_indented 2 "Removed network: $network"
                        fi
                    fi
                fi
            done
            print_success "Removed $unused_count unused networks"
        fi
    else
        print_info "No unused networks found"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Docker build cache
cleanup_docker_build_cache() {
    if ! command_exists docker; then
        return 0
    fi

    print_section "Cleaning Docker Build Cache"

    local total_freed=0

    # Clean build cache
    if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
        print_indented 2 "$(format_status "info" "Would clean Docker build cache")"
    else
        if docker builder prune -f 2>/dev/null; then
            print_success "Docker build cache cleaned"
        else
            print_warning "Failed to clean Docker build cache"
        fi
    fi

    show_cleanup_summary 0 "$total_freed"
}

# Clean Podman resources (similar to Docker functions)
cleanup_podman_containers() {
    if ! command_exists podman; then
        return 0
    fi

    print_section "Cleaning Podman Containers"

    local total_removed=0
    local total_freed=0

    # Remove stopped containers
    local stopped_containers
    stopped_containers=$(podman ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null || true)

    if [[ -n "$stopped_containers" ]]; then
        local stopped_count
        stopped_count=$(echo "$stopped_containers" | wc -l)

        print_info "Found $stopped_count stopped containers"

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove $stopped_count stopped containers")"
        else
            if podman rm --all 2>/dev/null; then
                print_success "Removed stopped containers"
            else
                print_warning "Failed to remove some stopped containers"
            fi
        fi
    else
        print_info "No stopped containers found"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

cleanup_podman_images() {
    if ! command_exists podman; then
        return 0
    fi

    print_section "Cleaning Podman Images"

    local total_removed=0
    local total_freed=0

    # Remove dangling images
    if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
        print_indented 2 "$(format_status "info" "Would remove dangling images")"
    else
        if podman image prune -f 2>/dev/null; then
            print_success "Podman dangling images cleaned"
        else
            print_warning "Failed to clean dangling images"
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

cleanup_podman_volumes() {
    if ! command_exists podman; then
        return 0
    fi

    print_section "Cleaning Podman Volumes"

    local total_removed=0
    local total_freed=0

    # Remove unused volumes
    if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
        print_indented 2 "$(format_status "info" "Would remove unused volumes")"
    else
        if [[ "$CONTAINER_KEEP_VOLUMES" != "true" ]]; then
            if podman volume prune -f 2>/dev/null; then
                print_success "Podman unused volumes cleaned"
            else
                print_warning "Failed to clean unused volumes"
            fi
        else
            print_info "Skipping volume removal (--keep-volumes enabled)"
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Comprehensive container cleanup
cleanup_containers_comprehensive() {
    print_header "Comprehensive Container Cleanup"
    print_info "Performing container system cleanup"

    if ! detect_container_runtimes; then
        print_info "No container runtimes found to clean"
        return 0
    fi

    if [[ "$CONTAINER_DRY_RUN" == "false" ]] && [[ "$CONTAINER_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will clean containers, images, volumes, and networks. Continue?" "This operation removes unused container resources and should be reviewed carefully."; then
            print_info "Container cleanup cancelled"
            return 0
        fi
    fi

    # Show current status
    show_container_status

    # Clean Docker resources
    if command_exists docker; then
        cleanup_docker_containers
        cleanup_docker_images
        cleanup_docker_volumes
        cleanup_docker_networks
        cleanup_docker_build_cache

        # Final Docker system prune
        if [[ "$CONTAINER_PRUNE_UNUSED" == "true" ]]; then
            print_section "Docker System Prune"
            if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would run Docker system prune")"
            else
                if docker system prune -f 2>/dev/null; then
                    print_success "Docker system prune completed"
                fi
            fi
        fi
    fi

    # Clean Podman resources
    if command_exists podman; then
        cleanup_podman_containers
        cleanup_podman_images
        cleanup_podman_volumes

        # Final Podman system prune
        if [[ "$CONTAINER_PRUNE_UNUSED" == "true" ]]; then
            print_section "Podman System Prune"
            if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would run Podman system prune")"
            else
                if podman system prune -f 2>/dev/null; then
                    print_success "Podman system prune completed"
                fi
            fi
        fi
    fi

    print_header "Container Cleanup Complete"
    print_success "Container system cleanup completed successfully"

    # Show final status
    echo ""
    show_container_status
}

# Parse container cleanup arguments
parse_container_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                CONTAINER_FORCE=true
                shift
                ;;
            -n|--dry-run)
                CONTAINER_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                CONTAINER_VERBOSE=true
                shift
                ;;
            --keep-images)
                CONTAINER_KEEP_IMAGES="$2"
                shift 2
                ;;
            --keep-volumes)
                CONTAINER_KEEP_VOLUMES=true
                shift
                ;;
            --no-prune)
                CONTAINER_PRUNE_UNUSED=false
                shift
                ;;
            -h|--help)
                show_container_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_container_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show container cleanup help
show_container_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}Container Cleanup Module${RESET}
${ITALIC}Comprehensive cleanup for Docker, Podman, and container resources${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup containers${RESET} [${YELLOW}RUNTIME${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Runtimes:${RESET}
    ${YELLOW}docker${RESET}                 Clean Docker containers, images, volumes, networks
    ${YELLOW}podman${RESET}                 Clean Podman containers, images, volumes
    ${YELLOW}all${RESET}                    Clean all detected container runtimes

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be cleaned
    ${YELLOW}-v, --verbose${RESET}                  Verbose output with details
    ${YELLOW}--keep-images${RESET} COUNT            Number of latest images to keep (default: 3)
    ${YELLOW}--keep-volumes${RESET}                 Keep all volumes (skip volume cleanup)
    ${YELLOW}--no-prune${RESET}                     Skip final system prune
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup containers docker${RESET}     # Clean Docker resources
    ${GREEN}fub cleanup containers --dry-run all${RESET} # Preview all cleanup actions
    ${GREEN}fub cleanup containers --keep-images 5${RESET} # Keep 5 latest images
    ${GREEN}fub cleanup containers --keep-volumes${RESET} # Skip volume cleanup

${BOLD}What gets cleaned:${RESET}
    • Stopped/exited containers
    • Dangling and old unused images
    • Unused volumes (unless --keep-volumes)
    • Unused networks
    • Build cache and temporary files
    • System-wide unused resources

${BOLD}Safety Features:${RESET}
    • Keeps running containers untouched
    • Preserves latest N images per repository
    • Optional volume protection
    • Dry-run mode for safe preview
    • Runtime-specific safe cleanup
    • Detailed reporting and logging

EOF
}

# Format bytes helper
if ! command -v format_bytes >/dev/null 2>&1; then
    format_bytes() {
        local bytes=$1
        local units=('B' 'KB' 'MB' 'GB' 'TB')
        local unit=0

        while [[ $bytes -gt 1024 ]] && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
            bytes=$((bytes / 1024))
            ((unit++))
        done

        echo "${bytes}${units[$unit]}"
    }
fi

# Show cleanup summary helper
if ! command -v show_cleanup_summary >/dev/null 2>&1; then
    show_cleanup_summary() {
        local files_removed="$1"
        local space_freed="$2"

        echo ""
        print_section "Cleanup Summary"

        if [[ "$files_removed" -gt 0 ]]; then
            print_success "Items removed: $files_removed"
        fi

        if [[ "$space_freed" -gt 0 ]]; then
            print_success "Space freed: $(format_bytes $space_freed)"
        fi

        if [[ "$CONTAINER_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No items were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_container_cleanup detect_container_runtimes show_container_status
export -f get_docker_info get_podman_info cleanup_docker_containers
export -f cleanup_docker_images cleanup_docker_volumes cleanup_docker_networks
export -f cleanup_docker_build_cache cleanup_podman_containers
export -f cleanup_podman_images cleanup_podman_volumes cleanup_containers_comprehensive
export -f parse_container_cleanup_args show_container_cleanup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_container_cleanup
    parse_container_cleanup_args "$@"

    # Default action if none specified
    local action="${1:-all}"

    case "$action" in
        docker)
            cleanup_docker_containers
            cleanup_docker_images
            cleanup_docker_volumes
            cleanup_docker_networks
            cleanup_docker_build_cache
            ;;
        podman)
            cleanup_podman_containers
            cleanup_podman_images
            cleanup_podman_volumes
            ;;
        all|comprehensive)
            cleanup_containers_comprehensive
            ;;
        status)
            show_container_status
            ;;
        help|--help|-h)
            show_container_cleanup_help
            ;;
        *)
            log_error "Unknown container runtime: $action"
            show_container_cleanup_help
            exit 1
            ;;
    esac
fi