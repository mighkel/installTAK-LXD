# TAK Server Administration Guide

**Comprehensive guide for TAK Server administrators in emergency services**

This guide covers day-to-day operations, user management, troubleshooting, and best practices for TAK Server running in LXD containers.

**Target Audience:** TAK Server administrators, IT staff, GIS/communications coordinators for emergency services agencies.

**Deployment Context:** TAK Server 5.5 running in LXD container on Ubuntu host.

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
- ✅ takserver service: "active (exited)" - normal
- ✅ 5+ Java processes running
- ✅ All ports (8089, 8443, 8446, 9001) listening
- ✅ No critical errors in last 24 hours
- ✅ Disk usage < 80%
- ✅ Memory available > 2GB

### 1.2 Check Connected Users

**Web UI Method:**
1. Access: https://tak.pinenut.tech:8443
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
- `CCFIRE780` - Clear Creek Fire, Unit 780, ATAK
- `CCFIRE780-wt` - Same user, WinTAK
- `BCSO2240` - Boise County Sheriff's Office, Unit 2240
- `IDACOM123-it` - Idaho Communications, ID 123, iTAK

**Device Suffixes:**
- *(none)* - ATAK (default/primary)
- `-wt` - WinTAK
- `-it` - iTAK  
- `-ta` - TAKAware
- `-tx` - TAK-X
- `-bk` - Backup device
- `-tr` - Training device

### 2.2 Creating New User

**Prerequisites:**
- Username decided (follow naming convention)
- User's full name and contact info
- Agency and unit/personnel number
- Device type
- Intended access level (which groups)

**Step 1: Create Certificate**
```bash
# Get shell in container
lxc exec tak -- bash

cd /opt/tak/certs

# Create certificate
sudo ./makeCert.sh client CCFIRE780

# Certificate created: /opt/tak/certs/files/CCFIRE780.p12
```

**Step 2: Copy Certificate to Host**
```bash
# Exit container
exit

# From VPS host
lxc file pull tak/opt/tak/certs/files/CCFIRE780.p12 ~/CCFIRE780.p12

# Download to your local machine
scp takadmin@your-vps-ip:~/CCFIRE780.p12 ./
```

**Step 3: Create User in Web UI**
1. Access: https://tak.pinenut.tech:8443
2. Login with webadmin.p12
3. User Manager → "Add User"
4. Fill in:
   - Username: `CCFIRE780` (must match certificate)
   - Password: (for enrollment - if using enrollment)
   - First Name: `[User's first name]`
   - Last Name: `[User's last name]`
   - Role: `USER` (or `ADMIN` for admins)
5. Add to appropriate groups (see Group Management)
6. Save

**Step 4: Distribute Certificate**
- Send CCFIRE780.p12 to user
- Send certificate password: `atakatak` (or your password)
- Send installation instructions
- Send enrollment package (enrollmentDP.zip) if using enrollment

**Step 5: Document in Inventory**
Add to certificate inventory spreadsheet:
- Username: CCFIRE780
- Device: ATAK on Samsung tablet
- Person: Fire Chief John Smith
- Contact: (208)555-0780
- Issued: 2025-11-24
- Expires: 2027-11-24
- Status: Active
- Groups: Fire Operations, Leadership, All Users

### 2.3 Multi-Device User Setup

**Scenario:** User needs ATAK and WinTAK

**Step 1: Create Primary Certificate (ATAK)**
```bash
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh client CCFIRE780
exit

lxc file pull tak/opt/tak/certs/files/CCFIRE780.p12 ~/CCFIRE780.p12
```

**Step 2: Create Secondary Certificate (WinTAK)**
```bash
lxc exec tak -- bash
cd /opt/tak/certs
sudo ./makeCert.sh client CCFIRE780-wt
exit

lxc file pull tak/opt/tak/certs/files/CCFIRE780-wt.p12 ~/CCFIRE780-wt.p12
```

**Step 3: Add Both to Web UI**
Create two users:
1. Username: `CCFIRE780` (ATAK)
2. Username: `CCFIRE780-wt` (WinTAK)

**Step 4: Add Both to Same Groups**
Create a meta-group:
- Group name: "CCFIRE780 - All Devices"
- Members: CCFIRE780, CCFIRE780-wt

Then add meta-group to operational groups:
- Group "Fire Operations" → Add "CCFIRE780 - All Devices"

**Benefit:** User sees same missions on both devices

### 2.4 Editing Users

**Change User Groups:**
1. Web UI → User Manager
2. Search for user: `CCFIRE780`
3. Click username
4. Modify groups (add/remove)
5. Save

**Change User Role:**
1. Web UI → User Manager
2. Click username
3. Change role: USER → ADMIN (or vice versa)
4. Save

**Note:** Cannot change username. To rename, must:
1. Create new user with new name
2. Migrate groups/permissions
3. Delete old user
4. User loses mission subscriptions (bad!)

**Recommendation:** Get username right the first time!

### 2.5 Disabling vs Deleting Users

**Disable User (Temporary):**
1. Revoke certificate (see Certificate Management)
2. Keep user in database
3. User can be re-enabled with new certificate

**Delete User (Permanent):**
1. Web UI → User Manager
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
keytool -list -v -keystore CCFIRE780.p12 -storepass atakatak | grep "Valid"
```

**Check 2: Certificate Revoked?**
```bash
openssl crl -in crl.pem -text -noout | grep -A 5 "Serial"
# If cert serial appears here, it's revoked
```

**Check 3: User Exists in Web UI?**
1. Web UI → User Manager
2. Search: CCFIRE780
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
- **Organizational:** Based on agency (CCVFD, BCSO)
- **Functional:** Based on role (Leadership, Operations, Support)
- **Operational:** Based on mission type (Fire Ops, Law Enforcement, Medical)
- **Meta:** Groups of users (multi-device users)

### 3.2 Recommended Group Structure

**For Clear Creek VFD / Boise County SO:**

```
All Users (Everyone)
├── CCVFD (All CCVFD Personnel)
│   ├── CCVFD Leadership
│   ├── CCVFD Operations
│   ├── CCVFD Support
│   └── CCVFD Training
├── BCSO (All Sheriff's Office)
│   ├── BCSO Leadership
│   ├── BCSO Patrol
│   ├── BCSO Investigations
│   └── BCSO Support
├── Mutual Aid (External agencies)
│   ├── State Resources
│   └── Federal Resources
└── Special Operations
    ├── Incident Command
    ├── SAR Operations
    └── Hazmat Operations
```

**Meta-Groups for Multi-Device Users:**
```
User-Specific Device Groups
├── CCFIRE780 - All Devices
│   ├── CCFIRE780 (ATAK)
│   ├── CCFIRE780-wt (WinTAK)
│   └── CCFIRE780-it (iTAK)
├── BCSO2240 - All Devices
│   ├── BCSO2240 (ATAK)
│   └── BCSO2240-wt (WinTAK)
```

### 3.3 Creating Groups

**Web UI Method:**
1. Access: https://tak.pinenut.tech:8443
2. Data Sync → Groups
3. Click "Add Group"
4. Fill in:
   - Group Name: `CCVFD Operations`
   - Description: `CCVFD operational personnel`
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
1. Groups → Select group
2. Click "Add Member"
3. Search for user: `CCFIRE780`
4. Add user
5. Save

**Multiple Users:**
1. Create list of usernames
2. Add each to group
3. Or create parent group and add all at once

**Multi-Device User:**
1. Create meta-group: "CCFIRE780 - All Devices"
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
1. Access: https://tak.pinenut.tech:8443
2. Data Sync → Missions
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
1. ATAK → Mission
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
- `Daily Ops - CCVFD - 2025-11-24`

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
1. Web UI → Data Sync → Missions
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
1. Web UI → Mission
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
1. Web UI → User Manager → Find user
2. Check groups
3. Compare to mission's allowed groups

**Check 2: Mission Access Settings**
1. Web UI → Missions → Click mission
2. Check "Allowed Groups"
3. Add user's group if missing

**Check 3: User Subscribed?**
Users must subscribe to missions in ATAK:
1. ATAK → Mission
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
1. Web UI → User Manager
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
    keytool -list -v -keystore "$cert" -storepass atakatak 2>/dev/null | grep "Valid until"
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
sudo ./makeCert.sh revoke CCFIRE780
sudo ./makeCert.sh crl
sudo systemctl restart takserver
```

**Issue Replacement:**
```bash
# New cert with same name (if same person, new device)
sudo ./makeCert.sh client CCFIRE780

# Or backup designation (if using backup device)
sudo ./makeCert.sh client CCFIRE780-bk
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
- Access URL: `https://tak.pinenut.tech:8443`

**What you can do with it:**
- ✅ Full server administration
- ✅ User management (create, delete, modify users)
- ✅ Group management (create groups, assign members)
- ✅ Mission management (view, delete missions)
- ✅ View server status and logs
- ✅ Configuration changes
- ✅ Certificate management via web UI
- ✅ Database queries and reports

**What you CANNOT do:**
- ❌ Use in ATAK/WinTAK/iTAK (won't work)
- ❌ Connect to TAK Server as a field client
- ❌ Create missions from the field
- ❌ Send/receive CoT data

**Protocol:** HTTPS client certificate authentication  
**Port:** 8443

**Real-world usage:**
```
Fire Chief sits down at office computer:
1. Opens Firefox (webadmin.p12 already imported)
2. Goes to https://tak.pinenut.tech:8443
3. Browser automatically presents webadmin.p12
4. Creates new user certificate for rookie firefighter
5. Adds user to "CCVFD Operations" group
6. Checks server health
7. Closes browser
```

**Distribution:**
- Import into browser on administrator's office computer
- Can be shared among multiple administrators
- Each admin imports same webadmin.p12 into their browser
- Password protect when distributing

**Important:** This certificate has **complete control** over the TAK Server. Treat it like a root password.

#### Type 2: Regular User Certificates (CCFIRE750.p12, CCFIRE760.p12, etc.)

**Purpose:** Client authentication for ATAK/WinTAK/iTAK field applications

**Created:** Manually by administrator for each user/device

**Used in:**
- ATAK (Android)
- WinTAK (Windows)
- iTAK (iOS)
- TAKAware
- TAK-X

**What you can do with it:**
- ✅ Connect to TAK Server
- ✅ Send/receive CoT data
- ✅ View missions (based on group membership)
- ✅ Subscribe to missions
- ✅ Add data to missions (markers, photos, files)
- ✅ View other users on map
- ✅ Send messages
- ✅ Access Data Sync

**What you CANNOT do (unless admin role assigned):**
- ❌ Access web UI at :8443
- ❌ Create/delete users
- ❌ Manage server configuration

**Protocol:** SSL/TLS client certificate authentication  
**Port:** 8089 (main), 8446 (enrollment)

**Real-world usage:**
```
Firefighter CCFIRE760 in the field:
1. Opens ATAK on tablet
2. ATAK connects using CCFIRE760.p12
3. Sees current missions based on group membership
4. Subscribes to "Structure Fire - 123 Main St" mission
5. Drops markers on map
6. Takes photos and uploads to mission
7. Sends position updates (CoT)
8. Coordinates with other firefighters on mission
```

**Distribution:**
- One certificate per user per device
- Follow naming convention: CCFIRE760, CCFIRE760-wt, etc.
- Secure distribution (encrypted channels)
- User imports into ATAK/WinTAK
- Track in certificate inventory

**Important:** Each user gets their own certificate. Never share certificates between users.

#### Type 3: The "admin.p12" File (Generic Admin Certificate)

**Created:** During TAK Server installation  
**Location:** `/opt/tak/certs/files/admin.p12`

**Purpose (Theoretical):**
- Generic admin-level client certificate
- Pre-created for convenience
- Has admin role by default

**Purpose (Reality):**
- **Typically never used**
- Better to create named certificates with admin roles
- Sits unused in certs directory

**Why you shouldn't use it:**
- Doesn't follow naming convention
- Can't track who's using it
- Can't tell which device it's on
- Difficult to revoke if compromised
- No accountability

**What to do instead:**

**Best Practice for CCVFD:**
```bash
# Don't use admin.p12
# Instead, create certificates for actual personnel:

# Fire Chief (needs admin privileges)
cd /opt/tak/certs
sudo ./makeCert.sh client CCFIRE750      # Chief's ATAK
sudo ./makeCert.sh client CCFIRE750-wt   # Chief's WinTAK

# Then in Web UI:
# User Manager → Find "CCFIRE750"
# Change Role: USER → ADMIN
# Save

# Now CCFIRE750 has admin privileges in ATAK/WinTAK
# Plus follows your naming convention
# Plus you know exactly who has admin access
```

**Summary:**
```
❌ Don't use: admin.p12 (generic, untraceable)
✅ Do use: CCFIRE750.p12 with admin role assigned
```

The generic `admin.p12` file will just sit in `/opt/tak/certs/files/` forever unused. That's fine and normal.

#### Certificate Comparison Chart

| Feature | webadmin.p12 | CCFIRE750.p12 (with admin role) | CCFIRE760.p12 (regular user) |
|---------|--------------|----------------------------------|------------------------------|
| **Access Web UI** | ✅ Yes | ❌ No | ❌ No |
| **Use in ATAK** | ❌ No | ✅ Yes | ✅ Yes |
| **Manage users** | ✅ Via Web UI | ❌ No | ❌ No |
| **Create missions** | ✅ Via Web UI | ✅ From ATAK | ✅ From ATAK |
| **Delete missions** | ✅ Via Web UI | ✅ From ATAK | ❌ No |
| **View all users** | ✅ Yes | ❌ No | ❌ No |
| **Change server config** | ✅ Yes | ❌ No | ❌ No |
| **Send CoT** | ❌ No | ✅ Yes | ✅ Yes |
| **Field operations** | ❌ No | ✅ Yes | ✅ Yes |
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

**Example Setup for CCVFD:**

```
Leadership (Admin Role):
- CCFIRE750 (Chief) → ADMIN role
- CCFIRE751 (Asst Chief) → ADMIN role
- CCFIRE752-759 (Officers) → ADMIN role (as appropriate)

Operations (User Role):
- CCFIRE760-779 (Firefighters) → USER role

Web Administration:
- webadmin.p12 → Used by Chief, Asst Chief, or IT/Communications staff
- Imported into office computers
```

#### Real-World Scenarios

**Scenario 1: Fire Chief Full Setup**

**Person:** Fire Chief (CCFIRE750)

**Needs:**
1. Server administration from office
2. Field operations with admin privileges
3. Command vehicle operations

**Certificates:**
```
1. webadmin.p12
   - Import into Firefox on office computer
   - Use for: Creating users, managing groups, checking server health
   
2. CCFIRE750.p12 (ADMIN role)
   - Import into ATAK on Samsung tablet
   - Use for: Field operations, mission creation/management
   
3. CCFIRE750-wt.p12 (ADMIN role)
   - Import into WinTAK on command vehicle laptop
   - Use for: Command vehicle operations, larger screen
```

**Workflow:**

```
Monday morning at station:
- Office computer → webadmin.p12 → Create certificate for new recruit
- Add CCFIRE778 to "CCVFD Operations" group

Structure fire callout:
- Grab tablet → ATAK (CCFIRE750.p12)
- Create mission "Structure Fire - 456 Oak St"
- Invite all responding units
- Manage tactical operations

Command vehicle on-scene:
- Laptop → WinTAK (CCFIRE750-wt.p12)
- Same mission visible
- Better overview on larger screen
- Coordinate with mutual aid (WRFIRE250, etc.)
```

**Scenario 2: Regular Firefighter Setup**

**Person:** Firefighter (CCFIRE760)

**Needs:**
1. Field operations only
2. No server administration
3. Phone for ATAK

**Certificates:**
```
1. CCFIRE760.p12 (USER role)
   - Import into ATAK on phone
   - Use for: All field operations
   
2. (Optional) CCFIRE760-wt.p12 (USER role)
   - Import into WinTAK on personal laptop
   - Use for: Training, mission review at home
```

**What they can do:**
- ✅ Connect to TAK Server
- ✅ Subscribe to missions
- ✅ Drop markers
- ✅ Take photos and upload
- ✅ Send messages
- ✅ View other units

**What they cannot do:**
- ❌ Access web UI
- ❌ Create/delete users
- ❌ Delete missions (unless admin grants permission)
- ❌ Change server settings

**Scenario 3: Communications/IT Staff Setup**

**Person:** Communications officer or IT staff (not actively responding to incidents)

**Needs:**
1. Server administration
2. Minimal field operations (testing/support only)
3. Office access primarily

**Certificates:**
```
1. webadmin.p12
   - Import into browser
   - Use for: All server administration tasks
   
2. (Optional) Create CCFIRE7XX.p12 (USER or ADMIN role)
   - For testing purposes
   - Verify user experience
   - Troubleshoot connection issues
```

**Typical tasks:**
- Create user certificates
- Manage groups
- Monitor server health
- Apply updates
- Backup server
- Troubleshoot issues

#### Common Questions

**Q: Can I use webadmin.p12 in ATAK?**  
A: No. Different certificate types, different protocols. webadmin.p12 only works in web browsers for the :8443 web UI.

**Q: Can I use my ATAK certificate (CCFIRE760.p12) in the web browser?**  
A: No. It won't authenticate to the web UI. You need webadmin.p12 for that.

**Q: Do I need both webadmin.p12 and CCFIRE750.p12 if I'm the chief?**  
A: If you want both server administration (from office) AND field operations (from ATAK), then yes, you need both. They serve different purposes.

**Q: What's the difference between ADMIN role and webadmin.p12?**  
A: 
- **ADMIN role** (CCFIRE750.p12): Enhanced privileges **within ATAK/WinTAK** (can delete missions, manage mission access)
- **webadmin.p12**: Full server administration **via web browser** (manage users, groups, server config)

**Q: Should I ever use the admin.p12 file created during install?**  
A: No. Create named certificates (CCFIRE750, etc.) and assign ADMIN role instead. Better tracking and accountability.

**Q: How many people should have webadmin.p12?**  
A: As few as necessary. Typically:
- Fire Chief
- Assistant Chief (if helping with admin)
- Communications/IT officer
Maybe 1-3 people total. It's powerful - limit access.

**Q: Can multiple people use the same webadmin.p12?**  
A: Technically yes (they all import the same file), but then you can't tell who did what in the logs. Better to create separate webadmin certs if you need multiple web admins (advanced topic).

**Q: Boise County Sheriff's Office wants TAK Server access. Do they need webadmin.p12?**  
A: No! They just need their own client certificates (BCSO2230, BCSO2231, etc.). Only YOUR administrators need webadmin.p12 for YOUR server. BCSO users are just regular users from your server's perspective.

**Q: What about Wilderness Ranch Fire or other mutual aid departments?**  
A: Same as above - they get regular client certificates (WRFIRE250, WRFIRE251, etc.). Only administrators of THIS server need webadmin.p12.

#### Certificate Security Summary

**webadmin.p12:**
- 🔒 Extremely sensitive
- Treat like root password
- Secure storage
- Limited distribution (1-3 people max)
- Track who has access
- Revoke/recreate if compromised

**User certificates (CCFIRE750.p12, etc.):**
- 🔒 Sensitive
- One per person per device
- Secure distribution
- Track in inventory
- Rotate every 1-2 years
- Revoke if device lost

**admin.p12 (generic):**
- ⚠️ Don't use
- Sits unused
- That's okay and normal

#### Summary: What You Actually Need

**For Clear Creek VFD TAK Server:**

```
1 × webadmin.p12
   → Imported into office computers (Chief, IT/Comms staff)
   → Server administration via web UI
   → Tightly controlled access

∞ × CCFIRE###.p12 certificates
   → One for each person, per device
   → Follow naming convention (750-779)
   → Assign ADMIN or USER role as appropriate
   → Track in inventory

∞ × WRFIRE###.p12, BCSO####.p12, etc.
   → For mutual aid and multi-agency users
   → Regular USER role (unless they're incident commanders)
   → Track in inventory
   
0 × admin.p12 usage
   → Ignore this file
   → Never distribute it
   → It just exists, that's fine
```

**Clean, organized, traceable, secure.**

---

## 6. Monitoring & Health Checks

### 6.1 Automated Monitoring Script

**Save as: `/root/check-tak-health.sh`**

```bash
#!/bin/bash
# TAK Server Health Check Script

LOGFILE="/var/log/tak-health-check.log"
EMAIL="admin@clearcrk.org"

echo "=== TAK Server Health Check - $(date) ===" | tee -a $LOGFILE

# Check container running
if lxc info tak > /dev/null 2>&1; then
    echo "[OK] Container 'tak' is running" | tee -a $LOGFILE
else
    echo "[ERROR] Container 'tak' is not running!" | tee -a $LOGFILE
    # Send alert email
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
echo "" | tee -a $LOGFILE
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
- ❌ `ERROR` or `FATAL` messages
- ⚠️ `SSL handshake failure` (certificate issues)
- ⚠️ `Connection refused` (port/firewall issues)
- ⚠️ `Out of memory` (resource issues)
- ⚠️ `Database connection failed` (PostgreSQL issues)

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

# Copy to secure off-site storage
# scp tak-backup-${BACKUP_DATE}.tar.gz user@backup-server:~/
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

# Remove old snapshots
lxc info tak | grep -E "tak-backup-" | awk '{print $1}' | while read snap; do
    SNAP_AGE=$(lxc info tak | grep -A 5 "$snap" | grep "Created:" | awk '{print $2}')
    # Add date comparison logic here if needed
done

echo "Backup complete: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
```

**Schedule with cron:**
```bash
# Daily backup at 2 AM
0 2 * * * /root/backup-tak.sh >> /var/log/tak-backup.log 2>&1

# Weekly full backup on Sunday
0 3 * * 0 /root/backup-tak-full.sh >> /var/log/tak-backup-full.log 2>&1
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
ping tak.pinenut.tech

# Are ports open?
telnet tak.pinenut.tech 8089
telnet tak.pinenut.tech 8443
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
keytool -list -v -keystore CCFIRE780.p12 -storepass atakatak | grep "Valid"

# Is certificate revoked?
openssl crl -in crl.pem -text -noout | grep -A 5 "Serial"
```

**Level 4: User Configuration**
```bash
# Does user exist in web UI?
# Web UI → User Manager → Search for CCFIRE780

# Is user in correct groups?
# Check group membership
```

### 8.3 SSL Handshake Failures

**Common causes:**

1. **Server not restarted after cert change**
   ```bash
   lxc exec tak -- systemctl restart takserver
   ```

2. **Wrong hostname in client**
   - Client must connect to: `tak.pinenut.tech`
   - NOT IP address
   - Must match server certificate CN

3. **Missing CA certificate on client**
   - Client needs truststore/CA cert
   - Extract from enrollmentDP.zip
   - Import into ATAK/WinTAK

4. **Expired certificate**
   ```bash
   # Check expiration
   keytool -list -v -keystore files/CCFIRE780.p12 -storepass atakatak | grep "Valid"
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

# Slow queries
lxc exec tak -- sudo -u postgres psql -c "SELECT query, state, query_start FROM pg_stat_activity WHERE state != 'idle' ORDER BY query_start;"
```

**Check 3: Network**
```bash
# Check bandwidth usage
iftop

# Check packet loss
ping -c 100 tak.pinenut.tech | grep loss
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
ssh takadmin@your-vps-ip
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

**Step 4: If Snapshot Fails, Restore from Backup (20-60 minutes)**
```bash
# Create new container
lxc copy tak tak-failed
lxc delete tak
lxc launch ubuntu:22.04 tak

# Restore certificates
lxc file push -r ~/backups/latest/certs/ tak/opt/tak/

# Restore database
lxc file push ~/backups/latest/database.sql tak/tmp/
lxc exec tak -- sudo -u postgres psql cot < /tmp/database.sql

# Reinstall TAK Server
# Follow installation guide
```

**Step 5: Communicate Outage (Throughout)**
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
   # Disable network
   lxc config device remove tak eth0
   ```

2. **Review logs**
   ```bash
   lxc exec tak -- grep -i "failed\|authentication\|unauthorized" /opt/tak/logs/takserver-messaging.log
   ```

3. **Identify compromised certificates**
   - Review recent connections
   - Check for unusual user activity

4. **Revoke compromised certificates**
   ```bash
   lxc exec tak -- bash
   cd /opt/tak/certs
   sudo ./makeCert.sh revoke [username]
   sudo ./makeCert.sh crl
   ```

5. **Change passwords**
   - Web UI admin password
   - Certificate password (for new certs)
   - PostgreSQL password
   - Host system passwords

6. **Document incident**
   - Timeline of events
   - Affected users/data
   - Actions taken
   - Lessons learned

### 9.3 Data Loss

**Mission data accidentally deleted:**

**Recovery options:**

1. **Restore from backup**
   ```bash
   # Restore database
   lxc exec tak -- sudo -u postgres psql cot < backup-database.sql
   ```

2. **Restore from snapshot**
   ```bash
   lxc restore tak [snapshot-before-deletion]
   ```

3. **Request data from users**
   - Users may have mission data locally
   - Can upload from ATAK data packages

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
# Disable password authentication
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
# TAK Server: 8089, 8443, 8446, 9001
# SSH: 22
# HTTP/HTTPS: 80, 443 (for Let's Encrypt/HAProxy)

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

**Purpose:** Share data between TAK Servers (CCVFD, BCSO, State)

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
   - CCVFD groups
   - BCSO groups
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
3. Example: `MUTUAL-GCFD-E1` (Garden City FD Engine 1)
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
https://tak.pinenut.tech:8443        - Admin interface
https://tak.pinenut.tech:8443/webtak  - WebTAK (if enabled)
https://tak.pinenut.tech:8446         - Certificate enrollment
```

---

## Additional Resources

- **[04-CERTIFICATE-MANAGEMENT.md](04-CERTIFICATE-MANAGEMENT.md)** - Certificate procedures
- **[CERTIFICATE-RENEWAL-USER-GUIDE.md](CERTIFICATE-RENEWAL-USER-GUIDE.md)** - User instructions
- **TAK.gov:** https://tak.gov/docs
- **TAK Community:** https://community.tak.gov

---

*Last Updated: November 2025*  
*Version: 1.0*  
*For: TAK Server 5.5 in LXD containers*  
*Agencies: Clear Creek VFD, Boise County SO*
