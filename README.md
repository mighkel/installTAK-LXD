# installTAK-LXD

**TAK Server deployment automation for LXD containers on Ubuntu VPS systems**

Optimized for emergency services, volunteer fire departments, and public safety organizations running TAK Server in containerized environments.

![TAK Server Version](https://img.shields.io/badge/TAK%20Server-5.5-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04%20LTS-orange)
![LXD](https://img.shields.io/badge/LXD-Container-green)
![Status](https://img.shields.io/badge/Status-Production%20Tested-success)

---

## 🎯 What This Does

This project provides documentation and scripts for deploying **TAK Server** (Team Awareness Kit) in **LXD containers** on cloud VPS systems. Perfect for organizations that need tactical situational awareness without the complexity of bare-metal server management.

**Key Features:**
- ✅ LXD container isolation for security and easy snapshots
- ✅ Automated certificate generation with multi-device support
- ✅ HAProxy reverse proxy for multi-service hosting
- ✅ Let's Encrypt SSL certificate integration
- ✅ PostgreSQL initialization and health checks
- ✅ Production-tested deployment (Clear Creek VFD / Boise County SO)
- ✅ Multi-device user support (ATAK + WinTAK + iTAK per user)
- ✅ Comprehensive troubleshooting and operations guides

---

## 📋 Prerequisites

### What You Need
- **VPS**: 2+ vCPU, 4GB+ RAM, 80GB+ storage
- **OS**: Ubuntu 22.04 or 24.04 LTS (minimal installation)
- **Domain**: Registered domain name with DNS configured (e.g., `tak.yourdomain.com`)
- **TAK Files**: Access to [TAK.gov](https://tak.gov) downloads:
  - `takserver-X.X-RELEASEX.deb` (or `.rpm`)
  - `takserver-public-gpg.key`

### Tested VPS Providers
- SSDNodes (primary testing platform)
- Linode
- DigitalOcean
- AWS EC2 (Ubuntu AMI)

---

## 🚀 Quick Start

### Recommended Path: Manual Setup

**Follow the comprehensive documentation to understand each step:**

1. **[LXD Setup](docs/01-LXD-SETUP.md)** - Install and configure LXD on your VPS
2. **[Container Creation](docs/02-CONTAINER-SETUP.md)** - Create and configure the TAK container
3. **[TAK Server Installation](docs/03-TAK-INSTALLATION.md)** - Install TAK Server using enhanced installTAK
4. **[Certificate Management](docs/04-CERTIFICATE-MANAGEMENT.md)** - Multi-device certificates and lifecycle management
5. **[Networking & HAProxy](docs/05-NETWORKING.md)** - Reverse proxy, port forwarding, and multi-service routing
6. **[Let's Encrypt SSL](docs/05B-LETSENCRYPT-SETUP.md)** - Browser-trusted SSL certificates (optional)
7. **[Final Verification](docs/06-FINAL-VERIFICATION.md)** - Test ATAK client connections and validate deployment

### Additional Guides

**For Administrators:**
- **[TAK Server Administration Guide](docs/TAK-ADMIN-GUIDE.md)** - Day-to-day operations, monitoring, backups
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions

**For End Users:**
- **[Certificate Renewal User Guide](docs/CERTIFICATE-RENEWAL-USER-GUIDE.md)** - Instructions for ATAK/WinTAK/iTAK certificate renewal

---

## 📂 Repository Structure
```
installTAK-LXD/
├── docs/                                    # Step-by-step documentation
│   ├── 01-LXD-SETUP.md                     # LXD installation and init
│   ├── 02-CONTAINER-SETUP.md               # Container creation
│   ├── 03-TAK-INSTALLATION.md              # TAK Server install with enhanced script
│   ├── 04-CERTIFICATE-MANAGEMENT.md        # Multi-device certs, lifecycle management
│   ├── 05-NETWORKING.md                    # HAProxy, firewall, DNS, multi-service
│   ├── 05B-LETSENCRYPT-SETUP.md           # Let's Encrypt SSL certificates
│   ├── 06-FINAL-VERIFICATION.md            # Testing and validation
│   ├── TAK-ADMIN-GUIDE.md                  # Operations guide for administrators
│   ├── CERTIFICATE-RENEWAL-USER-GUIDE.md   # End-user certificate renewal
│   └── TROUBLESHOOTING.md                  # Common issues and solutions
│
├── scripts/                                 # Enhanced installation scripts
│   ├── installTAK-LXD-enhanced.sh          # Main installation script
│   ├── preflight-check.sh                  # Pre-installation validation
│   └── utils/
│       ├── certificate-helper.sh           # Multi-device cert management
│       └── renewal-automation.sh           # Certificate renewal automation
│
├── examples/                                # Configuration examples
│   ├── haproxy-multi-service.cfg           # Complete HAProxy config
│   ├── haproxy-tak-only.cfg                # TAK Server only config
│   ├── lxd-profile.yaml                    # LXD container profile
│   └── firewall-rules.txt                  # UFW/iptables examples
│
├── archive/                                 # Historical learning documents
│   └── original-learning-docs/             # Early deployment attempts
│
├── env.template                             # Configuration template
├── README.md                                # This file
├── CHANGELOG.md                             # Version history
└── LICENSE
```

---

## 🎓 Learning Path

### New to TAK Server?
1. Start with [TAK.gov documentation](https://tak.gov)
2. Join the [TAK Syndicate](https://tak.gov/community) community
3. Read myTeckNet's [TAK Server guides](https://mytecknet.com/tag/tak/)

### New to LXD?
1. [LXD Getting Started](https://documentation.ubuntu.com/lxd/en/latest/tutorial/first_steps/)
2. [LXD Container Basics](https://ubuntu.com/tutorials/introduction-to-lxd-projects)

### Deployment Order
**First deployment?** Follow the manual guides in `docs/` to understand each component. This will save you hours of troubleshooting later.

**Experienced?** Use the enhanced installation script with preflight checks for faster deployment.

---

## 🔧 Critical Lessons Learned

### 1. Nginx Required for Let's Encrypt (Phase 5B)

**Problem:** Let's Encrypt verification fails with "unauthorized" or "503" errors.

**Root Cause:** 
- HAProxy routes ACME challenges to TAK container port 80
- No web server exists there to handle challenges
- Firewall blocks port 80 by default

**Solution:**
```bash
# Install nginx in TAK container
apt install -y nginx

# Configure for ACME challenges only
# See docs/05B-LETSENCRYPT-SETUP.md for complete config

# CRITICAL: Allow port 80 in firewall
ufw allow 80/tcp
```

**Impact:** This was completely missing from original guides and caused 100% failure rate on Let's Encrypt setup.

### 2. Certificate Renewals and Mission Preservation

**CRITICAL:** Always use the **same username** when renewing certificates!

**Why:**
- TAK Server's Data Sync missions are tied to usernames
- Different username = user loses all mission subscriptions
- User must manually rejoin every mission (30+ missions = painful!)

**Correct Renewal:**
```bash
# User has certificate: CCFIRE780
# Expiring certificate: CCFIRE780.p12

# CORRECT - Same username
./makeCert.sh client CCFIRE780
# Result: New cert, missions preserved, 30-second disconnect

# WRONG - Different username
./makeCert.sh client CCFIRE780-new
# Result: All missions lost, must rejoin manually
```

See **[docs/04-CERTIFICATE-MANAGEMENT.md Step 7](docs/04-CERTIFICATE-MANAGEMENT.md)** for complete renewal procedures.

### 3. Multi-Device Certificate Naming

**Problem:** User has phone (ATAK) + laptop (WinTAK). How to manage certificates?

**Solution:** Device-specific suffixes

| Device | Certificate Name | Example |
|--------|-----------------|---------|
| ATAK (primary) | `[BASE]` | `CCFIRE780` |
| WinTAK | `[BASE]-wt` | `CCFIRE780-wt` |
| iTAK | `[BASE]-it` | `CCFIRE780-it` |
| TAKAware | `[BASE]-ta` | `CCFIRE780-ta` |
| Backup device | `[BASE]-bk` | `CCFIRE780-bk` |

**Benefits:**
- Revoke one device without affecting others
- Track which device user is on
- Security incident response (lost phone ≠ lost laptop access)

See **[docs/04-CERTIFICATE-MANAGEMENT.md Step 3](docs/04-CERTIFICATE-MANAGEMENT.md)** for complete naming convention.

### 4. Port Forward Conflicts

**Problem:** Can't add HAProxy port forwards - "address already in use"

**Cause:** Temporary port forwards added during testing (Phase 3-4) conflict with Phase 5 setup.

**Solution:**
```bash
# Remove temporary forwards
lxc config device remove tak port8443
lxc config device remove tak port80

# Then add HAProxy forwards
lxc config device add haproxy proxy-8443 proxy listen=tcp:0.0.0.0:8443 connect=tcp:127.0.0.1:8443
```

**Best Practice:** Don't add temporary forwards. Follow phases in order. Test locally inside containers during Phase 3-4.

### 5. TAK Server Always Restart After Certificate Changes

**This cannot be emphasized enough!**

TAK Server loads certificates into memory at startup. Changes to certificate files are **NOT** picked up until restart.

```bash
# After ANY certificate operation:
systemctl restart takserver

# Wait for full restart
sleep 60

# Verify it's running
systemctl status takserver

# Check for errors
tail -100 /opt/tak/logs/takserver-messaging.log | grep -i error
```

**When to restart:**
- ✅ Creating new server certificate
- ✅ Regenerating CAs
- ✅ Installing Let's Encrypt certificates
- ✅ Updating truststore
- ✅ Changing CoreConfig.xml certificate settings

This is the #1 cause of "SSL handshake failure" issues.

### 6. HAProxy Stats Access via SSH Tunnel

**Problem:** Want to access HAProxy stats page securely without exposing to internet.

**Solution:** SSH tunnel (works with CGNAT!)

**Windows (PowerShell/CMD):**
```cmd
ssh -L 8404:localhost:8404 username@vps-ip
```

**Then browser:** `http://localhost:8404/haproxy_stats`

**Benefits:**
- No firewall changes needed
- Works from anywhere (including CGNAT networks)
- Most secure option for production

See **[docs/05-NETWORKING.md Step 3A.5](docs/05-NETWORKING.md)** for complete access methods.

### 7. HAProxy for TAK Requires TCP Passthrough

**Critical:** HAProxy must use TCP mode, NOT HTTP mode, for TAK Server ports.

**Why:**
- TAK Server uses mutual TLS authentication
- Client and server verify each other's certificates
- SSL termination at HAProxy breaks this

**Correct Configuration:**
```haproxy
frontend tak-client
    bind *:8089
    mode tcp              # Critical - not http
    option ssl-hello-chk  # Check SSL handshake
    default_backend tak-client-backend
```

**Wrong Configuration:**
```haproxy
frontend tak-client
    bind *:8089
    mode http            # Wrong - breaks mutual TLS
    # SSL termination
```

See **[docs/05-NETWORKING.md Step 3](docs/05-NETWORKING.md)** for complete HAProxy configuration.

---

## 📦 Production Deployment: Real-World Example

**Organization:** Clear Creek Volunteer Fire Department / Boise County Sheriff's Office  
**Location:** Rural Idaho (CGNAT network)  
**Date:** November 2025  
**Status:** ✅ Production deployment successful

**Infrastructure:**
- **VPS:** SSDNodes (2 vCPU, 4GB RAM, 80GB storage)
- **OS:** Ubuntu 22.04 LTS
- **TAK Server:** 5.5-RELEASE-58-HEAD
- **Containers:** TAK Server, HAProxy, web services
- **SSL:** Let's Encrypt certificates
- **Clients:** ATAK (Android), WinTAK (Windows laptops)

**Architecture:**
```
Internet
    ↓
VPS Host (Ubuntu 22.04)
    ├─ HAProxy Container
    │   ├─ Port 80/443 → Web services (SNI routing)
    │   ├─ Port 8089 → TAK client connections (TCP passthrough)
    │   ├─ Port 8443 → TAK web UI (TCP passthrough)
    │   └─ Port 8446 → Certificate enrollment (TCP passthrough)
    │
    └─ TAK Server Container
        ├─ TAK Server 5.5
        ├─ PostgreSQL
        ├─ Nginx (ACME challenges)
        └─ Let's Encrypt certs
```

**Users:**
- Fire Department: 15 personnel with multi-device certificates
- Sheriff's Office: 8 deputies with patrol vehicle WinTAK + handheld ATAK
- Training users: 5 training devices for new personnel

**Certificate Naming:**
- `CCFIRE780` (Fire Chief - ATAK)
- `CCFIRE780-wt` (Fire Chief - WinTAK command vehicle)
- `BCSO2240` (Deputy - ATAK tablet)
- `BCSO2240-wt` (Deputy - patrol vehicle WinTAK)

**Lessons Learned:** All captured in this repository's documentation.

---

## 🤝 Contributing

Found a bug? Have a better way? Contributions welcome!

1. Fork this repo
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Document your changes thoroughly
4. Test in clean LXD environment
5. Submit a pull request

**Particularly Interested In:**
- Tested configurations for other VPS providers
- Certificate automation improvements
- Multi-agency federation setups
- Troubleshooting scenarios and solutions
- Integration with other emergency services tools
- Mission management best practices

**Documentation Contributions:**
- Real-world deployment stories
- Additional troubleshooting scenarios
- HAProxy configurations for specific use cases
- Certificate management strategies

---

## 📝 Use Cases

This deployment method has been successfully used by:
- ✅ Volunteer fire departments (rural communications, CGNAT environments)
- ✅ Search and rescue teams (offline coordination, multi-agency ops)
- ✅ Emergency management agencies (multi-agency operations, federation)
- ✅ Training environments (student/practice servers)
- ✅ Multi-agency partnerships (fire + sheriff + EMS coordination)

**Running TAK for public safety?** Share your story! Open an issue or discussion.

---

## ⚠️ Important Notes

### Security Considerations
- LXD containers provide isolation but are NOT a complete security boundary
- Always use strong passwords and SSH keys
- Keep TAK Server updated with patches from TAK.gov
- Review [TAK Server hardening guide](https://tak.gov/docs)
- Regularly audit certificate inventory
- Implement certificate renewal procedures
- Test backup and disaster recovery plans

### Certificate Best Practices
- Use multi-device naming convention for users with multiple devices
- Always use same username when renewing certificates (preserves missions)
- Maintain certificate inventory spreadsheet
- Set up 90-day renewal reminders
- Document lost/stolen device procedures
- Regular certificate audits (monthly/quarterly)

### Licensing
- **This repo**: [Your chosen license]
- **Original installTAK**: [Original license from myTeckNet]
- **TAK Server**: Licensed by TAK Product Center - see TAK.gov
- **TAK Server files are NOT redistributable** - users must download from TAK.gov

### Support
- **This repo issues**: LXD deployment, documentation, installation questions
- **TAK Server issues**: Use [TAK.gov support channels](https://tak.gov/community)
- **Original installTAK**: Reference [myTeckNet's repo](https://github.com/myTeckNet/installTAK)
- **Emergency**: See [TAK-ADMIN-GUIDE.md](docs/TAK-ADMIN-GUIDE.md) for emergency procedures

---

## 📚 Additional Resources

### Official Documentation
- **TAK Server Documentation**: https://tak.gov/docs
- **TAK Product Center**: https://tak.gov
- **TAK Community Forums**: https://tak.gov/community
- **LXD Documentation**: https://documentation.ubuntu.com/lxd

### Community Resources
- **myTeckNet Blog**: https://mytecknet.com
- **CivTAK**: https://civtak.org
- **TAK Discord**: Join via TAK.gov community page

### Related Projects
- **Original installTAK**: https://github.com/myTeckNet/installTAK
- **TAK Server Docker**: Various community projects
- **ATAK Plugins**: TAK.gov plugin repository

### Tools
- **ATAK**: Android Team Awareness Kit - https://tak.gov
- **WinTAK**: Windows Team Awareness Kit - https://tak.gov
- **iTAK**: iOS Team Awareness Kit - https://tak.gov
- **HAProxy**: http://www.haproxy.org
- **Let's Encrypt**: https://letsencrypt.org

---

## 🙏 Credits & Attribution

### Original Work
This project builds upon the **excellent** foundation created by:

**[installTAK](https://github.com/myTeckNet/installTAK)** by [JR @ myTeckNet](https://mytecknet.com)
- Universal TAK Server installation automation
- Multi-OS support (Rocky Linux, RHEL, Ubuntu, Debian)
- Certificate generation wizards
- Let's Encrypt integration
- Comprehensive troubleshooting

**Key Differences in This Fork:**
- **Focus**: LXD container deployments (not bare metal)
- **Target OS**: Ubuntu 22.04/24.04 LTS exclusively
- **Use Case**: VPS cloud environments for emergency services
- **Additions**: 
  - Container-specific networking and troubleshooting
  - Multi-device certificate naming conventions
  - HAProxy multi-service reverse proxy configurations
  - Let's Encrypt with nginx ACME handler
  - Mission preservation during certificate renewal
  - Emergency services-specific operations guides
  - Production-tested deployment procedures

### Community Resources
- **[TAK Product Center](https://tak.gov)** - Official TAK Server releases
- **[TAK Syndicate](https://tak.gov/community)** - Community forums and support
- **[CivTAK](https://civtak.org)** - Public safety TAK implementations
- **[myTeckNet TAK Guides](https://mytecknet.com/tag/tak/)** - Comprehensive TAK tutorials

### Testing & Validation
- **Clear Creek Volunteer Fire Department** - Production deployment
- **Boise County Sheriff's Office** - Multi-agency testing
- Community members who provided feedback and bug reports

---

## 📧 Contact

**Maintainer**: Mike (mighkel)  
**GitHub**: [@mighkel](https://github.com/mighkel)  
**Organization**: Clear Creek Volunteer Fire Department  
**Role**: BIM Manager / Tactical Communications Officer  
**Location**: Rural Idaho (Boise County)

**For deployment assistance:**
- Open an issue for bugs or documentation problems
- Start a discussion for general questions
- Review existing issues/discussions before creating new ones

---

## 📋 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Current Version:** 2.5.2 (November 2025)
- ✅ Complete nginx setup for Let's Encrypt ACME challenges
- ✅ Multi-device certificate naming convention
- ✅ Mission preservation guidance for certificate renewal
- ✅ HAProxy stats access via SSH tunnel
- ✅ CGNAT considerations and solutions
- ✅ Common pitfalls section
- ✅ Production deployment validation
- ✅ TAK Server Administration Guide
- ✅ Certificate Renewal User Guide

---

*Last Updated: November 24, 2025*  
*TAK Server Version: 5.5-RELEASE-58*  
*Tested on: Ubuntu 22.04 LTS, 24.04 LTS*  
*Production Status: Deployed and operational*
