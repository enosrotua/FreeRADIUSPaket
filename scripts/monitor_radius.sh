#!/usr/bin/env bash
# Script untuk monitoring RADIUS authentication requests

echo "=========================================="
echo "Monitoring FreeRADIUS Authentication"
echo "=========================================="
echo ""
echo "FreeRADIUS Status:"
sudo systemctl status freeradius --no-pager | head -5
echo ""
echo "Listening on ports:"
sudo ss -luna 'sport = :1812 or sport = :1813' | cat
echo ""
echo "Recent authentication attempts (last 20 lines):"
echo "----------------------------------------------"
sudo tail -50 /var/log/freeradius/radius.log 2>/dev/null | grep -i "auth\|login\|access\|reject\|accept" | tail -20 | cat || sudo journalctl -u freeradius -n 50 --no-pager | grep -i "auth\|login\|access\|reject\|accept" | tail -20 | cat
echo ""
echo "=========================================="
echo "Live monitoring (Press Ctrl+C to stop):"
echo "=========================================="
sudo tail -f /var/log/freeradius/radius.log 2>/dev/null || sudo journalctl -u freeradius -f --no-pager

