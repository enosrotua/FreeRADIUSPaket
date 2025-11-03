# 🔧 Troubleshooting FreeRADIUS

Panduan troubleshooting untuk masalah umum FreeRADIUS.

## ❌ Error: Directory '/etc/freeradius/3.0' does not exist

### Penyebab:
- FreeRADIUS belum terinstall
- FreeRADIUS terinstall tapi directory belum dibuat
- Versi FreeRADIUS berbeda (2.x vs 3.x)

### Solusi:

#### 1. Cek Apakah FreeRADIUS Terinstall

```bash
dpkg -l | grep freeradius
```

Jika tidak ada output, berarti belum terinstall. Install dengan:

```bash
cd ~/FreeRADIUSPaket
sudo bash scripts/install_freeradius.sh
```

#### 2. Cek Direktori Konfigurasi

```bash
# Cek beberapa lokasi yang mungkin
ls -la /etc/freeradius/3.0/
ls -la /etc/freeradius/
ls -la /etc/raddb/
```

#### 3. Jika FreeRADIUS Terinstall Tapi Directory Tidak Ada

**Kemungkinan 1: Package tidak lengkap**
```bash
# Reinstall FreeRADIUS packages
sudo apt-get update
sudo apt-get install --reinstall freeradius freeradius-config freeradius-common
```

**Kemungkinan 2: Permission Issue**
```bash
# Cek dengan sudo
sudo ls -la /etc/freeradius/3.0/

# Jika ada tapi tidak bisa akses tanpa sudo, fix permission
sudo chmod -R 755 /etc/freeradius/
```

**Kemungkinan 3: Versi Berbeda**
- FreeRADIUS 2.x menggunakan `/etc/freeradius/` (tanpa subdirectory 3.0)
- FreeRADIUS 3.x menggunakan `/etc/freeradius/3.0/`

Cek versi:
```bash
freeradius -v
# atau
radiusd -v
```

#### 4. Buat Directory Manual (Jika Perlu)

```bash
# Jika directory benar-benar tidak ada
sudo mkdir -p /etc/freeradius/3.0
sudo chown freerad:freerad /etc/freeradius/3.0
sudo chmod 755 /etc/freeradius/3.0
```

#### 5. Reinstall dari Script

```bash
cd ~/FreeRADIUSPaket
sudo bash scripts/install_freeradius.sh
```

Script akan otomatis:
- Install FreeRADIUS 3.x
- Create directory structure
- Setup configuration files

## 🔍 Diagnosa Lengkap

Jalankan script berikut untuk diagnosa:

```bash
#!/bin/bash
echo "=== FreeRADIUS Diagnostic ==="
echo ""
echo "1. FreeRADIUS packages:"
dpkg -l | grep freeradius
echo ""
echo "2. FreeRADIUS version:"
freeradius -v 2>/dev/null || radiusd -v 2>/dev/null || echo "Not found"
echo ""
echo "3. Config directories:"
[ -d "/etc/freeradius/3.0" ] && echo "✅ /etc/freeradius/3.0 exists" || echo "❌ /etc/freeradius/3.0 NOT found"
[ -d "/etc/freeradius" ] && echo "✅ /etc/freeradius exists" || echo "❌ /etc/freeradius NOT found"
[ -d "/etc/raddb" ] && echo "✅ /etc/raddb exists (old version)" || echo "❌ /etc/raddb NOT found"
echo ""
echo "4. FreeRADIUS service:"
systemctl status freeradius --no-pager | head -3 || echo "Service not found"
echo ""
echo "5. FreeRADIUS binary:"
which freeradius || which radiusd || echo "Binary not in PATH"
```

## ✅ Quick Fix

Jika directory benar-benar tidak ada:

```bash
# Install/reinstall FreeRADIUS
sudo apt-get update
sudo apt-get install -y freeradius freeradius-mysql freeradius-config freeradius-common

# Verify directory created
ls -la /etc/freeradius/3.0/

# Run installation script
cd ~/FreeRADIUSPaket
sudo bash scripts/install_freeradius.sh
```

## 📝 Catatan

- Pastikan menjalankan sebagai `root` atau dengan `sudo`
- Setelah install, directory `/etc/freeradius/3.0/` akan otomatis dibuat
- Jika masih error, cek log: `journalctl -u freeradius -n 50`

---

**Last Updated:** 2024-11-03

