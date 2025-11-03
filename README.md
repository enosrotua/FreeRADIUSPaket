[![CI](https://github.com/enosrotua/FreeRADIUSPaket/actions/workflows/radius-ci.yml/badge.svg)](https://github.com/enosrotua/FreeRADIUSPaket/actions/workflows/radius-ci.yml)

# FreeRADIUS Paket

Paket instalasi FreeRADIUS + MariaDB untuk integrasi Mikrotik dan billing server (CVLMEDIA atau lainnya). **Production-ready** dengan security hardening, backup automation, dan dokumentasi lengkap.

## ✨ Fitur

- ✅ Instalasi otomatis dengan script lengkap
- ✅ Security hardening (firewall, secure passwords)
- ✅ Backup & restore otomatis
- ✅ Integrasi dengan billing server (database direct connection)
- ✅ Template SQL untuk package management
- ✅ Production deployment guide lengkap
- ✅ Monitoring & health checks

## 📦 Isi Paket

- **scripts/**: Script instalasi dan management
  - `install_freeradius.sh`: Instalasi otomatis lengkap
  - `setup_firewall.sh`: Setup firewall rules untuk security
  - `setup_billing_user.sh`: Setup database user untuk billing
  - `backup_radius.sh`: Backup otomatis database & config
  - `restore_backup.sh`: Restore dari backup
- **configs/**: File konfigurasi FreeRADIUS
  - `sql`: Konfigurasi modul SQL
  - `sites-default`: Site default dengan SQL aktif
  - `clients.conf.example`: Template NAS Mikrotik
- **sql/**: Template SQL queries
  - `groups.sql`: Definisi grup paket & isolir
  - `users.sql`: Template tambah user
  - `suspend_unsuspend.sql`: Template suspend/unsuspend
- **docs/**: Dokumentasi lengkap
  - `DEPLOYMENT_PRODUCTION.md`: Panduan deploy production
  - `BILLING_INTEGRATION.md`: Panduan integrasi billing server
  - `BILLING_SERVER_SETUP.md`: Panduan instalasi billing server

## 🚀 Quick Start

### Instalasi Cepat (Development/Testing)

```bash
# Clone repository (pertama kali)
git clone https://github.com/enosrotua/FreeRADIUSPaket.git
cd FreeRADIUSPaket

# Auto-setup (detect dan install jika belum ada)
sudo bash setup.sh
```

**Workflow Update:**
```bash
# Setelah git pull (untuk update)
git pull origin main
sudo bash setup.sh  # Auto-detect dan install jika perlu
```

Script `setup.sh` akan otomatis:
- ✅ Detect apakah FreeRADIUS sudah terinstall
- ✅ Check apakah config directory ada
- ✅ Install jika belum ada atau perlu update
- ✅ Skip jika sudah lengkap

**Manual Install (jika perlu):**
```bash
# Run instalasi manual (akan generate password otomatis)
sudo bash scripts/install_freeradius.sh
```

**⚠️ Catatan:** Untuk production, ikuti panduan lengkap di `docs/DEPLOYMENT_PRODUCTION.md`

### Instalasi Production

Lihat dokumentasi lengkap: **[docs/DEPLOYMENT_PRODUCTION.md](docs/DEPLOYMENT_PRODUCTION.md)**

## 📚 Dokumentasi

### Instalasi & Deployment
- **[Production Deployment Guide](docs/DEPLOYMENT_PRODUCTION.md)** - Panduan lengkap untuk deploy ke production
- **[⭐ CARA KONEK BILLING KE RADIUS](docs/CARA_KONEK_BILLING_KE_RADIUS.md)** - **BACA INI DULU!** Step-by-step cara koneksi billing ke FreeRADIUS
- **[Billing Integration Guide](docs/BILLING_INTEGRATION.md)** - Detail operasi CRUD untuk billing
- **[Billing Server Setup](docs/BILLING_SERVER_SETUP.md)** - Cara install billing server

### Quick Reference

**Setup Firewall:**
```bash
export MIKROTIK_IPS="192.168.1.1,192.168.1.2"
sudo -E bash scripts/setup_firewall.sh
```

**Setup Billing User:**
```bash
sudo bash scripts/setup_billing_user.sh
# Atau dengan custom values:
export BILLING_DB_USER=billing
export BILLING_DB_PASSWORD=secure_password
export BILLING_DB_HOST=localhost  # atau IP billing server
sudo -E bash scripts/setup_billing_user.sh
```

**Backup:**
```bash
# Manual backup
sudo bash scripts/backup_radius.sh

# Setup automated daily backup (crontab)
0 2 * * * /path/to/FreeRADIUSPaket/scripts/backup_radius.sh
```

**Restore:**
```bash
sudo bash scripts/restore_backup.sh freeradius_20241201_120000
```

## 🔗 Integrasi

### Mikrotik Configuration

1. **Setup NAS Clients:**
   ```bash
   sudo cp configs/clients.conf.example /etc/freeradius/3.0/clients.conf
   sudo nano /etc/freeradius/3.0/clients.conf
   # Edit IP dan secret untuk setiap Mikrotik
   ```

2. **Di Mikrotik Router:**
   ```
   /radius
   add address=<IP_RADIUS> secret=<SECRET> service=ppp,hotspot \
       accounting-port=1813 authentication-port=1812
   
   /ppp aaa
   set use-radius=yes
   
   /ip hotspot
   set use-radius=yes
   ```

### Billing Server Integration

**⚠️ Catatan:** Billing server adalah aplikasi terpisah yang perlu diinstall sendiri. FreeRADIUS Paket hanya menyediakan:
- Setup database user untuk billing
- Dokumentasi integrasi

**Dokumentasi:**
- **[BILLING_SERVER_SETUP.md](docs/BILLING_SERVER_SETUP.md)** - Cara install billing server (CVLMEDIA, dll)
- **[BILLING_INTEGRATION.md](docs/BILLING_INTEGRATION.md)** - Cara integrasi billing dengan FreeRADIUS

**Quick Setup (setelah billing server terinstall):**
```bash
# 1. Setup billing database user di FreeRADIUS
sudo bash scripts/setup_billing_user.sh

# 2. Update billing server config (contoh CVLMEDIA settings.json)
{
  "user_auth_mode": "radius",
  "radius_host": "localhost",
  "radius_user": "billing",
  "radius_password": "password_dari_script",
  "radius_database": "radius"
}
```

## 🔒 Security Best Practices

- ✅ **Password Generation**: Script instalasi generate password secure otomatis
- ✅ **Firewall**: Script setup firewall dengan whitelist IP Mikrotik
- ✅ **Database Security**: MariaDB secured, user privileges minimal
- ✅ **Backup Automation**: Backup otomatis dengan retention policy
- ⚠️ **Credential Storage**: Credentials disimpan di `/root/.freeradius_credentials` (chmod 600)

**⚠️ PENTING:**
- Simpan file credentials dengan aman (jangan commit ke git!)
- Gunakan secret yang kuat dan unik untuk setiap NAS Mikrotik
- Batasi akses port 1812/1813 hanya dari IP Mikrotik
- Review firewall rules setelah setup

## 📝 Template SQL Operations

Template SQL tersedia untuk operasi CRUD user:

- **sql/groups.sql** - Definisi grup paket & isolir (Mikrotik-Rate-Limit)
- **sql/users.sql** - Template tambah user & assign group
- **sql/suspend_unsuspend.sql** - Template suspend/unsuspend via penggantian group

**Contoh penggunaan:**
```sql
-- Import package groups
mysql -u root -p radius < sql/groups.sql

-- Tambah user (gunakan template dari sql/users.sql)
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('username', 'Cleartext-Password', ':=', 'password123')
ON DUPLICATE KEY UPDATE value = 'password123';

REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('username', 'paket_10mbps', 1);
```

Lihat **[BILLING_INTEGRATION.md](docs/BILLING_INTEGRATION.md)** untuk detail lengkap operasi CRUD.

## 📊 Monitoring & Maintenance

### Check Service Status
```bash
systemctl status freeradius
systemctl status mariadb
```

### View Logs
```bash
# FreeRADIUS logs
tail -f /var/log/freeradius/radius.log

# MariaDB logs
tail -f /var/log/mysql/error.log

# System logs
journalctl -u freeradius -f
```

### Test Authentication
```bash
radtest username password 127.0.0.1 0 testing123
```

## 🐛 Troubleshooting

### Service tidak start
```bash
# Check configuration
sudo freeradius -XC

# Check logs
sudo journalctl -u freeradius -n 50
```

### Authentication gagal
1. Check user exists di database
2. Verify NAS secret di clients.conf match dengan Mikrotik
3. Check firewall tidak block packets
4. Verify time sync (NTP)

Lihat troubleshooting section di **[DEPLOYMENT_PRODUCTION.md](docs/DEPLOYMENT_PRODUCTION.md)** untuk detail lengkap.

## 📄 License & Credits

FreeRADIUS Paket - Production-ready FreeRADIUS installation package

- FreeRADIUS: https://freeradius.org/
- MariaDB: https://mariadb.org/

## 🤝 Contributing

Pull requests welcome! Untuk production changes, pastikan:
- Security best practices diikuti
- Scripts di-test di environment development
- Dokumentasi di-update sesuai perubahan
