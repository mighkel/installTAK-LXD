# Changelog

All notable changes to installTAK-LXD will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Automated deployment script with full error handling
- NextCloud integration for file distribution
- HAProxy automation for multi-service hosting
- Backup and restore scripts
- LXD snapshot management
- Monitoring and alerting integration

---

## [1.0.0] - 2025-11-22

### Added
- Initial release as independent project (forked from myTeckNet/installTAK)
- Comprehensive documentation for manual LXD deployment
- Step-by-step guides for each deployment phase:
  - LXD setup and initialization
  - Container creation and configuration
  - TAK Server installation via installTAK
  - Certificate management best practices
  - Networking and HAProxy setup
  - Verification and testing procedures
- Environment variable template (`.env.template`)
- Google Drive file fetching via gdown
- Example HAProxy configuration for TCP passthrough
- Troubleshooting guide with common issues
- Archive of historical learning documents

### Documentation
- `docs/01-LXD-SETUP.md` - LXD installation and initialization
- `docs/02-CONTAINER-SETUP.md` - Container creation guide
- `docs/03-TAK-INSTALLATION.md` - TAK Server installation
- `docs/04-CERTIFICATE-MANAGEMENT.md` - Certificate generation and renewal
- `docs/05-NETWORKING.md` - HAProxy and firewall configuration
- `docs/06-VERIFICATION.md` - Testing and validation
- `docs/TROUBLESHOOTING.md` - Common problems and solutions
- `docs/FILE-DISTRIBUTION.md` - Google Drive and NextCloud setup

### Examples
- `examples/haproxy.cfg` - HAProxy TCP passthrough configuration
- `examples/lxd-profile.yaml` - LXD container profile template
- `examples/firewall-rules.txt` - UFW and iptables examples

### Infrastructure
- `.gitignore` - Comprehensive exclusions for secrets and TAK files
- `env.template` - Configuration template for deployments
- `CREDITS.md` - Attribution to original work and community
- `LICENSE` - Project licensing
- `README.md` - Complete project overview and quick start

### Key Learnings Documented
- Critical importance of restarting TAK Server after certificate updates
- HAProxy must use TCP passthrough (not SSL termination) for TAK clients
- Container networking verification at each layer
- PostgreSQL initialization in LXD environments
- Certificate chain verification techniques

### Tested Platforms
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- SSDNodes VPS (primary testing)
- LXD 5.21+

---

## Version History Notes

### Pre-1.0.0 (Historical)
Development occurred as fork of myTeckNet/installTAK with experimental LXD modifications. These early attempts are preserved in `archive/original-learning-docs/` for reference:
- `tak_vps_lxd_deployment_guide.md` - Early deployment attempts
- `VPS-LXD-SETUP-NOTES-OLD.md` - Initial setup notes
- `LXD-INSTALL-DOCS/` - Command references and checklists

The project was separated from the fork on 2025-11-22 to allow independent development focused on LXD container deployments.

---

## Links

- [GitHub Repository](https://github.com/mighkel/installTAK-LXD)
- [Original installTAK](https://github.com/myTeckNet/installTAK)
- [TAK Product Center](https://tak.gov)
- [Issue Tracker](https://github.com/mighkel/installTAK-LXD/issues)

---

## Contributors

- **Mike (mighkel)** - LXD deployment automation and documentation
- **JR (myTeckNet)** - Original installTAK script foundation

See [CREDITS.md](CREDITS.md) for full attribution and community resources.
