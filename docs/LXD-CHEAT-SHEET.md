# LXD Command Cheat Sheet

Quick reference for common LXD container operations during TAK Server deployment.

---

## Quick Reference Card
```bash
# ESSENTIAL COMMANDS
lxc list                              # Show all containers
lxc exec CONTAINER -- bash            # Get shell (run commands within container)
lxc file push FILE CONTAINER/path/    # Upload file
lxc file pull CONTAINER/path/ ./      # Download file
lxc snapshot CONTAINER name           # Create backup
lxc restore CONTAINER name            # Restore backup
lxc stop CONTAINER                    # Stop container
lxc start CONTAINER                   # Start container
exit                                  # Leave container shell (go back to host)

# FILE SHORTCUTS (from host)
lxc exec tak -- systemctl status takserver           # Check TAK status
lxc exec tak -- tail -f /opt/tak/logs/takserver.log # Watch logs
lxc file pull tak/root/webadmin.p12 ~/               # Get certificate
```

---

## Container Basics

### List Containers
```bash
lxc list
# Shows all containers with IPs, status, and type
```

### Start/Stop/Restart Container
```bash
lxc start tak
lxc stop tak
lxc restart tak
```

### Delete Container
```bash
lxc stop tak        # Must stop first
lxc delete tak      # Permanently deletes
```

### Check Container Status
```bash
lxc info tak
# Shows detailed info: memory, disk, snapshots, etc.
```

---

## Accessing Containers

### Get Shell Access
```bash
# Method 1: Interactive bash shell (most common)
lxc exec tak -- bash

# Method 2: Run single command
lxc exec tak -- systemctl status takserver

# Method 3: Login as specific user
lxc exec tak -- su - takadmin
```

### Exit Container Shell
```bash
exit
# or press Ctrl+D
```

---

## File Operations

### Copy Files INTO Container
```bash
# Single file
lxc file push localfile.txt tak/root/

# Multiple files
lxc file push file1.txt file2.txt tak/root/

# Entire directory
lxc file push -r /local/directory tak/root/

# From Windows via WinSCP: upload to host first, then push to container
```

### Copy Files OUT OF Container
```bash
# Single file from container to host
lxc file pull tak/root/webadmin.p12 ~/

# With specific filename
lxc file pull tak/opt/tak/logs/takserver.log ~/tak-logs.txt

# Directory (recursive)
lxc file pull -r tak/opt/tak/certs/files ~/tak-certs/
```

### Change File Ownership (for downloading via WinSCP)
```bash
# After pulling files to host, make them owned by your user
sudo chown takadmin:takadmin ~/webadmin.p12
```

---

## Snapshots (Backups)

### Create Snapshot
```bash
# Before making changes
lxc snapshot tak pre-install-$(date +%F)

# Or with descriptive name
lxc snapshot tak working-config-before-upgrade
```

### List Snapshots
```bash
lxc info tak | grep "Snapshots:" -A20
```

### Restore from Snapshot
```bash
# Restore container to previous state
lxc restore tak pre-install-2025-10-15

# Container must be stopped first if it's running
lxc stop tak
lxc restore tak snapshot-name
lxc start tak
```

### Delete Snapshot
```bash
lxc delete tak/snapshot-name
```

### Publish Snapshot as New Container
```bash
# Create a new container from a snapshot
lxc copy tak/working-config tak-backup
```

---

## Networking

### View Container IPs
```bash
lxc list
# Shows IPv4 and IPv6 addresses in the table
```

### Manually Assign IP (if DHCP fails)
```bash
lxc exec tak -- ip addr add 10.206.248.11/24 dev eth0
lxc exec tak -- ip route add default via 10.206.248.1
```

### Check DNS Resolution
```bash
lxc exec tak -- nslookup archive.ubuntu.com
lxc exec tak -- cat /etc/resolv.conf
```

### Test Internet Connectivity
```bash
lxc exec tak -- ping -c 3 8.8.8.8
lxc exec tak -- curl -I https://google.com
```

### View Network Config
```bash
lxc network list
lxc network show lxdbr0
```

---

## Port Forwarding (Proxy Devices)

### Add Port Forward from Host to Container
```bash
# Forward host port 8443 to container port 8443
lxc config device add haproxy tak8443 proxy \
  listen=tcp:0.0.0.0:8443 \
  connect=tcp:127.0.0.1:8443
```

### List Proxy Devices
```bash
lxc config show haproxy | grep -A5 "devices:"
```

### Remove Port Forward
```bash
lxc config device remove haproxy tak8443
```

---

## Resource Management

### Set Memory Limit
```bash
lxc config set tak limits.memory 8GB
lxc config set tak limits.memory.enforce hard
```

### Set CPU Limit
```bash
lxc config set tak limits.cpu 4
```

### View Current Resource Usage
```bash
lxc info tak --resources
```

---

## Container Configuration

### View All Config
```bash
lxc config show tak
```

### Edit Config Directly
```bash
lxc config edit tak
# Opens in default editor (usually nano or vim)
```

### Set Individual Config Option
```bash
lxc config set tak security.privileged false
lxc config set tak boot.autostart true
```

---

## Logs and Troubleshooting

### View Container Logs
```bash
# System logs
lxc exec tak -- journalctl -xe

# Specific service
lxc exec tak -- journalctl -u takserver -f

# Follow logs in real-time
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log
```

### Check Service Status
```bash
lxc exec tak -- systemctl status takserver
lxc exec tak -- systemctl status postgresql
```

### Check Listening Ports
```bash
lxc exec tak -- ss -tulpn | grep LISTEN
lxc exec tak -- netstat -tulpn
```

### Check Processes
```bash
lxc exec tak -- ps aux | grep java
lxc exec tak -- top
```

---

## Common Workflows

### Fresh TAK Server Install
```bash
# 1. Create container
lxc launch ubuntu:22.04 tak

# 2. Set up networking (if needed)
lxc exec tak -- ip addr add 10.206.248.11/24 dev eth0
lxc exec tak -- ip route add default via 10.206.248.1

# 3. Upload installer files
lxc file push installTAK tak/root/
lxc file push takserver.deb tak/root/
lxc file push takserver-public-gpg.key tak/root/
lxc file push deb_policy.pol tak/root/

# 4. Make executable and run
lxc exec tak -- chmod +x /root/installTAK
lxc exec tak -- bash
cd /root
./installTAK takserver_5.5-RELEASE58_all.deb false true

# 5. After install, pull certificates
exit  # Exit container
lxc file pull tak/root/webadmin.p12 ~/
lxc file pull tak/root/enrollment-default.zip ~/
sudo chown takadmin:takadmin ~/*.p12 ~/*.zip
```

### Snapshot Before Major Changes
```bash
# Before upgrading or changing config
lxc snapshot tak before-upgrade-$(date +%F)

# Make changes...
lxc exec tak -- bash

# If something breaks, restore
lxc stop tak
lxc restore tak before-upgrade-2025-10-15
lxc start tak
```

### Clone Container for Testing
```bash
# Create exact copy of running container
lxc copy tak tak-test

# Start the test copy
lxc start tak-test

# Test changes on tak-test, keep tak as production
```

---

## Quick Troubleshooting

### Container Won't Start
```bash
# Check for errors
lxc info tak

# Try force stop and start
lxc stop tak --force
lxc start tak

# Check host system logs
sudo journalctl -xe | grep lxc
```

### Can't Access Container
```bash
# Check if running
lxc list

# Try console access (sometimes works when exec doesn't)
lxc console tak
# Press Ctrl+A then Q to exit console
```

### Out of Disk Space
```bash
# Check container disk usage
lxc exec tak -- df -h

# Check host pool usage
lxc storage info default

# Clean up snapshots
lxc info tak | grep Snapshots -A20
lxc delete tak/old-snapshot-name
```

---

## Safety Tips

⚠️ **Before making changes:**
```bash
lxc snapshot tak backup-$(date +%F-%H%M)
```

⚠️ **Before deleting a container:**
```bash
# Make sure you have the right one!
lxc list | grep name-to-delete

# Consider snapshot or export first
lxc export tak tak-export.tar.gz
```

⚠️ **Testing commands:**
```bash
# Test on a clone, not production
lxc copy tak tak-test
lxc start tak-test
# Experiment on tak-test
```

---

## Further Reading

- Official LXD Docs: https://linuxcontainers.org/lxd/docs/latest/
- LXD GitHub: https://github.com/canonical/lxd
- Ubuntu LXD Tutorial: https://ubuntu.com/tutorials/introduction-to-lxd

---

*Bookmark this page for quick reference during your TAK Server deployment!*
