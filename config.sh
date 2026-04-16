#!/usr/bin/env bash
# ============================================================
#  config.sh — Global configuration for the Audit System
#  Edit the variables below to match your environment.
# ============================================================

# ── Directories 
REPORT_DIR="/var/log/sys_audit/reports"
LOG_DIR="/var/log/sys_audit/logs"
AUDIT_LOG="${LOG_DIR}/audit.log"

# ── Email settings 
# Set the default recipient; can be overridden via --email flag
DEFAULT_EMAIL="your@gmail.com"
EMAIL_SUBJECT_PREFIX="[SysAudit]"
# Mail tool: mail | mailx | msmtp | sendmail
MAIL_TOOL="msmtp"

# ── Remote hosts for SSH audit 
# Add one entry per line: "user@host:port:path_to_ssh_key"
# - port is optional (defaults to 22)
# - ssh_key is optional (defaults to ~/.ssh/id_rsa)
# Example:
#   REMOTE_HOSTS=(
#       "root@192.168.1.10:22:/home/user/.ssh/id_rsa"
#       "admin@192.168.1.20:22:"
#       "user@server3.local:2222:/home/user/.ssh/server3_key"
#   )
REMOTE_HOSTS=(
    # "root@192.168.1.10:22:/home/user/.ssh/id_rsa"
    # "admin@192.168.1.20:22:"
)

# Remote directory where reports are stored on each host
REMOTE_REPORT_DIR="/var/log/sys_audit/remote_reports"
# ── CPU alert threshold (percentage) 
CPU_ALERT_THRESHOLD=80

# ── Report retention (days before rotation) 
LOG_RETENTION_DAYS=30

# ── Cron schedule (used only for documentation / setup helper)
CRON_SCHEDULE="0 4 * * *"   # daily at 04:00 AM
