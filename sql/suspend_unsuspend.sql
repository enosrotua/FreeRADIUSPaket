-- Suspend: pindahkan user ke grup 'isolir'
-- Ganti {username}
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('{username}','isolir',1);

-- Unsuspend: kembalikan user ke grup paket
-- Ganti {username} {group}
REPLACE INTO radusergroup (username, groupname, priority)
VALUES ('{username}','{group}',1);
