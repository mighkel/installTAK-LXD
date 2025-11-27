# installTAK-LXD

**TAK Server deployment guide for LXD containers on Ubuntu VPS systems**

Comprehensive documentation for deploying TAK Server in containerized environments on cloud VPS platforms.

![TAK Server Version](https://img.shields.io/badge/TAK%20Server-5.5-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04%20LTS-orange)
![LXD](https://img.shields.io/badge/LXD-Container-green)
![Status](https://img.shields.io/badge/Status-Production%20Tested-success)

---

## 🎯 What This Does

This project provides comprehensive documentation for deploying **TAK Server** (Team Awareness Kit) in **LXD containers** on cloud VPS systems. Whether you're setting up situational awareness for a team, organization, or personal use, these guides walk you through the complete process.

**Key Features:**

- ✅ LXD container isolation for security, expansion, and easy snapshots
- ✅ Step-by-step guides with clear context indicators (VPS host vs. container)
- ✅ HAProxy reverse proxy for multi-service hosting
- ✅ Let's Encrypt SSL certificate integration for smooth auto-enrollment
- ✅ Certificate management with multi-device support
- ✅ Production-tested deployment

---

## 📋 Prerequisites

### What You Need

- **VPS**: 2+ vCPU, 4GB+ RAM, 80GB+ storage
- **OS**: Ubuntu 22.04 or 24.04 LTS (minimal installation)
- **Domain**: Registered domain name with DNS access (e.g., `tak.yourdomain.com`)
- **TAK Files**: Access to [TAK.gov](https://tak.gov/products/tak-server) downloads:
  - `takserver-5.5-RELEASE[##]_all.deb`
  - `takserver-public-gpg.key`
  - `deb_policy.pol`

### VPS Providers

- ✅ **SSDNodes** - Primary testing platform
- ✅ **DigitalOcean** - Should work with minimal adaptation
- ⚠️ **Linode** - Not tested, standard Ubuntu VPS should work
- ⚠️ **AWS EC2** - Not tested; AWS networking may require additional configuration

---

## 🚀 Deployment Guide

Follow these guides in order for a complete TAK Server deployment:

### Phase 1: [LXD Setup](docs/01-LXD-SETUP.md)

Install and configure LXD on your Ubuntu VPS.

- System updates and user creation
- SSH key authentication setup
- LXD installation and initialization
- Firewall (UFW) configuration
- Network forwarding for containers

### Phase 2: [Container Setup](docs/02-CONTAINER-SETUP.md)

Create and configure the TAK Server container.

- Launch Ubuntu 22.04 container
- Install prerequisites (git, python3, gdown)
- Create takadmin user inside container
- Configure networking options (LXD proxy vs HAProxy)
- Create pre-installation snapshot

### Phase 3: [TAK Server Installation](docs/03-TAK-INSTALLATION.md)

Install TAK Server using the installTAK script.

- Download TAK Server files (Google Drive or manual transfer)
- Run installTAK installation wizard
- Configure certificates and enrollment
- Verify installation and ports
- Create post-installation snapshot

### Phase 4: [Certificate Management](docs/04-CERTIFICATE-MANAGEMENT.md)

Understand and manage TAK Server certificates.

- Certificate architecture (Root CA → Intermediate CA → Server/Client)
- Create client certificates manually
- Multi-device naming conventions
- Certificate renewal and revocation
- Troubleshooting SSL issues

### Phase 5: [Networking & Reverse Proxy](docs/05-NETWORKING.md)

Expose TAK Server to the internet securely.

- Choose networking method (LXD proxy device or HAProxy)
- Configure HAProxy for multi-service routing
- DNS configuration
- Let's Encrypt SSL certificates for auto-enrollment
- Automatic certificate renewal

### Phase 6: [Verification & Testing](docs/06-VERIFICATION.md)

Validate the complete deployment.

- Access TAK Server web UI
- Create user accounts
- Connect ATAK and WinTAK clients
- Test data sharing between clients
- Configure auto-start and monitoring
- Production readiness checklist

---

## 📂 Repository Structure

```
installTAK-LXD/
├── docs/                                    # Step-by-step documentation
│   ├── 01-LXD-SETUP.md                     # LXD installation and initialization
│   ├── 02-CONTAINER-SETUP.md               # Container creation and configuration
│   ├── 03-TAK-INSTALLATION.md              # TAK Server installation
│   ├── 04-CERTIFICATE-MANAGEMENT.md        # Certificate lifecycle management
│   ├── 05-NETWORKING.md                    # HAProxy, firewall, Let's Encrypt
│   ├── 06-VERIFICATION.md                  # Testing and validation
│   ├── LXD-CHEAT-SHEET.md                  # Quick reference for LXD commands
│   ├── SSH-KEY-SETUP.md                    # Detailed SSH key guide (Windows/Linux/Mac)
│   └── TAK-ADMIN-GUIDE.md                  # Day-to-day operations (coming soon)
│
├── scripts/                                 # Helper scripts
│   ├── preflight-check.sh                  # Pre-installation validation
│   └── (additional scripts planned)
│
├── examples/                                # Configuration examples
│   └── env.template                        # Environment configuration template
│
├── README.md                                # This file
├── CREDITS.md                               # Attribution and credits
└── LICENSE
```

---

## 📖 Document Conventions

All guides use consistent conventions to help you know where to run commands:

| Symbol | Meaning |
|--------|---------|
| 💻 | **Local Machine** - Your Windows/Mac/Linux workstation |
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside containers) |
| 📦 | **Inside Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - Replace placeholder values |
| 💡 | **Tip** - Helpful information |
| ⛔ | **Critical** - Important warning |

**Placeholder Format:**

Throughout the documentation, placeholders appear as `[YOUR_VALUE]`. Replace the brackets AND the text inside with your actual value:

- `[YOUR_DOMAIN]` → `tak.example.com`
- `[YOUR_VPS_IP]` → `203.0.113.50`
- `[CONTAINER_IP]` → `10.x.x.11`

---

## 🔧 Key Lessons Learned

### Always Restart TAK Server After Certificate Changes

```bash
# Inside TAK container
sudo systemctl restart takserver
sleep 30
sudo systemctl status takserver
```

Certificate changes, CoreConfig.xml updates, and initial installation often don't fully apply until restart. This is the #1 cause of "SSL handshake failure" issues.

### HAProxy for TAK Requires TCP Passthrough

TAK Server uses mutual TLS (client certificates). HAProxy must pass through raw TCP traffic, not terminate SSL:

```haproxy
frontend tak-client
    bind *:8089
    mode tcp                    # NOT mode http
    option ssl-hello-chk
    default_backend tak-client-backend
```

### Let's Encrypt Requires Nginx in TAK Container

HAProxy routes ACME challenges to the TAK container on port 80. You need a web server there to respond:

```bash
# Inside TAK container
apt install -y nginx
ufw allow 80/tcp
```

See Phase 5 documentation for complete configuration.

### Test at Each Phase

Each guide includes verification steps. Don't skip them! It's much easier to troubleshoot issues at the phase where they occur than to backtrack from Phase 6.

---

## 🙏 Credits & Attribution

### Original Work

This project builds upon the excellent foundation created by:

**[installTAK](https://github.com/myTeckNet/installTAK)** by **JR @ [myTeckNet](https://mytecknet.com)**

- Universal TAK Server installation automation
- Multi-OS support (Rocky Linux, RHEL, Ubuntu, Debian, Raspberry Pi)
- Certificate generation and management
- Let's Encrypt integration

**What This Project Adds:**

- LXD container deployment focus (Ubuntu systems)
- VPS cloud environment optimization
- Container-specific networking
- Comprehensive step-by-step documentation
- Google Drive / NextCloud integration for file distribution

### Community Resources

- **[TAK Product Center](https://tak.gov)** - Official TAK Server releases and documentation
- **[myTeckNet Blog](https://mytecknet.com)** - TAK Server tutorials and troubleshooting
- **[TheTAKSyndicate](https://thetaksyndicate.org)** - TAK resources with a public safety focus
- **[ATAK Community Discord](https://discord.gg/xTdEcpc)** - Community support
- **[ATAK Reddit](https://www.reddit.com/r/ATAK/)** - Community discussions

See [CREDITS.md](CREDITS.md) for complete attribution.

---

## 🤝 Contributing

Found a bug? Have a better approach? Contributions welcome!

1. Fork this repo
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Document your changes clearly
4. Submit a pull request

**Particularly Interested In:**

- Tested configurations for additional VPS providers
- Troubleshooting scenarios and solutions
- Improvements to documentation clarity

---

## ⚠️ Important Notes

### Security Considerations

- LXD containers provide isolation but are not a strict security boundary
- Always use strong passwords and SSH keys
- Keep TAK Server updated with patches from TAK.gov
- Change default certificate password (`atakatak`) for production deployments
- Protect your Root CA private key (`ca-do-not-share.key`)

### Licensing

- **This repository**: MIT License (see LICENSE file)
- **Original installTAK**: See [myTeckNet's repository](https://github.com/myTeckNet/installTAK)
- **TAK Server**: Licensed by TAK Product Center - see [TAK.gov](https://tak.gov)

---

## 📚 Additional Resources

- **TAK Server**: https://tak.gov/products/tak-server
- **LXD Documentation**: https://documentation.ubuntu.com/lxd
- **HAProxy**: https://www.haproxy.org
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **PostgreSQL**: https://www.postgresql.org
- **Ubuntu**: https://ubuntu.com

---

*Last Updated: November 2025*  
*TAK Server Version: 5.5*  
*Tested on: Ubuntu 22.04 LTS, 24.04 LTS*
