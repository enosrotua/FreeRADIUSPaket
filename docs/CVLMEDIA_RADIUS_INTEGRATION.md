# Integrasi CVLMEDIA dengan FreeRADIUS - Step by Step

Panduan lengkap untuk mengintegrasikan CVLMEDIA billing dengan FreeRADIUS server.

## 📋 Prasyarat

1. ✅ FreeRADIUS sudah terinstall dan running
2. ✅ Database `radius` sudah dibuat dengan schema FreeRADIUS
3. ✅ CVLMEDIA sudah terinstall di server

## 🔧 Step 1: Setup Database User untuk Billing

### Di Server FreeRADIUS:

```bash
cd /home/enos/FreeRADIUSPaket
sudo bash scripts/setup_billing_user.sh
```

Script akan generate password dan menampilkan credentials:
```
Billing Database Configuration:
  Host: localhost
  User: billing
  Password: abc123xyz...
  Database: radius
```

**⚠️ SIMPAN PASSWORD INI!**

### Atau Manual:

```bash
mysql -u root -p
```

```sql
CREATE USER 'billing'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radcheck TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radusergroup TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radreply TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupreply TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupcheck TO 'billing'@'localhost';
GRANT SELECT ON radius.radacct TO 'billing'@'localhost';
GRANT SELECT ON radius.radpostauth TO 'billing'@'localhost';
FLUSH PRIVILEGES;
```

## 🔗 Step 2: Konfigurasi CVLMEDIA

### Via Web Interface (Recommended):

1. Login ke CVLMEDIA admin panel
2. Buka menu: **Setting > RADIUS/Api Setup** atau langsung ke: `/admin/radius`
3. Isi form:
   - **Mode Autentikasi**: Pilih "RADIUS"
   - **RADIUS Host**: `localhost` (atau IP FreeRADIUS jika berbeda server)
   - **RADIUS User**: `billing`
   - **RADIUS Password**: (password dari Step 1)
   - **RADIUS Database**: `radius`
4. Klik **Simpan**

### Via settings.json (Manual):

Edit `/home/enos/cvlmedia/settings.json`:

```json
{
  "user_auth_mode": "radius",
  "radius_host": "localhost",
  "radius_user": "billing",
  "radius_password": "password_dari_step_1",
  "radius_database": "radius"
}
```

**Restart CVLMEDIA setelah edit settings.json:**
```bash
# Jika pakai PM2
pm2 restart cvlmedia

# Atau jika manual
pkill -f "node app.js"
cd /home/enos/cvlmedia
node app.js
```

## ✅ Step 3: Test Koneksi

### Test dari CVLMEDIA Server:

```bash
mysql -h localhost -u billing -p radius
# Masukkan password billing
# Jika berhasil masuk, berarti koneksi OK
```

### Test Create User:

1. Login ke CVLMEDIA admin panel
2. Buka menu **Customer/Billing**
3. Tambah customer baru
4. Set username dan password
5. Set package/bandwidth
6. Save

**Verify di database RADIUS:**
```sql
SELECT * FROM radcheck WHERE username = 'testuser';
SELECT * FROM radusergroup WHERE username = 'testuser';
```

### Test Authentication:

```bash
radtest testuser testpassword 127.0.0.1 0 testing123
# Harus return: Access-Accept ✅
```

## 📝 Operasi CRUD yang Tersedia

### Current Status (Setelah Setup):

✅ **Create User** - CVLMEDIA bisa create user ke RADIUS  
⚠️ **Read Users** - CVLMEDIA bisa read users dari RADIUS  
❌ **Update Password** - Belum support (perlu ditambah)  
❌ **Update Package** - Belum support (perlu ditambah)  
❌ **Suspend/Unsuspend** - Belum support (perlu ditambah)  
❌ **Delete User** - Belum support (perlu ditambah)  

### Functions yang Sudah Ada (di `/home/enos/cvlmedia/config/mikrotik.js`):

```javascript
// ✅ Sudah ada
getRadiusConnection()      // Koneksi ke database RADIUS
getPPPoEUsersRadius()      // Get list users dari RADIUS
addPPPoEUserRadius()       // Tambah user (hanya password, belum assign group)
```

### Functions yang Perlu Ditambahkan:

```javascript
// ❌ Perlu ditambah
updatePPPoEUserRadius()    // Update password user
assignPackageRadius()      // Assign user ke package/group
suspendUserRadius()        // Suspend user (pindah ke group 'isolir')
unsuspendUserRadius()      // Unsuspend user (kembalikan ke package)
deletePPPoEUserRadius()    // Delete user dari RADIUS
```

## 🔧 Step 4: Lengkapi Fungsi CRUD (Jika Diperlukan)

Jika CVLMEDIA perlu operasi CRUD lengkap, fungsi-fungsi berikut perlu ditambahkan ke `config/mikrotik.js`.

**Contoh implementasi tersedia di:**
- `/home/enos/FreeRADIUSPaket/docs/BILLING_INTEGRATION.md`
- `/home/enos/FreeRADIUSPaket/sql/users.sql`
- `/home/enos/FreeRADIUSPaket/sql/suspend_unsuspend.sql`

## 🐛 Troubleshooting

### CVLMEDIA tidak bisa connect ke RADIUS database

**Check:**
1. User database `billing` sudah dibuat?
   ```sql
   SELECT User, Host FROM mysql.user WHERE User = 'billing';
   ```
2. Password benar di settings.json?
3. Database `radius` ada?
   ```sql
   SHOW DATABASES LIKE 'radius';
   ```
4. Firewall tidak block port 3306 (jika server berbeda)

### User tidak muncul setelah dibuat di CVLMEDIA

**Check:**
1. Settings `user_auth_mode` = `"radius"`?
2. Credentials di settings.json benar?
3. User ada di database RADIUS?
   ```sql
   SELECT * FROM radcheck WHERE username = 'username';
   ```
4. CVLMEDIA sudah restart setelah update settings?

### User tidak bisa login (authentication gagal)

**Check:**
1. User ada di `radcheck`?
   ```sql
   SELECT * FROM radcheck WHERE username = 'username';
   ```
2. User punya group di `radusergroup`?
   ```sql
   SELECT * FROM radusergroup WHERE username = 'username';
   ```
3. Group punya reply attributes di `radgroupreply`?
   ```sql
   SELECT * FROM radgroupreply WHERE groupname = 'paket_10mbps';
   ```

## 📚 Referensi

- [BILLING_INTEGRATION.md](BILLING_INTEGRATION.md) - Detail CRUD operations
- [CARA_KONEK_BILLING_KE_RADIUS.md](CARA_KONEK_BILLING_KE_RADIUS.md) - Step-by-step koneksi
- [DEPLOYMENT_PRODUCTION.md](DEPLOYMENT_PRODUCTION.md) - Setup FreeRADIUS production

---

**Last Updated:** 2024  
**Maintainer:** FreeRADIUS Paket Team

