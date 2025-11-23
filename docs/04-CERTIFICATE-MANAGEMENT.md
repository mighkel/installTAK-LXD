# Certificate Management Guide

**Phase 4: Understanding and managing TAK Server certificates**

This guide covers TAK Server's certificate architecture, client certificate creation, and certificate lifecycle management.

---

## Prerequisites

Before starting Phase 4, verify:

- [ ] TAK Server is installed and running
- [ ] installTAK script completed successfully
- [ ] Certificate files exist in `/opt/tak/certs/files/`
- [ ] Certificate password is documented

---

## Understanding TAK Certificate Architecture

### Certificate Hierarchy

TAK Server uses a three-tier certificate authority (CA) structure:
```
Root CA (CCVFD-ROOT-CA)
    ↓
Intermediate CA (CCVFD-INTERMEDIATE-CA)
    ↓
Server Certificate (tak.pinenut.tech)
    ↓
Client Certificates (users, ATAK devices)
```

**Why this structure?**
- **Root CA**: Rarely used, kept offline in production
- **Intermediate CA**: Signs day-to-day certificates
- **Server Certificate**: TAK Server's identity
- **Client Certificates**: Individual users/devices

### Certificate Types

**Server Certificates:**
- `tak.jks` - Server keystore (Java format)
- Used by TAK Server to identify itself to clients
- Contains: Private key + certificate + CA chain

**Client Certificates:**
- `admin.p12` - Admin user certificate
- `webadmin.p12` - Web UI access certificate
- `[username].p12` - Individual client certificates
- Used by ATAK/WinTAK to authenticate to TAK Server

**Trust Stores:**
- `truststore.jks` - Contains root and intermediate CAs
- Clients use this to verify the server's certificate
- Server uses this to verify client certificates

---

## Step 1: Verify Certificate Files

### 1.1 Check Certificate Directory
```bash
# Get shell in container
lxc exec tak -- bash

# Navigate to cert directory
cd /opt/tak/certs/files

# List all certificate files
ls -lh
```

**You should see:**
```
admin.p12              - Admin certificate
webadmin.p12           - Web admin certificate
tak.jks                - Server keystore
truststore.jks         - Trust store
ca.pem                 - Root CA certificate
ca-do-not-share.key    - Root CA private key (PROTECT THIS!)
```

### 1.2 Inspect Server Certificate
```bash
# View server certificate details
keytool -list -v -keystore tak.jks -storepass atakatak | grep -A 5 "Owner:"

# Expected output:
# Owner: CN=tak.pinenut.tech, OU=Communications, O=Clear Creek VFD, L=Idaho City, ST=Idaho, C=US
# Issuer: CN=CCVFD-INTERMEDIATE-CA, OU=Communications, O=Clear Creek VFD...
```

**Verify:**
- CN (Common Name) matches your domain: `tak.pinenut.tech`
- Organization matches what you entered during installation
- Issuer is your Intermediate CA

### 1.3 Check Certificate Validity
```bash
# Check certificate expiration
keytool -list -v -keystore tak.jks -storepass atakatak | grep -A 2 "Valid"

# Example output:
# Valid from: Fri Nov 22 10:30:00 MST 2025 until: Sun Nov 22 10:30:00 MST 2027
```

---

## Step 2: Understanding Enrollment Packages

### 2.1 What is enrollmentDP.zip?

The enrollment package contains:
- `manifest.xml` - Configuration for ATAK
- `truststore-root.p12` - Root CA for verifying server
- Server connection details (IP/domain, ports)

**What it does NOT contain:**
- Client certificate (generated during enrollment)
- Private keys (stay on device)

### 2.2 Locate Enrollment Package
```bash
# Check for enrollment package
ls -lh /root/enrollmentDP.zip
ls -lh /opt/tak/certs/files/enrollmentDP.zip

# View contents without extracting
unzip -l /root/enrollmentDP.zip
```

### 2.3 Copy Enrollment Package to Host
```bash
# Exit container
exit

# From VPS host, copy to home directory
lxc file pull tak/root/enrollmentDP.zip ~/enrollmentDP-$(date +%Y%m%d).zip

# Download to your local machine
# scp takadmin@your-vps-ip:~/enrollmentDP-*.zip ./
```

---

## Step 3: Creating Client Certificates Manually

Sometimes you need to create client certificates without enrollment.

### 3.1 Using makeCert.sh Script
```bash
# In container, navigate to certs directory
cd /opt/tak/certs

# Create a client certificate
sudo ./makeCert.sh client [username]

# Example:
sudo ./makeCert.sh client firefighter1

# Certificate created at:
# /opt/tak/certs/files/firefighter1.p12
```

### 3.2 Verify Client Certificate
```bash
# List the certificate details
keytool -list -v -keystore files/firefighter1.p12 -storepass atakatak

# Should show:
# Alias name: firefighter1
# Owner: CN=firefighter1, OU=Communications, O=Clear Creek VFD...
# Issuer: CN=CCVFD-INTERMEDIATE-CA...
```

### 3.3 Copy Client Certificate to Host
```bash
# Exit container
exit

# From VPS host
lxc file pull tak/opt/tak/certs/files/firefighter1.p12 ~/firefighter1.p12

# Download to local machine for distribution
# scp takadmin@your-vps-ip:~/firefighter1.p12 ./
```

### 3.4 Distribute to User

**Methods:**
1. **Secure email** - Password protect the .p12 file
2. **USB drive** - Hand-deliver for sensitive deployments
3. **Encrypted cloud** - Use your NextCloud/Google Drive (private)

**Never:**
- ❌ Post certificates on public websites
- ❌ Share via unencrypted channels
- ❌ Include password in same message as certificate

---

## Step 4: Certificate Installation on Clients

### 4.1 ATAK (Android)

**Method A: Using Enrollment Package**

1. Transfer `enrollmentDP.zip` to Android device
2. Open ATAK
3. Go to Settings → Network → Certificate Enrollment
4. Tap "Import Config" → Select `enrollmentDP.zip`
5. Enter username and password (created in TAK Server web UI)
6. Tap "Enroll"
7. Wait for certificate generation
8. ATAK connects automatically

**Method B: Using Manual Certificate**

1. Transfer `firefighter1.p12` to Android device
2. Open ATAK
3. Go to Settings → Network → Manage Server Connections
4. Tap "+" to add server
5. Enter:
   - Description: `CCVFD TAK Server`
   - Address: `tak.pinenut.tech`
   - Port: `8089`
   - Protocol: `SSL`
6. Tap "Manage SSL/TLS Certificates"
7. Import `firefighter1.p12`
8. Enter certificate password: `atakatak`
9. Also import `truststore-root.p12` from enrollment package
10. Save and connect

### 4.2 WinTAK (Windows)

1. Copy certificate file to Windows machine
2. Launch WinTAK
3. Click Settings → Network Preferences
4. Click "Manage Server Connections"
5. Add new connection:
   - Description: `CCVFD TAK Server`
   - Address: `tak.pinenut.tech:8089:ssl`
6. Under "Authentication":
   - Import Client Certificate: Select `firefighter1.p12`
   - Enter password: `atakatak`
   - Import CA Certificate: Select `truststore-root.p12`
7. Apply and connect

### 4.3 iTAK (iOS)

Similar process to ATAK:
1. Transfer enrollment package or certificate to iOS device
2. Open iTAK
3. Settings → Servers → Add Server
4. Import certificate and configure connection
5. Connect

---

## Step 5: CRITICAL - Restart After Certificate Changes

**This cannot be emphasized enough!**

### 5.1 When to Restart TAK Server

Restart TAK Server after ANY of these certificate operations:
- ✅ Creating new server certificate
- ✅ Regenerating CAs
- ✅ Updating truststore
- ✅ Changing certificate configuration in CoreConfig.xml
- ✅ Installing Let's Encrypt certificates

### 5.2 Proper Restart Procedure
```bash
# In container
sudo systemctl restart takserver

# Wait for full restart (30 seconds minimum)
sleep 30

# Verify it's running
sudo systemctl status takserver

# Check for errors
sudo journalctl -u takserver -n 50 | grep -i error
```

### 5.3 Why This Matters

TAK Server loads certificates into memory at startup. Changes to certificate files are **not** picked up until restart. This is the #1 cause of "SSL handshake failure" issues.

---

## Step 6: Certificate Renewal

Certificates expire (typically 2 years). Here's how to renew.

### 6.1 Check Certificate Expiration
```bash
# Check when server cert expires
cd /opt/tak/certs
keytool -list -v -keystore files/tak.jks -storepass atakatak | grep Valid

# Check CA expiration
openssl x509 -in files/ca.pem -text -noout | grep "Not After"
```

### 6.2 Renew Server Certificate
```bash
# Navigate to certs directory
cd /opt/tak/certs

# Backup old certificate
sudo cp files/tak.jks files/tak.jks.backup-$(date +%Y%m%d)

# Generate new server certificate
sudo ./makeCert.sh server tak.pinenut.tech

# RESTART TAK SERVER!
sudo systemctl restart takserver
sleep 30

# Verify new certificate
openssl s_client -connect localhost:8089 -showcerts | grep -A 2 "Valid"
```

### 6.3 Renew Client Certificates

Client certificates also expire. To renew:
```bash
# Create new certificate with same username
cd /opt/tak/certs
sudo ./makeCert.sh client firefighter1

# Old certificate at: files/firefighter1.p12.backup
# New certificate at: files/firefighter1.p12

# Distribute new certificate to user
```

**Users must:**
1. Remove old certificate from ATAK/WinTAK
2. Import new certificate
3. Reconnect to server

---

## Step 7: Certificate Revocation

If a certificate is compromised or a user leaves the organization:

### 7.1 Revoke via Web UI

1. Access TAK Server web UI at `https://tak.pinenut.tech:8443`
2. Login with webadmin.p12 certificate
3. Go to "User Manager"
4. Find the user
5. Click "Revoke Certificate"
6. Confirm revocation

### 7.2 Revoke via Command Line
```bash
# In container
cd /opt/tak/certs

# Revoke certificate
sudo ./makeCert.sh revoke [username]

# Example:
sudo ./makeCert.sh revoke firefighter1

# Restart TAK Server to apply
sudo systemctl restart takserver
```

### 7.3 Generate Certificate Revocation List (CRL)
```bash
# Generate CRL
cd /opt/tak/certs
sudo ./makeCert.sh crl

# CRL file created at: files/crl.pem

# TAK Server automatically checks this file
```

---

## Step 8: Certificate Troubleshooting

### Issue: "SSL handshake failure" in ATAK

**Common causes and fixes:**

1. **Server not restarted after cert change:**
```bash
   sudo systemctl restart takserver
```

2. **Wrong certificate password:**
   - Default is `atakatak`
   - Check what you set during installation

3. **Certificate hostname mismatch:**
```bash
   # Check server cert CN
   keytool -list -v -keystore /opt/tak/certs/files/tak.jks -storepass atakatak | grep Owner
   
   # CN must match domain in ATAK connection settings
```

4. **Missing trust store on client:**
   - Client needs `truststore-root.p12` to verify server
   - Re-import from enrollment package

5. **Certificate expired:**
```bash
   # Check expiration
   keytool -list -v -keystore /opt/tak/certs/files/tak.jks -storepass atakatak | grep Valid
```

### Issue: Web UI won't accept webadmin.p12

**Fixes:**

1. **Certificate not imported to browser:**
   - Firefox: Settings → Privacy & Security → Certificates → View Certificates → Your Certificates → Import
   - Chrome: Settings → Privacy and security → Security → Manage certificates → Import

2. **Wrong browser:**
   - Must use desktop browser (Firefox/Chrome/Edge)
   - Mobile browsers don't support client certificates well

3. **Certificate password incorrect:**
   - Default: `atakatak`
   - Try re-importing with correct password

### Issue: Certificate signed by unknown authority

**Fix:**
```bash
# Client is missing the CA certificate
# Extract CA from enrollment package
unzip enrollmentDP.zip
# Import truststore-root.p12 into client
```

### Issue: Can't create new client certificates

**Check permissions:**
```bash
cd /opt/tak/certs
ls -lh

# Should show root ownership
# If not:
sudo chown -R root:root /opt/tak/certs/
```

---

## Step 9: Advanced Certificate Topics

### 9.1 Custom Certificate Validity Period

By default, certificates are valid for 2 years. To change:
```bash
# Edit cert-metadata.sh
sudo nano /opt/tak/certs/cert-metadata.sh

# Find and modify:
CAVALIDITYDAYS=730     # CA valid for 2 years
VALIDITYDAYS=730       # Certificates valid for 2 years

# Save and exit
# New certificates will use these values
```

### 9.2 Creating Certificates with Custom Subject
```bash
# Manually specify certificate details
cd /opt/tak/certs

# Create cert with custom DN
sudo ./makeCert.sh client "firefighter1" \
  -subj "/C=US/ST=Idaho/L=Idaho City/O=Clear Creek VFD/OU=Field Ops/CN=firefighter1"
```

### 9.3 Exporting Certificates to Different Formats
```bash
# Convert .p12 to .pem (for other tools)
openssl pkcs12 -in firefighter1.p12 -out firefighter1.pem -nodes -passin pass:atakatak

# Extract just the certificate
openssl pkcs12 -in firefighter1.p12 -clcerts -nokeys -out firefighter1-cert.pem -passin pass:atakatak

# Extract just the private key
openssl pkcs12 -in firefighter1.p12 -nocerts -nodes -out firefighter1-key.pem -passin pass:atakatak
```

---

## Step 10: Certificate Best Practices

### Security Recommendations

1. **Protect Private Keys**
   - Never share `ca-do-not-share.key`
   - Keep root CA offline if possible
   - Backup to encrypted storage only

2. **Use Strong Passwords**
   - Change from default `atakatak` for production
   - Use password manager
   - Different passwords per deployment

3. **Regular Rotation**
   - Rotate certificates before expiration
   - Annual rotation for high-security environments
   - Track expiration dates

4. **Certificate Inventory**
   - Maintain list of issued certificates
   - Track who has which certificates
   - Document revocation dates

5. **Secure Distribution**
   - Use encrypted channels
   - Password-protect .p12 files
   - Verify receipt before deleting

### Backup Strategy
```bash
# Backup entire cert directory
sudo tar -czf tak-certs-backup-$(date +%Y%m%d).tar.gz /opt/tak/certs/

# Copy to safe location
lxc file pull tak/root/tak-certs-backup-*.tar.gz ~/

# Store off-server (encrypted)
```

---

## Step 11: Certificate Verification Checklist

Before proceeding to Phase 5:

- [ ] Server certificate CN matches your domain
- [ ] Server certificate is valid (not expired)
- [ ] enrollmentDP.zip exists and contains manifest.xml
- [ ] webadmin.p12 imported to browser
- [ ] Can access web UI at https://tak.pinenut.tech:8443
- [ ] Test client certificate created and verified
- [ ] Certificate backup created
- [ ] TAK Server restarted after any cert changes

### Quick Certificate Test
```bash
# Test server certificate from container
openssl s_client -connect localhost:8089 -showcerts < /dev/null

# Look for:
# - verify return:1 (certificate verified)
# - subject=CN=tak.pinenut.tech
# - No error messages
```

---

## Next Steps

Once certificates are verified and working:

**➡️ Proceed to:** [Phase 5: Networking & HAProxy](05-NETWORKING.md)

This next guide covers:
- Exposing TAK Server to the internet
- Setting up HAProxy reverse proxy
- Configuring firewall rules
- Setting up Let's Encrypt SSL certificates
- DNS configuration

---

## Additional Resources

- **TAK Server Certificate Guide:** https://tak.gov/docs
- **OpenSSL Documentation:** https://www.openssl.org/docs/
- **Java Keytool Guide:** https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html
- **myTeckNet Certificate Tutorials:** https://mytecknet.com/lets-sign-our-tak-server/

---

*Last Updated: November 2025*  
*Tested on: TAK Server 5.5*  
*Certificate Tools: OpenSSL 3.x, Java Keytool 17*
