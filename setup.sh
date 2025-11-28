#!/usr/bin/env bash
#
# Setup script - Auto-detect dan install FreeRADIUS jika belum ada
# Setelah git clone/pull, jalankan: bash setup.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   FreeRADIUS Paket - Auto Setup Cvlmedia By Enos Rotua   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Check FreeRADIUS installation
echo -e "${GREEN}[*] Checking FreeRADIUS installation...${NC}"

NEEDS_INSTALL=false

# Check if binary exists
if ! command -v freeradius &> /dev/null && ! command -v radiusd &> /dev/null; then
    echo -e "${YELLOW}[!] FreeRADIUS binary not found${NC}"
    NEEDS_INSTALL=true
fi

# Check if config directory exists
if [ ! -d "/etc/freeradius/3.0" ]; then
    echo -e "${YELLOW}[!] Config directory /etc/freeradius/3.0 not found${NC}"
    NEEDS_INSTALL=true
fi

# Check if SQL module configured
if [ -d "/etc/freeradius/3.0" ] && [ ! -f "/etc/freeradius/3.0/mods-enabled/sql" ]; then
    echo -e "${YELLOW}[!] SQL module not configured${NC}"
    NEEDS_INSTALL=true
fi

if [ "$NEEDS_INSTALL" = false ]; then
    echo -e "${GREEN}[+] FreeRADIUS appears to be installed and configured${NC}"
    
    # Verify database connection
    echo -e "${GREEN}[*] Verifying database connection...${NC}"
    if mysql -u radius -pradius -e "USE radius;" &>/dev/null 2>&1; then
        echo -e "${GREEN}[+] Database connection OK${NC}"
        
        # Apply configuration fixes (idempotent - safe to run multiple times)
        echo -e "${GREEN}[*] Menerapkan perbaikan konfigurasi (jika diperlukan)...${NC}"
        FIX_SCRIPT="${SCRIPT_DIR}/scripts/fix-freeradius-config.sh"
        if [[ -f "$FIX_SCRIPT" ]]; then
            if bash "$FIX_SCRIPT" 2>/dev/null; then
                echo -e "${GREEN}[+] Konfigurasi sudah diperiksa dan diperbaiki${NC}"
            else
                echo -e "${YELLOW}[!] Perbaikan konfigurasi gagal, tetapi tidak kritis${NC}"
            fi
        else
            echo -e "${YELLOW}[!] Fix script tidak ditemukan: $FIX_SCRIPT${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✅ FreeRADIUS is ready!${NC}"
        echo ""
    echo "Next steps:"
    echo "  1. Setup billing user: sudo bash scripts/setup_billing_user.sh"
    echo "  2. Setup billing application: bash scripts/setup_billing.sh"
    echo "  3. Configure Mikrotik clients: see docs/MIKROTIK_RADIUS_SETUP.md"
    echo "  4. Setup firewall: sudo bash scripts/setup_firewall.sh"
    exit 0
    else
        echo -e "${YELLOW}[!] Database connection failed, may need reconfiguration${NC}"
        NEEDS_INSTALL=true
    fi
fi

if [ "$NEEDS_INSTALL" = true ]; then
    echo -e "${YELLOW}[!] FreeRADIUS needs to be installed or reconfigured${NC}"
    echo ""
    echo -e "${GREEN}[*] Running installation script...${NC}"
    echo ""
    
    # Run install script
    bash "${SCRIPT_DIR}/scripts/install_freeradius.sh"
    
    echo ""
    echo -e "${GREEN}✅ Installation completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Setup billing user: sudo bash scripts/setup_billing_user.sh"
    echo "  2. Setup billing application: bash scripts/setup_billing.sh"
    echo "  3. Configure Mikrotik clients: see docs/MIKROTIK_RADIUS_SETUP.md"
    echo "  4. Setup firewall: sudo bash scripts/setup_firewall.sh"
fi

