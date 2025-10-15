# LXD Container Troubleshooting Guide

Common issues when installing TAK Server in LXD containers and how to fix them.

---

## Container Networking Issues

### Symptom: No IPv4 Address
```bash
lxc list
# Container shows only IPv6 address
```

**Cause:** LXD bridge not providing IPv4 addresses via DHCP.

**Fix:**
```bash
# On the host, manually assign IP and configure networking
lxc exec tak -- ip addr add 10.206.248.11/24 dev eth0
lxc exec tak -- ip route add default via 10.206.248.1
lxc exec tak -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

# Make it permanent with netplan
lxc exec tak -- bash -c 'cat > /etc/netplan/10-lxc.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [10.206.248.11/24]
      routes:
        - to: default
          via: 10.206.248.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF'

lxc exec tak -- chmod 600 /etc/netplan/10-lxc.yaml
lxc exec tak -- netplan apply
```

### Symptom: DNS Resolution Fails
```bash
# Inside container
nslookup archive.ubuntu.com
# Returns: connection timed out; no servers could be reached
```

**Cause:** Host firewall blocking DNS traffic from containers.

**Fix:**
```bash
# On the host
sudo iptables -I FORWARD -i lxdbr0 -p udp --dport 53 -j ACCEPT
sudo iptables -I FORWARD -i lxdbr0 -p tcp --dport 53 -j ACCEPT
sudo iptables -I FORWARD -i lxdbr0 -j ACCEPT
sudo iptables -I FORWARD -o lxdbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Make permanent
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Symptom: installTAK Script Errors Immediately
```
LXD Mode: Verifying container networking...
ERROR: No internet connectivity detected
```

**Cause:** Container can't reach the internet.

**Fix:** Apply the networking and firewall fixes above, then re-run installTAK.

---

## PostgreSQL Issues

### Symptom: Database Connection Refused
```bash
tail /opt/tak/logs/takserver-messaging.log
# Shows: Connection to 127.0.0.1:5432 refused
```

**Cause:** PostgreSQL didn't initialize properly in the container.

**Fix (Automatic in LXD mode):**
The script detects this and fixes it automatically. If you need to do it manually:
```bash
# Inside tak container
mkdir -p /var/lib/postgresql/15/main
chown -R postgres:postgres /var/lib/postgresql
sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main
pg_ctlcluster 15 main start

# Verify it's running
ss -tulpn | grep 5432
```

### Symptom: Permission Denied Errors in Database
```
ERROR: permission denied for schema public
```

**Cause:** Database user doesn't have proper permissions.

**Fix:**
```bash
# Inside tak container
sudo -u postgres psql <<EOF
ALTER DATABASE cot OWNER TO martiuser;
GRANT ALL PRIVILEGES ON DATABASE cot TO martiuser;
\c cot
ALTER SCHEMA public OWNER TO martiuser;
GRANT ALL ON SCHEMA public TO martiuser;
ALTER EXTENSION postgis OWNER TO martiuser;
EOF

# Re-run database setup
cd /opt/tak
./db-utils/takserver-setup-db.sh

# Restart TAK Server
systemctl restart takserver
```

---

## TAK Server Issues

### Symptom: TAK Server Won't Start
```bash
systemctl status takserver
# Shows: active (exited) but not actually running
```

**Check the logs:**
```bash
tail -n 100 /opt/tak/logs/takserver-messaging.log
```

**Common causes:**
1. **Database not running** - Fix PostgreSQL (see above)
2. **Certificate issues** - Check certificate generation during install
3. **Insufficient memory** - Container needs 8GB+ RAM

### Symptom: Can't Access Web UI

Browser shows: `ERR_CONNECTION_REFUSED` or `ERR_CONNECTION_CLOSED`

**Checklist:**
1. **TAK Server running?**
```bash
   systemctl status takserver
   ss -tulpn | grep 8443
```

2. **Using domain name, not IP?**
   - ✅ `https://tak.pinenut.tech:8443`
   - ❌ `https://104.225.221.119:8443`

3. **Certificate imported in browser?**
   - Import `webadmin.p12` using "automatic" store selection
   - Restart browser after import

4. **HAProxy forwarding correctly?** (if using HAProxy)
```bash
   # On host
   curl -v https://tak.pinenut.tech:8443 2>&1 | grep Connected
   # Should show: Connected to tak.pinenut.tech
```

### Symptom: Certificate Authentication Failed
```
ERR_BAD_SSL_CLIENT_AUTH_CERT
```

**Causes:**
1. Certificate not imported correctly
2. Certificate imported to wrong store
3. Browser not sending certificate

**Fix:**
1. Remove existing certificate from browser
2. Re-import `webadmin.p12`
3. When prompted, choose **"Automatically select certificate store"**
4. Enter certificate password (default: `atakatak` or your custom password)
5. **Restart browser completely**
6. Try accessing `https://tak.pinenut.tech:8443` again

---

## HAProxy Integration Issues

### Symptom: Let's Encrypt Validation Fails
```
Certbot failed to authenticate some domains
```

**Cause:** HAProxy not forwarding ACME challenges to TAK container.

**Fix:** Ensure HAProxy config has:
```
frontend http-in
    bind *:80
    mode http
    
    # Forward Let's Encrypt challenges
    acl is_acme_challenge path_beg /.well-known/acme-challenge/
    use_backend tak-acme-backend if is_acme_challenge
```

And backend:
```
backend tak-acme-backend
    mode http
    server tak 10.206.248.11:80
```

### Symptom: TAK Ports Not Forwarded
```bash
# On host
ss -tulpn | grep 8089
# Nothing listening
```

**Cause:** LXD proxy devices not configured.

**Fix:**
```bash
# On host
lxc config device add haproxy tak8089 proxy listen=tcp:0.0.0.0:8089 connect=tcp:127.0.0.1:8089
lxc config device add haproxy tak8443 proxy listen=tcp:0.0.0.0:8443 connect=tcp:127.0.0.1:8443

# Verify
lxc config show haproxy | grep devices -A10
```

---

## Installation Issues

### Symptom: Script Aborts with "Minimum 8GB RAM Required"

**Cause:** Container doesn't have enough memory allocated.

**Fix:**
```bash
# On host - stop container and set memory limit
lxc stop tak
lxc config set tak limits.memory 8GB
lxc start tak
```

### Symptom: GPG Key Import Fails
```
takserver-public-gpg.key not found within the directory
```

**Cause:** Missing required files.

**Fix:** Ensure all files are in `/root/`:
```bash
# Inside container
ls -lh /root/
# Should see:
# - installTAK (or installTAK.sh)
# - takserver_5.5-RELEASE58_all.deb
# - takserver-public-gpg.key
# - deb_policy.pol
```

---

## Getting More Help

### Check Logs

**TAK Server:**
```bash
tail -f /opt/tak/logs/takserver-messaging.log
```

**PostgreSQL:**
```bash
tail -f /var/log/postgresql/postgresql-15-main.log
```

**HAProxy** (if using):
```bash
lxc exec haproxy -- tail -f /var/log/haproxy.log
```

### Enable Debug Mode
```bash
# Edit TAK Server logging
nano /opt/tak/CoreConfig.xml
# Find <logging> section and set level="DEBUG"

# Restart TAK
systemctl restart takserver
```

### Report Issues

If you encounter a bug in the LXD enhancements:
1. Check this troubleshooting guide first
2. Review logs for specific error messages  
3. Open an issue on GitHub with:
   - Container OS and version
   - TAK Server version
   - Complete error message
   - Relevant log excerpts

---

## Prevention Tips

✅ **Always run with LXD mode:** `./installTAK takserver.deb false true`

✅ **Verify networking first:** Test `ping` and `nslookup` before installing

✅ **Use netplan for static IPs:** Makes networking persistent across reboots

✅ **Take snapshots:** Before major changes: `lxc snapshot tak pre-install`

✅ **Monitor during install:** Watch for PostgreSQL initialization messages

✅ **Test incrementally:** Verify each component (PostgreSQL → TAK → HAProxy) separately
