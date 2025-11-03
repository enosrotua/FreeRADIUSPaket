# Setup Billing Server untuk FreeRADIUS

Dokumen ini menjelaskan cara menginstall dan mengkonfigurasi billing server untuk terintegrasi dengan FreeRADIUS.

## 📋 Overview

Billing server adalah aplikasi terpisah yang mengelola:
- Customer management
- Package/subscription management
- Payment processing
- User provisioning ke RADIUS
- Reporting & analytics

**Posisi dalam arsitektur:**
```
Billing Server → Database (MariaDB) ← FreeRADIUS
                      ↓
                  User Data
                  (radcheck, radusergroup, etc.)
```

## 🎯 Pilihan Billing Server

### 1. CVLMEDIA
- **Website**: https://cvlmedia.com
- **Type**: Commercial/Open Source ISP Billing
- **Database**: MySQL/MariaDB
- **Integration**: Direct database connection ke FreeRADIUS

### 2. GnuBill / GPL Billing
- Open source billing system
- Support RADIUS integration

### 3. Custom Billing
- Build sendiri dengan framework (Laravel, Django, dll)
- Full control tapi perlu development

## 📦 Instalasi CVLMEDIA (Contoh)

### Prasyarat
- PHP 7.4+ atau 8.x
- MySQL/MariaDB 10.3+
- Web server (Apache/Nginx)
- Composer (PHP package manager)

### Step 1: Download & Install

```bash
# Clone atau download CVLMEDIA
cd /var/www
git clone https://github.com/cvlmedia/cvlmedia.git
# Atau download dari website resmi

cd cvlmedia

# Install dependencies
composer install

# Setup permissions
chown -R www-data:www-data /var/www/cvlmedia
chmod -R 755 /var/www/cvlmedia/storage
```

### Step 2: Setup Database

```bash
# Login ke MySQL
mysql -u root -p

# Buat database untuk billing
CREATE DATABASE cvlmedia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'cvlmedia'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON cvlmedia.* TO 'cvlmedia'@'localhost';
FLUSH PRIVILEGES;
```

### Step 3: Konfigurasi

```bash
# Copy config file
cp .env.example .env

# Edit .env file
nano .env
```

Update configuration:
```env
APP_NAME=CVLMEDIA
APP_ENV=production
APP_DEBUG=false

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=cvlmedia
DB_USERNAME=cvlmedia
DB_PASSWORD=secure_password

# RADIUS Configuration
RADIUS_HOST=localhost
RADIUS_DB_NAME=radius
RADIUS_DB_USER=billing
RADIUS_DB_PASSWORD=password_dari_setup_billing_user
```

### Step 4: Setup RADIUS Integration

Jika CVLMEDIA sudah terinstall, edit `settings.json` atau config file:

```json
{
  "user_auth_mode": "radius",
  "radius_host": "localhost",
  "radius_port": 3306,
  "radius_user": "billing",
  "radius_password": "password_dari_setup_billing_user",
  "radius_database": "radius"
}
```

**Catatan:** Pastikan billing user sudah dibuat dengan:
```bash
sudo bash scripts/setup_billing_user.sh
```

## 🔗 Integrasi dengan FreeRADIUS

Setelah billing server terinstall, ikuti panduan di:
- **[BILLING_INTEGRATION.md](BILLING_INTEGRATION.md)** - Detail integrasi CRUD operations

### Flow Integrasi:

1. **User Registration di Billing:**
   - User register via billing web interface
   - Billing create user di database sendiri

2. **Provision ke RADIUS:**
   - Billing insert ke `radius.radcheck` (password)
   - Billing insert ke `radius.radusergroup` (assign package)
   - FreeRADIUS otomatis bisa authenticate user

3. **Package Changes:**
   - Admin update package di billing
   - Billing update `radius.radusergroup` dengan package baru
   - User langsung dapat bandwidth baru

4. **Suspend/Unsuspend:**
   - Admin suspend user di billing
   - Billing update `radius.radusergroup` ke 'isolir'
   - User tidak bisa login
   - Unsuspend: kembalikan ke package sebelumnya

## 🧪 Testing Integration

### Test dari Billing Server

```bash
# Test database connection ke RADIUS
mysql -h localhost -u billing -p radius

# Test insert user
mysql -u billing -p radius <<EOF
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass123')
ON DUPLICATE KEY UPDATE value = 'testpass123';

REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('testuser', 'paket_10mbps', 1);
EOF
```

### Test Authentication

```bash
# Dari FreeRADIUS server
radtest testuser testpass123 127.0.0.1 0 testing123
# Harus return: Access-Accept
```

## 📊 Monitoring

### Check Billing → RADIUS Connection

```bash
# Check user di billing database
mysql -u cvlmedia -p cvlmedia -e "SELECT * FROM users LIMIT 5;"

# Check user di RADIUS database
mysql -u billing -p radius -e "SELECT * FROM radcheck LIMIT 5;"
mysql -u billing -p radius -e "SELECT * FROM radusergroup LIMIT 5;"
```

### Logs

- Billing logs: `/var/www/cvlmedia/storage/logs/`
- FreeRADIUS logs: `/var/log/freeradius/radius.log`
- MySQL logs: `/var/log/mysql/error.log`

## 🔧 Troubleshooting

### Billing tidak bisa connect ke RADIUS database

1. **Check user exists:**
   ```sql
   SELECT User, Host FROM mysql.user WHERE User = 'billing';
   ```

2. **Check privileges:**
   ```sql
   SHOW GRANTS FOR 'billing'@'localhost';
   ```

3. **Test connection:**
   ```bash
   mysql -h localhost -u billing -p radius
   ```

### User tidak sync ke RADIUS

1. Check billing configuration untuk RADIUS settings
2. Check billing logs untuk error messages
3. Verify billing punya permissions untuk write ke RADIUS database
4. Test manual insert ke database RADIUS

### Authentication gagal setelah user dibuat

1. Verify user ada di `radcheck`:
   ```sql
   SELECT * FROM radcheck WHERE username = 'username';
   ```

2. Verify user punya group:
   ```sql
   SELECT * FROM radusergroup WHERE username = 'username';
   ```

3. Verify group punya reply attributes:
   ```sql
   SELECT * FROM radgroupreply WHERE groupname = 'paket_10mbps';
   ```

## 📚 Referensi

- CVLMEDIA Documentation: https://cvlmedia.com/docs
- FreeRADIUS SQL Module: https://freeradius.org/radiusd/man/sql.html
- Billing Integration Guide: [BILLING_INTEGRATION.md](BILLING_INTEGRATION.md)

---

**Catatan:** Instalasi billing server berbeda-beda tergantung aplikasi yang digunakan. Panduan di atas adalah contoh umum. Untuk detail spesifik, lihat dokumentasi resmi billing server yang Anda gunakan.

