# Certificate Management Guide

**Phase 4: Understanding and managing TAK Server certificates**

This guide covers TAK Server's certificate architecture, client certificate creation, and certificate lifecycle management.

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
| `root@tak:~#` | 📦 Inside container (as root) |
| `takadmin@tak:~$` | 📦 Inside container (as takadmin) |

**Placeholders used in this document:**
- `[YOUR_DOMAIN]` - Your TAK server FQDN (e.g., `tak.example.com`)
- `[YOUR_CA_NAME]` - Your CA name prefix (e.g., `MVFD`)
- `[USERNAME]` - Client certificate username (e.g., `user1`, `engine1`)
- `[CERT_PASSWORD]` - Your certificate password (default: `atakatak`)

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_DOMAIN]` becomes `tak.example.com`
> (Keep any surrounding quotes, remove the brackets)

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
Root CA ([YOUR_CA_NAME]-ROOT-CA)
    ↓
Intermediate CA ([YOUR_CA_NAME]-INTERMEDIATE-CA)
    ↓
Server Certificate ([YOUR_DOMAIN])
    ↓
Client Certificates (users, ATAK devices)
```

**Why this structure?**
- **Root CA**: Rarely used, kept secure (ideally offline in production)
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
- `[USERNAME].p12` - Individual client certificates
- Used by ATAK/WinTAK to authenticate to TAK Server

**Trust Stores:**
- `truststore.jks` - Contains root and intermediate CAs
- Clients use this to verify the server's certificate
- Server uses this to verify client certificates

---

## Step 1: Verify Certificate Files

📦 **Inside Container**

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
keytool -list -v -keystore tak.jks -storepass [CERT_PASSWORD] | grep -A 5 "Owner:"

# Expected output:
# Owner: CN=[YOUR_DOMAIN], OU=[YOUR_UNIT], O=[YOUR_ORG], L=[YOUR_CITY], ST=[YOUR_STATE], C=US
# Issuer: CN=[YOUR_CA_NAME]-INTERMEDIATE-CA, OU=...
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[CERT_PASSWORD]` with your actual certificate password (default: `atakatak`).

**Verify:**
- CN (Common Name) matches your domain
- Organization matches what you entered during installation
- Issuer is your Intermediate CA

### 1.3 Check Certificate Validity

```bash
# Check certificate expiration
keytool -list -v -keystore tak.jks -storepass [CERT_PASSWORD] | grep -A 2 "Valid"

# Example output:
# Valid from: Fri Nov 22 10:30:00 MST 2025 until: Sun Nov 22 10:30:00 MST 2027
```

---

## Step 2: Understanding Enrollment Packages

### 2.1 What is enrollmentDP.zip?

The enrollment package contains:
- `manifest.xml` - Configuration for ATAK
- `truststore-root.p12` - Root CA for verifying server
- Server connection details (domain, ports)

**What it does NOT contain:**
- Client certificate (generated during enrollment)
- Private keys (stay on device)

> 💡 **RECOMMENDED APPROACH**
> Using enrollment packages with auto-enrollment (port 8446) is the easiest way to provision ATAK clients. The client generates its own certificate during enrollment.

### 2.2 Auto-Enrollment Overview

Auto-enrollment allows ATAK/WinTAK clients to automatically request and receive certificates from TAK Server. This requires:

1. **Certificate enrollment enabled** on TAK Server (port 8446)
2. **User account created** in TAK Server web UI
3. **Let's Encrypt SSL** (recommended) for browser-trusted enrollment page

> 💡 **LET'S ENCRYPT FOR AUTO-ENROLLMENT**
> While auto-enrollment works with self-signed certificates, clients may see SSL warnings. Configuring Let's Encrypt (covered in [Phase 5: Networking](05-NETWORKING.md)) provides a smoother enrollment experience.
>
> For now, enrollment with self-signed certificates works - users just need to accept the certificate warning.

### 2.3 Locate Enrollment Package

📦 **Inside Container**

```bash
# Check for enrollment package
ls -lh /root/enrollmentDP.zip
ls -lh /opt/tak/certs/files/enrollmentDP.zip

# View contents without extracting
unzip -l /root/enrollmentDP.zip
```

### 2.4 Copy Enrollment Package to Host

📦 **Inside Container** → 🖥️ **VPS Host**

```bash
# Exit container (may need 'exit' twice)
exit

# Verify you're on VPS host
hostname  # Should NOT be 'tak'
```

🖥️ **VPS Host**

```bash
# Copy to home directory
lxc file pull tak/root/enrollmentDP.zip ~/enrollmentDP-$(date +%Y%m%d).zip

# Download to your local machine
# scp takadmin@[YOUR_VPS_IP]:~/enrollmentDP-*.zip ./
```

---

## Step 3: Creating Client Certificates Manually

> 💡 **WHEN TO USE MANUAL CERTIFICATES**
> Manual certificate creation is useful when:
> - Auto-enrollment isn't available or desired
> - You need certificates for automated systems
> - You want pre-generated certificates for offline provisioning

📦 **Inside Container**

### 3.1 Using makeCert.sh Script

```bash
# Navigate to certs directory
cd /opt/tak/certs

# Create a client certificate
sudo ./makeCert.sh client [USERNAME]

# Example:
sudo ./makeCert.sh client user1

# Certificate created at:
# /opt/tak/certs/files/user1.p12
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[USERNAME]` with the actual username for the certificate.

### 3.2 Multi-Device User Naming Convention

If a user has multiple devices, consider a naming convention to keep them organized:

**Suggested naming pattern:**
```bash
sudo ./makeCert.sh client jsmith         # Default - Android EUD or primary device
sudo ./makeCert.sh client jsmith-wt      # WinTAK
sudo ./makeCert.sh client jsmith-it      # iTAK
sudo ./makeCert.sh client jsmith-ta      # TAKAware
sudo ./makeCert.sh client jsmith-tx      # TAK-X
```

**Or by unit/apparatus:**
```bash
sudo ./makeCert.sh client engine1        # Primary device
sudo ./makeCert.sh client engine1-mdt    # Mobile Data Terminal
```

> 💡 **NOTE**
> This is a suggested option, not a strict requirement. Choose a convention that works for your organization and document it in your admin procedures.

### 3.3 Verify Client Certificate

```bash
# List the certificate details
keytool -list -v -keystore files/user1.p12 -storepass [CERT_PASSWORD]

# Should show:
# Alias name: user1
# Owner: CN=user1, OU=[YOUR_UNIT], O=[YOUR_ORG]...
# Issuer: CN=[YOUR_CA_NAME]-INTERMEDIATE-CA...
```

### 3.4 Copy Client Certificate to Host

🖥️ **VPS Host**

```bash
# Copy from container
lxc file pull tak/opt/tak/certs/files/user1.p12 ~/user1.p12

# Download to local machine for distribution
# scp takadmin@[YOUR_VPS_IP]:~/user1.p12 ./
```

### 3.5 Distribute to User

**Secure distribution methods:**
- 🔒 **Secure email** - Password protect the .p12 file
- 💾 **USB drive** - Hand-deliver for sensitive deployments
- ☁️ **Encrypted cloud** - Private NextCloud/Google Drive share

> ⛔ **NEVER:**
> - Post certificates on public websites
> - Share via unencrypted channels
> - Include password in same message as certificate

---

## Step 4: Certificate Installation on Clients

### 4.1 ATAK (Android)

**Method A: Using Enrollment Package (Recommended)**

First, transfer `enrollmentDP.zip` to your Android device's Download folder.

**Import Option 1 (ATAK 5.4.0+):**
1. Open ATAK
2. Go to **Settings → Import → Local SD**
3. Browse to `/Download/` folder
4. Select `enrollmentDP.zip`
5. Select **Copy files** option

**Import Option 2 (ATAK 5.4.0+):**
1. Open ATAK
2. Go to **Settings → Network Preferences → Data Package**
3. Browse to `/Download/` folder
4. Select `enrollmentDP.zip`

**After importing:**
1. Go to **Settings → Network → Certificate Enrollment**
2. Enter username and password (created in TAK Server web UI)
3. Tap **Enroll**
4. Wait for certificate generation (10-30 seconds)
5. ATAK connects automatically ✅

**Method B: Using Manual Certificate**

1. Transfer `[USERNAME].p12` to Android device
2. Open ATAK
3. Go to **Settings → Network → Manage Server Connections**
4. Tap **+** to add server
5. Enter:
   - **Description:** `TAK Server`
   - **Address:** `[YOUR_DOMAIN]`
   - **Port:** `8089`
   - **Protocol:** `SSL`
6. Tap **Manage SSL/TLS Certificates**
7. Import client certificate (`[USERNAME].p12`)
8. Enter certificate password
9. Import CA certificate (`truststore-root.p12` from enrollment package)
10. Save and connect

### 4.2 WinTAK (Windows)

1. Copy certificate files to Windows machine
2. Launch WinTAK
3. Click **Settings → Network Preferences**
4. Click **Manage Server Connections**
5. Add new connection:
   - **Description:** `TAK Server`
   - **Address:** `[YOUR_DOMAIN]:8089:ssl`
6. Under **Authentication**:
   - Import Client Certificate: Select `[USERNAME].p12`
   - Enter password
   - Import CA Certificate: Select `truststore-root.p12`
7. Apply and connect

### 4.3 iTAK (iOS)

Similar process to ATAK:
1. Transfer enrollment package or certificate to iOS device (AirDrop, email, etc.)
2. Open iTAK
3. **Settings → Servers → Add Server**
4. Import certificate and configure connection
5. Connect

---

## Step 5: CRITICAL - Restart After Certificate Changes

> ⛔ **This cannot be emphasized enough!**

### 5.1 When to Restart TAK Server

Restart TAK Server after ANY of these certificate operations:
- ✅ Creating new server certificate
- ✅ Regenerating CAs
- ✅ Updating truststore
- ✅ Changing certificate configuration in CoreConfig.xml
- ✅ Installing Let's Encrypt certificates

### 5.2 Proper Restart Procedure

📦 **Inside Container**

```bash
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

📦 **Inside Container**

### 6.1 Check Certificate Expiration

```bash
# Check when server cert expires
cd /opt/tak/certs
keytool -list -v -keystore files/tak.jks -storepass [CERT_PASSWORD] | grep Valid

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
sudo ./makeCert.sh server [YOUR_DOMAIN]

# RESTART TAK SERVER!
sudo systemctl restart takserver
sleep 30

# Verify new certificate
openssl s_client -connect localhost:8089 -showcerts | grep -A 2 "Valid"
```

> ⚠️ **USER CONFIGURATION REQUIRED**
> Replace `[YOUR_DOMAIN]` with your actual domain.

### 6.3 Renew Client Certificates

Client certificates also expire. To renew:

```bash
# Create new certificate with same username
cd /opt/tak/certs
sudo ./makeCert.sh client [USERNAME]

# Old certificate backed up to: files/[USERNAME].p12.backup
# New certificate at: files/[USERNAME].p12

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

1. Access TAK Server web UI at `https://[YOUR_DOMAIN]:8443`
2. Login with webadmin.p12 certificate
3. Go to **User Manager**
4. Find the user
5. Click **Revoke Certificate**
6. Confirm revocation

### 7.2 Revoke via Command Line

📦 **Inside Container**

```bash
cd /opt/tak/certs

# Revoke certificate
sudo ./makeCert.sh revoke [USERNAME]

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
   keytool -list -v -keystore /opt/tak/certs/files/tak.jks -storepass [CERT_PASSWORD] | grep Owner
   
   # CN must match domain in ATAK connection settings
   ```

4. **Missing trust store on client:**
   - Client needs `truststore-root.p12` to verify server
   - Re-import from enrollment package

5. **Certificate expired:**
   ```bash
   # Check expiration
   keytool -list -v -keystore /opt/tak/certs/files/tak.jks -storepass [CERT_PASSWORD] | grep Valid
   ```

### Issue: Web UI won't accept webadmin.p12

**Fixes:**

1. **Certificate not imported to browser:**
   - **Firefox:** Settings → Privacy & Security → Certificates → View Certificates → Your Certificates → Import
   - **Chrome:** Settings → Privacy and security → Security → Manage certificates → Import

2. **Wrong browser:**
   - Must use desktop browser (Firefox/Chrome/Edge)
   - Mobile browsers don't support client certificates well

3. **Certificate password incorrect:**
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

📦 **Inside Container**

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
sudo ./makeCert.sh client "[USERNAME]" \
  -subj "/C=US/ST=[YOUR_STATE]/L=[YOUR_CITY]/O=[YOUR_ORG]/OU=Field Ops/CN=[USERNAME]"
```

### 9.3 Exporting Certificates to Different Formats

```bash
# Convert .p12 to .pem (for other tools)
openssl pkcs12 -in [USERNAME].p12 -out [USERNAME].pem -nodes -passin pass:[CERT_PASSWORD]

# Extract just the certificate
openssl pkcs12 -in [USERNAME].p12 -clcerts -nokeys -out [USERNAME]-cert.pem -passin pass:[CERT_PASSWORD]

# Extract just the private key
openssl pkcs12 -in [USERNAME].p12 -nocerts -nodes -out [USERNAME]-key.pem -passin pass:[CERT_PASSWORD]
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
   - Verify receipt before deleting source

### Backup Strategy

```bash
# Backup entire cert directory
sudo tar -czf tak-certs-backup-$(date +%Y%m%d).tar.gz /opt/tak/certs/

# Copy to host
exit  # Exit container
lxc file pull tak/root/tak-certs-backup-*.tar.gz ~/

# Store off-server (encrypted)
```

---

## Step 11: Verification Checklist

Before proceeding to Phase 5:

- [ ] Server certificate CN matches your domain
- [ ] Server certificate is valid (not expired)
- [ ] enrollmentDP.zip exists and contains manifest.xml
- [ ] webadmin.p12 imported to browser
- [ ] Can access web UI at `https://[YOUR_DOMAIN]:8443`
- [ ] Test client certificate created and verified
- [ ] Certificate backup created
- [ ] TAK Server restarted after any cert changes

### Quick Certificate Test

📦 **Inside Container**

```bash
# Test server certificate
openssl s_client -connect localhost:8089 -showcerts < /dev/null

# Look for:
# - verify return:1 (certificate verified)
# - subject=CN=[YOUR_DOMAIN]
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
- DNS configuration
- Setting up Let's Encrypt SSL certificates (for smoother auto-enrollment)

---

## Additional Resources

- **TAK Server Product Page:** https://tak.gov/products/tak-server
- **OpenSSL Documentation:** https://www.openssl.org/docs/
- **Java Keytool Guide:** https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html
- **TAK Syndicate:** https://www.thetaksyndicate.org/

---

*Last Updated: November 2025*  
*Tested on: TAK Server 5.5*  
*Certificate Tools: OpenSSL 3.x, Java Keytool 17*
