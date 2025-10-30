-- Contoh tambah user ke RADIUS (password cleartext)
-- Ganti {username} {password} {group}
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('{username}','Cleartext-Password',':=','{password}')
ON DUPLICATE KEY UPDATE value='{password}';

-- Assign user ke grup paket
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('{username}','{group}',1);
