#!/usr/bin/env bash
# config settings for the audit script

# where to save reports and logs
REPORT_DIR="/var/log/sys_audit/reports"
LOG_DIR="/var/log/sys_audit/logs"
AUDIT_LOG="${LOG_DIR}/audit.log"

# email stuff
DEFAULT_EMAIL="saadbelouadahchess@gmail.com"
EMAIL_SUBJECT_PREFIX="[SysAudit]"
MAIL_TOOL="msmtp" # can use mail, mailx, msmtp, sendmail

# remote hosts list for ssh
# format: "user@host:port:key_path"
# port defaults to 22 if empty
REMOTE_HOSTS=(
    # "root@192.168.1.10:22:/home/user/.ssh/id_rsa"
)

# where remote reports go
REMOTE_REPORT_DIR="/var/log/sys_audit/remote_reports"

# alert if cpu higher than this
CPU_ALERT_THRESHOLD=80

# how long to keep logs
LOG_RETENTION_DAYS=30

# when to run cron task
CRON_SCHEDULE="0 4 * * *"
