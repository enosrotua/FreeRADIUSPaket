#!/bin/bash
# Script untuk menambahkan Mikrotik sebagai RADIUS client

set -e

CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root"
    exit 1
fi

echo "🔧 Add Mikrotik as RADIUS Client"
echo ""

# Get IP address
read -p "Enter Mikrotik Router IP address: " MIKROTIK_IP

if [ -z "$MIKROTIK_IP" ]; then
    echo "❌ IP address is required"
    exit 1
fi

# Get secret
read -p "Enter RADIUS secret (default: testing123): " RADIUS_SECRET
RADIUS_SECRET=${RADIUS_SECRET:-testing123}

# Get client name
read -p "Enter client name (default: mikrotik-$(echo $MIKROTIK_IP | tr '.' '-')): " CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-mikrotik-$(echo $MIKROTIK_IP | tr '.' '-')}

# Check if IP already exists
if grep -q "ipaddr = $MIKROTIK_IP" "$CLIENTS_CONF"; then
    echo "⚠️  IP $MIKROTIK_IP already exists in clients.conf"
    read -p "Do you want to update it? (y/n): " UPDATE
    if [ "$UPDATE" != "y" ]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Backup clients.conf
cp "$CLIENTS_CONF" "${CLIENTS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created: ${CLIENTS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

# Add client configuration
CLIENT_CONFIG="
client $CLIENT_NAME {
    ipaddr = $MIKROTIK_IP
    secret = $RADIUS_SECRET
    require_message_authenticator = no
    nas_type = mikrotik
}
"

# Append to clients.conf
echo "$CLIENT_CONFIG" >> "$CLIENTS_CONF"
echo "✅ Client added to clients.conf"

# Test configuration
echo ""
echo "🧪 Testing FreeRADIUS configuration..."
if freeradius -Cx > /dev/null 2>&1; then
    echo "✅ Configuration is valid"
else
    echo "❌ Configuration error! Restoring backup..."
    mv "${CLIENTS_CONF}.backup.$(date +%Y%m%d_%H%M%S)" "$CLIENTS_CONF"
    exit 1
fi

# Restart FreeRADIUS
echo ""
read -p "Restart FreeRADIUS service? (y/n): " RESTART
if [ "$RESTART" = "y" ]; then
    systemctl restart freeradius
    sleep 2
    if systemctl is-active --quiet freeradius; then
        echo "✅ FreeRADIUS restarted successfully"
    else
        echo "❌ FreeRADIUS failed to start. Check logs: journalctl -u freeradius"
        exit 1
    fi
fi

echo ""
echo "✅ Done!"
echo ""
echo "📋 Summary:"
echo "   Client Name: $CLIENT_NAME"
echo "   IP Address: $MIKROTIK_IP"
echo "   Secret: $RADIUS_SECRET"
echo ""
echo "🧪 Next steps:"
echo "   1. Configure RADIUS client in Mikrotik:"
echo "      /radius add address=$MIKROTIK_IP secret=$RADIUS_SECRET service=hotspot"
echo "   2. Enable RADIUS in Hotspot:"
echo "      /ip hotspot set use-radius=yes"
echo "   3. Test authentication from Mikrotik:"
echo "      /radius test <server-name> user=rt password=rt"

