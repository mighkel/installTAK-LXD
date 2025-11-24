# TAK Server Installation Guide

**Phase 3: Installing TAK Server using the installTAK script**

This guide assumes you've completed:
- [Phase 1: LXD Setup](01-LXD-SETUP.md) ✅
- [Phase 2: Container Setup](02-CONTAINER-SETUP.md) ✅

---

## Prerequisites

Before starting Phase 3, verify:

- [ ] TAK container is running with internet access
- [ ] takadmin user exists with sudo access
- [ ] Fresh snapshot created: `lxc snapshot tak fresh-setup`

**Critical: Have your passwords ready!**
- takadmin user password
- Certificate password (default: `atakatak` or your chosen password)

---

## Step 1: Obtain TAK Server Files

You need these files from [TAK.gov](https://tak.gov/products/tak-server):
- `takserver-5.5-RELEASE##_all.deb` (or latest version)
- `takserver-public-gpg.key`

### Method A: Google Drive + gdown (Recommended)

**Setup (one-time):**

1. **Upload TAK files to your Google Drive**
2. **Get shareable links:**
   - Right-click file → Share → Get Link
   - Change to "Anyone with the link"
   - Copy the link
3. **Extract the File ID** from the URL:
```
   https://drive.google.com/file/d/1ABC123xyz456DEF/view?usp=sharing
                                    ↑ This is your File ID ↑
```

**Download to container:**
```bash
# Get shell in container
lxc exec tak -- bash

# Switch to takadmin
su - takadmin

# Create working directory
mkdir -p ~/takserver-install
cd ~/takserver-install

# Download TAK Server (replace with your File ID)
gdown 1ABC123xyz456DEF -O takserver-5.5-RELEASE##_all.deb

# Download GPG key (replace with your File ID)
gdown 1XYZ789abc123GHI -O takserver-public-gpg.key

# Download Debian Policy file (replace with your File ID)
gdown 1XYZ789abc123GHI -O deb_policy.pol

# Optional: Download Federation Hub (replace with your File ID)
gdown 1XYZ789abc123GHI -O takserver-fed-hub_5.5-RELEASE##_all.deb

# Verify files downloaded
ls -lh
```

### Method B: Manual Transfer (Alternative)

**From your local machine:**
```bash
# Step 1: Copy files to VPS host
scp takserver-5.5-RELEASE.deb takadmin@your-vps-ip:~/
scp takserver-public-gpg.key takadmin@your-vps-ip:~/

# Step 2: From VPS, push to container
lxc file push ~/takserver-5.5-RELEASE.deb tak/home/takadmin/takserver-install/
lxc file push ~/takserver-public-gpg.key tak/home/takadmin/takserver-install/

# Step 3: Verify in container
lxc exec tak -- ls -lh /home/takadmin/takserver-install/
```

---

## Step 2: Clone installTAK Script

The installTAK script automates the TAK Server installation process.

### 2.1 Clone the Repository
```bash
# Inside container as takadmin
cd /home/takadmin/takserver-install

# Clone the installTAK-LXD repository
git clone https://github.com/mighkel/installTAK-LXD.git

# Enter scripts directory
cd installTAK-LXD/scripts

# Verify script is present
ls -lh installTAK-LXD-enhanced.sh

# Move install script to installTAK-LXD directory
cp installTAK-LXD-enhanced.sh ..
cd ..


```

### 2.2 Move TAK Files into installTAK Directory
```bash
# Move TAK Server files into installTAK directory
mv ../takserver-5.5-RELEASE##_all.deb .
mv ../takserver-public-gpg.key .

# Verify all required files are present
ls -lh

# Should show:
# - installTAK-LXD-enhanced (script)
# - takserver-5.5-RELEASE.deb
# - takserver-public-gpg.key
```

---

## Step 3: Run installTAK Script

**Important:** Read through the prompts section below BEFORE running the script!

### 3.1 Make Script Executable
```bash
# Make installTAK executable
chmod +x installTAK-LXD-enhanced.sh

# Verify permissions
ls -lh installTAK-LXD-enhanced.sh
```

### 3.2 Run the Installation
```bash
# Run installTAK with the .deb file
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE##_all.deb

# The script will start installing prerequisites
# This takes 5-10 minutes
```

---

## Step 4: Answer Installation Wizard Prompts

The installTAK script will ask several questions. Here's what to answer:

### 4.1 Certificate Organization Information
```
Enter your State (e.g., California): 
→ Idaho

Enter your City (e.g., San Francisco): 
→ Idaho City

Enter your Organizational Unit (e.g., IT Department): 
→ Communications

Enter your Organization (e.g., ACME Corp): 
→ Clear Creek VFD
```

**Note:** Use your actual organization info. These appear in certificates.

### 4.2 Certificate Password
```
The default certificate password is 'atakatak'. 
Do you want to change it? (y/n): 
→ n  (or y if you want a custom password)

If you chose 'y':
Enter your new certificate password: 
→ [enter your chosen password]
Confirm your new certificate password: 
→ [enter same password again]
```

**CRITICAL:** Write this password down! You'll need it for:
- Importing certificates into ATAK/WinTAK
- Accessing TAK web UI
- Certificate management

### 4.3 Certificate Authority Names
```
Enter your Root Certificate Authority (CA) name 
(or press Enter to generate a random name): 
→ [Enter your name, e.g., CCVFD-ROOT-CA]

Enter your Intermediate Certificate Authority (CA) name 
(or press Enter to generate a random name): 
→ [Enter your name, e.g., CCVFD-INTERMEDIATE-CA]
```

**Tip:** Use descriptive names that match your organization.

### 4.4 Certificate Enrollment
```
Do you want to enable Certificate Enrollment? (y/n): 
→ y

This will open TCP port 8446 for certificate enrollment.
Continue? (y/n): 
→ y
```

**What this does:** Allows ATAK clients to request certificates automatically.

### 4.5 TAK Federation
```
Do you want to enable TAK Server Federation? (y/n): 
→ n  (unless you're federating with other TAK Servers)
```

**Note:** Federation connects multiple TAK Servers. Not needed for single-server deployments.

### 4.6 Connection Protocol
```
Select connection protocol:
1) SSL/TLS (default)
2) QUIC (experimental)

Enter your choice (1 or 2): 
→ 1  (SSL/TLS)
```

**Stick with SSL/TLS** - QUIC support is experimental.

### 4.7 Certificate Enrollment Features
```
Which features do you want to enable for certificate enrollment?
- Certificate requests only
- WebTAK access
- Both

Enter your choice: 
→ Certificate requests only  (simplest and most secure)
```

### 4.8 FQDN Configuration
```
Does this TAK Server have a Fully Qualified Domain Name (FQDN)? (y/n): 
→ y

Enter the FQDN for this TAK Server: 
→ tak.pinenut.tech  (use your actual domain)
```

**Important:** This must match your DNS record!

### 4.9 Certificate Trust Method
```
How will this TAK Server be trusted?
1) Local (self-signed)
2) Let's Encrypt (public CA)

Enter your choice (1 or 2): 
→ 1  (for now - Let's Encrypt comes in Phase 5)
```

**Why Local for now:** We'll set up Let's Encrypt in the networking phase after confirming basic connectivity works.

### 4.10 IP Address Confirmation
```
TAK Server IP Address detected: 10.206.248.11
Is this correct? (y/n): 
→ y
```

This is the container's internal IP - that's correct.

### 4.11 Final Confirmation
```
Review your configuration:

Organization: Clear Creek VFD
City: Idaho City
State: Idaho
Domain: tak.pinenut.tech
Certificate Password: atakatak
Enrollment: Enabled

Is this correct? (y/n): 
→ y
```

**Review carefully!** Once confirmed, installation proceeds.

---

## Step 5: Installation Process

### 5.1 Watch the Installation

The script will now:
1. Install TAK Server package ✅
2. Configure PostgreSQL database ✅
3. Generate certificates ✅
4. Configure CoreConfig.xml ✅
5. Start TAK Server ✅

**This takes 5-10 minutes.** Watch for any errors.

### 5.2 Installation Complete

When finished, you'll see:
```
TAK Server installation complete!

Important files created:
- /root/admin.p12 (admin certificate)
- /root/webadmin.p12 (web UI certificate)
- /root/enrollmentDP.zip (enrollment package for ATAK)

TAK Server is running on:
- Port 8089 (ATAK/WinTAK/iTAK connections)
- Port 8443 (Web UI)
- Port 8446 (Certificate enrollment)
```

---

## Step 6: Verify TAK Server Installation

### 6.1 Check TAK Server Status
```bash
# Check if TAK Server is running
sudo systemctl status takserver

# Expected output: active (running)
```

**If not running:**
```bash
# Check logs for errors
sudo journalctl -u takserver -n 50

# Try starting manually
sudo systemctl start takserver
```

### 6.2 Verify PostgreSQL Database
```bash
# Switch to postgres user
sudo su - postgres

# Connect to TAK database
psql -d cot

# List tables (should show TAK Server tables)
\dt

# Exit
\q
exit
```

### 6.3 Check TAK Server Ports
```bash
# Verify TAK Server is listening on required ports
sudo netstat -tlnp | grep java

# Expected output showing:
# 8089 - TAK client connections
# 8443 - Web UI
# 8446 - Certificate enrollment
```

**Example output:**
```
tcp6  0  0 :::8089  :::*  LISTEN  12345/java
tcp6  0  0 :::8443  :::*  LISTEN  12345/java
tcp6  0  0 :::8446  :::*  LISTEN  12345/java
```

### 6.4 Test SSL Certificate
```bash
# Test SSL handshake on port 8089
openssl s_client -connect localhost:8089 -showcerts

# Press Ctrl+C after seeing certificate info

# Look for:
# - subject=CN=tak.pinenut.tech (your domain)
# - issuer=CN=CCVFD-INTERMEDIATE-CA (your intermediate CA)
```

---

## Step 7: Locate Important Files

### 7.1 Certificate Files Location
```bash
# Certificate files are in:
cd /opt/tak/certs/files

# List certificate files
ls -lh

# Important files:
# - admin.p12           - Admin certificate for TAK Server management
# - webadmin.p12        - Web UI access certificate
# - tak.jks             - Server keystore (Java)
# - truststore.jks      - Client trust store
# - [username].p12      - Client certificates (if created)
```

### 7.2 Enrollment Package
```bash
# Enrollment package for ATAK clients
ls -lh /root/enrollmentDP.zip

# This file will be distributed to ATAK users
```

### 7.3 Configuration Files
```bash
# Main TAK Server configuration
cat /opt/tak/CoreConfig.xml

# Database configuration
cat /opt/tak/CoreConfig.xml | grep -A 5 "<connection>"

# Certificate configuration
cat /opt/tak/CoreConfig.xml | grep -A 10 "<tls>"
```

---

## Step 8: Copy Certificates to Host

**Important:** You need to copy certificates out of the container for distribution to clients.

### 8.1 Copy Enrollment Package to Host
```bash
# From the VPS host (NOT in container), run:
lxc file pull tak/root/enrollmentDP.zip ~/enrollmentDP.zip

# Verify
ls -lh ~/enrollmentDP.zip
```

### 8.2 Copy Web Admin Certificate
```bash
# Copy webadmin.p12 to host
lxc file pull tak/root/webadmin.p12 ~/webadmin.p12

# This certificate is needed to access TAK Server web UI
```

### 8.3 Copy to Your Local Machine
```bash
# From your local machine (Windows/Mac/Linux)
scp takadmin@your-vps-ip:~/enrollmentDP.zip ./
scp takadmin@your-vps-ip:~/webadmin.p12 ./
```

---

## Step 9: Create Post-Install Snapshot

**Now that TAK Server is installed, create another snapshot!**
```bash
# Exit container
exit

# From VPS host, create snapshot
lxc snapshot tak tak-installed

# List snapshots
lxc info tak | grep -A 10 Snapshots

# Should show:
# - fresh-setup (pre-installation)
# - tak-installed (post-installation)
```

---

## Step 10: CRITICAL - Restart TAK Server

**This is the most commonly missed step!**

After installation completes, **ALWAYS restart TAK Server** to ensure all configurations are loaded:
```bash
# In the container
sudo systemctl restart takserver

# Wait 30 seconds for full restart
sleep 30

# Verify it's running
sudo systemctl status takserver

# Check logs for any errors
sudo journalctl -u takserver -n 50
```

**Why this matters:** Certificate changes, config updates, and initial installation often don't fully apply until restart.

---

## Step 11: Verification Checklist

Before moving to Phase 4, verify all these:

**Installation Status:**
- [ ] `systemctl status takserver` shows "active (running)"
- [ ] No errors in `journalctl -u takserver`
- [ ] PostgreSQL database contains TAK tables
- [ ] Ports 8089, 8443, 8446 are listening

**Certificate Files:**
- [ ] `/opt/tak/certs/files/admin.p12` exists
- [ ] `/root/webadmin.p12` exists
- [ ] `/root/enrollmentDP.zip` exists
- [ ] Certificates copied to VPS host
- [ ] Certificate password documented

**SSL/TLS:**
- [ ] `openssl s_client -connect localhost:8089` succeeds
- [ ] Certificate subject matches your FQDN
- [ ] Certificate chain is valid

**Snapshots:**
- [ ] Snapshot `tak-installed` created
- [ ] Can list snapshots with `lxc info tak`

### Quick Verification Script

Save as `verify-tak-install.sh` on VPS host:
```bash
#!/bin/bash
echo "=== TAK Server Installation Verification ==="

echo -n "TAK Server running: "
lxc exec tak -- systemctl is-active takserver &>/dev/null && echo "✅" || echo "❌"

echo -n "Port 8089 listening: "
lxc exec tak -- netstat -tln | grep -q ":8089" && echo "✅" || echo "❌"

echo -n "Port 8443 listening: "
lxc exec tak -- netstat -tln | grep -q ":8443" && echo "✅" || echo "❌"

echo -n "Port 8446 listening: "
lxc exec tak -- netstat -tln | grep -q ":8446" && echo "✅" || echo "❌"

echo -n "PostgreSQL running: "
lxc exec tak -- systemctl is-active postgresql &>/dev/null && echo "✅" || echo "❌"

echo -n "Enrollment package exists: "
lxc exec tak -- test -f /root/enrollmentDP.zip && echo "✅" || echo "❌"

echo -n "Webadmin cert exists: "
lxc exec tak -- test -f /root/webadmin.p12 && echo "✅" || echo "❌"

echo -n "Certs copied to host: "
test -f ~/enrollmentDP.zip && echo "✅" || echo "❌"

echo -n "Post-install snapshot: "
lxc info tak | grep -q "tak-installed" && echo "✅" || echo "❌"

echo ""
echo "If all checks show ✅, proceed to Phase 4: Certificate Management"
```

**Run it:**
```bash
chmod +x verify-tak-install.sh
./verify-tak-install.sh
```

---

## Troubleshooting

### Issue: TAK Server won't start

**Check the logs:**
```bash
sudo journalctl -u takserver -n 100 --no-pager

# Look for common issues:
# - PostgreSQL connection errors
# - Java version mismatch
# - Certificate errors
# - Port conflicts
```

**Common fixes:**
```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Restart TAK Server
sudo systemctl restart takserver

# Check Java version
java -version  # Must be 17.x
```

### Issue: Ports not listening

**Check if TAK Server is actually running:**
```bash
ps aux | grep takserver

# If not running, check why:
sudo journalctl -u takserver -n 50
```

**Check port bindings:**
```bash
sudo netstat -tlnp | grep -E "8089|8443|8446"
```

### Issue: PostgreSQL errors

**Verify PostgreSQL is running:**
```bash
sudo systemctl status postgresql

# If not running:
sudo systemctl start postgresql
```

**Check if TAK database exists:**
```bash
sudo su - postgres
psql -l | grep cot
exit
```

### Issue: SSL certificate errors

**Regenerate certificates:**
```bash
cd /opt/tak/certs
sudo ./makeRootCa.sh
sudo ./makeCert.sh server tak.pinenut.tech

# CRITICAL: Restart TAK Server after cert changes!
sudo systemctl restart takserver
```

### Issue: Can't find enrollment package

**Enrollment package location:**
```bash
# Check these locations:
ls -lh /root/enrollmentDP.zip
ls -lh /home/takadmin/enrollmentDP.zip
ls -lh /opt/tak/certs/files/enrollmentDP.zip

# If missing, regenerate:
cd /opt/tak/certs
sudo ./makeEnrollmentPackage.sh
```

### Issue: Installation script failed midway

**Restore from snapshot and try again:**
```bash
# Exit container
exit

# Stop container
lxc stop tak

# Restore fresh-setup snapshot
lxc restore tak fresh-setup

# Start container
lxc start tak

# Wait a minute, then reconnect
lxc exec tak -- bash

# Try installation again with fixes applied
```

---

## Important Notes

### Certificate Password Default

The default certificate password is `atakatak`. If you didn't change it during installation, that's what you'll use for:
- Importing certificates into ATAK/WinTAK
- Accessing web UI
- Certificate management

**For production, you should change this!**

### File Ownership

Most TAK Server files are owned by `root`. This is normal. Don't change ownership unless you know what you're doing.

### Port Security

Right now, TAK Server ports are only accessible from within the container. In Phase 5, we'll expose them properly through the firewall and reverse proxy.

### Database Backups

Consider setting up automated PostgreSQL backups:
```bash
# Example backup script (run as postgres user)
pg_dump cot > /tmp/tak-backup-$(date +%Y%m%d).sql
```

---

## What's Installed?

After installTAK completes, you have:

1. **TAK Server 5.5** - Running as systemd service
2. **PostgreSQL 15** - Database backend
3. **Certificate Authority** - Root and Intermediate CAs
4. **Server Certificate** - For tak.pinenut.tech
5. **Admin Certificates** - For web UI access
6. **Enrollment Package** - For ATAK client provisioning

---

## Next Steps

Once all verification checks pass:

**➡️ Proceed to:** [Phase 4: Certificate Management](04-CERTIFICATE-MANAGEMENT.md)

This next guide covers:
- Understanding TAK Server certificate architecture
- Creating client certificates manually
- Managing certificate revocation
- Certificate renewal procedures
- Troubleshooting certificate issues

---

## Additional Resources

- **installTAK Repository:** https://github.com/myTeckNet/installTAK
- **TAK Server Documentation:** https://tak.gov/docs
- **myTeckNet TAK Guides:** https://mytecknet.com/tag/tak/
- **TAK Syndicate Forums:** https://tak.gov/community

---

*Last Updated: November 2025*  
*Tested on: TAK Server 5.5*  
*Ubuntu 22.04 LTS, 24.04 LTS*
