# Integrasi Billing Server dengan FreeRADIUS

Dokumen ini menjelaskan cara mengintegrasikan billing server (CVLMEDIA atau billing lainnya) dengan FreeRADIUS server.

## 📋 Prasyarat

1. FreeRADIUS server sudah terinstall dan berjalan
2. Database MySQL/MariaDB sudah setup dengan schema FreeRADIUS
3. Billing server memiliki akses ke database RADIUS (network access atau localhost)

## 🔌 Metode Koneksi

Ada dua metode utama untuk koneksi billing ke RADIUS:

### Metode 1: Koneksi Database Langsung (Recommended)

Billing server terhubung langsung ke database MySQL/MariaDB yang sama dengan FreeRADIUS.

**Keuntungan:**
- Performa tinggi
- Tidak perlu network layer tambahan
- Operasi CRUD langsung

**Kekurangan:**
- Perlu akses database langsung
- Perlu setup user database terpisah untuk billing

### Metode 2: Koneksi via RADIUS Protocol

Billing server menggunakan RADIUS protocol untuk autentikasi user.

**Keuntungan:**
- Standar protocol
- Tidak perlu akses database langsung

**Kekurangan:**
- Hanya untuk autentikasi (tidak untuk CRUD user)
- Lebih lambat untuk operasi batch

---

## 🗄️ Metode 1: Database Direct Connection

### Setup Database User untuk Billing

```sql
-- Buat user khusus untuk billing server
CREATE USER 'billing'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Atau jika billing di server berbeda:
CREATE USER 'billing'@'10.0.0.5' IDENTIFIED BY 'your_secure_password_here';
-- Ganti 10.0.0.5 dengan IP billing server

-- Grant privileges yang diperlukan
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radcheck TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radusergroup TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radreply TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupreply TO 'billing'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radgroupcheck TO 'billing'@'localhost';
GRANT SELECT ON radius.radacct TO 'billing'@'localhost'; -- Untuk reporting
GRANT SELECT ON radius.radpostauth TO 'billing'@'localhost'; -- Untuk logging

FLUSH PRIVILEGES;
```

### Konfigurasi Billing Server (CVLMEDIA)

Edit `settings.json` atau file konfigurasi billing:

```json
{
  "user_auth_mode": "radius",
  "radius_host": "localhost",
  "radius_port": 3306,
  "radius_user": "billing",
  "radius_password": "your_secure_password_here",
  "radius_database": "radius"
}
```

**Atau jika billing di server berbeda:**

```json
{
  "user_auth_mode": "radius",
  "radius_host": "192.168.1.10",
  "radius_port": 3306,
  "radius_user": "billing",
  "radius_password": "your_secure_password_here",
  "radius_database": "radius"
}
```

---

## 🔐 Metode 2: RADIUS Protocol Connection

Konfigurasi untuk koneksi via RADIUS protocol (jika billing mendukung):

```json
{
  "user_auth_mode": "radius",
  "radius_protocol": "radius",
  "radius_host": "192.168.1.10",
  "radius_port": 1812,
  "radius_secret": "your_shared_secret",
  "radius_timeout": 5
}
```

**Catatan:** Metode ini hanya untuk autentikasi user, tidak untuk CRUD operasi.

---

## 📝 Operasi CRUD User di Database

### 1. Tambah User Baru

```sql
-- Insert password user
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('newuser', 'Cleartext-Password', ':=', 'userpassword123')
ON DUPLICATE KEY UPDATE value = 'userpassword123';

-- Assign user ke grup paket
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('newuser', 'paket_10mbps', 1);
```

**Template SQL:** `sql/users.sql`

### 2. Edit Password User

```sql
UPDATE radcheck 
SET value = 'newpassword123' 
WHERE username = 'newuser' 
  AND attribute = 'Cleartext-Password';
```

### 3. Ganti Paket User

```sql
-- Pindahkan user ke paket baru
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('newuser', 'paket_20mbps', 1);
```

### 4. Suspend User

```sql
-- Pindahkan ke grup isolir (bandwidth minimal)
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('newuser', 'isolir', 1);
```

**Template SQL:** `sql/suspend_unsuspend.sql`

### 5. Unsuspend User

```sql
-- Kembalikan ke paket sebelumnya
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('newuser', 'paket_10mbps', 1);
```

### 6. Hapus User

```sql
-- Hapus dari grup
DELETE FROM radusergroup WHERE username = 'newuser';

-- Hapus password
DELETE FROM radcheck WHERE username = 'newuser';

-- Optional: Hapus accounting data (hati-hati!)
-- DELETE FROM radacct WHERE username = 'newuser';
```

---

## 📊 Query untuk Reporting & Monitoring

### Total User Aktif (per paket)

```sql
SELECT 
    ug.groupname,
    COUNT(DISTINCT ug.username) as total_users
FROM radusergroup ug
GROUP BY ug.groupname;
```

### User dengan Session Aktif

```sql
SELECT 
    username,
    nasipaddress,
    acctstarttime,
    acctsessiontime,
    acctinputoctets,
    acctoutputoctets
FROM radacct
WHERE acctstoptime IS NULL
ORDER BY acctstarttime DESC;
```

### Total Bandwidth per User (hari ini)

```sql
SELECT 
    username,
    SUM(acctinputoctets + acctoutputoctets) as total_bytes,
    SUM(acctinputoctets + acctoutputoctets) / 1024 / 1024 as total_mb
FROM radacct
WHERE DATE(acctstarttime) = CURDATE()
GROUP BY username
ORDER BY total_bytes DESC;
```

---

## 🔒 Security Best Practices

### 1. Network Security

Jika billing server di host berbeda:

```bash
# Di MySQL server, edit /etc/mysql/mariadb.conf.d/50-server.cnf
# Bind hanya ke IP tertentu
bind-address = 192.168.1.10
```

Atau setup MySQL over SSL:
```sql
-- Grant dengan REQUIRE SSL
ALTER USER 'billing'@'10.0.0.5' REQUIRE SSL;
```

### 2. Password Management

- Gunakan password kuat untuk user billing database
- Simpan password di environment variables atau secrets manager
- Jangan hardcode password di config files

### 3. Database Permissions

Hanya berikan privilege yang diperlukan:

```sql
-- Jangan gunakan ALL PRIVILEGES
-- Gunakan privilege spesifik seperti contoh di atas
```

### 4. Monitoring

Setup monitoring untuk:
- Failed login attempts ke database
- Unusual query patterns
- Database connection errors

---

## 🔧 Troubleshooting

### Masalah: Billing tidak bisa connect ke database

**Check:**
1. Apakah MySQL listening di IP yang benar?
   ```bash
   netstat -tlnp | grep 3306
   ```
2. Apakah firewall membuka port 3306?
3. Apakah user database ada dan punya privileges?
   ```sql
   SELECT User, Host FROM mysql.user WHERE User = 'billing';
   SHOW GRANTS FOR 'billing'@'localhost';
   ```

### Masalah: User tidak bisa login setelah ditambah

**Check:**
1. Apakah password sudah di-insert ke `radcheck`?
   ```sql
   SELECT * FROM radcheck WHERE username = 'username';
   ```
2. Apakah user sudah di-assign ke group?
   ```sql
   SELECT * FROM radusergroup WHERE username = 'username';
   ```
3. Apakah group punya reply attributes?
   ```sql
   SELECT * FROM radgroupreply WHERE groupname = 'paket_10mbps';
   ```

### Masalah: Performa lambat

**Solutions:**
1. Index pada kolom username:
   ```sql
   CREATE INDEX idx_username ON radcheck(username);
   CREATE INDEX idx_username ON radusergroup(username);
   ```
2. Tune connection pool di FreeRADIUS config
3. Consider read replica untuk reporting queries

---

## 📚 Referensi

- FreeRADIUS SQL Module: https://freeradius.org/radiusd/man/sql.html
- MySQL Privileges: https://dev.mysql.com/doc/refman/8.0/en/privileges-provided.html
- Template SQL files: `sql/users.sql`, `sql/groups.sql`, `sql/suspend_unsuspend.sql`

---

## ✅ Checklist Integrasi

- [ ] User database untuk billing sudah dibuat
- [ ] Privileges sudah di-grant dengan benar
- [ ] Konfigurasi billing server sudah diupdate
- [ ] Test koneksi database dari billing server
- [ ] Test CRUD operations (create, read, update, delete user)
- [ ] Test suspend/unsuspend user
- [ ] Test ganti paket user
- [ ] Verifikasi user bisa login setelah dibuat
- [ ] Setup monitoring untuk database connections
- [ ] Dokumentasi credentials disimpan dengan aman

---

**Last Updated:** 2024  
**Maintainer:** FreeRADIUS Paket Team

