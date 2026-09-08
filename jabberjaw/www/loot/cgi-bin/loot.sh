#!/bin/sh
LOOT_DIR="/root/loot/nmap"
PAYLOAD_DIR="/root/payload"

# Whitelist of allowed script IDs -> filenames
# ONLY these can be executed via the web UI
payload_file() {
  case "$1" in
    default)  echo "payload.sh" ;;
    tcpdump)  echo "payload_tcpdump.sh" ;;
    recon)    echo "payload_recon.sh" ;;
    stealth)  echo "payload_stealth.sh" ;;
    rogue)	  echo "payload_rogue.sh" ;;
    *)        echo "" ;;
  esac
}

# Parse query string
ACTION=""
FILE=""
SCRIPT=""
OLDIFS="$IFS"
IFS='&'
for p in $QUERY_STRING; do
  case "$p" in
    action=*) ACTION="${p#action=}" ;;
    file=*)   FILE="${p#file=}" ;;
    script=*) SCRIPT="${p#script=}" ;;
  esac
done
IFS="$OLDIFS"

# Sanitize filename
FILE=$(basename "$FILE" 2>/dev/null)

case "$ACTION" in
  list)
    printf "Content-Type: application/json\r\n\r\n"
    printf '{"files":['
    FIRST=1
    for f in $(ls -t "$LOOT_DIR"/*.txt "$LOOT_DIR"/*.pcap "$LOOT_DIR"/*.tar.gz 2>/dev/null); do
      [ -e "$f" ] || continue
      NAME=$(basename "$f")
      SIZE=$(ls -lhL "$f" | awk '{print $5}')
      [ $FIRST -eq 1 ] && FIRST=0 || printf ","
      printf '{"name":"%s","size":"%s"}' "$NAME" "$SIZE"
    done
    printf ']}'
    ;;
  view)
    if [ -n "$FILE" ] && [ -f "$LOOT_DIR/$FILE" ]; then
      printf "Content-Type: text/plain\r\n\r\n"
      cat "$LOOT_DIR/$FILE"
    else
      printf "Status: 404\r\nContent-Type: text/plain\r\n\r\nFile not found"
    fi
    ;;
  download)
    if [ -n "$FILE" ] && [ -f "$LOOT_DIR/$FILE" ]; then
      printf "Content-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"%s\"\r\n\r\n" "$FILE"
      cat "$LOOT_DIR/$FILE"
    else
      printf "Status: 404\r\nContent-Type: text/plain\r\n\r\nFile not found"
    fi
    ;;
  execute)
    printf "Content-Type: application/json\r\n\r\n"
    # Resolve script ID to filename via whitelist
    RESOLVED=$(payload_file "$SCRIPT")
    if [ -z "$RESOLVED" ]; then
      printf '{"status":"error","error":"unknown module: %s"}' "$SCRIPT"
    elif [ ! -x "$PAYLOAD_DIR/$RESOLVED" ]; then
      printf '{"status":"error","error":"script not found or not executable: %s"}' "$RESOLVED"
    else
      # Run in background, capture PID
      "$PAYLOAD_DIR/$RESOLVED" >/dev/null 2>&1 &
      BG_PID=$!
      printf '{"status":"started","script":"%s","pid":"%s"}' "$RESOLVED" "$BG_PID"
    fi
    ;;
  *)
    printf "Content-Type: application/json\r\n\r\n"
    printf '{"status":"ok","usage":"?action=list|view|download|execute&file=name.txt&script=id"}'
    ;;
esac
