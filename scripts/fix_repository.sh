#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[*] Fixing repository issues...${NC}"

# Remove invalid impish-security repository
echo -e "${YELLOW}[!] Removing invalid repository references...${NC}"

# Fix sources.list
if [ -f /etc/apt/sources.list ]; then
    sed -i '/impish-security/d' /etc/apt/sources.list
    echo -e "${GREEN}[+] Cleaned /etc/apt/sources.list${NC}"
fi

# Fix sources.list.d files
for file in /etc/apt/sources.list.d/*.list; do
    if [ -f "$file" ]; then
        sed -i '/impish-security/d' "$file"
        if grep -q "impish-security" "$file" 2>/dev/null; then
            echo -e "${GREEN}[+] Cleaned $(basename $file)${NC}"
        fi
    fi
done

echo -e "${GREEN}[*] Updating package list...${NC}"
apt-get update -y

echo -e "${GREEN}[+] Repository issues fixed!${NC}"
echo -e "${GREEN}[+] You can now run: sudo bash setup.sh${NC}"

