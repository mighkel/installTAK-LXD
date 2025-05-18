# Change Log
*Admittedly I'm not the best at documenting changes officially - I accept that.  Let's start...*

I found this site as my guide: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) , and will attempt to follow this: [Semantic Versioning](https://semver.org/).

## [2.0.2] - 18MAY2025
### Changed 🔃 <!-- changes in existing functionality -->
- Updated MongoDB reference to v8.0
- Changed webadmin cert for TAK Server Federation Hub to webadmin-hub to ensure that the admin cert is not overwritten if TAK Server and FedHub are installed on the same system
- ### Depreciated 📦 <!-- soon-to-be removed features -->
- [Debian] Removed gnupg and updated to gnupg2
- [Debian] Removed MongoDB 7.0 References
### Fixed 🛠️ <!--  bug fixes -->
- Firewall does not apply QUIC settings when installing TAK Server 5.4
- [Debian] TAK Server already installed being bypassed because of copy-paste error
- [Docker] Fixed federation cert not being copied after installation
- CoreConfig regeneration on reinstallation

## [2.0.1] - 21APR2025
### Fixed 🛠️ <!--  bug fixes -->
- Fixed uuidgen Ubuntu dependencies.

## [2.0.0] - 21APR2025
### Added ➕ <!-- new features -->
- CHANGELOG to identify changes made to the project
- Added system memory checker to ensure system has 8GB RAM or higher
- TAK Server cleanup process to allow installTAK to be run on the same system without rebuilding [[Issue 9](https://github.com/myTeckNet/installTAK/issues/9)]
### Changed 🔃 <!-- changes in existing functionality -->
- Added TAK Server Federation Hub installation support for both DOCKER, RPM, and DEB [[Issue 8](https://github.com/myTeckNet/installTAK/issues/8)]
### Documentation📎
- updated README to include the Federation Hub text dialogs
### Depreciated 📦 <!-- soon-to-be removed features -->
- ufw soon to be replaced with firewalld to reduce additional dependencies
### Removed 🗑️ <!-- now removed features -->
- tak-server-systemd submodule as it is no longer needed since TAK Server 5.3 added takserver and takserver-noplugin services
### Fixed 🛠️ <!--  bug fixes -->
- Raspberry Pi 4/5 hangs on starting services due to timeouts [[Issue 3](https://github.com/myTeckNet/installTAK/issues/3)]
- Certificate Auto-Enrollment not being applied for DOCKER [[Issue 4](https://github.com/myTeckNet/installTAK/issues/4)]
- Federation not being applied for DOCKER
- Docker: Containers do not start automatically on system reboot [[Issue 7](https://github.com/myTeckNet/installTAK/issues/7)]
### Security 🔐 <!-- vulnerabilities -->
- Added dialogs to prompt for enable/disable WebTAK user and admin authentication
- Removed the takserver-db exposed port as it was not required