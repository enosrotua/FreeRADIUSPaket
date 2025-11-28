#!/bin/bash
#
# Script untuk memperbaiki konfigurasi FreeRADIUS
# Memperbaiki:
# 1. Client localhost_ipv6 yang tidak memiliki ipv6addr
# 2. Attribute Max-All-Session dan Expire-After yang tidak ada di dictionary
#
# Usage: sudo ./fix-freeradius-config.sh

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Path konfigurasi
CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"
DICTIONARY="/etc/freeradius/3.0/dictionary"
BACKUP_DIR="/etc/freeradius/3.0/backups"

# Fungsi untuk logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then 
    log_error "Script ini harus dijalankan sebagai root (gunakan sudo)"
    exit 1
fi

log_info "Memulai perbaikan konfigurasi FreeRADIUS..."

# Buat backup directory jika belum ada
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ============================================
# 1. Perbaiki clients.conf - localhost_ipv6
# ============================================
log_info "Memeriksa clients.conf..."

if [ ! -f "$CLIENTS_CONF" ]; then
    log_error "File $CLIENTS_CONF tidak ditemukan!"
    exit 1
fi

# Backup clients.conf
if [ ! -f "${CLIENTS_CONF}.backup.${TIMESTAMP}" ]; then
    cp "$CLIENTS_CONF" "${CLIENTS_CONF}.backup.${TIMESTAMP}"
    log_info "Backup dibuat: ${CLIENTS_CONF}.backup.${TIMESTAMP}"
fi

# Cek apakah localhost_ipv6 sudah memiliki ipv6addr
if grep -q "client localhost_ipv6" "$CLIENTS_CONF"; then
    if grep -A 5 "client localhost_ipv6" "$CLIENTS_CONF" | grep -q "ipv6addr"; then
        log_info "Client localhost_ipv6 sudah memiliki ipv6addr"
    else
        log_warn "Client localhost_ipv6 tidak memiliki ipv6addr, menambahkan..."
        
        # Gunakan sed untuk menambahkan ipv6addr sebelum closing brace
        sed -i '/client localhost_ipv6 {/,/^}$/ {
            /require_message_authenticator = no/a\
	ipv6addr = ::1
        }' "$CLIENTS_CONF"
        
        log_info "ipv6addr = ::1 ditambahkan ke client localhost_ipv6"
    fi
else
    log_warn "Client localhost_ipv6 tidak ditemukan di clients.conf"
fi

# ============================================
# 2. Perbaiki dictionary - tambahkan attribute
# ============================================
log_info "Memeriksa dictionary..."

if [ ! -f "$DICTIONARY" ]; then
    log_error "File $DICTIONARY tidak ditemukan!"
    exit 1
fi

# Backup dictionary
if [ ! -f "${DICTIONARY}.backup.${TIMESTAMP}" ]; then
    cp "$DICTIONARY" "${DICTIONARY}.backup.${TIMESTAMP}"
    log_info "Backup dibuat: ${DICTIONARY}.backup.${TIMESTAMP}"
fi

# Cek dan tambahkan attribute jika belum ada
ATTRIBUTES_ADDED=0

# Cek Max-All-Session
if ! grep -q "^ATTRIBUTE.*Max-All-Session" "$DICTIONARY"; then
    log_warn "Attribute Max-All-Session tidak ditemukan, menambahkan..."
    
    # Cek apakah sudah ada section CVLMEDIA Custom Attributes
    if grep -q "# CVLMEDIA Custom Attributes" "$DICTIONARY"; then
        # Tambahkan setelah baris CVLMEDIA Custom Attributes
        sed -i '/# CVLMEDIA Custom Attributes/a ATTRIBUTE\tMax-All-Session\t\t3000\tinteger' "$DICTIONARY"
    else
        # Tambahkan di akhir file
        echo "" >> "$DICTIONARY"
        echo "# CVLMEDIA Custom Attributes" >> "$DICTIONARY"
        echo "ATTRIBUTE	Max-All-Session		3000	integer" >> "$DICTIONARY"
    fi
    
    ATTRIBUTES_ADDED=1
    log_info "Attribute Max-All-Session ditambahkan"
else
    log_info "Attribute Max-All-Session sudah ada"
fi

# Cek Expire-After
if ! grep -q "^ATTRIBUTE.*Expire-After" "$DICTIONARY"; then
    log_warn "Attribute Expire-After tidak ditemukan, menambahkan..."
    
    # Tambahkan setelah Max-All-Session
    if grep -q "Max-All-Session" "$DICTIONARY"; then
        sed -i '/ATTRIBUTE.*Max-All-Session/a ATTRIBUTE\tExpire-After\t\t3001\tinteger' "$DICTIONARY"
    else
        # Jika Max-All-Session tidak ada, tambahkan di akhir
        if grep -q "# CVLMEDIA Custom Attributes" "$DICTIONARY"; then
            sed -i '/# CVLMEDIA Custom Attributes/a ATTRIBUTE\tExpire-After\t\t3001\tinteger' "$DICTIONARY"
        else
            echo "ATTRIBUTE	Expire-After		3001	integer" >> "$DICTIONARY"
        fi
    fi
    
    ATTRIBUTES_ADDED=1
    log_info "Attribute Expire-After ditambahkan"
else
    log_info "Attribute Expire-After sudah ada"
fi

# ============================================
# 3. Validasi konfigurasi
# ============================================
log_info "Memvalidasi konfigurasi FreeRADIUS..."

if command -v freeradius &> /dev/null; then
    if freeradius -Cx -lstdout 2>&1 | grep -q "Configuration appears to be OK"; then
        log_info "Konfigurasi valid!"
    else
        log_error "Konfigurasi tidak valid! Cek error di atas."
        log_warn "Mengembalikan dari backup..."
        cp "${CLIENTS_CONF}.backup.${TIMESTAMP}" "$CLIENTS_CONF"
        cp "${DICTIONARY}.backup.${TIMESTAMP}" "$DICTIONARY"
        exit 1
    fi
else
    log_warn "freeradius command tidak ditemukan, skip validasi"
fi

# ============================================
# 4. Restart FreeRADIUS jika perlu
# ============================================
if [ "$ATTRIBUTES_ADDED" -eq 1 ] || systemctl is-active --quiet freeradius; then
    log_info "Merestart FreeRADIUS service..."
    
    if systemctl restart freeradius 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet freeradius; then
            log_info "FreeRADIUS berhasil direstart"
        else
            log_error "FreeRADIUS gagal start setelah restart"
            log_warn "Cek log: sudo journalctl -u freeradius -n 50"
            exit 1
        fi
    else
        log_warn "Gagal restart FreeRADIUS, coba restart manual: sudo systemctl restart freeradius"
    fi
fi

# ============================================
# 5. Verifikasi final
# ============================================
log_info "Verifikasi final..."

# Cek service status
if systemctl is-active --quiet freeradius; then
    log_info "✓ FreeRADIUS service: ACTIVE"
else
    log_error "✗ FreeRADIUS service: INACTIVE"
fi

# Cek port listening
if ss -luna 'sport = :1812 or sport = :1813' 2>/dev/null | grep -q ":1812\|:1813"; then
    log_info "✓ Port 1812/1813: LISTENING"
else
    log_warn "✗ Port 1812/1813: NOT LISTENING"
fi

# Cek clients.conf
if grep -A 5 "client localhost_ipv6" "$CLIENTS_CONF" | grep -q "ipv6addr"; then
    log_info "✓ Client localhost_ipv6: OK (memiliki ipv6addr)"
else
    log_warn "✗ Client localhost_ipv6: MASALAH (tidak memiliki ipv6addr)"
fi

# Cek dictionary
if grep -q "^ATTRIBUTE.*Max-All-Session" "$DICTIONARY" && grep -q "^ATTRIBUTE.*Expire-After" "$DICTIONARY"; then
    log_info "✓ Dictionary: OK (Max-All-Session dan Expire-After ada)"
else
    log_warn "✗ Dictionary: MASALAH (attribute tidak lengkap)"
fi

echo ""
log_info "Perbaikan selesai!"
log_info "Backup file tersimpan di: $BACKUP_DIR"
echo ""
log_info "Untuk test, jalankan:"
echo "  radtest <username> <password> 127.0.0.1 0 <secret>"
echo ""

