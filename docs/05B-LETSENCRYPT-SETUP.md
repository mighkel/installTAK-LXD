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
# Get shell in container
lxc exec tak -- bash

# Check saved FQDN
cat /opt/tak/fqdn-for-letsencrypt.txt

# Should output something like: tak.pinenut.tech
```

### 1.2 Update FQDN (If Needed)
```bash
# If FQDN is wrong or missing:
echo "tak.pinenut.tech" | sudo tee /opt/tak/fqdn-for-letsencrypt.txt

# Verify
cat /opt/tak/fqdn-for-letsencrypt.txt
```

---

## Step 2: Verify Port 80 Accessibility

**This is the most common failure point!**

### 2.1 Test from Outside Your Network
```bash
# From your LOCAL machine (not VPS), test:
curl -I http://tak.pinenut.tech

# Expected output:
HTTP/1.1 200 OK
# or
HTTP/1.1 404 Not Found
# (Either is fine - we just need a response)

# If you get "Connection refused" or timeout, port 80 is NOT accessible!
```

### 2.2 Test from Inside Container
```bash
# Inside container
curl -I http://localhost

# Should get a response (proves local web server works)
```

### 2.3 Common Port 80 Issues

**Issue:** Port 80 blocked by VPS firewall
```bash
# On VPS host (outside container)
sudo ufw allow 80/tcp
sudo ufw status

# Verify 80 is in the list
```

**Issue:** HAProxy not forwarding port 80
```bash
# Check HAProxy configuration
cat /etc/haproxy/haproxy.cfg

# Should have a frontend for port 80:
frontend http-in
    bind *:80
    default_backend tak-http
```

**Issue:** LXD proxy device missing for port 80
```bash
# Check LXD proxy devices
lxc config device list tak

# Should show proxy for 80
# If missing, add it:
lxc config device add tak http-proxy proxy \
    listen=tcp:0.0.0.0:80 \
    connect=tcp:127.0.0.1:80
```

---

## Step 3: Install Certbot

### 3.1 Install Certbot in Container
```bash
# Inside container as root
apt update
apt install certbot -y

# Verify installation
certbot --version
```

### 3.2 Stop TAK Server (Temporary)
```bash
# Stop TAK Server to free port 80
systemctl stop takserver

# Verify it's stopped
systemctl status takserver
```

---

## Step 4: Request Let's Encrypt Certificate

### 4.1 Run Certbot in Standalone Mode
```bash
# Replace tak.pinenut.tech with your FQDN
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)

certbot certonly \
    --standalone \
    --preferred-challenges http \
    -d $FQDN \
    -m your-email@example.com \
    --agree-tos \
    --no-eff-email
```

**During the process:**
- Enter your email when prompted (for renewal notices)
- Agree to Terms of Service
- Optionally share email with EFF (not required)

### 4.2 Troubleshooting Certbot Failures

**Error:** "Timeout during connect"
```bash
# Port 80 is not accessible from internet
# Go back to Step 2 and fix port forwarding
```

**Error:** "Connection refused"
```bash
# Port 80 is blocked locally
# Check firewall: sudo ufw status
# Check if something else is using port 80: ss -tulpn | grep :80
```

**Error:** "Invalid response"
```bash
# DNS not resolving correctly
# Check DNS: nslookup $FQDN
# Wait for DNS propagation (can take up to 24 hours)
```

**Error:** "Rate limit exceeded"
```bash
# Too many failed attempts
# Let's Encrypt limits: 5 failures per account per hour
# Wait 1 hour and try again
# Or use staging server for testing:
certbot certonly --standalone --staging -d $FQDN
```

### 4.3 Verify Certificate
```bash
# Check if certificate was created
ls -lh /etc/letsencrypt/live/$FQDN/

# Should show:
# cert.pem       - Your certificate
# chain.pem      - Intermediate certificates
# fullchain.pem  - cert.pem + chain.pem
# privkey.pem    - Private key
```

---

## Step 5: Convert Certificate for TAK Server

TAK Server uses Java KeyStore (JKS) format, so we need to convert the PEM certificates.

### 5.1 Create PKCS12 Keystore
```bash
# Read FQDN
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)

# Read certificate password (default: atakatak)
CAPASSWD="atakatak"  # Or your custom password

# Create PKCS12 keystore
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
    -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
    -out /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -name $FQDN \
    -passin pass:$CAPASSWD \
    -passout pass:$CAPASSWD
```

### 5.2 Convert to JKS Format
```bash
# Convert PKCS12 to JKS
keytool -importkeystore \
    -destkeystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -srckeystore /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -srcstoretype pkcs12 \
    -deststorepass "$CAPASSWD" \
    -destkeypass "$CAPASSWD" \
    -srcstorepass "$CAPASSWD"

# Verify keystore
keytool -list -v -keystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -storepass "$CAPASSWD"
```

### 5.3 Fix Permissions
```bash
# Set proper ownership
chown tak:tak /opt/tak/certs/files/$HOSTNAME-le.*

# Verify
ls -lh /opt/tak/certs/files/$HOSTNAME-le.*
```

---

## Step 6: Update TAK Server Configuration

### 6.1 Backup Current Configuration
```bash
# Create backup
cp /opt/tak/CoreConfig.xml /opt/tak/CoreConfig.xml.backup-pre-letsencrypt
```

### 6.2 Update CoreConfig.xml
```bash
# Update connector to use Let's Encrypt certificate
sed -i "s#connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\"#connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https_LE\" keystore=\"JKS\" keystoreFile=\"certs/files/$HOSTNAME-le.jks\" keystorePass=\"$CAPASSWD\"#g" /opt/tak/CoreConfig.xml
```

### 6.3 Verify Configuration
```bash
# Check if update was applied
grep "cert_https_LE" /opt/tak/CoreConfig.xml

# Should show line with your Let's Encrypt JKS file
```

---

## Step 7: Restart TAK Server

### 7.1 Start TAK Server
```bash
# Start TAK Server with new configuration
systemctl start takserver

# Wait for startup
sleep 30

# Check status
systemctl status takserver
```

### 7.2 Verify SSL Certificate
```bash
# Test SSL connection
openssl s_client -connect localhost:8446 -showcerts

# Look for:
# subject=CN=tak.pinenut.tech
# issuer=C=US, O=Let's Encrypt, CN=R11 (or similar)

# Press Ctrl+C to exit
```

### 7.3 Check TAK Server Logs
```bash
# Watch for successful startup
tail -f /opt/tak/logs/takserver-messaging.log

# Look for:
# "Started TAK Server"
# No SSL/certificate errors
```

---

## Step 8: Set Up Automatic Renewal

Let's Encrypt certificates expire after 90 days. Set up auto-renewal.

### 8.1 Create Renewal Script
```bash
# Create renewal script
cat > /opt/tak/renew-tak-le << 'EOF'
#!/bin/bash

# Read FQDN and password
FQDN=$(cat /opt/tak/fqdn-for-letsencrypt.txt)
CAPASSWD="atakatak"  # Or your custom password
HOSTNAME=$(hostname)

# Renew certificate
certbot renew --quiet

# Convert to PKCS12
openssl pkcs12 -export \
    -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
    -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
    -out /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -name $FQDN \
    -passin pass:$CAPASSWD \
    -passout pass:$CAPASSWD

# Convert to JKS
keytool -importkeystore \
    -destkeystore /opt/tak/certs/files/$HOSTNAME-le.jks \
    -srckeystore /opt/tak/certs/files/$HOSTNAME-le.p12 \
    -srcstoretype pkcs12 \
    -deststorepass "$CAPASSWD" \
    -destkeypass "$CAPASSWD" \
    -srcstorepass "$CAPASSWD"

# Fix permissions
chown -R tak:tak /opt/tak

# Restart TAK Server
systemctl restart takserver &
( tail -f -n0 /opt/tak/logs/takserver-messaging.log & ) | grep -q "Started TAK Server messaging Microservice"
EOF

# Make executable
chmod +x /opt/tak/renew-tak-le
```

### 8.2 Set Up Cron Job
```bash
# Create cron job to run renewal twice daily
cat > /etc/cron.d/certbot-tak-le << EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Run certbot renewal twice daily at random times
0 */12 * * * root certbot renew --quiet && /opt/tak/renew-tak-le
EOF

# Set proper permissions
chmod 644 /etc/cron.d/certbot-tak-le

# Reload cron
systemctl restart cron
```

### 8.3 Test Renewal (Dry Run)
```bash
# Test renewal without actually renewing
certbot renew --dry-run

# Should show:
# "Congratulations, all renewals succeeded"
```

---

## Step 9: Update Enrollment Packages

Now that you have a valid SSL certificate, update enrollment packages.

### 9.1 Regenerate Enrollment Package
```bash
# The enrollment package still references local certificates
# Optionally update to reflect new SSL endpoint

# Note: Client certificates don't need to change!
# The CA trust chain is still the same
# Only the server's SSL certificate changed
```

### 9.2 Test Client Connection
```bash
# From ATAK client, test connection to:
# tak.pinenut.tech:8089

# Should connect with valid SSL (green lock icon)
# Certificate issuer should show "Let's Encrypt"
```

---

## Step 10: Verification Checklist

Before considering Let's Encrypt setup complete:

**Certificate Files:**
- [ ] `/etc/letsencrypt/live/[domain]/` exists
- [ ] `/opt/tak/certs/files/[hostname]-le.p12` created
- [ ] `/opt/tak/certs/files/[hostname]-le.jks` created
- [ ] Files owned by `tak:tak`

**TAK Server:**
- [ ] `systemctl status takserver` shows "active (running)"
- [ ] No SSL errors in logs
- [ ] `openssl s_client -connect localhost:8446` shows Let's Encrypt issuer
- [ ] CoreConfig.xml updated with LE keystore

**Renewal:**
- [ ] `/opt/tak/renew-tak-le` script exists and is executable
- [ ] Cron job created in `/etc/cron.d/certbot-tak-le`
- [ ] `certbot renew --dry-run` succeeds

**External Access:**
- [ ] https://tak.pinenut.tech:8443 accessible (web UI)
- [ ] Browser shows valid SSL certificate
- [ ] Certificate issuer is "Let's Encrypt"
- [ ] No browser security warnings

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

echo -n "TAK Server running: "
systemctl is-active --quiet takserver && echo "✅" || echo "❌"

echo -n "Renewal script exists: "
test -f /opt/tak/renew-tak-le && test -x /opt/tak/renew-tak-le && echo "✅" || echo "❌"

echo -n "Cron job configured: "
test -f /etc/cron.d/certbot-tak-le && echo "✅" || echo "❌"

echo -n "Port 8443 listening: "
ss -tulpn | grep -q ":8443" && echo "✅" || echo "❌"

echo ""
echo "Testing SSL certificate..."
echo | openssl s_client -connect localhost:8443 2>/dev/null | grep -E "subject=|issuer="

echo ""
echo "If all checks show ✅ and issuer shows Let's Encrypt, you're good!"
```

---

## Troubleshooting

### Issue: Certbot fails with "Timeout during connect"

**Cause:** Port 80 not accessible from internet

**Fix:**
```bash
# On VPS host
sudo ufw allow 80/tcp
sudo ufw status

# Verify port forwarding in router/firewall
# Test externally: curl -I http://[your-public-ip]
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
```

### Issue: Renewal fails silently

**Cause:** Renewal script errors

**Fix:**
```bash
# Test renewal script manually
/opt/tak/renew-tak-le

# Check for errors
# Fix script as needed

# Test cron job
sudo run-parts --test /etc/cron.d
```

### Issue: Clients can't connect after Let's Encrypt

**Cause:** Client CA trust not updated

**Fix:**
```bash
# Clients still need to trust your internal CA
# Let's Encrypt only affects server SSL certificate
# Client certificates remain the same

# Verify client has:
# 1. Client certificate (user.p12)
# 2. CA trust (truststore-[CA-NAME].p12)

# These don't change with Let's Encrypt!
```

---

## Certificate Expiration Timeline

**Let's Encrypt Certificates:**
- Valid for 90 days
- Renewal recommended at 60 days
- Automatic renewal runs twice daily
- Failed renewals alert via email

**Monitor Certificate Expiration:**
```bash
# Check expiration date
openssl x509 -in /etc/letsencrypt/live/$FQDN/cert.pem \
    -noout -dates

# Should show:
# notBefore: [date]
# notAfter: [date 90 days from issue]
```

---

## Backup Important Files

After successful Let's Encrypt setup:

```bash
# Create backup directory
mkdir -p /root/tak-letsencrypt-backup

# Backup Let's Encrypt files
cp -r /etc/letsencrypt /root/tak-letsencrypt-backup/

# Backup TAK Server keystores
cp /opt/tak/certs/files/*-le.* /root/tak-letsencrypt-backup/

# Backup CoreConfig
cp /opt/tak/CoreConfig.xml /root/tak-letsencrypt-backup/

# Backup renewal script
cp /opt/tak/renew-tak-le /root/tak-letsencrypt-backup/

# Create tarball
cd /root
tar -czf tak-letsencrypt-backup-$(date +%Y%m%d).tar.gz tak-letsencrypt-backup/

# Copy to host
# (from VPS host outside container)
lxc file pull tak/root/tak-letsencrypt-backup-*.tar.gz ~/
```

---

## Reverting to Self-Signed Certificates

If you need to revert to self-signed certificates:

```bash
# Stop TAK Server
systemctl stop takserver

# Restore backup configuration
cp /opt/tak/CoreConfig.xml.backup-pre-letsencrypt /opt/tak/CoreConfig.xml

# Remove Let's Encrypt reference
sed -i 's/_name="cert_https_LE"/_name="cert_https"/g' /opt/tak/CoreConfig.xml
sed -i '/keystoreFile="certs\/files\/.*-le.jks"/d' /opt/tak/CoreConfig.xml

# Start TAK Server
systemctl start takserver
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

**➡️ Proceed to:** [Phase 6: Verification](06-VERIFICATION.md)

Final steps to verify your complete TAK Server deployment.

---

## Additional Resources

- **Let's Encrypt Documentation:** https://letsencrypt.org/docs/
- **Certbot Documentation:** https://eff-certbot.readthedocs.io/
- **TAK Server Documentation:** https://tak.gov/docs
- **myTeckNet TAK Guides:** https://mytecknet.com/tag/tak/

---

*Last Updated: November 22, 2025*  
*Tested on: TAK Server 5.5, Ubuntu 22.04/24.04 LTS*
