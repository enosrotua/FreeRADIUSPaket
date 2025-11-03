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
RADIUS_DB_USER="${RADIUS_DB_USER:-radius}"
RADIUS_DB_PASSWORD="${RADIUS_DB_PASSWORD:-}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}[*] Starting FreeRADIUS backup...${NC}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Get credentials from saved file if not set
if [[ -z "$RADIUS_DB_PASSWORD" ]] && [[ -f /root/.freeradius_credentials ]]; then
    source /root/.freeradius_credentials
fi

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PREFIX="freeradius_${TIMESTAMP}"

# Backup database
echo -e "${GREEN}[*] Backing up database...${NC}"
if [[ -n "$MARIADB_ROOT_PASSWORD" ]]; then
    mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        "${RADIUS_DB_NAME}" > "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql"
elif [[ -n "$RADIUS_DB_PASSWORD" ]]; then
    mysqldump -u "${RADIUS_DB_USER}" -p"${RADIUS_DB_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        "${RADIUS_DB_NAME}" > "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql"
else
    echo -e "${RED}[!] Database password not set${NC}"
    exit 1
fi

if [[ -f "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql" ]]; then
    echo -e "${GREEN}[+] Database backup created: ${BACKUP_PREFIX}_database.sql${NC}"
    # Compress database backup
    gzip "${BACKUP_DIR}/${BACKUP_PREFIX}_database.sql"
    echo -e "${GREEN}[+] Database backup compressed${NC}"
else
    echo -e "${RED}[!] Database backup failed${NC}"
    exit 1
fi

# Backup FreeRADIUS configuration
echo -e "${GREEN}[*] Backing up configuration...${NC}"
tar -czf "${BACKUP_DIR}/${BACKUP_PREFIX}_config.tar.gz" \
    /etc/freeradius/3.0/ \
    2>/dev/null || true

if [[ -f "${BACKUP_DIR}/${BACKUP_PREFIX}_config.tar.gz" ]]; then
    echo -e "${GREEN}[+] Configuration backup created: ${BACKUP_PREFIX}_config.tar.gz${NC}"
else
    echo -e "${YELLOW}[!] Configuration backup failed (may not exist)${NC}"
fi

# Backup credentials file if exists
if [[ -f /root/.freeradius_credentials ]]; then
    cp /root/.freeradius_credentials "${BACKUP_DIR}/${BACKUP_PREFIX}_credentials.txt"
    chmod 600 "${BACKUP_DIR}/${BACKUP_PREFIX}_credentials.txt"
    echo -e "${GREEN}[+] Credentials backup created${NC}"
fi

# Create backup manifest
cat > "${BACKUP_DIR}/${BACKUP_PREFIX}_manifest.txt" <<EOF
FreeRADIUS Backup Manifest
==========================
Backup Date: $(date)
Backup Type: Full
Components:
  - Database: ${RADIUS_DB_NAME}
  - Configuration: /etc/freeradius/3.0/
  - Credentials: /root/.freeradius_credentials

Files:
  - ${BACKUP_PREFIX}_database.sql.gz
  - ${BACKUP_PREFIX}_config.tar.gz
  - ${BACKUP_PREFIX}_credentials.txt
  - ${BACKUP_PREFIX}_manifest.txt

Restore Instructions:
  1. Extract config: tar -xzf ${BACKUP_PREFIX}_config.tar.gz -C /
  2. Restore database: zcat ${BACKUP_PREFIX}_database.sql.gz | mysql -u root -p ${RADIUS_DB_NAME}
  3. Restore credentials: cp ${BACKUP_PREFIX}_credentials.txt /root/.freeradius_credentials
  4. Restart service: systemctl restart freeradius
EOF

echo -e "${GREEN}[+] Backup manifest created${NC}"

# Cleanup old backups
echo -e "${GREEN}[*] Cleaning up backups older than ${RETENTION_DAYS} days...${NC}"
find "${BACKUP_DIR}" -name "freeradius_*" -type f -mtime +${RETENTION_DAYS} -delete
echo -e "${GREEN}[+] Cleanup completed${NC}"

# Show backup summary
BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_PREFIX}"* 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[+] Backup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Backup location: ${BACKUP_DIR}"
echo -e "Backup prefix: ${BACKUP_PREFIX}"
echo -e "Files created:"
ls -lh "${BACKUP_DIR}/${BACKUP_PREFIX}"* 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  (none)"
echo ""

