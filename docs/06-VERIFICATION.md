# Verification & Testing Guide

**Phase 6: Testing ATAK client connections and validating the complete deployment**

This is the final phase! You'll verify that everything works end-to-end.

---

## Document Conventions

See [Phase 1: LXD Setup](01-LXD-SETUP.md#document-conventions) for the full conventions guide.

**Quick Reference:**
| Symbol | Meaning |
|--------|---------|
| 💻 | **Local Machine** - Your Windows/Mac/Linux workstation |
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside containers) |
| 📦 | **Inside Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - Replace placeholder values |

**Placeholders used in this document:**
- `[YOUR_DOMAIN]` - Your TAK server FQDN (e.g., `tak.example.com`)
- `[YOUR_VPS_IP]` - Your VPS public IP address
- `[USERNAME]` - TAK user account name (e.g., `jsmith`)
- `[CERT_PASSWORD]` - Your certificate password (default: `atakatak`)
- `[YOUR_ORG]` - Your organization name

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_DOMAIN]` becomes `tak.example.com`
> (Keep any surrounding quotes, remove the brackets)

---

## Prerequisites

Before starting Phase 6, verify all previous phases are complete:

- [ ] Phase 1: LXD Setup ✅
- [ ] Phase 2: Container Setup ✅
- [ ] Phase 3: TAK Installation ✅
- [ ] Phase 4: Certificate Management ✅
- [ ] Phase 5: Networking ✅
- [ ] Can access TAK web UI from external network
- [ ] Have enrollment package or client certificates ready

---

## Step 1: Access TAK Server Web UI

### 1.1 Import Web Admin Certificate to Browser

💻 **Local Machine**

**Firefox:**
1. Open Firefox
2. Go to Settings (☰ menu → Settings)
3. Search for "certificates"
4. Click "View Certificates"
5. Click "Your Certificates" tab
6. Click "Import"
7. Select `webadmin.p12` file
8. Enter password: `[CERT_PASSWORD]`
9. Click OK

**Chrome/Edge:**
1. Go to Settings
2. Search for "certificates"
3. Click "Manage certificates"
4. Click "Import"
5. Follow wizard to import `webadmin.p12`
6. Enter password when prompted
7. Place in "Personal" certificates store

### 1.2 Access Web UI

💻 **Local Machine** (in your browser)

Navigate to:
```
https://[YOUR_DOMAIN]:8443
```

**What you should see:**
- Browser prompts you to select a certificate (choose webadmin)
- TAK Server dashboard loads
- No certificate errors (self-signed warning is normal without Let's Encrypt)

**If you see SSL errors:**
- Import the certificate again
- Try Firefox (better client cert support)
- Check that webadmin.p12 matches the server's CA

---

## Step 2: Create TAK Server Users

Users need accounts for certificate enrollment.

### 2.1 Create User via Web UI

1. In TAK Server web UI, click **User Manager** in left sidebar
2. Click **Add User** button
3. Fill in user details:
   - **Username:** `[USERNAME]` (e.g., `jsmith`)
   - **Password:** [choose strong password]
   - **Role:** `ROLE_ADMIN` (for testing, or `ROLE_USER` for regular users)
4. Click **Create User**
5. User appears in the list ✅

### 2.2 Create User via Command Line (Alternative)

📦 **Inside TAK Container**

```bash
lxc exec tak -- bash

# Use UserManager tool
cd /opt/tak
sudo java -jar utils/UserManager.jar usermod \
    -A -p [password] [USERNAME]

# Verify user created
sudo java -jar utils/UserManager.jar userlist

# Exit container
exit
```

---

## Step 3: Connect ATAK Client (Android)

### 3.1 Prerequisites

**On Android device:**
- ATAK installed (download from tak.gov or Google Play if civilian version)
- Device has internet connectivity
- Can reach `[YOUR_DOMAIN]` (test in browser)

### 3.2 Method A: Using Enrollment Package (Recommended)

**Step 1: Transfer enrollmentDP.zip to Android**
- Email to yourself
- Transfer via USB
- Upload to cloud storage (Google Drive, NextCloud)
- AirDrop (if iOS/Mac ecosystem)

**Step 2: Import Enrollment Package in ATAK**

**Import Option 1 (ATAK 5.4.0+):**
1. Open ATAK
2. Go to **Settings → Import → Local SD**
3. Browse to `/Download/` folder
4. Select `enrollmentDP.zip`
5. Select **Copy files** option

**Import Option 2 (ATAK 5.4.0+):**
1. Open ATAK
2. Go to **Settings → Network Preferences → Data Package**
3. Browse to `/Download/` folder
4. Select `enrollmentDP.zip`

**Step 3: Enroll Certificate**

1. Go to **Settings → Network → Certificate Enrollment**
2. Tap the imported server configuration
3. Enter username: `[USERNAME]`
4. Enter password: [password you set in Step 2]
5. Tap **Enroll**
6. Wait 10-30 seconds for certificate generation
7. "Enrollment successful" message appears ✅
8. ATAK automatically connects to server

**Step 4: Verify Connection**

- Top-right corner should show green indicator: **Connected**
- Bottom status bar shows: **TAK Server: Connected**

### 3.3 Method B: Using Pre-Generated Certificate

If you created a certificate manually in Phase 4:

1. Transfer `[USERNAME].p12` to Android device
2. Open ATAK
3. Go to **Settings → Network Preferences → Manage Server Connections**
4. Tap **+** to add server
5. Enter:
   - **Description:** `[YOUR_ORG] TAK Server`
   - **Address:** `[YOUR_DOMAIN]`
   - **Port:** `8089`
   - **Protocol:** `SSL`
6. Tap **Manage SSL/TLS Certificates**
7. Import client certificate (`[USERNAME].p12`)
8. Enter certificate password: `[CERT_PASSWORD]`
9. Import CA certificate (`truststore-root.p12` from enrollment package)
10. Save and connect

---

## Step 4: Connect WinTAK Client (Windows)

### 4.1 Install WinTAK

Download WinTAK from tak.gov (requires account).

### 4.2 Import Certificate

💻 **Local Machine**

1. Launch WinTAK
2. Click **Settings** (gear icon)
3. Go to **Network Preferences** tab
4. Click **Manage Server Connections**
5. Click **Add** to create new connection
6. Configure connection:
   - **Description:** `[YOUR_ORG] TAK Server`
   - **Address:** `[YOUR_DOMAIN]:8089:ssl`
   - Check "Connect on startup"
7. Under **Authentication** section:
   - Click **Browse** next to "Client Certificate"
   - Select `[USERNAME].p12`
   - Enter password: `[CERT_PASSWORD]`
   - Click **Browse** next to "CA Certificate"
   - Select `truststore-root.p12` (extract from enrollmentDP.zip)
8. Click **Apply**
9. Click **Connect**

### 4.3 Verify Connection

- Bottom-right corner shows: **Connected to [YOUR_ORG] TAK Server**
- Green indicator appears
- Console shows: `Connection established`

---

## Step 5: Test Data Sharing Between Clients

### 5.1 Test Self-Marker Visibility

**On ATAK (Android):**
1. Your position (blue dot) should appear on map
2. Long-press anywhere on map
3. Select "Add Marker"
4. Give it a name: "Test Marker 1"
5. Tap "Send" → "All Chat Rooms"

**On WinTAK (Windows):**
1. Test Marker 1 should appear on your map within 1-2 seconds ✅
2. You should see ATAK user's position marker

**If markers don't appear:**
- Check both clients show "Connected"
- Check TAK Server logs for errors
- Verify both clients are in same group/chat room

### 5.2 Test Text Chat

**From ATAK:**
1. Tap chat icon (speech bubble)
2. Type message: "Testing TAK Server"
3. Send to "All Chat Rooms"

**On WinTAK:**
1. Chat window should show the message ✅
2. Reply back: "WinTAK received"

**On ATAK:**
1. Should see WinTAK's reply ✅

### 5.3 Test File Sharing

**From ATAK:**
1. Take a photo or select existing image
2. Share to ATAK → Attach to marker
3. Send to All Chat Rooms

**On WinTAK:**
1. Right-click on marker
2. Select "View Attachments"
3. Should see and download the image ✅

---

## Step 6: Monitor Server Performance

### 6.1 Check TAK Server Status

🖥️ **VPS Host**

```bash
lxc exec tak -- systemctl status takserver

# Should show: active (running)
```

### 6.2 Check Active Connections

**Via Web UI:**
1. Login to `https://[YOUR_DOMAIN]:8443`
2. Dashboard shows:
   - Active clients
   - Messages per second
   - Uptime

**Via Command Line:**

📦 **Inside TAK Container**

```bash
lxc exec tak -- bash

# Check listening ports and connections
netstat -tnp | grep :8089

# Should show ESTABLISHED connections for each client
```

### 6.3 Monitor Logs

📦 **Inside TAK Container**

```bash
# Real-time log monitoring
tail -f /opt/tak/logs/takserver-messaging.log

# Look for:
# - Client connection events
# - Certificate validation
# - Message routing
# - Any ERROR or WARN messages
```

### 6.4 Check PostgreSQL Database

📦 **Inside TAK Container**

```bash
# Switch to postgres user
sudo su - postgres

# Connect to database
psql -d cot

# Check active sessions
SELECT * FROM cot_router.client_endpoint;

# Should show connected clients with:
# - uid (username)
# - callsign
# - last_event_time (recent timestamp)

# Exit
\q
exit
```

---

## Step 7: Performance Testing

### 7.1 Multi-Client Test

**Connect multiple clients:**
- 2-3 ATAK devices
- 1-2 WinTAK instances
- Mix of enrollment and manual certificates

**Test load:**
1. All clients send markers simultaneously
2. All clients send chat messages
3. Transfer files between clients

**Monitor:**

🖥️ **VPS Host**

```bash
# Check CPU/memory usage
lxc exec tak -- top

# Watch for:
# - Java process CPU% (should be reasonable)
# - Memory usage (should not constantly increase)
# - System load average
```

### 7.2 Message Rate Test

**Stress test (optional):**
1. Send rapid-fire position updates
2. Create many markers quickly
3. Send large files

**Check for:**
- ❌ Connection drops
- ❌ Message delays >5 seconds
- ❌ Memory leaks
- ✅ Stable performance

---

## Step 8: Backup and Snapshot

### 8.1 Create Production-Ready Snapshot

🖥️ **VPS Host**

```bash
# Create final snapshot with working configuration
lxc snapshot tak production-ready

# List all snapshots
lxc info tak | grep -A 20 Snapshots

# Should show:
# - fresh-setup (pre-TAK)
# - tak-installed (post-TAK)
# - production-ready (tested and verified)
```

### 8.2 Backup Important Files

🖥️ **VPS Host**

```bash
# Create backup directory
mkdir -p ~/tak-backups/$(date +%Y%m%d)

# Backup certificates
lxc file pull -r tak/opt/tak/certs/files/ ~/tak-backups/$(date +%Y%m%d)/certs/

# Backup configuration
lxc file pull tak/opt/tak/CoreConfig.xml ~/tak-backups/$(date +%Y%m%d)/

# Backup database (from inside container)
lxc exec tak -- sudo -u postgres pg_dump cot > ~/tak-backups/$(date +%Y%m%d)/cot-database.sql

# Backup enrollment package
cp ~/enrollmentDP.zip ~/tak-backups/$(date +%Y%m%d)/

# Create archive
cd ~/tak-backups
tar -czf tak-backup-$(date +%Y%m%d).tar.gz $(date +%Y%m%d)/

# Verify archive
ls -lh tak-backup-*.tar.gz
```

### 8.3 Store Backup Off-Server

💻 **Local Machine** (not VPS)

```bash
# Copy to your local machine
scp takadmin@[YOUR_VPS_IP]:~/tak-backups/tak-backup-*.tar.gz ./

# Or upload to cloud storage:
# - Google Drive (via web interface)
# - NextCloud
# - Encrypted USB drive
```

---

## Step 9: Production Readiness Checklist

### 9.1 Security Checklist

- [ ] Changed certificate password from default `atakatak`
- [ ] Root CA private key is backed up securely
- [ ] SSH key authentication is working (password auth can be disabled)
- [ ] UFW firewall is enabled and configured
- [ ] Only necessary ports are open (8089, 8443, 8446, 22)
- [ ] TAK Server web UI is SSL-secured
- [ ] User accounts have strong passwords
- [ ] Certificate revocation process is documented

### 9.2 Operational Checklist

- [ ] TAK Server starts automatically on boot
- [ ] PostgreSQL starts automatically on boot
- [ ] LXD containers auto-start configured
- [ ] Backup strategy is in place
- [ ] Monitoring is configured (optional but recommended)
- [ ] Contact list for TAK Server issues is documented
- [ ] Recovery procedures are documented

### 9.3 Documentation Checklist

- [ ] Server connection details documented
- [ ] Certificate password recorded (securely)
- [ ] User account credentials documented
- [ ] VPS login credentials backed up
- [ ] Network configuration documented
- [ ] Emergency contact procedures documented

### 9.4 Client Checklist

- [ ] Enrollment packages created and distributed
- [ ] Users successfully connected with ATAK/WinTAK
- [ ] Data sharing tested and working
- [ ] Chat functionality tested
- [ ] File sharing tested
- [ ] User training materials prepared

---

## Step 10: Configure Auto-Start

### 10.1 Enable Container Auto-Start

🖥️ **VPS Host**

```bash
# TAK container auto-start on boot
lxc config set tak boot.autostart true
lxc config set tak boot.autostart.delay 10

# HAProxy container auto-start (if using)
lxc config set haproxy boot.autostart true
lxc config set haproxy boot.autostart.delay 5

# Verify configuration
lxc config show tak | grep autostart
```

### 10.2 Test Auto-Start

```bash
# Reboot VPS to test
sudo reboot

# Wait 2 minutes, then reconnect
ssh takadmin@[YOUR_VPS_IP]

# Check containers started automatically
lxc list

# Should show both containers RUNNING

# Check TAK Server status
lxc exec tak -- systemctl status takserver
```

---

## Step 11: Optional Monitoring Setup

### 11.1 Install Monitoring Tools (Optional)

📦 **Inside TAK Container**

```bash
# Install htop for better process monitoring
apt install -y htop

# Monitor in real-time
htop

# Look for 'java' process (TAK Server)
```

### 11.2 Set Up External Monitoring (Optional)

**For production deployments, consider:**
- Uptime monitoring (UptimeRobot, Pingdom)
- Log aggregation (Papertrail, Loggly)
- Server monitoring (Datadog, New Relic)
- Discord/Slack webhooks for alerts

### 11.3 Simple Health Check Script

🖥️ **VPS Host**

Create the script:
```bash
nano check-tak-health.sh
```

Paste the following:
```bash
#!/bin/bash
# TAK Server Health Check Script

echo "=== TAK Server Health Check ==="
echo "Time: $(date)"

# Check container running
if lxc list | grep -q "tak.*RUNNING"; then
    echo "✅ TAK container: RUNNING"
else
    echo "❌ TAK container: NOT RUNNING"
    lxc start tak
fi

# Check TAK Server service
if lxc exec tak -- systemctl is-active takserver &>/dev/null; then
    echo "✅ TAK Server: RUNNING"
else
    echo "❌ TAK Server: NOT RUNNING"
    lxc exec tak -- systemctl restart takserver
fi

# Check PostgreSQL
if lxc exec tak -- systemctl is-active postgresql &>/dev/null; then
    echo "✅ PostgreSQL: RUNNING"
else
    echo "❌ PostgreSQL: NOT RUNNING"
    lxc exec tak -- systemctl restart postgresql
fi

# Check port listening
if lxc exec tak -- netstat -tln | grep -q ":8089"; then
    echo "✅ Port 8089: LISTENING"
else
    echo "❌ Port 8089: NOT LISTENING"
fi

# Check disk space
DISK_USAGE=$(lxc exec tak -- df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk usage: ${DISK_USAGE}%"
else
    echo "⚠️  Disk usage: ${DISK_USAGE}% (high)"
fi

# Check memory
MEM_USAGE=$(lxc exec tak -- free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
echo "📊 Memory usage: ${MEM_USAGE}%"

echo "=== Health Check Complete ==="
```

Save and exit (Ctrl+X, Y, Enter), then run:
```bash
chmod +x check-tak-health.sh
./check-tak-health.sh
```

**Add to cron (optional):**
```bash
# Run every hour
crontab -e

# Add line:
0 * * * * /home/takadmin/check-tak-health.sh >> /home/takadmin/tak-health.log 2>&1
```

---

## Step 12: Final Verification

### 12.1 Complete System Test

🖥️ **VPS Host**

1. **Reboot entire VPS:**
   ```bash
   sudo reboot
   ```

2. **Wait 3 minutes, then reconnect:**
   ```bash
   ssh takadmin@[YOUR_VPS_IP]
   ```

3. **Verify everything auto-started:**
   ```bash
   lxc list
   lxc exec tak -- systemctl status takserver
   lxc exec tak -- systemctl status postgresql
   ```

4. **Test client connections:**
   - ATAK should reconnect automatically
   - WinTAK should reconnect automatically
   - Web UI should be accessible

### 12.2 Run All Verification Scripts

🖥️ **VPS Host**

```bash
# Phase 1 verification
./verify-lxd.sh

# Phase 2 verification (if created)
./verify-container.sh

# Phase 5 verification
./verify-networking.sh

# Health check
./check-tak-health.sh
```

**All checks should pass! ✅**

---

## Troubleshooting

### Issue: ATAK won't connect after reboot

**Check in order:**

1. **Container running?**
   ```bash
   lxc list
   ```

2. **TAK Server running?**
   ```bash
   lxc exec tak -- systemctl status takserver
   ```

3. **Network accessible?**
   ```bash
   openssl s_client -connect [YOUR_DOMAIN]:8089
   ```

4. **ATAK certificate valid?**
   - Check certificate expiration
   - Re-enroll if needed

### Issue: Clients can see server but can't see each other

**Check groups/channels:**
1. Web UI → User Manager
2. Verify users are in same group
3. Check CoreConfig.xml for group settings

### Issue: Poor performance with multiple clients

📦 **Inside TAK Container**

**Increase Java heap size:**
```bash
nano /opt/tak/setenv.sh

# Increase -Xmx value:
export JAVA_OPTS="-Xmx4096m"  # 4GB (adjust based on VPS RAM)

# Restart TAK Server
systemctl restart takserver
```

---

## Success Criteria

Your deployment is successful when:

- ✅ TAK Server survives VPS reboot
- ✅ Multiple clients can connect simultaneously
- ✅ Clients can share data (markers, chat, files)
- ✅ Web UI is accessible and functional
- ✅ Certificate enrollment works
- ✅ Performance is acceptable (no lag, no drops)
- ✅ Backups are created and stored safely
- ✅ Documentation is complete

---

## Next Steps

### For Production Use:

1. **User Training:**
   - Create ATAK user guides
   - Schedule training sessions
   - Document common issues

2. **Operational Procedures:**
   - Establish backup schedule
   - Define maintenance windows
   - Create incident response plan

3. **Monitoring:**
   - Set up uptime monitoring
   - Configure alert notifications
   - Review logs regularly

4. **Scaling:**
   - Monitor user growth
   - Plan capacity increases
   - Consider federation with other servers

### For Continued Learning:

- **TAK Product Center:** https://tak.gov
- **TAK Syndicate:** https://www.thetaksyndicate.org/
- **CivTAK:** https://civtak.org

---

## Deployment Complete! 🎉

**Congratulations!** You now have a fully functional TAK Server deployment running in LXD containers.

### Your Infrastructure:
- ✅ Ubuntu VPS with LXD
- ✅ TAK Server 5.5 in container
- ✅ Certificate infrastructure
- ✅ Network connectivity (HAProxy or LXD proxy)
- ✅ Client access (ATAK/WinTAK)
- ✅ Production-ready configuration

### Share Your Success:
- Post in TAK Syndicate forums
- Contribute improvements back to this repo
- Help others in the community

---

*Last Updated: November 2025*  
*Deployment Status: Production Ready*
