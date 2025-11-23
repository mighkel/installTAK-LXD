# Quick Start Guide: Enhanced installTAK-LXD Script

## TL;DR - What Changed

**Problem:** Original script tried to set up Let's Encrypt during installation, which fails in LXD containers because networking isn't configured yet.

**Solution:** Enhanced script **skips Let's Encrypt** during Phase 3 installation and **defers it to Phase 5** after networking is ready.

---

## Installation Command (Phase 3)

```bash
# In your LXD container as takadmin:
cd ~/takserver-install/installTAK

# Replace the script:
wget https://raw.githubusercontent.com/mighkel/installTAK-LXD/main/scripts/installTAK-LXD-enhanced.sh
chmod +x installTAK-LXD-enhanced.sh

# Run with LXD mode enabled:
sudo ./installTAK-LXD-enhanced.sh takserver-5.5-RELEASE.deb false true
#                                                          ^^^^^ ^^^^^
#                                                          FIPS  LXD Mode
```

---

## What to Expect During Installation

### 1. **Modified Splash Screen**
You'll see:
```
IMPORTANT - LXD Mode Notes:
  • Let's Encrypt will be configured LATER in Phase 5 (Networking)
  • Choose 'Local (self-signed)' when prompted for FQDN trust
  • Network port forwarding is configured in Phase 5
```

### 2. **Installation Prompts**
Answer the same as before:
- **Certificate Info:** Your organization details
- **Certificate Password:** Default `atakatak` or custom
- **Certificate Authority Names:** Your CA names
- **Certificate Enrollment:** `Yes` (recommended)
- **Federation:** `No` (unless federating)
- **Connection Type:** `SSL` (recommended)

### 3. **FQDN Handling - THIS IS THE KEY CHANGE**
When asked for FQDN:
- Enter your domain (e.g., `tak.pinenut.tech`)
- Script saves it to `/opt/tak/fqdn-for-letsencrypt.txt`
- **Script SKIPS Let's Encrypt setup** (will be done in Phase 5)
- Uses local self-signed certificates for now

### 4. **Completion**
You'll see:
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
  1. Copy certificates to host
  2. Create snapshot: lxc snapshot tak tak-installed
  3. Proceed to Phase 4: Certificate Management
```

---

## After Installation (Phase 5)

Once networking is configured (ports forwarded, DNS working):

```bash
# Inside container:
sudo /opt/tak/setup-letsencrypt.sh

# Or follow the detailed Phase 5B guide
```

---

## Key Files Created

### During Phase 3 Installation:
```
/opt/tak/fqdn-for-letsencrypt.txt  ← Your domain saved for later
/home/takadmin/webadmin.p12        ← Web admin certificate
/home/takadmin/enrollmentDP.zip    ← ATAK enrollment package
/opt/tak/CoreConfig.xml            ← TAK Server config (local certs)
```

### During Phase 5 Let's Encrypt Setup:
```
/etc/letsencrypt/live/[domain]/    ← Let's Encrypt certificates
/opt/tak/certs/files/[host]-le.jks ← TAK Server keystore with LE cert
/opt/tak/renew-tak-le              ← Auto-renewal script
/etc/cron.d/certbot-tak-le         ← Renewal cron job
```

---

## Verification Commands

### Check Installation:
```bash
# TAK Server running?
systemctl status takserver

# Ports listening?
ss -tulpn | grep -E ":8089|:8443|:8446"

# FQDN saved?
cat /opt/tak/fqdn-for-letsencrypt.txt

# Logs good?
tail -f /opt/tak/logs/takserver-messaging.log
```

### Check Let's Encrypt (After Phase 5):
```bash
# Certificate exists?
ls -lh /etc/letsencrypt/live/*/fullchain.pem

# TAK using LE cert?
grep "cert_https_LE" /opt/tak/CoreConfig.xml

# SSL working?
openssl s_client -connect localhost:8443
```

---

## Troubleshooting Quick Reference

### Issue: Script fails at networking check
```bash
# Test connectivity:
ping -c 2 8.8.8.8
nslookup archive.ubuntu.com

# Fix: Check container networking
lxc exec tak -- cat /etc/resolv.conf
```

### Issue: PostgreSQL won't start
```bash
# Restart:
systemctl restart postgresql

# Check logs:
tail -f /var/log/postgresql/postgresql-15-main.log
```

### Issue: TAK Server won't start
```bash
# Check logs:
tail -f /opt/tak/logs/takserver-messaging.log

# Restart:
systemctl restart takserver
```

### Issue: Let's Encrypt fails (Phase 5)
```bash
# Port 80 accessible?
curl -I http://tak.pinenut.tech

# DNS working?
nslookup tak.pinenut.tech

# Test renewal:
certbot renew --dry-run
```

---

## Comparison: Old vs New Script

| Step | Original Script | Enhanced Script |
|------|----------------|-----------------|
| **Phase 3 Install** | Tries Let's Encrypt immediately → FAILS | Saves FQDN, uses local certs → SUCCESS |
| **Networking Dependency** | Required during install | Deferred to Phase 5 |
| **User Experience** | Installation fails, confusion | Clear guidance, phased approach |
| **Let's Encrypt Setup** | Attempted too early | Phase 5 after networking ready |

---

## Benefits of Enhanced Script

✅ **Installation succeeds** even without public network access  
✅ **Aligns with documentation** (Phase 1-6 workflow)  
✅ **Better error messages** and guidance  
✅ **Clearer separation** between local and public certificates  
✅ **Proper timing** for Let's Encrypt (after networking)  

---

## Documentation Links

1. **IMPROVEMENTS-SUMMARY.md** - Detailed technical changes
2. **05B-LETSENCRYPT-SETUP.md** - Complete Phase 5 Let's Encrypt guide
3. **installTAK-LXD-enhanced.sh** - The enhanced script

---

## Getting Help

**If you encounter issues:**
1. Check logs: `/opt/tak/logs/takserver-messaging.log`
2. Review installation log: `/tmp/.takinstall.log`
3. Verify prerequisites are met
4. Compare your setup to the troubleshooting section

**For Let's Encrypt issues (Phase 5):**
1. Verify port 80 is accessible from internet
2. Confirm DNS is resolving correctly
3. Check firewall and port forwarding
4. Review Phase 5B guide for detailed troubleshooting

---

## Quick Command Reference

```bash
# Copy certificates from container to host:
lxc file pull tak/home/takadmin/webadmin.p12 ~/
lxc file pull tak/home/takadmin/enrollmentDP.zip ~/

# Create snapshot after successful install:
lxc snapshot tak tak-installed

# Check TAK Server status:
lxc exec tak -- systemctl status takserver

# View TAK Server logs:
lxc exec tak -- tail -f /opt/tak/logs/takserver-messaging.log

# Check saved FQDN:
lxc exec tak -- cat /opt/tak/fqdn-for-letsencrypt.txt

# Test TAK Server ports:
lxc exec tak -- ss -tulpn | grep java
```

---

## Next Steps After Phase 3

1. ✅ **Copy certificates to host** (use commands above)
2. ✅ **Create snapshot** `lxc snapshot tak tak-installed`
3. ✅ **Proceed to Phase 4:** Certificate Management
4. ✅ **Continue to Phase 5:** Networking setup
5. ✅ **Run Let's Encrypt setup** (Phase 5B)
6. ✅ **Final verification** (Phase 6)

---

*Remember: This enhanced script is designed for LXD container deployments. For standard bare-metal or VM installations, the original script workflow still applies.*

---

**Version:** 2.5-LXD  
**Last Updated:** November 22, 2025  
**Compatibility:** TAK Server 5.5, Ubuntu 22.04/24.04 LTS
