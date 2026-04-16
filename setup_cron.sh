#!/usr/bin/env bash
# script to setup cron jobs and clean up old logs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib_colors.sh"

AUDIT_CMD="${SCRIPT_DIR}/audit_main.sh --full"
CRON_TAG="# sys_audit"

# add line to crontab
install_cron() {
    ( crontab -l 2>/dev/null | grep -v "${CRON_TAG}" ; \
      echo "${CRON_SCHEDULE} ${AUDIT_CMD} >> ${LOG_DIR}/cron_exec.log 2>&1 ${CRON_TAG}" \
    ) | crontab -

    color_echo GREEN "Cron job added: ${CRON_SCHEDULE}"
}

# clean up crontab
remove_cron() {
    crontab -l 2>/dev/null | grep -v "${CRON_TAG}" | crontab - || true
    color_echo YELLOW "Cron job removed."
}

# delete files older than rentention period
rotate_logs() {
    color_echo CYAN "Cleaning up logs older than ${LOG_RETENTION_DAYS} days..."
    find "${REPORT_DIR}" -type f -mtime "+${LOG_RETENTION_DAYS}" -delete
    find "${LOG_DIR}"    -type f -mtime "+${LOG_RETENTION_DAYS}" -delete
    color_echo GREEN "Logs rotated."
}

# system logrotate config
install_logrotate() {
    local conf="/etc/logrotate.d/sys_audit"
    if [[ $EUID -ne 0 ]]; then
        return
    fi

    cat > "${conf}" <<LOGROTATE
${REPORT_DIR}/*.txt ${LOG_DIR}/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
}
LOGROTATE

    color_echo GREEN "logrotate config written to ${conf}"
}

# simple cpu alert
check_cpu_alert() {
    local usage
    usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int(100-$8)}' || echo "0")
    if (( usage > CPU_ALERT_THRESHOLD )); then
        local msg="CPU ALERT: usage is ${usage}%"
        log_warn "${msg}"
        if [[ -n "${DEFAULT_EMAIL}" ]]; then
            echo "${msg}" | mail -s "CPU Alert" "${DEFAULT_EMAIL}" 2>/dev/null || true
        fi
    fi
}

# compare two files
diff_reports() {
    local r1="${1:-}"
    local r2="${2:-}"
    if [[ -z "${r1}" || -z "${r2}" ]]; then
        echo "Usage: $0 diff <val1> <val2>"
        return 1
    fi
    diff --color=always "${r1}" "${r2}" || true
}

# check sha256
verify_report() {
    local report="${1:-}"
    if [[ -z "${report}" ]]; then
        return 1
    fi
    local hashfile="${report}.sha256"
    if [[ ! -f "${hashfile}" ]]; then
        log_error "No hash file."
        return 1
    fi
    if sha256sum --check "${hashfile}" &>/dev/null; then
        color_echo GREEN "Integrity OK."
    else
        color_echo RED "Integrity check FAILED."
        return 1
    fi
}

# main loop
case "${1:-install}" in
    install|set) install_cron; install_logrotate ;;
    remove|unset) remove_cron ;;
    rotate|clean) rotate_logs ;;
    alert|check) check_cpu_alert ;;
    diff) diff_reports "${2:-}" "${3:-}" ;;
    verify) verify_report "${2:-}" ;;
    *)
        echo "Usage: $0 [install | remove | rotate | alert | diff | verify]"
        ;;
esac
