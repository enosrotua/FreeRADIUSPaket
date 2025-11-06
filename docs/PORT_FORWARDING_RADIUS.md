# 🔧 Setup RADIUS dengan Port Forwarding/NAT

## 📋 Skenario

RADIUS server memiliki:
- **IP Lokal**: `10.201.39.66` (IP internal server)
- **IP Public**: `103.19.57.68` (IP yang di-forward)

Mikrotik mengirim request ke `103.19.57.68`, kemudian di-forward ke `10.201.39.66`.

## 🔍 Masalah

**IP yang perlu ditambahkan ke `clients.conf` adalah IP router yang melakukan forwarding**, bukan IP tujuan (`103.19.57.68`).

Ketika request di-forward, IP source tetap adalah IP router Mikrotik yang mengirim request, bukan IP tujuan.

## ✅ Solusi

### Step 1: Cari IP Router yang Mengirim Request

**Opsi A: Monitor dengan tcpdump**

```bash
# Di RADIUS server (10.201.39.66)
sudo tcpdump -i any port 1812 -n

# Coba login dari Mikrotik hotspot
# Lihat IP source yang muncul
```

**Opsi B: Cek log FreeRADIUS**

```bash
# Monitor log saat test login
sudo tail -f /var/log/freeradius/radius.log

# Cari pesan "Ignoring request" atau "Dropping packet"
# IP yang muncul adalah IP yang perlu ditambahkan
```

**Opsi C: Cek dari Mikrotik**

```
# Di Mikrotik, cek IP yang digunakan untuk connect ke RADIUS
/ip address print
# Cari IP yang bisa reach 103.19.57.68
```

### Step 2: Tambahkan IP Router ke clients.conf

Setelah menemukan IP router, tambahkan ke `/etc/freeradius/3.0/clients.conf`:

```bash
sudo nano /etc/freeradius/3.0/clients.conf
```

Tambahkan:

```
client mikrotik-forwarded {
    ipaddr = <IP_ROUTER_MIKROTIK>        # IP router yang mengirim request
    secret = testing123                   # Secret (harus sama dengan di Mikrotik)
    require_message_authenticator = no
    nas_type = mikrotik
}
```

**PENTING:**
- `ipaddr` = IP router Mikrotik yang mengirim request (bukan 103.19.57.68!)
- `secret` = Secret yang dikonfigurasi di Mikrotik (harus sama!)

### Step 3: Restart FreeRADIUS

```bash
sudo systemctl restart freeradius
sudo systemctl status freeradius
```

### Step 4: Test

1. **Monitor log FreeRADIUS:**
   ```bash
   sudo tail -f /var/log/freeradius/radius.log
   ```

2. **Coba login dari Mikrotik hotspot** (user `rt`)

3. **Cek apakah request sampai:**
   - Jika request sampai, akan muncul di log
   - Jika masih "Ignoring request", IP belum benar

## 🔍 Troubleshooting

### Request masih tidak sampai

1. **Cek IP yang benar:**
   ```bash
   # Monitor dengan tcpdump
   sudo tcpdump -i any port 1812 -n -v
   # Coba login, lihat IP source
   ```

2. **Cek log untuk "Ignoring request":**
   ```bash
   sudo grep "Ignoring request" /var/log/freeradius/radius.log | tail -5
   ```

3. **Pastikan secret match:**
   - Di Mikrotik: `/radius print` → lihat secret
   - Di clients.conf: harus sama

### Request sampai tapi Access-Reject

1. **Cek user ada di database:**
   ```bash
   mysql -u billing -p radius
   SELECT * FROM radcheck WHERE username = 'rt';
   ```

2. **Cek user punya group:**
   ```sql
   SELECT * FROM radusergroup WHERE username = 'rt';
   ```

3. **Cek group punya reply attributes:**
   ```sql
   SELECT * FROM radgroupreply WHERE groupname = '<profile>';
   ```

## 📝 Checklist

- [ ] IP router Mikrotik ditemukan (bukan IP tujuan 103.19.57.68)
- [ ] IP router ditambahkan ke `clients.conf`
- [ ] Secret sama antara Mikrotik dan FreeRADIUS
- [ ] FreeRADIUS di-restart setelah update
- [ ] Request sampai ke server (cek log)
- [ ] Authentication berhasil (Access-Accept)

## 🔄 Port Forwarding Configuration

Jika menggunakan port forwarding di router/firewall:

**Contoh konfigurasi NAT/Port Forward:**
```
Source: Any
Destination: 103.19.57.68:1812
Forward to: 10.201.39.66:1812
```

**PENTING:** IP source yang sampai ke RADIUS server adalah IP router Mikrotik, bukan IP tujuan.

## 📚 Referensi

- [MIKROTIK_RADIUS_CLIENT_SETUP.md](MIKROTIK_RADIUS_CLIENT_SETUP.md) - Setup umum
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting umum

---

**Last Updated:** 2025-11-06  
**Issue:** Port forwarding - IP source berbeda dari IP tujuan  
**Status:** ⚠️ Perlu cari IP router yang benar

