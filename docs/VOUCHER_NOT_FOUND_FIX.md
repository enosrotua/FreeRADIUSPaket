# 🔧 Fix: Voucher Tidak Bisa Login - Voucher Tidak Ada di Database RADIUS

## 📋 Masalah

Voucher hotspot tidak bisa login dengan error: **"RADIUS server is not responding"** atau **"Access-Reject"**

Setelah troubleshooting, ditemukan bahwa voucher **tidak ada di database RADIUS**.

## 🔍 Diagnosis

### Check Voucher di Database:

```bash
# Menggunakan script CVLMEDIA
cd /home/enos/cvlmedia
node scripts/check_voucher.js cvIB1QN
```

**Output jika voucher tidak ada:**
```
❌ User NOT FOUND in radcheck table!
   This means the voucher was never created in RADIUS database.
```

### Manual Check:

```sql
-- Connect ke database RADIUS
mysql -u billing -p radius

-- Check apakah voucher ada
SELECT * FROM radcheck WHERE username = 'cvIB1QN';
SELECT * FROM radusergroup WHERE username = 'cvIB1QN';
```

## ✅ Solusi

### Opsi 1: Buat Voucher Baru via CVLMEDIA (Recommended)

1. Login ke CVLMEDIA admin panel
2. Buka menu **Hotspot > Voucher**
3. Generate voucher baru dengan:
   - Username: `cvIB1QN` (atau username baru)
   - Password: (password yang diinginkan)
   - Profile: (pilih profile yang valid)
   - Server Hotspot: (pilih server atau "all")
4. Pastikan mode RADIUS aktif di **Setting > RADIUS/Api Setup**

### Opsi 2: Buat Voucher Manual di Database

```sql
-- 1. Insert password ke radcheck
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('cvIB1QN', 'Cleartext-Password', ':=', 'password123')
ON DUPLICATE KEY UPDATE value = 'password123';

-- 2. Assign user ke group/profile
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('cvIB1QN', 'default', 1);

-- 3. Verify
SELECT * FROM radcheck WHERE username = 'cvIB1QN';
SELECT * FROM radusergroup WHERE username = 'cvIB1QN';
```

**Catatan:** Ganti `'default'` dengan nama profile yang valid di `radgroupreply`.

### Opsi 3: Re-create Voucher yang Sudah Ada

Jika voucher sudah dibuat sebelumnya tapi tidak ada di RADIUS:

1. **Cek apakah voucher ada di Mikrotik** (jika mode hybrid):
   ```
   /ip hotspot user print where name=cvIB1QN
   ```

2. **Jika ada di Mikrotik tapi tidak di RADIUS:**
   - Pastikan mode RADIUS aktif
   - Hapus voucher dari Mikrotik
   - Buat ulang via CVLMEDIA (akan otomatis masuk ke RADIUS)

## 🧪 Testing Setelah Fix

### Test Authentication:

```bash
# Test dari server RADIUS
radtest cvIB1QN password123 127.0.0.1 0 testing123
```

**Expected:** `Access-Accept` ✅

### Test dari Mikrotik:

1. Coba login dengan voucher dari hotspot client
2. Check log Mikrotik:
   ```
   /log print where topics~"hotspot|radius"
   ```
3. Check log FreeRADIUS:
   ```bash
   sudo tail -f /var/log/freeradius/radius.log
   ```

## 📝 Checklist Troubleshooting

Jika masih ada masalah setelah membuat voucher:

- [ ] Voucher ada di `radcheck`: `SELECT * FROM radcheck WHERE username = 'cvIB1QN';`
- [ ] Voucher punya group: `SELECT * FROM radusergroup WHERE username = 'cvIB1QN';`
- [ ] Group punya reply attributes: `SELECT * FROM radgroupreply WHERE groupname = '<profile>';`
- [ ] Password benar (test dengan `radtest`)
- [ ] FreeRADIUS service running: `sudo systemctl status freeradius`
- [ ] Port 1812/1813 listening: `sudo ss -luna 'sport = :1812 or sport = :1813'`
- [ ] Mikrotik RADIUS client configured: `/radius print`
- [ ] Secret sama antara Mikrotik dan FreeRADIUS

## 🔍 Scripts untuk Diagnosis

### Check Voucher:

```bash
cd /home/enos/cvlmedia
node scripts/check_voucher.js <username>
```

### Check FreeRADIUS Status:

```bash
cd /home/enos/FreeRADIUSPaket
sudo bash scripts/check_voucher.sh <username>
```

## 📚 Referensi

- [RADIUS_NOT_RESPONDING_FIX_V2.md](RADIUS_NOT_RESPONDING_FIX_V2.md) - Fix FreeRADIUS service tidak berjalan
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Panduan troubleshooting umum

---

**Last Updated:** 2025-11-06  
**Issue:** Voucher tidak ada di database RADIUS  
**Status:** ✅ Diagnosis Complete - Perlu create voucher baru

