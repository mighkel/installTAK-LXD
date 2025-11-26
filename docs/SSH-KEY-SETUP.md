# SSH Key Setup Guide

**Secure SSH access for your TAK Server VPS**

This guide covers setting up SSH key authentication from Windows, macOS, and Linux workstations to your VPS.

---

## Document Conventions

| Symbol | Meaning |
|--------|---------|
| 💻 | **Local Machine** - Your Windows/Mac/Linux workstation |
| 🖥️ | **VPS Host** - Commands run on the VPS via SSH |
| ⚠️ | **User Configuration Required** - Replace placeholder values |
| 💡 | **Tip** - Helpful information |
| ⛔ | **Critical** - Important warning |

**Placeholders used in this document:**
- `[YOUR_VPS_IP]` - Your VPS public IP address
- `[YOUR_VPS_HOSTNAME]` - A short name for your VPS

> 💡 **PLACEHOLDER SYNTAX**
> Replace the brackets AND the text inside with your actual value.
> Example: `[YOUR_VPS_IP]` becomes `203.0.113.50`
> (Keep any surrounding quotes, remove the brackets)

---

## Why SSH Keys?

SSH keys provide:
- **Security** - No password to brute-force
- **Convenience** - No password to type (optionally use passphrase)
- **Auditability** - Each user has unique key pair

> ⛔ **IMPORTANT**  
> Once SSH key authentication is configured, many VPS providers disable password login for root. Make sure your key works before closing your session!

---

## Windows: PuTTY Method

### Step 1: Install PuTTY Suite

Download and install PuTTY from [putty.org](https://www.putty.org/). The installer includes:
- **PuTTY** - SSH client
- **PuTTYgen** - Key generator
- **Pageant** - SSH authentication agent
- **PSCP/PSFTP** - Command-line file transfer

### Step 2: Generate SSH Key Pair

💻 **Local Machine (Windows)**

1. Launch **PuTTYgen**
2. Under **Parameters**, keep defaults:
   - Type: RSA
   - Bits: 2048 (or 4096 for higher security)
3. Click **Generate**
4. Move mouse randomly in the blank area to generate entropy
5. Once complete, you'll see:
   - Public key text box at top
   - Key fingerprint
   - Key comment field

6. Configure the key:
   - **Key comment:** `takadmin@[YOUR_VPS_HOSTNAME]` (or leave blank)
   - **Key passphrase:** Enter a strong passphrase (optional but recommended)
   - **Confirm passphrase:** Re-enter the same passphrase

7. Save your keys:
   - Click **Save private key** → `takadmin-[YOUR_VPS_HOSTNAME].ppk`
   - Click **Save public key** → `takadmin-[YOUR_VPS_HOSTNAME].pub`

8. **Copy the public key text** from the top box (starts with `ssh-rsa AAAA...`)
   - Keep PuTTYgen open, or save this text to a file

> ⚠️ **USER CONFIGURATION REQUIRED**  
> Replace `[YOUR_VPS_HOSTNAME]` with a short identifier (e.g., `takvps`, `prodtak`).

> 💡 **VPS Provider SSH Key Upload**  
> Some providers (SSDNodes, DigitalOcean, etc.) let you paste your public key during VPS provisioning. If so, paste the public key text there and skip Step 3 below.

### Step 3: Add Public Key to VPS

🖥️ **VPS Host** (connect with password for initial setup)

```bash
# Connect as root initially
# (Use PuTTY with password, or provider's web console)

# Create takadmin user if not exists
adduser takadmin
usermod -aG sudo takadmin

# Switch to takadmin
su - takadmin

# Create SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create/edit authorized_keys file
nano ~/.ssh/authorized_keys
```

**Paste your public key:**
- In PuTTY: Right-click to paste
- Should be ONE long line starting with `ssh-rsa AAAA...`
- Do NOT include line breaks

```bash
# Save and exit (Ctrl+X, Y, Enter)

# Set correct permissions (CRITICAL!)
chmod 600 ~/.ssh/authorized_keys

# Verify
ls -la ~/.ssh/
# Should show:
# drwx------ .ssh
# -rw------- authorized_keys
```

### Step 4: Configure PuTTY Session

💻 **Local Machine (Windows)**

1. Open **PuTTY**

2. **Session settings:**
   - Host Name: `takadmin@[YOUR_VPS_IP]`
   - Port: `22`
   - Connection type: SSH

3. **Configure private key:**
   - Left panel: **Connection → SSH → Auth → Credentials**
   - "Private key file for authentication": Browse → Select your `.ppk` file

4. **Save the session:**
   - Left panel: Go back to **Session**
   - "Saved Sessions": Enter a name (e.g., `TAK-VPS`)
   - Click **Save**

5. Click **Open** to connect

### Step 5: Test and Verify

**First connection:**
- You'll see "The server's host key is not cached..." - Click **Accept**
- If you set a passphrase, enter it when prompted
- You should now be logged in as `takadmin`

**Verify sudo works:**
```bash
sudo whoami
# Should output: root
```

> ⛔ **DON'T CLOSE THIS SESSION YET!**  
> Open a NEW PuTTY window and verify you can connect with the saved session before closing this one.

### Step 6: Use Pageant for Passphrase Management

If you set a passphrase, **Pageant** remembers it for your session:

💻 **Local Machine (Windows)**

1. Launch **Pageant** (appears in system tray)
2. Right-click the Pageant icon → **Add Key**
3. Select your `.ppk` file
4. Enter your passphrase once
5. PuTTY now authenticates automatically without prompting

> 💡 **TIP: Start Pageant Automatically**  
> Add Pageant to your Windows startup folder to load keys automatically on login.

---

## Windows: WinSCP for File Transfer

WinSCP provides a graphical file transfer interface.

💻 **Local Machine (Windows)**

### Setup

1. Download and install [WinSCP](https://winscp.net/)
2. Launch WinSCP
3. In the Login window:
   - **File protocol:** SFTP
   - **Host name:** `[YOUR_VPS_IP]`
   - **Port:** `22`
   - **User name:** `takadmin`
   - **Password:** (leave blank)

4. Click **Advanced → SSH → Authentication**
5. **Private key file:** Browse → Select your `.ppk` file
6. Click **OK**
7. Click **Save** to save the session
8. Click **Login**

### Using WinSCP with Pageant

If Pageant is running with your key loaded, WinSCP uses it automatically - no need to configure the private key in WinSCP.

---

## Linux / macOS: OpenSSH Method

### Step 1: Generate SSH Key Pair

💻 **Local Machine (Linux/macOS)**

```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -C "takadmin@[YOUR_VPS_HOSTNAME]"

# When prompted:
# Enter file: ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME]
# Enter passphrase: (optional but recommended)

# Set permissions
chmod 600 ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME]
chmod 644 ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME].pub
```

### Step 2: Copy Public Key to VPS

**Method A: Using ssh-copy-id (easiest)**

```bash
ssh-copy-id -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME].pub takadmin@[YOUR_VPS_IP]
# Enter password when prompted
```

**Method B: Manual copy**

```bash
# Display public key
cat ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME].pub

# Copy the output, then on VPS:
# (paste into ~/.ssh/authorized_keys as shown in Windows Step 3)
```

### Step 3: Test Connection

```bash
ssh -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME] takadmin@[YOUR_VPS_IP]
```

### Step 4: Create SSH Config (Optional but Recommended)

💻 **Local Machine (Linux/macOS)**

```bash
nano ~/.ssh/config
```

Add:
```
Host takvps
    HostName [YOUR_VPS_IP]
    User takadmin
    IdentityFile ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME]
    IdentitiesOnly yes
```

Now you can simply type:
```bash
ssh takvps
```

### Step 5: Use SSH Agent for Passphrase Management

```bash
# Start SSH agent
eval $(ssh-agent)

# Add your key
ssh-add ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME]
# Enter passphrase once

# Now connections use the cached passphrase
ssh takvps
```

> 💡 **TIP: Persistent SSH Agent**  
> Add `ssh-add` to your shell profile (`.bashrc`, `.zshrc`) to load keys on terminal start.

---

## SSH Tunneling for Local Access

SSH tunnels let you securely access services on your VPS from your local machine.

### Use Case: Access HAProxy Stats Page

The HAProxy stats page (port 8404) shouldn't be exposed to the internet. Use an SSH tunnel instead:

**Windows (PuTTY):**

1. Open your saved PuTTY session (don't connect yet)
2. Go to **Connection → SSH → Tunnels**
3. Add tunnel:
   - Source port: `8404`
   - Destination: `localhost:8404`
   - Click **Add**
4. Go back to **Session** → **Save**
5. Click **Open** to connect

6. In your browser, go to: `http://localhost:8404/haproxy_stats`

**Windows (PowerShell/Command Prompt):**

```powershell
# If you have OpenSSH installed (Windows 10+)
ssh -L 8404:localhost:8404 takadmin@[YOUR_VPS_IP]
```

> ⚠️ **NOTE:** PowerShell SSH may have issues with some key formats. PuTTY is more reliable on Windows.

**Linux/macOS:**

```bash
ssh -L 8404:localhost:8404 takvps

# Or with full path:
ssh -L 8404:localhost:8404 -i ~/.ssh/takadmin-[YOUR_VPS_HOSTNAME] takadmin@[YOUR_VPS_IP]
```

Then browse to: `http://localhost:8404/haproxy_stats`

### Common Tunnel Configurations

| Local Port | Remote Target | Use Case |
|------------|---------------|----------|
| `8404` | `localhost:8404` | HAProxy stats |
| `5432` | `localhost:5432` | PostgreSQL (if needed) |
| `8443` | `[CONTAINER_IP]:8443` | TAK Web UI (for testing) |

---

## Troubleshooting

### "Server refused our key"

| Cause | Fix |
|-------|-----|
| Wrong key format | Ensure you're using the `.ppk` file in PuTTY |
| Key not in authorized_keys | Re-add public key to `~/.ssh/authorized_keys` |
| Wrong permissions | Run `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys` |
| Wrong user | Verify you're connecting as `takadmin`, not `root` |
| Invalid characters in key | Re-copy public key, ensure no line breaks |

### "Permission denied (publickey)"

| Cause | Fix |
|-------|-----|
| Password auth disabled | Must use SSH key (no password fallback) |
| Key mismatch | Verify correct private key is selected |
| Key file permissions (Linux) | Run `chmod 600 ~/.ssh/id_rsa` |

### "Connection refused"

| Cause | Fix |
|-------|-----|
| SSH not running | VPS may still be provisioning |
| Wrong port | Verify port 22 (or custom port) |
| Firewall blocking | Check VPS firewall allows SSH |

### "Host key verification failed"

| Cause | Fix |
|-------|-----|
| VPS was reinstalled | Remove old entry: `ssh-keygen -R [YOUR_VPS_IP]` |
| Man-in-the-middle? | Verify you have the correct IP |

### PuTTY: "Unable to use key file"

| Cause | Fix |
|-------|-----|
| Wrong format | PuTTY needs `.ppk` format; use PuTTYgen to convert |
| Corrupted file | Regenerate key pair |

---

## Security Best Practices

1. **Use strong passphrases** on private keys
2. **Never share private keys** - each user should have their own
3. **Disable password authentication** after SSH keys work
4. **Use Fail2ban** to block brute-force attempts
5. **Consider changing SSH port** from default 22
6. **Regularly rotate keys** for high-security environments

### Disable Password Authentication (After Keys Work!)

🖥️ **VPS Host**

```bash
sudo nano /etc/ssh/sshd_config

# Find and change these lines:
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no

# Save and restart SSH
sudo systemctl restart sshd
```

> ⛔ **WARNING**  
> Only do this AFTER verifying SSH key login works! Test with a new connection first.

---

## Quick Reference

### Windows (PuTTY)
```
Key generation: PuTTYgen → Generate → Save .ppk
Connect: PuTTY → Load session → Open
Passphrase: Pageant → Add Key
File transfer: WinSCP with same .ppk
```

### Linux/macOS
```bash
# Generate
ssh-keygen -t rsa -b 4096 -f ~/.ssh/mykey

# Copy to server
ssh-copy-id -i ~/.ssh/mykey.pub user@host

# Connect
ssh -i ~/.ssh/mykey user@host

# Or with config
ssh myhost
```

---

## Additional Resources

- **PuTTY Documentation:** https://www.chiark.greenend.org.uk/~sgtatham/putty/docs.html
- **OpenSSH Manual:** https://www.openssh.com/manual.html
- **SSH Hardening Guide:** https://www.ssh.com/academy/ssh/sshd_config

---

*Last Updated: November 2025*
