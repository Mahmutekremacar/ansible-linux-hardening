RUN THIS AS ADMINISTRATOR ON YOUR CLIENTS (192.168.100.156, .161, .165)

1. Enable PowerShell Remoting (starts the WinRM service and creates default rules)

Enable-PSRemoting -Force

2. Explicitly allow inbound traffic on TCP 5985 (WinRM HTTP) just to be safe

New-NetFirewallRule -DisplayName "Allow WinRM 5985 (EDR Arena)" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

3. Allow Basic Authentication and Unencrypted traffic

(This is strictly required for Python's 'pywinrm' library to connect successfully)

Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force

4. Trust all hosts (allows your Python backend IP to connect)

Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

5. Restart the service to apply the new auth configurations

Restart-Service WinRM

Write-Host "WinRM is now fully open for the EDR Arena!" -ForegroundColor Green
















# Ansible Linux Server Hardening Playbook

A production-ready, idempotent Ansible playbook that applies security hardening to a fresh Ubuntu/Debian server. Designed to bring a baseline server to a defensible posture in a single automated run.

---

## Security Features

### 1. Package Auditing & Patch Management

The playbook begins by refreshing the APT package index and performing a full `dist-upgrade` to eliminate known vulnerabilities in pre-installed packages. It also installs and configures **`unattended-upgrades`** to apply security patches automatically every day without operator intervention.

| APT Automation Setting | Value |
|---|---|
| Package list refresh | Daily |
| Security upgrades | Daily |
| Unused dependency cleanup | Weekly |
| Automatic reboot | Disabled (operator-controlled) |

Disabling automatic reboots is a deliberate trade-off for production environments where uptime is critical — the operator reviews and schedules reboots after kernel or libc updates.

---

### 2. Network Defense (UFW Firewall)

**Uncomplicated Firewall (UFW)** is configured with a default-deny stance on all inbound traffic. Only explicitly approved ports are opened.

| Direction | Default Policy |
|---|---|
| Incoming | **DENY** |
| Outgoing | ALLOW |

The only permitted inbound rule is TCP traffic on the configured SSH port (default `2222`). This dramatically reduces the attack surface compared to the standard configuration that exposes port 22 — the first port scanned by virtually every automated scanner on the internet.

The SSH port is controlled via the `ssh_port` variable, making it trivially overridable per environment without editing the playbook:

```bash
# Override at runtime
ansible-playbook playbook.yml -e "ssh_port=22222"
```

---

### 3. SSH Hardening

`/etc/ssh/sshd_config` is modified to enforce the following controls. All changes are validated with `sshd -t` before being applied, preventing a misconfiguration from locking out access.

| Directive | Value | Rationale |
|---|---|---|
| `Port` | `{{ ssh_port }}` (default: 2222) | Reduces automated scan noise |
| `PermitRootLogin` | `no` | Eliminates direct root compromise via SSH |
| `PasswordAuthentication` | `no` | Enforces SSH key pairs; renders password-spraying and brute-force attacks ineffective |
| `ChallengeResponseAuthentication` | `no` | Closes a secondary authentication bypass vector |
| `MaxAuthTries` | `3` | Limits per-connection authentication attempts |
| `LoginGraceTime` | `30s` | Reduces the window for slow-credential attacks |
| `X11Forwarding` | `no` | Removes an unnecessary and exploitable feature |
| `AllowTcpForwarding` | `no` | Prevents SSH from being used as an unauthorized proxy |

A handler ensures the SSH daemon restarts only when the configuration is actually changed, not on every playbook run.

> **Important:** Deploy your SSH public key to `~/.ssh/authorized_keys` on the target host **before** running this playbook, or you will lose remote access when `PasswordAuthentication` is disabled.

---

### 4. Brute-Force Mitigation (Fail2ban)

**Fail2ban** monitors `/var/log/auth.log` and automatically bans source IPs that exhibit brute-force behavior by adding ephemeral `iptables` rules.

| Jail Parameter | Value | Meaning |
|---|---|---|
| `maxretry` | 3 | Ban after 3 failed authentication attempts |
| `findtime` | 600 seconds | Within a 10-minute window |
| `bantime` | 3600 seconds | IP is blocked for 1 hour |

The jail is scoped to the custom SSH port defined in `ssh_port`, ensuring Fail2ban correctly monitors the non-standard port. Configuration is deployed to `/etc/fail2ban/jail.d/sshd.conf` to follow the drop-in override pattern, preserving the Fail2ban package defaults.

---

## Requirements

| Dependency | Version |
|---|---|
| Ansible | >= 2.12 |
| `community.general` collection | >= 5.0 (for `ufw` module) |
| Target OS | Ubuntu 20.04 / 22.04 / Debian 11+ |

Install the required collection:

```bash
ansible-galaxy collection install community.general
```

---

## Usage

**1. Define your inventory** (`inventory.ini`):

```ini
[servers]
your-server-ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your_key
```

**2. Run the playbook:**

```bash
ansible-playbook -i inventory.ini playbook.yml
```

**3. Override the SSH port if needed:**

```bash
ansible-playbook -i inventory.ini playbook.yml -e "ssh_port=22222"
```

**4. Verify idempotency** — a second run with no changes should report `changed=0`.

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `ssh_port` | `2222` | The TCP port the SSH daemon will listen on |

---

## Project Structure

```
ansible-linux-hardening/
├── playbook.yml      # Main hardening playbook
└── README.md         # This document
```

---

## License

MIT
