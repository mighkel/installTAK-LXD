# installTAK-LXD Enhanced Script - Improvements Summary

## Version 2.5-LXD
**Date:** November 2025

---

## Key Improvements

### 1. **Let's Encrypt Deferral for LXD Containers**

**Problem:**
The original script attempted to run Let's Encrypt certificate enrollment during initial installation, which fails in LXD containers because:
- Port 80 is not yet forwarded from the host
- No reverse proxy is configured
- DNS may not be properly configured
- Container networking is still internal-only

**Solution:**
- Added `set-FQDN-lxd()` function that captures FQDN but **skips** Let's Encrypt setup
- Saves FQDN to `/opt/tak/fqdn-for-letsencrypt.txt` for later use in Phase 5
- Shows clear messaging that Let's Encrypt is deferred to Phase 5 (Networking)
- Uses local self-signed certificates for initial installation

**Benefits:**
- Installation completes successfully without network dependencies
- Aligns with the documented Phase 1-6 workflow
- Let's Encrypt can be properly configured after networking is ready

---

### 2. **Enhanced LXD Mode Detection and Messaging**

**Changes:**
- Modified splash screen to show "LXD Mode" when `lxdMode=true`
- Added clear warnings about Let's Encrypt deferral
- Improved user guidance throughout installation

**Example Splash Screen (LXD Mode):**
```
WELCOME to the TAK initial setup script (LXD Container Mode).

IMPORTANT - LXD Mode Notes:
  • Let's Encrypt will be configured LATER in Phase 5 (Networking)
  • Choose 'Local (self-signed)' when prompted for FQDN trust
  • Network port forwarding is configured in Phase 5
```

---

### 3. **Improved Post-Install Verification**

**New `postInstallVerification()` Function:**
- Verifies TAK Server is running
- Checks PostgreSQL status
- Validates port bindings (8089, 8443, 8446)
- Provides clear next steps for users
- Shows saved FQDN for later Let's Encrypt setup

**Example Output:**
```
================================
TAK Server Installation Complete
================================
Web Admin: https://tak-container:8443
Admin Certificate: /home/takadmin/webadmin.p12
Enrollment Package: /home/takadmin/enrollmentDP.zip

IMPORTANT: Let's Encrypt SSL Setup
Let's Encrypt will be configured in Phase 5 (Networking)
Saved FQDN: tak.pinenut.tech

Next Steps:
  1. Copy certificates to host: lxc file pull tak/home/takadmin/webadmin.p12 ~/
  2. Create snapshot: lxc snapshot tak tak-installed
  3. Proceed to Phase 4: Certificate Management
```

---

### 4. **Better Container Networking Verification**

**Enhanced `verifyContainerNetworking()` Function:**
- Checks internet connectivity (ping 8.8.8.8)
- Verifies DNS resolution (nslookup)
- Provides specific troubleshooting guidance
- Fails early if networking issues detected

---

### 5. **PostgreSQL Initialization for LXD**

**Enhanced `verifyPostgreSQL()` Function:**
- Checks if PostgreSQL is listening on port 5432
- Automatically initializes data directory if missing
- Starts PostgreSQL cluster if needed
- Verifies successful startup before proceeding

**Why This Matters:**
LXD containers sometimes have PostgreSQL installed but not initialized. This function ensures PostgreSQL is fully operational before TAK Server starts.

---

### 6. **Improved Datapackage Generation**

**Changes to `create-datapackage()` Function:**
- In LXD mode, uses saved FQDN from `/opt/tak/fqdn-for-letsencrypt.txt`
- Falls back to container IP if FQDN not set
- Works correctly for both initial setup and post-networking updates

---

## Usage

### Standard LXD Container Installation
```bash
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb false true
```

### With FIPS Mode
```bash
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb true true
```

### Standard (Non-LXD) Installation
```bash
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb
```

---

## Workflow Integration

### Phase 3: TAK Installation (Initial Setup)
```bash
# Run enhanced script in LXD mode
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb false true

# Script will:
# 1. Install TAK Server
# 2. Create local self-signed certificates
# 3. Save FQDN for later
# 4. Skip Let's Encrypt setup
# 5. Verify installation
```

### Phase 5: Networking (Let's Encrypt Setup)
```bash
# After port forwarding and DNS are configured
# Run Let's Encrypt setup script (see Phase 5 guide)
sudo ./setup-letsencrypt.sh

# Script will:
# 1. Read saved FQDN from /opt/tak/fqdn-for-letsencrypt.txt
# 2. Request Let's Encrypt certificate
# 3. Configure TAK Server to use new certificate
# 4. Set up automatic renewal
```

---

## Files Created

### During Installation
- `/opt/tak/fqdn-for-letsencrypt.txt` - Saved FQDN for Phase 5
- `/home/takadmin/webadmin.p12` - Web admin certificate
- `/home/takadmin/enrollmentDP.zip` - ATAK enrollment package
- `/home/takadmin/FedCA.pem` - Federation CA certificate

### After Let's Encrypt (Phase 5)
- `/etc/letsencrypt/live/[domain]/` - Let's Encrypt certificates
- `/opt/tak/certs/files/[hostname]-le.jks` - TAK Server keystore with LE cert
- `/opt/tak/renew-tak-le` - Auto-renewal script

---

## Compatibility

### Tested On:
- Ubuntu 22.04 LTS (LXD container)
- Ubuntu 24.04 LTS (LXD container)
- TAK Server 5.5-RELEASE

### Host Requirements:
- LXD installed and configured
- Internet connectivity for container
- DNS resolution working in container

### Container Requirements:
- Minimum 8GB RAM
- PostgreSQL 15
- Java 17 (OpenJDK)

---

## Breaking Changes from Original Script

### Removed Functions:
- `enableFQDN()` - Replaced with `set-FQDN-lxd()` for LXD mode
- Automatic Let's Encrypt setup during installation

### Modified Functions:
- `splash()` - Added LXD mode messaging
- `create-datapackage()` - Uses saved FQDN in LXD mode
- `postInstallVerification()` - Enhanced for LXD containers
- `takWizard()` - Calls `set-FQDN-lxd()` instead of FQDN prompts

### New Functions:
- `set-FQDN-lxd()` - Captures FQDN without setting up Let's Encrypt
- `postInstallVerification()` - Comprehensive post-install checks

---

## Migration from Original Script

If you're currently using the original `installTAK` script:

1. **No changes needed** for existing installations
2. **For new installations** in LXD containers:
   - Use enhanced script with `lxdMode=true`
   - Follow Phase 5 guide for Let's Encrypt
3. **For standard installations** (non-LXD):
   - Script works identically to original

---

## Troubleshooting

### Installation Fails at Networking Check
```bash
# Inside container, test:
ping -c 2 8.8.8.8
nslookup archive.ubuntu.com

# If failing, check:
lxc exec tak -- cat /etc/resolv.conf
lxc network list
```

### PostgreSQL Won't Start
```bash
# Check PostgreSQL status
systemctl status postgresql

# Check logs
tail -f /var/log/postgresql/postgresql-15-main.log

# Reinitialize if needed
sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main
```

### TAK Server Won't Start
```bash
# Check logs
tail -f /opt/tak/logs/takserver-messaging.log

# Check if ports are in use
ss -tulpn | grep -E ":8089|:8443|:8446"

# Restart
systemctl restart takserver
```

### FQDN Not Saved
```bash
# Check if file exists
cat /opt/tak/fqdn-for-letsencrypt.txt

# If missing, create manually
echo "tak.yourdomain.com" | sudo tee /opt/tak/fqdn-for-letsencrypt.txt
```

---

## Future Enhancements

Planned improvements for future versions:

1. **Automated Phase 5 Integration** - Script to automatically configure Let's Encrypt after networking is ready
2. **Health Check Dashboard** - Web-based status page for verifying installation
3. **Certificate Management UI** - Simplified interface for certificate operations
4. **Multi-Container Support** - Deployment scripts for clustered TAK Server
5. **Backup/Restore Tools** - Automated backup of certificates and configuration

---

## Contributing

Found a bug or have a suggestion? Please:
1. Create an issue on GitHub
2. Include your environment details
3. Attach relevant log files
4. Describe expected vs actual behavior

---

## Credits

- **Original installTAK Script:** JR@myTeckNet
- **LXD Enhancements:** mighkel
- **Version:** 2.5-LXD
- **License:** MIT (or as per original script)

---

## References

- [TAK.gov](https://tak.gov)
- [myTeckNet TAK Guides](https://mytecknet.com/tag/tak/)
- [LXD Documentation](https://linuxcontainers.org/lxd/)
- [Let's Encrypt](https://letsencrypt.org/)

---

*Last Updated: November 22, 2025*
