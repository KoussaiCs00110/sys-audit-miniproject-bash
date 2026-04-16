#!/usr/bin/env bash
# colors and logging stuff

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# print with a specific color
color_echo() {
    local color_name="$1"
    local msg="$2"
    local code="${!color_name:-}"
    echo -e "${code}${msg}${RESET}"
}

# functions for logging with timestamps
log_info() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  ${msg}" >> "${AUDIT_LOG:-/tmp/audit.log}"
}

log_warn() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  ${msg}" >> "${AUDIT_LOG:-/tmp/audit.log}"
    color_echo YELLOW "x  ${msg}"
}

log_error() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${msg}" >> "${AUDIT_LOG:-/tmp/audit.log}"
    color_echo RED "-  ${msg}" >&2
}

# visual divider
separator() {
    printf '%0.s─' {1..70} 
    echo ""
}

# bold header for sections
section_header() {
    local title="$1"
    echo ""
    color_echo BOLD "| ${title}"
    separator
}
