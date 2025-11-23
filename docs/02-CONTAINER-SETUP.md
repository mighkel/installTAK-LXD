# Container Setup Guide

**Phase 2: Creating and configuring the TAK Server LXD container**

This guide assumes you've completed [Phase 1: LXD Setup](01-LXD-SETUP.md) and all verification checks passed.

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

### 1.1 Launch Ubuntu Container
```bash
# Launch Ubuntu 22.04 container named 'tak'
lxc launch ubuntu:22.04 tak

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
| tak  | RUNNING | 10.206.248.11 (eth0) |      | CONTAINER  | 0         |
+------+---------+----------------------+------+------------+-----------+
```

**Note the IP address** - you'll need it later. In this example: `10.206.248.11`

### 1.2 Verify Container Networking

**Critical: Test networking before proceeding!**
```bash
# Test internet connectivity
lxc exec tak -- ping -c 3 1.1.1.1

# Test DNS resolution
lxc exec tak -- ping -c 3 google.com

# Test apt repositories
lxc exec tak -- apt update
```

**All three tests must succeed.** If any fail, stop and troubleshoot networking.

---

## Step 2: Initial Container Configuration

### 2.1 Access the Container
```bash
# Get a shell in the container
lxc exec tak -- bash

# You're now inside the container!
# Prompt should show: root@tak:~#
```

### 2.2 Update the Container
```bash
# Update package lists
apt update

# Upgrade all packages
apt upgrade -y

# Install basic utilities
apt install -y nano curl wget net-tools

# Clean up
apt autoremove -y
```

### 2.3 Set Container Timezone (Optional)
```bash
# Check current timezone
timedatectl

# Set to your timezone (example: America/Boise)
timedatectl set-timezone America/Boise

# Or use UTC (recommended for servers)
# timedatectl set-timezone UTC

# Verify
date
```

---

## Step 3: Create TAK Admin User in Container

**Best Practice:** Don't run TAK Server as root inside the container.

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

# Exit back to root
exit
```

### 3.2 Document the Password

**IMPORTANT:** Write this password down in your password manager or secure location!
```bash
# Container: tak
# User: takadmin
# Password: [your chosen password]
# IP: [container IP from lxc list]
```

---

## Step 4: Install Basic Prerequisites

The installTAK script will handle PostgreSQL and Java installation automatically. We only need basic tools.

### 4.1 Install Essential Utilities
```bash
# Still in the container as root

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
# Install gdown for downloading TAK files from Google Drive
pip3 install gdown --break-system-packages

# Verify installation
gdown --version
```

**Note:** The `--break-system-packages` flag is required on Ubuntu 22.04+ due to PEP 668.

---

## Step 5: Prepare for installTAK Script

The installTAK script will automatically install:
- ✅ PostgreSQL 15 with PostGIS
- ✅ Java 17 (OpenJDK)
- ✅ TAK Server package
- ✅ Database configuration
- ✅ Firewall rules

### 5.1 Create Working Directory
```bash
# Create directory for TAK installation files
mkdir -p /home/takadmin/takserver-install
cd /home/takadmin/takserver-install

# Set ownership
chown -R takadmin:takadmin /home/takadmin/takserver-install
```
**Alternative: Manual File Transfer**

If you prefer to manually transfer files instead of using gdown:
```bash
# From your local machine (NOT in the container):
# Copy file to VPS host first
scp takserver-5.5-RELEASE.deb takadmin@your-vps-ip:~/

# Then from VPS host, push to container
lxc file push ~/takserver-5.5-RELEASE.deb tak/home/takadmin/takserver-install/
```

### 5.2 Verify Container is Ready

Before proceeding to Phase 3, verify:
- [ ] Container has internet access
- [ ] Basic utilities installed (git, wget, curl)
- [ ] gdown is installed
- [ ] takadmin user exists
- [ ] Working directory created
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
```bash
# From VPS host (not in container):
lxc list tak

# Note the IPv4 address - example: 10.206.248.11
```

### 6.2 Test Host-to-Container Connectivity
```bash
# From VPS host, test connection to container
ping -c 3 [container-ip]

# Example:
ping -c 3 10.206.248.11

# Should succeed ✅
```

### 6.3 Plan Port Forwarding Strategy

You'll need to decide how external traffic reaches the TAK container:

**Option A: LXD Proxy Device** (Simpler, recommended for single service)
```bash
# Example (don't run yet - this is Phase 5):
lxc config device add tak tak-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089
```

**Option B: HAProxy** (More complex, better for multiple services)
- Covered in [Phase 5: Networking](05-NETWORKING.md)

**For now, just note which approach you'll use.**

---

## Step 7: Container Resource Limits (Optional)

Set limits to prevent TAK Server from consuming all VPS resources.

### 7.1 Check Current Resource Usage
```bash
# From VPS host:
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

---

## Step 8: Create Container Snapshot

**Before proceeding to TAK installation, create a snapshot!**

This lets you rollback if something goes wrong.

### 8.1 Exit Container and Create Snapshot
```bash
# If you're inside the container, exit first
exit

# From VPS host, create snapshot
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

Save this as `verify-container.sh` on your VPS host:
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

echo -n "PostgreSQL installed: "
lxc exec tak -- systemctl is-active postgresql &>/dev/null && echo "✅" || echo "❌"

echo -n "Java installed: "
lxc exec tak -- java -version &>/dev/null && echo "✅" || echo "❌"

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
```

**Run it:**
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
```bash
lxc exec tak -- cat /etc/resolv.conf
# Should show nameserver (like 10.206.248.1)

# If missing, restart container
lxc restart tak
```

### Issue: PostgreSQL won't install

**Check if old version is present:**
```bash
lxc exec tak -- dpkg -l | grep postgres

# Remove old versions if found
lxc exec tak -- apt purge postgresql* -y
lxc exec tak -- apt autoremove -y

# Try installation again
```

### Issue: Can't ping container from host

**Check LXD network:**
```bash
lxc network show lxdbr0

# Verify IPv4 address range matches container IP
```

### Issue: gdown not found after installation
```bash
# Try installing with --break-system-packages
lxc exec tak -- pip3 install gdown --break-system-packages

# Or use apt version
lxc exec tak -- apt install python3-gdown -y
```

---

## Container Management Commands

**Useful commands for managing your container:**
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

# View container info
lxc info tak

# List all snapshots
lxc info tak | grep -A 20 Snapshots

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

### Why PostgreSQL Inside the Container?

- TAK Server expects local PostgreSQL by default
- Simpler configuration
- Container isolation protects the database
- Easy to backup/snapshot entire stack together

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
