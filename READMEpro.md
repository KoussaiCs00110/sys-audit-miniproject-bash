# Linux Audit & Monitoring System

**NSCS Mini-Project 2025/2026 — Belouadah Saad Eddine Koussai**

A modular Bash toolset that audits Linux machines — locally and remotely — and generates reports in TXT, JSON, and HTML format, with email delivery and cron scheduling.

---

## Table of Contents

1. [What It Does](#1-what-it-does)
2. [File Structure](#2-file-structure)
3. [Installation](#3-installation)
4. [How to Run](#4-how-to-run)
5. [All Command-Line Flags](#5-all-command-line-flags)
6. [Configuration (config.sh)](#6-configuration-configsh)
7. [Email Setup](#7-email-setup)
8. [Remote Auditing via SSH](#8-remote-auditing-via-ssh)
9. [Cron Scheduling](#9-cron-scheduling)
10. [Understanding Reports](#10-understanding-reports)
11. [Security Features](#11-security-features)
12. [Troubleshooting](#12-troubleshooting)
13. [Dependencies](#13-dependencies)

---

## 1. What It Does

| Feature | Description |
|---|---|
| Hardware Audit | CPU, RAM, GPU, Disk, Network, BIOS, USB, PCI |
| Software Audit | OS, packages, services, ports, firewall, login history |
| 3 Report Formats | TXT (human), JSON (machine), HTML (email) |
| SHA-256 Integrity | Every report gets a checksum to detect tampering |
| Email Delivery | Sends HTML body + TXT attachment automatically |
| Remote SSH Audit | Audits other machines without installing anything on them |
| Cron Scheduling | Runs daily at 4 AM automatically, with log rotation |
| Interactive Menu | 8-option menu for running individual components |

---

## 2. File Structure

```
FINALMINIPROJ/
├── audit_main.sh      # Entry point — runs everything, parses flags, shows menu
├── config.sh          # All settings in one place (edit this to configure)
├── hw_audit.sh        # Collects hardware info into HW[] array
├── sw_audit.sh        # Collects software/security info into SW[] array
├── report.sh          # Writes TXT, JSON, HTML reports + SHA-256 checksum
├── email.sh           # Builds MIME email and sends it
├── remote.sh          # SSH upload → run → retrieve → cleanup
├── setup_cron.sh      # Installs/removes cron, rotates logs, verifies reports
└── lib_colors.sh      # Colored terminal output + log functions
```

---

## 3. Installation

```bash
# 1. Go to the project folder
cd ~/FINALMINIPROJ

# 2. Give execute permissions to all scripts
chmod +x *.sh

# 3. Create the report/log directories
sudo mkdir -p /var/log/sys_audit/reports
sudo mkdir -p /var/log/sys_audit/logs
```

---

## 4. How to Run

### Interactive mode (guided prompts)
```bash
sudo ./audit_main.sh
```
It will ask you 3 questions: report type, email, and remote hosts — then run.

### Interactive menu (8 options)
```bash
sudo ./audit_main.sh --menu
```

### Direct with flags (skip prompts)
```bash
sudo ./audit_main.sh --full
sudo ./audit_main.sh --short
sudo ./audit_main.sh --full --email you@gmail.com
sudo ./audit_main.sh --full --remote-all
```

---

## 5. All Command-Line Flags

| Flag | What it does |
|---|---|
| `--full` | Full audit with all details |
| `--short` | Summary-only audit (faster) |
| `--email addr` | Send the report to this email address |
| `--remote-all` | Also audit all hosts listed in `config.sh` |
| `--menu` | Launch the interactive 8-option menu |
| `-h` / `--help` | Show usage and exit |

**Combining flags:**
```bash
# Full audit + email + remote hosts
sudo ./audit_main.sh --full --email admin@company.com --remote-all

# Short summary delivered by email
sudo ./audit_main.sh --short --email me@gmail.com
```

---

## 6. Configuration (config.sh)

All settings are in `config.sh`. You only need to edit this one file to configure everything.

```bash
# ── PATHS ───────────────────────────────────────────────────────────
# Where reports (TXT, JSON, HTML) are saved
REPORT_DIR="/var/log/sys_audit/reports"

# Where audit logs are saved
LOG_DIR="/var/log/sys_audit/logs"
AUDIT_LOG="${LOG_DIR}/audit.log"

# ── EMAIL ───────────────────────────────────────────────────────────
# Default recipient when --email flag is not used
DEFAULT_EMAIL="you@example.com"

# Prefix added to all email subjects
EMAIL_SUBJECT_PREFIX="[SysAudit]"

# Which mail tool to use: msmtp | mail | mailx | sendmail
MAIL_TOOL="msmtp"

# ── REMOTE HOSTS ────────────────────────────────────────────────────
# Format: "user@host:port:path_to_ssh_key"
# Port defaults to 22. SSH key path is optional.
REMOTE_HOSTS=(
    # "root@192.168.1.10:22:/home/user/.ssh/id_rsa"
    # "admin@192.168.1.20:2222:/home/user/.ssh/id_ed25519"
)

# Where remote audit reports are saved locally
REMOTE_REPORT_DIR="/var/log/sys_audit/remote_reports"

# ── ALERTS ──────────────────────────────────────────────────────────
# Send alert email when CPU usage exceeds this %
CPU_ALERT_THRESHOLD=80

# ── LOG ROTATION ────────────────────────────────────────────────────
# Delete files older than this many days
LOG_RETENTION_DAYS=30

# ── CRON ────────────────────────────────────────────────────────────
# When to run the automatic audit
# Format: minute hour day month weekday
CRON_SCHEDULE="0 4 * * *"   # Every day at 4:00 AM
```

---

## 7. Email Setup

The tool supports three mail clients. **msmtp is recommended.**

---

### Option A — msmtp (Recommended)

`msmtp` is a lightweight client that sends email using your Gmail or any SMTP server. It reads credentials from `~/.msmtprc`.

#### Step 1 — Install msmtp

```bash
# Debian / Ubuntu
sudo apt install msmtp msmtp-mta -y

# Fedora / RHEL
sudo dnf install msmtp -y

# Arch Linux
sudo pacman -S msmtp
```

#### Step 2 — Create a Gmail App Password

Your regular Gmail password will **not** work. You must create an App Password:

1. Go to [myaccount.google.com/security](https://myaccount.google.com/security)
2. Enable **2-Step Verification** (required)
3. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
4. Select **Mail** → **Other (Custom name)** → name it `msmtp` → click **Generate**
5. Copy the **16-character password** shown (you only see it once)

#### Step 3 — Create the config file

```bash
nano ~/.msmtprc
```

Paste this, replacing the placeholders:

```
# Default settings
defaults
    auth           on
    tls            on
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    logfile        ~/.msmtp.log

# Gmail account
account        gmail
host           smtp.gmail.com
port           587
from           your.email@gmail.com
user           your.email@gmail.com
password       abcdefghijklmnop    # 16-char App Password, no spaces

# Use this account by default
account default : gmail
```

#### Step 4 — Secure the file

```bash
chmod 600 ~/.msmtprc
```

#### Step 5 — Test it

```bash
echo "Test email" | msmtp your.email@gmail.com
```

If it works, you'll receive the email within seconds.

#### Step 6 — Set it in config.sh

```bash
MAIL_TOOL="msmtp"
DEFAULT_EMAIL="you@gmail.com"
```

> **Using Outlook instead of Gmail?**
> ```
> account        outlook
> host           smtp.office365.com
> port           587
> from           your.name@outlook.com
> user           your.name@outlook.com
> password       your_password_here
> auth           login
> tls            on
> ```

---

### Option B — mailx / mail

If your system has a local MTA already configured:

```bash
# Install
sudo apt install mailutils -y      # Debian/Ubuntu
sudo dnf install mailx -y          # Fedora

# Test
echo "Test" | mail -s "Subject" recipient@example.com

# Set in config.sh
MAIL_TOOL="mailx"
```

> **Note:** `mailx` sends TXT only (no HTML body, no attachment). Use msmtp for proper emails.

---

### Option C — sendmail

```bash
sudo apt install sendmail -y
sudo sendmailconfig            # interactive setup wizard

# Set in config.sh
MAIL_TOOL="sendmail"
```

---

### Sending a Report Manually

```bash
# With flag
sudo ./audit_main.sh --full --email admin@company.com

# From the interactive menu (option 6 — "Send Last Report via Email")
sudo ./audit_main.sh --menu
```

---

## 8. Remote Auditing via SSH

The tool audits other Linux machines on your network **without installing anything on them**. It uploads the collection scripts temporarily, runs them, downloads the results, and deletes everything.

### How It Works

```
Your Machine                          Remote Machine
─────────────                         ──────────────
1. SSH connect ──────────────────────► create /tmp/sys_audit_TIMESTAMP/
2. scp upload  ──────────────────────► upload hw_audit.sh, sw_audit.sh, lib_colors.sh
3. SSH execute ──────────────────────► run the audit scripts
               ◄────────────────────── stream report output back
4. Save output   (saved to local REMOTE_REPORT_DIR)
5. SSH cleanup ──────────────────────► rm -rf /tmp/sys_audit_TIMESTAMP/
```

No permanent installation on the remote machine. No traces left after the audit.

---

### Step 1 — Generate an SSH Key Pair

On **your local machine**:

```bash
# Generate a modern ED25519 key
ssh-keygen -t ed25519 -C "audit_key" -f ~/.ssh/audit_key

# This creates:
#   ~/.ssh/audit_key        ← private key (never share this)
#   ~/.ssh/audit_key.pub    ← public key  (copy this to remote machines)

# When prompted for a passphrase:
# → Press Enter for no passphrase (best for automation)
```

---

### Step 2 — Copy the Public Key to Each Remote Host

```bash
# Easiest method (needs password once)
ssh-copy-id -i ~/.ssh/audit_key.pub root@192.168.1.10
ssh-copy-id -i ~/.ssh/audit_key.pub root@192.168.1.20

# Manual method (if ssh-copy-id is not available)
cat ~/.ssh/audit_key.pub | ssh root@192.168.1.10 \
    'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

---

### Step 3 — Test the Key

```bash
# This should log in WITHOUT asking for a password
ssh -i ~/.ssh/audit_key root@192.168.1.10 'hostname'

# If it still asks for a password, check authorized_keys on the remote:
ssh root@192.168.1.10 'cat ~/.ssh/authorized_keys'
```

---

### Step 4 — Add Hosts to config.sh

```bash
REMOTE_HOSTS=(
    "root@192.168.1.10:22:/home/youruser/.ssh/audit_key"
    "root@192.168.1.20:22:/home/youruser/.ssh/audit_key"
    "admin@myserver.com:2222:/home/youruser/.ssh/audit_key"
)

# Format: "user@host:port:key_path"
#   user     = SSH user on the REMOTE machine
#   host     = IP address or hostname
#   port     = SSH port (22 is the default)
#   key_path = absolute path to YOUR private key
```

---

### Step 5 — Run the Remote Audit

```bash
# Audit all configured remote hosts
sudo ./audit_main.sh --remote-all

# Reports will appear in:
ls /var/log/sys_audit/reports/
# remote_root_192_168_1_10_20250416_040000.txt
```

---

### SSH Troubleshooting

| Problem | Solution |
|---|---|
| `Connection refused` | Start sshd on remote: `systemctl start sshd` |
| `Permission denied (publickey)` | Key not copied correctly — re-run `ssh-copy-id` |
| `Host key verification failed` | Run `ssh-keygen -R hostname`, then reconnect manually once |
| Audit times out | Check connectivity: `ping hostname` |
| `SCP upload failed` | SSH user may lack write access to `/tmp` — try with `root` |
| Some fields show `N/A` | Remote user is not root — use `root` or add `sudo NOPASSWD` rules |

---

## 9. Cron Scheduling

Cron runs the audit automatically on a schedule. No manual action needed after setup.

---

### Understanding Cron Syntax

The schedule uses 5 fields:

```
 ┌───── minute     (0–59)
 │ ┌─── hour       (0–23)
 │ │ ┌─ day        (1–31,  * = every day)
 │ │ │ ┌ month     (1–12,  * = every month)
 │ │ │ │ ┌ weekday (0–7,   0/7=Sun, 1=Mon … 6=Sat, * = every day)
 │ │ │ │ │
 0 4 * * *
```

**Common examples:**

```bash
CRON_SCHEDULE="0 4 * * *"      # Every day at 4:00 AM (default)
CRON_SCHEDULE="0 2 * * 1"      # Every Monday at 2:00 AM
CRON_SCHEDULE="30 6 * * 1-5"   # Weekdays (Mon–Fri) at 6:30 AM
CRON_SCHEDULE="0 */6 * * *"    # Every 6 hours
CRON_SCHEDULE="0 8 1 * *"      # First day of every month at 8:00 AM
```

---

### Install the Cron Job

```bash
# Install the cron job and set up logrotate
sudo ./setup_cron.sh install

# Verify it was added
crontab -l
# 0 4 * * * /home/user/FINALMINIPROJ/audit_main.sh --full >> /var/log/sys_audit/logs/cron_exec.log 2>&1 # sys_audit
```

> The install script: reads existing crontab → removes any old `# sys_audit` entry → adds the new line → writes it back. Your other cron jobs are never touched.

---

### Change the Schedule

**Method 1 — Edit config.sh (recommended):**
```bash
# Change CRON_SCHEDULE in config.sh
CRON_SCHEDULE="0 6 * * 1-5"    # Weekdays at 6:00 AM

# Reinstall to apply
sudo ./setup_cron.sh remove
sudo ./setup_cron.sh install
```

**Method 2 — Edit crontab directly:**
```bash
crontab -e
# Find the line with # sys_audit and edit the 5 time fields
# Save and exit — takes effect immediately
```

---

### Remove the Cron Job

```bash
sudo ./setup_cron.sh remove

# Verify it's gone
crontab -l | grep sys_audit
# (no output = removed successfully)
```

---

### View Cron Logs

```bash
# See what happened each time the cron ran
cat /var/log/sys_audit/logs/cron_exec.log

# Watch it live
tail -f /var/log/sys_audit/logs/cron_exec.log

# General audit event log (INFO / WARN / ERROR with timestamps)
cat /var/log/sys_audit/logs/audit.log

# System-level cron log
grep CRON /var/log/syslog | tail -20       # Debian/Ubuntu
journalctl -u cron --since today            # systemd systems
```

---

### Log Rotation

`setup_cron.sh install` also creates `/etc/logrotate.d/sys_audit` which automatically compresses and deletes old files:

```
/var/log/sys_audit/reports/*.txt /var/log/sys_audit/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
}
```

You can also rotate manually at any time:
```bash
sudo ./setup_cron.sh rotate
```

---

## 10. Understanding Reports

### Report Filename Format

```
audit_{type}_{hostname}_{YYYYMMDD_HHMMSS}.{ext}

Examples:
  audit_full_myserver_20250416_040000.txt
  audit_full_myserver_20250416_040000.json
  audit_full_myserver_20250416_040000.html
  audit_full_myserver_20250416_040000.txt.sha256

Remote host reports:
  remote_root_192_168_1_10_20250416_040001.txt
```

---

### Short vs Full Report

| Section | `--short` | `--full` |
|---|:---:|:---:|
| CPU model, cores, architecture | ✅ | ✅ |
| CPU frequency, cache, usage | ❌ | ✅ |
| RAM total, used, available | ✅ | ✅ |
| RAM free, swap details | ❌ | ✅ |
| Disk root usage | ✅ | ✅ |
| Full disk layout (lsblk) | ❌ | ✅ |
| Network interfaces & IPs | ✅ | ✅ |
| MACs, gateway, DNS | ❌ | ✅ |
| OS name, kernel, hostname | ✅ | ✅ |
| Timezone, locale | ❌ | ✅ |
| Package list | ❌ | ✅ |
| Logged-in users | ✅ | ✅ |
| Running services | ❌ | ✅ |
| Failed services | ✅ | ✅ |
| Open ports | ✅ | ✅ |
| Firewall status | ✅ | ✅ |
| SUID files | ❌ | ✅ |
| World-writable directories | ❌ | ✅ |

---

### Verify Report Integrity

```bash
# Verify a report was not modified after generation
sudo ./setup_cron.sh verify /var/log/sys_audit/reports/audit_full_myserver_20250416.txt

# Output if OK:       Integrity OK.
# Output if modified: Integrity check FAILED.

# Manual verification
sha256sum --check /var/log/sys_audit/reports/audit_full_myserver_20250416.txt.sha256
```

---

### Compare Two Reports

Detect what changed between two audits (new packages, disappeared services, etc.):

```bash
sudo ./setup_cron.sh diff \
    /var/log/sys_audit/reports/audit_full_server_20250415.txt \
    /var/log/sys_audit/reports/audit_full_server_20250416.txt
```

---

## 11. Security Features

The software audit collects several items specifically for security monitoring:

| Check | Command Used | Why It Matters |
|---|---|---|
| **SUID files** | `find / -perm -4000 -type f` | Files that run as root for any user — attackers use misconfigured ones for privilege escalation |
| **World-writable dirs** | `find /etc /tmp /var -perm -0002 -type d` | Directories anyone can write to — exploitable for symlink attacks or config injection |
| **Open ports** | `ss -tuln` | Unexpected listening ports = service that shouldn't be running, or a backdoor |
| **Failed logins** | `lastb -n 10` (root only) | Many failures from one IP = brute-force attack in progress |
| **Firewall status** | `ufw status` / `iptables -L` | A disabled firewall on an internet-facing server is a critical finding |

---

## 12. Troubleshooting

| Problem | Solution |
|---|---|
| `Permission denied` when running | Add `sudo` — many audit commands need root |
| Reports directory missing | `sudo mkdir -p /var/log/sys_audit/reports /var/log/sys_audit/logs` |
| `msmtp: command not found` | Install msmtp (Section 7) or change `MAIL_TOOL` in config.sh |
| Email arrives but is empty | Wrong password in `~/.msmtprc` — check it, use App Password for Gmail |
| `Email address looks wrong` error | The validation requires `user@domain.tld` format — check for typos |
| Script stops unexpectedly | `set -e` is active. Run `bash -x ./audit_main.sh` to see which command failed |
| SSH: `Connection refused` | Start sshd on remote: `sudo systemctl start sshd` |
| SSH: some fields show `N/A` | Remote user is not root — switch to `root` user in config.sh |
| Cron job not running | Check `crontab -l` (exists?), then check `cron_exec.log` for errors |
| `dmidecode: command not found` | `sudo apt install dmidecode` — or ignore, it's not critical |

---

## 13. Dependencies

### Required (always present on Linux)
- `bash 4.0+` — associative arrays need Bash 4 minimum
- `/proc/cpuinfo`, `/proc/meminfo` — CPU and RAM data
- `uname`, `hostname`, `df`, `free`, `uptime` — basic system info
- `ip` or `ifconfig` — network info
- `systemctl` or `service` — service status
- `ps`, `ss` or `netstat` — processes and ports

### Optional (handled gracefully if missing)

| Tool | What you lose without it |
|---|---|
| `dmidecode` | BIOS info, motherboard model, serial number |
| `lspci` | GPU and PCI device list |
| `lsusb` | USB device list |
| `msmtp` | Email delivery (use mailx instead) |
| `cron` | Automatic scheduling |
| `logrotate` | Automatic old-file deletion |
| `sha256sum` | Report integrity checking |

---

*Linux Audit & Monitoring System — NSCS 2025/2026*
