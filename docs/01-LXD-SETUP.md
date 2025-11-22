# LXD Setup Guide

**Complete guide for installing and configuring LXD on Ubuntu VPS**

This is Phase 1 of the TAK Server LXD deployment. Complete this guide before proceeding to container creation.

---

## Prerequisites

### What You Need
- Fresh Ubuntu 22.04 or 24.04 LTS installation (minimal)
- Root or sudo access
- SSH access to your VPS
- At least 4GB RAM, 2 vCPU, 80GB storage

### VPS Providers Tested
- ✅ SSDNodes
- ✅ Linode
- ✅ DigitalOcean
- ✅ AWS EC2

---

## Step 1: Initial System Setup

### 1.1 Connect to Your VPS
```bash
# From your local machine (Windows/Mac/Linux)
ssh root@your-vps-ip

# Or if using a non-root user:
ssh username@your-vps-ip
```

### 1.2 Update System

**Always start with system updates:**
```bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
```

**Reboot if kernel was updated:**
```bash
# Check if reboot is needed
[ -f /var/run/reboot-required ] && echo "Reboot required" || echo "No reboot needed"

# If reboot required:
sudo reboot

# Wait 60 seconds, then reconnect
ssh username@your-vps-ip
```

### 1.3 Create TAK Admin User (if not already done)

**Best practice:** Don't run everything as root.
```bash
# Create user
sudo adduser takadmin

# Add to sudo group
sudo usermod -aG sudo takadmin

# Test sudo access
su - takadmin
sudo whoami  # Should output: root

# Exit back to your original user
exit
```

**Set up SSH key for takadmin:**
```bash
# From your local machine, copy SSH key
ssh-copy-id takadmin@your-vps-ip

# Test passwordless login
ssh takadmin@your-vps-ip
```

---

## Step 2: Install LXD

LXD is installed via snap on Ubuntu.

### 2.1 Verify Snapd is Installed
```bash
# Check if snapd is running
systemctl status snapd

# If not installed (rare on Ubuntu):
sudo apt install snapd -y
```

### 2.2 Install LXD Snap
```bash
# Install LXD (latest stable LTS - currently 5.21)
sudo snap install lxd

# Verify installation
lxd --version

# Expected output similar to: 5.21
```

### 2.3 Add User to LXD Group
```bash
# Add current user to lxd group
sudo usermod -aG lxd $USER

# Apply group changes (or logout/login)
newgrp lxd

# Verify group membership
groups | grep lxd
```

---

## Step 3: Initialize LXD

This is the **most important step**. LXD needs to be configured for networking and storage.

### 3.1 Run LXD Init
```bash
lxd init
```

### 3.2 Answer the Initialization Prompts

**Follow this configuration for TAK Server deployment:**
```
Would you like to use LXD clustering? (yes/no) [default=no]: 
→ no

Do you want to configure a new storage pool? (yes/no) [default=yes]: 
→ yes

Name of the new storage pool [default=default]: 
→ [press Enter] (keep default)

Name of the storage backend to use (dir, lvm, zfs, btrfs, ceph) [default=zfs]: 
→ dir

Would you like to connect to a MAAS server? (yes/no) [default=no]: 
→ no

Would you like to create a new local network bridge? (yes/no) [default=yes]: 
→ yes

What should the new bridge be called? [default=lxdbr0]: 
→ [press Enter] (keep lxdbr0)

What IPv4 address should be used? (CIDR subnet notation, "auto" or "none") [default=auto]: 
→ auto

What IPv6 address should be used? (CIDR subnet notation, "auto" or "none") [default=auto]: 
→ none  (IPv6 can cause issues with TAK Server)

Would you like the LXD server to be available over the network? (yes/no) [default=no]: 
→ no  (unless you're clustering, keep this no)

Would you like stale cached images to be updated automatically? (yes/no) [default=yes]: 
→ yes

Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: 
→ no
```

### 3.3 Verify LXD Configuration
```bash
# Check LXD network
lxc network list

# Expected output:
# +---------+----------+---------+-------------+---------+
# |  NAME   |   TYPE   | MANAGED | DESCRIPTION | USED BY |
# +---------+----------+---------+-------------+---------+
# | lxdbr0  | bridge   | YES     |             | 0       |
# +---------+----------+---------+-------------+---------+

# Check storage pool
lxc storage list

# Expected output showing 'default' storage pool
```

---

## Step 4: Test LXD Installation

**Always test before proceeding!**

### 4.1 Launch a Test Container
```bash
# Launch Ubuntu 22.04 test container
lxc launch ubuntu:22.04 test

# Wait a few seconds, then check status
lxc list

# Expected output:
# +------+---------+---------------------+------+------------+-----------+
# | NAME |  STATE  |        IPV4         | IPV6 |    TYPE    | SNAPSHOTS |
# +------+---------+---------------------+------+------------+-----------+
# | test | RUNNING | 10.x.x.x (eth0)     |      | CONTAINER  | 0         |
# +------+---------+---------------------+------+------------+-----------+
```

### 4.2 Verify Container Networking
```bash
# Test internet connectivity from container
lxc exec test -- ping -c 3 1.1.1.1

# Test DNS resolution
lxc exec test -- ping -c 3 google.com

# If both work, networking is good! ✅
```

### 4.3 Test Container Access
```bash
# Get a shell in the container
lxc exec test -- bash

# Inside container - verify internet
apt update

# Exit container
exit
```

### 4.4 Clean Up Test Container
```bash
# Stop and delete test container
lxc stop test
lxc delete test

# Verify it's gone
lxc list
```

---

## Step 5: Configure Firewall (UFW)

**Important:** Configure firewall BEFORE creating TAK containers.

### 5.1 Install and Enable UFW
```bash
# Install UFW (usually pre-installed)
sudo apt install ufw -y

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CRITICAL - do this first!)
sudo ufw allow ssh

# Or allow SSH on specific port if changed:
# sudo ufw allow 2222/tcp

# Enable UFW
sudo ufw enable

# Verify status
sudo ufw status verbose
```

### 5.2 Allow TAK Server Ports
```bash
# TAK client connections (ATAK/WinTAK/iTAK)
sudo ufw allow 8089/tcp comment 'TAK Client'

# TAK web UI
sudo ufw allow 8443/tcp comment 'TAK WebUI'

# Certificate enrollment (if enabling)
sudo ufw allow 8446/tcp comment 'TAK Enrollment'

# HTTP (for Let's Encrypt challenges)
sudo ufw allow 80/tcp comment 'HTTP'

# HTTPS (for web services)
sudo ufw allow 443/tcp comment 'HTTPS'

# Check rules
sudo ufw status numbered
```

---

## Step 6: Configure LXD Network for Firewall

LXD containers need to reach the internet through the host's firewall.

### 6.1 Enable IP Forwarding
```bash
# Check if IP forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward
# Should output: 1

# If it outputs 0, enable it:
sudo sysctl -w net.ipv4.ip_forward=1

# Make it permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

### 6.2 Configure UFW for LXD
```bash
# Edit UFW before.rules
sudo nano /etc/ufw/before.rules
```

**Add these lines AFTER the header comments but BEFORE the *filter section:**
```
# NAT table rules for LXD
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic from LXD containers
-A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE

COMMIT
```

**Save and exit** (Ctrl+X, Y, Enter)

### 6.3 Allow LXD Bridge Traffic
```bash
# Allow traffic on lxdbr0
sudo ufw allow in on lxdbr0
sudo ufw route allow in on lxdbr0
sudo ufw route allow out on lxdbr0

# Reload UFW
sudo ufw reload
```

### 6.4 Verify Container Internet Access
```bash
# Launch another test container
lxc launch ubuntu:22.04 nettest

# Test internet from container
lxc exec nettest -- ping -c 3 1.1.1.1

# Test DNS
lxc exec nettest -- ping -c 3 google.com

# If both work: ✅ Networking is properly configured!

# Clean up
lxc stop nettest
lxc delete nettest
```

---

## Step 7: Optional - Configure LXD Limits

Set resource limits to prevent containers from consuming all VPS resources.

### 7.1 Create a Limited Profile (Optional)
```bash
# Create a profile for TAK containers
lxc profile create tak-limited

# Set CPU limit (2 cores)
lxc profile set tak-limited limits.cpu 2

# Set memory limit (4GB)
lxc profile set tak-limited limits.memory 4GB

# View profile
lxc profile show tak-limited
```

**You'll apply this profile when creating the TAK container in the next guide.**

---

## Step 8: Verification Checklist

Before moving to Phase 2 (Container Creation), verify:

- [ ] LXD is installed and initialized
- [ ] `lxc list` works without sudo
- [ ] Test container can reach internet
- [ ] Test container has DNS resolution
- [ ] UFW is enabled with TAK ports open
- [ ] IP forwarding is enabled
- [ ] LXD bridge traffic is allowed through UFW

### Quick Verification Script
```bash
#!/bin/bash
echo "=== LXD Setup Verification ==="

echo -n "LXD installed: "
lxd --version && echo "✅" || echo "❌"

echo -n "Can run lxc without sudo: "
lxc list &>/dev/null && echo "✅" || echo "❌"

echo -n "LXD network exists: "
lxc network list | grep -q lxdbr0 && echo "✅" || echo "❌"

echo -n "Storage pool exists: "
lxc storage list | grep -q default && echo "✅" || echo "❌"

echo -n "UFW is active: "
sudo ufw status | grep -q "Status: active" && echo "✅" || echo "❌"

echo -n "IP forwarding enabled: "
[ $(cat /proc/sys/net/ipv4/ip_forward) -eq 1 ] && echo "✅" || echo "❌"

echo ""
echo "If all checks show ✅, proceed to Phase 2: Container Setup"
```

**Save this as `verify-lxd.sh` and run:**
```bash
chmod +x verify-lxd.sh
./verify-lxd.sh
```

---

## Troubleshooting

### Issue: "Permission denied" when running lxc commands

**Solution:**
```bash
# Add user to lxd group
sudo usermod -aG lxd $USER

# Logout and login, or:
newgrp lxd

# Verify
groups | grep lxd
```

### Issue: Container can't reach internet

**Check these in order:**

1. **IP forwarding:**
```bash
   cat /proc/sys/net/ipv4/ip_forward
   # Must be: 1
```

2. **UFW routing:**
```bash
   sudo ufw status verbose
   # Should show lxdbr0 allowed
```

3. **NAT rules:**
```bash
   sudo cat /etc/ufw/before.rules | grep -A 5 "nat"
   # Should show POSTROUTING rule
```

4. **Test from host:**
```bash
   ping -c 3 1.1.1.1  # Should work from host
```

### Issue: LXD init fails with storage error

**Solution - Use dir instead of zfs:**

ZFS may not be available on all VPS systems. If init fails, run again and choose `dir` for storage backend.

### Issue: IPv6 conflicts

**Solution - Disable IPv6 in LXD:**
```bash
lxc network set lxdbr0 ipv6.address none
lxc network show lxdbr0
```

---

## Next Steps

Once all verification checks pass:

**➡️ Proceed to:** [Phase 2: Container Setup](02-CONTAINER-SETUP.md)

This next guide covers:
- Creating the TAK Server container
- Initial container configuration
- Preparing for TAK Server installation

---

## Additional Resources

- **LXD Documentation:** https://documentation.ubuntu.com/lxd
- **UFW Guide:** https://help.ubuntu.com/community/UFW
- **LXD Networking:** https://documentation.ubuntu.com/lxd/en/latest/howto/network_bridge_firewalld/

---

*Last Updated: November 2025*  
*Tested on: Ubuntu 22.04 LTS, 24.04 LTS*  
*LXD Version: 5.21+*
