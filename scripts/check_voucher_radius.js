#!/usr/bin/env node
/**
 * Script untuk check voucher di database RADIUS
 * Usage: node check_voucher_radius.js <username>
 */

const mysql = require('mysql2/promise');
const path = require('path');
const fs = require('fs');

const username = process.argv[2] || 'cvIB1QN';

async function getRadiusConfig() {
    // Try to read from CVLMEDIA settings.json
    const cvlmediaPath = '/home/enos/cvlmedia/settings.json';
    if (fs.existsSync(cvlmediaPath)) {
        try {
            const settings = JSON.parse(fs.readFileSync(cvlmediaPath, 'utf8'));
            if (settings.radius_host && settings.radius_user && settings.radius_password) {
                return {
                    host: settings.radius_host || 'localhost',
                    user: settings.radius_user || 'billing',
                    password: settings.radius_password,
                    database: settings.radius_database || 'radius'
                };
            }
        } catch (e) {
            console.error('Error reading CVLMEDIA settings:', e.message);
        }
    }
    
    // Try to read from app_settings table (CVLMEDIA)
    try {
        const sqlite3 = require('sqlite3').verbose();
        const dbPath = '/home/enos/cvlmedia/data/billing.db';
        if (fs.existsSync(dbPath)) {
            const db = new sqlite3.Database(dbPath);
            return new Promise((resolve, reject) => {
                db.all("SELECT key, value FROM app_settings WHERE key LIKE 'radius_%'", [], (err, rows) => {
                    db.close();
                    if (err) {
                        reject(err);
                        return;
                    }
                    
                    const config = {
                        host: 'localhost',
                        user: 'billing',
                        password: '',
                        database: 'radius'
                    };
                    
                    rows.forEach(row => {
                        const key = row.key.replace('radius_', '');
                        if (key === 'host') config.host = row.value;
                        else if (key === 'user') config.user = row.value;
                        else if (key === 'password') config.password = row.value;
                        else if (key === 'database') config.database = row.value;
                    });
                    
                    if (config.password) {
                        resolve(config);
                    } else {
                        reject(new Error('No RADIUS password found'));
                    }
                });
            });
        }
    } catch (e) {
        console.error('Error reading app_settings:', e.message);
    }
    
    throw new Error('Cannot find RADIUS configuration');
}

async function checkVoucher() {
    try {
        console.log(`🔍 Checking voucher: ${username}\n`);
        
        const config = await getRadiusConfig();
        console.log(`📡 Connecting to RADIUS database: ${config.user}@${config.host}/${config.database}\n`);
        
        const conn = await mysql.createConnection(config);
        
        // Check radcheck
        console.log('📊 Checking radcheck table...');
        const [radcheck] = await conn.execute(
            'SELECT username, attribute, op, value FROM radcheck WHERE username = ?',
            [username]
        );
        
        if (radcheck.length === 0) {
            console.log('❌ User NOT FOUND in radcheck table!');
            console.log('   This means the voucher was never created in RADIUS database.\n');
        } else {
            console.log('✅ User found in radcheck:');
            radcheck.forEach(row => {
                console.log(`   ${row.username} | ${row.attribute} | ${row.op} | ${row.value}`);
            });
            console.log('');
        }
        
        // Check radusergroup
        console.log('📊 Checking radusergroup table...');
        const [radusergroup] = await conn.execute(
            'SELECT username, groupname, priority FROM radusergroup WHERE username = ?',
            [username]
        );
        
        if (radusergroup.length === 0) {
            console.log('❌ User NOT FOUND in radusergroup table!');
            console.log('   This means the user has no profile/group assigned.\n');
        } else {
            console.log('✅ User found in radusergroup:');
            radusergroup.forEach(row => {
                console.log(`   ${row.username} | ${row.groupname} | Priority: ${row.priority}`);
            });
            console.log('');
            
            // Check radgroupreply for each group
            for (const group of radusergroup) {
                console.log(`📊 Checking radgroupreply for group: ${group.groupname}...`);
                const [radgroupreply] = await conn.execute(
                    'SELECT groupname, attribute, op, value FROM radgroupreply WHERE groupname = ?',
                    [group.groupname]
                );
                
                if (radgroupreply.length === 0) {
                    console.log(`   ⚠️  No attributes found for group '${group.groupname}'!`);
                    console.log('   This might cause authentication issues.\n');
                } else {
                    console.log(`   ✅ Found ${radgroupreply.length} attributes:`);
                    radgroupreply.forEach(row => {
                        console.log(`      ${row.attribute} | ${row.op} | ${row.value}`);
                    });
                    console.log('');
                }
            }
        }
        
        // Check radreply
        console.log('📊 Checking radreply table (user-specific attributes)...');
        const [radreply] = await conn.execute(
            'SELECT username, attribute, op, value FROM radreply WHERE username = ?',
            [username]
        );
        
        if (radreply.length === 0) {
            console.log('   No user-specific attributes found.\n');
        } else {
            console.log('✅ User-specific attributes:');
            radreply.forEach(row => {
                console.log(`   ${row.attribute} | ${row.op} | ${row.value}`);
            });
            console.log('');
        }
        
        await conn.end();
        
        // Summary
        console.log('📋 Summary:');
        if (radcheck.length === 0) {
            console.log('   ❌ Voucher does NOT exist in RADIUS database');
            console.log('   💡 Solution: Create the voucher again via CVLMEDIA billing application');
        } else if (radusergroup.length === 0) {
            console.log('   ⚠️  Voucher exists but has NO profile/group assigned');
            console.log('   💡 Solution: Assign a profile to the voucher');
        } else {
            console.log('   ✅ Voucher exists and has profile assigned');
            console.log('   💡 If authentication still fails, check:');
            console.log('      1. Password is correct');
            console.log('      2. Group has valid reply attributes');
            console.log('      3. FreeRADIUS service is running');
            console.log('      4. Mikrotik RADIUS client is configured correctly');
        }
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        if (error.code === 'ER_ACCESS_DENIED_ERROR') {
            console.error('   Cannot connect to database. Check credentials.');
        }
        process.exit(1);
    }
}

checkVoucher();

