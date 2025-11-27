# Container Setup Guide

**Phase 2: Creating and configuring the TAK Server LXD container**

This guide assumes you've completed [Phase 1: LXD Setup](01-LXD-SETUP.md) and all verification checks passed.

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

**Where Am I? (Check Your Prompt)**
| Prompt Looks Like | You Are |
|-------------------|---------|
| `user@your-vps-name:~$` | 🖥️ VPS Host |
| `root@tak:~#` | 📦 Inside container (as root) |
| `takadmin@tak:~$` | 📦 Inside container (as takadmin) |

> 💡 **TIP: Exiting Containers**  
> If you're `takadmin@tak`, type `exit` twice to get back to VPS host:
> 1. First `exit`: takadmin → root (still in container)
> 2. Second `exit`: root in container → VPS host

**Placeholders used in this document:**
- `[YOUR_DOMAIN]` - Your TAK server domain (e.g., `tak.example.com`)
- `[YOUR_VPS_IP]` - Your VPS public IP address
- TAK Container IP: 10.100.100.10 (static, assigned during container creation)
- HAProxy Container IP: 10.100.100.11 (assigned in Phase 5)
- `[##]` - TAK Server release number (e.g., `58` in `takserver-5.5-RELEASE58_all.deb`)

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_VPS_IP]` becomes `203.0.113.50`
> (Keep any surrounding quotes, remove the brackets)

---

## Prerequisites

Before starting Phase 2, verify:

- [ ] LXD is installed and initialized
- [ ] `lxc list` works without sudo
- [ ] UFW is configured with TAK ports open
- [ ] IP forwarding is enabled
- [ ] Test container successfully reached internet

**If any of these are not complete, go back to Phase 1.**

---

## Step 1: Create the TAK Container

🖥️ **VPS Host**

### 1.1 Launch Ubuntu Container

```bash
# Launch Ubuntu 22.04 container named 'tak' on takbr0 network
lxc launch ubuntu:22.04 tak --network takbr0

# Assign static IP for predictable networking
lxc config device override tak eth0 ipv4.address=10.100.100.10

# Wait a few seconds for it to fully start
sleep 10

# Verify it's running
lxc list
```

**Expected output:**
```
+------+---------+----------------------+------+------------+-----------+
| NAME |  STATE  |         IPV4         | IPV6 |    TYPE    | SNAPSHOTS |
+------+---------+----------------------+------+------------+-----------+
| tak  | RUNNING | 10.100.100.10 (eth0) |      | CONTAINER  | 0         |
+------+---------+----------------------+------+------------+-----------+
```

💡 STATIC IP ASSIGNED
Your TAK container IP is 10.100.100.10. This is pre-configured for the HAProxy setup in Phase 5.

### 1.2 Verify Container Networking

🖥️ **VPS Host**

**Critical: Test networking before proceeding!**

```bash
# Test internet connectivity
lxc exec tak -- ping -c 3 1.1.1.1

# Test DNS resolution
lxc exec tak -- ping -c 3 google.com

# Test apt repositories
lxc exec tak -- apt update
```

**All three tests must succeed.** If any fail, stop and troubleshoot networking (see Phase 1 troubleshooting).

---

## Step 2: Initial Container Configuration

### 2.1 Access the Container

🖥️ **VPS Host**

```bash
# Get a shell in the container
lxc exec tak -- bash

# You're now inside the container!
# Prompt should show: root@tak:~#
```

### 2.2 Update the Container

📦 **Inside Container**

```bash
# Update and upgrade packages
apt update && apt upgrade -y

# Install basic utilities
apt install -y nano curl wget net-tools

# Clean up
apt autoremove -y
```

### 2.3 Set Container Timezone (Optional)

📦 **Inside Container**

```bash
# Check current timezone
timedatectl

# List available timezones
timedatectl list-timezones | grep America

# Set to your timezone (example)
timedatectl set-timezone America/Denver

# Or use UTC (recommended for servers serving multiple timezones)
# timedatectl set-timezone UTC

# Verify
date
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `America/Denver` with your actual timezone. Use `timedatectl list-timezones` to find yours.

---

## Step 3: Create TAK Admin User in Container

**Best Practice:** Don't run TAK Server as root inside the container.

📦 **Inside Container**

### 3.1 Create takadmin User

```bash
# Create user (still inside the container)
adduser takadmin

# Follow prompts:
# - Enter password: [choose a strong password]
# - Full Name: TAK Administrator
# - Room Number: [press Enter]
# - Work Phone: [press Enter]
# - Home Phone: [press Enter]
# - Other: [press Enter]
# - Is the information correct? Y

# Add to sudo group
usermod -aG sudo takadmin

# Test sudo access
su - takadmin
sudo whoami  # Should output: root

# Exit back to root (still inside container)
exit
```

> 💡 **WHERE ARE YOU NOW?**  
> After this step, you should still be **root inside the container** (prompt: `root@tak:~#`).  
> - One `exit` = back to root in container  
> - Two `exit` commands = back to VPS host  
> 
> Stay inside the container for the next steps.

### 3.2 Document the Password

> ⛔ **CRITICAL: SAVE THIS PASSWORD**  
> Store this password in a secure location (password manager recommended).
> ```
> Container: tak
> User: takadmin
> Password: [your chosen password]
> IP: [CONTAINER_IP from lxc list]
> ```

---

## Step 4: Install Basic Prerequisites

The installTAK script will handle PostgreSQL and Java installation automatically. We only need basic tools.

📦 **Inside Container** (as root)

### 4.1 Install Essential Utilities

```bash
# Install basic tools needed for installation
apt install -y \
    wget \
    curl \
    git \
    unzip \
    zip \
    python3 \
    python3-pip \
    net-tools \
    vim \
    nano

# Verify installations
which git       # Should show path
which python3   # Should show path
which curl      # Should show path
```

### 4.2 Install gdown (for Google Drive file fetching)

```bash
# Upgrade pip and install gdown
pip3 install --upgrade pip && pip3 install gdown

# Verify installation
gdown --version
```

**Expected output:**
```
gdown 5.2.0 at /usr/local/lib/python3.10/dist-packages
```

> 💡 **TIP**  
> You may see warnings about running pip as root - these can be safely ignored in a container environment. If gdown fails, try: `pip3 install gdown --break-system-packages`

---

## Step 5: Prepare for installTAK Script

The installTAK script will automatically install:
- ✅ PostgreSQL 15 with PostGIS
- ✅ Java 17 (OpenJDK)
- ✅ TAK Server package
- ✅ Database configuration
- ✅ Firewall rules

📦 **Inside Container**

### 5.1 Create Working Directory

```bash
# Create directory for TAK installation files
mkdir -p /home/takadmin/takserver-install
cd /home/takadmin/takserver-install

# Set ownership
chown -R takadmin:takadmin /home/takadmin/takserver-install
```

### 5.2 Alternative: Manual File Transfer

If you prefer to manually transfer files instead of using gdown:

> ⚠️ **TAK SERVER FILE NAMING**  
> TAK Server files from tak.gov include a release number that changes with each build:
> ```
> takserver-5.5-RELEASE[##]_all.deb
>                      ^^^
>                      Release number (e.g., 58, 59, 60...)
> ```
> 
> **Use the EXACT filename you downloaded.** File names are case-sensitive and must be verbatim.
>
> Example: `takserver-5.5-RELEASE58_all.deb`
>
> 💡 **NOTE:** The 5.5 release used `-` before the version (`takserver-5.5-...`) which differs from the typical convention (`takserver_5.5-...`). Always verify your actual filename.

🖥️ **VPS Host** (not inside container)

```bash
# Copy file to VPS host first (from your local machine)
# scp takserver-5.5-RELEASE[##]_all.deb takadmin@[YOUR_VPS_IP]:~/

# Then from VPS host, push to container
lxc file push ~/takserver-5.5-RELEASE[##]_all.deb tak/home/takadmin/takserver-install/
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[##]` with your actual release number (e.g., `58`).

### 5.3 Verify Container is Ready

📦 **Inside Container**

Before proceeding to Phase 3, verify:

```bash
# Quick verification
ping -c 3 1.1.1.1        # Internet works
git --version             # Git installed
gdown --version           # gdown installed
id takadmin               # User exists
ls -ld /home/takadmin/takserver-install  # Directory exists
```

---

## Step 6: Network Configuration Notes

### 6.1 Document Container IP

🖥️ **VPS Host**

```bash
# Get container IP
lxc list tak -c n4

# Note the IPv4 address - you'll need this for HAProxy configuration
```

### 6.2 Test Host-to-Container Connectivity

🖥️ **VPS Host**

```bash
# Test connection to container
ping -c 3 [CONTAINER_IP]

# Example:
# ping -c 3 10.177.85.22

# Should succeed ✅
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[CONTAINER_IP]` with your actual container IP from `lxc list`.

### 6.3 Plan Port Forwarding Strategy

You'll need to decide how external traffic reaches containers on your VPS.

#### Understanding Your Deployment Type

**Single Service Deployment:**
- ONLY TAK Server running on the VPS
- No other web services, apps, or containers
- Simple use case: VPS exists solely for TAK

**Multi-Service Deployment:**
- TAK Server PLUS other services like:
  - Web server (Apache/Nginx)
  - NextCloud file sharing
  - MediaMTX video streaming (RTSP)
  - Other applications
- Multiple containers sharing ports (80, 443, etc.)
- Need intelligent routing by domain/subdomain

---

### Option A: LXD Proxy Device (Single Service ONLY)

**Use this ONLY if:**
- ✅ TAK Server is your ONLY service
- ✅ No web server, no NextCloud, no other apps
- ✅ Simple deployment

**Pros:**
- ✅ Simpler setup
- ✅ Built into LXD
- ✅ No additional container needed

**Cons:**
- ❌ Cannot handle multiple services well
- ❌ No domain-based routing
- ❌ Port conflicts with other services

**Example (don't run yet - configured in Phase 5):**
```bash
# Forward TAK ports directly to container
lxc config device add tak tak-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089
```

---

### Option B: HAProxy (Multi-Service - RECOMMENDED)

**Use this if you're running (or might run):**
- ✅ TAK Server
- ✅ Web server (Apache/Nginx)
- ✅ NextCloud or other file sharing
- ✅ MediaMTX (RTSP streaming)
- ✅ Any combination of services

**Pros:**
- ✅ Professional-grade load balancer
- ✅ Route by domain/subdomain
- ✅ Advanced health checks
- ✅ Can share ports (80, 443) across services

**Cons:**
- ❌ More complex initial setup
- ❌ Requires separate container

**Example Multi-Service Architecture:**
```
Internet
    ↓
VPS Public IP ([YOUR_VPS_IP])
    ↓
HAProxy Container ([HAPROXY_IP])
    ├─→ tak.[YOUR_DOMAIN]:8089 → TAK Container ([CONTAINER_IP]:8089)
    ├─→ web.[YOUR_DOMAIN]:80 → Web Container ([WEB_IP]:80)
    ├─→ files.[YOUR_DOMAIN]:443 → NextCloud Container ([NC_IP]:443)
    └─→ rtsp.[YOUR_DOMAIN]:8554 → MediaMTX Container ([MEDIA_IP]:8554)
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace all `[YOUR_DOMAIN]` and IP placeholders with your actual values.

---

### Making the Decision

**Choose LXD Proxy (Option A) if:**
- This is a simple, single-purpose TAK Server
- You don't plan to run other services
- You want the simplest possible setup

**Choose HAProxy (Option B) if:**
- You might add services later
- You need domain-based routing
- You want a professional, scalable setup

> 💡 **RECOMMENDATION**  
> Even if you're only running TAK Server now, **HAProxy is recommended** if you might add services later. It's easier to set up HAProxy from the start than to migrate later.

---

### 6.4 Plan Your Container IPs (If Using HAProxy)

🖥️ **VPS Host**

Document your planned containers and IPs:

```bash
# List current container IPs
lxc list -c n4

# Example planning table:
# +------------+---------------+------------------+
# | Container  | Purpose       | IP (from lxc)    |
# +------------+---------------+------------------+
# | tak        | TAK Server    | 10.x.x.11        |
# | haproxy    | Reverse Proxy | 10.x.x.12        |
# | web        | Web Server    | (future)         |
# | nextcloud  | File Sharing  | (future)         |
# +------------+---------------+------------------+
```

> 💡 **TIP**  
> Create a text file on your VPS to track container IPs:
> ```bash
> nano ~/container-ips.txt
> ```

**Phase 5 (Networking) will provide complete HAProxy configuration.**

---

## Step 7: Container Resource Limits (Optional)

> 💡 **SKIP THIS STEP FOR MOST USERS**  
> LXD containers share host resources by default, which works fine for most TAK Server deployments. Only configure limits if you know you need them.

<details>
<summary><strong>Advanced: Click to expand resource limit configuration</strong></summary>

🖥️ **VPS Host**

### 7.1 Check Current Resource Usage

```bash
lxc info tak

# Shows CPU, memory, and disk usage
```

### 7.2 Set CPU Limits

```bash
# Limit to 2 CPU cores (adjust based on VPS size)
lxc config set tak limits.cpu 2

# Verify
lxc config get tak limits.cpu
```

### 7.3 Set Memory Limits

```bash
# Set 4GB memory limit (adjust based on VPS RAM)
lxc config set tak limits.memory 4GB

# Verify
lxc config get tak limits.memory
```

### 7.4 Set Disk Limits

```bash
# Set root disk size limit (optional)
lxc config device override tak root size=60GB

# Verify
lxc config show tak
```

</details>

---

## Step 8: Create Container Snapshot

**Before proceeding to TAK installation, create a snapshot!**

This lets you rollback if something goes wrong.

🖥️ **VPS Host**

### 8.1 Exit Container and Create Snapshot

📦 **Inside Container** → 🖥️ **VPS Host**

```bash
# Exit the container completely (may need to type 'exit' twice)
# - If you're takadmin: exit → root → exit → VPS host
# - If you're root: exit → VPS host
exit

# Verify you're on VPS host (prompt should NOT say 'root@tak')
hostname
# Should output your VPS hostname, NOT 'tak'
```

🖥️ **VPS Host**

```bash
# Create snapshot
lxc snapshot tak fresh-setup

# List snapshots
lxc info tak | grep -A 10 Snapshots
```

### 8.2 How to Restore from Snapshot (if needed)

```bash
# Stop container
lxc stop tak

# Restore snapshot
lxc restore tak fresh-setup

# Start container
lxc start tak
```

---

## Step 9: Verification Checklist

Before moving to Phase 3 (TAK Installation), verify all these:

**Container Basics:**
- [ ] Container named 'tak' is running
- [ ] Container has IPv4 address
- [ ] Can access container with `lxc exec tak -- bash`

**Networking:**
- [ ] Container can ping 1.1.1.1 (internet)
- [ ] Container can ping google.com (DNS)
- [ ] Container can run `apt update` successfully
- [ ] Host can ping container IP

**Software Prerequisites:**
- [ ] Git is installed (`git --version`)
- [ ] Python3 is installed (`python3 --version`)
- [ ] gdown is installed (`gdown --version`)

**User Setup:**
- [ ] takadmin user exists
- [ ] takadmin has sudo access
- [ ] takadmin password is documented

**Snapshots:**
- [ ] Fresh snapshot created before TAK installation

### Quick Verification Script

🖥️ **VPS Host**

Create the script:
```bash
nano verify-container.sh
```

Paste the following:
```bash
#!/bin/bash
echo "=== TAK Container Verification ==="

echo -n "Container exists and running: "
lxc list | grep -q "tak.*RUNNING" && echo "✅" || echo "❌"

echo -n "Container has IP: "
lxc list tak -c 4 | grep -q "10\." && echo "✅" || echo "❌"

echo -n "Container internet access: "
lxc exec tak -- ping -c 1 1.1.1.1 &>/dev/null && echo "✅" || echo "❌"

echo -n "Container DNS working: "
lxc exec tak -- ping -c 1 google.com &>/dev/null && echo "✅" || echo "❌"

echo -n "Git installed: "
lxc exec tak -- git --version &>/dev/null && echo "✅" || echo "❌"

echo -n "Python3 installed: "
lxc exec tak -- python3 --version &>/dev/null && echo "✅" || echo "❌"

echo -n "gdown installed: "
lxc exec tak -- gdown --version &>/dev/null && echo "✅" || echo "❌"

echo -n "takadmin user exists: "
lxc exec tak -- id takadmin &>/dev/null && echo "✅" || echo "❌"

echo -n "Snapshot created: "
lxc info tak | grep -q "fresh-setup" && echo "✅" || echo "❌"

echo ""
echo "If all checks show ✅, proceed to Phase 3: TAK Installation"
echo ""
echo "Note: installTAK script will install PostgreSQL and Java automatically"
```

Save and exit (Ctrl+X, Y, Enter), then run:
```bash
chmod +x verify-container.sh
./verify-container.sh
```

---

## Troubleshooting

### Issue: Container won't start

```bash
# Check logs
lxc info tak --show-log

# Try starting with console access
lxc start tak --console
```

### Issue: apt update fails in container

**Check DNS resolution:**

📦 **Inside Container**
```bash
cat /etc/resolv.conf
# Should show nameserver (like 10.x.x.1)

# If missing or wrong, restart container from host:
```

🖥️ **VPS Host**
```bash
lxc restart tak
```

### Issue: Can't ping container from host

🖥️ **VPS Host**
```bash
# Check LXD network
lxc network show lxdbr0

# Verify IPv4 address range matches container IP
```

### Issue: gdown not found after installation

📦 **Inside Container**
```bash
# Try installing with --break-system-packages
pip3 install gdown --break-system-packages

# Or use apt version (if available)
apt install python3-gdown -y
```

---

## Container Management Quick Reference

🖥️ **VPS Host**

```bash
# Start container
lxc start tak

# Stop container
lxc stop tak

# Restart container
lxc restart tak

# Get shell in container
lxc exec tak -- bash

# Run single command in container
lxc exec tak -- systemctl status postgresql

# Push file to container
lxc file push localfile.txt tak/home/takadmin/

# Pull file from container
lxc file pull tak/home/takadmin/file.txt ./

# View container config
lxc config show tak

# View container info (including snapshots)
lxc info tak

# Delete/restore snapshot
lxc delete tak/snapshot-name
lxc restore tak snapshot-name

# Delete container (CAREFUL!)
# lxc stop tak && lxc delete tak
```

---

## Next Steps

Once all verification checks pass:

**➡️ Proceed to:** [Phase 3: TAK Server Installation](03-TAK-INSTALLATION.md)

This next guide covers:
- Downloading TAK Server files (via gdown or manual transfer)
- Running the installTAK script
- Understanding the installation wizard prompts
- Initial TAK Server configuration

---

## Notes

### Why Create takadmin in the Container?

- TAK Server should not run as root (security best practice)
- Easier to manage permissions
- Matches the VPS host user structure
- Makes troubleshooting easier

### Container vs VM?

This guide uses **containers** (not VMs) because:
- Faster startup times
- Lower resource overhead
- Easier snapshots and backups
- Sufficient isolation for TAK Server use case

---

*Last Updated: November 2025*  
*Tested on: Ubuntu 22.04 LTS, 24.04 LTS*  
*LXD Version: 5.21+*
