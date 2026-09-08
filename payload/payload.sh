#!/bin/sh
#
# Title:        payload_recon.sh (JabberJaw Swiss Knife Port)
# Description:  Modular network reconnaissance payload based on Hak5 Shark Jack payload
#               by Robert Coemans. Ported for OpenWrt / GL-AR300M.
#

# ****************************************************************************************************
# Configuration Toggles
# ****************************************************************************************************

# Setup toggles
STEALTH_MODE=false
CHANGE_HOSTNAME=false
CHANGE_MAC_ADDRESS=false
LOOKUP_SUBNET=true
COPY_BACK_DHCP_RETRIEVED_DNS_SERVERS=true
USE_CUSTOM_DNS_SERVER=false
START_SSH_SERVER=false
CHECK_DEFAULT_GATEWAY=true
CHECK_INTERNET_ACCESS=true
GET_EXTERNAL_IP_ADDRESS=true
NOTIFY_HOMEY=false
NOTIFY_PUSHOVER=false
NOTIFY_SLACK=false

# Attack toggles
GRAB_IFCONFIG_LOOT=true
GRAB_TRACEROUTE_LOOT=true
GRAB_DNS_INFORMATION_LOOT=true
GRAB_PUBLIC_IP_WHOIS_LOOT=true
GRAB_NMAP_LOOT=true
GRAB_NMAP_INTERESTING_HOSTS_LOOT=true
GRAB_DIG_LOOT=true
TRY_TO_GET_INTERNAL_DOMAINS=true

# Finish toggles
HALT_SYSTEM_WHEN_DONE=false

# Setup variables
IFACE="eth1"
LOOT_DIR_ROOT="/root/loot/network-recon"
TODAY=$(date +%Y%m%d)
START_TIME=$(date)
HOSTNAME_CUSTOM="shark"
MAC_ADDRESS_CUSTOM="4a:3f:6d:db:ba:d8"
CUSTOM_NAME_SERVER="1.1.1.1"
RESOLV_CONF_FILE="/etc/resolv.conf"
RESOLV_CONF_AUTO_FILE="/tmp/resolv.conf.auto"
INTERNET_TEST_HOST="1.1.1.1"
PUBLIC_IP_URL="http://icanhazip.com"

# Attack variables
TRACEROUTE_HOST="1.1.1.1"
INTERNAL_DOMAINS="lan"
NMAP_OPTIONS_ACTIVE_HOSTS="--top-ports 20"
INTERESTING_HOSTS_PATTERN="Synology|QNAP|Apple|Amazon|Espressif|Asus|Sernet"
NMAP_OPTIONS_INTERESTING_HOSTS="-Pn -sT --top-ports 100 --open -T4"

# Notifications
PUSHOVER_API_POST_URL="https://api.pushover.net/1/messages.json"
PUSHOVER_APPLICATION_TOKEN=""
PUSHOVER_USER_TOKEN=""

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

CREATE_SCAN_FOLDER() {
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
    LOG_FILE="${LOOT_DIR}/network-recon.log"
    {
        echo "****************************************************************************************************"
        echo "Payload executed at: $START_TIME"
        echo "Target Interface: $IFACE"
        echo "****************************************************************************************************"
        echo ""
        echo "Free diskspace before actions: $(df -h /overlay | awk 'NR==2 {print $4}')"
        echo "Loot directory created: $LOOT_DIR"
    } > "$LOG_FILE"
}

WAIT_FOR_IP() {
    ELAPSED=0
    while [ $ELAPSED -lt 20 ]; do
        INTERNAL_IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep inet | awk '{print $2}')
        if [ -n "$INTERNAL_IP" ]; then
            echo "Internal IP address: $INTERNAL_IP" >> "$LOG_FILE"
            return 0
        fi
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done
    echo "ERROR: Timeout waiting for IP address on $IFACE" >> "$LOG_FILE"
    return 1
}

CHANGE_HOSTNAME_FN() {
    if [ "$CHANGE_HOSTNAME" = "true" ]; then
        uci set system.@system[0].hostname="$HOSTNAME_CUSTOM"
        uci commit system
        /etc/init.d/system reload
        echo "HOSTNAME set to: $HOSTNAME_CUSTOM" >> "$LOG_FILE"
    fi
}

CHANGE_MAC_ADDRESS_FN() {
    if [ "$CHANGE_MAC_ADDRESS" = "true" ]; then
        ip link set dev "$IFACE" down
        ip link set dev "$IFACE" address "$MAC_ADDRESS_CUSTOM"
        ip link set dev "$IFACE" up
        sleep 2
        echo "MAC ADDRESS altered to: $MAC_ADDRESS_CUSTOM" >> "$LOG_FILE"
    fi
}

LOOKUP_SUBNET() {
    if [ "$LOOKUP_SUBNET" = "true" ]; then
        DEFAULT_GATEWAY=$(ip route show default 0.0.0.0/0 dev "$IFACE" 2>/dev/null | head -n 1 | awk '{print $3}')
        if [ -n "$DEFAULT_GATEWAY" ]; then
            SUBNET="$(echo "$DEFAULT_GATEWAY" | cut -d. -f1-3).0/24"
            echo "Subnet evaluated: $SUBNET via Gateway $DEFAULT_GATEWAY" >> "$LOG_FILE"
        fi
    fi
}

COPY_BACK_DHCP_DNS() {
    if [ "$COPY_BACK_DHCP_RETRIEVED_DNS_SERVERS" = "true" ] && [ -f "$RESOLV_CONF_AUTO_FILE" ]; then
        cp -f "$RESOLV_CONF_AUTO_FILE" "$RESOLV_CONF_FILE" 2>/dev/null
        echo "DNS updated from $RESOLV_CONF_AUTO_FILE" >> "$LOG_FILE"
    fi
}

USE_CUSTOM_DNS() {
    if [ "$USE_CUSTOM_DNS_SERVER" = "true" ]; then
        echo "nameserver $CUSTOM_NAME_SERVER" > "$RESOLV_CONF_FILE"
        echo "Custom DNS server enforced: $CUSTOM_NAME_SERVER" >> "$LOG_FILE"
    fi
}

CHECK_DEFAULT_GATEWAY_FN() {
    if [ "$CHECK_DEFAULT_GATEWAY" = "true" ] && [ -n "$DEFAULT_GATEWAY" ]; then
        if ping -q -c 2 -W 2 "$DEFAULT_GATEWAY" >/dev/null 2>&1; then
            echo "Default Gateway ($DEFAULT_GATEWAY) reachable" >> "$LOG_FILE"
        else
            echo "Default Gateway ($DEFAULT_GATEWAY) unreachable" >> "$LOG_FILE"
        fi
    fi
}

CHECK_INTERNET_ACCESS_FN() {
    if [ "$CHECK_INTERNET_ACCESS" = "true" ]; then
        if ping -q -c 2 -W 2 "$INTERNET_TEST_HOST" >/dev/null 2>&1; then
            echo "Internet access test: PASSED" >> "$LOG_FILE"
        else
            echo "Internet access test: FAILED" >> "$LOG_FILE"
        fi
    fi
}

GET_EXTERNAL_IP() {
    if [ "$GET_EXTERNAL_IP_ADDRESS" = "true" ]; then
        EXTERNAL_IP=$(curl -s -m 4 "$PUBLIC_IP_URL" 2>/dev/null || wget -qO- -T 4 "$PUBLIC_IP_URL" 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo "External IP: $EXTERNAL_IP" >> "$LOG_FILE"
        fi
    fi
}

# ****************************************************************************************************
# Attack Functions
# ****************************************************************************************************

GRAB_IFCONFIG_LOOT_FN() {
    [ "$GRAB_IFCONFIG_LOOT" != "true" ] && return
    LOOT_OUT="$LOOT_DIR/ifconfig.txt"
    {
        echo "=== IP ADDR SHOW DEV $IFACE ==="
        ip addr show dev "$IFACE"
        echo ""
        echo "=== ROUTING TABLE ==="
        ip route
    } > "$LOOT_OUT"
    echo "IFCONFIG loot recorded" >> "$LOG_FILE"
}

GRAB_TRACEROUTE_LOOT_FN() {
    [ "$GRAB_TRACEROUTE_LOOT" != "true" ] && return
    traceroute -4 -w 2 -m 10 "$TRACEROUTE_HOST" > "$LOOT_DIR/traceroute.txt" 2>&1
    echo "TRACEROUTE loot recorded" >> "$LOG_FILE"
}

GRAB_DNS_INFORMATION_LOOT_FN() {
    [ "$GRAB_DNS_INFORMATION_LOOT" != "true" ] && return
    LOOT_OUT="$LOOT_DIR/dns_information.txt"
    {
        echo "=== /etc/resolv.conf ==="
        cat /etc/resolv.conf 2>/dev/null
        echo ""
        echo "=== /tmp/resolv.conf.auto ==="
        cat /tmp/resolv.conf.auto 2>/dev/null
    } > "$LOOT_OUT"
    echo "DNS information loot recorded" >> "$LOG_FILE"
}

GRAB_PUBLIC_IP_WHOIS_LOOT_FN() {
    [ "$GRAB_PUBLIC_IP_WHOIS_LOOT" != "true" ] && return
    [ -z "$EXTERNAL_IP" ] && return
    LOOT_OUT="$LOOT_DIR/public_ip_whois.txt"
    {
        echo "=== NSLOOKUP $EXTERNAL_IP ==="
        nslookup "$EXTERNAL_IP" 2>&1
        echo ""
        echo "=== WHOIS $EXTERNAL_IP ==="
        curl -s -m 5 "https://ipapi.co/${EXTERNAL_IP}/yaml/" 2>/dev/null
    } > "$LOOT_OUT"
    echo "Public IP whois loot recorded" >> "$LOG_FILE"
}

GRAB_DIG_LOOT_FN() {
    [ "$GRAB_DIG_LOOT" != "true" ] && return
    LOOT_OUT="$LOOT_DIR/dig.txt"
    if [ "$TRY_TO_GET_INTERNAL_DOMAINS" = "true" ]; then
        DISC_DOM=$(cat /tmp/resolv.conf.auto 2>/dev/null | grep search | awk '{print $2}' | head -n 1)
        [ -n "$DISC_DOM" ] && INTERNAL_DOMAINS="$DISC_DOM"
    fi
    {
        echo "=== DIG $INTERNAL_DOMAINS ANY ==="
        dig "$INTERNAL_DOMAINS" ANY +short 2>&1
        echo ""
        echo "=== DIG AXFR TEST ==="
        dig -t AXFR "$INTERNAL_DOMAINS" 2>&1
    } > "$LOOT_OUT"
    echo "DIG loot recorded" >> "$LOG_FILE"
}

GRAB_NMAP_LOOT_FN() {
    [ "$GRAB_NMAP_LOOT" != "true" ] && return
    [ -z "$SUBNET" ] && return
    echo "[*] Launching fast Nmap scan against $SUBNET..." >> "$LOG_FILE"
    nmap -sT $NMAP_OPTIONS_ACTIVE_HOSTS --open -e "$IFACE" "$SUBNET" -oN "$LOOT_DIR/nmap.txt" >/dev/null 2>&1
    echo "Nmap active hosts scan finished" >> "$LOG_FILE"
}

GRAB_NMAP_INTERESTING_HOSTS_LOOT_FN() {
    [ "$GRAB_NMAP_INTERESTING_HOSTS_LOOT" != "true" ] && return
    [ ! -f "$LOOT_DIR/nmap.txt" ] && return

    # Rileva gli IP corrispondenti al pattern
    INTERESTING_IPS=$(grep -E "$INTERESTING_HOSTS_PATTERN" "$LOOT_DIR/nmap.txt" -B 5 2>/dev/null | grep "Nmap scan report for" | awk '{print $NF}' | tr -d '()' | sort -u)
    
    if [ -n "$INTERESTING_IPS" ]; then
        echo "[*] Discovered interesting target(s): $INTERESTING_IPS" >> "$LOG_FILE"
        nmap $NMAP_OPTIONS_INTERESTING_HOSTS -e "$IFACE" $INTERESTING_IPS -oN "$LOOT_DIR/nmap_interesting_hosts.txt" >/dev/null 2>&1
        echo "Nmap deep scan on interesting hosts completed" >> "$LOG_FILE"
    fi
}

# ****************************************************************************************************
# Execution Flow
# ****************************************************************************************************

LED_CTRL SETUP
CREATE_SCAN_FOLDER
INITIALIZE_LOG_FILE

if WAIT_FOR_IP; then
    CHANGE_HOSTNAME_FN
    CHANGE_MAC_ADDRESS_FN
    LOOKUP_SUBNET
    COPY_BACK_DHCP_DNS
    USE_CUSTOM_DNS
    CHECK_DEFAULT_GATEWAY_FN
    CHECK_INTERNET_ACCESS_FN
    GET_EXTERNAL_IP

    LED_CTRL ATTACK
    GRAB_IFCONFIG_LOOT_FN
    GRAB_TRACEROUTE_LOOT_FN
    GRAB_DNS_INFORMATION_LOOT_FN
    GRAB_PUBLIC_IP_WHOIS_LOOT_FN
    GRAB_DIG_LOOT_FN
    GRAB_NMAP_LOOT_FN
    GRAB_NMAP_INTERESTING_HOSTS_LOOT_FN

    # Collega il report Nmap per la visualizzazione nella Web Dashboard
    mkdir -p /root/loot/nmap
    if [ -f "$LOOT_DIR/nmap.txt" ]; then
        ln -sf "$LOOT_DIR/nmap.txt" "/root/loot/nmap/recon_${SCAN_COUNT}-${TODAY}.txt"
    fi

    echo "Free diskspace after actions: $(df -h /overlay | awk 'NR==2 {print $4}')" >> "$LOG_FILE"
    echo "Recon completed in $SECONDS seconds" >> "$LOG_FILE"
    sync
    LED_CTRL FINISH
else
    sync
    LED_CTRL FAIL
fi

if [ "$HALT_SYSTEM_WHEN_DONE" = "true" ]; then poweroff; fi
exit 0

