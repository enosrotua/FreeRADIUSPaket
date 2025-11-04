#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
RADIUS_DB_USER="${RADIUS_DB_USER:-radius}"
RADIUS_DB_PASSWORD="${RADIUS_DB_PASSWORD:-uoPvB6sQLrPhuSJvBIWtpZhTV}"
RADIUS_DB_NAME="${RADIUS_DB_NAME:-radius}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}[*] Fixing FreeRADIUS database user...${NC}"

# Get credentials if not provided
if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && [[ -f /root/.freeradius_credentials ]]; then
    source /root/.freeradius_credentials
fi

if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] MariaDB root password required${NC}"
    read -sp "Enter MariaDB root password: " MARIADB_ROOT_PASSWORD
    echo
fi

echo -e "${GREEN}[*] Creating/updating user '${RADIUS_DB_USER}'@'localhost'...${NC}"
echo -e "  Database: ${RADIUS_DB_NAME}"
echo -e "  Password: ${RADIUS_DB_PASSWORD}"

# Create or update user
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
-- Create user if not exists, or update password if exists
CREATE USER IF NOT EXISTS '${RADIUS_DB_USER}'@'localhost' IDENTIFIED BY '${RADIUS_DB_PASSWORD}';

-- If user exists, update password
ALTER USER '${RADIUS_DB_USER}'@'localhost' IDENTIFIED BY '${RADIUS_DB_PASSWORD}';

-- Grant all privileges on radius database
GRANT ALL PRIVILEGES ON ${RADIUS_DB_NAME}.* TO '${RADIUS_DB_USER}'@'localhost';

FLUSH PRIVILEGES;

-- Verify user exists
SELECT user, host FROM mysql.user WHERE user='${RADIUS_DB_USER}';
EOF

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[+] FreeRADIUS user fixed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Now restarting FreeRADIUS service...${NC}"
    systemctl restart freeradius
    
    sleep 2
    
    if systemctl is-active --quiet freeradius; then
        echo -e "${GREEN}[+] FreeRADIUS is now running!${NC}"
        echo ""
        echo -e "${GREEN}Verification:${NC}"
        systemctl status freeradius --no-pager | head -10
    else
        echo -e "${RED}[!] FreeRADIUS failed to start. Check logs:${NC}"
        echo -e "  sudo journalctl -u freeradius -n 50"
    fi
else
    echo -e "${RED}[!] Failed to fix FreeRADIUS user${NC}"
    exit 1
fi

