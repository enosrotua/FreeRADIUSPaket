-- Grup paket contoh untuk Mikrotik (PPPoE/Hotspot)
-- Sesuaikan nilai Mikrotik-Rate-Limit dengan profil/policy Anda

-- Paket 3Mbps
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES ('paket_3mbps','Simultaneous-Use',':=','1') ON DUPLICATE KEY UPDATE value='1';
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('paket_3mbps','Mikrotik-Rate-Limit',':=','3M/3M') ON DUPLICATE KEY UPDATE value='3M/3M';

-- Paket 5Mbps
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES ('paket_5mbps','Simultaneous-Use',':=','1') ON DUPLICATE KEY UPDATE value='1';
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('paket_5mbps','Mikrotik-Rate-Limit',':=','5M/5M') ON DUPLICATE KEY UPDATE value='5M/5M';

-- Paket 10Mbps
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES ('paket_10mbps','Simultaneous-Use',':=','1') ON DUPLICATE KEY UPDATE value='1';
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('paket_10mbps','Mikrotik-Rate-Limit',':=','10M/10M') ON DUPLICATE KEY UPDATE value='10M/10M';

-- Grup isolir (limit minimal)
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES ('isolir','Simultaneous-Use',':=','1') ON DUPLICATE KEY UPDATE value='1';
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('isolir','Mikrotik-Rate-Limit',':=','1k/1k') ON DUPLICATE KEY UPDATE value='1k/1k';
