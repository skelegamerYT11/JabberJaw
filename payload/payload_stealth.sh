#!/bin/sh
#
# Title:         Ultra-Stealth Passive Recon
# Description:   Zero-packet network mapping via broadcast/multicast sniffing
#

INTERFACE="eth1"
CAPTURE_TIME=120               # 2 minuti di ascolto passivo
LOOT_DIR="/root/loot/stealth"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SESSION_DIR="${LOOT_DIR}/${TIMESTAMP}"
PCAP_FILE="${SESSION_DIR}/stealth_${TIMESTAMP}.pcap"
REPORT_FILE="${SESSION_DIR}/stealth_${TIMESTAMP}.txt"

/usr/bin/LED SETUP 2>/dev/null
mkdir -p "$SESSION_DIR"
mkdir -p /root/loot/nmap

{
    echo "========================================================================"
    echo " 🥷 ULTRA-STEALTH PASSIVE RECON"
    echo "========================================================================"
    echo " Started at: $(date)"
    echo " Interface : $INTERFACE (Promiscuous Mode, Zero-Packet Transmit)"
    echo " Duration  : $CAPTURE_TIME seconds"
    echo "========================================================================"
} > "$REPORT_FILE"

# 1. Attiva l'interfaccia in modalità passiva (niente IP, solo Link UP e Promisc)
ip link set dev "$INTERFACE" up
ip link set dev "$INTERFACE" promisc on

/usr/bin/LED ATTACK 2>/dev/null

# 2. Cattura esclusivamente rumore di fondo (Broadcast/Multicast)
# Questo esclude il traffico unicast e si concentra su ARP, DHCP, mDNS, LLMNR, NBT-NS
timeout "$CAPTURE_TIME" tcpdump -i "$INTERFACE" -s 0 -w "$PCAP_FILE" "broadcast or multicast" >/dev/null 2>&1

# 3. Analisi e Data Extraction dal PCAP
if [ -f "$PCAP_FILE" ]; then
    
    echo -e "\n\n[+] ESTRARRE DISPOSITIVI E MAC ADDRESS (ARP)..." >> "$REPORT_FILE"
    echo "------------------------------------------------" >> "$REPORT_FILE"
    # Estrae IP e MAC dalle richieste ARP (es. "who-has 192.168.1.1 tell 192.168.1.50")
    tcpdump -nn -e -r "$PCAP_FILE" arp 2>/dev/null | grep "Request" | awk '{print "IP: " $12 " \tMAC: " $2}' | tr -d ',' | sort -u >> "$REPORT_FILE"

    echo -e "\n\n[+] ESTRARRE HOSTNAME WINDOWS/APPLE (DHCP)..." >> "$REPORT_FILE"
    echo "------------------------------------------------" >> "$REPORT_FILE"
    # Estrae l'Option 12 (Hostname) dalle richieste DHCP (Client -> Server)
    tcpdump -nn -v -r "$PCAP_FILE" port 67 or port 68 2>/dev/null | grep -i "Hostname Option" | awk -F'"' '{print $2}' | sort -u >> "$REPORT_FILE"

    echo -e "\n\n[+] ESTRARRE NOMI DOMINIO E SERVIZI (mDNS/LLMNR/NBT-NS)..." >> "$REPORT_FILE"
    echo "------------------------------------------------" >> "$REPORT_FILE"
    # Cerca le richieste di risoluzione nomi (A e AAAA) per scovare PC Windows (.local) e server Active Directory
    tcpdump -nn -r "$PCAP_FILE" port 5353 or port 5355 or port 137 2>/dev/null | grep -E "A\?|AAAA\?" | awk -F '?' '{print $2}' | awk '{print $1}' | sort -u >> "$REPORT_FILE"

    echo -e "\n========================================================================" >> "$REPORT_FILE"
    echo " Analysis complete. Capture saved to: $PCAP_FILE" >> "$REPORT_FILE"
    
    # Crea i symlink per farli comparire immediatamente nella Web UI
    ln -sf "$REPORT_FILE" "/root/loot/nmap/stealth_${TIMESTAMP}.txt" 2>/dev/null
    ln -sf "$PCAP_FILE" "/root/loot/nmap/stealth_${TIMESTAMP}.pcap" 2>/dev/null
else
    echo "[-] ERRORE: Nessun traffico catturato. Cavo scollegato?" >> "$REPORT_FILE"
fi

# Ripristina l'interfaccia
ip link set dev "$INTERFACE" promisc off

sync
/usr/bin/LED SUCCESS 2>/dev/null
exit 0
