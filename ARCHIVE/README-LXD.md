# installTAK for LXD Containers

Enhanced version of installTAK with LXD container support. Automatically handles common container deployment issues.

## What's Different?

This fork adds LXD-specific enhancements:
- ✅ Pre-flight networking verification
- ✅ Automatic PostgreSQL initialization fixes
- ✅ Post-install TAK Server verification
- ✅ Automatic enrollment package creation
- ✅ Better error messages for container issues

## Quick Start (LXD Container)

### Prerequisites

1. **LXD container running Ubuntu 22.04 LTS**
2. **Container has internet access** (see troubleshooting if not)
3. **8GB+ RAM** allocated to container
4. **TAK Server .deb file** downloaded from https://tak.gov

### Installation Steps
```bash
# 1. Enter your LXD container
lxc exec tak -- bash

# 2. Upload files to container (from host)
# Place installTAK, takserver.deb, takserver-public-gpg.key, deb_policy.pol in /root/

# 3. Make installer executable
chmod +x /root/installTAK

# 4. Run with LXD mode enabled (IMPORTANT: note the extra 'true' argument)
cd /root
./installTAK takserver_5.5-RELEASE58_all.deb false true
#                                           ↑     ↑
#                                         FIPS  LXD-mode
```

### What Happens in LXD Mode

**Before installation:**
- Verifies internet connectivity
- Verifies DNS resolution
- Provides helpful error messages if networking is broken

**During installation:**
- Monitors PostgreSQL initialization
- Automatically fixes common PostgreSQL issues in containers
- Creates database and user with proper permissions

**After installation:**
- Verifies TAK Server actually started
- Checks logs for successful startup
- Creates default enrollment package automatically
- Displays summary with certificate locations

### Output Files

After successful installation, find these in `/root/`:
- `webadmin.p12` - Import into browser to access TAK Server web UI
- `enrollment-default.zip` - Distribute to ATAK users for easy setup
- Logs at `/opt/tak/logs/takserver-messaging.log`

## Usage

### Standard Install (Bare Metal/VM)
```bash
./installTAK takserver.deb
```

### LXD Container Install
```bash
./installTAK takserver.deb false true
```

### FIPS Mode + LXD
```bash
./installTAK takserver.deb true true
```

## Troubleshooting

### Container Has No Internet Access

**Symptoms:**
```
LXD Mode: Verifying container networking...
ERROR: No internet connectivity detected
```

**Fix:**
See [Container Networking Guide](docs/LXD-DEPLOYMENT-GUIDE.md#troubleshooting-container-networking-issues)

Quick fix from host:
```bash
# Allow container traffic through host firewall
sudo iptables -I FORWARD -i lxdbr0 -j ACCEPT
sudo iptables -I FORWARD -o lxdbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### PostgreSQL Won't Start

The LXD mode automatically handles this, but if you see PostgreSQL errors:
```bash
# The script will automatically:
# 1. Create /var/lib/postgresql/15/main
# 2. Initialize the cluster
# 3. Start PostgreSQL
# 4. Verify it's listening on port 5432
```

### TAK Server Won't Start

Check the verification output:
```bash
tail -f /opt/tak/logs/takserver-messaging.log
```

Look for:
- `Started TAK Server messaging Microservice` ✅
- Database connection errors ❌
- Certificate errors ❌

## Differences from Original installTAK

| Feature | Original | LXD Enhanced |
|---------|----------|--------------|
| Container networking check | ❌ | ✅ |
| PostgreSQL auto-fix | ❌ | ✅ |
| Post-install verification | ❌ | ✅ |
| Auto-enrollment package | ❌ | ✅ |
| Container-specific errors | ❌ | ✅ |
| Bare metal support | ✅ | ✅ (unchanged) |

## Full Deployment Guide

For complete VPS + LXD + HAProxy + TAK Server setup, see:
- [Complete LXD Deployment Guide](docs/LXD-DEPLOYMENT-GUIDE.md)

This covers:
- VPS provisioning and hardening
- LXD container networking setup
- HAProxy reverse proxy configuration
- Let's Encrypt certificate integration
- Multi-container architecture

## Credits

- **Original installTAK:** [myTeckNet/installTAK](https://github.com/myTeckNet/installTAK)
- **LXD Enhancements:** Added for container deployment use cases
- **Maintained by:** [Your GitHub Username]

## Contributing

Found a bug? Have a suggestion? Open an issue or PR!

## License

Same as original installTAK repository.
