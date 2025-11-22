# installTAK-LXD

**TAK Server deployment automation for LXD containers on Ubuntu VPS systems**

Optimized for emergency services, volunteer fire departments, and public safety organizations running TAK Server in containerized environments.

![TAK Server Version](https://img.shields.io/badge/TAK%20Server-5.5-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04%20LTS-orange)
![LXD](https://img.shields.io/badge/LXD-Container-green)

---

## 🎯 What This Does

This project provides documentation and scripts for deploying **TAK Server** (Team Awareness Kit) in **LXD containers** on cloud VPS systems. Perfect for organizations that need tactical situational awareness without the complexity of bare-metal server management.

**Key Features:**
- ✅ LXD container isolation for security and easy snapshots
- ✅ Automated certificate generation with proper hostname support
- ✅ PostgreSQL initialization and health checks
- ✅ Google Drive / NextCloud integration for TAK file management
- ✅ HAProxy reverse proxy support for multi-service hosting
- ✅ Tested on SSDNodes, Linode, DigitalOcean VPS platforms

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

### Phase 1: Manual Setup (Recommended First Time)

**Follow the documentation to understand each step:**

1. **[LXD Setup Guide](docs/01-LXD-SETUP.md)** - Install and configure LXD on your VPS
2. **[Container Creation](docs/02-CONTAINER-SETUP.md)** - Create and configure the TAK container
3. **[TAK Server Installation](docs/03-TAK-INSTALLATION.md)** - Install TAK Server using installTAK
4. **[Certificate Management](docs/04-CERTIFICATE-MANAGEMENT.md)** - Generate and manage certificates
5. **[Networking & HAProxy](docs/05-NETWORKING.md)** - Set up reverse proxy and port forwarding
6. **[Verification & Testing](docs/06-VERIFICATION.md)** - Test ATAK client connections

### Phase 2: Automated Deployment (Coming Soon)

Once you understand the manual process, use the automated scripts:
```bash
# Clone the repo
git clone https://github.com/mighkel/installTAK-LXD.git
cd installTAK-LXD

# Copy and configure environment
cp env.template .env
nano .env  # Add your settings

# Run automated deployment
./scripts/deploy-lxd-tak.sh
```

---

## 📂 Repository Structure
```
installTAK-LXD/
├── docs/                          # Step-by-step documentation
│   ├── 01-LXD-SETUP.md           # LXD installation and init
│   ├── 02-CONTAINER-SETUP.md     # Container creation
│   ├── 03-TAK-INSTALLATION.md    # TAK Server install
│   ├── 04-CERTIFICATE-MANAGEMENT.md
│   ├── 05-NETWORKING.md          # HAProxy, firewall, DNS
│   ├── 06-VERIFICATION.md        # Testing and troubleshooting
│   └── TROUBLESHOOTING.md        # Common issues and solutions
│
├── scripts/                       # Automation scripts (future)
│   ├── deploy-lxd-tak.sh         # Main deployment script
│   └── utils/
│       ├── fetch-tak-files.sh    # Google Drive / NextCloud fetch
│       └── certificate-helper.sh # Cert generation helpers
│
├── examples/                      # Configuration examples
│   ├── haproxy.cfg               # Sample HAProxy config
│   ├── lxd-profile.yaml          # LXD container profile
│   └── firewall-rules.txt        # UFW/iptables examples
│
├── archive/                       # Historical learning documents
│   └── original-learning-docs/   # Early deployment attempts
│
├── env.template                   # Configuration template
├── README.md                      # This file
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

**Experienced?** Jump to the automated scripts (when available).

---

## 🔧 Key Lessons Learned

### Critical Steps That Often Get Missed

1. **ALWAYS restart TAK Server after certificate changes:**
```bash
   systemctl restart takserver
   sleep 30  # Give it time to reload
   systemctl status takserver
```

2. **Test certificates before enrollment:**
```bash
   openssl s_client -connect tak.yourdomain.com:8089 -showcerts
```

3. **Verify networking at each layer:**
   - Container can reach internet: `lxc exec tak -- ping -c 3 1.1.1.1`
   - Host can reach container: `lxc list` → test IP
   - External can reach host: Test from another machine

4. **HAProxy for TAK requires TCP passthrough, NOT SSL termination:**
```
   mode tcp
   option ssl-hello-chk
```

---

## 📦 File Distribution Methods

### Option 1: Google Drive (gdown)
Store your TAK Server files in Google Drive and fetch them automatically:
```bash
# Install gdown
pip3 install gdown

# Fetch files using shareable link IDs
gdown YOUR-FILE-ID -O takserver.deb
gdown YOUR-KEY-ID -O takserver-public-gpg.key
```

**Setup Instructions:** See [docs/FILE-DISTRIBUTION.md](docs/FILE-DISTRIBUTION.md)

### Option 2: NextCloud (WebDAV)
Self-host your TAK files on NextCloud:
```bash
curl -u "user:password" \
  "https://files.yourdomain.com/remote.php/dav/files/user/TAK/takserver.deb" \
  -o takserver.deb
```

**Why not GitHub?** TAK Server files from TAK.gov are **not redistributable** under their license. Private hosting (Google Drive, NextCloud) with controlled access is the legal approach.

---

## 🙏 Credits & Attribution

### Original Work
This project builds upon the **excellent** foundation created by:

**[installTAK](https://github.com/myTeckNet/installTAK)** by [JR @ myTeckNet](https://mytecknet.com)
- Universal TAK Server installation automation
- Multi-OS support (Rocky Linux, RHEL, Ubuntu, Debian)
- Certificate generation wizards
- Let's Encrypt integration

**Key Differences in This Fork:**
- **Focus**: LXD container deployments (not bare metal)
- **Target OS**: Ubuntu 22.04/24.04 LTS exclusively
- **Use Case**: VPS cloud environments for emergency services
- **Additions**: Container-specific networking, PostgreSQL fixes, deployment automation

### Community Resources
- **[TAK Product Center](https://tak.gov)** - Official TAK Server releases
- **[TAK Syndicate](https://tak.gov/community)** - Community forums and support
- **[CivTAK](https://civtak.org)** - Public safety TAK implementations
- **[myTeckNet TAK Guides](https://mytecknet.com/tag/tak/)** - Comprehensive TAK tutorials

---

## 🤝 Contributing

Found a bug? Have a better way? Contributions welcome!

1. Fork this repo
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Document your changes
4. Submit a pull request

**Particularly Interested In:**
- Tested configurations for other VPS providers
- Certificate automation improvements
- Troubleshooting scenarios and solutions
- Integration with other emergency services tools

---

## 📝 Use Cases

This deployment method has been successfully used by:
- Volunteer fire departments (rural communications)
- Search and rescue teams (offline coordination)
- Emergency management agencies (multi-agency operations)
- Training environments (student/practice servers)

**Running TAK for public safety?** Share your story! Open an issue or discussion.

---

## ⚠️ Important Notes

### Security Considerations
- LXD containers provide isolation but are NOT a security boundary
- Always use strong passwords and SSH keys
- Keep TAK Server updated with patches from TAK.gov
- Review [TAK Server hardening guide](https://tak.gov/docs)

### Licensing
- **This repo**: [Your chosen license]
- **Original installTAK**: [Original license from myTeckNet]
- **TAK Server**: Licensed by TAK Product Center - see TAK.gov

### Support
- **This repo issues**: Installation questions, LXD-specific problems
- **TAK Server issues**: Use [TAK.gov support channels](https://tak.gov/community)
- **Original installTAK**: Reference [myTeckNet's repo](https://github.com/myTeckNet/installTAK)

---

## 📚 Additional Resources

- **TAK Server Documentation**: https://tak.gov/docs
- **LXD Documentation**: https://documentation.ubuntu.com/lxd
- **myTeckNet Blog**: https://mytecknet.com
- **TAK Discord**: Join via TAK.gov community page

---

## 📧 Contact

**Maintainer**: Mike (mighkel)  
**GitHub**: [@mighkel](https://github.com/mighkel)  
**Use Case**: Clear Creek Volunteer Fire Department - Tactical Communications

---

*Last Updated: November 2025*  
*TAK Server Version: 5.5*  
*Tested on: Ubuntu 22.04 LTS, 24.04 LTS*
