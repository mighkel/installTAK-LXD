# LXD Container Enhancements for installTAK

This document describes enhancements to installTAK.sh for LXD container deployments.

## Enhancement Overview

### New Features
1. **Pre-flight container networking verification**
2. **PostgreSQL initialization verification** 
3. **Post-install TAK Server verification**
4. **Automatic enrollment package creation**
5. **LXD mode flag** (`--lxd-mode`)

### Implementation Approach
- **Backward compatible** - existing installs unchanged
- **Opt-in** - activate with `--lxd-mode` flag
- **Three new functions** inserted at strategic points
- **Minimal changes** to existing code

## Code Additions

### 1. Add LXD Mode Detection (After line 4, in global variables section)
```bash
#globalVariables
lxdMode=${3:-false}  # Third argument: --lxd-mode
```

### 2. Add New Function: verifyContainerNetworking() (After line 29, before prerequisite())
```bash
#::::::::::
# LXD Container Networking Verification
#::::::::::
verifyContainerNetworking(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying container networking...${NC}" 2>&1 | tee -a $logfile
        
        # Check internet connectivity
        if ! ping -c 2 8.8.8.8 > /dev/null 2>&1; then
            ERRoR="No internet connectivity detected. Container networking may not be configured.\nSee deployment guide section 5.3b for troubleshooting."
            abort
        fi
        
        # Check DNS resolution
        if ! nslookup archive.ubuntu.com > /dev/null 2>&1; then
            ERRoR="DNS resolution failing. Check /etc/resolv.conf in container."
            abort
        fi
        
        echo -e "${GREEN}✓ Container networking verified${NC}" 2>&1 | tee -a $logfile
    fi
}
```

### 3. Add New Function: verifyPostgreSQL() (After prerequisite(), before Install())
```bash
#::::::::::
# PostgreSQL Verification for Containers
#::::::::::
verifyPostgreSQL(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying PostgreSQL initialization...${NC}" 2>&1 | tee -a $logfile
        
        # Wait for PostgreSQL to start
        sleep 5
        
        # Check if PostgreSQL is listening
        if ! ss -tulpn | grep -q ":5432"; then
            echo -e "${YELLOW}PostgreSQL not listening on port 5432, attempting initialization...${NC}" 2>&1 | tee -a $logfile
            
            # Check if data directory exists
            if [ ! -d "/var/lib/postgresql/15/main" ]; then
                echo -e "${YELLOW}Creating PostgreSQL data directory...${NC}" 2>&1 | tee -a $logfile
                mkdir -p /var/lib/postgresql/15/main
                chown -R postgres:postgres /var/lib/postgresql
                sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main 2>&1 | tee -a $logfile
            fi
            
            # Start PostgreSQL cluster
            pg_ctlcluster 15 main start 2>&1 | tee -a $logfile
            sleep 3
            
            # Verify it's now running
            if ! ss -tulpn | grep -q ":5432"; then
                ERRoR="PostgreSQL failed to start. Check logs at /var/log/postgresql/"
                abort
            fi
        fi
        
        echo -e "${GREEN}✓ PostgreSQL verified and running${NC}" 2>&1 | tee -a $logfile
    fi
}
```

### 4. Add New Function: postInstallVerification() (After executeConfiguration())
```bash
#::::::::::
# Post-Install Verification
#::::::::::
postInstallVerification(){
    if [[ $lxdMode == "true" ]]; then
        echo -e "${YELLOW}LXD Mode: Verifying TAK Server installation...${NC}" 2>&1 | tee -a $logfile
        
        # Wait for TAK to start
        sleep 15
        
        # Check if takserver is running
        if systemctl is-active --quiet takserver; then
            echo -e "${GREEN}✓ TAK Server service is running${NC}" 2>&1 | tee -a $logfile
            
            # Check logs for successful startup
            if tail -n 50 /opt/tak/logs/takserver-messaging.log | grep -q "Started TAK Server"; then
                echo -e "${GREEN}✓ TAK Server started successfully${NC}" 2>&1 | tee -a $logfile
            else
                echo -e "${YELLOW}⚠ TAK Server running but startup incomplete${NC}" 2>&1 | tee -a $logfile
                echo -e "${YELLOW}Check logs: tail -f /opt/tak/logs/takserver-messaging.log${NC}" 2>&1 | tee -a $logfile
            fi
            
            # Create enrollment package
            echo -e "${YELLOW}Creating default enrollment package...${NC}" 2>&1 | tee -a $logfile
            cd /opt/tak/certs
            ./makeCert.sh client defaultuser 2>&1 | tee -a $logfile
            cd files
            zip -q /root/enrollment-default.zip defaultuser.p12 truststore-root.p12
            echo -e "${GREEN}✓ Enrollment package created: /root/enrollment-default.zip${NC}" 2>&1 | tee -a $logfile
            
        else
            ERRoR="TAK Server failed to start. Check logs at /opt/tak/logs/takserver-messaging.log"
            abort
        fi
        
        echo -e "${GREEN}================================${NC}" 2>&1 | tee -a $logfile
        echo -e "${GREEN}TAK Server Installation Complete${NC}" 2>&1 | tee -a $logfile
        echo -e "${GREEN}================================${NC}" 2>&1 | tee -a $logfile
        echo -e "Web Admin: https://$(hostname -f):8443" 2>&1 | tee -a $logfile
        echo -e "Admin Certificate: /root/webadmin.p12" 2>&1 | tee -a $logfile
        echo -e "Enrollment Package: /root/enrollment-default.zip" 2>&1 | tee -a $logfile
    fi
}
```

### 5. Modify Main Execution Flow (Around line 1645)

Find the section that says `# Execute Script` and modify to add our function calls:

**BEFORE (original):**
```bash
# Execute Script
splash
```

**AFTER (enhanced):**
```bash
# Execute Script
verifyContainerNetworking  # NEW: LXD pre-flight check
splash
```

Then find where `Install()` is called and add after PostgreSQL installation.

### 6. Add Help Text for LXD Mode

Find the beginning of the script (around line 1-10) and add usage documentation:
```bash
#!/bin/bash
#Version 2.4-LXD
#JR@myTeckNet + LXD enhancements
#
# Usage: 
#   Normal install: ./installTAK.sh <takserver.deb>
#   LXD container:  ./installTAK.sh <takserver.deb> false true
#
# Arguments:
#   $1: Path to TAK Server .deb file
#   $2: FIPS mode (true/false) - default: false  
#   $3: LXD mode (true/false) - default: false
#
```

## Testing Plan

1. Test in LXD container with `--lxd-mode true`
2. Test on bare metal without flag (ensure backward compatibility)
3. Test network failure scenarios
4. Test PostgreSQL initialization edge cases

## Files to Modify

- `installTAK.sh` - Add all enhancements above

## Files to Create

- `docs/LXD-ENHANCEMENTS.md` - This file
- `docs/LXD-DEPLOYMENT-GUIDE.md` - Your full deployment guide
- `README-LXD.md` - Quick start for LXD users
