#!/bin/bash
# Script untuk menemukan IP Mikrotik router yang mengirim request RADIUS

echo "🔍 Finding Mikrotik Router IP from RADIUS requests"
echo ""
echo "This script will monitor RADIUS port 1812 to find the source IP"
echo "Please try to login from Mikrotik hotspot in another terminal"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor RADIUS port
sudo tcpdump -i any port 1812 -n -c 5 2>&1 | grep -E "IP.*>.*1812" | head -5 | while read line; do
    # Extract source IP
    SRC_IP=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
    if [ ! -z "$SRC_IP" ]; then
        echo "✅ Found RADIUS request from IP: $SRC_IP"
        echo ""
        echo "Add this IP to clients.conf:"
        echo "client mikrotik-router {"
        echo "    ipaddr = $SRC_IP"
        echo "    secret = testing123"
        echo "    require_message_authenticator = no"
        echo "    nas_type = mikrotik"
        echo "}"
    fi
done

