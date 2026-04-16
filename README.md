# Linux System Audit & Monitoring Tool

**NSCS Mini-Project — Academic Year 2025/2026**

A modular Bash-based system audit tool that collects hardware and software information from local and remote Linux machines, generates reports, and sends them via email.

---

## Project Structure

```
miniproject/
├── audit_main.sh      # Main entry point — runs the full audit pipeline
├── config.sh          # Global settings (email, remote hosts, paths)
├── lib_colors.sh      # Terminal colors and logging utilities
├── hw_audit.sh        # Hardware info collection (CPU, RAM, disk, network)
├── sw_audit.sh        # Software info collection (OS, packages, services)
├── report.sh          # Report generation (TXT + JSON output)
├── email.sh           # Email sending module (plain text)
├── remote.sh          # Multi-host SSH audit module
├── setup_cron.sh      # Cron job and log rotation setup
└── README.md          # This file
```

### What Each Script Does

| Script | Purpose |
|---|---|
| `audit_main.sh` | Main script. Parses arguments, runs HW/SW collection, generates reports, sends email, runs remote audits. |
| `config.sh` | All settings in one place: directories, email config, remote host list, thresholds. |
| `lib_colors.sh` | Colored terminal output (`color_echo`) and logging functions (`log_info`, `log_warn`, `log_error`). |
| `hw_audit.sh` | Collects: CPU model/cores/usage, RAM, GPU, disk layout, network interfaces, motherboard, USB/PCI devices. |
| `sw_audit.sh` | Collects: OS info, installed packages, running services, open ports, firewall, cron jobs, SUID files. |
| `report.sh` | Generates TXT and JSON reports from collected data. Creates SHA-256 hash for integrity. |
| `email.sh` | Sends the TXT report via email using `msmtp`, `mail`, `mailx`, or `sendmail`. |
| `remote.sh` | Connects to multiple remote PCs via SSH, runs an audit script on each, saves results locally. |
| `setup_cron.sh` | Helper to install/remove cron jobs, rotate old logs, check CPU alerts, diff/verify reports. |

---

## Quick Start

### 1. Make scripts executable

```bash
chmod +x *.sh
```

### 2. Run a local audit (interactive mode)

```bash
sudo ./audit_main.sh
```

The script will ask you to choose:
- Report type (full or short)
- Whether to send email
- Whether to audit remote hosts

### 3. Run with flags (non-interactive)

```bash
# Full audit, no email
sudo ./audit_main.sh --full

# Short audit + send email
sudo ./audit_main.sh --short --email user@example.com

# Full audit + audit all remote hosts
sudo ./audit_main.sh --full --remote-all

# Interactive menu
sudo ./audit_main.sh --menu
```

---

## Remote Multi-PC Audit

The tool can connect to multiple remote Linux machines via SSH, run an audit on each one, and save the results locally.

### Setup

1. Edit `config.sh` and add your hosts to the `REMOTE_HOSTS` array:

```bash
REMOTE_HOSTS=(
    "root@192.168.1.10:22:/home/user/.ssh/id_rsa"
    "admin@192.168.1.20:22:"
    "user@server3.local:2222:/home/user/.ssh/server3_key"
)
```

**Format:** `user@host:port:ssh_key_path`
- `port` — SSH port (default: 22)
- `ssh_key_path` — path to private key (leave empty for default `~/.ssh/id_rsa`)

2. Make sure SSH key-based authentication is set up for each host:

```bash
ssh-copy-id -i ~/.ssh/id_rsa user@192.168.1.10
```

3. Run the remote audit:

```bash
sudo ./audit_main.sh --remote-all
```

Or use the interactive menu (option 5).

Results are saved to `/var/log/sys_audit/reports/remote_<host>_<timestamp>.txt`.

---

## Email Setup

The tool sends plain text reports via email.

### Configure

In `config.sh`:

```bash
DEFAULT_EMAIL="your@email.com"
MAIL_TOOL="msmtp"    # options: msmtp, mail, mailx, sendmail
```

### Using msmtp (recommended)

```bash
# Install
sudo apt install msmtp msmtp-mta

# Configure ~/.msmtprc
cat > ~/.msmtprc << 'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host           smtp.gmail.com
port           587
from           your@gmail.com
user           your@gmail.com
password       your_app_password
EOF
chmod 600 ~/.msmtprc
```

### Send a report

```bash
sudo ./audit_main.sh --full --email recipient@example.com
```

---

## Cron Job (Automated Scheduling)

```bash
# Install daily audit at 4:00 AM
sudo ./setup_cron.sh install

# Remove the cron job
sudo ./setup_cron.sh remove

# Rotate old logs (delete reports older than 30 days)
sudo ./setup_cron.sh rotate

# Check CPU and send alert if above threshold
sudo ./setup_cron.sh alert

# Compare two reports
sudo ./setup_cron.sh diff report1.txt report2.txt

# Verify report integrity (SHA-256)
sudo ./setup_cron.sh verify /var/log/sys_audit/reports/report.txt
```

---

## Output Files

Reports are saved to `/var/log/sys_audit/reports/`:

```
audit_full_hostname_20260415_180000.txt         # Plain text report
audit_full_hostname_20260415_180000.json        # JSON report
audit_full_hostname_20260415_180000.txt.sha256  # Integrity hash
remote_root_192_168_1_10_20260415_180000.txt    # Remote host report
```

Logs are saved to `/var/log/sys_audit/logs/audit.log`.

---

## Requirements

- **OS:** Linux (Debian/Ubuntu, RHEL/Fedora, Arch)
- **Bash:** 4.0+ (for associative arrays)
- **Root:** Recommended for full hardware details (motherboard, BIOS)
- **For email:** `msmtp`, `mail`, `mailx`, or `sendmail`
- **For remote audit:** SSH key-based authentication to target hosts
