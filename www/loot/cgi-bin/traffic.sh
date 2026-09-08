#!/bin/sh
echo "Content-Type: application/json"
echo ""
ETH0=$(grep eth0 /proc/net/dev | awk '{print $2","$10}' 2>/dev/null || echo "0,0")
ETH1=$(grep eth1 /proc/net/dev | awk '{print $2","$10}' 2>/dev/null || echo "0,0")
CONN=$(wc -l /proc/net/nf_conntrack 2>/dev/null | awk '{print $1}' || echo "0")
echo "{\"eth0\":\"$ETH0\", \"eth1\":\"$ETH1\", \"connections\":\"$CONN\"}"
