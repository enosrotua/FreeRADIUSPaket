#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BILLING_DB_USER="${BILLING_DB_USER:-billing}"
BILLING_DB_HOST="${BILLING_DB_HOST:-localhost}"
RADIUS_DB_NAME="${RADIUS_DB_NAME:-radius}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}[*] Updating billing user permissions...${NC}"

# Determine host for grant
if [[ "$BILLING_DB_HOST" == "localhost" ]] || [[ "$BILLING_DB_HOST" == "127.0.0.1" ]]; then
    GRANT_HOST="localhost"
else
    GRANT_HOST="$BILLING_DB_HOST"
fi

# Get credentials if not provided
if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && [[ -f /root/.freeradius_credentials ]]; then
    source /root/.freeradius_credentials
fi

if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && [[ -f /root/.freeradius_billing_credentials ]]; then
    # Try to get password from billing credentials (might have root password info)
    source /root/.freeradius_billing_credentials 2>/dev/null || true
fi

if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
    echo -e "${YELLOW}[!] MariaDB root password required${NC}"
    read -sp "Enter MariaDB root password: " MARIADB_ROOT_PASSWORD
    echo
fi

echo -e "${GREEN}[*] Updating permissions for user '${BILLING_DB_USER}'@'${GRANT_HOST}'...${NC}"
echo -e "  Database: ${RADIUS_DB_NAME}"
echo -e "  Adding: INSERT, UPDATE, DELETE on radreply table"

# Update permissions
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
-- Grant additional permissions untuk radreply (jika belum ada)
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radreply TO '${BILLING_DB_USER}'@'${GRANT_HOST}';

-- Ensure all other permissions are still there
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radcheck TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${RADIUS_DB_NAME}.radusergroup TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE ON ${RADIUS_DB_NAME}.radgroupreply TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT, INSERT, UPDATE ON ${RADIUS_DB_NAME}.radgroupcheck TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT ON ${RADIUS_DB_NAME}.radacct TO '${BILLING_DB_USER}'@'${GRANT_HOST}';
GRANT SELECT ON ${RADIUS_DB_NAME}.radpostauth TO '${BILLING_DB_USER}'@'${GRANT_HOST}';

FLUSH PRIVILEGES;

-- Show granted privileges
SHOW GRANTS FOR '${BILLING_DB_USER}'@'${GRANT_HOST}';
EOF

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[+] Permissions updated successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${GREEN}User '${BILLING_DB_USER}'@'${GRANT_HOST}' sekarang memiliki permission:${NC}"
    echo -e "  ✓ SELECT, INSERT, UPDATE, DELETE on radcheck"
    echo -e "  ✓ SELECT, INSERT, UPDATE, DELETE on radusergroup"
    echo -e "  ✓ SELECT, INSERT, UPDATE, DELETE on radreply"
    echo -e "  ✓ SELECT, INSERT, UPDATE on radgroupreply"
    echo -e "  ✓ SELECT, INSERT, UPDATE on radgroupcheck"
    echo -e "  ✓ SELECT on radacct"
    echo -e "  ✓ SELECT on radpostauth"
    echo ""
else
    echo -e "${RED}[!] Failed to update permissions${NC}"
    exit 1
fi

