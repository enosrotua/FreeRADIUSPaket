# 🔧 Fix: RADIUS Server Not Responding - FreeRADIUS Service Tidak Berjalan

## 📋 Masalah

Voucher hotspot tidak bisa login dengan error: **"RADIUS server is not responding"**

Dari log Mikrotik:
```
cvIB1QN (192.168.30.254): login failed: RADIUS server is not responding
```

## 🔍 Root Cause

**FreeRADIUS service tidak bisa start** karena error konfigurasi di `/etc/freeradius/3.0/clients.conf`:

```
No 'ipaddr' or 'ipv4addr' or 'ipv6addr' field found in client localhost_ipv6
```

Client `localhost_ipv6` tidak memiliki field `ipaddr` atau `ipv6addr`, menyebabkan FreeRADIUS gagal start dan port 1812/1813 tidak listening.

## ✅ Solusi

### 1. Fix clients.conf

Edit `/etc/freeradius/3.0/clients.conf` dan tambahkan `ipv6addr` untuk client `localhost_ipv6`:

**Sebelum:**
```
client localhost_ipv6 {
	secret = testing123
	nas_type = other
	require_message_authenticator = no
}
```

**Sesudah:**
```
client localhost_ipv6 {
	ipv6addr = ::1
	secret = testing123
	nas_type = other
	require_message_authenticator = no
}
```

### 2. Restart FreeRADIUS

```bash
sudo systemctl restart freeradius
```

### 3. Verify Service Running

```bash
# Cek status
sudo systemctl status freeradius

# Cek port listening
sudo ss -luna 'sport = :1812 or sport = :1813'
```

**Expected output:**
```
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
UNCONN 0      0            0.0.0.0:1812      0.0.0.0:*          
UNCONN 0      0            0.0.0.0:1813      0.0.0.0:*          
```

## 🧪 Testing

### Test dari Server RADIUS:

```bash
# Test authentication (ganti password dengan password voucher yang benar)
radtest cvIB1QN <password> 127.0.0.1 0 testing123
```

**Expected:** `Access-Accept` jika user dan password benar.

### Test dari Mikrotik:

1. Pastikan RADIUS client dikonfigurasi dengan benar di Mikrotik:
   ```
   /radius print
   ```

2. Pastikan Hotspot menggunakan RADIUS:
   ```
   /ip hotspot print
   ```

3. Coba login dengan voucher yang sudah dibuat.

## 📝 Checklist Troubleshooting

Jika masih ada masalah setelah fix:

- [ ] FreeRADIUS service running: `sudo systemctl status freeradius`
- [ ] Port 1812/1813 listening: `sudo ss -luna 'sport = :1812 or sport = :1813'`
- [ ] Voucher ada di database: `SELECT * FROM radcheck WHERE username = 'cvIB1QN';`
- [ ] Voucher punya group: `SELECT * FROM radusergroup WHERE username = 'cvIB1QN';`
- [ ] Group punya reply attributes: `SELECT * FROM radgroupreply WHERE groupname = '<profile>';`
- [ ] Mikrotik IP ada di clients.conf: `sudo cat /etc/freeradius/3.0/clients.conf | grep ipaddr`
- [ ] Secret sama antara Mikrotik dan FreeRADIUS
- [ ] Firewall tidak block port 1812/1813: `sudo ufw status` atau `sudo iptables -L`

## 🔍 Log Monitoring

### Cek log FreeRADIUS:

```bash
# Real-time log
sudo tail -f /var/log/freeradius/radius.log

# Cek error terakhir
sudo journalctl -u freeradius -n 50 --no-pager
```

### Cek log Mikrotik:

Di Winbox/WebFig:
- **Log** → Filter: `hotspot,radius`

Atau via CLI:
```
/log print where topics~"hotspot|radius"
```

## 📚 Referensi

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Panduan troubleshooting umum
- [MIKROTIK_RADIUS_SETUP.md](MIKROTIK_RADIUS_SETUP.md) - Setup RADIUS di Mikrotik

---

**Last Updated:** 2025-11-06  
**Issue:** FreeRADIUS service tidak bisa start karena error clients.conf  
**Status:** ✅ Fixed

