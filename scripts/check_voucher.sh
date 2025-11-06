#!/bin/bash
# Script untuk check voucher di database RADIUS

VOUCHER_USERNAME="${1:-cvIB1QN}"

echo "🔍 Checking voucher: $VOUCHER_USERNAME"
echo ""

# Try to get password from credentials file
if [ -f /root/.freeradius_credentials ]; then
    source /root/.freeradius_credentials
fi

# Try billing password from CVLMEDIA settings
if [ -f /home/enos/cvlmedia/settings.json ]; then
    BILLING_PASS=$(grep -A 2 '"radius_password"' /home/enos/cvlmedia/settings.json 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
fi

# Try to connect with billing user
if [ -n "$BILLING_PASS" ]; then
    echo "📊 Checking radcheck table..."
    mysql -u billing -p"$BILLING_PASS" radius -e "SELECT username, attribute, op, value FROM radcheck WHERE username = '$VOUCHER_USERNAME';" 2>/dev/null || echo "❌ Cannot connect with billing user"
    
    echo ""
    echo "📊 Checking radusergroup table..."
    mysql -u billing -p"$BILLING_PASS" radius -e "SELECT username, groupname, priority FROM radusergroup WHERE username = '$VOUCHER_USERNAME';" 2>/dev/null || echo "❌ Cannot connect with billing user"
    
    echo ""
    echo "📊 Checking radgroupreply (group attributes)..."
    mysql -u billing -p"$BILLING_PASS" radius -e "SELECT groupname, attribute, op, value FROM radgroupreply WHERE groupname IN (SELECT groupname FROM radusergroup WHERE username = '$VOUCHER_USERNAME');" 2>/dev/null || echo "❌ Cannot connect with billing user"
    
    echo ""
    echo "📊 Checking radreply (user-specific attributes)..."
    mysql -u billing -p"$BILLING_PASS" radius -e "SELECT username, attribute, op, value FROM radreply WHERE username = '$VOUCHER_USERNAME';" 2>/dev/null || echo "❌ Cannot connect with billing user"
else
    echo "⚠️  Cannot find billing password. Trying with root..."
    
    if [ -n "$MARIADB_ROOT_PASSWORD" ]; then
        mysql -u root -p"$MARIADB_ROOT_PASSWORD" radius -e "SELECT username, attribute, op, value FROM radcheck WHERE username = '$VOUCHER_USERNAME';" 2>/dev/null || echo "❌ Cannot connect"
        mysql -u root -p"$MARIADB_ROOT_PASSWORD" radius -e "SELECT username, groupname FROM radusergroup WHERE username = '$VOUCHER_USERNAME';" 2>/dev/null || echo "❌ Cannot connect"
    else
        echo "❌ Cannot find database credentials"
        echo ""
        echo "Please run manually:"
        echo "  mysql -u billing -p radius"
        echo "  SELECT * FROM radcheck WHERE username = '$VOUCHER_USERNAME';"
        echo "  SELECT * FROM radusergroup WHERE username = '$VOUCHER_USERNAME';"
    fi
fi

echo ""
echo "🧪 Testing authentication..."
radtest "$VOUCHER_USERNAME" "$VOUCHER_USERNAME" 127.0.0.1 0 testing123 2>&1 | grep -E "Access-Accept|Access-Reject|Expected"

