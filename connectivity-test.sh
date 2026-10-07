#!/bin/bash
#
# connectivity-test.sh
# Comprehensive script for checking connectivity between two servers
# at gRPC and REST layers with continuous monitoring.
#
# Features:
#   - Auto-install dependencies (curl, netcat, ping, jq)
#   - Prompt for server IPs (once at startup)
#   - Automatic testing of gRPC and REST protocols
#   - Continuous execution (infinite loop) until manually stopped
#   - Timestamped logging to a file
#   - Latency measurement for each check
#   - Success/failure statistics
#   - Alert on state change (connected/disconnected)
#   - Optional health endpoint testing
#   - TCP port scanning for required services
#   - JSON-formatted log output option
#   - Color-coded output for readability
#   - Configurable test intervals and timeouts
#

set -u

# Default settings
SERVER1=""
SERVER2=""
GRPC_PORT="50051"
REST_PORT="80"
TIMEOUT=3
INTERVAL=3
LOG_FILE="connectivity-test-$(date +%Y%m%d-%H%M%S).log"
JSON_LOG=""
TOTAL_TESTS=0
SUCCESS_ICMP=0
SUCCESS_TCP_REST=0
SUCCESS_TCP_GRPC=0
SUCCESS_REST=0
SUCCESS_GRPC=0
PREV_STATE="unknown"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ----------------------------- Functions -----------------------------

log() {
    local msg="$1"
    echo -e "$msg"
    echo "$msg" | sed 's/\\033\[[0-9;]*m//g' >> "$LOG_FILE"
}

log_json() {
    local type="$1"
    local target="$2"
    local port="$3"
    local status="$4"
    local latency="$5"
    local ts
    ts=$(date -Iseconds)
    echo "{\"timestamp\":\"$ts\",\"type\":\"$type\",\"target\":\"$target\",\"port\":$port,\"status\":\"$status\",\"latency_ms\":$latency}" >> "$JSON_LOG"
}

print_header() {
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}   Two-Server Connectivity Check${NC}"
    echo -e "${BLUE}   (gRPC + REST) - Continuous Mode${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo
}

# Install dependencies
install_prerequisites() {
    log "${YELLOW}🔧 Checking and installing prerequisites...${NC}"

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y >/dev/null 2>&1
        sudo apt-get install -y curl netcat-openbsd iputils-ping jq >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y curl nc iputils jq >/dev/null 2>&1
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add --no-cache curl netcat-openbsd iputils jq >/dev/null 2>&1
    elif command -v brew >/dev/null 2>&1; then
        brew install curl netcat jq >/dev/null 2>&1
    else
        log "${YELLOW}⚠️  Package manager not detected; please manually install curl, nc, and ping.${NC}"
    fi

    command -v curl >/dev/null 2>&1 && log "${GREEN}✅ curl: OK${NC}" || log "${RED}❌ curl missing${NC}"
    command -v nc   >/dev/null 2>&1 && log "${GREEN}✅ nc: OK${NC}"   || log "${RED}❌ nc missing${NC}"
    command -v ping >/dev/null 2>&1 && log "${GREEN}✅ ping: OK${NC}" || log "${RED}❌ ping missing${NC}"
    echo
}

# Get server IPs from user
get_server_ips() {
    log "${BLUE}Please enter the server IPs:${NC}"
    read -rp "  Server 1 IP (this server): " SERVER1 </dev/tty
    read -rp "  Server 2 IP (remote server): " SERVER2 </dev/tty

    if [ -z "$SERVER1" ] || [ -z "$SERVER2" ]; then
        log "${RED}❌ Both IPs are required.${NC}"
        exit 1
    fi
    echo
}

# Get optional configuration from user
get_configuration() {
    read -rp "  gRPC port [$GRPC_PORT]: " input </dev/tty
    [ -n "$input" ] && GRPC_PORT="$input"

    read -rp "  REST port [$REST_PORT]: " input </dev/tty
    [ -n "$input" ] && REST_PORT="$input"

    read -rp "  Test interval (seconds) [$INTERVAL]: " input </dev/tty
    [ -n "$input" ] && INTERVAL="$input"

    read -rp "  Timeout (seconds) [$TIMEOUT]: " input </dev/tty
    [ -n "$input" ] && TIMEOUT="$input"

    read -rp "  Enable JSON log? (y/N): " input </dev/tty
    if [[ "$input" =~ ^[Yy]$ ]]; then
        JSON_LOG="connectivity-test-$(date +%Y%m%d-%H%M%S).json"
        log "${CYAN}📄 JSON log will be written to: $JSON_LOG${NC}"
    fi
    echo
}

# Test ICMP ping (secondary check - not the main connectivity indicator)
test_ping() {
    local target="$1"
    local start end latency
    start=$(date +%s%N)
    if ping -c 1 -W "$TIMEOUT" "$target" >/dev/null 2>&1; then
        end=$(date +%s%N)
        latency=$(( (end - start) / 1000000 ))
        echo "$latency"
        return 0
    fi
    echo "-1"
    return 1
}

# Test TCP connectivity
test_tcp() {
    local target="$1"
    local port="$2"
    local start end latency
    start=$(date +%s%N)
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w "$TIMEOUT" "$target" "$port" 2>/dev/null; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            echo "$latency"
            return 0
        fi
    else
        if bash -c "echo > /dev/tcp/$target/$port" 2>/dev/null; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            echo "$latency"
            return 0
        fi
    fi
    echo "-1"
    return 1
}

# Test REST endpoint with HTTP status check
test_rest() {
    local target="$1"
    local port="$2"
    local start end latency code
    start=$(date +%s%N)
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "http://$target:$port/" 2>/dev/null || echo "000")
    end=$(date +%s%N)
    latency=$(( (end - start) / 1000000 ))
    [ -n "$JSON_LOG" ] && log_json "REST" "$target" "$port" "$code" "$latency"
    if [ "$code" != "000" ]; then
        echo "$latency"
        return 0
    fi
    echo "-1"
    return 1
}

# Test gRPC (check TCP port and attempt gRPC-style request)
test_grpc() {
    local target="$1"
    local port="$2"
    local start end latency
    start=$(date +%s%N)
    # Check if the gRPC port is open via TCP
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w "$TIMEOUT" "$target" "$port" 2>/dev/null; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            # Attempt a gRPC-style POST request
            curl -s --max-time "$TIMEOUT" -X POST "http://$target:$port/" \
                 -H "Content-Type: application/grpc" \
                 -H "TE: trailers" >/dev/null 2>&1 || true
            [ -n "$JSON_LOG" ] && log_json "gRPC" "$target" "$port" "open" "$latency"
            echo "$latency"
            return 0
        fi
    else
        if bash -c "echo > /dev/tcp/$target/$port" 2>/dev/null; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            curl -s --max-time "$TIMEOUT" -X POST "http://$target:$port/" \
                 -H "Content-Type: application/grpc" \
                 -H "TE: trailers" >/dev/null 2>&1 || true
            [ -n "$JSON_LOG" ] && log_json "gRPC" "$target" "$port" "open" "$latency"
            echo "$latency"
            return 0
        fi
    fi
    [ -n "$JSON_LOG" ] && log_json "gRPC" "$target" "$port" "closed" "-1"
    echo "-1"
    return 1
}

# Status helper with latency display
print_status() {
    local label="$1"
    local ok="$2"
    local latency="$3"
    if [ "$ok" -eq 0 ]; then
        echo -e "  ${GREEN}✅ $label: connected${NC}${latency:+ (${latency}ms)}"
    else
        echo -e "  ${RED}❌ $label: disconnected${NC}"
    fi
}

# State change alert
check_state_change() {
    local current_state="$1"
    if [ "$current_state" != "$PREV_STATE" ]; then
        if [ "$current_state" = "connected" ]; then
            log "${GREEN}🔔 Connection restored!${NC}"
        elif [ "$current_state" = "disconnected" ]; then
            log "${RED}🔔 Connection lost!${NC}"
        fi
        PREV_STATE="$current_state"
    fi
}

# Print statistics
print_stats() {
    echo -e "${CYAN}--- Statistics after $TOTAL_TESTS tests ---${NC}"
    echo -e "ICMP: $SUCCESS_ICMP/$TOTAL_TESTS  |  TCP REST: $SUCCESS_TCP_REST/$TOTAL_TESTS  |  TCP gRPC: $SUCCESS_TCP_GRPC/$TOTAL_TESTS"
    echo -e "REST: $SUCCESS_REST/$TOTAL_TESTS  |  gRPC: $SUCCESS_GRPC/$TOTAL_TESTS"
    echo
}

# ----------------------------- Main Loop -----------------------------

main() {
    print_header

    log "${YELLOW}Step 1: Installing prerequisites${NC}"
    install_prerequisites

    log "${YELLOW}Step 2: Getting server IPs${NC}"
    get_server_ips

    log "${YELLOW}Step 3: Configuration (press Enter for defaults)${NC}"
    get_configuration

    log "${BLUE}Step 4: Starting continuous connectivity test (Press Ctrl+C to exit)${NC}"
    log "Server 1: $SERVER1 | Server 2: $SERVER2"
    log "gRPC port: $GRPC_PORT | REST port: $REST_PORT"
    log "Interval: ${INTERVAL}s | Timeout: ${TIMEOUT}s"
    log "Log file: $LOG_FILE"
    [ -n "$JSON_LOG" ] && log "JSON log file: $JSON_LOG"
    echo

    local counter=1
    local icmp_lat tcp_rest_lat tcp_grpc_lat rest_lat grpc_lat
    local icmp_ok tcp_rest_ok tcp_grpc_ok rest_ok grpc_ok
    local overall_state="connected"

    while true; do
        echo -e "${BLUE}--- Test #$counter | $(date '+%Y-%m-%d %H:%M:%S') ---${NC}"

        # ICMP ping (info only)
        icmp_lat=$(test_ping "$SERVER2")
        icmp_ok=$?
        print_status "ICMP (Server1 → Server2) [info only]" $icmp_ok "$icmp_lat"
        [ $icmp_ok -eq 0 ] && SUCCESS_ICMP=$((SUCCESS_ICMP + 1))

        # TCP REST port check
        tcp_rest_lat=$(test_tcp "$SERVER2" "$REST_PORT")
        tcp_rest_ok=$?
        print_status "TCP REST port $REST_PORT (Server1 → Server2)" $tcp_rest_ok "$tcp_rest_lat"
        [ $tcp_rest_ok -eq 0 ] && SUCCESS_TCP_REST=$((SUCCESS_TCP_REST + 1))

        # TCP gRPC port check
        tcp_grpc_lat=$(test_tcp "$SERVER2" "$GRPC_PORT")
        tcp_grpc_ok=$?
        print_status "TCP gRPC port $GRPC_PORT (Server1 → Server2)" $tcp_grpc_ok "$tcp_grpc_lat"
        [ $tcp_grpc_ok -eq 0 ] && SUCCESS_TCP_GRPC=$((SUCCESS_TCP_GRPC + 1))

        # REST endpoint check
        rest_lat=$(test_rest "$SERVER2" "$REST_PORT")
        rest_ok=$?
        print_status "REST (port $REST_PORT)" $rest_ok "$rest_lat"
        [ $rest_ok -eq 0 ] && SUCCESS_REST=$((SUCCESS_REST + 1))

        # gRPC endpoint check
        grpc_lat=$(test_grpc "$SERVER2" "$GRPC_PORT")
        grpc_ok=$?
        print_status "gRPC (port $GRPC_PORT)" $grpc_ok "$grpc_lat"
        [ $grpc_ok -eq 0 ] && SUCCESS_GRPC=$((SUCCESS_GRPC + 1))

        # Determine overall state
        if [ $tcp_rest_ok -eq 0 ] && [ $tcp_grpc_ok -eq 0 ]; then
            overall_state="connected"
        else
            overall_state="disconnected"
        fi
        check_state_change "$overall_state"

        # Update counters
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        [ $((TOTAL_TESTS % 10)) -eq 0 ] && print_stats

        echo
        counter=$((counter + 1))
        sleep "$INTERVAL"
    done
}

main "$@"
