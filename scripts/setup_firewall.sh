#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root${NC}" 
   exit 1
fi

# Configuration
RADIUS_AUTH_PORT="${RADIUS_AUTH_PORT:-1812}"
RADIUS_ACCT_PORT="${RADIUS_ACCT_PORT:-1813}"
MIKROTIK_IPS="${MIKROTIK_IPS:-}"

echo -e "${GREEN}[*] Setting up firewall for FreeRADIUS...${NC}"

# Detect firewall type
if command -v ufw &> /dev/null; then
    FIREWALL_TYPE="ufw"
elif command -v firewall-cmd &> /dev/null; then
    FIREWALL_TYPE="firewalld"
elif command -v iptables &> /dev/null; then
    FIREWALL_TYPE="iptables"
else
    echo -e "${RED}[!] No firewall tool detected (ufw/firewalld/iptables)${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Detected firewall: ${FIREWALL_TYPE}${NC}"

case $FIREWALL_TYPE in
    ufw)
        # UFW Configuration
        echo -e "${GREEN}[*] Configuring UFW...${NC}"
        
        # Allow localhost
        ufw allow from 127.0.0.1 to any port ${RADIUS_AUTH_PORT} proto udp
        ufw allow from 127.0.0.1 to any port ${RADIUS_ACCT_PORT} proto udp
        
        # If Mikrotik IPs provided, allow only those
        if [[ -n "$MIKROTIK_IPS" ]]; then
            IFS=',' read -ra IPS <<< "$MIKROTIK_IPS"
            for ip in "${IPS[@]}"; do
                ip=$(echo "$ip" | xargs) # trim whitespace
                echo -e "${GREEN}[+] Allowing RADIUS from Mikrotik: ${ip}${NC}"
                ufw allow from "${ip}" to any port ${RADIUS_AUTH_PORT} proto udp
                ufw allow from "${ip}" to any port ${RADIUS_ACCT_PORT} proto udp
            done
        else
            echo -e "${YELLOW}[!] MIKROTIK_IPS not set. Opening ports to all (NOT RECOMMENDED FOR PRODUCTION)${NC}"
            echo -e "${YELLOW}[!] Set MIKROTIK_IPS environment variable with comma-separated IPs${NC}"
            read -p "Continue anyway? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                exit 1
            fi
            ufw allow ${RADIUS_AUTH_PORT}/udp
            ufw allow ${RADIUS_ACCT_PORT}/udp
        fi
        
        # Enable UFW if not already enabled
        if ! ufw status | grep -q "Status: active"; then
            echo -e "${GREEN}[*] Enabling UFW...${NC}"
            ufw --force enable
        fi
        
        echo -e "${GREEN}[+] UFW configured${NC}"
        ;;
        
    firewalld)
        # Firewalld Configuration
        echo -e "${GREEN}[*] Configuring Firewalld...${NC}"
        
        # Create custom service
        firewall-cmd --permanent --new-service=freeradius-auth
        firewall-cmd --permanent --service=freeradius-auth --set-description="FreeRADIUS Authentication"
        firewall-cmd --permanent --service=freeradius-auth --add-port=${RADIUS_AUTH_PORT}/udp
        
        firewall-cmd --permanent --new-service=freeradius-acct
        firewall-cmd --permanent --service=freeradius-acct --set-description="FreeRADIUS Accounting"
        firewall-cmd --permanent --service=freeradius-acct --add-port=${RADIUS_ACCT_PORT}/udp
        
        # Allow localhost
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='127.0.0.1' service name='freeradius-auth' accept"
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='127.0.0.1' service name='freeradius-acct' accept"
        
        # If Mikrotik IPs provided
        if [[ -n "$MIKROTIK_IPS" ]]; then
            IFS=',' read -ra IPS <<< "$MIKROTIK_IPS"
            for ip in "${IPS[@]}"; do
                ip=$(echo "$ip" | xargs)
                echo -e "${GREEN}[+] Allowing RADIUS from Mikrotik: ${ip}${NC}"
                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${ip}' service name='freeradius-auth' accept"
                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${ip}' service name='freeradius-acct' accept"
            done
        else
            echo -e "${YELLOW}[!] MIKROTIK_IPS not set. Opening ports to all (NOT RECOMMENDED)${NC}"
            firewall-cmd --permanent --add-service=freeradius-auth
            firewall-cmd --permanent --add-service=freeradius-acct
        fi
        
        firewall-cmd --reload
        echo -e "${GREEN}[+] Firewalld configured${NC}"
        ;;
        
    iptables)
        # iptables Configuration
        echo -e "${GREEN}[*] Configuring iptables...${NC}"
        
        # Allow localhost
        iptables -A INPUT -p udp -s 127.0.0.1 --dport ${RADIUS_AUTH_PORT} -j ACCEPT
        iptables -A INPUT -p udp -s 127.0.0.1 --dport ${RADIUS_ACCT_PORT} -j ACCEPT
        
        # If Mikrotik IPs provided
        if [[ -n "$MIKROTIK_IPS" ]]; then
            IFS=',' read -ra IPS <<< "$MIKROTIK_IPS"
            for ip in "${IPS[@]}"; do
                ip=$(echo "$ip" | xargs)
                echo -e "${GREEN}[+] Allowing RADIUS from Mikrotik: ${ip}${NC}"
                iptables -A INPUT -p udp -s "${ip}" --dport ${RADIUS_AUTH_PORT} -j ACCEPT
                iptables -A INPUT -p udp -s "${ip}" --dport ${RADIUS_ACCT_PORT} -j ACCEPT
            done
        else
            echo -e "${YELLOW}[!] MIKROTIK_IPS not set. Opening ports to all (NOT RECOMMENDED)${NC}"
            iptables -A INPUT -p udp --dport ${RADIUS_AUTH_PORT} -j ACCEPT
            iptables -A INPUT -p udp --dport ${RADIUS_ACCT_PORT} -j ACCEPT
        fi
        
        # Save iptables rules (distribution-specific)
        if command -v netfilter-persistent &> /dev/null; then
            netfilter-persistent save
        elif [[ -f /etc/redhat-release ]]; then
            service iptables save
        elif [[ -f /etc/debian_version ]]; then
            iptables-save > /etc/iptables/rules.v4
        fi
        
        echo -e "${GREEN}[+] iptables configured${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[+] Firewall configured successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Current firewall rules:${NC}"
case $FIREWALL_TYPE in
    ufw) ufw status numbered ;;
    firewalld) firewall-cmd --list-all ;;
    iptables) iptables -L -n -v | grep -E "(1812|1813)" || iptables -L INPUT -n -v ;;
esac
echo ""

