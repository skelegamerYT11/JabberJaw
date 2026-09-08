#!/bin/sh
INTERFACE="eth1"
CAPTURE_TIME=30
TCPDUMP_FILTER=""
LOOT_DIR="/root/loot/tcpdump"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SESSION_DIR="${LOOT_DIR}/${TIMESTAMP}"
PCAP_FILE="${SESSION_DIR}/capture_${TIMESTAMP}.pcap"
ARCHIVE_FILE="${SESSION_DIR}/capture_${TIMESTAMP}.tar.gz"
LOG_FILE="${SESSION_DIR}/capture.log"

/usr/bin/LED SETUP 2>/dev/null
mkdir -p "$SESSION_DIR"
mkdir -p /root/loot/nmap

echo "[*] Session started at $(date)" > "$LOG_FILE"

ELAPSED=0
while [ $ELAPSED -lt 20 ]; do
    if ip -4 addr show dev "$INTERFACE" 2>/dev/null | grep -q inet; then
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

IPADDR=$(ip -4 addr show dev "$INTERFACE" 2>/dev/null | grep inet | awk '{print $2}')
echo "[*] Interface $INTERFACE IP: ${IPADDR:-none}" >> "$LOG_FILE"

/usr/bin/LED ATTACK 2>/dev/null
echo "[*] Starting tcpdump for ${CAPTURE_TIME}s on $INTERFACE..." >> "$LOG_FILE"

timeout "$CAPTURE_TIME" tcpdump -i "$INTERFACE" -s 0 -w "$PCAP_FILE" $TCPDUMP_FILTER >> "$LOG_FILE" 2>&1

echo "[*] Capture completed at $(date)" >> "$LOG_FILE"

if [ -f "$PCAP_FILE" ]; then
    PACKET_COUNT=$(tcpdump -r "$PCAP_FILE" 2>/dev/null | wc -l)
    echo "[*] Captured packets: $PACKET_COUNT" >> "$LOG_FILE"
    
    tar -czf "$ARCHIVE_FILE" -C "$SESSION_DIR" "capture_${TIMESTAMP}.pcap" "capture.log"
    
    ln -sf "$ARCHIVE_FILE" "/root/loot/nmap/capture_${TIMESTAMP}.tar.gz" 2>/dev/null
    ln -sf "$PCAP_FILE" "/root/loot/nmap/capture_${TIMESTAMP}.pcap" 2>/dev/null
fi

sync
/usr/bin/LED SUCCESS 2>/dev/null
exit 0
