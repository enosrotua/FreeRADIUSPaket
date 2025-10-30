[![CI](https://github.com/enosrotua/FreeRADIUSPaket/actions/workflows/radius-ci.yml/badge.svg)](https://github.com/enosrotua/FreeRADIUSPaket/actions/workflows/radius-ci.yml)

# FreeRADIUS Paket

Paket instalasi FreeRADIUS + MariaDB untuk integrasi Mikrotik dan cvlmedia (mode RADIUS).

Isi Paket:
- scripts/install_freeradius.sh: instalasi & konfigurasi otomatis
- configs/sql: contoh config modul SQL (MySQL)
- configs/sites-default: site default dengan SQL aktif
- configs/clients.conf.example: template NAS Mikrotik

Instalasi Cepat:
  sudo bash scripts/install_freeradius.sh

Default database:
- DB: radius
- User: radius
- Pass: radius

Setelah instal:
- Tambahkan setiap Mikrotik ke clients.conf dengan shared-secret Anda
- Buka UDP 1812 (auth) & 1813 (acct)

Test:
  radtest testuser testpass 127.0.0.1 0 testing123

Integrasi cvlmedia (settings.json):
- user_auth_mode: radius
- radius_host: localhost
- radius_user: radius
- radius_password: radius
- radius_database: radius

## Langkah Instalasi Lengkap (Production)
1) Install paket
   sudo bash scripts/install_freeradius.sh

2) Tambah NAS Mikrotik
   - Salin contoh configs/clients.conf.example ke /etc/freeradius/3.0/clients.conf
   - Edit ipaddr dan secret untuk setiap Mikrotik (A/B/C)
   - Restart FreeRADIUS: sudo systemctl restart freeradius

3) Verifikasi DB & autentikasi
   - Buat user contoh: INSERT INTO radius.radcheck (username,attribute,op,value) VALUES ('testuser','Cleartext-Password',':=','testpass');
   - Test: radtest testuser testpass 127.0.0.1 0 testing123  (harus Access-Accept)

4) Integrasi cvlmedia (settings.json)
   - user_auth_mode: radius
   - radius_host: localhost
   - radius_user: radius
   - radius_password: radius
   - radius_database: radius

5) Mikrotik (PPP Secret/Hotspot ke RADIUS)
   - Radius Servers: add  address=<IP_RADIUSS> secret=<SECRET> service=ppp,hotspot accounting-port=1813 authentication-port=1812
   - PPP AAA: use-radius=yes  Hotspot: use-radius=yes
   - Pastikan waktu (NTP) benar dan firewall membuka UDP 1812/1813

Catatan Keamanan
- Ubah password DB dan shared secret sebelum production.
- Batasi akses 1812/1813 hanya dari IP Mikrotik.
