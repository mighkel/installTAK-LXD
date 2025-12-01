# Node-RED Integration Setup

**Supplemental Guide: Adding Node-RED for TAK automation and data integration**

This guide adds a Node-RED container for creating automated workflows, integrating external data sources, and extending TAK Server capabilities.

---

## Document Conventions

See [Phase 1: LXD Setup](01-LXD-SETUP.md#document-conventions) for the full conventions guide.

**Quick Reference:**
| Symbol | Meaning |
|--------|---------|
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH (outside containers) |
| 📦 | **Inside Container** - Commands run inside an LXD container |
| ⚠️ | **User Configuration Required** - Replace placeholder values |

**Where Am I? (Check Your Prompt)**
| Prompt Looks Like | You Are |
|-------------------|---------|
| `takadmin@your-vps:~$` | 🖥️ VPS Host |
| `root@nodered:~#` | 📦 Inside Node-RED container |

**Container IPs:**
| Container | IP Address |
|-----------|------------|
| tak | 10.100.100.10 |
| haproxy | 10.100.100.11 |
| mediamtx | 10.100.100.12 |
| nodered | 10.100.100.14 |

---

## Prerequisites

Before starting this guide, verify:

- [ ] Completed Phases 1-6 of main deployment
- [ ] TAK Server is running and accessible
- [ ] HAProxy is configured and working

---

## What is Node-RED?

Node-RED is a flow-based programming tool for wiring together hardware devices, APIs, and online services. For TAK deployments, it enables:

- **Data Integration** - Connect external data sources (weather, sensors, ADS-B, etc.) to TAK
- **Automation** - Create automated alerts, notifications, and responses
- **Protocol Translation** - Convert data formats to Cursor on Target (CoT)
- **Web Dashboards** - Build browser-based situational awareness displays
- **Gateway Functions** - Bridge TAK with other systems (email, SMS, databases)

---

## Step 1: Create Node-RED Container

🖥️ **VPS Host**

### 1.1 Launch Container

```bash
# Create Node-RED container on takbr0 network
lxc launch ubuntu:22.04 nodered --network takbr0

# Wait for container to start
sleep 5

# Assign static IP
lxc stop nodered
lxc config device set nodered eth0 ipv4.address=10.100.100.14
lxc start nodered

# Verify
lxc list
```

**Expected output:**
```
+----------+---------+-----------------------+------+-----------+-----------+
|   NAME   |  STATE  |         IPV4          | IPV6 |   TYPE    | SNAPSHOTS |
+----------+---------+-----------------------+------+-----------+-----------+
| haproxy  | RUNNING | 10.100.100.11 (eth0)  |      | CONTAINER | 0         |
+----------+---------+-----------------------+------+-----------+-----------+
| nodered  | RUNNING | 10.100.100.14 (eth0)  |      | CONTAINER | 0         |
+----------+---------+-----------------------+------+-----------+-----------+
| tak      | RUNNING | 10.100.100.10 (eth0)  |      | CONTAINER | 0         |
+----------+---------+-----------------------+------+-----------+-----------+
```

### 1.2 Verify Networking

```bash
# Test internet connectivity
lxc exec nodered -- ping -c 3 1.1.1.1

# Test DNS
lxc exec nodered -- ping -c 3 google.com
```

---

## Step 2: Install Node.js and Node-RED

📦 **Inside Node-RED Container**

### 2.1 Access Container

🖥️ **VPS Host**

```bash
lxc exec nodered -- bash
```

### 2.2 Update System

📦 **Inside Node-RED Container**

```bash
apt update && apt upgrade -y
apt install -y curl wget nano build-essential git
```

### 2.3 Install Node.js (LTS)

```bash
# Add NodeSource repository for Node.js 20.x LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Install Node.js
apt install -y nodejs

# Verify installation
node --version
npm --version
```

**Expected output:**
```
v20.x.x
10.x.x
```

### 2.4 Install Node-RED

```bash
# Install Node-RED globally
npm install -g --unsafe-perm node-red

# Verify installation
node-red --version
```

---

## Step 3: Configure Node-RED Service

📦 **Inside Node-RED Container**

### 3.1 Create Node-RED User

```bash
# Create dedicated user for Node-RED
useradd -m -s /bin/bash nodered

# Create data directory
mkdir -p /home/nodered/.node-red
chown -R nodered:nodered /home/nodered
```

### 3.2 Create Systemd Service

```bash
nano /etc/systemd/system/node-red.service
```

**Paste this content:**

```ini
[Unit]
Description=Node-RED
After=network.target

[Service]
Type=simple
User=nodered
Group=nodered
WorkingDirectory=/home/nodered/.node-red
Environment="NODE_OPTIONS=--max_old_space_size=512"
ExecStart=/usr/bin/node-red --userDir /home/nodered/.node-red
Restart=always
RestartSec=10
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
```

Save and exit (Ctrl+X, Y, Enter).

### 3.3 Generate Initial Configuration

```bash
# Run Node-RED once as nodered user to generate settings
su - nodered -c "node-red --userDir /home/nodered/.node-red &"

# Wait for initialization
sleep 10

# Stop Node-RED
pkill -f node-red
```

### 3.4 Configure Settings

```bash
nano /home/nodered/.node-red/settings.js
```

**Find and modify these settings:**

```javascript
// Bind to all interfaces (required for container access)
uiHost: "0.0.0.0",

// Default port
uiPort: process.env.PORT || 1880,

// Enable projects feature (optional but useful)
editorTheme: {
    projects: {
        enabled: true
    }
},
```

> ⚠️ **Security Note:** We'll configure authentication in Step 7. For now, Node-RED is only accessible within the LXD network.

Save and exit.

### 3.5 Enable and Start Service

```bash
# Reload systemd
systemctl daemon-reload

# Enable on boot
systemctl enable node-red

# Start service
systemctl start node-red

# Check status
systemctl status node-red
```

**Expected output:** Active (running)

### 3.6 Verify Node-RED is Running

```bash
# Check port
ss -tulpn | grep 1880

# Test local access
curl -s http://localhost:1880 | head -20
```

Exit container:
```bash
exit
```

---

## Step 4: Install TAK Integration Nodes

📦 **Inside Node-RED Container**

🖥️ **VPS Host**

```bash
lxc exec nodered -- bash
```

### 4.1 Install Core TAK Nodes

📦 **Inside Node-RED Container**

```bash
# Switch to nodered user
su - nodered

# Navigate to Node-RED directory
cd ~/.node-red

# Install TAK nodes
npm install node-red-contrib-tak

# Install TAK registration/gateway node
npm install node-red-contrib-tak-registration

# Install worldmap for web-based SA display
npm install node-red-contrib-web-worldmap

# Exit nodered user
exit
```

### 4.2 Install Additional Useful Nodes

```bash
# Switch to nodered user
su - nodered
cd ~/.node-red

# Dashboard for UI elements
npm install node-red-dashboard

# XML parsing (for CoT manipulation)
npm install node-red-contrib-xml

# HTTP request improvements
npm install node-red-contrib-https

# Exit nodered user
exit
```

### 4.3 Restart Node-RED

```bash
systemctl restart node-red
systemctl status node-red
```

Exit container:
```bash
exit
```

---

## Step 5: Configure Network Access

🖥️ **VPS Host**

### 5.1 Option A: SSH Tunnel Access (Recommended for Admin)

Access Node-RED editor securely via SSH tunnel:

```bash
# From your local machine
ssh -L 1880:10.100.100.14:1880 takadmin@[YOUR_VPS_IP]

# Then browse to: http://localhost:1880
```

This is the most secure method - Node-RED is never exposed publicly.

### 5.2 Option B: HAProxy Access (For Shared Access)

If you need to expose Node-RED externally (with authentication):

📦 **Inside HAProxy Container**

```bash
lxc exec haproxy -- bash
nano /etc/haproxy/haproxy.cfg
```

**Add these sections:**

```haproxy
#============================================================
# NODE-RED (Port 1880)
#============================================================

frontend nodered-in
    bind *:1880
    mode http
    option httplog
    default_backend nodered-backend

backend nodered-backend
    mode http
    server nodered 10.100.100.14:1880 check
```

**Test and reload:**

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl reload haproxy
exit
```

**Add port forwarding:**

🖥️ **VPS Host**

```bash
# Add LXD proxy device
lxc config device add haproxy nodered proxy \
  listen=tcp:0.0.0.0:1880 \
  connect=tcp:10.100.100.11:1880

# Open firewall
sudo ufw allow 1880/tcp comment 'Node-RED'
```

> ⚠️ **IMPORTANT:** If exposing Node-RED externally, you MUST configure authentication (Step 7) before opening the firewall.

---

## Step 6: Connect Node-RED to TAK Server

### 6.1 Copy TAK Certificates to Node-RED Container

🖥️ **VPS Host**

Node-RED needs certificates to connect to TAK Server via TLS.

```bash
# Create certs directory in Node-RED container
lxc exec nodered -- mkdir -p /home/nodered/.node-red/certs

# Copy certificates from TAK container
lxc file pull tak/opt/tak/certs/files/admin.pem /tmp/admin.pem
lxc file pull tak/opt/tak/certs/files/admin-key.pem /tmp/admin-key.pem
lxc file pull tak/opt/tak/certs/files/ca.pem /tmp/ca.pem

# Push to Node-RED container
lxc file push /tmp/admin.pem nodered/home/nodered/.node-red/certs/
lxc file push /tmp/admin-key.pem nodered/home/nodered/.node-red/certs/
lxc file push /tmp/ca.pem nodered/home/nodered/.node-red/certs/

# Set permissions
lxc exec nodered -- chown -R nodered:nodered /home/nodered/.node-red/certs
lxc exec nodered -- chmod 600 /home/nodered/.node-red/certs/*.pem

# Clean up temp files
rm /tmp/admin.pem /tmp/admin-key.pem /tmp/ca.pem
```

### 6.2 Configure TLS in Node-RED

Access Node-RED editor (via SSH tunnel or direct):

1. Open Node-RED: `http://localhost:1880`
2. Click the **hamburger menu** (☰) → **Manage palette**
3. Verify TAK nodes are installed (should show `node-red-contrib-tak`)
4. Close palette manager

### 6.3 Create Basic TAK Connection Flow

In the Node-RED editor:

1. Click **hamburger menu** (☰) → **Import**
2. Paste this basic TAK listener flow:

```json
[
    {
        "id": "tak-tcp-in",
        "type": "tcp in",
        "name": "TAK Server Input",
        "server": "client",
        "host": "10.100.100.10",
        "port": "8089",
        "datamode": "stream",
        "datatype": "utf8",
        "newline": "</event>",
        "topic": "",
        "trim": false,
        "base64": false,
        "tls": "tak-tls-config",
        "x": 150,
        "y": 100,
        "wires": [["tak-decode"]]
    },
    {
        "id": "tak-decode",
        "type": "tak",
        "name": "Decode CoT",
        "x": 350,
        "y": 100,
        "wires": [["debug-output"]]
    },
    {
        "id": "debug-output",
        "type": "debug",
        "name": "CoT Events",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "payload",
        "x": 550,
        "y": 100,
        "wires": []
    },
    {
        "id": "tak-tls-config",
        "type": "tls-config",
        "name": "TAK TLS",
        "cert": "/home/nodered/.node-red/certs/admin.pem",
        "key": "/home/nodered/.node-red/certs/admin-key.pem",
        "ca": "/home/nodered/.node-red/certs/ca.pem",
        "certname": "",
        "keyname": "",
        "caname": "",
        "servername": "",
        "verifyservercert": false,
        "alpnprotocol": ""
    }
]
```

3. Click **Import**
4. Click **Deploy**

### 6.4 Verify Connection

1. Open the **Debug** sidebar (bug icon on right)
2. When TAK clients send position updates, you should see CoT events appear
3. If no events appear, check:
   - TAK Server is running
   - Certificates are correct
   - Port 8089 is the streaming port on your TAK Server

---

## Step 7: Configure Authentication (Required for External Access)

📦 **Inside Node-RED Container**

🖥️ **VPS Host**

```bash
lxc exec nodered -- bash
```

### 7.1 Generate Password Hash

📦 **Inside Node-RED Container**

```bash
# Generate password hash
su - nodered -c "node-red admin hash-pw"
```

Enter your desired password when prompted. Copy the resulting hash (starts with `$2b$...`).

### 7.2 Configure Admin Authentication

```bash
nano /home/nodered/.node-red/settings.js
```

**Find the `adminAuth` section and uncomment/modify:**

```javascript
adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2b$08$YOUR_HASH_HERE",
        permissions: "*"
    }]
},
```

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `$2b$08$YOUR_HASH_HERE` with the hash you generated.

Save and exit.

### 7.3 Restart Node-RED

```bash
systemctl restart node-red
```

Exit container:
```bash
exit
```

---

## Step 8: Example TAK Integration Flows

### 8.1 Display TAK Data on Web Worldmap

This flow displays all TAK client positions on a web-based map:

```json
[
    {
        "id": "worldmap-flow",
        "type": "tab",
        "label": "TAK Worldmap",
        "disabled": false
    },
    {
        "id": "tak-input",
        "type": "tcp in",
        "z": "worldmap-flow",
        "name": "TAK Server",
        "server": "client",
        "host": "10.100.100.10",
        "port": "8089",
        "datamode": "stream",
        "datatype": "utf8",
        "newline": "</event>",
        "topic": "",
        "trim": false,
        "base64": false,
        "tls": "tak-tls-config",
        "x": 130,
        "y": 100,
        "wires": [["tak-decode-wm"]]
    },
    {
        "id": "tak-decode-wm",
        "type": "tak",
        "z": "worldmap-flow",
        "name": "Decode CoT",
        "x": 310,
        "y": 100,
        "wires": [["tak2worldmap"]]
    },
    {
        "id": "tak2worldmap",
        "type": "tak2worldmap",
        "z": "worldmap-flow",
        "name": "TAK to Worldmap",
        "x": 510,
        "y": 100,
        "wires": [["worldmap"]]
    },
    {
        "id": "worldmap",
        "type": "worldmap",
        "z": "worldmap-flow",
        "name": "Map Display",
        "lat": "43.5",
        "lon": "-116.0",
        "zoom": "10",
        "layer": "OSM",
        "cluster": "",
        "maxage": "",
        "usermenu": "show",
        "layers": "show",
        "panit": "false",
        "panlock": "false",
        "zoomlock": "false",
        "hiderightclick": "false",
        "coords": "deg",
        "showgrid": "false",
        "showruler": "false",
        "allowFileDrop": "false",
        "path": "/worldmap",
        "x": 710,
        "y": 100,
        "wires": []
    }
]
```

After importing and deploying, access the map at: `http://localhost:1880/worldmap`

### 8.2 Send Alerts to TAK Clients

This flow sends a CoT alert marker to all TAK clients:

```json
[
    {
        "id": "alert-flow",
        "type": "tab",
        "label": "TAK Alerts",
        "disabled": false
    },
    {
        "id": "inject-alert",
        "type": "inject",
        "z": "alert-flow",
        "name": "Send Test Alert",
        "props": [
            {"p": "payload"}
        ],
        "repeat": "",
        "crontab": "",
        "once": false,
        "onceDelay": 0.1,
        "topic": "",
        "payload": "{\"name\":\"ALERT-001\",\"lat\":43.6150,\"lon\":-116.2023,\"cottype\":\"b-m-p-s-m\",\"remarks\":\"Test alert from Node-RED\"}",
        "payloadType": "json",
        "x": 150,
        "y": 100,
        "wires": [["encode-cot"]]
    },
    {
        "id": "encode-cot",
        "type": "tak",
        "z": "alert-flow",
        "name": "Encode CoT",
        "x": 350,
        "y": 100,
        "wires": [["tak-output"]]
    },
    {
        "id": "tak-output",
        "type": "tcp out",
        "z": "alert-flow",
        "name": "TAK Server Output",
        "host": "10.100.100.10",
        "port": "8089",
        "beserver": "client",
        "base64": false,
        "end": false,
        "tls": "tak-tls-config",
        "x": 570,
        "y": 100,
        "wires": []
    }
]
```

> 💡 **CoT Types:** Common types include:
> - `a-f-G-U-C` - Friendly ground unit
> - `a-h-G` - Hostile ground
> - `b-m-p-s-m` - Spot marker
> - `b-m-p-w-GOTO` - Waypoint

---

## Step 9: Create Snapshot

🖥️ **VPS Host**

```bash
# Create snapshot of configured Node-RED container
lxc snapshot nodered nodered-configured

# Verify
lxc info nodered | grep -A 5 Snapshots
```

---

## Verification Checklist

- [ ] Node-RED container running with static IP (10.100.100.14)
- [ ] Node-RED service active and enabled
- [ ] TAK nodes installed (node-red-contrib-tak)
- [ ] Worldmap node installed
- [ ] TAK certificates copied to Node-RED container
- [ ] Basic TAK connection flow working
- [ ] Authentication configured (if externally accessible)
- [ ] Snapshot created

---

## Troubleshooting

### Issue: Node-RED won't start

```bash
# Check logs
lxc exec nodered -- journalctl -u node-red -n 50

# Common issues:
# - Permission errors on .node-red directory
# - Invalid settings.js syntax
# - Port already in use
```

### Issue: Can't connect to TAK Server

1. Verify TAK Server is running:
   ```bash
   lxc exec tak -- systemctl status takserver
   ```

2. Check certificate paths in TLS config node

3. Verify port 8089 is correct (check TAK Server config)

4. Test connectivity from Node-RED container:
   ```bash
   lxc exec nodered -- openssl s_client -connect 10.100.100.10:8089
   ```

### Issue: No CoT events appearing

1. Verify TAK clients are connected to the server
2. Check the Debug sidebar is open and enabled
3. Verify the TCP-in node shows "connected" status
4. Try redeploying the flow

### Issue: Worldmap not loading

1. Verify worldmap node is installed:
   ```bash
   lxc exec nodered -- su - nodered -c "cd ~/.node-red && npm list node-red-contrib-web-worldmap"
   ```

2. Check browser console for JavaScript errors

3. Ensure the worldmap path isn't conflicting with other routes

---

## Quick Reference

| Item | Value |
|------|-------|
| Container IP | 10.100.100.14 |
| Node-RED Port | 1880 |
| Editor URL | http://localhost:1880 (via SSH tunnel) |
| Worldmap URL | http://localhost:1880/worldmap |
| Config Directory | /home/nodered/.node-red |
| Settings File | /home/nodered/.node-red/settings.js |
| Certificates | /home/nodered/.node-red/certs/ |
| Service | systemctl [start\|stop\|status] node-red |
| Logs | journalctl -u node-red -f |

**TAK Server Connection:**
- Host: 10.100.100.10
- Port: 8089 (streaming)
- TLS: Required (use admin certificates)

---

## Popular TAK Integration Nodes

| Node Package | Purpose |
|--------------|---------|
| node-red-contrib-tak | Core TAK/CoT encoding/decoding |
| node-red-contrib-tak-registration | TAK gateway/heartbeat registration |
| node-red-contrib-web-worldmap | Web-based map display with NATO symbols |
| node-red-contrib-tfr2cot | FAA TFR (Temporary Flight Restrictions) to CoT |
| node-red-contrib-cot2xtopo | CalTopo integration |

---

## Next Steps

- Build custom data integration flows (weather, sensors, ADS-B)
- Create automated alerting based on CoT events
- Set up dashboards for monitoring
- Explore Mission API integration for data sync
- Configure flow version control with projects feature

---

## Resources

- **Node-RED Documentation:** https://nodered.org/docs/
- **node-red-contrib-tak Docs:** https://node-red-contrib-tak.readthedocs.io/
- **TAK Integration Guide:** https://ampledata.org/node_red_atak.html
- **Node-RED Worldmap:** https://flows.nodered.org/node/node-red-contrib-web-worldmap
- **CoT Event Schema:** https://www.mitre.org/sites/default/files/pdf/09_4937.pdf

---

*Last Updated: November 2025*
