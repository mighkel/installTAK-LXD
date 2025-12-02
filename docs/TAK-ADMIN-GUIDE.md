# TAK Server Administration Guide

**Comprehensive guide for TAK Server administrators in emergency services**

This guide covers day-to-day operations, user management, troubleshooting, and best practices for TAK Server running in LXD containers.

**Target Audience:** TAK Server administrators, IT staff, GIS/communications coordinators for emergency services agencies.

**Deployment Context:** TAK Server 5.5 running in LXD container on Ubuntu host.

---

## Customization Reference

This template uses placeholder values that should be replaced with your organization's specific information. Use find-and-replace to customize this document for your agency.

### Required Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `[YOUR_DOMAIN]` | Your TAK server's FQDN | `tak.example.org` |
| `[YOUR_ORG]` | Organization abbreviation | `MVFD`, `BCSO`, `SAR1` |
| `[YOUR_ORG_FULL]` | Full organization name | `Mountain View Fire Department` |
| `[YOUR_PREFIX]` | Callsign prefix for users | `MVFIRE`, `BCSO`, `SAR` |
| `[YOUR_UNIT_RANGE]` | Unit number range | `750-779`, `2200-2299` |
| `[PARTNER_ORG]` | Primary partner agency abbrev | `GCSO`, `STATEFD` |
| `[PARTNER_PREFIX]` | Partner callsign prefix | `GCSO`, `STFIRE` |
| `[PARTNER_ORG_FULL]` | Partner full name | `Grant County Sheriff's Office` |
| `[MUTUAL_AID_ORG]` | Mutual aid agency abbrev | `WRFD`, `FEDRES` |
| `[MUTUAL_AID_PREFIX]` | Mutual aid callsign prefix | `WRFIRE`, `FEMA` |
| `[YOUR_AREA_CODE]` | Local area code | `208`, `303`, `406` |
| `[CERT_PASSWORD]` | Your certificate password | (don't put actual password here) |

### Optional Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `[ADMIN_EMAIL]` | TAK admin contact email | `takadmin@example.org` |
| `[IT_CONTACT]` | IT department contact | `helpdesk@example.org` |
| `[VPS_IP]` | Your VPS IP address | `203.0.113.50` |

### Quick Find-Replace Commands

```bash
# In VS Code, Sublime, or similar editors:
# Ctrl+H (or Cmd+H on Mac) then replace each placeholder:

[YOUR_DOMAIN]       -> tak.yourdomain.org
[YOUR_ORG]          -> YOURORG
[YOUR_ORG_FULL]     -> Your Organization Full Name
[YOUR_PREFIX]       -> YOURORG
[YOUR_UNIT_RANGE]   -> 750-779
[PARTNER_ORG]       -> PARTNERORG
[PARTNER_PREFIX]    -> PARTNER
[PARTNER_ORG_FULL]  -> Partner Organization Full Name
[MUTUAL_AID_ORG]    -> MUTUALAID
[MUTUAL_AID_PREFIX] -> MUTUAL
[YOUR_AREA_CODE]    -> 555
[CERT_PASSWORD]     -> (your actual password)
[ADMIN_EMAIL]       -> admin@yourdomain.org
[VPS_IP]            -> your.vps.ip.address
```

After customization, delete this "Customization Reference" section.

---

## Table of Contents

1. [Daily Operations](#1-daily-operations)
2. [User Management](#2-user-management)
3. [Group Management](#3-group-management)
4. [Mission Management](#4-mission-management)
5. [Certificate Management](#5-certificate-management)
6. [Monitoring & Health Checks](#6-monitoring--health-checks)
7. [Backup Procedures](#7-backup-procedures)
8. [Troubleshooting](#8-troubleshooting)
9. [Emergency Procedures](#9-emergency-procedures)
10. [Security Best Practices](#10-security-best-practices)
11. [Multi-Agency Coordination](#11-multi-agency-coordination)
12. [Training & Documentation](#12-training--documentation)

---

## 1. Daily Operations

### 1.1 Morning Checklist

**Every morning (or start of shift):**

```bash
# From VPS host, check TAK Server health
lxc exec tak -- systemctl status takserver

# Check for Java processes running
lxc exec tak -- ps aux | grep takserver | grep -v grep

# Check listening ports
lxc exec tak -- ss -tulpn | grep -E "8089|8443|8446|9001"

# Check recent errors
lxc exec tak -- journalctl -u takserver --since "24 hours ago" | grep -i error

# Check disk space
lxc exec tak -- df -h

# Check memory usage
lxc exec tak -- free -h
```

**Expected Results:**
- takserver service: "active (exited)" - normal
- 5+ Java processes running
- All ports (8089, 8443, 8446, 9001) listening
- No critical errors in last 24 hours
- Disk usage < 80%
- Memory available > 2GB

### 1.2 Check Connected Users

**Web UI Method:**
1. Access: https://[YOUR_DOMAIN]:8443
2. Login with webadmin.p12
3. Navigate to "User Manager"
4. Review active connections
5. Verify expected users online

**Command Line Method:**
```bash
# Get shell in container
lxc exec tak -- bash

# View active connections in logs
tail -100 /opt/tak/logs/takserver-messaging.log | grep "connection"

# Count active users
# (requires parsing logs or using API)
```

### 1.3 Verify Core Services

**PostgreSQL:**
```bash
lxc exec tak -- systemctl status postgresql
lxc exec tak -- sudo -u postgres psql -c "SELECT count(*) FROM cot_router.users;"
```

**TAK Server Components:**
```bash
# Check all TAK processes
lxc exec tak -- ps aux | grep takserver

# Should see:
# - takserver-config.sh
# - takserver-messaging.sh  
# - takserver-api.sh
# - takserver-plugins.sh
# - takserver-retention.sh
```

### 1.4 Quick Health Test

**Test connections:**
```bash
# Test SSL port
lxc exec tak -- openssl s_client -connect localhost:8089 < /dev/null

# Test web UI port
lxc exec tak -- curl -k https://localhost:8443

# Test cert enrollment port
lxc exec tak -- curl -k https://localhost:8446
```

### 1.5 Review Recent Activity

**Check logs for anomalies:**
```bash
# Get shell
lxc exec tak -- bash

# Check for authentication failures
grep -i "authentication failed" /opt/tak/logs/takserver-messaging.log | tail -20

# Check for SSL errors
grep -i "ssl\|handshake" /opt/tak/logs/takserver-messaging.log | tail -20

# Check for database errors
grep -i "postgres\|database" /opt/tak/logs/takserver-messaging.log | tail -20
```

---

## 2. User Management

### 2.1 User Naming Convention

**Standard Format:** `[AGENCY][UNIT][-DEVICE]`

**Examples:**
- `[YOUR_PREFIX]780` - [YOUR_ORG], Unit 780, ATAK
- `[YOUR_PREFIX]780-wt` - Same user, WinTAK
- `[PARTNER_PREFIX]2240` - [PARTNER_ORG], Unit 2240

**Device Suffixes:**
- *(none)* - ATAK (default/primary)
- `-wt` - WinTAK
- `-it` - iTAK  
- `-ta` - TAKAware
- `-tx` - TAK-X
- `-bk` - Backup device
- `-tr` - Training device

### 2.1.1 Three Methods for User Onboarding

TAK Server supports three different methods for getting users connected. Understanding the differences is important for choosing the right approach.

---

#### Method 1: Certificate Enrollment with Data Package (Standard)

**How it works:**
1. Admin creates user in web UI with username/password
2. Admin distributes enrollmentDP.zip + credentials to user
3. User imports DP into ATAK, enters username/password
4. ATAK requests certificate from server via port 8446
5. **Server automatically generates certificate** for user
6. Certificate downloaded and installed in ATAK
7. User connects (certificate-based from now on)

**Advantages:**
- Works with self-signed certificates (DP contains trust store)
- No Android system-level certificate installation
- Self-service (users provision themselves)
- No .p12 files to manually distribute
- Certificates auto-created by server

**Requirements:**
- Port 8446 must be accessible to users
- User authentication configured (UserAuthenticationFile.xml)
- Enrollment enabled in CoreConfig.xml (default in installTAK)

**When to use:**
- Self-signed TAK certificates (no Let's Encrypt)
- Multiple users to onboard
- Users not technically sophisticated
- Want self-service provisioning

**User receives:**
- enrollmentDP.zip (TCP) or enrollmentDP-QUIC.zip (QUIC transport)
- Username: [YOUR_PREFIX]780
- Password: [set in web UI]
- Server URL: [YOUR_DOMAIN]

**About enrollmentDP-QUIC.zip:**

> **Note:** QUIC (Quick UDP Internet Connections) is a transport protocol, not an enrollment method. The `-QUIC` suffix indicates the data package is configured to use QUIC protocol instead of TCP for the server connection. QUIC can provide better performance on unreliable networks. This is NOT related to ATAK's "Quick Connect" feature (see Method 2 below).

---

#### Method 2: Quick Connect (No Data Package Required)

**How it works:**
1. Admin creates user in web UI with username/password
2. Admin gives user ONLY: server address + username/password
3. User opens ATAK -> Settings -> Network -> TAK Servers -> Add
4. User enters server URL, checks "Use Authentication", enters credentials
5. If using Let's Encrypt: ATAK trusts server automatically
6. If using self-signed: User must install CA cert in Android first
7. ATAK connects to port 8446, requests certificate
8. Certificate downloaded and installed automatically

**Advantages:**
- No data package distribution needed
- Simplest for users (just address + credentials)
- Works great with Let's Encrypt certificates
- Can use QR codes for even faster enrollment

**Requirements:**
- **Strongly recommended:** Let's Encrypt SSL certificates on port 8446
- Without Let's Encrypt: Users must manually install CA certificate in Android
- Port 8446 accessible to users
- User authentication configured

**When to use:**
- TAK Server uses Let's Encrypt certificates
- Want simplest possible user experience
- Distributing QR codes for rapid enrollment
- Can't easily distribute data package files

**User receives:**
- Server URL: [YOUR_DOMAIN]:8089
- Username: [YOUR_PREFIX]780
- Password: [set in web UI]
- (Optional) QR code containing above

**ATAK Quick Connect Steps:**
```
1. Open ATAK
2. Tap hamburger menu -> Settings
3. Network -> TAK Servers
4. Tap menu -> Add
5. Address: [YOUR_DOMAIN]
6. Port: 8089
7. Protocol: SSL
8. Check "Use Authentication"
9. Enter Username and Password
10. Tap OK
11. Wait for "Registration succeeded" message
```

**If Using Self-Signed Certificates (No Let's Encrypt):**

Users must install the CA certificate in Android's trust store BEFORE using Quick Connect:

```
1. Transfer CA certificate (truststore-intermediate.p12 or ca.pem) to device
2. Android Settings -> Security -> Encryption & Credentials
3. Install a certificate -> CA certificate
4. Select the CA file
5. Now Quick Connect will work
```

This extra step is why Method 1 (Data Package) is preferred for self-signed deployments.

---

#### Method 3: Pre-Generated Certificates (Manual Distribution)

**How it works:**
1. Admin creates certificate via CLI: `makeCert.sh client [YOUR_PREFIX]780`
2. Admin creates matching user in web UI
3. Admin securely distributes .p12 file to user
4. User imports .p12 into ATAK
5. User connects immediately (certificate IS the authentication)

**Advantages:**
- Maximum admin control
- No passwords to manage after initial setup
- Works without enrollment port (8446)
- Good for offline certificate generation
- Certificate security fully in admin hands

**Disadvantages:**
- More admin work (create each cert individually)
- Must securely distribute .p12 files
- More complex for non-technical users
- Doesn't scale as well for large groups

**When to use:**
- Small number of users (< 10)
- High-security requirements
- Enrollment port not accessible
- Prefer manual certificate management
- Users are technically sophisticated

**User receives:**
- [YOUR_PREFIX]780.p12 file
- Certificate password: [CERT_PASSWORD]
- Server URL: [YOUR_DOMAIN]
- CA trust store (if needed)

---

#### Comparison Chart

| Feature | DP Enrollment | Quick Connect | Pre-Generated Certs |
|---------|---------------|---------------|---------------------|
| **Data package needed?** | Yes | No | No (.p12 only) |
| **Admin creates cert?** | No (auto) | No (auto) | Yes (makeCert.sh) |
| **Username/password?** | Yes | Yes | No (cert is auth) |
| **Works with self-signed?** | Yes (easy) | Requires CA install | Yes |
| **Works with Let's Encrypt?** | Yes | Yes (best option) | Yes |
| **Port 8446 needed?** | Yes | Yes | No |
| **User complexity** | Medium | Low | Medium |
| **Admin workload** | Low | Low | High |
| **Scalability** | High | High | Low |
| **Best for** | Self-signed certs | Let's Encrypt | Small/secure |

---

#### Which Method for [YOUR_ORG]?

**If using Let's Encrypt certificates:** Use Quick Connect (Method 2) for the simplest user experience. Users only need server address and credentials.

**If using self-signed certificates:** Use Data Package Enrollment (Method 1). The data package includes the trust store, so users don't need to manually install CA certificates.

**For special cases (high security, small team, offline):** Use Pre-Generated Certificates (Method 3).

---

### 2.2 User Onboarding Workflows

Choose the appropriate workflow based on your agency's needs and certificate type.

#### 2.2.1 Creating User via Data Package Enrollment (Self-Signed Certs)

This is the standard method where users self-provision using username/password, and TAK Server automatically generates their certificate.

**Step 1: Create User in Web UI**
```
1. Access: https://[YOUR_DOMAIN]:8443
2. Login with webadmin.p12
3. User Manager -> "Add User"
4. Fill in:
   - Username: [YOUR_PREFIX]780 (following naming convention)
   - Password: [Create strong password] <- IMPORTANT for enrollment
   - First Name: John
   - Last Name: Smith
   - Role: USER (or ADMIN for leadership)
5. Add to appropriate groups:
   - All Users (everyone)
   - [YOUR_ORG] Operations (or appropriate group)
   - Additional groups as needed
6. Save
```

**Step 2: Distribute Enrollment Package and Credentials**

Give the user:
- `enrollmentDP.zip` (or `enrollmentDP-QUIC.zip` for QUIC transport)
- Username: `[YOUR_PREFIX]780`
- Password: `[password you set]`
- Server URL: `[YOUR_DOMAIN]`
- Installation instructions

**How to get enrollmentDP.zip:**
```bash
# Copy from container to host (if not already done)
lxc file pull tak/home/takadmin/enrollmentDP.zip ~/

# Download to your local machine
scp takadmin@[VPS_IP]:~/enrollmentDP.zip ./
```

**Step 3: User Enrollment Process (User does this)**

**In ATAK:**
```
1. Transfer enrollmentDP.zip to Android device
2. Open ATAK
3. Tap hamburger menu -> Settings
4. Network -> Certificate Enrollment
5. Tap "Import Config"
6. Select enrollmentDP.zip
7. Enter Username: [YOUR_PREFIX]780
8. Enter Password: [password from Step 1]
9. Tap "Enroll"
10. Wait 10-30 seconds
11. Certificate automatically generated and installed
12. ATAK automatically connects
13. Green "Connected" status appears
```

**Behind the scenes:**
- ATAK connects to port 8446 (enrollment port)
- Sends username/password to TAK Server
- TAK Server verifies credentials
- TAK Server runs: `makeCert.sh client [YOUR_PREFIX]780` automatically
- Certificate sent to ATAK encrypted
- ATAK installs [YOUR_PREFIX]780.p12
- Connection switches to port 8089 (cert-based auth)

**Step 4: Verify User Connected**
```
1. Web UI -> User Manager
2. Find user: [YOUR_PREFIX]780
3. Status should show "Connected" (green)
4. Click username to see connection details
5. Verify user can access expected missions
```

**Step 5: Document in Inventory**
```
Add to certificate inventory spreadsheet:
- Username: [YOUR_PREFIX]780
- Device: ATAK on Samsung tablet
- Person: John Smith
- Contact: ([YOUR_AREA_CODE])555-0780
- Issued: 2025-11-24 (date enrolled)
- Expires: 2027-11-24 (2 years)
- Status: Active
- Groups: All Users, [YOUR_ORG] Operations
- Role: USER
- Method: Enrollment
```

**Troubleshooting Enrollment:**

**User gets "Enrollment failed":**
- Verify username/password correct (case-sensitive!)
- Check port 8446 is accessible from user's network
- Check TAK Server logs: `lxc exec tak -- tail -f /opt/tak/logs/takserver-api.log`
- Verify user exists in web UI with correct password

**User gets "Connection failed" after enrollment:**
- Certificate may not have installed properly
- Check ATAK -> Settings -> Network -> Manage SSL/TLS Certificates
- Should see [YOUR_PREFIX]780 certificate listed
- If missing, retry enrollment

**Enrollment works but can't see missions:**
- User enrolled successfully but not in right groups
- Web UI -> User Manager -> [YOUR_PREFIX]780 -> Edit groups
- Add to appropriate groups

---

#### 2.2.2 Creating User via Quick Connect (Let's Encrypt)

This is the simplest method when your TAK Server uses Let's Encrypt certificates.

**Step 1: Create User in Web UI**
```
1. Access: https://[YOUR_DOMAIN]:8443
2. Login with webadmin.p12
3. User Manager -> "Add User"
4. Fill in:
   - Username: [YOUR_PREFIX]780
   - Password: [Create strong password]
   - First Name: John
   - Last Name: Smith
   - Role: USER
5. Add to appropriate groups
6. Save
```

**Step 2: Provide User with Connection Info**

Give the user ONLY:
- Server address: `[YOUR_DOMAIN]`
- Port: `8089`
- Username: `[YOUR_PREFIX]780`
- Password: `[password you set]`

No data package or certificate files needed!

**Step 3: User Quick Connect Process (User does this)**

**In ATAK:**
```
1. Open ATAK
2. Tap hamburger menu -> Settings
3. Network -> TAK Servers
4. Tap menu (three dots) -> Add
5. Enter:
   - Description: [YOUR_ORG] TAK
   - Address: [YOUR_DOMAIN]
   - Port: 8089
   - Protocol: SSL
   - Check "Use Authentication"
   - Username: [YOUR_PREFIX]780
   - Password: [password]
6. Tap OK
7. Wait for "TAK Server registration succeeded"
8. Connection established!
```

**Step 4: Verify and Document**

Same as Section 2.2.1 Steps 4-5.

**Optional: QR Code Enrollment**

For even faster onboarding, generate QR codes containing connection info. Users scan with phone camera, which opens ATAK and auto-populates settings.

See: https://github.com/sgofferj/TAK-mass-enrollment

---

#### 2.2.3 Creating User via Pre-Generated Certificates (Manual Method)

**Prerequisites:**
- Username decided (follow naming convention)
- User's full name and contact info
- Agency and unit/personnel number
- Device type
- Intended access level (which groups)

**Important:** TAK Server requires BOTH a certificate (created via CLI) AND a user entry (created in web UI). The certificate provides authentication, while the user entry provides authorization (groups, roles, permissions). **The names must match exactly.**

**Step 1: Create Certificate (CLI)**
```bash
# Get shell in container
lxc exec tak -- bash

cd /opt/tak/certs

# Create certificate
sudo ./makeCert.sh client [YOUR_PREFIX]780

# Certificate created: /opt/tak/certs/files/[YOUR_PREFIX]780.p12
# This creates a certificate with CN=[YOUR_PREFIX]780
```

**Step 2: Copy Certificate to Host**
```bash
# Exit container
exit

# From VPS host
lxc file pull tak/opt/tak/certs/files/[YOUR_PREFIX]780.p12 ~/[YOUR_PREFIX]780.p12

# Verify
ls -lh ~/[YOUR_PREFIX]780.p12

# Download to your local machine
scp takadmin@[VPS_IP]:~/[YOUR_PREFIX]780.p12 ./
```

**Step 3: Create Matching User in Web UI**
```
CRITICAL: Username must EXACTLY match certificate name (case-sensitive)

1. Access: https://[YOUR_DOMAIN]:8443
2. Login with webadmin.p12
3. User Manager -> "Add User"
4. Fill in:
   - Username: [YOUR_PREFIX]780 (MUST match cert name exactly)
   - Password: (leave blank - not needed for cert-based auth)
   - First Name: John
   - Last Name: Smith
   - Role: USER (or ADMIN for leadership)
5. Add to appropriate groups:
   - All Users (everyone gets this)
   - [YOUR_ORG] Operations (or appropriate group)
   - Additional groups as needed
6. Save
```

**How They Connect:**
```
When user connects with [YOUR_PREFIX]780.p12:
1. Certificate presents CN=[YOUR_PREFIX]780 to TAK Server
2. TAK Server looks up user "[YOUR_PREFIX]780" in database
3. Finds match -> Grants access with assigned groups/role
4. User sees missions based on group membership
```

**Common Mistakes:**
- Cert: [YOUR_PREFIX]780.p12, User: [YOUR_PREFIX]-780 (hyphen) -> No match, fails
- Cert: [your_prefix]780.p12, User: [YOUR_PREFIX]780 (case) -> No match, fails
- Cert: [YOUR_PREFIX]780.p12, User: not created -> Connection fails

**Step 4: Distribute Certificate**
- Send [YOUR_PREFIX]780.p12 to user
- Send certificate password: `[CERT_PASSWORD]`
- Send installation instructions
- Inform user which groups they're in

**Step 5: Document in Inventory**
Add to certificate inventory spreadsheet:
- Username: [YOUR_PREFIX]780
- Device: ATAK on Samsung tablet
- Person: John Smith
- Contact: ([YOUR_AREA_CODE])555-0780
- Issued: 2025-11-24
- Expires: 2027-11-24
- Status: Active
- Groups: All Users, [YOUR_ORG] Operations
- Role: USER
- Method: Pre-generated

**Step 6: Verify User Can Connect**
After user imports certificate:
1. Check Web UI -> User Manager
2. Look for [YOUR_PREFIX]780
3. Status should show "Connected" when user is online
4. Verify user can access expected missions

**Note: Auto-User Creation**

If you skip Step 3 (creating user in web UI), TAK Server may automatically create the user when they first connect, depending on your CoreConfig.xml settings. However, auto-created users:
- Have default permissions only
- Not assigned to any groups (except maybe "All Users")
- Have USER role (not ADMIN)
- Require manual group assignment after creation

**Best Practice:** Always create the user in web UI BEFORE distributing certificate.

### 2.3 Multi-Device User Setup

**Scenario:** User needs ATAK and WinTAK

**Step 1: Create Primary Certificate (ATAK)**
```bash
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh client [YOUR_PREFIX]780
exit

lxc file pull tak/opt/tak/certs/files/[YOUR_PREFIX]780.p12 ~/[YOUR_PREFIX]780.p12
```

**Step 2: Create Secondary Certificate (WinTAK)**
```bash
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh client [YOUR_PREFIX]780-wt
exit

lxc file pull tak/opt/tak/certs/files/[YOUR_PREFIX]780-wt.p12 ~/[YOUR_PREFIX]780-wt.p12
```

**Step 3: Add Both to Web UI**
Create two users:
1. Username: `[YOUR_PREFIX]780` (ATAK)
2. Username: `[YOUR_PREFIX]780-wt` (WinTAK)

**Step 4: Add Both to Same Groups**
Create a meta-group:
- Group name: "[YOUR_PREFIX]780 - All Devices"
- Members: [YOUR_PREFIX]780, [YOUR_PREFIX]780-wt

Then add meta-group to operational groups:
- Group "[YOUR_ORG] Operations" -> Add "[YOUR_PREFIX]780 - All Devices"

**Benefit:** User sees same missions on both devices

### 2.4 Editing Users

**Change User Groups:**
1. Web UI -> User Manager
2. Search for user: `[YOUR_PREFIX]780`
3. Click username
4. Modify groups (add/remove)
5. Save

**Change User Role:**
1. Web UI -> User Manager
2. Click username
3. Change role: USER -> ADMIN (or vice versa)
4. Save

**Note:** Cannot change username. To rename, must:
1. Create new user with new name
2. Migrate groups/permissions
3. Delete old user
4. User loses mission subscriptions

**Recommendation:** Get username right the first time!

### 2.5 Disabling vs Deleting Users

**Disable User (Temporary):**
1. Revoke certificate (see Certificate Management)
2. Keep user in database
3. User can be re-enabled with new certificate

**Delete User (Permanent):**
1. Web UI -> User Manager
2. Find user
3. Delete user
4. User loses all mission subscriptions
5. Historical data association lost

**Recommendation:**
- Disable: For temporary suspensions, lost devices
- Delete: Only for departed personnel (after archiving data)

### 2.6 User Troubleshooting

**User Can't Connect:**

**Check 1: Certificate Valid?**
```bash
lxc exec tak -- bash
cd /opt/tak/certs/files
keytool -list -v -keystore [YOUR_PREFIX]780.p12 -storepass [CERT_PASSWORD] | grep "Valid"
```

**Check 2: Certificate Revoked?**
```bash
openssl crl -in crl.pem -text -noout | grep -A 5 "Serial"
# If cert serial appears here, it's revoked
```

**Check 3: User Exists in Web UI?**
1. Web UI -> User Manager
2. Search: [YOUR_PREFIX]780
3. If not found, create user entry

**Check 4: Groups Correct?**
1. Click username in User Manager
2. Verify group membership
3. Add to "All Users" group at minimum

**User Can Connect But No Missions:**
- Check group membership
- Verify missions allow user's groups
- Check Data Sync enabled for user

---

## 3. Group Management

### 3.1 Understanding Groups

**Purpose:**
- Control mission access
- Organize users by role/agency
- Define data sharing boundaries
- Simplify permission management

**Types:**
- **Organizational:** Based on agency ([YOUR_ORG], [PARTNER_ORG])
- **Functional:** Based on role (Leadership, Operations, Support)
- **Operational:** Based on mission type (Fire Ops, Law Enforcement, Medical)
- **Meta:** Groups of users (multi-device users)

### 3.2 Recommended Group Structure

**For [YOUR_ORG_FULL] / [PARTNER_ORG_FULL]:**

```
All Users (Everyone)
+-- [YOUR_ORG] (All [YOUR_ORG] Personnel)
|   +-- [YOUR_ORG] Leadership
|   +-- [YOUR_ORG] Operations
|   +-- [YOUR_ORG] Support
|   +-- [YOUR_ORG] Training
+-- [PARTNER_ORG] (All [PARTNER_ORG])
|   +-- [PARTNER_ORG] Leadership
|   +-- [PARTNER_ORG] Patrol
|   +-- [PARTNER_ORG] Investigations
|   +-- [PARTNER_ORG] Support
+-- Mutual Aid (External agencies)
|   +-- State Resources
|   +-- Federal Resources
+-- Special Operations
    +-- Incident Command
    +-- SAR Operations
    +-- Hazmat Operations
```

**Meta-Groups for Multi-Device Users:**
```
User-Specific Device Groups
+-- [YOUR_PREFIX]780 - All Devices
|   +-- [YOUR_PREFIX]780 (ATAK)
|   +-- [YOUR_PREFIX]780-wt (WinTAK)
|   +-- [YOUR_PREFIX]780-it (iTAK)
+-- [PARTNER_PREFIX]2240 - All Devices
    +-- [PARTNER_PREFIX]2240 (ATAK)
    +-- [PARTNER_PREFIX]2240-wt (WinTAK)
```

### 3.3 Creating Groups

**Web UI Method:**
1. Access: https://[YOUR_DOMAIN]:8443
2. Data Sync -> Groups
3. Click "Add Group"
4. Fill in:
   - Group Name: `[YOUR_ORG] Operations`
   - Description: `[YOUR_ORG] operational personnel`
   - Type: `Group`
5. Add members (users or other groups)
6. Save

**Best Practices:**
- Use descriptive names
- Document group purpose
- Start with broad groups, refine later
- Don't over-complicate (fewer is better)

### 3.4 Adding Users to Groups

**Single User:**
1. Groups -> Select group
2. Click "Add Member"
3. Search for user: `[YOUR_PREFIX]780`
4. Add user
5. Save

**Multiple Users:**
1. Create list of usernames
2. Add each to group
3. Or create parent group and add all at once

**Multi-Device User:**
1. Create meta-group: "[YOUR_PREFIX]780 - All Devices"
2. Add all device certs to meta-group
3. Add meta-group to operational groups

### 3.5 Group Permissions

**Data Sync Permissions:**
- Who can see missions
- Who can create missions
- Who can edit missions
- Who can delete missions

**File Sharing:**
- Who can upload files
- Who can download files
- File size limits

**Federation:**
- Groups allowed to federate
- Groups visible to federated servers

### 3.6 Group Best Practices

**Design Principles:**
1. **Hierarchy:** Start broad, get specific
2. **Purpose:** Each group serves clear purpose
3. **Minimal:** Fewest groups that meet needs
4. **Documented:** Write down what each group is for
5. **Tested:** Verify missions accessible by right people

**Avoid:**
- Too many groups (confusion)
- Overlapping groups (duplicate access)
- Unclear naming (what is "Group1"?)
- Groups of one person (use for 2+ only)

---

## 4. Mission Management

### 4.1 Understanding Missions

**What is a Mission?**
- Shared operational space
- Common Operating Picture (COP)
- Data Sync container
- Persistent storage of:
  - CoT markers (points, lines, shapes)
  - Files (photos, documents, PDFs)
  - Data packages
  - Mission logs

**Use Cases:**
- **Structure Fire:** All resources on scene
- **SAR Operation:** Search teams coordination
- **Multi-Agency Incident:** Unified command
- **Training Exercise:** Student tracking
- **Daily Operations:** Routine activities

### 4.2 Creating Missions

**Web UI Method:**
1. Access: https://[YOUR_DOMAIN]:8443
2. Data Sync -> Missions
3. Click "Create Mission"
4. Fill in:
   - Name: `Structure Fire - 123 Main St`
   - Description: `Residential structure fire response`
   - Tool: `public` (or `private` for restricted)
   - Groups: Add groups that need access
   - Password: (optional, for private missions)
5. Create

**ATAK Method:**
Users can create missions from ATAK:
1. ATAK -> Mission
2. Tap "+"
3. Enter mission name
4. Sync to server
5. Invite others

**Mission Naming Convention:**

Format: `[TYPE] - [LOCATION] - [DATE]`

Examples:
- `Fire - 123 Main St - 2025-11-24`
- `SAR - Lost Hiker - 2025-11-24`
- `Training - Fire Ops - 2025-11-24`
- `Daily Ops - [YOUR_ORG] - 2025-11-24`

### 4.3 Mission Lifecycle

**Active Mission:**
```
1. Create mission (incident start)
2. Add users/groups
3. Share mission link/invite
4. Users subscribe
5. Users add data (markers, photos, etc.)
6. Monitor in real-time
7. Export for documentation (incident end)
8. Archive mission
```

**Mission States:**
- **Active:** Currently in use, users adding data
- **Archived:** Completed, read-only
- **Deleted:** Removed (cannot recover)

### 4.4 Managing Active Missions

**Add Users to Mission:**
1. Web UI -> Data Sync -> Missions
2. Click mission name
3. "Manage Access"
4. Add groups or individual users
5. Save

**Remove Users from Mission:**
1. Same as above
2. Remove group/user
3. Save
4. User loses access immediately

**Change Mission Settings:**
1. Click mission
2. Edit:
   - Name/description
   - Groups with access
   - Password (if private)
   - Default role (owner, subscriber)
3. Save

### 4.5 Mission Data Management

**View Mission Contents:**
1. Web UI -> Mission
2. Click mission name
3. View:
   - CoT events (markers)
   - Files uploaded
   - Mission logs
   - Subscribers

**Download Mission Data:**
1. Click mission
2. "Export" or "Download"
3. Saves as data package
4. Import into ATAK for offline review

**Delete Old Mission Data:**
1. Review missions periodically
2. Archive completed missions
3. Delete only if:
   - Documented elsewhere
   - No legal/compliance need
   - Confirmed with users

### 4.6 Mission Troubleshooting

**User Can't See Mission:**

**Check 1: User in Right Group?**
1. Web UI -> User Manager -> Find user
2. Check groups
3. Compare to mission's allowed groups

**Check 2: Mission Access Settings**
1. Web UI -> Missions -> Click mission
2. Check "Allowed Groups"
3. Add user's group if missing

**Check 3: User Subscribed?**
Users must subscribe to missions in ATAK:
1. ATAK -> Mission
2. Search for mission
3. Subscribe

**Mission Data Not Syncing:**

**Check 1: TAK Server Running?**
```bash
lxc exec tak -- systemctl status takserver
```

**Check 2: Network Connectivity?**
User must have internet connection to sync

**Check 3: Data Sync Enabled?**
1. Web UI -> User Manager
2. Check user has Data Sync role

---

## 5. Certificate Management

### 5.1 Daily Certificate Tasks

**Check for Expiring Certificates:**
```bash
# Run monthly or weekly
lxc exec tak -- bash

cd /opt/tak/certs/files

for cert in *.p12; do
    echo "=== $cert ==="
    keytool -list -v -keystore "$cert" -storepass [CERT_PASSWORD] 2>/dev/null | grep "Valid until"
done | grep -B 1 "2026-02"  # Adjust date range
```

**Renew Certificates (90 days before expiry):**
See [04-CERTIFICATE-MANAGEMENT.md](04-CERTIFICATE-MANAGEMENT.md) - Step 7

### 5.2 Emergency Certificate Revocation

**Lost/Stolen Device:**
```bash
# Immediate revocation
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh revoke [YOUR_PREFIX]780
sudo ./makeCert.sh crl
sudo systemctl restart takserver
```

**Issue Replacement:**
```bash
# New cert with same name (if same person, new device)
sudo ./makeCert.sh client [YOUR_PREFIX]780

# Or backup designation (if using backup device)
sudo ./makeCert.sh client [YOUR_PREFIX]780-bk
```

### 5.3 Certificate Inventory

**Maintain spreadsheet with:**
- Username / Cert name
- Person's name
- Contact info
- Device type
- Issued date
- Expiration date
- Status (Active/Revoked/Expired)
- Notes

**Update after:**
- Creating new certificate
- Renewing certificate
- Revoking certificate
- User leaves organization

### 5.4 Understanding Certificate Types

TAK Server creates different types of certificates during installation. Understanding the difference is critical for proper administration.

#### Type 1: webadmin.p12 (Web UI Access Certificate)

**Purpose:** Browser-based authentication to TAK Server web administration interface

**Created:** During TAK Server installation (one per server)

**Used in:**
- Desktop web browsers (Firefox, Chrome, Edge)
- Imported into browser's certificate manager
- Access URL: `https://[YOUR_DOMAIN]:8443`

**What you can do with it:**
- Full server administration
- User management (create, delete, modify users)
- Group management (create groups, assign members)
- Mission management (view, delete missions)
- View server status and logs
- Configuration changes
- Certificate management via web UI
- Database queries and reports

**What you CANNOT do:**
- Use in ATAK/WinTAK/iTAK (won't work)
- Connect to TAK Server as a field client
- Create missions from the field
- Send/receive CoT data

**Protocol:** HTTPS client certificate authentication  
**Port:** 8443

**Important:** This certificate has **complete control** over the TAK Server. Treat it like a root password.

#### Type 2: Regular User Certificates ([YOUR_PREFIX]750.p12, [YOUR_PREFIX]760.p12, etc.)

**Purpose:** Client authentication for ATAK/WinTAK/iTAK field applications

**Created:** Manually by administrator for each user/device

**Used in:**
- ATAK (Android)
- WinTAK (Windows)
- iTAK (iOS)
- TAKAware
- TAK-X

**What you can do with it:**
- Connect to TAK Server
- Send/receive CoT data
- View missions (based on group membership)
- Subscribe to missions
- Add data to missions (markers, photos, files)
- View other users on map
- Send messages
- Access Data Sync

**What you CANNOT do (unless admin role assigned):**
- Access web UI at :8443
- Create/delete users
- Manage server configuration

**Protocol:** SSL/TLS client certificate authentication  
**Port:** 8089 (main), 8446 (enrollment)

**Important:** Each user gets their own certificate. Never share certificates between users.

#### Type 3: The "admin.p12" File (Generic Admin Certificate)

**Created:** During TAK Server installation  
**Location:** `/opt/tak/certs/files/admin.p12`

**Purpose:** Generic admin-level client certificate (pre-created for convenience)

**Reality:** **Typically never used** - Better to create named certificates with admin roles

**Why you shouldn't use it:**
- Doesn't follow naming convention
- Can't track who's using it
- Can't tell which device it's on
- Difficult to revoke if compromised
- No accountability

**Best Practice:**
```bash
# Don't use admin.p12
# Instead, create certificates for actual personnel:

cd /opt/tak/certs
sudo ./makeCert.sh client [YOUR_PREFIX]750      # Chief's ATAK
sudo ./makeCert.sh client [YOUR_PREFIX]750-wt   # Chief's WinTAK

# Then in Web UI:
# User Manager -> Find "[YOUR_PREFIX]750"
# Change Role: USER -> ADMIN
# Save
```

#### Certificate Comparison Chart

| Feature | webadmin.p12 | [YOUR_PREFIX]750 (admin role) | [YOUR_PREFIX]760 (user) |
|---------|--------------|-------------------------------|-------------------------|
| **Access Web UI** | Yes | No | No |
| **Use in ATAK** | No | Yes | Yes |
| **Manage users** | Via Web UI | No | No |
| **Create missions** | Via Web UI | From ATAK | From ATAK |
| **Delete missions** | Via Web UI | From ATAK | No |
| **View all users** | Yes | No | No |
| **Change server config** | Yes | No | No |
| **Send CoT** | No | Yes | Yes |
| **Field operations** | No | Yes | Yes |
| **Number needed** | 1 per server | 1 per admin per device | 1 per user per device |

#### Certificate Roles in Web UI

When you create a user in the web UI, you assign a **role**:

**USER Role (Default)**
- Can connect to TAK Server
- Can view missions they have access to
- Can subscribe to missions
- Can add data to missions
- Cannot delete missions
- Cannot manage other users
- **Most personnel get this role**

**ADMIN Role**
- All USER permissions
- **Plus:** Can delete missions from ATAK/WinTAK
- **Plus:** Enhanced mission management
- **Plus:** Some server management functions from client
- **Note:** Still cannot access Web UI (that's webadmin.p12 only)
- **Use for:** Leadership, incident commanders, senior officers

**Example Setup for [YOUR_ORG]:**

```
Leadership (Admin Role):
- [YOUR_PREFIX]750 (Chief) -> ADMIN role
- [YOUR_PREFIX]751 (Asst Chief) -> ADMIN role
- [YOUR_PREFIX]752-759 (Officers) -> ADMIN role (as appropriate)

Operations (User Role):
- [YOUR_PREFIX]760-779 (Members) -> USER role

Web Administration:
- webadmin.p12 -> Used by Chief, Asst Chief, or IT/Communications staff
- Imported into office computers
```

#### Common Questions

**Q: Can I use webadmin.p12 in ATAK?**  
A: No. Different certificate types, different protocols. webadmin.p12 only works in web browsers for the :8443 web UI.

**Q: Can I use my ATAK certificate ([YOUR_PREFIX]760.p12) in the web browser?**  
A: No. It won't authenticate to the web UI. You need webadmin.p12 for that.

**Q: Do I need both webadmin.p12 and [YOUR_PREFIX]750.p12 if I'm the chief?**  
A: If you want both server administration (from office) AND field operations (from ATAK), then yes, you need both.

**Q: [PARTNER_ORG] wants TAK Server access. Do they need webadmin.p12?**  
A: No! They just need their own client certificates ([PARTNER_PREFIX]2230, etc.). Only YOUR administrators need webadmin.p12 for YOUR server.

#### Certificate Security Summary

**webadmin.p12:**
- Extremely sensitive
- Treat like root password
- Secure storage
- Limited distribution (1-3 people max)
- Track who has access
- Revoke/recreate if compromised

**User certificates ([YOUR_PREFIX]750.p12, etc.):**
- Sensitive
- One per person per device
- Secure distribution
- Track in inventory
- Rotate every 1-2 years
- Revoke if device lost

**admin.p12 (generic):**
- Don't use
- Sits unused
- That's okay and normal

---

## 6. Monitoring & Health Checks

### 6.1 Automated Monitoring Script

**Save as: `/root/check-tak-health.sh`**

```bash
#!/bin/bash
# TAK Server Health Check Script

LOGFILE="/var/log/tak-health-check.log"
EMAIL="[ADMIN_EMAIL]"

echo "=== TAK Server Health Check - $(date) ===" | tee -a $LOGFILE

# Check container running
if lxc info tak > /dev/null 2>&1; then
    echo "[OK] Container 'tak' is running" | tee -a $LOGFILE
else
    echo "[ERROR] Container 'tak' is not running!" | tee -a $LOGFILE
    exit 1
fi

# Check TAK Server service
if lxc exec tak -- systemctl is-active takserver > /dev/null 2>&1; then
    echo "[OK] TAK Server service is active" | tee -a $LOGFILE
else
    echo "[ERROR] TAK Server service is not active!" | tee -a $LOGFILE
    exit 1
fi

# Check Java processes
JAVA_COUNT=$(lxc exec tak -- ps aux | grep takserver | grep -v grep | wc -l)
if [ "$JAVA_COUNT" -ge 5 ]; then
    echo "[OK] $JAVA_COUNT TAK Server processes running" | tee -a $LOGFILE
else
    echo "[WARNING] Only $JAVA_COUNT TAK Server processes (expected 5+)" | tee -a $LOGFILE
fi

# Check ports listening
for port in 8089 8443 8446 9001; do
    if lxc exec tak -- ss -tulpn | grep -q ":$port"; then
        echo "[OK] Port $port is listening" | tee -a $LOGFILE
    else
        echo "[ERROR] Port $port is NOT listening!" | tee -a $LOGFILE
    fi
done

# Check disk space
DISK_USAGE=$(lxc exec tak -- df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "[OK] Disk usage: ${DISK_USAGE}%" | tee -a $LOGFILE
else
    echo "[WARNING] Disk usage: ${DISK_USAGE}% (high!)" | tee -a $LOGFILE
fi

# Check memory
FREE_MEM=$(lxc exec tak -- free -g | grep Mem: | awk '{print $4}')
if [ "$FREE_MEM" -gt 2 ]; then
    echo "[OK] Free memory: ${FREE_MEM}GB" | tee -a $LOGFILE
else
    echo "[WARNING] Free memory: ${FREE_MEM}GB (low!)" | tee -a $LOGFILE
fi

# Check for errors in last hour
ERROR_COUNT=$(lxc exec tak -- journalctl -u takserver --since "1 hour ago" | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "[OK] No errors in last hour" | tee -a $LOGFILE
else
    echo "[WARNING] $ERROR_COUNT errors in last hour" | tee -a $LOGFILE
fi

echo "=== Health check complete ===" | tee -a $LOGFILE
```

**Schedule with cron:**
```bash
# Run every hour
0 * * * * /root/check-tak-health.sh

# Or every 15 minutes for critical ops
*/15 * * * * /root/check-tak-health.sh
```

### 6.2 Log Monitoring

**Important Logs:**
```bash
# Main messaging log
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log

# API log
lxc exec tak -- tail -f /opt/tak/logs/takserver-api.log

# Config log
lxc exec tak -- tail -f /opt/tak/logs/takserver-config.log

# PostgreSQL log
lxc exec tak -- tail -f /var/log/postgresql/postgresql-14-main.log
```

**What to Watch For:**
- `ERROR` or `FATAL` messages
- `SSL handshake failure` (certificate issues)
- `Connection refused` (port/firewall issues)
- `Out of memory` (resource issues)
- `Database connection failed` (PostgreSQL issues)

### 6.3 Performance Metrics

**Monitor:**
- Active connections
- CoT messages per second
- Database size
- Memory usage
- CPU usage
- Disk I/O

**Check Connected Users:**
```bash
# Count active connections (approximate)
lxc exec tak -- grep "connection" /opt/tak/logs/takserver-messaging.log | tail -100 | grep -c "Connected"
```

**Check Database Size:**
```bash
lxc exec tak -- sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('cot'));"
```

---

## 7. Backup Procedures

### 7.1 What to Backup

**Critical Data:**
1. **Certificates:** `/opt/tak/certs/`
2. **Configuration:** `/opt/tak/CoreConfig.xml`
3. **PostgreSQL Database:** Full database dump
4. **Mission Data:** Data packages, files
5. **Logs:** Recent logs for troubleshooting history
6. **Documentation:** Certificate inventory, user lists, procedures

### 7.2 Manual Backup

**Full TAK Server Backup:**
```bash
# From VPS host
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p ~/backups/tak-${BACKUP_DATE}

# Backup certificates
lxc file pull -r tak/opt/tak/certs/ ~/backups/tak-${BACKUP_DATE}/

# Backup CoreConfig
lxc file pull tak/opt/tak/CoreConfig.xml ~/backups/tak-${BACKUP_DATE}/

# Backup PostgreSQL database
lxc exec tak -- sudo -u postgres pg_dump cot > ~/backups/tak-${BACKUP_DATE}/cot-database.sql

# Backup entire container (snapshot)
lxc snapshot tak tak-backup-${BACKUP_DATE}

# Verify
ls -lh ~/backups/tak-${BACKUP_DATE}/

# Compress for archiving
cd ~/backups
tar -czf tak-backup-${BACKUP_DATE}.tar.gz tak-${BACKUP_DATE}/
```

### 7.3 Automated Backup Script

**Save as: `/root/backup-tak.sh`**

```bash
#!/bin/bash
# TAK Server Automated Backup Script

BACKUP_DIR="/home/takadmin/backups"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="tak-backup-${DATE}"

mkdir -p ${BACKUP_DIR}

echo "Starting TAK Server backup: ${BACKUP_NAME}"

# Backup certificates
echo "Backing up certificates..."
lxc file pull -r tak/opt/tak/certs/ ${BACKUP_DIR}/${BACKUP_NAME}-certs/

# Backup CoreConfig
echo "Backing up CoreConfig.xml..."
lxc file pull tak/opt/tak/CoreConfig.xml ${BACKUP_DIR}/${BACKUP_NAME}-CoreConfig.xml

# Backup PostgreSQL
echo "Backing up PostgreSQL database..."
lxc exec tak -- sudo -u postgres pg_dump cot > ${BACKUP_DIR}/${BACKUP_NAME}-database.sql

# Create snapshot
echo "Creating container snapshot..."
lxc snapshot tak ${BACKUP_NAME}

# Compress
echo "Compressing backup..."
cd ${BACKUP_DIR}
tar -czf ${BACKUP_NAME}.tar.gz ${BACKUP_NAME}-*

# Cleanup temporary files
rm -rf ${BACKUP_NAME}-*

# Remove old backups
echo "Removing backups older than ${RETENTION_DAYS} days..."
find ${BACKUP_DIR} -name "tak-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup complete: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
```

**Schedule with cron:**
```bash
# Daily backup at 2 AM
0 2 * * * /root/backup-tak.sh >> /var/log/tak-backup.log 2>&1
```

### 7.4 Backup Verification

**Test restoration periodically:**
```bash
# Create test container
lxc copy tak tak-restore-test

# Restore database
lxc exec tak-restore-test -- sudo -u postgres psql cot < backup-database.sql

# Test functionality
lxc exec tak-restore-test -- systemctl status takserver

# Delete test container
lxc delete tak-restore-test --force
```

### 7.5 Off-Site Backup

**Strategies:**
1. **Cloud Storage:** Encrypted upload to cloud (Nextcloud, AWS S3)
2. **Remote Server:** SCP/rsync to remote server
3. **External Drive:** Weekly copy to external HDD (encrypted)
4. **Physical Media:** Monthly DVD/tape backup (secure storage)

**Encryption:**
```bash
# Encrypt backup before off-site storage
gpg --symmetric --cipher-algo AES256 tak-backup-${DATE}.tar.gz

# Creates: tak-backup-${DATE}.tar.gz.gpg
# Upload encrypted file only
```

---

## 8. Troubleshooting

### 8.1 TAK Server Won't Start

**Symptoms:** Service shows failed, no Java processes

**Check 1: PostgreSQL Running?**
```bash
lxc exec tak -- systemctl status postgresql

# If not running:
lxc exec tak -- systemctl start postgresql
lxc exec tak -- systemctl restart takserver
```

**Check 2: Port Conflicts?**
```bash
# Check if ports already in use
lxc exec tak -- ss -tulpn | grep -E "8089|8443|8446"

# If occupied, find process
lxc exec tak -- lsof -i :8089
```

**Check 3: Certificate Issues?**
```bash
# Verify certificates exist
lxc exec tak -- ls -lh /opt/tak/certs/files/

# Check CoreConfig.xml points to correct certs
lxc exec tak -- grep -i keystore /opt/tak/CoreConfig.xml
```

**Check 4: Check Logs**
```bash
lxc exec tak -- tail -100 /opt/tak/logs/takserver-messaging.log
lxc exec tak -- journalctl -u takserver -n 100
```

### 8.2 Users Can't Connect

**Systematic approach:**

**Level 1: Network**
```bash
# Can host reach TAK Server?
ping [YOUR_DOMAIN]

# Are ports open?
telnet [YOUR_DOMAIN] 8089
telnet [YOUR_DOMAIN] 8443
```

**Level 2: Server**
```bash
# Is TAK Server running?
lxc exec tak -- systemctl status takserver

# Are ports listening?
lxc exec tak -- ss -tulpn | grep 8089
```

**Level 3: Certificates**
```bash
# Is user's certificate valid?
cd /opt/tak/certs/files
keytool -list -v -keystore [YOUR_PREFIX]780.p12 -storepass [CERT_PASSWORD] | grep "Valid"

# Is certificate revoked?
openssl crl -in crl.pem -text -noout | grep -A 5 "Serial"
```

**Level 4: User Configuration**
- Does user exist in web UI?
- Is user in correct groups?

### 8.3 SSL Handshake Failures

**Common causes:**

1. **Server not restarted after cert change**
   ```bash
   lxc exec tak -- systemctl restart takserver
   ```

2. **Wrong hostname in client**
   - Client must connect to: `[YOUR_DOMAIN]`
   - NOT IP address
   - Must match server certificate CN

3. **Missing CA certificate on client**
   - Client needs truststore/CA cert
   - Extract from enrollmentDP.zip
   - Import into ATAK/WinTAK

4. **Expired certificate**
   ```bash
   keytool -list -v -keystore files/[YOUR_PREFIX]780.p12 -storepass [CERT_PASSWORD] | grep "Valid"
   ```

### 8.4 Performance Issues

**Slow response / lag:**

**Check 1: System Resources**
```bash
# Memory
lxc exec tak -- free -h

# CPU
lxc exec tak -- top

# Disk I/O
lxc exec tak -- iostat
```

**Check 2: Database Performance**
```bash
# Database size
lxc exec tak -- sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('cot'));"

# Active connections
lxc exec tak -- sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

**Check 3: Network**
```bash
# Check packet loss
ping -c 100 [YOUR_DOMAIN] | grep loss
```

**Solutions:**
- Increase container memory/CPU
- Optimize PostgreSQL
- Archive old missions
- Clean up old logs

### 8.5 Database Issues

**Database won't start:**
```bash
# Check PostgreSQL status
lxc exec tak -- systemctl status postgresql

# Check logs
lxc exec tak -- tail -100 /var/log/postgresql/postgresql-14-main.log

# Try restart
lxc exec tak -- systemctl restart postgresql
```

**Database corruption:**
```bash
# Stop TAK Server
lxc exec tak -- systemctl stop takserver

# Run PostgreSQL checks
lxc exec tak -- sudo -u postgres pg_isready

# Restore from backup if needed
lxc exec tak -- sudo -u postgres psql cot < backup-database.sql

# Restart TAK Server
lxc exec tak -- systemctl start takserver
```

---

## 9. Emergency Procedures

### 9.1 Complete Server Outage

**Rapid recovery checklist:**

**Step 1: Assess Situation (0-5 minutes)**
```bash
# Is container running?
lxc list

# Is host network up?
ping 8.8.8.8

# Can access host?
ssh takadmin@[VPS_IP]
```

**Step 2: Attempt Quick Restart (5-10 minutes)**
```bash
# Restart container
lxc restart tak

# Wait 30 seconds
sleep 30

# Check TAK Server
lxc exec tak -- systemctl status takserver

# Check ports
lxc exec tak -- ss -tulpn | grep -E "8089|8443|8446"
```

**Step 3: If Still Down, Restore Snapshot (10-20 minutes)**
```bash
# List snapshots
lxc info tak | grep -A 10 Snapshots

# Restore last good snapshot
lxc restore tak [snapshot-name]

# Restart container
lxc restart tak

# Verify
lxc exec tak -- systemctl status takserver
```

**Step 4: Communicate Outage (Throughout)**
```
Message to users:
"TAK Server experiencing technical difficulties. 
ETA for restoration: [time]
Alternate communications: [radio/phone]
Status updates every 15 minutes."
```

### 9.2 Security Incident

**Unauthorized access suspected:**

**Immediate Actions:**
1. **Isolate server**
   ```bash
   lxc config device remove tak eth0
   ```

2. **Review logs**
   ```bash
   lxc exec tak -- grep -i "failed\|authentication\|unauthorized" /opt/tak/logs/takserver-messaging.log
   ```

3. **Identify compromised certificates**

4. **Revoke compromised certificates**
   ```bash
   lxc exec tak -- bash
   cd /opt/tak/certs
   sudo ./makeCert.sh revoke [username]
   sudo ./makeCert.sh crl
   ```

5. **Change passwords**

6. **Document incident**

### 9.3 Data Loss

**Mission data accidentally deleted:**

**Recovery options:**

1. **Restore from backup**
   ```bash
   lxc exec tak -- sudo -u postgres psql cot < backup-database.sql
   ```

2. **Restore from snapshot**
   ```bash
   lxc restore tak [snapshot-before-deletion]
   ```

3. **Request data from users**
   - Users may have mission data locally

### 9.4 Disaster Recovery Plan

**Full site disaster (fire, flood, etc.):**

**Prerequisites:**
- Off-site backups (encrypted, tested)
- Documented procedures
- Contact list
- Hardware/software inventory
- Alternative hosting identified

**Recovery Process:**
1. Acquire new hardware or cloud hosting
2. Install Ubuntu 22.04/24.04 LTS
3. Setup LXD
4. Create container
5. Restore from backup
6. Update DNS
7. Test functionality
8. Notify users of new connection details

**RTO (Recovery Time Objective):** 4-8 hours  
**RPO (Recovery Point Objective):** 24 hours (daily backups)

---

## 10. Security Best Practices

### 10.1 Access Control

**Principle of Least Privilege:**
- Give users minimum permissions needed
- Limit admin accounts
- Regular review of permissions
- Remove access when no longer needed

**Admin Access:**
```bash
# Limit who can SSH to host
# Edit /etc/ssh/sshd_config
AllowUsers takadmin

# Use SSH keys, not passwords
PasswordAuthentication no
```

**Certificate Security:**
- Strong passwords (not default "atakatak")
- Secure distribution methods
- Track certificate inventory
- Rotate regularly

### 10.2 Network Security

**Firewall Rules:**
```bash
# Only allow necessary ports
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8089/tcp
ufw allow 8443/tcp
ufw allow 8446/tcp
ufw allow 9001/tcp
ufw enable
```

**Monitoring:**
- Log all access attempts
- Alert on failed authentications
- Review logs regularly

### 10.3 Data Protection

**Encryption:**
- All backups encrypted
- Certificates password-protected
- Secure certificate distribution
- HTTPS/SSL for all connections

**Data Retention:**
- Define retention policy
- Archive old missions
- Delete when no longer needed
- Document deletions

### 10.4 Incident Response

**Preparation:**
- Document procedures
- Contact list (IT, management, users)
- Backup communication methods
- Alternative TAK Server (if possible)

**Detection:**
- Monitor logs for anomalies
- Automated alerts
- User reports

**Response:**
- Isolate if compromised
- Investigate
- Mitigate
- Recover
- Document

**Recovery:**
- Restore from clean backup
- Verify integrity
- Update credentials
- Notify users
- Post-incident review

---

## 11. Multi-Agency Coordination

### 11.1 Federation Setup

**Purpose:** Share data between TAK Servers ([YOUR_ORG], [PARTNER_ORG], State)

**Not covered in detail here** - see TAK Server federation documentation

**Key Concepts:**
- Federated servers exchange data
- Groups control what's shared
- SSL certificates for authentication
- Trust relationships

### 11.2 Shared Missions

**Multi-agency incidents:**

**Setup:**
1. Create mission on one agency's server
2. Configure groups:
   - [YOUR_ORG] groups
   - [PARTNER_ORG] groups
   - Mutual aid groups
3. Invite users from all agencies
4. All users subscribe to mission

**Best Practices:**
- Clear naming: "Multi-Agency - [Incident]"
- Unified command structure
- Defined data sharing rules
- Communication plan

### 11.3 Mutual Aid Users

**Temporary access for external agencies:**

**Process:**
1. Request certificate in advance
2. Use "Mutual Aid" naming: `MUTUAL-AGENCY-UNIT`
3. Example: `MUTUAL-[MUTUAL_AID_ORG]-E1` ([MUTUAL_AID_ORG] Engine 1)
4. Add to "Mutual Aid" group only
5. Limited mission access
6. Revoke after incident

---

## 12. Training & Documentation

### 12.1 User Training

**New User Onboarding:**
1. Basic TAK/ATAK training
2. Certificate installation
3. Mission subscription
4. Data entry (markers, photos)
5. CoT creation
6. Mission tools

**Ongoing Training:**
- Quarterly refreshers
- New feature training
- Scenario-based exercises
- Multi-agency drills

### 12.2 Admin Documentation

**Maintain:**
- Installation procedures
- Configuration backup
- Certificate inventory
- User list
- Group structure
- Troubleshooting guide
- Change log
- Incident reports

### 12.3 Standard Operating Procedures (SOPs)

**Create SOPs for:**
- New user creation
- Certificate renewal
- Mission creation
- Backup procedures
- Emergency procedures
- Security incident response

---

## Quick Reference

### Essential Commands

```bash
# Check status
lxc exec tak -- systemctl status takserver

# Restart TAK Server
lxc exec tak -- systemctl restart takserver

# View logs
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log

# Create certificate
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh client USERNAME

# Revoke certificate
sudo ./makeCert.sh revoke USERNAME
sudo ./makeCert.sh crl
sudo systemctl restart takserver

# Backup
lxc snapshot tak tak-backup-$(date +%Y%m%d)

# Check connections
lxc exec tak -- ss -tulpn | grep -E "8089|8443|8446"
```

### Important Files

```
/opt/tak/CoreConfig.xml              - Main configuration
/opt/tak/certs/                      - Certificates
/opt/tak/logs/takserver-messaging.log - Main log
/opt/tak/logs/takserver-api.log      - API log
/etc/systemd/system/takserver.service - Service file
```

### Web UI URLs

```
https://[YOUR_DOMAIN]:8443        - Admin interface
https://[YOUR_DOMAIN]:8443/webtak  - WebTAK (if enabled)
https://[YOUR_DOMAIN]:8446         - Certificate enrollment
```

---

## Additional Resources

- **[04-CERTIFICATE-MANAGEMENT.md](04-CERTIFICATE-MANAGEMENT.md)** - Certificate procedures
- **[CERTIFICATE-RENEWAL-USER-GUIDE.md](CERTIFICATE-RENEWAL-USER-GUIDE.md)** - User instructions
- **TAK.gov:** https://tak.gov/docs
- **TAK Community:** https://community.tak.gov

---

*Last Updated: [DATE]*  
*Version: 1.0*  
*For: TAK Server 5.5 in LXD containers*  
*Organization: [YOUR_ORG_FULL]*
