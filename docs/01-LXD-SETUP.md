# LXD Setup Guide

**Complete guide for installing and configuring LXD on Ubuntu VPS**

This is Phase 1 of the TAK Server LXD deployment. Complete this guide before proceeding to container creation.

---

## Document Conventions

Throughout this documentation, you'll see these indicators:

| Symbol | Meaning |
|--------|---------|
| 💻 | **Local Machine** - Commands run on your Windows/Mac/Linux workstation |
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside any container) |
| 📦 | **Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - You must replace placeholder values |
| 💡 | **Tip** - Helpful information |
| ⛔ | **Critical** - Important warning |

**Where Am I? (Check Your Prompt)**
| Prompt Looks Like | You Are |
|-------------------|---------|
| `C:\Users\you>` or `you@local:~$` | 💻 Local Machine |
| `takadmin@your-vps:~$` | 🖥️ VPS Host |
| `root@tak:~#` | 📦 Inside container (as root) |
| `takadmin@tak:~$` | 📦 Inside container (as takadmin) |

> 💡 **TIP: Exiting Containers**  
> When inside a container, you may need `exit` twice to return to VPS host:
> 1. First `exit`: non-root user → root (still in container)
> 2. Second `exit`: container → VPS host

**Placeholder Convention:**
- `[YOUR_DOMAIN]` - Your registered domain (e.g., `tak.example.com`)
- `[YOUR_VPS_IP]` - Your VPS public IP address (e.g., `203.0.113.50`)
- `[YOUR_VPS_HOSTNAME]` - A short name for your VPS (e.g., `takvps`, `prodtak`)
- `[YOUR_ORG]` - Your organization name

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_VPS_IP]` becomes `203.0.113.50`
> (Keep any surrounding quotes, remove the brackets)

---

## Prerequisites

### What You Need

- Fresh Ubuntu 22.04 or 24.04 LTS installation (minimal)
- Root or sudo access
- SSH access to your VPS
- At least 4GB RAM, 2 vCPU, 80GB storage

### VPS Providers

- ✅ **SSDNodes** - Primary testing platform for this guide
- ✅ **DigitalOcean** - Should work with minimal adaptation
- ⚠️ **Linode** - Not tested, but standard Ubuntu VPS should work
- ⚠️ **AWS EC2** - Not tested; AWS networking is more complex and may require additional configuration

---

## Step 1: Initial System Setup

### 1.1 Connect to Your VPS

💻 **Local Machine**

```bash
# From your local machine (Windows/Mac/Linux)
ssh root@[YOUR_VPS_IP]

# Or if using a non-root user:
ssh username@[YOUR_VPS_IP]
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[YOUR_VPS_IP]` with your actual VPS public IP address.

### 1.2 Update System

🖥️ **VPS Host**

**Always start with system updates:**

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
```

**Reboot if kernel was updated:**

```bash
# Check if reboot is needed
[ -f /var/run/reboot-required ] && echo "Reboot required" || echo "No reboot needed"

# If reboot required:
sudo reboot

# Wait 60 seconds, then reconnect
```

💻 **Local Machine**

```bash
ssh username@[YOUR_VPS_IP]
```

### 1.3 Create TAK Admin User (if not already done)

🖥️ **VPS Host**

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

---

## Step 2: Set Up SSH Key Authentication

SSH keys provide secure, passwordless authentication to your VPS.

### 2.1 For Windows Users (PuTTY Method)

> 💡 **DETAILED GUIDE AVAILABLE**  
> For step-by-step instructions with screenshots, see [SSH Key Setup Guide](SSH-KEY-SETUP.md).

💻 **Local Machine (Windows)**

**Step 1: Generate SSH Key Pair**

1. Download and install [PuTTY](https://www.putty.org/) (includes PuTTYgen and Pageant)
2. Launch **PuTTYgen**
3. Click "Generate" and move mouse randomly to generate entropy
4. Once generated:
   - **Key comment:** `takadmin@[YOUR_VPS_HOSTNAME]` (or leave blank)
   - **Key passphrase:** (optional but recommended)
5. Click "Save private key" → Save as `takadmin-[YOUR_VPS_HOSTNAME].ppk`
6. Copy the public key text from the top box (starts with `ssh-rsa`)

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[YOUR_VPS_HOSTNAME]` with a short name for your VPS (e.g., `takvps`, `prodtak`).

**Step 2: Add Public Key to VPS**

🖥️ **VPS Host** (connect with password this time)

```bash
# Switch to takadmin
su - takadmin

# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create authorized_keys file
nano ~/.ssh/authorized_keys

# Paste the public key from PuTTYgen (right-click to paste in PuTTY)
# Should be one long line starting with "ssh-rsa AAAA..."

# Save and exit (Ctrl+X, Y, Enter)

# Set correct permissions
chmod 600 ~/.ssh/authorized_keys

# Exit back to root/original user
exit
```

**Step 3: Configure PuTTY Session**

💻 **Local Machine (Windows)**

1. Open **PuTTY**
2. Navigate to: **Connection → SSH → Auth → Credentials**
3. Browse and select your `.ppk` file for "Private key file for authentication"
4. Go back to **Session**
5. Enter: `takadmin@[YOUR_VPS_IP]` in Host Name, Port `22`, SSH
6. Save session with a name (e.g., `TAK-VPS`)
7. Click **Open** to connect

**Step 4: Test Connection**

- Should connect without password (or prompt for passphrase if you set one)
- Accept the host key warning on first connection

> 💡 **TIP: Use Pageant for Passphrase Management**  
> Pageant (included with PuTTY) lets you enter your passphrase once per session:
> 1. Launch **Pageant** (appears in system tray)
> 2. Right-click → "Add Key" → Select your `.ppk` file
> 3. Enter passphrase once; PuTTY uses it automatically

> ⛔ **SECURITY NOTE**  
> Keep your `.ppk` file safe! Anyone with this file (and passphrase if set) can access your VPS.

---

### 2.2 For Linux/Mac Users

💻 **Local Machine (Linux/Mac)**

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "takadmin@[YOUR_VPS_HOSTNAME]"

# When prompted for file location:
# Save to: ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME]
# Enter passphrase (optional but recommended)

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME].pub takadmin@[YOUR_VPS_IP]

# Test passwordless login
ssh -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME] takadmin@[YOUR_VPS_IP]
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[YOUR_VPS_HOSTNAME]` and `[YOUR_VPS_IP]` with your values.

---

### 2.3 Verify SSH Key Authentication Works

💻 **Local Machine**

```bash
# Should connect without asking for password
# (or only ask for passphrase if you set one)

# Windows/PuTTY: Load saved session and click "Open"
# Linux/Mac: ssh -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME] takadmin@[YOUR_VPS_IP]
```

---

## Step 3: Install LXD

LXD is installed via snap on Ubuntu.

🖥️ **VPS Host** (as takadmin)

### 3.1 Verify Snapd is Installed

```bash
# Check if snapd is running
systemctl status snapd

# If not installed (rare on Ubuntu):
sudo apt install snapd -y
```

### 3.2 Install LXD Snap

```bash
# Install LXD (latest stable LTS - currently 5.21)
sudo snap install lxd

# Verify installation
lxd --version

# Expected output similar to: 5.21
```

### 3.3 Add User to LXD Group

```bash
# Add current user to lxd group
sudo usermod -aG lxd $USER

# Apply group changes (or logout/login)
newgrp lxd

# Verify group membership
groups | grep lxd
```

---

## Step 4: Initialize LXD and Create TAK Network

This step configures LXD storage and creates a dedicated network bridge for TAK deployment.

🖥️ **VPS Host**

### 4.1 Run Minimal LXD Init
```bash
lxd init --minimal
```

This creates default storage without interactive prompts.

### 4.2 Create Dedicated TAK Network Bridge

Create a dedicated LXD network with a predictable subnet:
```bash
lxc network create takbr0 \
  ipv4.address=10.100.100.1/24 \
  ipv4.nat=true \
  ipv4.dhcp=true \
  ipv4.dhcp.ranges=10.100.100.100-10.100.100.199 \
  ipv6.address=none
```

> 💡 **Why takbr0?**  
> Using a dedicated bridge with a predictable subnet (`10.100.100.0/24`) means:
> - Container IPs are always predictable (TAK = `.10`, HAProxy = `.11`)
> - HAProxy configuration uses real IPs instead of placeholders
> - Documentation examples work without modification

### 4.3 Verify Network Configuration
```bash
# List networks
lxc network list

# Expected output:
# +---------+----------+---------+----------------+---------------------------+
# |  NAME   |   TYPE   | MANAGED |      IPV4      |           IPV6            |
# +---------+----------+---------+----------------+---------------------------+
# | takbr0  | bridge   | YES     | 10.100.100.1/24|                           |
# +---------+----------+---------+----------------+---------------------------+

# Show network details
lxc network show takbr0

# Verify storage
lxc storage list
```

---

## Step 5: Test LXD Installation

**Always test before proceeding!**

🖥️ **VPS Host**

### 5.1 Launch a Test Container

```bash
# Launch Ubuntu 22.04 test container
lxc launch ubuntu:22.04 test --network takbr0

# Wait a few seconds, then check status
lxc list

# Expected output:
# +------+---------+---------------------+------+------------+-----------+
# | NAME |  STATE  |        IPV4         | IPV6 |    TYPE    | SNAPSHOTS |
# +------+---------+---------------------+------+------------+-----------+
# | test | RUNNING | 10.x.x.x (eth0)     |      | CONTAINER  | 0         |
# +------+---------+---------------------+------+------------+-----------+
```

> 💡 **TIP**  
> Note the container IP address (e.g., `10.x.x.x`). Your actual containers will get IPs from this same range.

### 5.2 Verify Container Networking

```bash
# Test internet connectivity from container
lxc exec test -- ping -c 3 1.1.1.1

# Test DNS resolution
lxc exec test -- ping -c 3 google.com

# If both work, networking is good! ✅
```

### 5.3 Test Container Access

```bash
# Get a shell in the container
lxc exec test -- bash

# Inside container - verify internet
apt update

# Exit container
exit
```

### 5.4 Clean Up Test Container

```bash
# Stop and delete test container
lxc stop test
lxc delete test

# Verify it's gone
lxc list
```

---

## Step 6: Configure Firewall (UFW)

**Important:** Configure firewall BEFORE creating TAK containers.

🖥️ **VPS Host**

### 6.1 Install and Enable UFW

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

> ⛔ **CRITICAL**  
> Always allow SSH before enabling UFW, or you'll lock yourself out!

### 6.2 Allow TAK Server Ports

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

## Step 7: Configure LXD Network for Firewall

LXD containers need to reach the internet through the host's firewall.

🖥️ **VPS Host**

### 7.1 Enable IP Forwarding

```bash
# Check if IP forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward
# Should output: 1

# If it outputs 0, enable it:
sudo sysctl -w net.ipv4.ip_forward=1

# Make it permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

### 7.2 Configure UFW for LXD

```bash
# Edit UFW before.rules
sudo nano /etc/ufw/before.rules
```

**Add these lines AFTER the header comments but BEFORE the `*filter` section:**

```
# NAT table rules for LXD
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic from LXD containers
-A POSTROUTING -s 10.100.100.0/24 -o eth0 -j MASQUERADE

COMMIT
```

> 💡 **TIP**  
> If your VPS uses a different network interface (not `eth0`), check with `ip a` and adjust accordingly.

**Save and exit** (Ctrl+X, Y, Enter)

### 7.3 Allow LXD Bridge Traffic

```bash
# Allow traffic on takbr0
sudo ufw allow in on takbr0
sudo ufw route allow in on takbr0
sudo ufw route allow out on takbr0

# Reload UFW
sudo ufw reload
```

### 7.4 Verify Container Internet Access

```bash
# Launch another test container
lxc launch ubuntu:22.04 nettest --network takbr0

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

## Step 8: Optional - Configure LXD Resource Limits

> 💡 **SKIP THIS STEP FOR MOST USERS**  
> LXD containers share host resources by default, which works fine for most TAK Server deployments. Only configure limits if you:
> - Are running multiple containers and need to prevent one from starving others
> - Have specific resource requirements you've calculated
> - Are experienced with Linux resource management
>
> **Default recommendation:** Skip this section and proceed to Step 9.

<details>
<summary><strong>Advanced: Click to expand resource limit configuration</strong></summary>

🖥️ **VPS Host**

### 8.1 Create a Limited Profile

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

</details>

---

## Step 9: Verification Checklist

Before moving to Phase 2 (Container Creation), verify:

- [ ] LXD is installed and initialized
- [ ] `lxc list` works without sudo
- [ ] Test container can reach internet
- [ ] Test container has DNS resolution
- [ ] UFW is enabled with TAK ports open
- [ ] IP forwarding is enabled
- [ ] LXD bridge traffic is allowed through UFW

### Quick Verification Script

🖥️ **VPS Host**

Create the script:
```bash
nano verify-lxd.sh
```

Paste the following:
```bash
#!/bin/bash
echo "=== LXD Setup Verification ==="

echo -n "LXD installed: "
lxd --version && echo "✅" || echo "❌"

echo -n "Can run lxc without sudo: "
lxc list &>/dev/null && echo "✅" || echo "❌"

echo -n "LXD network exists: "
lxc network list | grep -q takbr0 && echo "✅" || echo "❌"

echo -n "Storage pool exists: "
lxc storage list | grep -q default && echo "✅" || echo "❌"

echo -n "UFW is active: "
sudo ufw status | grep -q "Status: active" && echo "✅" || echo "❌"

echo -n "IP forwarding enabled: "
[ $(cat /proc/sys/net/ipv4/ip_forward) -eq 1 ] && echo "✅" || echo "❌"

echo ""
echo "If all checks show ✅, proceed to Phase 2: Container Setup"
```

Save and exit (Ctrl+X, Y, Enter), then run:

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
   # Should show takbr0 allowed
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
lxc network set takbr0 ipv6.address none
lxc network show takbr0
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
