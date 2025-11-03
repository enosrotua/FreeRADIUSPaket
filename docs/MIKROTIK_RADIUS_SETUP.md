# 🔧 Konfigurasi RADIUS di Mikrotik RouterOS

Panduan lengkap untuk mengkonfigurasi Mikrotik agar menggunakan FreeRADIUS server untuk autentikasi PPPoE.

## 📋 Prerequisites

- ✅ FreeRADIUS server sudah terinstall dan running
- ✅ Database `radius` sudah terisi dengan user (radcheck table)
- ✅ Mikrotik bisa reach FreeRADIUS server (network connectivity)

## 🔐 Step 1: Cek FreeRADIUS Server Info

Dari FreeRADIUS server, catat informasi berikut:
- **RADIUS Server IP**: IP address FreeRADIUS server (misal: `192.168.1.100` atau `10.0.0.100`)
- **RADIUS Secret**: Secret yang digunakan (cek di `/etc/freeradius/3.0/clients.conf`)
- **RADIUS Port**: Default `1812` untuk authentication, `1813` untuk accounting

Cek secret di FreeRADIUS:
```bash
cat /etc/freeradius/3.0/clients.conf | grep -A 5 "client"
```

Default secret biasanya `testing123` untuk testing atau bisa diset sesuai kebutuhan.

## 🛠️ Step 2: Konfigurasi RADIUS di Mikrotik

### Via Winbox / WebFig:

#### A. Tambah RADIUS Server

1. Buka **Radius** menu
2. Klik **+** untuk tambah server baru
3. Isi form:
   - **Name**: `radius-server` (atau nama lain)
   - **Service**: `login` (untuk authentication)
   - **Address**: IP address FreeRADIUS server (misal: `192.168.1.100`)
   - **Secret**: Secret dari FreeRADIUS (`testing123` atau secret custom)
   - **Timeout**: `3s` (default)
   - **Accounting Port**: `1813` (default)
   - **Authentication Port**: `1812` (default)
4. Klik **OK**

#### B. Tambah Accounting Server (Optional)

Untuk accounting/tracking koneksi:
1. Tambah lagi server RADIUS baru
2. Atau edit server yang sudah ada, enable accounting

### Via Terminal (CLI):

```bash
# Masuk ke Mikrotik terminal/SSH
/radius
add name=radius-server address=192.168.1.100 secret=testing123 service=login
```

**Catatan**: Ganti `192.168.1.100` dengan IP FreeRADIUS server Anda, dan `testing123` dengan secret yang sesuai.

## 🔄 Step 3: Konfigurasi PPPoE Server untuk Pakai RADIUS

### Via Winbox / WebFig:

1. Buka **PPP** → **PPP Profiles**
2. Edit profile yang ingin pakai RADIUS (atau buat profile baru)
3. Di tab **Authentication**:
   - **Authentication Protocol**: `pap` atau `chap` (sesuai kebutuhan)
   - **Use RADIUS**: ✅ **Enable**
   - **RADIUS Server**: Pilih server yang sudah dibuat (`radius-server`)
4. Klik **OK**

**PENTING**: Jika sudah ada user lokal di Mikrotik dan ingin pindah ke RADIUS:
- Hapus atau disable user lokal
- Atau pisahkan: user lokal untuk admin, RADIUS untuk customer

### Via Terminal (CLI):

```bash
# Edit profile existing (contoh: default)
/ppp profile
set default use-radius=yes radius-initial-attributes="Session-Timeout=3600,Idle-Timeout=300"

# Atau buat profile baru khusus RADIUS
/ppp profile
add name=radius-profile local-address=10.0.0.1 remote-address=10.0.0.2-10.0.0.254 use-radius=yes
```

## 🔍 Step 4: Verifikasi Konfigurasi

### Test dari Mikrotik:

```bash
# Test RADIUS connection
/radius test radius-server user=testuser password=testpass

# Harus muncul: Access-Accept jika user ada dan password benar
```

### Test dari FreeRADIUS Server:

```bash
# Test dengan radtest
radtest testuser testpass 127.0.0.1 0 testing123

# Atau test dari Mikrotik IP
radtest testuser testpass MIKROTIK_IP 0 testing123
```

## 📝 Step 5: Konfigurasi Mikrotik sebagai NAS Client di FreeRADIUS

Agar FreeRADIUS menerima request dari Mikrotik, tambahkan Mikrotik sebagai client di FreeRADIUS:

```bash
# Edit clients.conf di FreeRADIUS server
sudo nano /etc/freeradius/3.0/clients.conf
```

Tambahkan:

```
client mikrotik {
    ipaddr = 192.168.1.1              # IP Mikrotik
    secret = testing123                # Secret (harus sama dengan di Mikrotik)
    require_message_authenticator = no
    nas_type = other
}
```

**PENTING**: 
- Ganti `192.168.1.1` dengan IP Mikrotik Anda
- Secret harus sama dengan yang di-set di Mikrotik

Restart FreeRADIUS:
```bash
sudo systemctl restart freeradius
```

## 🔄 Step 6: Test End-to-End

### Dari Mikrotik:

1. Coba login dengan user yang ada di database RADIUS
2. Check log di FreeRADIUS:
   ```bash
   tail -f /var/log/freeradius/radius.log
   ```
3. Check active connection di Mikrotik:
   ```bash
   /ppp active print
   ```

## ⚙️ Advanced Configuration

### Multiple RADIUS Servers (Failover):

```bash
/radius
add name=radius-server-1 address=192.168.1.100 secret=testing123 service=login
add name=radius-server-2 address=192.168.1.101 secret=testing123 service=login
```

Mikrotik akan otomatis failover ke server kedua jika pertama down.

### Radius Attributes untuk Profile:

Anda bisa set attributes via RADIUS yang akan diterapkan ke user:

```bash
# Profile dengan rate limit dari RADIUS
/ppp profile
set default use-radius=yes radius-initial-attributes="Session-Timeout=3600"
```

Attributes yang bisa dikirim dari RADIUS:
- `Session-Timeout`: Timeout session (dalam detik)
- `Idle-Timeout`: Timeout idle (dalam detik)
- `Mikrotik-Rate-Limit`: Rate limit (contoh: `512k/512k`)
- `Framed-IP-Address`: IP address untuk user
- `Framed-IP-Netmask`: Netmask

## 📊 Monitoring

### Check RADIUS Connection di Mikrotik:

```bash
/radius print
/radius print stats
```

### Check Active PPPoE Sessions:

```bash
/ppp active print
```

### Check Accounting di FreeRADIUS:

```bash
mysql -u radius -p radius
SELECT * FROM radacct ORDER BY acctstarttime DESC LIMIT 10;
```

## 🐛 Troubleshooting

### Error: "Access-Reject" saat login
**Solusi**:
1. Cek user ada di database: `SELECT * FROM radcheck WHERE username='testuser';`
2. Cek password benar
3. Cek secret di Mikrotik dan FreeRADIUS sama
4. Cek firewall tidak block port 1812/1813

### Error: "No response from RADIUS server"
**Solusi**:
1. Cek connectivity: `ping RADIUS_SERVER_IP`
2. Cek FreeRADIUS running: `systemctl status freeradius`
3. Cek firewall: Port 1812/1813 harus open
4. Cek IP address benar di Mikrotik

### Error: "Timeout"
**Solusi**:
1. Increase timeout di Mikrotik: `/radius set radius-server timeout=5s`
2. Cek network latency
3. Cek FreeRADIUS tidak overload

### User login tapi tidak dapat IP
**Solusi**:
1. Cek profile PPPoE memiliki `remote-address` pool
2. Cek IP pool tersedia
3. Cek `Framed-IP-Address` di RADIUS reply

## 📚 Contoh Konfigurasi Lengkap

### Mikrotik (CLI):

```bash
# 1. Setup RADIUS server
/radius
add name=freeradius-server address=192.168.1.100 secret=testing123 service=login

# 2. Setup PPPoE profile dengan RADIUS
/ppp profile
add name=radius-customers \
    local-address=10.0.0.1 \
    remote-address=10.0.0.2-10.0.0.254 \
    use-radius=yes \
    rate-limit=0/0

# 3. Setup PPPoE server (jika belum ada)
/interface pppoe-server server
add interface=ether1 service-name=internet default-profile=radius-customers
```

### FreeRADIUS clients.conf:

```
client mikrotik {
    ipaddr = 192.168.1.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
}
```

## ✅ Checklist

- [ ] RADIUS server ditambahkan di Mikrotik
- [ ] Secret sama antara Mikrotik dan FreeRADIUS
- [ ] Mikrotik ditambahkan sebagai client di FreeRADIUS
- [ ] PPPoE profile mengaktifkan `use-radius=yes`
- [ ] Test connection berhasil
- [ ] User bisa login via RADIUS

---

**Last Updated:** 2024-11-03

