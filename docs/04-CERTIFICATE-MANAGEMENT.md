# Certificate Management Guide

**Phase 4: Understanding and managing TAK Server certificates**

This guide covers TAK Server's certificate architecture, client certificate creation, certificate lifecycle management, and multi-device user handling.

**Deployment Context:** This guide is written for TAK Server running in an LXD container. Commands show both container and host operations.

---

## Prerequisites

Before starting Phase 4, verify:

- [ ] TAK Server is installed and running in LXD container
- [ ] Can access container: `lxc exec tak -- bash`
- [ ] installTAK script completed successfully
- [ ] Certificate files exist in `/opt/tak/certs/files/`
- [ ] Certificate password is documented
- [ ] Snapshot created: `lxc snapshot tak tak-installed`

---

## Understanding TAK Certificate Architecture

### Certificate Hierarchy

TAK Server uses a three-tier certificate authority (CA) structure:
```
Root CA (CCVFD-ROOT-CA)
    ↓
Intermediate CA (CCVFD-INTERMEDIATE-CA)
    ↓
Server Certificate (tak.pinenut.tech)
    ↓
Client Certificates (CCFIRE780, CCFIRE780-wt, BCSO2240, etc.)
```

**Why this structure?**
- **Root CA**: Rarely used, kept secure/offline in production
- **Intermediate CA**: Signs day-to-day certificates
- **Server Certificate**: TAK Server's identity
- **Client Certificates**: Individual users/devices

### Certificate Types

**Server Certificates:**
- `tak.jks` or `[hostname].jks` - Server keystore (Java format)
- Used by TAK Server to identify itself to clients
- Contains: Private key + certificate + CA chain

**Client Certificates:**
- `admin.p12` - Admin user certificate
- `webadmin.p12` - Web UI access certificate
- `CCFIRE780.p12` - User's ATAK device
- `CCFIRE780-wt.p12` - Same user's WinTAK
- Used by ATAK/WinTAK/iTAK to authenticate to TAK Server

**Trust Stores:**
- `truststore-[CA-NAME].jks` - Contains root and intermediate CAs
- Clients use this to verify the server's certificate
- Server uses this to verify client certificates

---

## Step 1: Verify Certificate Files

### 1.1 Check Certificate Directory

**From VPS host:**
```bash
# Check certificate directory in container
lxc exec tak -- ls -lh /opt/tak/certs/files

# Or get shell in container
lxc exec tak -- bash

# Then navigate to cert directory
cd /opt/tak/certs/files
ls -lh
```

**You should see:**
```
admin.p12                           - Admin certificate
webadmin.p12                        - Web admin certificate
[hostname].jks                      - Server keystore
truststore-[CA-NAME].jks           - Trust store
ca.pem                             - Root CA certificate
ca-do-not-share.key                - Root CA private key (PROTECT THIS!)
[CA-NAME].pem                      - Intermediate CA certificate
[CA-NAME]-signing.jks              - Intermediate CA signing keystore
```

### 1.2 Inspect Server Certificate

**Inside container:**
```bash
cd /opt/tak/certs/files

# View server certificate details
keytool -list -v -keystore [hostname].jks -storepass atakatak | grep -A 5 "Owner:"

# Example with hostname "tak":
keytool -list -v -keystore tak.jks -storepass atakatak | grep -A 5 "Owner:"
```

**Expected output:**
```
Owner: CN=tak.pinenut.tech, OU=Communications, O=Clear Creek VFD, L=Idaho City, ST=Idaho, C=US
Issuer: CN=CCVFD-INTERMEDIATE-CA, OU=Communications, O=Clear Creek VFD...
```

**Verify:**
- CN (Common Name) matches your domain: `tak.pinenut.tech`
- Organization matches what you entered during installation
- Issuer is your Intermediate CA

### 1.3 Check Certificate Validity

**Inside container:**
```bash
# Check certificate expiration
keytool -list -v -keystore files/[hostname].jks -storepass atakatak | grep -A 2 "Valid"

# Example output:
# Valid from: Fri Nov 22 10:30:00 MST 2025 until: Sun Nov 22 10:30:00 MST 2027
```

---

## Step 2: Understanding Enrollment Packages

### 2.1 What is enrollmentDP.zip?

The enrollment package contains:
- `config.pref` - ATAK configuration (server connection details)
- `MANIFEST.xml` - Package metadata
- `caCert.p12` - CA trust store for verifying server

**What it does NOT contain:**
- Client certificate (generated during enrollment)
- Private keys (stay on device)
- User credentials (entered during enrollment)

### 2.2 Locate Enrollment Package

**From VPS host:**
```bash
# Check for enrollment package
lxc exec tak -- ls -lh /root/enrollmentDP*.zip
lxc exec tak -- ls -lh /home/takadmin/enrollmentDP*.zip

# View contents without extracting
lxc exec tak -- unzip -l /home/takadmin/enrollmentDP.zip
```

### 2.3 Copy Enrollment Package to Host

**From VPS host:**
```bash
# Copy from container to host
lxc file pull tak/home/takadmin/enrollmentDP.zip ~/enrollmentDP-$(date +%Y%m%d).zip

# Also copy QUIC version if you enabled QUIC
lxc file pull tak/home/takadmin/enrollmentDP-QUIC.zip ~/enrollmentDP-QUIC-$(date +%Y%m%d).zip

# Verify copies
ls -lh ~/enrollmentDP*.zip

# Download to your local machine (from local machine terminal)
scp takadmin@your-vps-ip:~/enrollmentDP-*.zip ./
```

---

## Step 3: User Naming Conventions and Multi-Device Support

### 3.1 Understanding the Challenge

**Problem:** Users often have multiple devices:
- ATAK on phone/tablet
- WinTAK on laptop
- iTAK on iPhone
- TAKAware on another device
- TAK-X for specialized ops

**TAK Server Requirement:** Each device needs its own unique certificate.

**Why?**
- Security: Revoke one device without affecting others
- Tracking: Know which device a user is on
- Troubleshooting: Identify connection issues by device
- Compliance: Audit trail per device

### 3.2 Recommended Naming Convention

**Base Username Format:**
```
[AGENCY][UNIT/RADIO]
```

**Examples:**
- `CCFIRE780` - Clear Creek Fire, Unit 780
- `BCSO2240` - Boise County Sheriff's Office, Unit 2240
- `IDACOM123` - Idaho Communications, ID 123

**Device-Specific Suffixes:**

| Device/Platform | Suffix | Example |
|----------------|--------|---------|
| **ATAK (Default)** | *(none)* | `CCFIRE780` |
| **WinTAK** | `-wt` | `CCFIRE780-wt` |
| **iTAK** | `-it` | `CCFIRE780-it` |
| **TAKAware** | `-ta` | `CCFIRE780-ta` |
| **TAK-X** | `-tx` | `CCFIRE780-tx` |
| **Backup Device** | `-bk` | `CCFIRE780-bk` |
| **Training Device** | `-tr` | `CCFIRE780-tr` |

**Real-World Examples:**

User: Fire Chief with 3 devices
- `CCFIRE780` - Primary ATAK on phone
- `CCFIRE780-wt` - WinTAK on command vehicle laptop
- `CCFIRE780-it` - iTAK on personal iPhone (backup)

User: Sheriff Deputy with 2 devices
- `BCSO2240` - ATAK on issued tablet
- `BCSO2240-wt` - WinTAK on patrol vehicle computer

### 3.3 Creating Multi-Device User Certificates

**Scenario:** User "CCFIRE780" needs WinTAK on their laptop in addition to ATAK on their phone.

**Step 1: Create Primary Certificate (Already Done During Setup)**
```bash
# Inside container
cd /opt/tak/certs

# Primary device (ATAK) - no suffix
sudo ./makeCert.sh client CCFIRE780
```

**Step 2: Create Additional Device Certificate**
```bash
# Additional device (WinTAK) - with suffix
sudo ./makeCert.sh client CCFIRE780-wt

# Certificates created:
# /opt/tak/certs/files/CCFIRE780.p12     (ATAK on phone)
# /opt/tak/certs/files/CCFIRE780-wt.p12  (WinTAK on laptop)
```

**Step 3: Copy Both Certificates to Host**
```bash
# Exit container
exit

# From VPS host, copy both certificates
lxc file pull tak/opt/tak/certs/files/CCFIRE780.p12 ~/CCFIRE780.p12
lxc file pull tak/opt/tak/certs/files/CCFIRE780-wt.p12 ~/CCFIRE780-wt.p12

# Download to your local machine for distribution
scp takadmin@your-vps-ip:~/CCFIRE780*.p12 ./
```

**Step 4: Distribute to User**
- Give `CCFIRE780.p12` for ATAK device
- Give `CCFIRE780-wt.p12` for WinTAK device
- Provide certificate password
- Include device-specific installation instructions

### 3.4 Managing Multi-Device Users

**TAK Server Web UI View:**

When you view users in the web UI, you'll see:
```
Username          | Connection Status | Device Type
------------------|-------------------|-------------
CCFIRE780         | Connected         | ATAK
CCFIRE780-wt      | Connected         | WinTAK
CCFIRE780-it      | Disconnected      | iTAK
BCSO2240          | Connected         | ATAK
```

**Mission Access:** 
- Each device is technically a separate "user" in TAK Server
- Add all device variations to appropriate groups for mission access
- Example: Add both `CCFIRE780` and `CCFIRE780-wt` to "Fire Ops" group

**Group Assignment Best Practice:**
```bash
# In TAK Server Web UI:
# Create a group for the actual person:
Group: "Fire Chief CCFIRE780 - All Devices"
Members:
  - CCFIRE780
  - CCFIRE780-wt
  - CCFIRE780-it

# Then add that group to operational groups:
Group: "Fire Operations"
Members:
  - Fire Chief CCFIRE780 - All Devices
  - [other users/groups]
```

### 3.5 Certificate Inventory Tracking

**Spreadsheet Template for Multi-Device Users:**

| User/Unit | Device | Certificate Name | Issued Date | Expires | Status | Notes |
|-----------|--------|------------------|-------------|---------|--------|-------|
| Fire Chief 780 | ATAK Phone | CCFIRE780 | 2025-01-15 | 2027-01-15 | Active | Primary |
| Fire Chief 780 | WinTAK Laptop | CCFIRE780-wt | 2025-01-20 | 2027-01-20 | Active | Command vehicle |
| Fire Chief 780 | iTAK iPhone | CCFIRE780-it | 2025-02-01 | 2027-02-01 | Active | Backup |
| Deputy 2240 | ATAK Tablet | BCSO2240 | 2025-01-10 | 2027-01-10 | Active | Patrol |
| Deputy 2240 | WinTAK Patrol Car | BCSO2240-wt | 2025-01-10 | 2027-01-10 | Active | Patrol vehicle |

**Benefits:**
- Know exactly what devices each person has
- Track renewal dates per device
- Identify which device had issues
- Revoke specific device without affecting others

### 3.6 Revoking a Single Device

**Scenario:** User lost their phone but still has laptop.

**Goal:** Revoke phone certificate, keep laptop working.

```bash
# Inside container
cd /opt/tak/certs

# Revoke ONLY the phone certificate
sudo ./makeCert.sh revoke CCFIRE780

# Laptop (CCFIRE780-wt) still works!

# Generate updated CRL
sudo ./makeCert.sh crl

# Restart TAK Server
sudo systemctl restart takserver
```

**Result:**
- ATAK on phone: ❌ Cannot connect (revoked)
- WinTAK on laptop: ✅ Still works (not revoked)
- User maintains situational awareness via laptop

**Later, issue new phone certificate:**
```bash
# Create new cert for replacement phone
sudo ./makeCert.sh client CCFIRE780

# Or if they want a backup phone too:
sudo ./makeCert.sh client CCFIRE780-bk
```

---

## Step 4: Creating Client Certificates Manually

### 4.1 Using makeCert.sh Script

**Inside container:**
```bash
# Get shell in container
lxc exec tak -- bash

# Navigate to certs directory
cd /opt/tak/certs

# Create a client certificate
sudo ./makeCert.sh client [username]

# Examples:
sudo ./makeCert.sh client CCFIRE780          # Primary ATAK
sudo ./makeCert.sh client CCFIRE780-wt       # WinTAK
sudo ./makeCert.sh client BCSO2240           # Sheriff deputy
sudo ./makeCert.sh client IDACOM123-tr       # Training device

# Certificate created at:
# /opt/tak/certs/files/[username].p12
```

### 4.2 Verify Client Certificate

**Inside container:**
```bash
# List the certificate details
keytool -list -v -keystore files/CCFIRE780.p12 -storepass atakatak

# Should show:
# Alias name: CCFIRE780
# Owner: CN=CCFIRE780, OU=Communications, O=Clear Creek VFD...
# Issuer: CN=CCVFD-INTERMEDIATE-CA...
```

### 4.3 Copy Client Certificate to Host

**Exit container and run from host:**
```bash
# Exit container if you're in it
exit

# From VPS host, copy certificate from container
lxc file pull tak/opt/tak/certs/files/CCFIRE780.p12 ~/CCFIRE780.p12

# Verify copy
ls -lh ~/CCFIRE780.p12

# Download to your local machine for distribution (from local machine)
scp takadmin@your-vps-ip:~/CCFIRE780.p12 ./
```

### 4.4 Secure Distribution Methods

**Option 1: Encrypted Cloud Storage** (Recommended for most)
1. Upload to NextCloud/Google Drive (private folder)
2. Share link with password protection
3. SMS password separately
4. User downloads and deletes

**Option 2: In-Person USB Transfer** (High Security)
1. Copy certificate to USB drive
2. Hand-deliver to user
3. Watch user import certificate
4. Securely delete from USB

**Option 3: Encrypted Email** (Acceptable)
1. Password-protect .p12 file (ZIP with password)
2. Email encrypted ZIP
3. Call/SMS password separately
4. Confirm receipt and import

**Never:**
- ❌ Post certificates on public websites
- ❌ Share via unencrypted channels
- ❌ Include password in same message as certificate
- ❌ Store on unencrypted network shares
- ❌ Send via SMS/text message

---

## Step 5: Certificate Installation on Clients

### 5.1 ATAK (Android)

**Method A: Using Enrollment Package (Recommended for New Users)**

1. Transfer `enrollmentDP.zip` to Android device
2. Open ATAK
3. Tap hamburger menu (≡) → Settings
4. Network → Certificate Enrollment
5. Tap "Import Config" → Select `enrollmentDP.zip`
6. Enter username: `CCFIRE780` (exact, case-sensitive)
7. Enter password (set in TAK Server web UI for this user)
8. Tap "Enroll"
9. Wait for certificate generation (~30 seconds)
10. ATAK connects automatically
11. Verify connection: Green "Connected" in status bar

**Method B: Using Manual Certificate (For Pre-Generated Certs)**

1. Transfer `CCFIRE780.p12` to Android device
2. Also transfer `truststore-[CA-NAME].p12` (from enrollment package)
3. Open ATAK
4. Tap hamburger menu (≡) → Settings
5. Network → Manage Server Connections
6. Tap "+" to add server
7. Enter:
   - Description: `CCVFD TAK Server`
   - Address: `tak.pinenut.tech`
   - Port: `8089`
   - Protocol: `SSL`
8. Tap "Manage SSL/TLS Certificates"
9. Under "Client Certificates":
   - Tap "Import"
   - Select `CCFIRE780.p12`
   - Enter password: `atakatak` (or your password)
10. Under "CA Certificates":
   - Tap "Import"
   - Select `truststore-[CA-NAME].p12`
   - Enter password: `atakatak`
11. Back out and save connection
12. Connection status should show green "Connected"

### 5.2 WinTAK (Windows)

1. Copy `CCFIRE780-wt.p12` and `truststore-[CA-NAME].p12` to Windows machine
2. Launch WinTAK
3. Click Settings (gear icon) → Network Preferences
4. Click "Manage Server Connections"
5. Add new connection:
   - Description: `CCVFD TAK Server`
   - Address: `tak.pinenut.tech:8089:ssl`
6. Under "Authentication":
   - Import Client Certificate: Browse to `CCFIRE780-wt.p12`
   - Enter password: `atakatak`
   - Import CA Certificate: Browse to `truststore-[CA-NAME].p12`
   - Enter password: `atakatak`
7. Click "Apply" or "OK"
8. Connection status should show "Connected" in green

### 5.3 iTAK (iOS)

Similar process to ATAK:
1. Transfer `CCFIRE780-it.p12` and truststore to iOS device
2. Open iTAK
3. Tap Settings → Servers → Add Server
4. Configure connection details
5. Import client certificate and CA certificate
6. Save and connect

---

## Step 6: CRITICAL - Restart After Certificate Changes

**This cannot be emphasized enough!**

### 6.1 When to Restart TAK Server

Restart TAK Server after ANY of these certificate operations:
- ✅ Creating new server certificate
- ✅ Regenerating CAs
- ✅ Updating truststore
- ✅ Changing certificate configuration in CoreConfig.xml
- ✅ Installing Let's Encrypt certificates (Phase 5)
- ✅ Revoking certificates
- ✅ Updating CRL

### 6.2 Proper Restart Procedure

**From VPS host:**
```bash
# Restart TAK Server
lxc exec tak -- systemctl restart takserver

# Wait for full restart (30 seconds minimum)
sleep 30

# Verify it's running
lxc exec tak -- systemctl status takserver

# Check for errors
lxc exec tak -- journalctl -u takserver -n 50 | grep -i error

# Verify ports listening
lxc exec tak -- ss -tulpn | grep -E "8089|8443|8446"
```

**Or from inside container:**
```bash
# If you're inside the container
sudo systemctl restart takserver

# Wait for restart
sleep 30

# Check status
sudo systemctl status takserver
ps aux | grep takserver | grep -v grep

# Watch logs for successful startup
tail -f /opt/tak/logs/takserver-messaging.log
# Look for: "Started TAK Server messaging Microservice"
```

### 6.3 Why This Matters

TAK Server loads certificates into memory at startup. Changes to certificate files are **not** picked up until restart. This is the #1 cause of "SSL handshake failure" issues.

**Certificate changes are NOT hot-reloadable.** Always restart after:
- Issuing new certificates
- Revoking certificates
- Updating CRLs
- Modifying certificate configuration

---

## Step 7: Client Certificate Renewal - Complete Guide

Certificates expire (typically 2 years). Renewal requires careful coordination with users.

### 7.1 CRITICAL: Use Same Username!

**Most Important Rule:** Always renew with the **same username** to preserve:
- ✅ Data Sync mission subscriptions
- ✅ Mission memberships
- ✅ User preferences and settings
- ✅ Group assignments
- ✅ Historical data association

**Example - Correct Renewal:**
```bash
# User had certificate: CCFIRE780.p12
# Create renewal with SAME name:
cd /opt/tak/certs
sudo ./makeCert.sh client CCFIRE780

# Result: User keeps all missions and data
```

**Example - WRONG (Never do this):**
```bash
# This creates a NEW user identity
sudo ./makeCert.sh client CCFIRE780-2025  ❌
# User will lose all mission subscriptions!
```

### 7.2 Administrator Renewal Process

**Step 1: Identify Certificates Needing Renewal**
```bash
# Inside container
cd /opt/tak/certs/files

# Check expiration dates for all certificates
for cert in *.p12; do
    echo "=== $cert ==="
    keytool -list -v -keystore "$cert" -storepass atakatak 2>/dev/null | grep "Valid"
    echo ""
done

# Or check a specific certificate
keytool -list -v -keystore CCFIRE780.p12 -storepass atakatak | grep "Valid"
```

**Step 2: Create New Certificate**
```bash
# Inside container
cd /opt/tak/certs

# Backup old certificate first
sudo cp files/CCFIRE780.p12 files/CCFIRE780.p12.backup-$(date +%Y%m%d)

# Generate new certificate with SAME username
sudo ./makeCert.sh client CCFIRE780

# New certificate overwrites old one at: files/CCFIRE780.p12
```

**Step 3: Restart TAK Server**
```bash
# CRITICAL: Restart to clear cached certificates
sudo systemctl restart takserver
sleep 30
```

**Step 4: Copy to Host for Distribution**
```bash
# Exit container
exit

# From VPS host, copy renewed certificate
lxc file pull tak/opt/tak/certs/files/CCFIRE780.p12 ~/CCFIRE780-renewed-$(date +%Y%m%d).p12

# Verify
ls -lh ~/CCFIRE780-renewed-*.p12

# Download to your local machine (from local machine)
scp takadmin@your-vps-ip:~/CCFIRE780-renewed-*.p12 ./
```

**Step 5: Distribute to User**

Send the user:
1. ✉️ New certificate file: `CCFIRE780.p12`
2. 🔑 Certificate password (usually unchanged: `atakatak`)
3. 📋 Renewal instructions: [CERTIFICATE-RENEWAL-USER-GUIDE.md](CERTIFICATE-RENEWAL-USER-GUIDE.md)
4. ⏰ Renewal deadline (at least 7 days notice)
5. ☎️ Support contact for assistance

**Email Template:**
```
Subject: TAK Certificate Renewal Required - CCFIRE780

Your TAK client certificate expires on [DATE].

ATTACHED:
- CCFIRE780.p12 (your new certificate)
- Password: atakatak
- Renewal instructions PDF

WHAT TO DO:
1. Choose a time when you're NOT on a mission
2. Follow the attached instructions to swap certificates
3. Process takes 2-3 minutes
4. Verify your missions still appear after reconnecting

IMPORTANT: Your mission subscriptions will be preserved.
Do NOT create a new connection - just replace the certificate.

DEADLINE: [7 days before expiration]

HELP: Contact dispatch/IT at [phone] if you have issues.
```

**Step 6: Verify User Reconnection**

After user renews:
1. Check TAK Server Web UI → User Manager
2. Find user: `CCFIRE780`
3. Verify "Connected" status
4. Check certificate serial number (should be different/new)
5. Confirm user can still access missions

### 7.3 Multi-Device User Renewal

**Scenario:** User has ATAK and WinTAK (CCFIRE780 and CCFIRE780-wt).

**Process: Renew Each Device Certificate Separately**

```bash
# Inside container
cd /opt/tak/certs

# Backup both old certificates
sudo cp files/CCFIRE780.p12 files/CCFIRE780.p12.backup-$(date +%Y%m%d)
sudo cp files/CCFIRE780-wt.p12 files/CCFIRE780-wt.p12.backup-$(date +%Y%m%d)

# Generate new certificates
sudo ./makeCert.sh client CCFIRE780        # ATAK device
sudo ./makeCert.sh client CCFIRE780-wt     # WinTAK device

# Restart TAK Server
sudo systemctl restart takserver
```

**Distribute:**
- Send `CCFIRE780.p12` for ATAK device
- Send `CCFIRE780-wt.p12` for WinTAK device
- User can renew devices at different times if needed

**Renewal Timeline:**
```
Day 0: Both certs expire in 90 days
Day 30: Renew ATAK cert (CCFIRE780)
Day 35: User imports new ATAK cert
Day 60: Renew WinTAK cert (CCFIRE780-wt)
Day 65: User imports new WinTAK cert
Day 90: Old certs would have expired (but renewed!)
```

**Benefit:** User can renew one device at a time, reducing complexity.

### 7.4 What Users Experience During Renewal

**Timeline:**
1. Receive new certificate (Day 0)
2. Choose convenient time (non-mission critical)
3. Remove old certificate in ATAK/WinTAK (~30 seconds)
4. Import new certificate (~30 seconds)
5. Connection auto-reconnects (~30 seconds)
6. Verify missions still visible (~30 seconds)

**Total Downtime: 2-3 minutes**

**What They Keep:**
- ✅ All mission subscriptions
- ✅ All data packages
- ✅ Contact lists
- ✅ Saved feeds
- ✅ Settings
- ✅ Map layers

**What They Experience:**
- ⚠️ Brief "Disconnected" status
- ⚠️ "Reconnecting..." message
- ⚠️ CoT temporarily stops transmitting
- ✅ Auto-reconnects when new cert imported
- ✅ Everything works as before

### 7.5 Impact on Data Sync Missions

**Same Username Renewal (CCFIRE780 → CCFIRE780):**
```
Before Renewal:
- User "CCFIRE780" subscribed to 15 missions
- All missions visible in ATAK
- Active participant in operations

During Renewal (2-3 minutes):
- Brief disconnect
- Missions temporarily unavailable
- CoT stops transmitting

After Renewal:
- ✅ User reconnects as "CCFIRE780"
- ✅ All 15 missions still subscribed
- ✅ No re-subscription needed
- ✅ Data sync continues seamlessly
- ✅ Historical data preserved
```

**Different Username Renewal (CCFIRE780 → CCFIRE780-NEW) - WRONG!:**
```
Before Renewal:
- User "CCFIRE780" subscribed to 15 missions

After Renewal with Different Name:
- ❌ TAK Server sees "CCFIRE780-NEW" as completely new user
- ❌ All 15 missions GONE from mission list
- ❌ Must manually rejoin all missions
- ❌ May lose access to restricted missions
- ❌ Admin must re-add to groups
- ❌ Hours of disruption
- ❌ Possible loss of mission-critical data access
```

**Real-World Impact:**

Good renewal:
```
Fire Chief: "My cert expired, got new one, still have all my missions. 
             Took 2 minutes. Back in service."
```

Bad renewal (wrong username):
```
Fire Chief: "I can't see any of my missions! All my structure fire data is gone!
             Can't access the incident action plans! We're running blind here!"
```

### 7.6 Batch Certificate Renewals

When renewing multiple users (e.g., whole department):

**Best Practices:**

**1. Schedule During Downtime**
- Shift changes (6am, 2pm, 10pm)
- Planned maintenance windows
- NOT during active incidents
- NOT during training exercises

**2. Stagger Renewals by Priority**
```
Week 1: Leadership (Chief, Deputies)
Week 2: Operations (Line personnel)
Week 3: Support (Dispatch, Admin)
Week 4: Reserve/Backup personnel
```

**3. Create Renewal Batches**
```bash
# Script to generate renewal batch
#!/bin/bash

cd /opt/tak/certs

# Week 1 - Leadership batch
for user in CCFIRE780 CCFIRE760 BCSO2200; do
    echo "Renewing $user..."
    sudo cp files/$user.p12 files/$user.p12.backup-$(date +%Y%m%d)
    sudo ./makeCert.sh client $user
done

# Restart after batch
sudo systemctl restart takserver

echo "Week 1 leadership certificates renewed"
```

**4. Test First**
```bash
# Create test user
sudo ./makeCert.sh client TEST-USER

# Renew test user
sudo ./makeCert.sh client TEST-USER

# Verify missions persist
# Document any issues
```

**5. Provide Real-Time Support**
- IT helpdesk standing by
- Walk-through support via phone
- Screen sharing available
- Quick troubleshooting guide

**6. Monitor Server Logs**
```bash
# Watch for connection issues during renewal period
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log | grep -i "ssl\|handshake\|error\|CCFIRE"
```

---

## Step 8: Certificate Revocation

### 8.1 Understanding Revocation Impact

When you revoke a user's certificate:
- ❌ User immediately loses connection to TAK Server
- ❌ User's CoT stops transmitting
- ⚠️ User removed from active connections
- ✅ Other users unaffected
- 🔄 Revoked user needs new certificate to regain access

**Use Cases:**
1. **Device lost/stolen** → Revoke immediately
2. **User leaving organization** → Revoke permanently
3. **Certificate compromised** → Revoke and reissue quickly
4. **Temporary suspension** → Revoke, reissue when cleared
5. **Wrong device (multi-device user)** → Revoke specific device cert

### 8.2 Revoke via Command Line

**Inside container:**
```bash
cd /opt/tak/certs

# Revoke a certificate
sudo ./makeCert.sh revoke [username]

# Examples:
sudo ./makeCert.sh revoke CCFIRE780        # Revoke ATAK device
sudo ./makeCert.sh revoke CCFIRE780-wt     # Revoke WinTAK only
sudo ./makeCert.sh revoke BCSO2240         # Revoke sheriff deputy

# Generate updated Certificate Revocation List
sudo ./makeCert.sh crl

# CRITICAL: Restart TAK Server to apply revocation
sudo systemctl restart takserver
```

**Result:**
- Certificate added to CRL (Certificate Revocation List)
- TAK Server refuses connections from revoked certificate
- User sees "Connection failed" or "SSL handshake failure"

### 8.3 Revoke via Web UI

1. Access TAK Server Web UI: `https://tak.pinenut.tech:8443`
2. Login with `webadmin.p12` certificate
3. Navigate to "User Manager"
4. Search for user: `CCFIRE780`
5. Click on username
6. Click "Revoke Certificate" button
7. Confirm revocation
8. TAK Server automatically updates CRL

**Note:** Still need to restart TAK Server for immediate effect:
```bash
lxc exec tak -- systemctl restart takserver
```

### 8.4 Emergency Revocation (Lost/Stolen Device)

**Immediate Actions (Within 1 Hour):**

**Step 1: Revoke Certificate**
```bash
# Get shell in container quickly
lxc exec tak -- bash

cd /opt/tak/certs

# Revoke immediately
sudo ./makeCert.sh revoke CCFIRE780

# Update CRL
sudo ./makeCert.sh crl

# Restart TAK Server
sudo systemctl restart takserver
```

**Step 2: Verify Revocation Applied**
```bash
# Check CRL contains revoked certificate
openssl crl -in files/crl.pem -text -noout | grep -A 5 "Serial Number"

# Watch logs for revoked cert trying to connect
tail -f /opt/tak/logs/takserver-messaging.log | grep -i "revoked\|revocation\|CCFIRE780"
```

**Step 3: Issue Replacement Certificate** (if appropriate)
```bash
# If user needs new cert for replacement device
cd /opt/tak/certs

# Option A: Same username (if same device replaced)
sudo ./makeCert.sh client CCFIRE780

# Option B: Backup device (if using backup device)
sudo ./makeCert.sh client CCFIRE780-bk

# Restart TAK Server
sudo systemctl restart takserver
```

**Step 4: Document Incident**
- Date/time device lost/stolen
- Last known location
- Certificate revoked: `CCFIRE780`
- User notified: [Name]
- Replacement cert issued: `CCFIRE780` or `CCFIRE780-bk`
- Incident report filed: [Number]

**Step 5: Monitor for Attempted Connections**
```bash
# Watch for revoked cert trying to connect over next 24 hours
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log | grep "CCFIRE780"

# If you see connection attempts, device may have been found
# Do NOT re-enable until device physically recovered
```

### 8.5 Multi-Device Partial Revocation

**Scenario:** User lost phone but still has laptop.

**Goal:** Revoke phone, keep laptop working.

```bash
# Inside container
cd /opt/tak/certs

# Revoke ONLY the phone certificate
sudo ./makeCert.sh revoke CCFIRE780

# DO NOT revoke laptop certificate (CCFIRE780-wt)

# Update CRL and restart
sudo ./makeCert.sh crl
sudo systemctl restart takserver
```

**Result:**
- Phone (CCFIRE780): ❌ Cannot connect (revoked)
- Laptop (CCFIRE780-wt): ✅ Still works (not revoked)
- User maintains situational awareness via laptop

**Later, issue replacement phone certificate:**
```bash
# New cert for replacement phone
sudo ./makeCert.sh client CCFIRE780

# Or use backup designation
sudo ./makeCert.sh client CCFIRE780-bk
```

---

## Step 9: Certificate Troubleshooting

### 9.1 Issue: "SSL Handshake Failure" in ATAK

**Symptom:** ATAK shows "SSL handshake failure" or won't connect

**Common Causes & Fixes:**

**Cause 1: Server not restarted after cert change**
```bash
# Restart TAK Server
lxc exec tak -- systemctl restart takserver
sleep 30
```

**Cause 2: Wrong certificate password**
```bash
# Check what password was set
# Default: atakatak
# If changed during install, check your documentation

# Verify certificate password works
keytool -list -keystore CCFIRE780.p12 -storepass atakatak
# If error, wrong password
```

**Cause 3: Certificate hostname mismatch**
```bash
# Inside container, check server cert CN
cd /opt/tak/certs/files
keytool -list -v -keystore tak.jks -storepass atakatak | grep "Owner:"

# CN must match domain user enters in ATAK
# If CN=tak.pinenut.tech, ATAK must connect to tak.pinenut.tech
# NOT to IP address
```

**Cause 4: Missing trust store on client**
```bash
# Client needs CA certificate to verify server
# Extract from enrollment package:
unzip enrollmentDP.zip
# File: caCert.p12 or truststore-[CA-NAME].p12

# Import this into ATAK under "CA Certificates"
```

**Cause 5: Certificate expired**
```bash
# Check expiration
keytool -list -v -keystore /opt/tak/certs/files/CCFIRE780.p12 -storepass atakatak | grep "Valid until"

# If expired, create new certificate
sudo ./makeCert.sh client CCFIRE780
sudo systemctl restart takserver
```

**Cause 6: Certificate revoked**
```bash
# Check if cert is in CRL
cd /opt/tak/certs/files
openssl crl -in crl.pem -text -noout | grep -A 5 "Serial"

# If accidentally revoked, must create new certificate
# Cannot "unrevoke" - create fresh certificate
```

### 9.2 Issue: Web UI Won't Accept webadmin.p12

**Symptom:** Browser won't load web UI or rejects certificate

**Fixes:**

**Fix 1: Certificate not imported to browser**
```
Firefox:
1. Settings → Privacy & Security → Certificates
2. View Certificates → Your Certificates
3. Import → Select webadmin.p12
4. Enter password: atakatak
5. Restart browser
6. Navigate to https://tak.pinenut.tech:8443

Chrome/Edge:
1. Settings → Privacy and security → Security
2. Manage certificates → Import
3. Select webadmin.p12
4. Enter password: atakatak
5. Restart browser
6. Navigate to https://tak.pinenut.tech:8443
```

**Fix 2: Wrong browser or mobile browser**
```
✅ Use: Desktop Firefox, Chrome, or Edge
❌ Don't use: Mobile browsers (limited cert support)
❌ Don't use: Safari (poor P12 support)
```

**Fix 3: Certificate password incorrect**
```
# Try default password
Password: atakatak

# If that fails, check installation documentation
# Password was set during installTAK setup
```

**Fix 4: Browser not accepting self-signed cert**
```
# When accessing web UI, you'll see security warning
# This is normal for self-signed certificates

In browser:
1. Click "Advanced"
2. Click "Accept Risk and Continue" (Firefox)
   or "Proceed to tak.pinenut.tech" (Chrome)
3. Then certificate prompt appears
4. Select webadmin.p12
5. Enter password
```

### 9.3 Issue: Certificate Signed by Unknown Authority

**Symptom:** ATAK/WinTAK says "Certificate signed by unknown authority"

**Cause:** Client doesn't have CA certificate to verify server

**Fix:**
```
1. Extract CA from enrollment package:
   unzip enrollmentDP.zip
   
2. File will be named: caCert.p12 or truststore-[CA-NAME].p12

3. Import into ATAK:
   Settings → Network → Manage Server Connections
   → Select server → Manage SSL/TLS Certificates
   → CA Certificates → Import
   → Select caCert.p12
   → Enter password: atakatak

4. Reconnect
```

### 9.4 Issue: Can't Create New Client Certificates

**Symptom:** `./makeCert.sh` fails or produces errors

**Check Permissions:**
```bash
# Inside container
cd /opt/tak/certs
ls -lh

# Files should be owned by root
# If not:
sudo chown -R root:root /opt/tak/certs/
sudo chmod 755 /opt/tak/certs/*.sh
```

**Check Scripts Exist:**
```bash
# Verify scripts present
ls -lh /opt/tak/certs/make*.sh

# Should show:
# makeRootCa.sh
# makeCert.sh

# If missing, TAK Server installation incomplete
```

**Check Certificate Signing CA:**
```bash
# Verify intermediate CA exists
ls -lh /opt/tak/certs/files/*-signing.jks

# If missing, CAs weren't created properly
# May need to regenerate CAs (destructive!)
```

### 9.5 Issue: Multi-Device User Can't Access Same Missions

**Symptom:** User's ATAK has missions, but WinTAK doesn't

**Cause:** Device certs not in same groups

**Fix via Web UI:**
1. Access TAK Server Web UI
2. User Manager
3. Find both users: `CCFIRE780` and `CCFIRE780-wt`
4. Add both to same groups
5. Wait 30 seconds for sync
6. User should see missions on both devices

**Fix via Group Structure:**
```
Create a "meta group" for the person:

Group: "CCFIRE780 - All Devices"
Members:
  - CCFIRE780 (ATAK)
  - CCFIRE780-wt (WinTAK)
  - CCFIRE780-it (iTAK)

Then add meta group to operational groups:

Group: "Fire Operations"
Members:
  - CCFIRE780 - All Devices
  - [other users]
```

---

## Step 10: Advanced Certificate Topics

### 10.1 Custom Certificate Validity Period

**Default:** Certificates valid for 2 years (730 days)

**To Change:**
```bash
# Inside container
cd /opt/tak/certs

# Edit certificate metadata
sudo nano cert-metadata.sh

# Find and modify:
CAVALIDITYDAYS=730          # CA valid for 2 years
VALIDITYDAYS=730            # Certificates valid for 2 years

# Example: 1-year validity
VALIDITYDAYS=365

# Example: 5-year validity (not recommended)
VALIDITYDAYS=1825

# Save and exit (Ctrl+X, Y, Enter)

# New certificates will use these values
```

**Recommendation:**
- Short-lived (1 year): Better security, more renewals
- Standard (2 years): Balance of security and convenience
- Long-lived (5 years): Less secure, fewer renewals

**For Emergency Services:**
- Leadership/24-7 personnel: 2 years
- Part-time/reserve personnel: 1 year
- Training/test devices: 90-180 days

### 10.2 Certificate Naming Convention Documentation

**Create a reference document:**

```markdown
# TAK Server Certificate Naming Convention
## Clear Creek VFD & Boise County SO

### Format
[AGENCY][UNIT_NUMBER][-DEVICE_SUFFIX]

### Agency Codes
- CCFIRE: Clear Creek Fire Department
- BCSO: Boise County Sheriff's Office
- IDACOM: Idaho Communications
- MUTUAL: Mutual aid agencies

### Device Suffixes
- (none): Primary ATAK device
- -wt: WinTAK
- -it: iTAK
- -ta: TAKAware
- -tx: TAK-X
- -bk: Backup device
- -tr: Training device

### Examples
- CCFIRE780: Fire Chief, ATAK on phone
- CCFIRE780-wt: Fire Chief, WinTAK on command vehicle
- BCSO2240: Deputy, ATAK on tablet
- BCSO2240-wt: Deputy, WinTAK in patrol car
- MUTUAL-IC1: Mutual aid incident commander

### Special Designations
- CCFIRE-DISPATCH: Dispatch console
- CCFIRE-EOC: Emergency Operations Center
- CCFIRE-MOBILE: Mobile command unit

### Certificate Lifecycle
1. Request cert using this naming convention
2. Track in certificate inventory spreadsheet
3. Renew with SAME name (keep subscriptions)
4. Revoke if device lost/person leaves
5. Document all changes in log
```

### 10.3 Exporting Certificates to Different Formats

**Convert P12 to PEM:**
```bash
# Inside container
cd /opt/tak/certs/files

# Full certificate + key
openssl pkcs12 -in CCFIRE780.p12 -out CCFIRE780.pem -nodes -passin pass:atakatak

# Certificate only
openssl pkcs12 -in CCFIRE780.p12 -clcerts -nokeys -out CCFIRE780-cert.pem -passin pass:atakatak

# Private key only (BE VERY CAREFUL WITH THIS)
openssl pkcs12 -in CCFIRE780.p12 -nocerts -nodes -out CCFIRE780-key.pem -passin pass:atakatak
```

**Use Cases:**
- Importing into other TAK tools
- Using with Python TAK libraries
- Integration with other systems
- Backup in alternate format

### 10.4 Certificate Inventory Automation

**Script to List All Certificates with Expiration:**

```bash
#!/bin/bash
# Save as: /opt/tak/certs/list-cert-expiry.sh

cd /opt/tak/certs/files

echo "Certificate Expiration Report - $(date)"
echo "=========================================="
echo ""

for cert in *.p12; do
    if [ "$cert" != "*.p12" ]; then
        echo "Certificate: $cert"
        keytool -list -v -keystore "$cert" -storepass atakatak 2>/dev/null | \
            grep -A 1 "Owner:\|Valid from:"
        echo "---"
    fi
done | tee ~/cert-expiry-report-$(date +%Y%m%d).txt

echo ""
echo "Report saved to: ~/cert-expiry-report-$(date +%Y%m%d).txt"
```

**Usage:**
```bash
# Inside container
chmod +x /opt/tak/certs/list-cert-expiry.sh
/opt/tak/certs/list-cert-expiry.sh

# Copy report to host
exit
lxc file pull tak/root/cert-expiry-report-*.txt ~/
```

---

## Step 11: Certificate Best Practices

### 11.1 Security Recommendations

**1. Protect Private Keys**
```bash
# Root CA private key is CRITICAL
# File: /opt/tak/certs/files/ca-do-not-share.key

# Verify permissions
ls -l /opt/tak/certs/files/ca-do-not-share.key
# Should be: -rw------- root root

# If not:
chmod 600 /opt/tak/certs/files/ca-do-not-share.key

# Backup to encrypted storage only
# Consider keeping root CA offline
```

**2. Use Strong Passwords**
```
Production recommendations:
❌ Don't use: atakatak (default)
✅ Use: Strong password (16+ characters)
✅ Store in: Password manager
✅ Document: Certificate password in secure location
✅ Separate: Different password per deployment
```

**3. Regular Certificate Rotation**
```
Rotation schedule:
- High-security roles (leadership): Annual
- Standard operations: Every 2 years
- Training/test devices: Every 6 months
- Revoked/compromised: Immediate
```

**4. Certificate Inventory**
```
Maintain spreadsheet with:
- Username
- Device type
- Certificate issued date
- Certificate expiration date
- Last connection date
- Person's name
- Contact info
- Status (Active/Revoked/Expired)
```

**5. Secure Distribution**
```
Best practices:
✅ Encrypted channels (TLS/HTTPS)
✅ Password-protected files
✅ Separate password delivery (SMS/phone)
✅ Confirm receipt and import
✅ Delete distribution copies after user confirms

Never:
❌ Public websites
❌ Unencrypted email
❌ Group chat/SMS with attachment
❌ Shared network drives
❌ Cloud storage without encryption
```

### 11.2 Operational Best Practices

**1. User Naming Convention**
```
Establish and document:
- Clear naming scheme
- Agency codes
- Unit/personnel numbers
- Device suffixes
- Special designations

Train all certificate administrators on convention
```

**2. Multi-Device Management**
```
For users with multiple devices:
- Create separate cert for each device
- Use consistent naming with suffixes
- Track all devices in inventory
- Add all device certs to same groups
- Document which device is primary
```

**3. Certificate Lifecycle Documentation**
```
Document every:
- Certificate creation (who, when, what)
- Certificate distribution (to whom, how)
- Certificate renewal (date, reason)
- Certificate revocation (date, reason, incident #)
- Device changes (old device, new device)
```

**4. Regular Audits**
```
Monthly:
- Review active connections vs issued certs
- Identify unused certificates (revoke?)
- Check for expiring certs (next 90 days)

Quarterly:
- Full certificate inventory audit
- Verify all users in correct groups
- Test certificate renewal process
- Update documentation

Annually:
- Security review of certificate practices
- Update naming conventions if needed
- Review certificate validity periods
- Train new administrators
```

### 11.3 Backup Strategy

**Critical Certificate Backups:**

```bash
# From VPS host, backup entire cert directory
lxc exec tak -- tar -czf /tmp/tak-certs-backup-$(date +%Y%m%d).tar.gz /opt/tak/certs/

# Copy to host
lxc file pull tak/tmp/tak-certs-backup-*.tar.gz ~/

# Download to secure off-site storage
scp takadmin@your-vps-ip:~/tak-certs-backup-*.tar.gz ./

# Verify backup
tar -tzf tak-certs-backup-*.tar.gz | head -20

# Store in:
# - Encrypted external drive (offline)
# - Encrypted cloud storage
# - Secure physical location
```

**Backup Schedule:**
```
Weekly: After creating new certificates
Monthly: Full cert directory backup
Before: Major changes (renewals, CA regeneration)
After: Incident (revocations, compromises)
```

**What to Backup:**
- ✅ /opt/tak/certs/ (entire directory)
- ✅ /opt/tak/CoreConfig.xml
- ✅ Certificate inventory spreadsheet
- ✅ Certificate password documentation
- ✅ Naming convention guide

**Do NOT Backup to:**
- ❌ Unencrypted cloud storage
- ❌ Public repositories
- ❌ Unencrypted USB drives
- ❌ Network shares without encryption

---

## Step 12: Certificate Renewal Calendar & Tracking

### 12.1 Certificate Expiration Tracking

**Spreadsheet Template:**

| User/Unit | Device | Cert Name | Issued | Expires | Renew By | Status | Contact | Notes |
|-----------|--------|-----------|--------|---------|----------|--------|---------|-------|
| Fire Chief 780 | ATAK Phone | CCFIRE780 | 2025-01-15 | 2027-01-15 | 2026-10-15 | Active | (208)555-0780 | Primary device |
| Fire Chief 780 | WinTAK Laptop | CCFIRE780-wt | 2025-01-20 | 2027-01-20 | 2026-10-20 | Active | (208)555-0780 | Command vehicle |
| Fire Chief 780 | iTAK iPhone | CCFIRE780-it | 2025-02-01 | 2027-02-01 | 2026-11-01 | Active | (208)555-0780 | Backup/personal |
| Deputy 2240 | ATAK Tablet | BCSO2240 | 2025-01-10 | 2027-01-10 | 2026-10-10 | Active | (208)555-2240 | Patrol tablet |
| Deputy 2240 | WinTAK Patrol | BCSO2240-wt | 2025-01-10 | 2027-01-10 | 2026-10-10 | Active | (208)555-2240 | Patrol vehicle |

**Renewal Timeline:**
- **120 days before expiry:** Add to renewal queue
- **90 days:** First notification to user
- **60 days:** Generate new certificate
- **30 days:** Distribute new certificate to user
- **14 days:** Second reminder if not renewed
- **7 days:** Final urgent reminder
- **0 days:** Certificate expires (user loses access)

### 12.2 Renewal Process Checklist

**For Each Certificate Renewal:**

**Week 12 (90 days before expiration):**
- [ ] Identify certificate expiring
- [ ] Verify user still active/needs cert
- [ ] Send first renewal notification
- [ ] Add to renewal tracking list

**Week 8 (60 days before expiration):**
- [ ] Generate new certificate (same username!)
- [ ] Test certificate (verify it works)
- [ ] Prepare distribution package
- [ ] Update inventory spreadsheet

**Week 4 (30 days before expiration):**
- [ ] Distribute new certificate to user
- [ ] Send renewal instructions
- [ ] Schedule support availability
- [ ] Set reminder for confirmation

**Week 2 (14 days before expiration):**
- [ ] Check if user renewed certificate
- [ ] Send reminder if not renewed
- [ ] Offer hands-on assistance

**Week 1 (7 days before expiration):**
- [ ] Urgent reminder if not renewed
- [ ] Schedule mandatory renewal time
- [ ] Provide direct support

**Day 0 (Expiration day):**
- [ ] If not renewed, certificate becomes invalid
- [ ] User loses access
- [ ] Issue emergency replacement if critical role

**After Renewal:**
- [ ] Verify user reconnected successfully
- [ ] Confirm missions still accessible
- [ ] Update inventory: Renewal date, new expiration
- [ ] Document any issues for future improvements

---

## Step 13: Verification Checklist

Before proceeding to Phase 5:

**Certificate Files:**
- [ ] Server certificate exists and is valid
- [ ] Server cert CN matches your domain
- [ ] Intermediate CA certificate exists
- [ ] Root CA certificate exists
- [ ] Trust stores created

**Client Certificates:**
- [ ] enrollmentDP.zip exists
- [ ] webadmin.p12 created and copied to host
- [ ] Test client certificate created (optional)
- [ ] All certificates follow naming convention

**Multi-Device Setup:**
- [ ] Naming convention documented
- [ ] Multi-device user testing completed (if applicable)
- [ ] Certificate inventory spreadsheet created
- [ ] Group structure configured for multi-device users

**Operations:**
- [ ] Can access web UI with webadmin.p12
- [ ] Certificate password documented
- [ ] Renewal process documented
- [ ] Certificate backup created

**Testing:**
- [ ] Test SSL connection: `openssl s_client -connect localhost:8089`
- [ ] Server certificate verified
- [ ] Web UI accessible at https://tak.pinenut.tech:8443
- [ ] Created and tested at least one client certificate

**Documentation:**
- [ ] Certificate inventory created
- [ ] Naming convention documented
- [ ] Renewal calendar established
- [ ] Distribution procedures documented
- [ ] Emergency revocation procedures documented

### Quick Certificate Test

**From VPS host:**
```bash
# Test server certificate
lxc exec tak -- openssl s_client -connect localhost:8089 -showcerts < /dev/null

# Look for:
# - verify return:1 (certificate verified)
# - subject=CN=tak.pinenut.tech
# - No error messages
```

---

## Next Steps

Once certificates are verified and working:

**➡️ Proceed to:** [Phase 5: Networking & HAProxy](05-NETWORKING.md)

This next guide covers:
- Exposing TAK Server to the internet
- Setting up HAProxy reverse proxy
- Configuring firewall rules  
- Port forwarding (80, 443, 8089, 8443, 8446, 9001)
- DNS configuration

**After Phase 5 Networking is complete:**

**➡️ Then proceed to:** [Phase 5B: Let's Encrypt SSL](05B-LETSENCRYPT-SETUP.md)

This guide covers:
- Let's Encrypt certificate request
- Converting LE certs for TAK Server
- Automatic renewal setup
- TAK Server reconfiguration for LE certs

---

## Additional Resources

### Documentation
- **TAK Server Certificate Guide:** https://tak.gov/docs
- **OpenSSL Documentation:** https://www.openssl.org/docs/
- **Java Keytool Guide:** https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html
- **myTeckNet Certificate Tutorials:** https://mytecknet.com/lets-sign-our-tak-server/

### Related Guides
- **[Certificate Renewal User Guide](CERTIFICATE-RENEWAL-USER-GUIDE.md)** - For end users
- **[TAK Server Administration Guide](TAK-ADMIN-GUIDE.md)** - For administrators (coming soon)

### Tools
- **OpenSSL:** Certificate inspection and conversion
- **keytool:** Java keystore management
- **ATAK:** Android Team Awareness Kit
- **WinTAK:** Windows Team Awareness Kit

---

*Last Updated: November 2025*  
*Tested on: TAK Server 5.5 in LXD container*  
*Certificate Tools: OpenSSL 3.x, Java Keytool 17*  
*Deployment: Clear Creek VFD / Boise County SO*
