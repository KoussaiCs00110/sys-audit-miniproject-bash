#!/usr/bin/env bash
# ============================================================
#  setup_cron.sh — Cron Job & Log Rotation Setup Helper
#  Run once as root or the target user to install automation.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib_colors.sh"

AUDIT_CMD="${SCRIPT_DIR}/audit_main.sh --full"
CRON_TAG="# sys_audit — managed entry"

# ── Install cron job 
install_cron() {
    # Remove any previous sys_audit cron line to avoid duplicates
    ( crontab -l 2>/dev/null | grep -v "${CRON_TAG}" ; \
      echo "${CRON_SCHEDULE} ${AUDIT_CMD} >> ${LOG_DIR}/cron_exec.log 2>&1 ${CRON_TAG}" \
    ) | crontab -

    color_echo GREEN "+ Cron job installed: ${CRON_SCHEDULE}  →  ${AUDIT_CMD}"
    color_echo CYAN  "  View with: crontab -l"
}

# ── Remove cron job 
remove_cron() {
    crontab -l 2>/dev/null | grep -v "${CRON_TAG}" | crontab - || true
    color_echo YELLOW "Cron job removed."
}

# ── Log rotation (manual) 
rotate_logs() {
    color_echo CYAN "Rotating logs older than ${LOG_RETENTION_DAYS} days in ${REPORT_DIR}..."
    find "${REPORT_DIR}" -type f -mtime "+${LOG_RETENTION_DAYS}" -delete
    find "${LOG_DIR}"    -type f -mtime "+${LOG_RETENTION_DAYS}" -delete
    color_echo GREEN "+ Old logs removed."
}

# ── Systemd logrotate config (optional) 
install_logrotate() {
    local conf="/etc/logrotate.d/sys_audit"
    if [[ $EUID -ne 0 ]]; then
        log_warn "Root required to write to /etc/logrotate.d/. Skipping."
        return
    fi

    cat > "${conf}" <<LOGROTATE
${REPORT_DIR}/*.txt ${LOG_DIR}/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0640 root root
}
LOGROTATE

    color_echo GREEN "+ logrotate config written to ${conf}"
}

# ── Alert system: check CPU and send alert if over threshold ──
check_cpu_alert() {
    local usage
    usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int(100-$8)}' || echo "0")
    if (( usage > CPU_ALERT_THRESHOLD )); then
        local msg="⚠ CPU ALERT on $(hostname): usage is ${usage}% (threshold: ${CPU_ALERT_THRESHOLD}%)"
        log_warn "${msg}"
        if [[ -n "${DEFAULT_EMAIL}" ]]; then
            echo "${msg}" | mail -s "[SysAudit] CPU Alert — $(hostname)" "${DEFAULT_EMAIL}" 2>/dev/null || true
        fi
    fi
}

# ── Diff two reports 
diff_reports() {
    local r1="${1:-}"
    local r2="${2:-}"
    if [[ -z "${r1}" || -z "${r2}" ]]; then
        echo "Usage: $0 diff <report1.txt> <report2.txt>"
        return 1
    fi
    color_echo CYAN "Comparing reports:"
    color_echo CYAN "  A: ${r1}"
    color_echo CYAN "  B: ${r2}"
    diff --color=always "${r1}" "${r2}" || true
}

# ── Verify report integrity 
verify_report() {
    local report="${1:-}"
    if [[ -z "${report}" ]]; then
        echo "Usage: $0 verify <report.txt>"
        return 1
    fi
    local hashfile="${report}.sha256"
    if [[ ! -f "${hashfile}" ]]; then
        log_error "Hash file not found: ${hashfile}"
        return 1
    fi
    if sha256sum --check "${hashfile}" &>/dev/null; then
        color_echo GREEN "+ Integrity OK: ${report}"
    else
        color_echo RED "- Integrity FAILED: ${report} — file may have been tampered!"
        return 1
    fi
}

# ── Entry point 
case "${1:-install}" in
    install)   install_cron; install_logrotate ;;
    remove)    remove_cron ;;
    rotate)    rotate_logs ;;
    alert)     check_cpu_alert ;;
    diff)      diff_reports "${2:-}" "${3:-}" ;;
    verify)    verify_report "${2:-}" ;;
    *)
        echo "Usage: $0 [install | remove | rotate | alert | diff <r1> <r2> | verify <report>]"
        ;;
esac
