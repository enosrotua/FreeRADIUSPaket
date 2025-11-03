# Cara Koneksi Billing Server ke FreeRADIUS - Step by Step

Panduan lengkap dan mudah dipahami untuk menghubungkan billing server Anda ke FreeRADIUS.

## 🎯 Konsep Dasar

Billing server dan FreeRADIUS menggunakan **database yang sama** untuk menyimpan data user:

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────┐
│  Billing Server │─────┐   │   Database   │    ┌────│ FreeRADIUS  │
│  (CVLMEDIA/     │     │   │  (MariaDB)   │    │    │   Server    │
│   Aplikasi Lain)│     │   │              │    │    │             │
└─────────────────┘     │   │  radius DB   │    │    └─────────────┘
                        │   │              │    │
                        └───│─ radcheck    │────┘
                            │─ radusergroup│
                            │─ radgroupreply│
                            └──────────────┘
```

**Intinya:** 
- Billing server **menulis** user data ke database
- FreeRADIUS **membaca** user data dari database
- Mereka **share database yang sama**

## 📋 Langkah-Langkah Koneksi

### Step 1: Pastikan FreeRADIUS Sudah Terinstall

```bash
# Check FreeRADIUS running
sudo systemctl status freeradius

# Check database ada
mysql -u root -p -e "SHOW DATABASES LIKE 'radius';"
```

Jika belum terinstall, jalankan:
```bash
sudo bash scripts/install_freeradius.sh
```

### Step 2: Buat Database User untuk Billing

Billing server butuh user database sendiri dengan akses ke database `radius`.

**Cara 1: Menggunakan Script (Recommended)**
```bash
# Jalankan script yang sudah disediakan
sudo bash scripts/setup_billing_user.sh
```

Script ini akan:
- Membuat user database `billing`
- Memberikan permissions yang diperlukan
- Menampilkan credentials yang harus Anda simpan

**Output contoh:**
```
[+] Billing user created successfully
Billing Database Configuration:
  Host: localhost
  User: billing
  Password: abc123xyz789...
  Database: radius
```

**Cara 2: Manual (jika perlu custom)**
```bash
mysql -u root -p
```

```sql
-- Buat user untuk billing
CREATE USER 'billing'@'localhost' IDENTIFIED BY 'password_yang_kuat';

-- Berikan permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radcheck TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radusergroup TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupreply TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupcheck TO 'billing'@'localhost';
GRANT SELECT ON radius.radacct TO 'billing'@'localhost';

FLUSH PRIVILEGES;
```

### Step 3: Test Koneksi Database

Pastikan billing bisa connect ke database sebelum konfigurasi aplikasi:

```bash
# Test dari command line
mysql -h localhost -u billing -p radius
# Masukkan password billing
# Jika berhasil masuk ke MySQL prompt, berarti koneksi OK
```

Atau test dari PHP (jika billing pakai PHP):
```php
<?php
$host = 'localhost';
$dbname = 'radius';
$username = 'billing';
$password = 'password_billing';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    echo "Koneksi berhasil!";
} catch (PDOException $e) {
    echo "Koneksi gagal: " . $e->getMessage();
}
?>
```

### Step 4: Konfigurasi Billing Server

Sekarang edit konfigurasi billing server Anda. Setiap billing berbeda, tapi umumnya ada file config seperti `settings.json`, `.env`, atau `config.php`.

#### Contoh 1: CVLMEDIA (settings.json)
```json
{
  "user_auth_mode": "radius",
  "radius_host": "localhost",
  "radius_port": 3306,
  "radius_user": "billing",
  "radius_password": "password_yang_anda_pakai",
  "radius_database": "radius"
}
```

#### Contoh 2: Laravel-based Billing (.env)
```env
RADIUS_DB_HOST=localhost
RADIUS_DB_PORT=3306
RADIUS_DB_DATABASE=radius
RADIUS_DB_USERNAME=billing
RADIUS_DB_PASSWORD=password_yang_anda_pakai
```

#### Contoh 3: PHP Config (config.php)
```php
<?php
$radius_config = [
    'host' => 'localhost',
    'port' => 3306,
    'database' => 'radius',
    'username' => 'billing',
    'password' => 'password_yang_anda_pakai'
];
?>
```

### Step 5: Test CRUD Operations

Setelah konfigurasi, test apakah billing bisa write ke database:

#### Test 1: Insert User (Create)
```sql
-- Masuk sebagai billing user
mysql -u billing -p radius

-- Insert test user
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser123', 'Cleartext-Password', ':=', 'testpass123')
ON DUPLICATE KEY UPDATE value = 'testpass123';

-- Assign ke package
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('testuser123', 'paket_10mbps', 1);
```

#### Test 2: Verify dari FreeRADIUS
```bash
# Test authentication
radtest testuser123 testpass123 127.0.0.1 0 testing123

# Harus return: Access-Accept
```

Jika dapat `Access-Accept`, berarti koneksi billing → FreeRADIUS **berhasil!** ✅

## 🔧 Skenario: Billing dan FreeRADIUS di Server Berbeda

Jika billing server ada di server lain (bukan localhost):

### Di Server FreeRADIUS:

1. **Edit MySQL config untuk allow remote connection:**
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Ubah:
```ini
bind-address = 0.0.0.0  # Sebelumnya: 127.0.0.1
```

2. **Create user dengan IP billing server:**
```bash
mysql -u root -p
```

```sql
-- Ganti 192.168.1.100 dengan IP billing server Anda
CREATE USER 'billing'@'192.168.1.100' IDENTIFIED BY 'password_kuat';

GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radcheck TO 'billing'@'192.168.1.100';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radusergroup TO 'billing'@'192.168.1.100';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupreply TO 'billing'@'192.168.1.100';
GRANT SELECT ON radius.radacct TO 'billing'@'192.168.1.100';

FLUSH PRIVILEGES;
```

3. **Buka firewall untuk MySQL port:**
```bash
# Allow dari IP billing saja
sudo ufw allow from 192.168.1.100 to any port 3306
```

### Di Server Billing:

Konfigurasi billing dengan IP FreeRADIUS:

```json
{
  "radius_host": "192.168.1.10",  // IP FreeRADIUS server
  "radius_port": 3306,
  "radius_user": "billing",
  "radius_password": "password_kuat",
  "radius_database": "radius"
}
```

## 🔍 Troubleshooting

### Masalah: Billing tidak bisa connect ke database

**Check 1: User database ada?**
```sql
SELECT User, Host FROM mysql.user WHERE User = 'billing';
```

**Check 2: Privileges benar?**
```sql
SHOW GRANTS FOR 'billing'@'localhost';
```

**Check 3: Password benar?**
```bash
mysql -u billing -p radius
# Masukkan password, jika error berarti password salah
```

**Check 4: Database ada?**
```sql
SHOW DATABASES LIKE 'radius';
```

**Check 5: Firewall block?**
```bash
# Check port 3306 terbuka
sudo netstat -tlnp | grep 3306

# Test dari billing server
telnet IP_FREERADIUS 3306
```

### Masalah: Billing bisa connect tapi tidak bisa insert

**Check permissions:**
```sql
SHOW GRANTS FOR 'billing'@'localhost';
```

Harus ada:
- INSERT ON radius.radcheck
- INSERT ON radius.radusergroup

Jika tidak ada, tambahkan:
```sql
GRANT INSERT ON radius.radcheck TO 'billing'@'localhost';
GRANT INSERT ON radius.radusergroup TO 'billing'@'localhost';
FLUSH PRIVILEGES;
```

### Masalah: User tidak muncul di FreeRADIUS setelah insert

**Check 1: Data benar di database?**
```sql
SELECT * FROM radcheck WHERE username = 'testuser';
SELECT * FROM radusergroup WHERE username = 'testuser';
```

**Check 2: FreeRADIUS config menggunakan SQL?**
```bash
# Check SQL module enabled
ls -la /etc/freeradius/3.0/mods-enabled/sql

# Check config
sudo freeradius -C
```

**Check 3: FreeRADIUS service running?**
```bash
sudo systemctl status freeradius
sudo journalctl -u freeradius -n 50
```

## 📝 Checklist Koneksi

Gunakan checklist ini untuk memastikan semua langkah sudah dilakukan:

- [ ] FreeRADIUS terinstall dan running
- [ ] Database `radius` sudah ada
- [ ] User database `billing` sudah dibuat
- [ ] Permissions sudah diberikan (SELECT, INSERT, UPDATE, DELETE)
- [ ] Password billing sudah dicatat dan disimpan aman
- [ ] Test koneksi dari command line berhasil
- [ ] Konfigurasi billing sudah diupdate dengan credentials
- [ ] Test insert user ke database berhasil
- [ ] Test authentication dari FreeRADIUS berhasil (Access-Accept)
- [ ] Jika server berbeda, firewall sudah dibuka untuk port 3306

## 🎯 Contoh Lengkap: End-to-End

```bash
# === DI SERVER FREERADIUS ===

# 1. Install FreeRADIUS (jika belum)
sudo bash scripts/install_freeradius.sh

# 2. Buat user untuk billing
sudo bash scripts/setup_billing_user.sh

# Output: Password = "abc123xyz..."

# 3. Import package groups (optional)
mysql -u root -p radius < sql/groups.sql

# === DI BILLING SERVER ===

# 4. Edit config billing (contoh: settings.json)
{
  "radius_host": "localhost",
  "radius_user": "billing",
  "radius_password": "abc123xyz...",
  "radius_database": "radius"
}

# 5. Test insert user dari billing
# (Via web interface atau API billing)

# 6. Verify di database
mysql -u billing -p radius -e "SELECT * FROM radcheck LIMIT 5;"

# 7. Test authentication
radtest username password 127.0.0.1 0 testing123
# Harus: Access-Accept ✅
```

## 📚 Referensi

- [BILLING_INTEGRATION.md](BILLING_INTEGRATION.md) - Detail CRUD operations
- [BILLING_SERVER_SETUP.md](BILLING_SERVER_SETUP.md) - Install billing server
- [DEPLOYMENT_PRODUCTION.md](DEPLOYMENT_PRODUCTION.md) - Setup production

---

**Pertanyaan?** Jika masih bingung, coba test step-by-step di atas dan lihat di mana step yang error.

