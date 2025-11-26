# TAK Server Installation Guide

**Phase 3: Installing TAK Server using the installTAK script**

This guide assumes you've completed:
- [Phase 1: LXD Setup](01-LXD-SETUP.md) ✅
- [Phase 2: Container Setup](02-CONTAINER-SETUP.md) ✅

---

## Document Conventions

See [Phase 1: LXD Setup](01-LXD-SETUP.md#document-conventions) for the full conventions guide.

**Quick Reference:**
| Symbol | Meaning |
|--------|---------|
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside containers) |
| 📦 | **Inside Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - Replace placeholder values |

**Where Am I? (Check Your Prompt)**
| Prompt Looks Like | You Are |
|-------------------|---------|
| `takadmin@your-vps:~$` | 🖥️ VPS Host |
| `root@tak:~#` | 📦 Inside container (as root) |
| `takadmin@tak:~$` | 📦 Inside container (as takadmin) |

**Placeholders used in this document:**
- `[YOUR_DOMAIN]` - Your TAK server FQDN (e.g., `tak.example.com`)
- `[YOUR_ORG]` - Your organization name (e.g., `Example Fire Dept`)
- `[YOUR_STATE]` - Your state/province (e.g., `Colorado`)
- `[YOUR_CITY]` - Your city (e.g., `Denver`)
- `[YOUR_UNIT]` - Your organizational unit (e.g., `Communications`)
- `[YOUR_CA_NAME]` - Root CA name (e.g., `YOURORG-ROOT-CA`)
- `[##]` - TAK Server release number (e.g., `58`)
- `[CONTAINER_IP]` - Container's internal IP from `lxc list`

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_DOMAIN]` becomes `tak.example.com`
> (Keep any surrounding quotes, remove the brackets)

---

## Prerequisites

Before starting Phase 3, verify:

- [ ] TAK container is running with internet access
- [ ] takadmin user exists with sudo access
- [ ] Fresh snapshot created: `lxc snapshot tak fresh-setup`

> ⛔ **CRITICAL: Have your information ready!**
> - takadmin user password
> - Your organization details (for certificates)
> - Your domain name (FQDN)
> - Certificate password (default: `atakatak` or choose your own)

---

## Step 1: Obtain TAK Server Files

You need these files from [TAK.gov](https://tak.gov/products/tak-server):
- `takserver-5.5-RELEASE[##]_all.deb` (or latest version)
- `takserver-public-gpg.key`
- `deb_policy.pol` (security policy file)

> ⚠️ **TAK SERVER FILE NAMING**
> TAK Server files include a release number that changes with each build:
> ```
> takserver-5.5-RELEASE[##]_all.deb
>                      ^^^
>                      Release number (e.g., 58, 59, 60...)
> ```
> **Use the EXACT filename you downloaded.** File names are case-sensitive.
>
> 💡 **NOTE:** The 5.5 release used `-` before the version (`takserver-5.5-...`) which may differ from other versions. Always verify your actual filename.

### Method A: Google Drive + gdown (Recommended)

📦 **Inside Container** (as takadmin)

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

# Download TAK Server (replace FILE_ID with your actual ID)
gdown 1ABC123xyz456DEF -O takserver-5.5-RELEASE[##]_all.deb

# Download GPG key (replace FILE_ID with your actual ID)
gdown 1XYZ789abc123GHI -O takserver-public-gpg.key

# Download policy file (replace FILE_ID with your actual ID)
gdown 1JKL456mno789PQR -O deb_policy.pol

# Verify files downloaded
ls -lh
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> - Replace each `1ABC...` file ID with your actual Google Drive file IDs
> - Replace `[##]` with your actual release number (e.g., `58`)

> 💡 **SECURITY TIP**
> After downloading, go back to Google Drive and **remove sharing** (set files back to "Restricted"). TAK Server files should not remain publicly accessible.

### Method B: Manual Transfer (Alternative)

💻 **Local Machine** → 🖥️ **VPS Host** → 📦 **Container**

```bash
# Step 1: From local machine, copy files to VPS host
scp takserver-5.5-RELEASE[##]_all.deb takadmin@[YOUR_VPS_IP]:~/
scp takserver-public-gpg.key takadmin@[YOUR_VPS_IP]:~/
scp deb_policy.pol takadmin@[YOUR_VPS_IP]:~/

# Step 2: From VPS host, push to container
lxc file push ~/takserver-5.5-RELEASE[##]_all.deb tak/home/takadmin/takserver-install/
lxc file push ~/takserver-public-gpg.key tak/home/takadmin/takserver-install/
lxc file push ~/deb_policy.pol tak/home/takadmin/takserver-install/

# Step 3: Verify in container
lxc exec tak -- ls -lh /home/takadmin/takserver-install/
```

---

## Step 2: Clone installTAK Script

The installTAK script automates the TAK Server installation process.

📦 **Inside Container** (as takadmin)

### 2.1 Clone the Repository

```bash
cd /home/takadmin/takserver-install

# Clone the installTAK repository
git clone https://github.com/myTeckNet/installTAK.git

# Enter directory
cd installTAK

# Verify script is present
ls -lh installTAK
```

### 2.2 Move TAK Files into installTAK Directory

```bash
# Move TAK Server files into installTAK directory
mv ../takserver-5.5-RELEASE[##]_all.deb .
mv ../takserver-public-gpg.key .
mv ../deb_policy.pol .

# Verify all required files are present
ls -lh

# Should show:
# - installTAK (script)
# - takserver-5.5-RELEASE[##]_all.deb
# - takserver-public-gpg.key
# - deb_policy.pol
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[##]` with your actual release number in the mv command.

---

## Step 3: Run installTAK Script

> ⛔ **IMPORTANT: Read Step 4 BEFORE running the script!**
> Step 4 explains all the prompts you'll encounter. Review it first so you know what to enter.

📦 **Inside Container** (as takadmin)

### 3.1 Make Script Executable

```bash
# Make installTAK executable
chmod +x installTAK

# Verify permissions
ls -lh installTAK
```

### 3.2 Run the Installation

```bash
# Run installTAK with the .deb file
sudo ./installTAK takserver-5.5-RELEASE[##]_all.deb

# The script will start installing prerequisites
# This takes 5-10 minutes
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[##]` with your actual release number.

---

## Step 4: Answer Installation Wizard Prompts

The installTAK script will ask several questions. Here's what to answer:

### 4.1 Certificate Organization Information

```
Enter your State (e.g., California): 
→ [YOUR_STATE]

Enter your City (e.g., San Francisco): 
→ [YOUR_CITY]

Enter your Organizational Unit (e.g., IT Department): 
→ [YOUR_UNIT]

Enter your Organization (e.g., ACME Corp): 
→ [YOUR_ORG]
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Enter YOUR actual organization information. These appear in certificates.
> 
> **Example:**
> - State: `Colorado`
> - City: `Denver`
> - Organizational Unit: `Communications`
> - Organization: `Mountain View Fire Dept`

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

> ⛔ **CRITICAL: DOCUMENT THIS PASSWORD!**
> You'll need it for:
> - Importing certificates into ATAK/WinTAK
> - Accessing TAK web UI
> - Certificate management
>
> Store it in your password manager now.

### 4.3 Certificate Authority Names

```
Enter your Root Certificate Authority (CA) name 
(or press Enter to generate a random name): 
→ [YOUR_CA_NAME]-ROOT-CA

Enter your Intermediate Certificate Authority (CA) name 
(or press Enter to generate a random name): 
→ [YOUR_CA_NAME]-INTERMEDIATE-CA
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Use descriptive names that match your organization.
> 
> **Example:**
> - Root CA: `MVFD-ROOT-CA`
> - Intermediate CA: `MVFD-INTERMEDIATE-CA`
>
> 💡 **TIP:** Use a short abbreviation of your organization (e.g., MVFD for Mountain View Fire Dept).

### 4.4 Certificate Enrollment

```
Do you want to enable Certificate Enrollment? (y/n): 
→ y

This will open TCP port 8446 for certificate enrollment.
Continue? (y/n): 
→ y
```

**What this does:** Allows ATAK clients to request certificates automatically instead of manually distributing .p12 files.

### 4.5 TAK Federation

```
Do you want to enable TAK Server Federation? (y/n): 
→ n  (unless you're federating with other TAK Servers)
```

> 💡 **NOTE:** Federation connects multiple TAK Servers together. Not needed for single-server deployments. You can enable this later if needed.

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
→ [YOUR_DOMAIN]
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Enter YOUR actual domain name (e.g., `tak.example.com`).
> 
> **This must match your DNS record!** If you haven't set up DNS yet, use the domain you plan to use.

### 4.9 Certificate Trust Method

```
How will this TAK Server be trusted?
1) Local (self-signed)
2) Let's Encrypt (public CA)

Enter your choice (1 or 2): 
→ 1  (for now - Let's Encrypt comes in Phase 5)
```

> 💡 **WHY LOCAL FOR NOW?**
> We'll set up Let's Encrypt in Phase 5 after confirming basic connectivity works. Self-signed certificates work perfectly for TAK clients (ATAK/WinTAK).

### 4.10 IP Address Confirmation

```
TAK Server IP Address detected: [CONTAINER_IP]
Is this correct? (y/n): 
→ y
```

This is the container's internal IP - that's correct. External access is configured in Phase 5.

### 4.11 Final Confirmation

```
Review your configuration:

Organization: [YOUR_ORG]
City: [YOUR_CITY]
State: [YOUR_STATE]
Domain: [YOUR_DOMAIN]
Certificate Password: atakatak
Enrollment: Enabled

Is this correct? (y/n): 
→ y
```

**Review carefully!** Once confirmed, installation proceeds.

> 💡 **PASSWORD RECOMMENDATION**
> If you kept the default password `atakatak`, consider changing it for production use. See [Important Notes: Certificate Password Default](#certificate-password-default) below for details.

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

📦 **Inside Container**

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
# - subject=CN=[YOUR_DOMAIN]
# - issuer=CN=[YOUR_CA_NAME]-INTERMEDIATE-CA
```

---

## Step 7: Locate Important Files

📦 **Inside Container**

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

# View database configuration
cat /opt/tak/CoreConfig.xml | grep -A 5 "<connection>"

# View certificate configuration
cat /opt/tak/CoreConfig.xml | grep -A 10 "<tls>"
```

---

## Step 8: Copy Certificates to Host

> ⛔ **IMPORTANT**
> You need to copy certificates out of the container for distribution to clients.

🖥️ **VPS Host** (exit container first - may need `exit` twice)

### 8.1 Verify You're on VPS Host

```bash
hostname
# Should output your VPS hostname, NOT 'tak'
```

### 8.2 Copy Enrollment Package to Host

```bash
lxc file pull tak/root/enrollmentDP.zip ~/enrollmentDP.zip

# Verify
ls -lh ~/enrollmentDP.zip
```

### 8.3 Copy Web Admin Certificate

```bash
# Copy webadmin.p12 to host
lxc file pull tak/root/webadmin.p12 ~/webadmin.p12

# This certificate is needed to access TAK Server web UI
```

### 8.4 Copy to Your Local Machine

💻 **Local Machine**

```bash
# From your local machine (not VPS)
scp takadmin@[YOUR_VPS_IP]:~/enrollmentDP.zip ./
scp takadmin@[YOUR_VPS_IP]:~/webadmin.p12 ./
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[YOUR_VPS_IP]` with your actual VPS IP address.

---

## Step 9: Create Post-Install Snapshot

🖥️ **VPS Host**

**Now that TAK Server is installed, create another snapshot!**

```bash
# Create snapshot
lxc snapshot tak tak-installed

# List snapshots
lxc info tak | grep -A 10 Snapshots

# Should show:
# - fresh-setup (pre-installation)
# - tak-installed (post-installation)
```

---

## Step 10: CRITICAL - Restart TAK Server

> ⛔ **This is the most commonly missed step!**

After installation completes, **ALWAYS restart TAK Server** to ensure all configurations are loaded:

📦 **Inside Container**

```bash
# Get back into container
lxc exec tak -- bash

# Restart TAK Server
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
- [ ] Certificate chain shows your CA names

**Snapshots:**
- [ ] Snapshot `tak-installed` created

### Quick Verification Script

🖥️ **VPS Host**

Create the script:
```bash
nano verify-tak-install.sh
```

Paste the following:
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

Save and exit (Ctrl+X, Y, Enter), then run:
```bash
chmod +x verify-tak-install.sh
./verify-tak-install.sh
```

---

## Troubleshooting

### Issue: TAK Server won't start

📦 **Inside Container**

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

```bash
# Check if TAK Server is actually running
ps aux | grep takserver

# If not running, check why:
sudo journalctl -u takserver -n 50
```

### Issue: PostgreSQL errors

```bash
# Verify PostgreSQL is running
sudo systemctl status postgresql

# If not running:
sudo systemctl start postgresql

# Check if TAK database exists
sudo su - postgres
psql -l | grep cot
exit
```

### Issue: SSL certificate errors

```bash
# Regenerate certificates
cd /opt/tak/certs
sudo ./makeRootCa.sh
sudo ./makeCert.sh server [YOUR_DOMAIN]

# CRITICAL: Restart TAK Server after cert changes!
sudo systemctl restart takserver
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[YOUR_DOMAIN]` with your actual domain.

### Issue: Can't find enrollment package

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

🖥️ **VPS Host**

**Restore from snapshot and try again:**
```bash
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

**For production, consider changing this!**

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
4. **Server Certificate** - For your domain
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
- **TAK Server Documentation:** https://tak.gov/products/tak-server
- **myTeckNet TAK Guides:** https://mytecknet.com/tag/tak/
- **TAK Syndicate:** https://www.thetaksyndicate.org/

---

*Last Updated: November 2025*  
*Tested on: TAK Server 5.5*  
*Ubuntu 22.04 LTS, 24.04 LTS*
