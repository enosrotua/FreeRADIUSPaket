# Troubleshooting FreeRADIUS

Panduan troubleshooting untuk masalah umum FreeRADIUS.

## 🔴 Error: "RADIUS server is not responding"

### Penyebab:
1. FreeRADIUS service tidak berjalan
2. IP Mikrotik router tidak ada di `clients.conf`
3. Secret tidak match antara Mikrotik dan FreeRADIUS
4. Firewall memblokir port 1812/1813

### Solusi:
1. **Cek FreeRADIUS status:**
   ```bash
   sudo systemctl status freeradius
   ```

2. **Cek listening port:**
   ```bash
   sudo ss -luna 'sport = :1812 or sport = :1813'
   ```

3. **Cek IP Mikrotik di clients.conf:**
   ```bash
   sudo cat /etc/freeradius/3.0/clients.conf | grep -A 5 "client"
   ```
   Pastikan IP Mikrotik router ada di clients.conf

4. **Pastikan secret sama:**
   - Di Mikrotik: `/radius print`
   - Di FreeRADIUS: `sudo cat /etc/freeradius/3.0/clients.conf`

5. **Test connectivity:**
   ```bash
   ping MIKROTIK_IP
   radtest user password RADIUS_SERVER_IP 0 secret
   ```

## 🔴 Error: "Access-Reject" dengan Reply-Message "voucher"

### Penyebab:
Value `Session-Timeout` atau `Idle-Timeout` di tabel `radgroupreply` menggunakan format yang tidak valid (misalnya `"5m"`).

### Solusi:
FreeRADIUS mengharapkan nilai dalam **detik** (integer), bukan format waktu seperti `"5m"` atau `"5 minutes"`.

**Fix:**
```sql
-- Ubah dari "5m" menjadi 300 (detik)
UPDATE radgroupreply 
SET value = '300' 
WHERE attribute IN ('Session-Timeout', 'Idle-Timeout') 
AND value LIKE '%m';
```

**Valid values:**
- ✅ `300` (detik)
- ✅ `3600` (detik)
- ❌ `"5m"` (tidak valid)
- ❌ `"5 minutes"` (tidak valid)

## 🔴 Error: "Unknown or invalid value for attribute Session-Timeout"

### Penyebab:
Format nilai `Session-Timeout` atau `Idle-Timeout` tidak valid.

### Solusi:
Pastikan nilai dalam detik (integer). Lihat solusi di atas.

## 🔍 Monitoring RADIUS Authentication

### Script Monitoring:
```bash
sudo bash /home/enos/FreeRADIUSPaket/scripts/monitor_radius.sh
```

Script ini akan:
- Menampilkan status FreeRADIUS
- Menampilkan port yang listening
- Menampilkan log authentication terakhir
- Live monitoring log saat login

### Manual Monitoring:
```bash
# Real-time log
sudo tail -f /var/log/freeradius/radius.log

# Atau dengan journalctl
sudo journalctl -u freeradius -f

# Debug mode (detail)
sudo systemctl stop freeradius
sudo freeradius -X
```

## 🔧 Common Issues

### 1. FreeRADIUS tidak start

**Cek konfigurasi:**
```bash
sudo freeradius -CX
```

**Cek error:**
```bash
sudo journalctl -u freeradius -n 50
```

### 2. Client tidak dikenal

**Pastikan IP ada di clients.conf:**
```bash
sudo cat /etc/freeradius/3.0/clients.conf | grep -A 5 "client"
```

**Restart setelah edit:**
```bash
sudo systemctl restart freeradius
```

### 3. User tidak bisa login

**Cek user di database:**
```sql
SELECT * FROM radcheck WHERE username='USERNAME';
SELECT * FROM radusergroup WHERE username='USERNAME';
```

**Test dengan radtest:**
```bash
sudo radtest USERNAME PASSWORD 127.0.0.1 0 testing123
```

### 4. Profile tidak match

**Cek case sensitivity:**
- Groupname di `radusergroup` harus match dengan groupname di `radgroupreply`
- FreeRADIUS melakukan case-sensitive matching

**Fix:**
Pastikan groupname sama persis (case-sensitive) antara `radusergroup` dan `radgroupreply`.

## 📝 Tips

1. **Selalu test konfigurasi sebelum restart:**
   ```bash
   sudo freeradius -CX
   ```

2. **Gunakan debug mode untuk troubleshooting:**
   ```bash
   sudo systemctl stop freeradius
   sudo freeradius -X
   ```

3. **Monitor log saat test:**
   ```bash
   sudo tail -f /var/log/freeradius/radius.log
   ```

4. **Cek database permission:**
   ```bash
   mysql -u billing -p radius
   SHOW GRANTS FOR 'billing'@'localhost';
   ```

5. **Pastikan format nilai benar:**
   - Session-Timeout: detik (integer)
   - Idle-Timeout: detik (integer)
   - Mikrotik-Rate-Limit: format "50M/50M" atau "512k/512k"

---

**Last Updated:** 2025-11-04
