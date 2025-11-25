# Phase 5B: Let's Encrypt SSL Configuration for TAK Server (LXD)

**Supplemental Guide for TAK Server 5.5 in LXD Container**

This guide assumes you've completed:
- [Phase 1: LXD Setup](01-LXD-SETUP.md) ✅
- [Phase 2: Container Setup](02-CONTAINER-SETUP.md) ✅
- [Phase 3: TAK Installation](03-TAK-INSTALLATION.md) ✅
- [Phase 4: Certificate Management](04-CERTIFICATE-MANAGEMENT.md) ✅
- [Phase 5: Networking](05-NETWORKING.md) ✅

---

## Prerequisites

Before configuring Let's Encrypt, verify:

- [ ] TAK Server is installed and running
- [ ] Port forwarding is configured (80, 443, 8089, 8443, 8446)
- [ ] HAProxy or nginx reverse proxy is configured
- [ ] DNS A record points to your public IP
- [ ] FQDN resolves correctly: `nslookup tak.pinenut.tech`
- [ ] Port 80 is accessible from internet: `curl -I http://tak.pinenut.tech`

**Critical:** Do NOT proceed if port 80 is not accessible from the internet!

---

## Step 1: Verify Saved FQDN

During Phase 3 installation, your FQDN was saved for this step.

### 1.1 Check Saved FQDN
```bash
# Get shell in container as root
lxc exec tak -- bash

# Check saved FQDN
cat /opt/tak/fqdn-for-letsencrypt.txt

# Should output something like: tak.pinenut.tech
```

### 1.2 Update FQDN (If Needed)
```bash
# If FQDN is wrong or missing:
echo "tak.pinenut.tech" | tee /opt/tak/fqdn-for-letsencrypt.txt

# Verify
cat /opt/tak/fqdn-for-letsencrypt.txt
```

**Note:** All commands in this guide assume you're running as **root** in the TAK container. Use `lxc exec tak -- bash` from the VPS host to get a root shell.

---

## Step 2: Verify Port 80 Accessibility

**This is the most common failure point!**

### 2.1 Test from Outside Your Network
```bash
# From your LOCAL machine (not VPS), test:
curl -I http://tak.pinenut.tech

# Expected output:
HTTP/1.1 301 Moved Permanently  (redirect to HTTPS)
# or
HTTP/1.1 200 OK
# or
HTTP/1.1 404 Not Found
# (Any of these is fine - we just need a response)

# If you get "Connection refused" or timeout, port 80 is NOT accessible!
```

### 2.2 Common Port 80 Issues

**Issue:** Port 80 blocked by VPS firewall
```bash
# On VPS host (exit container first)
exit

# Allow port 80
sudo ufw allow 80/tcp
sudo ufw status | grep 80

# Should show: 80/tcp ALLOW Anywhere
```

**Issue:** HAProxy not forwarding port 80
```bash
# Check HAProxy configuration
lxc exec haproxy -- grep -A 5 "frontend http-in" /etc/haproxy/haproxy.cfg

# Should have:
# frontend http-in
#     bind *:80
```

**Issue:** LXD proxy device missing for port 80
```bash
# From VPS host, check proxy devices
lxc config device list haproxy | grep -i proxy

# Should show proxy-80 or similar
# If missing, HAProxy can't receive traffic on port 80
```

---

## Step 3: Install and Configure Nginx for ACME Challenges

Let's Encrypt needs to verify domain ownership via HTTP. HAProxy is configured to forward ACME challenges (from `/.well-known/acme-challenge/`) to the TAK container on port 80, so we need a web server there to handle them.

### 3.1 Why Nginx?

**The Architecture:**
```
Internet 
    ↓
VPS Host (port 80)
    ↓
HAProxy Container (routes ACME challenges)
    ↓
TAK Container Port 80
    ↓
Nginx (serves challenge files)
```

HAProxy routes requests matching `/.well-known/acme-challenge/*` to the TAK container, but we need nginx there to serve the challenge files that Let's Encrypt will request.

### 3.2 Install Nginx

**Get root shell in TAK container (if not already):**
```bash
# From VPS host
lxc exec tak -- bash

# You're now root in TAK container
```

**Install nginx:**
```bash
# Update package lists
apt update

# Install nginx
apt install -y nginx

# Verify installation
nginx -v
```

### 3.3 Configure Nginx for ACME Only

We'll configure nginx to ONLY serve ACME challenges and reject everything else:

```bash
# Create ACME-only configuration
cat > /etc/nginx/sites-available/acme << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # Serve ACME challenges only
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files $uri =404;
    }
    
    # Reject everything else (nginx returns no response)
    location / {
        return 444;
    }
}
EOF

# Remove default nginx site
rm /etc/nginx/sites-enabled/default

# Enable ACME configuration
ln -s /etc/nginx/sites-available/acme /etc/nginx/sites-enabled/acme

# Test nginx configuration
nginx -t
# Should show: configuration file is valid

# Start and enable nginx
systemctl enable nginx
systemctl start nginx

# Verify nginx is running
systemctl status nginx
```

### 3.4 Set Up Web Root Permissions

```bash
# Create ACME challenge directory
mkdir -p /var/www/html/.well-known/acme-challenge

# Set correct ownership (www-data is nginx user)
chown -R www-data:www-data /var/www/html

# Set correct permissions
chmod -R 755 /var/www/html

# Verify permissions
ls -la /var/www/html/.well-known/
```

### 3.5 CRITICAL: Allow Port 80 in TAK Container Firewall

**This step is ESSENTIAL!** Without it, HAProxy gets 503 errors when trying to reach nginx.

```bash
# Allow HTTP (port 80) for ACME challenges
ufw allow 80/tcp

# Verify rule was added
ufw status | grep 80

# Should show:
# 80/tcp    ALLOW    Anywhere
```

**Why this is critical:**
- HAProxy forwards ACME challenges to TAK container port 80
- TAK container firewall blocks incoming port 80 by default
- Without this rule, Let's Encrypt verification fails with 503 errors

### 3.6 Test Nginx Configuration

**Create test file:**
```bash
# Create test file
echo "nginx acme test success" > /var/www/html/.well-known/acme-challenge/test

# Make it readable
chmod 644 /var/www/html/.well-known/acme-challenge/test

# Test locally in TAK container
curl http://localhost/.well-known/acme-challenge/test
# Should return: nginx acme test success
```

**Test from VPS host:**
```bash
# Exit TAK container
exit

# Test through HAProxy from VPS host
curl http://tak.pinenut.tech/.well-known/acme-challenge/test
# Should return: nginx acme test success
```

**Test from your local machine:**
```bash
# From your local computer
curl http://tak.pinenut.tech/.well-known/acme-challenge/test
# Should return: nginx acme test success
```

**If all three tests return "nginx acme test success", you're ready for certbot!**

**Common Issues:**

**Issue: 403 Forbidden**
```bash
# Fix permissions
chmod -R 755 /var/www/html
chown -R www-data:www-data /var/www/html
```

**Issue: 503 Service Unavailable**
```bash
# Port 80 blocked in firewall
ufw allow 80/tcp
ufw status | grep 80
```

**Issue: Connection refused from local machine**
```bash
# Check nginx is running
systemctl status nginx

# If not running:
systemctl start nginx
```

**Issue: Empty directory returns 403**
```bash
# This is normal - nginx returns 403 for empty directories
# Create a test file as shown above
# certbot will create its own files during verification
```

---

## Step 4: Install Certbot

### 4.1 Install Certbot in Container
```bash
# Get root shell in TAK container
lxc exec tak -- bash

# Install certbot
apt update
apt install certbot -y

# Verify installation
certbot --version
```

---

## Step 5: Request Let's Encrypt Certificate

### 5.1 Run Certbot in Webroot Mode

**Important:** We use **webroot mode**, not standalone mode. This allows nginx to keep running while certbot verifies domain ownership.

```bash
# Load saved FQDN
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)

# Verify it's correct
echo "Requesting certificate for: $FQDN"

# Request certificate using webroot mode
certbot certonly \
    --webroot \
    -w /var/www/html \
    -d $FQDN \
    -m your-email@example.com \
    --agree-tos \
    --no-eff-email
```

**Replace `your-email@example.com` with your actual email for renewal notices.**

**Important flags explained:**
- `--webroot`: Use existing nginx (don't start own web server)
- `-w /var/www/html`: Web root where nginx serves files
- `-d $FQDN`: Domain to get certificate for
- `-m your-email@example.com`: Your email (for renewal notices)
- `--agree-tos`: Accept Let's Encrypt Terms of Service
- `--no-eff-email`: Don't share email with EFF

**Expected output:**
```
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Requesting a certificate for tak.pinenut.tech

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/tak.pinenut.tech/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/tak.pinenut.tech/privkey.pem
This certificate expires on 2026-02-22.
```

### 5.2 Why Webroot Mode?

**Webroot Mode (What We Use):**
- Uses existing web server (nginx)
- Web server keeps running
- Certbot writes challenge files to web root
- TAK Server stays running
- Best for production (no downtime)

**Standalone Mode (Don't Use):**
```bash
# This WILL NOT WORK in our setup
certbot certonly --standalone -d $FQDN  # ❌ Don't do this
```
- Tries to start its own web server on port 80
- Fails because nginx is already using port 80
- Causes error: "Could not bind TCP port 80"
- Requires stopping nginx and TAK Server
- Causes service interruption

### 5.3 Troubleshooting Certbot Failures

**Error: "Failed to authenticate" / "unauthorized" / "Invalid response"**

Let's Encrypt couldn't access the challenge file. Check each layer:

**Layer 1: DNS Resolution**
```bash
nslookup $FQDN
# Should return your VPS public IP
```

**Layer 2: Port 80 Accessible from Internet**
```bash
# From your local machine
curl -I http://tak.pinenut.tech
# Should get HTTP response (not timeout/refused)
```

**Layer 3: HAProxy Routing**
```bash
# Check HAProxy backend config
lxc exec haproxy -- grep -A 5 "tak-acme-backend" /etc/haproxy/haproxy.cfg
# Should show TAK container IP
```

**Layer 4: Nginx Running in TAK Container**
```bash
systemctl status nginx
# Should show: active (running)
```

**Layer 5: Firewall Allows Port 80**
```bash
ufw status | grep 80
# Must show: 80/tcp ALLOW
```

**Layer 6: Test File Accessible**
```bash
curl http://tak.pinenut.tech/.well-known/acme-challenge/test
# Should return test file content
```

**Error: "503 Service Unavailable"**

HAProxy can't reach TAK container nginx.

**Fix:**
```bash
# Allow port 80 in TAK container firewall
ufw allow 80/tcp

# Verify
ufw status | grep 80
```

**Error: "Connection refused"**

Nginx not running in TAK container.

**Fix:**
```bash
systemctl start nginx
systemctl enable nginx
systemctl status nginx
```

**Error: "Timeout during connect"**

Port 80 not accessible from internet.

**Fix:**
```bash
# Check VPS host firewall
exit  # Exit to VPS host
sudo ufw allow 80/tcp
sudo ufw status | grep 80

# Check LXD proxy device
lxc config device list haproxy | grep proxy-80
```

**Error: "Rate limit exceeded"**

Too many failed attempts.

**Fix:**
```bash
# Let's Encrypt limits: 5 failures per account per hour
# Wait 1 hour and try again
# Or use staging server for testing:
certbot certonly --webroot -w /var/www/html -d $FQDN \
    --staging \
    -m your-email@example.com \
    --agree-tos
```

### 5.4 Verify Certificate Files

```bash
# Check certificate files exist
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
ls -lh /etc/letsencrypt/live/$FQDN/

# Should show:
# cert.pem       - Your certificate only
# chain.pem      - Intermediate certificates
# fullchain.pem  - cert.pem + chain.pem (use this for TAK)
# privkey.pem    - Private key
```

---

## Step 6: Convert Certificate for TAK Server

TAK Server uses Java KeyStore (JKS) format, so we need to convert the PEM certificates.

### 6.1 Create PKCS12 Keystore
```bash
# Read FQDN
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)

# Read certificate password (default: atakatak, or your custom password)
CAPASSWD="atakatak"

# Get hostname for file naming
HOSTNAME=$(hostname)

# Create PKCS12 keystore
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
    -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
    -out /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -name $FQDN \
    -passin pass:$CAPASSWD \
    -passout pass:$CAPASSWD
```

### 6.2 Convert to JKS Format
```bash
# Convert PKCS12 to JKS
keytool -importkeystore \
    -destkeystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -srckeystore /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -srcstoretype pkcs12 \
    -deststorepass "$CAPASSWD" \
    -destkeypass "$CAPASSWD" \
    -srcstorepass "$CAPASSWD"

# Verify keystore was created
ls -lh /opt/tak/certs/files/$HOSTNAME-le.*

# View keystore contents
keytool -list -v -keystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -storepass "$CAPASSWD" | head -20
```

### 6.3 Fix Permissions
```bash
# Set proper ownership
chown tak:tak /opt/tak/certs/files/$HOSTNAME-le.*

# Verify
ls -lh /opt/tak/certs/files/$HOSTNAME-le.*
# Should show: tak tak
```

---

## Step 7: Update TAK Server Configuration

### 7.1 Backup Current Configuration
```bash
# Create backup with timestamp
cp /opt/tak/CoreConfig.xml /opt/tak/CoreConfig.xml.backup-$(date +%Y%m%d)

# Verify backup
ls -lh /opt/tak/CoreConfig.xml.backup-*
```

### 7.2 Update CoreConfig.xml

**Method A: Manual Edit (Recommended for understanding)**

```bash
# Edit CoreConfig.xml
nano /opt/tak/CoreConfig.xml

# Find the line with: connector port="8446"
# It looks like:
#   <connector port="8446" clientAuth="false" _name="cert_https"/>

# Change it to:
#   <connector port="8446" clientAuth="false" _name="cert_https_LE" 
#       keystore="JKS" 
#       keystoreFile="certs/files/[hostname]-le.jks" 
#       keystorePass="atakatak"/>

# Replace [hostname] with actual hostname
# Save and exit (Ctrl+X, Y, Enter)
```

**Method B: Automated Update**

```bash
# Get hostname and password
HOSTNAME=$(hostname)
CAPASSWD="atakatak"

# Update connector to use Let's Encrypt certificate
sed -i "s#connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\"#connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https_LE\" keystore=\"JKS\" keystoreFile=\"certs/files/$HOSTNAME-le.jks\" keystorePass=\"$CAPASSWD\"#g" /opt/tak/CoreConfig.xml
```

### 7.3 Verify Configuration
```bash
# Check if update was applied
grep "cert_https_LE" /opt/tak/CoreConfig.xml

# Should show line with your Let's Encrypt JKS file

# Full context check
grep -A 2 "port=\"8446\"" /opt/tak/CoreConfig.xml
```

---

## Step 8: Restart TAK Server

### 8.1 Restart TAK Server
```bash
# Restart TAK Server with new configuration
systemctl restart takserver

# Wait for startup (TAK Server takes 1-2 minutes to fully start)
echo "Waiting for TAK Server to start..."
sleep 60

# Check status
systemctl status takserver
```

### 8.2 Verify Ports Are Listening
```bash
# Check all TAK ports
ss -tulpn | grep -E "8089|8443|8446"

# Should show all three ports with Java processes
```

### 8.3 Verify SSL Certificate
```bash
# Test SSL connection with Let's Encrypt cert
echo | openssl s_client -connect localhost:8446 -showcerts 2>/dev/null | head -30

# Look for:
# subject=CN=tak.pinenut.tech
# issuer=C=US, O=Let's Encrypt, CN=R11 (or similar)

# The issuer should show "Let's Encrypt"
```

### 8.4 Check TAK Server Logs
```bash
# Watch logs for successful startup
tail -50 /opt/tak/logs/takserver-messaging.log

# Look for:
# "Started TAK Server messaging Microservice"
# No SSL/certificate errors
```

### 8.5 Test from Browser

From your local machine, access:
```
https://tak.pinenut.tech:8443
```

**You should see:**
1. No browser security warning about self-signed certificate
2. Valid SSL certificate from Let's Encrypt
3. Browser may prompt for client certificate (webadmin.p12)
4. TAK Server web UI loads

**If you still see security warnings about self-signed certificates:**
- Check that CoreConfig.xml was updated correctly
- Verify TAK Server restarted successfully
- Check logs for certificate loading errors

---

## Step 9: Set Up Automatic Renewal

Let's Encrypt certificates expire after 90 days. Set up auto-renewal.

### 9.1 Create Renewal Script
```bash
# Create renewal script
cat > /opt/tak/renew-tak-le << 'EOF'
#!/bin/bash

# TAK Server Let's Encrypt Certificate Renewal Script

# Read FQDN and password
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
CAPASSWD="atakatak"  # Change if you used different password
HOSTNAME=$(hostname)

echo "=== TAK Server Let's Encrypt Renewal ==="
echo "Domain: $FQDN"
echo "Date: $(date)"

# Renew certificate (only if expiring within 30 days)
echo "Attempting certificate renewal..."
certbot renew --quiet --webroot -w /var/www/html

# Check if renewal occurred
if [ $? -eq 0 ]; then
    echo "Certificate renewal check complete"
    
    # Convert to PKCS12
    echo "Converting to PKCS12..."
    openssl pkcs12 -export \
        -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
        -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
        -out /opt/tak/certs/files/$HOSTNAME-le.p12 \
        -name $FQDN \
        -passin pass:$CAPASSWD \
        -passout pass:$CAPASSWD

    # Convert to JKS
    echo "Converting to JKS..."
    keytool -importkeystore \
        -destkeystore /opt/tak/certs/files/$HOSTNAME-le.jks \
        -srckeystore /opt/tak/certs/files/$HOSTNAME-le.p12 \
        -srcstoretype pkcs12 \
        -deststorepass "$CAPASSWD" \
        -destkeypass "$CAPASSWD" \
        -srcstorepass "$CAPASSWD" \
        -noprompt

    # Fix permissions
    echo "Setting permissions..."
    chown tak:tak /opt/tak/certs/files/$HOSTNAME-le.*

    # Restart TAK Server
    echo "Restarting TAK Server..."
    systemctl restart takserver
    
    echo "Renewal complete!"
else
    echo "Certificate not yet due for renewal"
fi

echo "=== Renewal Process Complete ==="
EOF

# Make executable
chmod +x /opt/tak/renew-tak-le

# Test the script
echo "Testing renewal script..."
/opt/tak/renew-tak-le
```

### 9.2 Set Up Cron Job
```bash
# Create cron job to run renewal twice daily
cat > /etc/cron.d/certbot-tak-le << 'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Run TAK Server Let's Encrypt renewal twice daily
# Runs at 3:47 AM and 3:47 PM (random minutes to spread load)
47 3,15 * * * root /opt/tak/renew-tak-le >> /var/log/tak-le-renewal.log 2>&1
EOF

# Set proper permissions
chmod 644 /etc/cron.d/certbot-tak-le

# Reload cron
systemctl restart cron

# Verify cron job
cat /etc/cron.d/certbot-tak-le
```

### 9.3 Test Renewal (Dry Run)
```bash
# Test renewal without actually renewing
certbot renew --dry-run --webroot -w /var/www/html

# Should show:
# "Congratulations, all simulated renewals succeeded"
```

### 9.4 Check Renewal Log
```bash
# View renewal log (will be empty until first automatic run)
tail -f /var/log/tak-le-renewal.log

# Or check certbot's log
tail -f /var/log/letsencrypt/letsencrypt.log
```

---

## Step 10: Verification Checklist

Before considering Let's Encrypt setup complete:

### Certificate Files:
- [ ] `/etc/letsencrypt/live/[domain]/fullchain.pem` exists
- [ ] `/etc/letsencrypt/live/[domain]/privkey.pem` exists
- [ ] `/opt/tak/certs/files/[hostname]-le.p12` created
- [ ] `/opt/tak/certs/files/[hostname]-le.jks` created
- [ ] JKS files owned by `tak:tak`

### Nginx (ACME Handler):
- [ ] Nginx installed and running
- [ ] Port 80 allowed in TAK container firewall
- [ ] Test file accessible: `curl http://tak.pinenut.tech/.well-known/acme-challenge/test`

### TAK Server:
- [ ] `systemctl status takserver` shows "active (running)"
- [ ] All ports listening: 8089, 8443, 8446
- [ ] No SSL errors in `/opt/tak/logs/takserver-messaging.log`
- [ ] `openssl s_client -connect localhost:8446` shows Let's Encrypt issuer
- [ ] CoreConfig.xml updated with LE keystore

### Renewal:
- [ ] `/opt/tak/renew-tak-le` script exists and is executable
- [ ] Cron job created in `/etc/cron.d/certbot-tak-le`
- [ ] `certbot renew --dry-run` succeeds

### External Access:
- [ ] https://tak.pinenut.tech:8443 accessible (web UI)
- [ ] Browser shows valid SSL certificate (green lock icon)
- [ ] Certificate issuer is "Let's Encrypt"
- [ ] No browser security warnings about self-signed certs

### Quick Verification Script

```bash
#!/bin/bash
echo "=== Let's Encrypt Verification ==="

FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
HOSTNAME=$(hostname)

echo -n "Let's Encrypt cert exists: "
test -f /etc/letsencrypt/live/$FQDN/fullchain.pem && echo "✅" || echo "❌"

echo -n "TAK Server LE keystore exists: "
test -f /opt/tak/certs/files/$HOSTNAME-le.jks && echo "✅" || echo "❌"

echo -n "Nginx running: "
systemctl is-active --quiet nginx && echo "✅" || echo "❌"

echo -n "Port 80 allowed in firewall: "
ufw status | grep -q "80/tcp.*ALLOW" && echo "✅" || echo "❌"

echo -n "TAK Server running: "
systemctl is-active --quiet takserver && echo "✅" || echo "❌"

echo -n "Renewal script exists: "
test -f /opt/tak/renew-tak-le && test -x /opt/tak/renew-tak-le && echo "✅" || echo "❌"

echo -n "Cron job configured: "
test -f /etc/cron.d/certbot-tak-le && echo "✅" || echo "❌"

echo -n "Port 8443 listening: "
ss -tulpn | grep -q ":8443" && echo "✅" || echo "❌"

echo ""
echo "Testing SSL certificate from localhost:8446..."
echo | openssl s_client -connect localhost:8446 2>/dev/null | grep -E "subject=|issuer="

echo ""
echo "Testing ACME challenge accessibility..."
curl -I http://tak.pinenut.tech/.well-known/acme-challenge/test 2>/dev/null | head -1

echo ""
echo "If all checks show ✅ and issuer shows Let's Encrypt, you're good!"
```

---

## Troubleshooting

### Issue: Certbot fails with "unauthorized" or "403"

**Cause:** ACME challenge files not accessible

**Diagnosis:**
```bash
# Test each layer
curl http://localhost/.well-known/acme-challenge/test
curl http://tak.pinenut.tech/.well-known/acme-challenge/test

# Check nginx logs
tail -50 /var/log/nginx/error.log
tail -50 /var/log/nginx/access.log
```

**Fix:**
```bash
# Fix permissions
chmod -R 755 /var/www/html
chown -R www-data:www-data /var/www/html

# Recreate test file
echo "test" > /var/www/html/.well-known/acme-challenge/test
chmod 644 /var/www/html/.well-known/acme-challenge/test
```

### Issue: Certbot fails with "503 Service Unavailable"

**Cause:** HAProxy can't reach TAK container nginx

**Fix:**
```bash
# Allow port 80 in TAK container firewall
ufw allow 80/tcp
ufw status | grep 80

# Restart nginx
systemctl restart nginx

# Test from HAProxy container
lxc exec haproxy -- curl -I http://10.203.133.157/.well-known/acme-challenge/test
```

### Issue: TAK Server won't start after cert update

**Cause:** Incorrect keystore password or path

**Fix:**
```bash
# Check CoreConfig.xml
grep "keystoreFile" /opt/tak/CoreConfig.xml

# Verify keystore exists
ls -lh /opt/tak/certs/files/*-le.jks

# Test keystore password
keytool -list -keystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -storepass atakatak

# If password wrong, recreate keystore with correct password
# Check TAK Server logs for specific error
tail -100 /opt/tak/logs/takserver-messaging.log | grep -i error
```

### Issue: Browser still shows self-signed certificate

**Cause:** TAK Server still using old certificates

**Fix:**
```bash
# Verify CoreConfig.xml has LE keystore
grep -A 3 "port=\"8446\"" /opt/tak/CoreConfig.xml

# Should show keystoreFile with -le.jks

# Restart TAK Server
systemctl restart takserver
sleep 60

# Check which cert is loaded
echo | openssl s_client -connect localhost:8446 2>/dev/null | grep issuer
```

### Issue: Renewal fails silently

**Cause:** Renewal script errors

**Fix:**
```bash
# Test renewal script manually with verbose output
bash -x /opt/tak/renew-tak-le

# Check for errors in output

# Check certbot logs
tail -100 /var/log/letsencrypt/letsencrypt.log

# Check renewal log
tail -100 /var/log/tak-le-renewal.log
```

### Issue: Clients can't connect after Let's Encrypt

**Cause:** Client CA trust not updated (but this shouldn't matter!)

**Important:** Let's Encrypt only affects the **server's SSL certificate** (port 8446 enrollment).

**Client certificates remain the same!**
- ATAK clients still use their same .p12 certificates
- Internal CA trust (truststore) doesn't change
- Only the server's public-facing SSL certificate changed

**If clients can't connect:**
```bash
# Check TAK Server logs
tail -100 /opt/tak/logs/takserver-messaging.log

# Look for SSL handshake errors
# Client mutual TLS is separate from server SSL certificate
```

---

## Certificate Expiration Timeline

**Let's Encrypt Certificates:**
- Valid for 90 days
- Renewal recommended at 60 days
- Certbot automatically renews when <30 days remain
- Automatic renewal runs twice daily (3:47 AM and 3:47 PM)
- Failed renewals logged to `/var/log/tak-le-renewal.log`

**Monitor Certificate Expiration:**
```bash
# Check expiration date
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
openssl x509 -in /etc/letsencrypt/live/$FQDN/cert.pem \
    -noout -dates

# Should show:
# notBefore: [issue date]
# notAfter: [90 days from issue]
```

**Check Renewal Status:**
```bash
# See when certificates will be renewed
certbot certificates

# Shows:
# Certificate Name, Domains, Expiry Date, etc.
```

---

## Backup Important Files

After successful Let's Encrypt setup:

```bash
# Exit TAK container to VPS host
exit

# Create backup directory on host
mkdir -p ~/tak-letsencrypt-backup

# Backup Let's Encrypt files
lxc file pull -r tak/etc/letsencrypt/ ~/tak-letsencrypt-backup/

# Backup TAK Server keystores
lxc file pull tak/opt/tak/certs/files/tak-le.jks ~/tak-letsencrypt-backup/
lxc file pull tak/opt/tak/certs/files/tak-le.p12 ~/tak-letsencrypt-backup/

# Backup CoreConfig
lxc file pull tak/opt/tak/CoreConfig.xml ~/tak-letsencrypt-backup/

# Backup renewal script
lxc file pull tak/opt/tak/renew-tak-le ~/tak-letsencrypt-backup/

# Create tarball
cd ~
tar -czf tak-letsencrypt-backup-$(date +%Y%m%d).tar.gz tak-letsencrypt-backup/

# Verify backup
ls -lh ~/tak-letsencrypt-backup-*.tar.gz
```

---

## Reverting to Self-Signed Certificates

If you need to revert to self-signed certificates:

```bash
# Get shell in TAK container
lxc exec tak -- bash

# Stop TAK Server
systemctl stop takserver

# Restore backup configuration
cp /opt/tak/CoreConfig.xml.backup-[date] /opt/tak/CoreConfig.xml

# Or manually edit to remove Let's Encrypt reference
nano /opt/tak/CoreConfig.xml

# Find the connector line and change:
# FROM: _name="cert_https_LE" keystore="JKS" keystoreFile="certs/files/tak-le.jks"
# TO:   _name="cert_https"

# Start TAK Server
systemctl start takserver

# Wait for startup
sleep 60

# Verify
systemctl status takserver
```

---

## Next Steps

With Let's Encrypt configured:

**✅ Completed:**
- Phase 1: LXD Setup
- Phase 2: Container Setup  
- Phase 3: TAK Installation
- Phase 4: Certificate Management
- Phase 5: Networking
- **Phase 5B: Let's Encrypt SSL** ← You are here

**➡️ Proceed to:** [Phase 6: Final Verification](06-FINAL-VERIFICATION.md)

Final steps to verify your complete TAK Server deployment.

---

## Additional Resources

- **Let's Encrypt Documentation:** https://letsencrypt.org/docs/
- **Certbot Documentation:** https://eff-certbot.readthedocs.io/
- **Certbot Webroot Plugin:** https://eff-certbot.readthedocs.io/en/stable/using.html#webroot
- **TAK Server Documentation:** https://tak.gov/docs
- **myTeckNet TAK Guides:** https://mytecknet.com/tag/tak/

---

*Last Updated: November 24, 2025*  
*Tested on: TAK Server 5.5, Ubuntu 22.04/24.04 LTS*  
*Deployment: Clear Creek VFD / Boise County SO*
