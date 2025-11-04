-- Update permission untuk user 'billing' agar bisa INSERT/UPDATE/DELETE pada tabel radreply
-- Script ini perlu dijalankan sebagai root MariaDB

GRANT SELECT, INSERT, UPDATE, DELETE ON radius.radreply TO 'billing'@'localhost';
FLUSH PRIVILEGES;

-- Verifikasi permission
SHOW GRANTS FOR 'billing'@'localhost';

