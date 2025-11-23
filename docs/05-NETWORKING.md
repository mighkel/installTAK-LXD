# Networking & Reverse Proxy Setup

**Phase 5: Exposing TAK Server to the internet with HAProxy**

This guide covers making your TAK Server accessible from outside the VPS using port forwarding and reverse proxy.

---

## Prerequisites

Before starting Phase 5, verify:

- [ ] TAK Server is running and accessible from within container
- [ ] Certificates are working (Phase 4 complete)
- [ ] Domain DNS is configured pointing to your VPS IP
- [ ] UFW firewall is enabled with TAK ports allowed
- [ ] You've decided: LXD proxy device OR HAProxy

---

## Networking Architecture Overview

### Current State (After Phase 4)
```
Internet
    ↓
VPS (104.225.221.119)
    ↓
LXD Bridge (lxdbr0)
    ↓
TAK Container (10.206.248.11)
    ↓
TAK Server :8089, :8443, :8446
```

**Problem:** TAK Server is only accessible from inside the container!

### Goal State (After Phase 5)
```
Internet → tak.pinenut.tech:8089
    ↓
VPS Public IP (104.225.221.119:8089)
    ↓
[LXD Proxy OR HAProxy]
    ↓
TAK Container (10.206.248.11:8089)
    ↓
TAK Server
```

---

## Decision: LXD Proxy vs HAProxy

### Option A: LXD Proxy Device (Recommended for Single Service)

**Pros:**
- ✅ Simpler setup
- ✅ Built into LXD
- ✅ No additional container needed
- ✅ Less moving parts
- ✅ Perfect for TAK-only deployment

**Cons:**
- ❌ Less flexible for multiple services
- ❌ Limited load balancing options
- ❌ Basic health checking

### Option B: HAProxy (Recommended for Multiple Services)

**Pros:**
- ✅ Professional-grade load balancer
- ✅ Can proxy multiple services (TAK, web, NextCloud)
- ✅ Advanced health checks
- ✅ Statistics dashboard
- ✅ SSL termination options

**Cons:**
- ❌ More complex setup
- ❌ Requires separate container
- ❌ More configuration to maintain

**Choose LXD Proxy if:**
- This is your first TAK deployment
- TAK Server is your only service
- You want simplicity

**Choose HAProxy if:**
- You're hosting multiple services (NextCloud, web server, etc.)
- You need advanced features
- You're comfortable with proxy configuration

---

## Method A: LXD Proxy Device Setup

### Step 1: Configure LXD Proxy Devices
```bash
# From VPS host (not in container)

# Forward TAK client port (8089)
lxc config device add tak tak-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089

# Forward TAK web UI port (8443)
lxc config device add tak tak-8443 proxy \
    listen=tcp:0.0.0.0:8443 \
    connect=tcp:127.0.0.1:8443

# Forward certificate enrollment port (8446)
lxc config device add tak tak-8446 proxy \
    listen=tcp:0.0.0.0:8446 \
    connect=tcp:127.0.0.1:8446

# Verify devices added
lxc config show tak | grep -A 3 devices
```

### Step 2: Test External Access
```bash
# From VPS host, test connection
openssl s_client -connect localhost:8089 -showcerts

# From another machine, test external
openssl s_client -connect tak.pinenut.tech:8089 -showcerts

# Both should succeed! ✅
```

### Step 3: Skip to Step 7 (Verification)

If using LXD proxy, skip the HAProxy sections and jump to Step 7.

---

## Method B: HAProxy Setup

### Step 1: Create HAProxy Container
```bash
# From VPS host
lxc launch ubuntu:22.04 haproxy

# Wait for start
sleep 10

# Verify running
lxc list
```

### Step 2: Install HAProxy in Container
```bash
# Access HAProxy container
lxc exec haproxy -- bash

# Update and install HAProxy
apt update
apt install -y haproxy

# Verify installation
haproxy -v

# Expected: HAProxy version 2.4.x or higher
```

### Step 3: Configure HAProxy for TAK Server
```bash
# Backup original config
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original

# Create new config
nano /etc/haproxy/haproxy.cfg
```

**Paste this configuration:**
```haproxy
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # Intermediate configuration
    ssl-default-bind-ciphers ECDHE+AESGCM:ECDHE+CHACHA20:!RSA
    ssl-default-bind-options ssl-min-ver TLSv1.2

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  1m
    timeout server  1m
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

#--------------------------------------------------
# TAK Client Connections (Port 8089) - TCP Passthrough
#--------------------------------------------------
frontend tak-client
    bind *:8089
    mode tcp
    option tcplog
    default_backend tak-client-backend

backend tak-client-backend
    mode tcp
    option ssl-hello-chk
    server tak1 10.206.248.11:8089 check

#--------------------------------------------------
# TAK Web UI (Port 8443) - TCP Passthrough
#--------------------------------------------------
frontend tak-webui
    bind *:8443
    mode tcp
    option tcplog
    default_backend tak-webui-backend

backend tak-webui-backend
    mode tcp
    option ssl-hello-chk
    server takweb 10.206.248.11:8443 check

#--------------------------------------------------
# TAK Certificate Enrollment (Port 8446) - TCP Passthrough
#--------------------------------------------------
frontend tak-enrollment
    bind *:8446
    mode tcp
    option tcplog
    default_backend tak-enrollment-backend

backend tak-enrollment-backend
    mode tcp
    option ssl-hello-chk
    server takenroll 10.206.248.11:8446 check

#--------------------------------------------------
# HAProxy Statistics Page
#--------------------------------------------------
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy_stats
    stats refresh 30s
    stats auth admin:ChangeThisPassword
```

**Important notes:**
- Replace `10.206.248.11` with your TAK container's actual IP
- Change the stats password from `ChangeThisPassword`
- Using `mode tcp` for passthrough (not SSL termination)

**Save and exit** (Ctrl+X, Y, Enter)

### Step 4: Test HAProxy Configuration
```bash
# Test config syntax
haproxy -c -f /etc/haproxy/haproxy.cfg

# Expected output: Configuration file is valid
```

### Step 5: Start HAProxy
```bash
# Start HAProxy
systemctl start haproxy

# Enable auto-start
systemctl enable haproxy

# Check status
systemctl status haproxy

# Expected: active (running)
```

### Step 6: Forward Ports from VPS to HAProxy Container
```bash
# Exit HAProxy container
exit

# From VPS host, configure LXD proxy to HAProxy container
# Get HAProxy container IP first
lxc list haproxy

# Example IP: 10.206.248.12

# Forward ports to HAProxy container
lxc config device add haproxy proxy-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089

lxc config device add haproxy proxy-8443 proxy \
    listen=tcp:0.0.0.0:8443 \
    connect=tcp:127.0.0.1:8443

lxc config device add haproxy proxy-8446 proxy \
    listen=tcp:0.0.0.0:8446 \
    connect=tcp:127.0.0.1:8446

# Optional: Stats page
lxc config device add haproxy proxy-8404 proxy \
    listen=tcp:0.0.0.0:8404 \
    connect=tcp:127.0.0.1:8404
```

---

## Step 7: Verify External Access

### 7.1 Test from VPS Host
```bash
# Test TAK client port
openssl s_client -connect localhost:8089 -showcerts

# Should see certificate info for tak.pinenut.tech
```

### 7.2 Test from External Machine

**From your local computer (not the VPS):**
```bash
# Test TAK client connection
openssl s_client -connect tak.pinenut.tech:8089 -showcerts

# Should succeed and show certificate
```

### 7.3 Test Web UI

**In a web browser:**

1. Import `webadmin.p12` certificate to browser (if not already)
2. Navigate to: `https://tak.pinenut.tech:8443`
3. Should see TAK Server login page ✅

---

## Step 8: Firewall Configuration

Your UFW firewall should already allow TAK ports from Phase 1, but let's verify:

### 8.1 Check Current Firewall Rules
```bash
# From VPS host
sudo ufw status numbered
```

**Should show:**
```
[X]  8089/tcp              ALLOW IN    Anywhere    # TAK Client
[Y]  8443/tcp              ALLOW IN    Anywhere    # TAK WebUI
[Z]  8446/tcp              ALLOW IN    Anywhere    # TAK Enrollment
```

### 8.2 Add Rules if Missing
```bash
sudo ufw allow 8089/tcp comment 'TAK Client'
sudo ufw allow 8443/tcp comment 'TAK WebUI'
sudo ufw allow 8446/tcp comment 'TAK Enrollment'

# Optional: HAProxy stats
sudo ufw allow 8404/tcp comment 'HAProxy Stats'

# Reload firewall
sudo ufw reload
```

---

## Step 9: DNS Configuration

### 9.1 Verify DNS Records

Your domain must point to your VPS IP.
```bash
# Check DNS resolution
dig tak.pinenut.tech +short

# Should output: 104.225.221.119 (your VPS IP)

# Or use nslookup
nslookup tak.pinenut.tech

# Should show your VPS IP
```

### 9.2 DNS Record Setup

**If DNS is not configured:**

Login to your DNS provider (Cloudflare, GoDaddy, etc.) and create:
```
Type: A
Name: tak
Value: 104.225.221.119
TTL: 3600 (or Auto)
```

**Wait 5-60 minutes for DNS propagation.**

---

## Step 10: Optional - Let's Encrypt SSL Certificates

**Note:** This is OPTIONAL. TAK Server works perfectly with self-signed certificates.

Let's Encrypt is useful if you want browser-trusted certificates for the web UI.

### 10.1 Understanding the Limitation

**Important:** TAK clients (ATAK/WinTAK) use **mutual TLS** authentication. This means:
- Client presents certificate to server
- Server presents certificate to client
- Both verify each other

Let's Encrypt certificates are **one-way SSL** (server to client only). They can't be used for the main TAK client port (8089).

**Use Let's Encrypt for:**
- ✅ Web UI port 8443 (browser access)
- ✅ HTTP services on port 80/443

**Don't use Let's Encrypt for:**
- ❌ TAK client port 8089 (use self-signed)
- ❌ Certificate enrollment port 8446

### 10.2 Install Certbot (if using Let's Encrypt for web UI)
```bash
# From VPS host
sudo apt install -y certbot

# Verify installation
certbot --version
```

### 10.3 Obtain Certificate
```bash
# Request certificate (port 80 must be open)
sudo certbot certonly --standalone -d tak.pinenut.tech

# Follow prompts:
# - Enter email address
# - Agree to terms
# - Share email? (your choice)

# Certificates saved to:
# /etc/letsencrypt/live/tak.pinenut.tech/fullchain.pem
# /etc/letsencrypt/live/tak.pinenut.tech/privkey.pem
```

### 10.4 Convert for TAK Server (Optional)

If you want to use Let's Encrypt cert for web UI:
```bash
# Convert to PKCS12 format
sudo openssl pkcs12 -export \
    -in /etc/letsencrypt/live/tak.pinenut.tech/fullchain.pem \
    -inkey /etc/letsencrypt/live/tak.pinenut.tech/privkey.pem \
    -out /tmp/letsencrypt-tak.p12 \
    -name tak.pinenut.tech \
    -passout pass:atakatak

# Copy to container
lxc file push /tmp/letsencrypt-tak.p12 tak/opt/tak/certs/files/

# Update CoreConfig.xml to use this cert for web UI
# (Advanced - see TAK Server documentation)
```

**For most deployments, self-signed certificates work fine!**

---

## Step 11: HAProxy Monitoring (If using HAProxy)

### 11.1 Access Stats Page

**In web browser:**
```
http://your-vps-ip:8404/haproxy_stats
```

**Login:**
- Username: `admin`
- Password: (what you set in haproxy.cfg)

### 11.2 What to Monitor

- **Backend Status**: Should show "UP" in green
- **Queue**: Should be 0 or low
- **Session Rate**: Shows active connections
- **Errors**: Should be 0

### 11.3 HAProxy Logs
```bash
# View HAProxy logs
lxc exec haproxy -- tail -f /var/log/haproxy.log

# Or system journal
lxc exec haproxy -- journalctl -u haproxy -f
```

---

## Step 12: Troubleshooting Network Issues

### Issue: Can't connect from external network

**Diagnose step-by-step:**

1. **Check TAK Server is running in container:**
```bash
   lxc exec tak -- systemctl status takserver
```

2. **Test from within container:**
```bash
   lxc exec tak -- openssl s_client -connect localhost:8089
```

3. **Test from VPS host:**
```bash
   openssl s_client -connect localhost:8089
```

4. **Check firewall:**
```bash
   sudo ufw status | grep 8089
```

5. **Check LXD proxy devices:**
```bash
   lxc config show tak | grep proxy
   # or
   lxc config show haproxy | grep proxy
```

6. **Check external connectivity:**
```bash
   # From another machine
   telnet tak.pinenut.tech 8089
   # Should connect
```

### Issue: SSL handshake failure from external

**Common causes:**

1. **Wrong domain in certificate:**
```bash
   lxc exec tak -- openssl s_client -connect localhost:8089 -showcerts | grep subject
   # subject=CN=tak.pinenut.tech (must match!)
```

2. **TAK Server not restarted after cert changes:**
```bash
   lxc exec tak -- sudo systemctl restart takserver
```

3. **HAProxy terminating SSL instead of passthrough:**
   - Check haproxy.cfg has `mode tcp` not `mode http`
   - Check for `ssl-hello-chk` in backend

### Issue: HAProxy won't start

**Check config syntax:**
```bash
lxc exec haproxy -- haproxy -c -f /etc/haproxy/haproxy.cfg

# Fix any errors shown
```

**Check logs:**
```bash
lxc exec haproxy -- journalctl -u haproxy -n 50
```

### Issue: DNS not resolving

**Check DNS propagation:**
```bash
# Check from multiple DNS servers
dig @8.8.8.8 tak.pinenut.tech
dig @1.1.1.1 tak.pinenut.tech

# Should both return your VPS IP
```

**Clear local DNS cache:**
```bash
# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns

# Mac
sudo dscacheutil -flushcache
```

---

## Step 13: Network Performance Tuning (Optional)

### 13.1 Increase Connection Limits
```bash
# On VPS host, increase file descriptors
sudo nano /etc/sysctl.conf

# Add these lines:
fs.file-max = 65536
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1

# Apply changes
sudo sysctl -p
```

### 13.2 HAProxy Tuning
```bash
lxc exec haproxy -- nano /etc/haproxy/haproxy.cfg

# In 'global' section, add:
maxconn 4096
tune.ssl.default-dh-param 2048

# Restart HAProxy
lxc exec haproxy -- systemctl restart haproxy
```

---

## Step 14: Backup Network Configuration

### 14.1 Document Configuration

Create a file with your network setup:
```bash
cat > ~/tak-network-config.txt <<EOF
=== TAK Server Network Configuration ===

VPS IP: 104.225.221.119
Domain: tak.pinenut.tech
DNS Provider: [Your provider]

Container IPs:
- tak: 10.206.248.11
- haproxy: 10.206.248.12 (if using)

LXD Proxy Devices:
$(lxc config show tak | grep -A 3 devices)

Firewall Rules:
$(sudo ufw status numbered | grep -E "8089|8443|8446")

HAProxy Status: [Using / Not Using]

Last Updated: $(date)
EOF

cat ~/tak-network-config.txt
```

### 14.2 Backup Configurations
```bash
# Backup HAProxy config (if using)
lxc file pull haproxy/etc/haproxy/haproxy.cfg ~/haproxy.cfg.backup

# Backup LXD config
lxc config show tak > ~/lxd-tak-config.yaml
```

---

## Step 15: Verification Checklist

Before proceeding to Phase 6:

- [ ] Chosen networking method (LXD proxy OR HAProxy)
- [ ] Port forwarding configured and working
- [ ] Can connect to `tak.pinenut.tech:8089` from external network
- [ ] Can access web UI at `https://tak.pinenut.tech:8443`
- [ ] DNS resolves correctly
- [ ] Firewall rules are configured
- [ ] HAProxy is running (if using)
- [ ] HAProxy stats accessible (if using)
- [ ] Network configuration documented

### Quick Network Test Script
```bash
#!/bin/bash
echo "=== TAK Server Network Verification ==="

echo -n "DNS resolves: "
dig +short tak.pinenut.tech | grep -q "104.225.221.119" && echo "✅" || echo "❌"

echo -n "Port 8089 accessible: "
timeout 5 bash -c '</dev/tcp/tak.pinenut.tech/8089' && echo "✅" || echo "❌"

echo -n "Port 8443 accessible: "
timeout 5 bash -c '</dev/tcp/tak.pinenut.tech/8443' && echo "✅" || echo "❌"

echo -n "SSL handshake works: "
echo | openssl s_client -connect tak.pinenut.tech:8089 2>/dev/null | grep -q "Verify return code: 0" && echo "✅" || echo "⚠️  (self-signed is OK)"

echo -n "TAK Server running: "
lxc exec tak -- systemctl is-active takserver &>/dev/null && echo "✅" || echo "❌"

if lxc list | grep -q "haproxy.*RUNNING"; then
    echo -n "HAProxy running: "
    lxc exec haproxy -- systemctl is-active haproxy &>/dev/null && echo "✅" || echo "❌"
fi

echo ""
echo "If all checks show ✅ or ⚠️, proceed to Phase 6: Verification & Testing"
```

---

## Next Steps

Once networking is configured and tested:

**➡️ Proceed to:** [Phase 6: Verification & Testing](06-VERIFICATION.md)

This final phase covers:
- Connecting ATAK clients to the server
- Testing all TAK Server features
- Performance verification
- Production readiness checklist

---

## Additional Resources

- **HAProxy Documentation:** https://www.haproxy.org/
- **LXD Proxy Devices:** https://documentation.ubuntu.com/lxd/en/latest/howto/instances_configure/#proxy-devices
- **Let's Encrypt Guide:** https://letsencrypt.org/getting-started/
- **UFW Guide:** https://help.ubuntu.com/community/UFW

---

*Last Updated: November 2025*  
*Tested on: Ubuntu 22.04 LTS*  
*HAProxy Version: 2.4+*
