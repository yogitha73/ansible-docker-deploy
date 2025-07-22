#!/bin/bash

# Automated Apache Container Deployment - Verification Script
# This script verifies that the Apache container deployment is working correctly

set -e  # Exit on any error

# Script configuration
SCRIPT_NAME="verify.sh"
SCRIPT_VERSION="1.0"
LOG_FILE="verification.log"

# Container and network configuration
CONTAINER_NAME="apache_web"
NETWORK_NAME="apache_network"
CONTAINER_IP="172.168.10.2"
HOST_PORT="8080"
CONTAINER_PORT="80"
EXPECTED_CONTENT="Welcome to Apache Container deployed with Ansible"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}"
}

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    log "PASS" "$1"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    log "FAIL" "$1"
    ((TESTS_FAILED++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "WARN" "$1"
}

print_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
    log "TEST" "$1"
    ((TESTS_TOTAL++))
}

# Banner function
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║               APACHE CONTAINER DEPLOYMENT                   ║
║                  VERIFICATION SCRIPT                        ║
╠══════════════════════════════════════════════════════════════╣
║ This script verifies the Apache container deployment        ║
║ and tests all components for proper functionality.          ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if Docker is available
check_docker_availability() {
    print_test "Checking Docker availability"
    
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_success "Docker is available and running"
            return 0
        else
            print_failure "Docker daemon is not running"
            return 1
        fi
    else
        print_failure "Docker command not found"
        return 1
    fi
}

# Check if container exists and is running
check_container_status() {
    print_test "Checking container status: $CONTAINER_NAME"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^$CONTAINER_NAME"; then
        local status=$(docker ps --format "{{.Status}}" --filter "name=$CONTAINER_NAME")
        print_success "Container is running: $status"
        return 0
    elif docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "^$CONTAINER_NAME"; then
        local status=$(docker ps -a --format "{{.Status}}" --filter "name=$CONTAINER_NAME")
        print_failure "Container exists but is not running: $status"
        return 1
    else
        print_failure "Container not found: $CONTAINER_NAME"
        return 1
    fi
}

# Check container health
check_container_health() {
    print_test "Checking container health"
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-health-check")
    
    case $health_status in
        "healthy")
            print_success "Container health status: healthy"
            return 0
            ;;
        "unhealthy")
            print_failure "Container health status: unhealthy"
            return 1
            ;;
        "starting")
            print_warning "Container health status: starting (may need more time)"
            return 1
            ;;
        "no-health-check")
            print_warning "No health check configured for container"
            return 0
            ;;
        *)
            print_failure "Unknown health status: $health_status"
            return 1
            ;;
    esac
}

# Check network configuration
check_network_configuration() {
    print_test "Checking Docker network: $NETWORK_NAME"
    
    if docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
        print_success "Network exists: $NETWORK_NAME"
        
        # Check network details
        local subnet=$(docker network inspect "$NETWORK_NAME" --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null)
        if [[ -n "$subnet" ]]; then
            print_info "Network subnet: $subnet"
        fi
        
        return 0
    else
        print_failure "Network not found: $NETWORK_NAME"
        return 1
    fi
}

# Check container network assignment
check_container_network() {
    print_test "Checking container network assignment"
    
    local container_ip=$(docker inspect --format="{{.NetworkSettings.Networks.$NETWORK_NAME.IPAddress}}" "$CONTAINER_NAME" 2>/dev/null)
    
    if [[ -n "$container_ip" && "$container_ip" != "<no value>" ]]; then
        if [[ "$container_ip" == "$CONTAINER_IP" ]]; then
            print_success "Container has correct IP address: $container_ip"
            return 0
        else
            print_failure "Container has wrong IP address: $container_ip (expected: $CONTAINER_IP)"
            return 1
        fi
    else
        print_failure "Container is not connected to network: $NETWORK_NAME"
        return 1
    fi
}

# Check port mapping
check_port_mapping() {
    print_test "Checking port mapping: $HOST_PORT -> $CONTAINER_PORT"
    
    local port_mapping=$(docker port "$CONTAINER_NAME" "$CONTAINER_PORT" 2>/dev/null || echo "")
    
    if [[ -n "$port_mapping" ]]; then
        if echo "$port_mapping" | grep -q ":$HOST_PORT$"; then
            print_success "Port mapping configured correctly: $port_mapping"
            return 0
        else
            print_failure "Incorrect port mapping: $port_mapping (expected: *:$HOST_PORT)"
            return 1
        fi
    else
        print_failure "No port mapping found for container port $CONTAINER_PORT"
        return 1
    fi
}

# Test HTTP connectivity
test_http_connectivity() {
    print_test "Testing HTTP connectivity on localhost:$HOST_PORT"
    
    # Check if port is listening
    if ss -tln | grep -q ":$HOST_PORT "; then
        print_success "Port $HOST_PORT is listening"
    else
        print_failure "Port $HOST_PORT is not listening"
        return 1
    fi
    
    # Test HTTP response
    local response_code
    local response_body
    
    if command -v curl &> /dev/null; then
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HOST_PORT" --connect-timeout 10 --max-time 30 || echo "000")
        
        if [[ "$response_code" == "200" ]]; then
            print_success "HTTP response code: $response_code"
            
            # Check response content
            response_body=$(curl -s "http://localhost:$HOST_PORT" --connect-timeout 10 --max-time 30 || echo "")
            if echo "$response_body" | grep -q "$EXPECTED_CONTENT"; then
                print_success "Response contains expected content"
                return 0
            else
                print_failure "Response does not contain expected content"
                print_info "Expected: $EXPECTED_CONTENT"
                print_info "Response preview: $(echo "$response_body" | head -c 100)..."
                return 1
            fi
        else
            print_failure "HTTP response code: $response_code"
            return 1
        fi
    else
        print_warning "curl not available, skipping HTTP content test"
        return 0
    fi
}

# Test internal container connectivity
test_internal_connectivity() {
    print_test "Testing internal container connectivity"
    
    # Test connectivity from within the Docker network
    if docker run --rm --network "$NETWORK_NAME" alpine/curl:latest curl -s -f "http://$CONTAINER_IP:$CONTAINER_PORT" > /dev/null 2>&1; then
        print_success "Internal network connectivity working"
        return 0
    else
        print_failure "Internal network connectivity failed"
        return 1
    fi
}

# Check container logs for errors
check_container_logs() {
    print_test "Checking container logs for errors"
    
    local log_output=$(docker logs "$CONTAINER_NAME" --tail 20 2>&1)
    local error_count=$(echo "$log_output" | grep -i "error\|fail\|exception" | wc -l)
    
    if [[ $error_count -eq 0 ]]; then
        print_success "No errors found in container logs"
        return 0
    else
        print_failure "Found $error_count potential errors in container logs"
        print_info "Recent log entries:"
        echo "$log_output" | tail -5 | while read line; do
            print_info "  $line"
        done
        return 1
    fi
}

# Check resource usage
check_resource_usage() {
    print_test "Checking container resource usage"
    
    local stats_output=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "")
    
    if [[ -n "$stats_output" ]]; then
        local cpu_usage=$(echo "$stats_output" | tail -n 1 | awk '{print $1}' | sed 's/%//')
        local mem_usage=$(echo "$stats_output" | tail -n 1 | awk '{print $2}')
        
        print_success "Resource usage - CPU: ${cpu_usage}%, Memory: ${mem_usage}"
        
        # Check if CPU usage is reasonable (less than 50% for a simple web server)
        if (( $(echo "$cpu_usage < 50" | bc -l 2>/dev/null || echo "1") )); then
            print_success "CPU usage is within normal range"
        else
            print_warning "High CPU usage detected: ${cpu_usage}%"
        fi
        
        return 0
    else
        print_warning "Unable to retrieve resource usage statistics"
        return 0
    fi
}

# Check file system and content
check_static_content() {
    print_test "Checking static content deployment"
    
    # Check if index.html exists in container
    if docker exec "$CONTAINER_NAME" test -f "/usr/local/apache2/htdocs/index.html"; then
        print_success "Static content file exists in container"
        
        # Check file permissions
        local file_perms=$(docker exec "$CONTAINER_NAME" stat -c "%a" "/usr/local/apache2/htdocs/index.html" 2>/dev/null || echo "")
        if [[ -n "$file_perms" ]]; then
            print_info "File permissions: $file_perms"
        fi
        
        return 0
    else
        print_failure "Static content file not found in container"
        return 1
    fi
}

# Performance test
run_performance_test() {
    print_test "Running basic performance test"
    
    if command -v curl &> /dev/null; then
        print_info "Testing response time..."
        
        local total_time=0
        local test_count=5
        
        for i in $(seq 1 $test_count); do
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" "http://localhost:$HOST_PORT" --connect-timeout 5 --max-time 10 2>/dev/null || echo "10")
            total_time=$(echo "$total_time + $response_time" | bc -l 2>/dev/null || echo "$total_time")
        done
        
        local avg_time=$(echo "scale=3; $total_time / $test_count" | bc -l 2>/dev/null || echo "unknown")
        
        if [[ "$avg_time" != "unknown" ]]; then
            print_success "Average response time: ${avg_time}s over $test_count requests"
            
            # Check if response time is reasonable (less than 1 second)
            if (( $(echo "$avg_time < 1.0" | bc -l 2>/dev/null || echo "1") )); then
                print_success "Response time is within acceptable range"
            else
                print_warning "High response time detected: ${avg_time}s"
            fi
        else
            print_warning "Unable to calculate average response time"
        fi
        
        return 0
    else
        print_warning "curl not available, skipping performance test"
        return 0
    fi
}

# Generate detailed report
generate_report() {
    print_info "Generating verification report..."
    
    local report_file="verification_report.txt"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$report_file" << EOF
# Apache Container Deployment - Verification Report
Generated: $timestamp
Hostname: $(hostname)
User: $(whoami)

## Test Summary
Total Tests: $TESTS_TOTAL
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Success Rate: $(echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc -l 2>/dev/null || echo "N/A")%

## Container Information
$(docker inspect "$CONTAINER_NAME" --format='Container: {{.Name}}
Image: {{.Config.Image}}
Status: {{.State.Status}}
Started: {{.State.StartedAt}}
Restart Count: {{.RestartCount}}' 2>/dev/null || echo "Container information not available")

## Network Information
$(docker network inspect "$NETWORK_NAME" --format='Network: {{.Name}}
Driver: {{.Driver}}
Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}
Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "Network information not available")

## Port Mapping
$(docker port "$CONTAINER_NAME" 2>/dev/null || echo "Port mapping information not available")

## Resource Usage
$(docker stats "$CONTAINER_NAME" --no-stream 2>/dev/null || echo "Resource usage information not available")

## Recent Container Logs
$(docker logs "$CONTAINER_NAME" --tail 10 2>/dev/null || echo "Container logs not available")

## System Information
$(uname -a)
$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "Docker version not available")

EOF
    
    print_success "Verification report saved to: $report_file"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    # Add cleanup logic here if needed
    return 0
}

# Main verification function
main() {
    print_banner
    
    print_info "Starting verification process..."
    print_info "Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    print_info "Target container: $CONTAINER_NAME"
    print_info "Target network: $NETWORK_NAME"
    print_info "Log file: ${LOG_FILE}"
    
    # Initialize log file
    echo "# Apache Container Deployment Verification Log" > "$LOG_FILE"
    echo "# Started: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Reset counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    
    # Run verification tests
    check_docker_availability
    check_container_status
    check_container_health
    check_network_configuration
    check_container_network
    check_port_mapping
    test_http_connectivity
    test_internal_connectivity
    check_container_logs
    check_resource_usage
    check_static_content
    run_performance_test
    
    # Generate summary
    echo ""
    print_info "═══════════════════════════════════════════════════════════════"
    print_info "                      VERIFICATION SUMMARY"
    print_info "═══════════════════════════════════════════════════════════════"
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc -l 2>/dev/null || echo "0")
        print_info "Total Tests Run: $TESTS_TOTAL"
        print_info "Tests Passed: $TESTS_PASSED"
        print_info "Tests Failed: $TESTS_FAILED"
        print_info "Success Rate: ${success_rate}%"
    fi
    
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        print_success "🎉 All tests passed! Apache container deployment is working correctly."
        print_info "Service URL: http://localhost:$HOST_PORT"
        print_info "Container IP: $CONTAINER_IP"
    else
        print_failure "❌ $TESTS_FAILED test(s) failed. Please review the issues above."
        print_info "Check the log file for more details: $LOG_FILE"
    fi
    
    generate_report
    cleanup
    
    echo ""
    print_info "Verification complete: $(date)"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Apache Container Deployment Verification

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version information
    --quick         Run only essential tests
    --detailed      Run all tests including performance tests

DESCRIPTION:
    This script verifies that the Apache container deployment is working
    correctly by running a comprehensive set of tests.

TESTS PERFORMED:
    - Docker availability and connectivity
    - Container status and health
    - Network configuration
    - Port mapping verification
    - HTTP connectivity and content validation
    - Resource usage monitoring
    - Log analysis
    - Performance testing

EXAMPLES:
    $0                    # Run all verification tests
    $0 --quick           # Run essential tests only
    $0 --detailed        # Run comprehensive test suite

EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "$SCRIPT_NAME v$SCRIPT_VERSION"
        exit 0
        ;;
    --quick)
        print_info "Running quick verification (essential tests only)..."
        # Add logic for quick tests if needed
        main
        ;;
    --detailed)
        print_info "Running detailed verification (comprehensive test suite)..."
        main
        ;;
    "")
        main
        ;;
    *)
        print_failure "Unknown option: $1"
        print_info "Use --help for usage information"
        exit 1
        ;;
esac
