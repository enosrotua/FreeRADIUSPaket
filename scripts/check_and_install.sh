#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[*] Checking FreeRADIUS installation...${NC}"

# Check if FreeRADIUS is installed
if command -v freeradius &> /dev/null || dpkg -l | grep -q "^ii.*freeradius"; then
    echo -e "${GREEN}[+] FreeRADIUS is already installed${NC}"
    
    # Check if directory exists
    if [ -d "/etc/freeradius/3.0" ]; then
        echo -e "${GREEN}[+] Config directory exists: /etc/freeradius/3.0${NC}"
        
        # Check if properly configured
        if [ -f "/etc/freeradius/3.0/mods-enabled/sql" ]; then
            echo -e "${GREEN}[+] SQL module is enabled${NC}"
            
            # Check if database is set up
            if mysql -u radius -pradius -e "USE radius;" &>/dev/null 2>&1; then
                echo -e "${GREEN}[+] Database connection OK${NC}"
                echo -e "${GREEN}[+] FreeRADIUS is ready!${NC}"
                exit 0
            else
                echo -e "${YELLOW}[!] Database exists but connection failed${NC}"
                echo -e "${YELLOW}[!] Running installation script to fix configuration...${NC}"
            fi
        else
            echo -e "${YELLOW}[!] SQL module not enabled, running installation script...${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Config directory not found, running installation script...${NC}"
    fi
else
    echo -e "${YELLOW}[!] FreeRADIUS not installed, running installation script...${NC}"
fi

# Run installation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/install_freeradius.sh"

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}[!] Installation script not found: $INSTALL_SCRIPT${NC}"
    exit 1
fi

echo -e "${GREEN}[*] Running installation script...${NC}"
bash "$INSTALL_SCRIPT"

