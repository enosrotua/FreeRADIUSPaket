#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/freeradius}"
RADIUS_DB_NAME="${RADIUS_DB_NAME:-radius}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

if [[ $# -eq 0 ]]; then
    echo -e "${YELLOW}Usage: $0 <backup_prefix>${NC}"
    echo -e "Example: $0 freeradius_20241201_120000"
    echo ""
    echo -e "Available backups:"
    ls -1 "${BACKUP_DIR}"/freeradius_*_manifest.txt 2>/dev/null | \
        sed 's|.*/||' | \
        sed 's|_manifest.txt||' | \
        head -10 || echo "  (none found)"
    exit 1
fi

BACKUP_PREFIX="$1"

echo -e "${GREEN}[*] Restoring FreeRADIUS backup: ${BACKUP_PREFIX}${NC}"

# Check if backup exists
if [[ ! -f "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql.gz" ]]; then
    echo -e "${RED}[!] Backup not found: ${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql.gz${NC}"
    exit 1
fi

# Get credentials
if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && [[ -f /root/.freeradius_credentials ]]; then
    source /root/.freeradius_credentials
fi

if [[ -z "$MARIADB_ROOT_PASSWORD" ]]; then
    read -sp "Enter MariaDB root password: " MARIADB_ROOT_PASSWORD
    echo
fi

# Confirm restore
echo -e "${YELLOW}[!] WARNING: This will restore database and may overwrite existing data!${NC}"
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}[*] Restore cancelled${NC}"
    exit 0
fi

# Stop FreeRADIUS
echo -e "${GREEN}[*] Stopping FreeRADIUS service...${NC}"
systemctl stop freeradius

# Restore database
echo -e "${GREEN}[*] Restoring database...${NC}"
zcat "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql.gz" | \
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" "${RADIUS_DB_NAME}"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}[+] Database restored${NC}"
else
    echo -e "${RED}[!] Database restore failed${NC}"
    exit 1
fi

# Restore configuration if exists
if [[ -f "${BACKUP_DIR}/${BACKUP_PREFIX}_config.tar.gz" ]]; then
    echo -e "${GREEN}[*] Restoring configuration...${NC}"
    read -p "Restore configuration files? This will overwrite current config (yes/no): " restore_config
    if [[ "$restore_config" == "yes" ]]; then
        # Backup current config first
        CURRENT_BACKUP="/tmp/freeradius_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "${CURRENT_BACKUP}" /etc/freeradius/3.0/ 2>/dev/null || true
        echo -e "${YELLOW}[*] Current config backed up to: ${CURRENT_BACKUP}${NC}"
        
        # Restore
        tar -xzf "${BACKUP_DIR}/${BACKUP_PREFIX}_config.tar.gz" -C /
        chown -R freerad:freerad /etc/freeradius/3.0
        echo -e "${GREEN}[+] Configuration restored${NC}"
    fi
fi

# Restore credentials if exists
if [[ -f "${BACKUP_DIR}/${BACKUP_PREFIX}_credentials.txt" ]]; then
    echo -e "${GREEN}[*] Restoring credentials...${NC}"
    cp "${BACKUP_DIR}/${BACKUP_PREFIX}_credentials.txt" /root/.freeradius_credentials
    chmod 600 /root/.freeradius_credentials
    echo -e "${GREEN}[+] Credentials restored${NC}"
fi

# Test configuration
echo -e "${GREEN}[*] Testing FreeRADIUS configuration...${NC}"
if freeradius -C &>/dev/null; then
    echo -e "${GREEN}[+] Configuration test passed${NC}"
else
    echo -e "${RED}[!] Configuration test failed! Please check: freeradius -XC${NC}"
    read -p "Continue anyway? (yes/no): " continue_anyway
    if [[ "$continue_anyway" != "yes" ]]; then
        exit 1
    fi
fi

# Start FreeRADIUS
echo -e "${GREEN}[*] Starting FreeRADIUS service...${NC}"
systemctl start freeradius

sleep 2
if systemctl is-active --quiet freeradius; then
    echo -e "${GREEN}[+] FreeRADIUS service started${NC}"
else
    echo -e "${RED}[!] FreeRADIUS service failed to start. Check logs: journalctl -u freeradius${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[+] Restore completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

