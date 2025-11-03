# Production Deployment Guide - FreeRADIUS Server

Panduan lengkap untuk deploy FreeRADIUS server ke production environment.

## 📋 Prerequisites

- Ubuntu/Debian server (minimal Ubuntu 20.04 atau Debian 11)
- Root atau sudo access
- Akses internet untuk download packages
- IP address yang akan digunakan untuk RADIUS server
- Daftar IP Mikrotik yang akan mengakses RADIUS

## 🚀 Step 1: Preparation

### 1.1 Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y openssl curl
```

### 1.2 Setup Environment Variables

Buat file `.env` atau export variables:

```bash
# Database credentials (gunakan password kuat!)
export RADIUS_DB_NAME="radius"
export RADIUS_DB_USER="radius"
export RADIUS_DB_PASSWORD="$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)"
export MARIADB_ROOT_PASSWORD="$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)"

# Mikrotik IPs (comma-separated)
export MIKROTIK_IPS="192.168.1.1,192.168.1.2,10.0.0.5"

# Save untuk referensi
echo "RADIUS_DB_PASSWORD=${RADIUS_DB_PASSWORD}" > /root/.radius_secrets
echo "MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}" >> /root/.radius_secrets
chmod 600 /root/.radius_secrets
```

## 🔧 Step 2: Installation

### 2.1 Clone atau Copy Project

```bash
cd /opt
git clone https://github.com/yourrepo/FreeRADIUSPaket.git
cd FreeRADIUSPaket
```

Atau jika sudah ada:

```bash
cd /path/to/FreeRADIUSPaket
```

### 2.2 Run Installation Script

```bash
chmod +x scripts/install_freeradius.sh
sudo -E bash scripts/install_freeradius.sh
```

Script akan:
- Install FreeRADIUS dan dependencies
- Setup MariaDB dengan password secure
- Create database dan user
- Import schema
- Configure FreeRADIUS
- Test configuration

**Catatan:** Credentials akan disimpan di `/root/.freeradius_credentials`

## 🔥 Step 3: Firewall Setup

### 3.1 Setup Firewall Rules

```bash
# Set IP Mikrotik
export MIKROTIK_IPS="192.168.1.1,192.168.1.2,10.0.0.5"

# Run firewall script
chmod +x scripts/setup_firewall.sh
sudo -E bash scripts/setup_firewall.sh
```

Script akan:
- Detect firewall type (ufw/firewalld/iptables)
- Allow UDP 1812 (auth) dan 1813 (acct) hanya dari IP Mikrotik
- Allow localhost untuk testing

## 📝 Step 4: Configure NAS Clients

### 4.1 Edit clients.conf

```bash
sudo cp configs/clients.conf.example /etc/freeradius/3.0/clients.conf
sudo nano /etc/freeradius/3.0/clients.conf
```

Edit untuk setiap Mikrotik:

```
client mikrotik-1 {
    ipaddr = 192.168.1.1
    secret = YOUR_SECURE_SECRET_HERE  # Ganti dengan secret yang kuat!
    nas_type = other
}

client mikrotik-2 {
    ipaddr = 192.168.1.2
    secret = ANOTHER_SECURE_SECRET    # Secret berbeda untuk setiap NAS
    nas_type = other
}
```

**⚠️ PENTING:**
- Gunakan secret yang kuat (minimal 16 karakter, random)
- Setiap NAS harus punya secret unik
- Simpan secrets di tempat yang aman

### 4.2 Restart FreeRADIUS

```bash
sudo systemctl restart freeradius
sudo systemctl status freeradius
```

## 📦 Step 5: Setup Package Groups

### 5.1 Import Package Groups

```bash
# Login ke MySQL
mysql -u root -p

# Di MySQL prompt:
use radius;

# Import groups
source /path/to/FreeRADIUSPaket/sql/groups.sql;

# Verify
SELECT * FROM radgroupreply;
```

Atau langsung dari command line:

```bash
mysql -u root -p radius < sql/groups.sql
```

### 5.2 Customize Package Rates

Edit `sql/groups.sql` sesuai kebutuhan bandwidth Anda:

```sql
-- Paket 10Mbps
INSERT INTO radgroupreply (groupname, attribute, op, value) 
VALUES ('paket_10mbps','Mikrotik-Rate-Limit',':=','10M/10M') 
ON DUPLICATE KEY UPDATE value='10M/10M';
```

## 🗄️ Step 6: Setup Billing Integration

### 6.1 Create Database User for Billing

Lihat dokumentasi lengkap di `docs/BILLING_INTEGRATION.md`

```bash
mysql -u root -p
```

```sql
CREATE USER 'billing'@'localhost' IDENTIFIED BY 'secure_billing_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radcheck TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radusergroup TO 'billing'@'localhost';
GRANT SELECT ON radius.radacct TO 'billing'@'localhost';
FLUSH PRIVILEGES;
```

### 6.2 Configure Billing Server

Update konfigurasi billing (CVLMEDIA atau lainnya):

```json
{
  "user_auth_mode": "radius",
  "radius_host": "192.168.1.10",
  "radius_user": "billing",
  "radius_password": "secure_billing_password",
  "radius_database": "radius"
}
```

## ✅ Step 7: Testing

### 7.1 Test Configuration

```bash
# Test FreeRADIUS config
sudo freeradius -C

# Test dengan debug mode (temporary)
sudo freeradius -X
# Di terminal lain, test:
radtest testuser testpass 127.0.0.1 0 testing123
```

### 7.2 Create Test User

```bash
mysql -u root -p radius
```

```sql
-- Insert test user
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass123');

-- Assign to package
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('testuser', 'paket_10mbps', 1);
```

### 7.3 Test Authentication

```bash
# Test dari localhost
radtest testuser testpass123 127.0.0.1 0 testing123

# Harus return: Access-Accept
```

### 7.4 Test dari Mikrotik

Di Mikrotik:
```
/radius test testuser testpass123
```

## 🔒 Step 8: Security Hardening

### 8.1 Secure MariaDB

```bash
sudo mysql_secure_installation
```

Atau manual:

```bash
mysql -u root -p
```

```sql
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Disable remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

FLUSH PRIVILEGES;
```

### 8.2 Setup Fail2ban (Optional but Recommended)

```bash
sudo apt-get install -y fail2ban

# Create FreeRADIUS jail
sudo nano /etc/fail2ban/jail.d/freeradius.conf
```

```ini
[freeradius]
enabled = true
port = 1812,1813
filter = freeradius
logpath = /var/log/freeradius/radius.log
maxretry = 5
bantime = 3600
```

### 8.3 Enable TLS for MySQL (Optional)

Lihat dokumentasi MySQL untuk setup SSL certificates.

### 8.4 Setup Log Rotation

```bash
sudo nano /etc/logrotate.d/freeradius
```

```
/var/log/freeradius/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 freerad freerad
    sharedscripts
    postrotate
        systemctl reload freeradius > /dev/null 2>&1 || true
    endscript
}
```

## 🔄 Step 9: Backup Setup

### 9.1 Manual Backup

```bash
chmod +x scripts/backup_radius.sh
sudo -E bash scripts/backup_radius.sh
```

### 9.2 Automated Daily Backup

```bash
# Add to crontab
sudo crontab -e
```

Add line:
```
0 2 * * * /path/to/FreeRADIUSPaket/scripts/backup_radius.sh >> /var/log/radius_backup.log 2>&1
```

Ini akan backup setiap hari jam 2 AM.

## 📊 Step 10: Monitoring Setup

### 10.1 Check Service Status

```bash
systemctl status freeradius
systemctl status mariadb
```

### 10.2 Check Logs

```bash
# FreeRADIUS logs
tail -f /var/log/freeradius/radius.log

# MariaDB logs
tail -f /var/log/mysql/error.log

# System logs
journalctl -u freeradius -f
```

### 10.3 Health Check Script

```bash
# Create simple health check
cat > /usr/local/bin/radius_health_check.sh <<'EOF'
#!/bin/bash
if systemctl is-active --quiet freeradius; then
    if mysql -u radius -p'${RADIUS_DB_PASSWORD}' -e "SELECT 1" &>/dev/null; then
        echo "OK"
        exit 0
    fi
fi
echo "FAIL"
exit 1
EOF

chmod +x /usr/local/bin/radius_health_check.sh
```

## 📋 Production Checklist

### Pre-Deployment
- [ ] System updated
- [ ] Strong passwords generated dan disimpan
- [ ] IP Mikrotik sudah didokumentasikan
- [ ] Network connectivity tested

### Installation
- [ ] FreeRADIUS installed successfully
- [ ] Database created dengan schema
- [ ] Configuration tested (`freeradius -C`)
- [ ] Service running (`systemctl status freeradius`)

### Security
- [ ] Firewall rules configured
- [ ] Default passwords changed
- [ ] NAS secrets configured (strong & unique)
- [ ] MariaDB secured
- [ ] Fail2ban installed (optional)

### Configuration
- [ ] Package groups imported
- [ ] NAS clients configured
- [ ] Billing integration setup (if needed)
- [ ] Test user created dan tested

### Operations
- [ ] Backup script tested
- [ ] Cron job untuk backup setup
- [ ] Log rotation configured
- [ ] Monitoring setup
- [ ] Documentation updated

### Testing
- [ ] Local authentication test passed
- [ ] Mikrotik authentication test passed
- [ ] Accounting packets received
- [ ] Billing CRUD operations tested (if applicable)

## 🚨 Troubleshooting

### Service tidak start

```bash
# Check config
sudo freeradius -XC

# Check logs
sudo journalctl -u freeradius -n 50

# Check permissions
ls -la /etc/freeradius/3.0/
```

### Authentication gagal

1. Check user exists:
   ```sql
   SELECT * FROM radcheck WHERE username = 'username';
   SELECT * FROM radusergroup WHERE username = 'username';
   ```

2. Check NAS secret di clients.conf match dengan Mikrotik

3. Check firewall tidak block packets

4. Check time sync (NTP)

### Database connection error

```bash
# Test connection
mysql -u radius -p radius

# Check service
systemctl status mariadb

# Check privileges
mysql -u root -p -e "SHOW GRANTS FOR 'radius'@'localhost';"
```

## 📚 Additional Resources

- FreeRADIUS Documentation: https://freeradius.org/documentation/
- FreeRADIUS SQL Module: https://freeradius.org/radiusd/man/sql.html
- Mikrotik RADIUS: https://wiki.mikrotik.com/wiki/Manual:RADIUS
- Billing Integration: `docs/BILLING_INTEGRATION.md`

## 📞 Support

Jika ada masalah:
1. Check logs: `/var/log/freeradius/`
2. Check documentation: `docs/` folder
3. Review troubleshooting section di atas

---

**Last Updated:** 2024  
**Version:** 1.0  
**Maintainer:** FreeRADIUS Paket Team

