# 🔧 Setup Mikrotik sebagai RADIUS Client di FreeRADIUS

## 📋 Masalah

Mikrotik tidak bisa connect ke FreeRADIUS server, error: **"RADIUS server is not responding"**

Dari log Mikrotik:
```
rt (192.168.30.254): login failed: RADIUS server is not responding
```

## 🔍 Root Cause

**IP Mikrotik router tidak ada di `/etc/freeradius/3.0/clients.conf`** atau **secret tidak match**.

FreeRADIUS hanya menerima request dari IP yang sudah dikonfigurasi di `clients.conf`. Jika IP Mikrotik tidak ada, request akan di-reject atau diabaikan.

## ✅ Solusi

### Step 1: Cari IP Mikrotik Router

Dari log Mikrotik, IP client hotspot adalah `192.168.30.254`, tapi yang penting adalah **IP router Mikrotik itu sendiri** yang mengirim request ke RADIUS server.

**Cara cek IP Mikrotik:**
1. Login ke Mikrotik (Winbox/SSH)
2. Cek IP address:
   ```
   /ip address print
   ```
3. Atau cek dari router yang terhubung ke RADIUS server:
   ```
   /ip route print
   ```

**Atau dari RADIUS server, cek IP yang mencoba connect:**
```bash
sudo tcpdump -i any port 1812 -n
# Coba login dari Mikrotik, lihat IP source
```

### Step 2: Tambahkan IP Mikrotik ke clients.conf

Edit `/etc/freeradius/3.0/clients.conf`:

```bash
sudo nano /etc/freeradius/3.0/clients.conf
```

Tambahkan client baru (ganti IP dan secret sesuai konfigurasi):

```
client mikrotik-hotspot {
    ipaddr = 192.168.30.1              # IP Mikrotik router (GANTI dengan IP yang benar!)
    secret = testing123                 # Secret (harus sama dengan di Mikrotik)
    require_message_authenticator = no
    nas_type = mikrotik
}
```

**PENTING:**
- `ipaddr` = IP Mikrotik router yang mengirim request ke RADIUS server
- `secret` = Secret yang dikonfigurasi di Mikrotik (harus sama!)
- `nas_type = mikrotik` = Optional, tapi membantu identifikasi

### Step 3: Pastikan Secret Sama

**Di Mikrotik, cek secret:**
```
/radius print
```

**Di FreeRADIUS, secret harus sama dengan di Mikrotik.**

### Step 4: Restart FreeRADIUS

```bash
sudo systemctl restart freeradius
sudo systemctl status freeradius
```

### Step 5: Cek Firewall

Pastikan firewall tidak memblokir port 1812/1813:

```bash
# Cek iptables
sudo iptables -L -n | grep 1812

# Cek ufw
sudo ufw status

# Jika perlu, allow port 1812/1813
sudo ufw allow 1812/udp
sudo ufw allow 1813/udp
```

### Step 6: Test Connectivity

**Catatan:** Command `/radius test` tidak tersedia di semua versi RouterOS. Gunakan cara lain untuk test.

**Alternatif test dari Mikrotik:**
1. Coba login dari hotspot client
2. Monitor log FreeRADIUS untuk melihat apakah request sampai
3. Atau gunakan `/ping` untuk test connectivity:
   ```
   /ping 103.19.57.68
   ```

**Atau test ping:**
```
/ping <RADIUS_SERVER_IP>
```

## 🧪 Testing

### Test dari RADIUS Server:

```bash
# Monitor log saat test dari Mikrotik
sudo tail -f /var/log/freeradius/radius.log

# Di terminal lain, coba login dari Mikrotik
# Lihat apakah request sampai ke server
```

### Test dari Mikrotik:

1. Pastikan RADIUS client dikonfigurasi:
   ```
   /radius print
   ```

2. Test authentication:
   ```
   /radius test <server-name> user=rt password=rt
   ```

3. Coba login dari hotspot client

## 📝 Checklist Troubleshooting

Jika masih error setelah setup:

- [ ] IP Mikrotik router ada di `clients.conf`: `sudo cat /etc/freeradius/3.0/clients.conf | grep ipaddr`
- [ ] Secret sama antara Mikrotik dan FreeRADIUS
- [ ] FreeRADIUS service running: `sudo systemctl status freeradius`
- [ ] Port 1812/1813 listening: `sudo ss -luna 'sport = :1812 or sport = :1813'`
- [ ] Firewall tidak block: `sudo ufw status` atau `sudo iptables -L`
- [ ] Network connectivity: `ping <RADIUS_SERVER_IP>` dari Mikrotik
- [ ] Request sampai ke server: Cek log FreeRADIUS saat test login

## 🔍 Debugging

### Cek apakah request sampai ke server:

```bash
# Monitor log real-time
sudo tail -f /var/log/freeradius/radius.log

# Atau cek dengan tcpdump
sudo tcpdump -i any port 1812 -n -v
```

**Jika tidak ada request di log:**
- IP Mikrotik tidak ada di clients.conf
- Firewall memblokir
- Network connectivity issue

**Jika ada request tapi di-reject:**
- Secret tidak match
- User tidak ada di database
- Konfigurasi lain salah

## 📚 Referensi

- [MIKROTIK_RADIUS_SETUP.md](MIKROTIK_RADIUS_SETUP.md) - Setup RADIUS di Mikrotik
- [RADIUS_NOT_RESPONDING_FIX_V2.md](RADIUS_NOT_RESPONDING_FIX_V2.md) - Fix FreeRADIUS service
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting umum

---

**Last Updated:** 2025-11-06  
**Issue:** Mikrotik tidak bisa connect ke RADIUS server  
**Status:** ⚠️ Perlu tambahkan IP Mikrotik ke clients.conf

