#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BILLING_DB_USER="${BILLING_DB_USER:-billing}"
BILLING_DB_PASSWORD="${BILLING_DB_PASSWORD:-}"
BILLING_DB_HOST="${BILLING_DB_HOST:-localhost}"
RADIUS_DB_NAME="${RADIUS_DB_NAME:-radius}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}[*] Setting up billing database user...${NC}"

# Get credentials if not provided
if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && [[ -f /root/.freeradius_credentials ]]; then
    source /root/.freeradius_credentials
fi

if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] MariaDB root password required${NC}"
    read -sp "Enter MariaDB root password: " MARIADB_ROOT_PASSWORD
    echo
fi

# Generate password if not provided
if [[ -z "$BILLING_DB_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] Billing password not set. Generating secure password...${NC}"
    BILLING_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo -e "${GREEN}[+] Generated password: $BILLING_DB_PASSWORD${NC}"
    echo -e "${YELLOW}[!] SAVE THIS PASSWORD!${NC}"
    sleep 2
fi

# Determine host for grant
if [[ "$BILLING_DB_HOST" == "localhost" ]] || [[ "$BILLING_DB_HOST" == "127.0.0.1" ]]; then
    GRANT_HOST="localhost"
else
    GRANT_HOST="$BILLING_DB_HOST"
fi

echo -e "${GREEN}[*] Creating billing user...${NC}"
echo -e "  User: ${BILLING_DB_USER}"
echo -e "  Host: ${GRANT_HOST}"
echo -e "  Database: ${RADIUS_DB_NAME}"

# Create user and grant privileges
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
-- Drop user if exists (to allow re-running script)
DROP USER IF EXISTS '${BILLING_DB_USER}'@'${GRANT_HOST}';

-- Create user
CREATE USER '${BILLING_DB_USER}'@'${GRANT_HOST}' IDENTIFIED BY '${BILLING_DB_PASSWORD}';

-- Grant privileges untuk CRUD operations
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radcheck TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radusergroup TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radreply TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radgroupreply TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radgroupcheck TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT ON ${RADIUS_DB_NAME}.radacct TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT ON ${RADIUS_DB_NAME}.radpostauth TO '${BILLING_DB_USER}'@'${GRANT_HOST}';

FLUSH PRIVILEGES;

-- Show granted privileges
SHOW GRANTS FOR '${BILLING_DB_USER}'@'${GRANT_HOST}';
EOF

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[+] Billing user created successfully${NC}"
    
    # Save credentials
    BILLING_CREDS_FILE="/root/.freeradius_billing_credentials"
    cat > "${BILLING_CREDS_FILE}" <<EOF
# Billing Database Credentials
# Generated: $(date)

BILLING_DB_USER="${BILLING_DB_USER}"
BILLING_DB_HOST="${BILLING_DB_HOST}"
BILLING_DB_PASSWORD="${BILLING_DB_PASSWORD}"
RADIUS_DB_NAME="${RADIUS_DB_NAME}"

# Connection String for Billing Server
# MySQL: mysql://${BILLING_DB_USER}:${BILLING_DB_PASSWORD}@${BILLING_DB_HOST}/${RADIUS_DB_NAME}
EOF
    chmod 600 "${BILLING_CREDS_FILE}"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[+] Billing user setup completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Credentials saved to: ${BILLING_CREDS_FILE}${NC}"
    echo -e "${YELLOW}Billing Database Configuration:${NC}"
    echo -e "  Host: ${BILLING_DB_HOST}"
    echo -e "  User: ${BILLING_DB_USER}"
    echo -e "  Password: ${BILLING_DB_PASSWORD}"
    echo -e "  Database: ${RADIUS_DB_NAME}"
    echo ""
    echo -e "${GREEN}Update your billing server configuration:${NC}"
    echo -e "  radius_host: ${BILLING_DB_HOST}"
    echo -e "  radius_user: ${BILLING_DB_USER}"
    echo -e "  radius_password: ${BILLING_DB_PASSWORD}"
    echo -e "  radius_database: ${RADIUS_DB_NAME}"
    echo ""
else
    echo -e "${RED}[!] Failed to create billing user${NC}"
    exit 1
fi

