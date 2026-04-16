# Linux Audit Project
NSCS Mini-Project - 2025/2026

This is a bash script that checks hardware and software info on Linux. It works on local machines and can also check remote ones via SSH. It saves reports as text and json.

## Files in this project
- `audit_main.sh`: The main script you run.
- `config.sh`: Settings for email and remote hosts.
- `hw_audit.sh`: Gets hardware info (CPU, RAM, Disks).
- `sw_audit.sh`: Gets software info (OS, packages, services).
- `report.sh`: Creates the actual report files.
- `email.sh`: Handles sending the report via email.
- `remote.sh`: Logic for checking other PCs over SSH.
- `setup_cron.sh`: for scheduling the audit to run automatically.
- `lib_colors.sh`: colors and logs functions.

## How to use it

### 1. Give permissions
```bash
chmod +x *.sh
```

### 2. Run local audit
You can just run it like this:
```bash
sudo ./audit_main.sh
```
It will ask you a few questions about the report type and if you want to send it via email.

### 3. Using flags
You can also skip the questions using flags:
- `./audit_main.sh --full` : run everything
- `./audit_main.sh --short` : summary only
- `./audit_main.sh --email user@mail.com` : send report to email

---

## Remote Audit (SSH)
To check other PCs, add them to `config.sh` in the `REMOTE_HOSTS` list.
Example format: `user@192.168.1.10:22`

Then run:
```bash
sudo ./audit_main.sh --remote-all
```

## Email
I used `msmtp` for email. You need to configure your `~/.msmtprc` for it to work. You can change the tool in `config.sh` if you prefer `mailx` or `sendmail`.

## Scheduling
If you want to run this every day at 4 AM:
```bash
sudo ./setup_cron.sh install
```

To stop it:
```bash
sudo ./setup_cron.sh remove
```

Reports are saved in `/var/log/sys_audit/reports/`.
