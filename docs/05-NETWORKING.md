# Networking & Reverse Proxy Setup

**Phase 5: Exposing TAK Server to the internet with HAProxy**

This guide covers making your TAK Server accessible from outside the VPS using port forwarding and reverse proxy.

---

## Prerequisites

Before starting Phase 5, verify:

- [ ] TAK Server is installed and running
- [ ] TAK Server accessible from within container
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

---

## Step 3A: Multi-Service HAProxy Configuration

**Use this configuration if you're running multiple services** (TAK + Web + NextCloud + MediaMTX + others)

### Understanding Service Types

HAProxy handles different service types differently:

**TCP Passthrough (for TAK Server):**
- HAProxy forwards raw TCP traffic
- No SSL termination - TAK handles its own certificates
- Required for mutual TLS authentication
- Ports: 8089, 8443, 8446

**HTTP/HTTPS (for web services):**
- HAProxy can terminate SSL or passthrough
- Domain-based routing (SNI)
- Can share port 80/443 across multiple services
- Services: Web server, NextCloud

**TCP with different ports (for MediaMTX):**
- Simple TCP forwarding on unique ports
- No SSL complexity
- Port: 8554 (RTSP)

---

### Step 3A.1: Plan Your Container IPs

Before configuring HAProxy, document your container IPs:
```bash
# Create containers (if not already created)
lxc launch ubuntu:22.04 tak        # TAK Server
lxc launch ubuntu:22.04 haproxy    # HAProxy reverse proxy
lxc launch ubuntu:22.04 web        # Web server (optional)
lxc launch ubuntu:22.04 nextcloud  # NextCloud (future)
lxc launch ubuntu:22.04 mediamtx   # MediaMTX (future)

# Wait for network assignment
sleep 10

# List all container IPs
lxc list -c n4

# Example output:
# +----------+---------------------+
# |   NAME   |        IPV4         |
# +----------+---------------------+
# | tak      | 10.206.248.11       |
# | haproxy  | 10.206.248.12       |
# | web      | 10.206.248.13       |
# | nextcloud| 10.206.248.14       |
# | mediamtx | 10.206.248.15       |
# +----------+---------------------+
```

**Document these IPs - you'll need them for HAProxy config!**

---

### Step 3A.2: Complete Multi-Service HAProxy Configuration
```bash
# Access HAProxy container
lxc exec haproxy -- bash

# Backup original config
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original

# Create new multi-service config
nano /etc/haproxy/haproxy.cfg
```

**Paste this complete configuration:**
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

    # SSL/TLS configuration
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers ECDHE+AESGCM:ECDHE+CHACHA20:!RSA
    ssl-default-bind-options ssl-min-ver TLSv1.2
    
    # Performance tuning
    maxconn 4096
    tune.ssl.default-dh-param 2048

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

#============================================================
# TAK SERVER - TCP PASSTHROUGH (Mutual TLS)
#============================================================

# TAK Client Connections (Port 8089)
frontend tak-client
    bind *:8089
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    default_backend tak-client-backend

backend tak-client-backend
    mode tcp
    option ssl-hello-chk
    server tak1 10.206.248.11:8089 check

# TAK Web UI (Port 8443)
frontend tak-webui
    bind *:8443
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    default_backend tak-webui-backend

backend tak-webui-backend
    mode tcp
    option ssl-hello-chk
    server takweb 10.206.248.11:8443 check

# TAK Certificate Enrollment (Port 8446)
frontend tak-enrollment
    bind *:8446
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    default_backend tak-enrollment-backend

backend tak-enrollment-backend
    mode tcp
    option ssl-hello-chk
    server takenroll 10.206.248.11:8446 check

#============================================================
# WEB SERVICES - HTTP/HTTPS with SNI Routing
#============================================================

# HTTP Frontend (Port 80)
# Handles: ACME challenges, HTTP redirects, non-SSL traffic
frontend http-in
    bind *:80
    mode http
    option httplog
    
    # Log format
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
    
    # ACME Challenge routing for Let's Encrypt
    acl is_acme_challenge path_beg /.well-known/acme-challenge/
    
    # Route ACME challenges to TAK container (has certbot)
    use_backend tak-acme-backend if is_acme_challenge
    
    # Domain-based routing
    acl host_web hdr(host) -i web.pinenut.tech
    acl host_nc hdr(host) -i nc.pinenut.tech
    
    use_backend web-backend if host_web
    use_backend nextcloud-backend if host_nc
    
    # Default: Redirect to HTTPS
    http-request redirect scheme https code 301 unless is_acme_challenge

backend tak-acme-backend
    mode http
    server tak 10.206.248.11:80 check

backend web-backend
    mode http
    server web1 10.206.248.13:80 check

backend nextcloud-backend
    mode http
    server nextcloud1 10.206.248.14:80 check

# HTTPS Frontend (Port 443)
# Handles: SSL/TLS web traffic with SNI routing
frontend https-in
    bind *:443
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    
    # SNI-based routing
    acl host_web req.ssl_sni -i web.pinenut.tech
    acl host_nc req.ssl_sni -i nc.pinenut.tech
    
    use_backend web-ssl-backend if host_web
    use_backend nextcloud-ssl-backend if host_nc
    
    # Default backend
    default_backend web-ssl-backend

backend web-ssl-backend
    mode tcp
    option ssl-hello-chk
    server web1 10.206.248.13:443 check

backend nextcloud-ssl-backend
    mode tcp
    option ssl-hello-chk
    server nextcloud1 10.206.248.14:443 check

#============================================================
# MEDIAMTX - RTSP Video Streaming (Port 8554)
#============================================================

frontend rtsp-in
    bind *:8554
    mode tcp
    option tcplog
    default_backend rtsp-backend

backend rtsp-backend
    mode tcp
    server mediamtx1 10.206.248.15:8554 check

#============================================================
# HAPROXY STATISTICS & MONITORING
#============================================================

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /haproxy_stats
    stats refresh 30s
    stats auth admin:ChangeThisStatsPassword123
    stats admin if TRUE
```

**Important:** 
- Replace `10.206.248.X` with your actual container IPs
- Change stats password from `ChangeThisStatsPassword123`
- Update domain names (pinenut.tech) to your actual domain

**Save and exit** (Ctrl+X, Y, Enter)

---

### Step 3A.3: Test and Apply Configuration
```bash
# Test configuration syntax
haproxy -c -f /etc/haproxy/haproxy.cfg

# Expected: Configuration file is valid

# If valid, restart HAProxy
systemctl restart haproxy

# Check status
systemctl status haproxy

# View logs in real-time
tail -f /var/log/haproxy.log
```

---

### Step 3A.4: Understanding the Configuration

**TAK Server Section:**
```haproxy
frontend tak-client
    bind *:8089
    mode tcp              # Raw TCP passthrough
    option ssl-hello-chk  # Check SSL handshake
    default_backend tak-client-backend
```
- **No SSL termination** - TAK handles its own certificates
- **Mutual TLS** - Client and server authenticate each other
- **Required** for TAK client authentication to work

**Web Services Section:**
```haproxy
frontend https-in
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    acl host_web req.ssl_sni -i web.pinenut.tech
    use_backend web-ssl-backend if host_web
```
- **SNI inspection** - Routes by domain name
- **Multiple services** on same port (443)
- **Can terminate SSL** at HAProxy or passthrough to backend

**MediaMTX Section:**
```haproxy
frontend rtsp-in
    bind *:8554
    mode tcp
    default_backend rtsp-backend
```
- **Simple TCP forwarding**
- **Dedicated port** - no routing needed
- **No SSL** - RTSP typically unencrypted (use RTSPS if needed)

---

### Step 3A.5: Accessing HAProxy Statistics

HAProxy provides a web-based statistics page on port 8404. There are several ways to access it securely.

#### Option A: SSH Tunnel (Most Secure - Recommended)

Access stats without exposing port 8404 to the internet.

**From Windows (PowerShell or Command Prompt):**
```cmd
ssh -L 8404:localhost:8404 username@your-vps-ip

# Leave this terminal open
```

**From Linux/Mac:**
```bash
ssh -L 8404:localhost:8404 username@your-vps-ip

# Leave this terminal open
```

**Then open in your local browser:**
```
http://localhost:8404/haproxy_stats
```

**Credentials:**
- Username: `admin`
- Password: (what you set in haproxy.cfg)

**Using PuTTY (Windows GUI):**

1. Open PuTTY
2. Session → Host Name: `your-vps-ip`
3. Connection → SSH → Tunnels:
   - Source port: `8404`
   - Destination: `localhost:8404`
   - Click "Add"
4. Click "Open" and login
5. Open browser: `http://localhost:8404/haproxy_stats`

**Benefits:**
- Stats page not exposed to internet
- No firewall changes needed
- Works from anywhere (including CGNAT networks)
- Most secure option for production

#### Option B: Allow Through Firewall (Less Secure)

If you must expose stats to internet (not recommended for production):

```bash
# Exit HAProxy container
exit

# On VPS host, allow port 8404
sudo ufw allow 8404/tcp

# Access in browser:
http://your-vps-ip:8404/haproxy_stats
```

**Security concerns:**
- Exposed to internet (password-protected but visible)
- Subject to brute force attempts
- Not recommended for production deployments

#### Option C: IP Whitelisting (Good if Static IP)

Restrict access to your IP only:

```bash
# Allow only from your IP
sudo ufw allow from YOUR_IP to any port 8404

# Find your IP:
curl https://icanhazip.com
```

**Limitation:** Doesn't work with CGNAT or dynamic IPs (see CGNAT section below).

#### Option D: Close Port, Use SSH Tunnel Only (Recommended)

Most secure for production:

```bash
# Make sure port 8404 is NOT in firewall rules
sudo ufw status | grep 8404

# If it exists, remove it:
sudo ufw delete allow 8404/tcp

# Always use SSH tunnel to access stats
```

This ensures stats are never accessible from the internet.

---

### Step 3A.6: CGNAT and Dynamic IP Considerations

**What is CGNAT?**

Carrier-Grade NAT (CGNAT) is when your ISP shares a single public IP address among multiple customers. This affects how you access your services.

**Symptoms of CGNAT:**
- Your "public IP" starts with 100.x.x.x (RFC 6598 address space)
- Can't access your server from outside even with ports open
- Port forwarding from your router doesn't work
- Your IP changes frequently

**Checking if you have CGNAT:**
```bash
# Get your public IP
curl https://icanhazip.com

# Compare with your router's WAN IP
# If they don't match, you likely have CGNAT
# If IP starts with 100.x.x.x, you definitely have CGNAT
```

**Solutions for CGNAT:**

1. **Request Static Public IP from ISP** (sometimes available for business accounts)
2. **Use VPN Service** (Tailscale, WireGuard, CloudFlare Tunnel)
3. **Rent VPS with Public IP** (what we're doing in this guide!)
4. **IPv6 Only** (if ISP provides native IPv6)

**For HAProxy Stats with CGNAT:**
- ✅ Always use SSH tunnel (Option A above) - works perfectly with CGNAT
- ❌ IP whitelisting won't work (your IP is shared/dynamic)
- ❌ Direct access usually blocked by ISP

**Why This Guide Works with CGNAT:**

This entire guide deploys TAK Server on a VPS with a real public IP, so CGNAT at your home/office doesn't matter. You're accessing the VPS's public IP, not exposing your local network.

---

### Step 3A.7: Port Forwarding to HAProxy Container

Now forward ports from VPS host to HAProxy container:

```bash
# Exit HAProxy container
exit

# From VPS host, get HAProxy container IP
lxc list haproxy -c 4

# Forward all required ports to HAProxy container
lxc config device add haproxy proxy-80 proxy \
    listen=tcp:0.0.0.0:80 \
    connect=tcp:127.0.0.1:80

lxc config device add haproxy proxy-443 proxy \
    listen=tcp:0.0.0.0:443 \
    connect=tcp:127.0.0.1:443

lxc config device add haproxy proxy-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089

lxc config device add haproxy proxy-8443 proxy \
    listen=tcp:0.0.0.0:8443 \
    connect=tcp:127.0.0.1:8443

lxc config device add haproxy proxy-8446 proxy \
    listen=tcp:0.0.0.0:8446 \
    connect=tcp:127.0.0.1:8446

lxc config device add haproxy proxy-8554 proxy \
    listen=tcp:0.0.0.0:8554 \
    connect=tcp:127.0.0.1:8554

# Optional: Stats page (if exposing - not recommended)
# lxc config device add haproxy proxy-8404 proxy \
#     listen=tcp:0.0.0.0:8404 \
#     connect=tcp:127.0.0.1:8404

# Verify all proxy devices
lxc config show haproxy | grep -A 3 proxy
```

**⚠️ Warning About Port Forwards**

**Common mistake:** Adding temporary port forwards to test services early, then forgetting to remove them before adding HAProxy forwards.

**Problem:**
```bash
# User adds temporary forward to test TAK web UI in Phase 4
lxc config device add tak port8443 proxy listen=tcp:0.0.0.0:8443 connect=tcp:127.0.0.1:8443

# Later in Phase 5, when adding HAProxy forwards:
lxc config device add haproxy proxy-8443 proxy listen=tcp:0.0.0.0:8443 connect=tcp:127.0.0.1:8443
# ERROR: Failed to start device "proxy-8443": address already in use
```

**If you added temporary forwards earlier:**
```bash
# Check for existing forwards
lxc config device list tak

# Remove any temporary forwards
lxc config device remove tak port8443
lxc config device remove tak port80
lxc config device remove tak port8089

# Verify clean
lxc config show tak | grep -A 3 devices

# Now add HAProxy forwards
```

**Best practice:**
- Follow phases in order
- Don't add temporary forwards to test early
- Wait until Phase 5 to expose services
- Test locally inside containers during Phase 3-4

---

### Step 3A.8: DNS Configuration for Multi-Service

Configure DNS A records for all services:

| Hostname | Type | Value | TTL |
|----------|------|-------|-----|
| tak.pinenut.tech | A | 104.225.221.119 | 3600 |
| web.pinenut.tech | A | 104.225.221.119 | 3600 |
| nc.pinenut.tech | A | 104.225.221.119 | 3600 |
| rtsp.pinenut.tech | A | 104.225.221.119 | 3600 |

**All point to same VPS IP** - HAProxy routes by domain name!

---

### Step 3A.9: Testing Multi-Service Routing

**Test TAK Server:**
```bash
openssl s_client -connect tak.pinenut.tech:8089 -showcerts
# Should connect to TAK container
```

**Test Web Server (when configured):**
```bash
curl -I http://web.pinenut.tech
# Should route to web container
```

**Test NextCloud (when configured):**
```bash
curl -I http://nc.pinenut.tech
# Should route to nextcloud container
```

**Test MediaMTX (when configured):**
```bash
telnet rtsp.pinenut.tech 8554
# Should connect to mediamtx container
```

**Test HAProxy Stats (via SSH tunnel):**
```bash
# Create SSH tunnel
ssh -L 8404:localhost:8404 username@your-vps-ip

# Open in browser:
http://localhost:8404/haproxy_stats
```

---

### Step 3A.10: Future Service Addition

**To add a new service later:**

1. **Create container:**
```bash
   lxc launch ubuntu:22.04 newservice
   lxc list newservice -c 4  # Note the IP
```

2. **Add to HAProxy config:**
```bash
   lxc exec haproxy -- nano /etc/haproxy/haproxy.cfg
   
   # Add frontend ACL:
   acl host_newservice hdr(host) -i newservice.pinenut.tech
   use_backend newservice-backend if host_newservice
   
   # Add backend:
   backend newservice-backend
       mode http
       server newservice1 10.206.248.XX:80 check
```

3. **Restart HAProxy:**
```bash
   lxc exec haproxy -- systemctl restart haproxy
```

4. **Add DNS record:**
   - Create A record: `newservice.pinenut.tech` → VPS IP

---

### Step 3A.11: HAProxy Monitoring Commands
```bash
# View real-time logs
lxc exec haproxy -- tail -f /var/log/haproxy.log

# Check backend status
lxc exec haproxy -- bash
echo "show stat" | socat stdio /run/haproxy/admin.sock

# View current sessions
echo "show sess" | socat stdio /run/haproxy/admin.sock

# Test config before applying changes
haproxy -c -f /etc/haproxy/haproxy.cfg

# Reload without downtime (after config changes)
systemctl reload haproxy
```

---

### Step 3A.12: SSL Certificate Strategy

**For TAK Server:**
- ✅ Uses self-signed or Let's Encrypt certificates
- ✅ Mutual TLS authentication
- ✅ HAProxy does TCP passthrough (no SSL termination)

**For Web Services (web, NextCloud):**
- Option A: Self-signed certificates in each container
- Option B: Let's Encrypt at HAProxy (SSL termination)
- Option C: Let's Encrypt in each container (passthrough)

**Recommended for your setup:**
- TAK Server: Let's Encrypt (see Phase 5B)
- Web/NextCloud: Let's Encrypt in each container
- HAProxy: TCP passthrough for all SSL traffic

---

## Continuing to Single-Service Setup...

**If you're only running TAK Server** (no other services), skip to the original Step 4 configuration. Otherwise, use Step 3A above for your multi-service deployment.

---

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
lxc list haproxy -c 4

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

# Stats page - only if exposing (use SSH tunnel instead)
# lxc config device add haproxy proxy-8404 proxy \
#     listen=tcp:0.0.0.0:8404 \
#     connect=tcp:127.0.0.1:8404
```

**Note on Port Forward Naming:**

Use descriptive names for proxy devices:
```bash
# Good naming:
lxc config device add haproxy proxy-80 proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80
lxc config device add haproxy proxy-8089 proxy listen=tcp:0.0.0.0:8089 connect=tcp:127.0.0.1:8089

# Also acceptable:
lxc config device add haproxy http-proxy proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80
lxc config device add haproxy tak-client proxy listen=tcp:0.0.0.0:8089 connect=tcp:127.0.0.1:8089

# Avoid ambiguous names:
lxc config device add haproxy port1 proxy ...  # What port is this?
lxc config device add haproxy test proxy ...   # Not descriptive
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

# Note: Do NOT open 8404 for HAProxy stats - use SSH tunnel instead

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

## Step 10: Verification Checklist

Before proceeding to Phase 5B:

- [ ] Chosen networking method (LXD proxy OR HAProxy)
- [ ] Port forwarding configured and working
- [ ] Can connect to `tak.pinenut.tech:8089` from external network
- [ ] Can access web UI at `https://tak.pinenut.tech:8443`
- [ ] DNS resolves correctly
- [ ] Firewall rules are configured
- [ ] HAProxy is running (if using)
- [ ] HAProxy stats accessible via SSH tunnel (if using HAProxy)
- [ ] No temporary port forwards causing conflicts
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
echo "If all checks show ✅ or ⚠️, proceed to Phase 5B: Let's Encrypt Setup"
```

---

## Step 11: Common Pitfalls and Solutions

### Pitfall 1: Jumped Ahead to Test Web UI

**Problem:** Added temporary port forward in Phase 3-4 to test web UI early, causes conflicts in Phase 5.

**Symptoms:**
```bash
lxc config device add haproxy proxy-8443 proxy listen=tcp:0.0.0.0:8443 connect=tcp:127.0.0.1:8443
# Error: address already in use
```

**Solution:**
```bash
# Remove all temporary forwards
lxc config device remove tak port8443
lxc config device remove tak port80
lxc config device remove tak port8089

# Verify clean
lxc config show tak | grep -A 3 devices

# Continue with Phase 5 HAProxy setup
```

### Pitfall 2: Forgot to Remove Old Forwards

**Problem:** Old device forwards conflict with HAProxy forwards.

**Symptom:** `Error: address already in use`

**Solution:**
```bash
# List all device forwards
lxc config device list tak
lxc config device list haproxy

# Remove conflicting ones
lxc config device remove [container] [device-name]
```

### Pitfall 3: Wrong Container for Port Forwards

**Problem:** Added HAProxy port forwards to TAK container instead of HAProxy container.

**Solution:**
```bash
# Remove from wrong container
lxc config device remove tak proxy-8089

# Add to correct container (haproxy)
lxc config device add haproxy proxy-8089 proxy listen=tcp:0.0.0.0:8089 connect=tcp:127.0.0.1:8089
```

### Pitfall 4: Can't Access Stats Page

**Symptoms:**
- Timeout accessing `http://ip:8404/haproxy_stats`
- Connection refused

**Causes & Solutions:**

1. **Port exposed but should use SSH tunnel (recommended):**
```bash
   # Close port 8404 in firewall
   sudo ufw delete allow 8404/tcp
   
   # Use SSH tunnel instead
   ssh -L 8404:localhost:8404 username@vps-ip
   # Then: http://localhost:8404/haproxy_stats
```

2. **HAProxy not running:**
```bash
   lxc exec haproxy -- systemctl status haproxy
   lxc exec haproxy -- systemctl restart haproxy
```

3. **Port forward missing (if you want direct access - not recommended):**
```bash
   # Only if you really need direct access
   lxc config device add haproxy proxy-8404 proxy listen=tcp:0.0.0.0:8404 connect=tcp:127.0.0.1:8404
   sudo ufw allow 8404/tcp
```

### Pitfall 5: HAProxy Shows 503 for Backends

**Problem:** HAProxy stats show backends in red (DOWN) or returning 503 errors.

**This is normal if:**
- Backend containers don't exist yet (web, nextcloud)
- Backend services not running (MediaMTX, nginx)
- Only TAK Server configured so far

**Check if TAK backends are up:**
```bash
# Access HAProxy stats via SSH tunnel
# Look for:
# - tak-client-backend (should be green/UP)
# - tak-webui-backend (should be green/UP)
# - tak-enrollment-backend (should be green/UP)

# Red/down backends you can ignore for now:
# - web-backend (if no web container)
# - nextcloud-backend (if no nextcloud container)
# - rtsp-backend (if no MediaMTX)
```

**If TAK backends show DOWN:**
```bash
# Check TAK Server running
lxc exec tak -- systemctl status takserver

# Check TAK container IP matches HAProxy config
lxc list tak -c 4
lxc exec haproxy -- grep -A 5 "tak.*backend" /etc/haproxy/haproxy.cfg

# Verify IPs match, update if needed
# Restart HAProxy after config changes
lxc exec haproxy -- systemctl restart haproxy
```

### Pitfall 6: Testing Before Phase 5 Complete

**Problem:** Trying to access TAK Server from internet before networking is set up.

**Best practices:**
```bash
# Phase 3-4: Test locally INSIDE containers
lxc exec tak -- curl -k https://localhost:8443
lxc exec tak -- openssl s_client -connect localhost:8089

# Phase 5: After port forwarding, test from VPS host
curl -k https://tak.pinenut.tech:8443
openssl s_client -connect tak.pinenut.tech:8089

# Phase 5 complete: Test from external machine
# (from your local computer)
```

---

## Step 12: Network Performance Tuning (Optional)

### 12.1 Increase Connection Limits
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

### 12.2 HAProxy Tuning
```bash
lxc exec haproxy -- nano /etc/haproxy/haproxy.cfg

# In 'global' section, add:
maxconn 4096
tune.ssl.default-dh-param 2048

# Restart HAProxy
lxc exec haproxy -- systemctl restart haproxy
```

---

## Step 13: Backup Network Configuration

### 13.1 Document Configuration

Create a file with your network setup:
```bash
cat > ~/tak-network-config.txt <<EOF
=== TAK Server Network Configuration ===

VPS IP: 104.225.221.119
Domain: tak.pinenut.tech
DNS Provider: [Your provider]

Container IPs:
- tak: $(lxc list tak -c 4 --format csv | cut -d' ' -f1)
- haproxy: $(lxc list haproxy -c 4 --format csv | cut -d' ' -f1 2>/dev/null || echo "Not using HAProxy")

LXD Proxy Devices:
$(lxc config show tak | grep -A 3 devices)
$(lxc config show haproxy 2>/dev/null | grep -A 3 devices || echo "")

Firewall Rules:
$(sudo ufw status numbered | grep -E "8089|8443|8446")

HAProxy Status: $(lxc list haproxy 2>/dev/null | grep -q "RUNNING" && echo "Using" || echo "Not Using")

Last Updated: $(date)
EOF

cat ~/tak-network-config.txt
```

### 13.2 Backup Configurations
```bash
# Backup HAProxy config (if using)
lxc file pull haproxy/etc/haproxy/haproxy.cfg ~/haproxy.cfg.backup 2>/dev/null

# Backup LXD config
lxc config show tak > ~/lxd-tak-config.yaml
lxc config show haproxy > ~/lxd-haproxy-config.yaml 2>/dev/null
```

---

## Step 14: Troubleshooting Network Issues

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
   lxc exec tak -- systemctl restart takserver
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

## Next Steps

Once networking is configured and tested:

**✅ Completed:**
- Phase 1: LXD Setup
- Phase 2: Container Setup  
- Phase 3: TAK Installation
- Phase 4: Certificate Management
- **Phase 5: Networking** ← You are here

**➡️ Proceed to:** [Phase 5B: Let's Encrypt SSL Setup](05B-LETSENCRYPT-SETUP.md)

Optional but recommended: Replace self-signed certificates with Let's Encrypt for browser-trusted SSL.

---

## Additional Resources

- **HAProxy Documentation:** https://www.haproxy.org/
- **LXD Proxy Devices:** https://documentation.ubuntu.com/lxd/en/latest/howto/instances_configure/#proxy-devices
- **UFW Guide:** https://help.ubuntu.com/community/UFW
- **SSH Tunneling Guide:** https://www.ssh.com/academy/ssh/tunneling-example

---

*Last Updated: November 24, 2025*  
*Tested on: Ubuntu 22.04/24.04 LTS*  
*HAProxy Version: 2.4+*  
*Deployment: Clear Creek VFD / Boise County SO*
