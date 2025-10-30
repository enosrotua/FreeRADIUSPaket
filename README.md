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
