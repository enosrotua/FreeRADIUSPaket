#!/usr/bin/env bash
# Script untuk memperbaiki Session-Timeout dan Idle-Timeout dari format m/h/d ke detik

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get billing password
if [[ -f /root/.freeradius_billing_credentials ]]; then
    source /root/.freeradius_billing_credentials
fi

if [[ -z "${BILLING_DB_PASSWORD:-}" ]]; then
    echo -e "${RED}[!] BILLING_DB_PASSWORD tidak ditemukan${NC}"
    exit 1
fi

echo -e "${GREEN}[*] Memperbaiki Session-Timeout dan Idle-Timeout ke format detik...${NC}"

# Function untuk konversi ke detik
convert_to_seconds() {
    local value="$1"
    local num=$(echo "$value" | sed 's/[^0-9]//g')
    local unit=$(echo "$value" | sed 's/[0-9]//g' | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$num" ]] || [[ "$num" -le 0 ]]; then
        echo "0"
        return
    fi
    
    case "$unit" in
        s|detik|"")
            echo "$num"
            ;;
        m|menit|men)
            echo $((num * 60))
            ;;
        h|jam)
            echo $((num * 3600))
            ;;
        d|hari)
            echo $((num * 86400))
            ;;
        *)
            echo "$num"
            ;;
    esac
}

# Get semua timeout yang masih menggunakan format salah
mysql -u billing -p"${BILLING_DB_PASSWORD}" radius <<EOF | while IFS=$'\t' read -r groupname attribute value; do
    SELECT groupname, attribute, value 
    FROM radgroupreply 
    WHERE attribute IN ('Session-Timeout', 'Idle-Timeout') 
    AND (value LIKE '%m' OR value LIKE '%h' OR value LIKE '%d' OR value LIKE '%s')
    AND value NOT REGEXP '^[0-9]+$'
    ORDER BY groupname, attribute;
EOF
    if [[ -n "$groupname" ]] && [[ -n "$attribute" ]] && [[ -n "$value" ]]; then
        seconds=$(convert_to_seconds "$value")
        if [[ "$seconds" -gt 0 ]]; then
            echo -e "${YELLOW}[*] Memperbaiki ${groupname}: ${attribute} = ${value} -> ${seconds} detik${NC}"
            mysql -u billing -p"${BILLING_DB_PASSWORD}" radius <<EOF
                UPDATE radgroupreply 
                SET value = '${seconds}' 
                WHERE groupname = '${groupname}' 
                AND attribute = '${attribute}' 
                AND value = '${value}';
EOF
        fi
    fi
done

echo -e "${GREEN}[+] Selesai memperbaiki semua timeout${NC}"

# Verifikasi
echo -e "${GREEN}[*] Verifikasi hasil:${NC}"
mysql -u billing -p"${BILLING_DB_PASSWORD}" radius <<EOF
    SELECT groupname, attribute, value 
    FROM radgroupreply 
    WHERE attribute IN ('Session-Timeout', 'Idle-Timeout') 
    ORDER BY groupname, attribute;
EOF

