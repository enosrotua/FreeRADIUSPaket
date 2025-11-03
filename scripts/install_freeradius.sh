#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables (can be overridden by environment)
RADIUS_DB_NAME="${RADIUS_DB_NAME:-radius}"
RADIUS_DB_USER="${RADIUS_DB_USER:-radius}"
RADIUS_DB_PASSWORD="${RADIUS_DB_PASSWORD:-}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

echo -e "${GREEN}[*] Starting FreeRADIUS installation...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

# Generate secure password if not provided
if [[ -z "$RADIUS_DB_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] RADIUS_DB_PASSWORD not set. Generating secure password...${NC}"
    RADIUS_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo -e "${GREEN}[+] Generated password: $RADIUS_DB_PASSWORD${NC}"
    echo -e "${YELLOW}[!] SAVE THIS PASSWORD! It will not be shown again.${NC}"
    sleep 3
fi

# Generate MariaDB root password if not provided
if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] MARIADB_ROOT_PASSWORD not set. Generating secure password...${NC}"
    MARIADB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo -e "${GREEN}[+] Generated MariaDB root password: $MARIADB_ROOT_PASSWORD${NC}"
    echo -e "${YELLOW}[!] SAVE THIS PASSWORD!${NC}"
    sleep 3
fi

echo -e "${GREEN}[*] Updating package list...${NC}"
# Update package list, continue even if some repositories fail
if ! apt-get update -y 2>&1; then
    echo -e "${YELLOW}[!] Some repository errors detected (may be old/invalid repos)${NC}"
    echo -e "${YELLOW}[!] This is usually non-critical, continuing installation...${NC}"
    # Remove invalid repository references
    if grep -q "impish-security" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
        echo -e "${YELLOW}[!] Attempting to fix invalid repository references...${NC}"
        sed -i '/impish-security/d' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
        echo -e "${GREEN}[+] Removed invalid repository references${NC}"
    fi
fi

echo -e "${GREEN}[*] Installing packages...${NC}"
apt-get install -y \
    freeradius \
    freeradius-mysql \
    freeradius-utils \
    mariadb-server \
    mariadb-client \
    openssl

echo -e "${GREEN}[*] Starting MariaDB service...${NC}"
systemctl enable --now mariadb

# Wait for MariaDB to be ready
echo -e "${GREEN}[*] Waiting for MariaDB to be ready...${NC}"
for i in {1..30}; do
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        break
    fi
    echo -e "${YELLOW}[.] Waiting for MariaDB... ($i/30)${NC}"
    sleep 2
done

# Secure MariaDB installation
echo -e "${GREEN}[*] Configuring MariaDB...${NC}"
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create database and user
echo -e "${GREEN}[*] Creating database and user...${NC}"
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${RADIUS_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${RADIUS_DB_USER}'@'localhost' IDENTIFIED BY '${RADIUS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${RADIUS_DB_NAME}.* TO '${RADIUS_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import FreeRADIUS schema
echo -e "${GREEN}[*] Importing FreeRADIUS database schema...${NC}"
if [[ -f /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql ]]; then
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" ${RADIUS_DB_NAME} < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
    echo -e "${GREEN}[+] Schema imported${NC}"
else
    echo -e "${RED}[!] Schema file not found: /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql${NC}"
    exit 1
fi

# Import setup.sql if exists
if [[ -f /etc/freeradius/3.0/mods-config/sql/main/mysql/setup.sql ]]; then
    echo -e "${GREEN}[*] Importing setup.sql...${NC}"
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" ${RADIUS_DB_NAME} < /etc/freeradius/3.0/mods-config/sql/main/mysql/setup.sql || true
fi

# Copy configuration files
echo -e "${GREEN}[*] Configuring FreeRADIUS...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configure SQL module
if [[ -f "${PROJECT_ROOT}/configs/sql" ]]; then
    cp "${PROJECT_ROOT}/configs/sql" /etc/freeradius/3.0/mods-available/sql
    # Replace database credentials
    sed -i "s|^server = .*|server = \"localhost\"|" /etc/freeradius/3.0/mods-available/sql
    sed -i "s|^port = .*|port = 3306|" /etc/freeradius/3.0/mods-available/sql
    sed -i "s|^login = .*|login = \"${RADIUS_DB_USER}\"|" /etc/freeradius/3.0/mods-available/sql
    sed -i "s|^password = .*|password = \"${RADIUS_DB_PASSWORD}\"|" /etc/freeradius/3.0/mods-available/sql
    sed -i "s|^radius_db = .*|radius_db = \"${RADIUS_DB_NAME}\"|" /etc/freeradius/3.0/mods-available/sql
    
    # Enable SQL module
    ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql || true
    echo -e "${GREEN}[+] SQL module configured${NC}"
fi

# Copy sites-default if provided
if [[ -f "${PROJECT_ROOT}/configs/sites-default" ]]; then
    cp "${PROJECT_ROOT}/configs/sites-default" /etc/freeradius/3.0/sites-available/default
    echo -e "${GREEN}[+] Site configuration copied${NC}"
fi

# Set proper permissions
chown -R freerad:freerad /etc/freeradius/3.0

# Test configuration
echo -e "${GREEN}[*] Testing FreeRADIUS configuration...${NC}"
if freeradius -C &>/dev/null; then
    echo -e "${GREEN}[+] Configuration test passed${NC}"
else
    echo -e "${RED}[!] Configuration test failed. Please check: freeradius -XC${NC}"
    exit 1
fi

# Enable and start FreeRADIUS
echo -e "${GREEN}[*] Enabling FreeRADIUS service...${NC}"
systemctl enable freeradius
systemctl restart freeradius

# Wait for service to start
sleep 2
if systemctl is-active --quiet freeradius; then
    echo -e "${GREEN}[+] FreeRADIUS service started successfully${NC}"
else
    echo -e "${RED}[!] FreeRADIUS service failed to start. Check logs: journalctl -u freeradius${NC}"
    exit 1
fi

# Save credentials to secure file
CREDS_FILE="/root/.freeradius_credentials"
cat > "${CREDS_FILE}" <<EOF
# FreeRADIUS Installation Credentials
# Generated: $(date)
# KEEP THIS FILE SECURE!

MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD}"
RADIUS_DB_NAME="${RADIUS_DB_NAME}"
RADIUS_DB_USER="${RADIUS_DB_USER}"
RADIUS_DB_PASSWORD="${RADIUS_DB_PASSWORD}"
EOF
chmod 600 "${CREDS_FILE}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[+] Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Database Credentials saved to: ${CREDS_FILE}${NC}"
echo -e "${YELLOW}Credentials:${NC}"
echo -e "  MariaDB Root Password: ${MARIADB_ROOT_PASSWORD}"
echo -e "  Database: ${RADIUS_DB_NAME}"
echo -e "  User: ${RADIUS_DB_USER}"
echo -e "  Password: ${RADIUS_DB_PASSWORD}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "  1. Configure NAS clients in /etc/freeradius/3.0/clients.conf"
echo -e "  2. Setup firewall rules (see scripts/setup_firewall.sh)"
echo -e "  3. Import package groups (see sql/groups.sql)"
echo -e "  4. Test authentication: radtest username password 127.0.0.1 0 testing123"
echo ""
