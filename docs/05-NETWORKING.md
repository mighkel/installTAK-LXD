# Networking & Reverse Proxy Setup

**Phase 5: Exposing TAK Server to the internet with HAProxy and Let's Encrypt**

This guide covers making your TAK Server accessible from outside the VPS using port forwarding, reverse proxy, and optional SSL certificates from Let's Encrypt.

---

## Document Conventions

See [Phase 1: LXD Setup](01-LXD-SETUP.md#document-conventions) for the full conventions guide.

**Quick Reference:**
| Symbol | Meaning |
|--------|---------|
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside containers) |
| 📦 | **Inside Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - Replace placeholder values |

**Where Am I? (Check Your Prompt)**
| Prompt Looks Like | You Are |
|-------------------|---------|
| `takadmin@your-vps:~$` | 🖥️ VPS Host |
| `root@tak:~#` | 📦 Inside TAK container |
| `root@haproxy:~#` | 📦 Inside HAProxy container |

**Placeholders used in this document:**
- `[YOUR_DOMAIN]` - Your TAK server FQDN (e.g., `tak.example.com`)
- `[YOUR_BASE_DOMAIN]` - Your base domain (e.g., `example.com`)
- `[YOUR_VPS_IP]` - Your VPS public IP address
- `[YOUR_HOSTNAME]` - TAK container hostname (run `hostname` inside container)
- `[TAK_CONTAINER_IP]` - TAK container's internal IP (from `lxc list`)
- `[HAPROXY_CONTAINER_IP]` - HAProxy container's internal IP
- `[MEDIAMTX_CONTAINER_IP]` - MediaMTX container IP (if using video streaming)
- `[NEXTCLOUD_CONTAINER_IP]` - NextCloud container IP (if using file sharing)
- `[YOUR_EMAIL]` - Your email for Let's Encrypt notifications
- `[CERT_PASSWORD]` - Your certificate password
- `[STATS_PASSWORD]` - Password for HAProxy stats page

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `TAK_HOSTNAME="[YOUR_HOSTNAME]"` becomes `TAK_HOSTNAME="mytakserver"`
> (Keep the quotes, remove the brackets)

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
VPS ([YOUR_VPS_IP])
    ↓
LXD Bridge (lxdbr0)
    ↓
TAK Container ([TAK_CONTAINER_IP])
    ↓
TAK Server :8089, :8443, :8446
```

**Problem:** TAK Server is only accessible from inside the container!

### Goal State (After Phase 5)

```
Internet → [YOUR_DOMAIN]:8089
    ↓
VPS Public IP ([YOUR_VPS_IP]:8089)
    ↓
[LXD Proxy OR HAProxy]
    ↓
TAK Container ([TAK_CONTAINER_IP]:8089)
    ↓
TAK Server
```

---

## Step 1: Decision - LXD Proxy vs HAProxy

### Option A: LXD Proxy Device (Single Service ONLY)

**Use this ONLY if:**
- ✅ TAK Server is your ONLY service
- ✅ No web server, no NextCloud, no other apps
- ✅ Simple deployment

**Pros:**
- ✅ Simpler setup
- ✅ Built into LXD
- ✅ No additional container needed
- ✅ Less moving parts

**Cons:**
- ❌ Cannot handle multiple services well
- ❌ No domain-based routing
- ❌ Limited load balancing options

### Option B: HAProxy (Multi-Service - RECOMMENDED)

**Use this if you're running (or might run):**
- ✅ TAK Server
- ✅ Web server (Apache/Nginx)
- ✅ NextCloud or file sharing
- ✅ MediaMTX (RTSP streaming)
- ✅ Any combination of services

**Pros:**
- ✅ Professional-grade reverse proxy
- ✅ Route by domain/subdomain
- ✅ Advanced health checks
- ✅ Statistics dashboard
- ✅ Room to grow

**Cons:**
- ❌ More complex initial setup
- ❌ Requires separate container

> 💡 **RECOMMENDATION**
> Even if you're only running TAK Server now, **HAProxy is recommended** if you might add services later. It's easier to set up from the start than to migrate later.

---

## Step 2: Method A - LXD Proxy Device Setup

> 💡 **SKIP THIS SECTION** if you're using HAProxy (Method B). Jump to [Step 3](#step-3-method-b---haproxy-setup).

🖥️ **VPS Host**

### 2.1 Configure LXD Proxy Devices

```bash
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

### 2.2 Test External Access

```bash
# From VPS host, test connection
openssl s_client -connect localhost:8089 -showcerts

# Should see certificate info for [YOUR_DOMAIN]
```

### 2.3 Skip to Step 7 (Verification)

If using LXD proxy, skip HAProxy sections and jump to [Step 7: Verify External Access](#step-7-verify-external-access).

---

## Step 3: Method B - HAProxy Setup

### 3.1 Create HAProxy Container

🖥️ **VPS Host**

```bash
# Create HAProxy container on takbr0 network with static IP
lxc launch ubuntu:22.04 haproxy --network takbr0
lxc config device override haproxy eth0 ipv4.address=10.100.100.11

# Wait for start
sleep 10

# Verify running
lxc list

# Verify static IP assignment
lxc list

# Expected:
# | haproxy | RUNNING | 10.100.100.11 (eth0) |
```

### 3.2 Install HAProxy

📦 **Inside HAProxy Container**

```bash
# Access HAProxy container
lxc exec haproxy -- bash

# Update and install HAProxy
apt update && apt install -y haproxy

# Verify installation
haproxy -v

# Expected: HAProxy version 2.4.x or higher
```

### 3.3 Get Container IPs

🖥️ **VPS Host** (open another terminal or exit container)

```bash
# List all container IPs
lxc list -c n4

# Document these IPs:
# tak:     [TAK_CONTAINER_IP]      (e.g., 10.x.x.11)
# haproxy: [HAPROXY_CONTAINER_IP]  (e.g., 10.x.x.12)
```

> ⚠️ **DOCUMENT YOUR IPS**
> You'll need these IPs for the HAProxy configuration. Create a reference file:
> ```bash
> nano ~/container-ips.txt
> ```

---

## Step 4: Configure HAProxy

📦 **Inside HAProxy Container**

### 4.1 Backup Original Config

```bash
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original
```

### 4.2 Understanding Multi-Service Architecture

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
- Services: Web server, NextCloud, file sharing

**TCP with dedicated ports (for MediaMTX/RTSP):**
- Simple TCP forwarding on unique ports
- No SSL complexity
- Port: 8554 (RTSP)

### 4.3 Plan Your Container IPs

Before configuring HAProxy, document your container IPs:

🖥️ **VPS Host** (open another terminal)

```bash
# Create containers for your services (if not already created)
# Uncomment/add containers as needed for your deployment

# Required:
lxc launch ubuntu:22.04 tak        # TAK Server
lxc launch ubuntu:22.04 haproxy    # HAProxy reverse proxy

# Optional - uncomment as needed:
# lxc launch ubuntu:22.04 mediamtx   # Video streaming (RTSP)
# lxc launch ubuntu:22.04 nextcloud  # File sharing
# lxc launch ubuntu:22.04 web        # General web server

# Wait for network assignment
sleep 10

# List all container IPs
lxc list -c n4
```

**Output:**
```
**Container IPs (Pre-configured):**

| Container | IP Address | Purpose |
|-----------|------------|---------|
| tak | 10.100.100.10 | TAK Server |
| haproxy | 10.100.100.11 | Reverse Proxy |
| mediamtx | 10.100.100.12 | Video Streaming (optional) |
| nextcloud | 10.100.100.13 | File Sharing (optional) |

> 💡 These IPs are assigned during container creation using static IP configuration.
> The HAProxy template in `examples/haproxy.cfg` uses these exact addresses.
```

> ⚠️ **DOCUMENT YOUR IPS**
> Create a reference file with your actual container IPs:
> ```bash
> nano ~/container-ips.txt
> ```
> You'll need these for the HAProxy configuration below.

### 4.4 Download HAProxy Configuration Template

📦 **Inside HAProxy Container**
```bash
# Backup original config
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original

# Download pre-configured template
cd /etc/haproxy
sudo wget -O haproxy.cfg https://raw.githubusercontent.com/mighkel/installTAK-LXD/main/examples/haproxy.cfg
```

### 4.5 Customize the Configuration
```bash
sudo nano /etc/haproxy/haproxy.cfg
```

**Replace these placeholders:**

| Find | Replace With | Example |
|------|--------------|---------|
| `[YOUR_DOMAIN]` | Your TAK FQDN | `tak.example.com` |
| `[YOUR_BASE_DOMAIN]` | Your base domain | `example.com` |
| `[STATS_PASSWORD]` | Secure password | `MyS3cur3P@ss!` |

> 💡 **Note:** The container IPs (`10.100.100.10`, `10.100.100.11`) are already
> configured in the template to match the static IPs assigned in earlier steps.

### 4.6 Verify and Start HAProxy
```bash
# Test configuration syntax
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# If valid, restart HAProxy
sudo systemctl restart haproxy
sudo systemctl status haproxy
```

### 4.7 Start HAProxy

```bash
# Start HAProxy
systemctl start haproxy

# Enable auto-start
systemctl enable haproxy

# Check status
systemctl status haproxy
```

---

## Step 5: Configure Port Forwarding to HAProxy

🖥️ **VPS Host** (exit HAProxy container first)

```bash
# Verify you're on VPS host
hostname  # Should NOT be 'haproxy' or 'tak'

# Forward ports to HAProxy container

# Required ports:
lxc config device add haproxy proxy-80 proxy \
    listen=tcp:0.0.0.0:80 \
    connect=tcp:127.0.0.1:80

lxc config device add haproxy proxy-8089 proxy \
    listen=tcp:0.0.0.0:8089 \
    connect=tcp:127.0.0.1:8089

lxc config device add haproxy proxy-8443 proxy \
    listen=tcp:0.0.0.0:8443 \
    connect=tcp:127.0.0.1:8443

lxc config device add haproxy proxy-8446 proxy \
    listen=tcp:0.0.0.0:8446 \
    connect=tcp:127.0.0.1:8446

# Optional: HTTPS for web services (uncomment when needed)
# lxc config device add haproxy proxy-443 proxy \
#     listen=tcp:0.0.0.0:443 \
#     connect=tcp:127.0.0.1:443

# Optional: RTSP for video streaming (uncomment when needed)
# lxc config device add haproxy proxy-8554 proxy \
#     listen=tcp:0.0.0.0:8554 \
#     connect=tcp:127.0.0.1:8554

# Optional: Stats page (consider SSH tunnel instead for security)
lxc config device add haproxy proxy-8404 proxy \
    listen=tcp:0.0.0.0:8404 \
    connect=tcp:127.0.0.1:8404

# Verify all proxy devices
lxc config show haproxy | grep -A 20 devices
```

> ⛔ **WARNING: Don't Add Temporary Port Forwards to TAK Container**
> If you previously added port forwards directly to the TAK container for testing, **remove them now**:
> ```bash
> lxc config device remove tak tak-8089
> lxc config device remove tak tak-8443
> lxc config device remove tak tak-8446
> ```
> All traffic should flow through HAProxy.

---

## Step 6: DNS Configuration

### 6.1 Create DNS Records

Login to your DNS provider (Cloudflare, GoDaddy, Route53, etc.) and create A records:

**Required:**
| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `tak` | `[YOUR_VPS_IP]` | 3600 |

**Optional (for multi-service):**
| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `files` | `[YOUR_VPS_IP]` | 3600 |
| A | `rtsp` | `[YOUR_VPS_IP]` | 3600 |

**Example:** If your domain is `example.com` and VPS IP is `203.0.113.50`:
- `tak.example.com` → `203.0.113.50`
- `files.example.com` → `203.0.113.50` (for NextCloud/file sharing)
- `rtsp.example.com` → `203.0.113.50` (for video streaming)

> 💡 **ALL SUBDOMAINS POINT TO SAME IP**
> HAProxy routes traffic by domain name (SNI), so all services share the same VPS IP address.

### 6.2 Verify DNS Resolution

🖥️ **VPS Host**

```bash
# Check DNS resolution
dig [YOUR_DOMAIN] +short

# Should output: [YOUR_VPS_IP]

# Or use nslookup
nslookup [YOUR_DOMAIN]
```

> ⚠️ **DNS PROPAGATION**
> DNS changes can take 5-60 minutes to propagate. If resolution fails, wait and try again.

---

## Step 7: Verify External Access

### 7.1 Test from VPS Host

🖥️ **VPS Host**

```bash
# Test TAK client port
openssl s_client -connect localhost:8089 -showcerts

# Should see certificate info for [YOUR_DOMAIN]
```

### 7.2 Test from External Machine

💻 **Local Machine** (not the VPS)

```bash
# Test TAK client connection
openssl s_client -connect [YOUR_DOMAIN]:8089 -showcerts

# Should succeed and show certificate
```

### 7.3 Test Web UI

**In a web browser:**

1. Import `webadmin.p12` certificate to browser (if not already done)
2. Navigate to: `https://[YOUR_DOMAIN]:8443`
3. Accept certificate warning (if using self-signed)
4. Should see TAK Server login page ✅

---

## Step 8: Firewall Configuration

Your UFW firewall should already allow TAK ports from Phase 1. Verify:

🖥️ **VPS Host**

### 8.1 Check Current Firewall Rules

```bash
sudo ufw status numbered
```

**Should show (at minimum):**
```
[X]  80/tcp               ALLOW IN    Anywhere    # HTTP
[X]  8089/tcp             ALLOW IN    Anywhere    # TAK Client
[X]  8443/tcp             ALLOW IN    Anywhere    # TAK WebUI
[X]  8446/tcp             ALLOW IN    Anywhere    # TAK Enrollment
```

### 8.2 Add Rules if Missing

```bash
# Required ports
sudo ufw allow 80/tcp comment 'HTTP/ACME'
sudo ufw allow 8089/tcp comment 'TAK Client'
sudo ufw allow 8443/tcp comment 'TAK WebUI'
sudo ufw allow 8446/tcp comment 'TAK Enrollment'

# Optional: HTTPS for web services (uncomment when needed)
# sudo ufw allow 443/tcp comment 'HTTPS'

# Optional: RTSP for video streaming (uncomment when needed)
# sudo ufw allow 8554/tcp comment 'RTSP'

# Reload firewall
sudo ufw reload
```

---

## Step 9: Let's Encrypt SSL Certificates (Recommended)

Let's Encrypt provides free, browser-trusted SSL certificates. This improves the auto-enrollment experience for ATAK clients.

> 💡 **WHAT LET'S ENCRYPT DOES FOR TAK**
> - **Certificate enrollment (8446):** Browser-trusted SSL eliminates warnings
> - **Web UI (8443):** No browser security warnings
> - **ATAK connections (8089):** Still uses TAK's mutual TLS (not affected)

### 9.1 Install Nginx in TAK Container (for ACME challenges)

HAProxy routes ACME challenges to the TAK container on port 80. We need a web server there to respond.

📦 **Inside TAK Container**

```bash
lxc exec tak -- bash

# Install nginx
apt update && apt install -y nginx

# Stop nginx for now (we'll configure it first)
systemctl stop nginx
```

### 9.2 Configure Nginx for ACME Only

```bash
# Create ACME-only configuration
cat > /etc/nginx/sites-available/acme-only << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files $uri =404;
    }

    # Deny everything else
    location / {
        return 404;
    }
}
EOF

# Enable the configuration
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/acme-only /etc/nginx/sites-enabled/

# Create webroot directory
mkdir -p /var/www/html/.well-known/acme-challenge
chown -R www-data:www-data /var/www/html

# Test nginx configuration
nginx -t

# Start nginx
systemctl start nginx
systemctl enable nginx
```

### 9.3 Allow Port 80 in TAK Container Firewall

```bash
# Check if UFW is active in container
ufw status

# If active, allow port 80
ufw allow 80/tcp

# Verify
ufw status | grep 80
```

### 9.4 Test ACME Path

📦 **Inside TAK Container**

```bash
# Create test file
echo "acme-test-working" > /var/www/html/.well-known/acme-challenge/test.txt

# Test locally
curl http://localhost/.well-known/acme-challenge/test.txt
# Should output: acme-test-working
```

💻 **Local Machine** (or any external machine)

```bash
# Test externally
curl http://[YOUR_DOMAIN]/.well-known/acme-challenge/test.txt
# Should output: acme-test-working

# Clean up test file
rm /var/www/html/.well-known/acme-challenge/test.txt
```

> ⛔ **STOP HERE IF EXTERNAL TEST FAILS**
> If the external curl doesn't work, check:
> 1. DNS is resolving correctly
> 2. Port 80 is open in VPS firewall
> 3. HAProxy is routing to TAK container
> 4. Nginx is running in TAK container
> 5. Port 80 is allowed in TAK container firewall

### 9.5 Install Certbot

📦 **Inside TAK Container**

```bash
# Install certbot
apt install -y certbot

# Verify installation
certbot --version
```

### 9.6 Request Let's Encrypt Certificate

```bash
# Request certificate using webroot method
certbot certonly \
    --webroot \
    --webroot-path /var/www/html \
    -d [YOUR_DOMAIN] \
    -m [YOUR_EMAIL] \
    --agree-tos \
    --no-eff-email
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> - Replace `[YOUR_DOMAIN]` with your actual domain
> - Replace `[YOUR_EMAIL]` with your email for renewal notifications

**Expected output:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/[YOUR_DOMAIN]/fullchain.pem
Key is saved at: /etc/letsencrypt/live/[YOUR_DOMAIN]/privkey.pem
```

### 9.7 Verify Certificate Files

```bash
# Check certificates exist
ls -lh /etc/letsencrypt/live/[YOUR_DOMAIN]/

# Should show:
# cert.pem       - Your certificate
# chain.pem      - Intermediate certificates
# fullchain.pem  - cert.pem + chain.pem
# privkey.pem    - Private key
```

---

## Step 10: Convert Let's Encrypt Certificate for TAK Server

TAK Server uses Java KeyStore (JKS) format. We need to convert the PEM certificates.

📦 **Inside TAK Container**

### 10.1 Set Variables

```bash
# Set your domain and certificate password
FQDN="[YOUR_DOMAIN]"
CERT_PASSWORD="[CERT_PASSWORD]"  # Same as your TAK certificate password

# Get hostname (used for keystore filename)
TAK_HOSTNAME=$(hostname)

# Verify
echo "Domain: $FQDN"
echo "Hostname: $TAK_HOSTNAME"
echo "Keystore will be: ${TAK_HOSTNAME}-le.jks"
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[YOUR_DOMAIN]` and `[CERT_PASSWORD]` with your actual values.

### 10.2 Create PKCS12 Keystore

```bash
# Create PKCS12 keystore from Let's Encrypt certificates
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
    -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
    -out /opt/tak/certs/files/${TAK_HOSTNAME}-le.p12 \
    -name $FQDN \
    -passout pass:$CERT_PASSWORD
```

### 10.3 Convert to JKS Format

```bash
# Convert PKCS12 to JKS
keytool -importkeystore \
    -destkeystore /opt/tak/certs/files/${TAK_HOSTNAME}-le.jks \
    -srckeystore /opt/tak/certs/files/${TAK_HOSTNAME}-le.p12 \
    -srcstoretype pkcs12 \
    -deststorepass "$CERT_PASSWORD" \
    -destkeypass "$CERT_PASSWORD" \
    -srcstorepass "$CERT_PASSWORD"

# Fix permissions
chown tak:tak /opt/tak/certs/files/${TAK_HOSTNAME}-le.*

# Verify
ls -lh /opt/tak/certs/files/${TAK_HOSTNAME}-le.*
```

---

## Step 11: Configure TAK Server to Use Let's Encrypt

📦 **Inside TAK Container**

### 11.1 Backup Current Configuration

```bash
cp /opt/tak/CoreConfig.xml /opt/tak/CoreConfig.xml.backup-pre-letsencrypt
```

### 11.2 Update CoreConfig.xml

The certificate enrollment connector (port 8446) needs to use the Let's Encrypt certificate.

**Option A: Command-Line Update (Recommended)**

> 💡 **WORKFLOW**
> 1. Copy the code block below to a text editor (e.g., Notepad on Windows)
> 2. Update the two placeholder values:
>    - `[YOUR_HOSTNAME]` - Your TAK container hostname (run `hostname` to check)
>    - `[CERT_PASSWORD]` - Your certificate password
> 3. Copy the entire updated code block
> 4. Paste into the TAK container command line

```bash
# ============================================================
# UPDATE THESE TWO VALUES BEFORE RUNNING
# ============================================================
TAK_HOSTNAME="[YOUR_HOSTNAME]"      # e.g., "tak" - run 'hostname' to verify
CERT_PASSWORD="[CERT_PASSWORD]"     # Your certificate password

# ============================================================
# DO NOT MODIFY BELOW THIS LINE
# ============================================================

# Backup current config
cp /opt/tak/CoreConfig.xml /opt/tak/CoreConfig.xml.backup-pre-letsencrypt

# Update the 8446 connector to use Let's Encrypt certificate
# This preserves enableAdminUI, enableWebtak, and enableNonAdminUI settings
sed -i "s|<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\"|<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https_LE\" keystore=\"JKS\" keystoreFile=\"certs/files/${TAK_HOSTNAME}-le.jks\" keystorePass=\"${CERT_PASSWORD}\"|g" /opt/tak/CoreConfig.xml

# Verify the change was applied
echo "=== Verifying CoreConfig.xml update ==="
grep -o 'port="8446"[^>]*' /opt/tak/CoreConfig.xml

# Expected output should include:
# keystoreFile="certs/files/[hostname]-le.jks"
# keystorePass="[your password]"
```

> ⚠️ **VERIFY BEFORE PROCEEDING**
> The grep output should show the Let's Encrypt keystore file path. If it still shows the old config, check your hostname and try again.

**Option B: Manual Edit**

If you prefer to edit manually:

```bash
nano /opt/tak/CoreConfig.xml
```

Find the connector for port 8446:
```xml
<connector port="8446" clientAuth="false" _name="cert_https" ...
```

Replace with (all on one line in the actual file):
```xml
<connector port="8446" clientAuth="false" _name="cert_https_LE" keystore="JKS" keystoreFile="certs/files/[YOUR_HOSTNAME]-le.jks" keystorePass="[CERT_PASSWORD]" enableAdminUI="true" enableWebtak="true" enableNonAdminUI="false"/>
```

**Save and exit** (Ctrl+X, Y, Enter)

### 11.3 Restart TAK Server

```bash
# Restart TAK Server
systemctl restart takserver

# Wait for full restart
sleep 30

# Verify it's running
systemctl status takserver

# Check for errors
journalctl -u takserver -n 50 | grep -i error
```

### 11.4 Verify Let's Encrypt Certificate

```bash
# Test SSL on enrollment port
openssl s_client -connect localhost:8446 -showcerts 2>/dev/null | grep -E "subject=|issuer="

# Should show:
# subject=CN=[YOUR_DOMAIN]
# issuer=C=US, O=Let's Encrypt, CN=...
```

---

## Step 12: Set Up Automatic Certificate Renewal

Let's Encrypt certificates expire after 90 days. Set up auto-renewal.

📦 **Inside TAK Container**

### 12.1 Create Renewal Script

```bash
cat > /opt/tak/renew-letsencrypt.sh << 'EOF'
#!/bin/bash
# TAK Server Let's Encrypt Renewal Script

# Configuration - UPDATE THESE
FQDN="[YOUR_DOMAIN]"
CERT_PASSWORD="[CERT_PASSWORD]"
TAK_HOSTNAME="[YOUR_HOSTNAME]"

# Renew certificate
certbot renew --quiet

# Check if renewal happened (cert modified in last hour)
if [ $(find /etc/letsencrypt/live/$FQDN/fullchain.pem -mmin -60 2>/dev/null | wc -l) -gt 0 ]; then
    echo "Certificate renewed, updating TAK Server..."
    
    # Convert to PKCS12
    openssl pkcs12 -export \
        -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
        -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
        -out /opt/tak/certs/files/${TAK_HOSTNAME}-le.p12 \
        -name $FQDN \
        -passout pass:$CERT_PASSWORD

    # Convert to JKS
    keytool -importkeystore \
        -destkeystore /opt/tak/certs/files/${TAK_HOSTNAME}-le.jks \
        -srckeystore /opt/tak/certs/files/${TAK_HOSTNAME}-le.p12 \
        -srcstoretype pkcs12 \
        -deststorepass "$CERT_PASSWORD" \
        -destkeypass "$CERT_PASSWORD" \
        -srcstorepass "$CERT_PASSWORD" \
        -noprompt

    # Fix permissions
    chown tak:tak /opt/tak/certs/files/${TAK_HOSTNAME}-le.*

    # Restart TAK Server
    systemctl restart takserver
    
    echo "TAK Server restarted with new certificate"
else
    echo "No renewal needed"
fi
EOF

# Make executable
chmod +x /opt/tak/renew-letsencrypt.sh
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Edit the script and replace the three placeholder values with your actual values:
> ```bash
> nano /opt/tak/renew-letsencrypt.sh
> ```
> - `[YOUR_DOMAIN]` - Your TAK server FQDN
> - `[CERT_PASSWORD]` - Your certificate password
> - `[YOUR_HOSTNAME]` - Your TAK container hostname (run `hostname` to check)

### 12.2 Set Up Cron Job

```bash
# Create cron job for automatic renewal
cat > /etc/cron.d/certbot-tak << 'EOF'
# Renew Let's Encrypt certificates twice daily
0 */12 * * * root /opt/tak/renew-letsencrypt.sh >> /var/log/tak-cert-renewal.log 2>&1
EOF

# Set permissions
chmod 644 /etc/cron.d/certbot-tak

# Restart cron
systemctl restart cron
```

### 12.3 Test Renewal (Dry Run)

```bash
# Test renewal without actually renewing
certbot renew --dry-run

# Should show: Congratulations, all renewals succeeded
```

---

## Step 13: HAProxy Stats Access (Optional)

The HAProxy stats page provides useful monitoring but shouldn't be exposed to the internet.

### Option A: SSH Tunnel (Recommended)

💻 **Local Machine**

**Windows (PuTTY):**
1. Open saved PuTTY session (don't connect yet)
2. Go to **Connection → SSH → Tunnels**
3. Source port: `8404`
4. Destination: `localhost:8404`
5. Click **Add**
6. Go to **Session** → **Save**
7. Click **Open**
8. Browse to: `http://localhost:8404/haproxy_stats`

**Linux/macOS:**
```bash
ssh -L 8404:localhost:8404 takadmin@[YOUR_VPS_IP]

# Then browse to: http://localhost:8404/haproxy_stats
```

### Option B: Remove Public Access

🖥️ **VPS Host**

```bash
# Remove public stats port forward
lxc config device remove haproxy proxy-8404

# Stats now only accessible via SSH tunnel
```

---

## Step 14: Verification Checklist

Before proceeding to Phase 6:

**Networking:**
- [ ] DNS resolves `[YOUR_DOMAIN]` to `[YOUR_VPS_IP]`
- [ ] Port 8089 accessible from external network
- [ ] Port 8443 accessible from external network
- [ ] Port 8446 accessible from external network
- [ ] HAProxy is running (if using)

**Let's Encrypt (if configured):**
- [ ] Certificate files exist in `/etc/letsencrypt/live/[YOUR_DOMAIN]/`
- [ ] JKS keystore created at `/opt/tak/certs/files/[YOUR_HOSTNAME]-le.jks`
- [ ] TAK Server using Let's Encrypt cert on port 8446
- [ ] Auto-renewal cron job configured
- [ ] `certbot renew --dry-run` succeeds

**TAK Server:**
- [ ] TAK Server is running
- [ ] Can access web UI at `https://[YOUR_DOMAIN]:8443`
- [ ] Certificate enrollment page loads without warnings (with Let's Encrypt)

### Quick Verification Script

🖥️ **VPS Host**

Create the script:
```bash
nano verify-networking.sh
```

Paste the following:
```bash
#!/bin/bash
echo "=== TAK Server Networking Verification ==="

DOMAIN="[YOUR_DOMAIN]"  # UPDATE THIS

echo -n "DNS resolves: "
dig +short $DOMAIN | grep -q "." && echo "✅" || echo "❌"

echo -n "Port 8089 accessible: "
timeout 5 bash -c "</dev/tcp/$DOMAIN/8089" 2>/dev/null && echo "✅" || echo "❌"

echo -n "Port 8443 accessible: "
timeout 5 bash -c "</dev/tcp/$DOMAIN/8443" 2>/dev/null && echo "✅" || echo "❌"

echo -n "Port 8446 accessible: "
timeout 5 bash -c "</dev/tcp/$DOMAIN/8446" 2>/dev/null && echo "✅" || echo "❌"

echo -n "TAK Server running: "
lxc exec tak -- systemctl is-active takserver &>/dev/null && echo "✅" || echo "❌"

if lxc list | grep -q "haproxy.*RUNNING"; then
    echo -n "HAProxy running: "
    lxc exec haproxy -- systemctl is-active haproxy &>/dev/null && echo "✅" || echo "❌"
fi

echo -n "Let's Encrypt cert exists: "
lxc exec tak -- test -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem 2>/dev/null && echo "✅" || echo "⚠️ (optional)"

echo ""
echo "If all required checks show ✅, proceed to Phase 6: Verification & Testing"
```

Save and exit (Ctrl+X, Y, Enter), then run:
```bash
chmod +x verify-networking.sh

# Edit to add your domain
nano verify-networking.sh

# Run
./verify-networking.sh
```

---

## Troubleshooting

### Issue: Can't connect from external network

**Diagnose step-by-step:**

1. **TAK Server running in container?**
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
   lxc config show haproxy | grep proxy
   ```

### Issue: Let's Encrypt certificate request fails

**"Timeout during connect":**
- Port 80 not accessible from internet
- Check HAProxy is forwarding port 80
- Check nginx is running in TAK container

**"Unauthorized":**
- ACME challenge path not working
- Verify: `curl http://[YOUR_DOMAIN]/.well-known/acme-challenge/test.txt`
- Check nginx configuration
- Check TAK container firewall allows port 80

**"Rate limit exceeded":**
- Too many failed attempts
- Wait 1 hour and try again
- Use `--staging` flag for testing

### Issue: HAProxy won't start

```bash
# Check config syntax
lxc exec haproxy -- haproxy -c -f /etc/haproxy/haproxy.cfg

# Check logs
lxc exec haproxy -- journalctl -u haproxy -n 50
```

### Issue: SSL handshake failure after Let's Encrypt

**Check certificate is loaded:**
```bash
lxc exec tak -- openssl s_client -connect localhost:8446 -showcerts 2>/dev/null | grep issuer
# Should show Let's Encrypt as issuer
```

**TAK Server not restarted:**
```bash
lxc exec tak -- systemctl restart takserver
```

---

## Network Configuration Summary

Create a summary file for your records:

🖥️ **VPS Host**

```bash
cat > ~/tak-network-config.txt << EOF
=== TAK Server Network Configuration ===

VPS IP: [YOUR_VPS_IP]
Base Domain: [YOUR_BASE_DOMAIN]
DNS Provider: [your provider]

Container IPs:
- tak:       [TAK_CONTAINER_IP]
- haproxy:   [HAPROXY_CONTAINER_IP]
- mediamtx:  [MEDIAMTX_CONTAINER_IP]  (if configured)
- nextcloud: [NEXTCLOUD_CONTAINER_IP] (if configured)

DNS Records:
- tak.[YOUR_BASE_DOMAIN]   → [YOUR_VPS_IP]
- files.[YOUR_BASE_DOMAIN] → [YOUR_VPS_IP] (if configured)
- rtsp.[YOUR_BASE_DOMAIN]  → [YOUR_VPS_IP] (if configured)

Ports:
- 80:   HTTP/ACME challenges (HAProxy → services)
- 443:  HTTPS web services (HAProxy → services)
- 8089: TAK client connections (mutual TLS)
- 8443: TAK Web UI
- 8446: Certificate enrollment (Let's Encrypt)
- 8554: RTSP video streaming (if configured)
- 8404: HAProxy stats (SSH tunnel only)

Let's Encrypt:
- Certificate: /etc/letsencrypt/live/[YOUR_DOMAIN]/
- TAK Keystore: /opt/tak/certs/files/[YOUR_HOSTNAME]-le.jks
- Renewal: Automatic via cron (twice daily)

Last Updated: $(date)
EOF

cat ~/tak-network-config.txt
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
- **Let's Encrypt Documentation:** https://letsencrypt.org/docs/
- **Certbot Documentation:** https://eff-certbot.readthedocs.io/
- **LXD Proxy Devices:** https://documentation.ubuntu.com/lxd/en/latest/howto/instances_configure/
- **TAK Syndicate:** https://www.thetaksyndicate.org/

---

*Last Updated: November 2025*  
*Tested on: Ubuntu 22.04 LTS, HAProxy 2.4+*
