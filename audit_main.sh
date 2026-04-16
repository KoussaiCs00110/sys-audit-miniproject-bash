#!/usr/bin/env bash
# ============================================================
#  audit_main.sh — Main entry point for the Linux Audit System
#  NSCS Mini-Project Part 1 — Academic Year 2025/2026
#  Author : belouadah saad eddine koussai 
# ============================================================
# Usage:
#   ./audit_main.sh [--short | --full] [--email <addr>] [--remote-all]
#   ./audit_main.sh --menu          (interactive mode)
# ============================================================

set -euo pipefail

# ── Resolve absolute paths 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" # the config file that contains all the variables settings 
source "${SCRIPT_DIR}/lib_colors.sh" # the color functions used to color the output 
source "${SCRIPT_DIR}/hw_audit.sh" # the hardware audit functions 
source "${SCRIPT_DIR}/sw_audit.sh" # the software audit functions 
source "${SCRIPT_DIR}/report.sh" # the report generation functions 
source "${SCRIPT_DIR}/email.sh" # the email functions 
source "${SCRIPT_DIR}/remote.sh" # the remote audit functions 

# ── Defaults (set the default values for the variables)
REPORT_TYPE="full"
EMAIL_ADDR="saadbelouadahchess@gmail.com"
DO_REMOTE_ALL=false
INTERACTIVE=false

# ── Argument parsing (help menu)
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --short          Generate summary report (default: full)"
    echo "  --full           Generate detailed report"
    echo "  --email <addr>   Send report to this email address"
    echo "  --remote-all     Run audit on all remote hosts in config.sh"
    echo "  --menu           Launch interactive menu"
    echo "  -h, --help       Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do # adjust the arguments of all options used by user 
    case "$1" in
        --short)      REPORT_TYPE="short" ;;
        --full)       REPORT_TYPE="full"  ;;
        --email)      shift; EMAIL_ADDR="${1:-}" ;;
        --remote-all) DO_REMOTE_ALL=true ;;
        --menu)       INTERACTIVE=true ;;
        -h|--help)    usage ;;
        *) color_echo RED "Unknown option: $1"; usage ;;
    esac
    shift
done

# ── Interactive menu (work if the user run the script with --menu options)
interactive_menu() {
    while true; do
        echo ""
        color_echo CYAN "========================================"
        color_echo CYAN "#   Linux Audit & Monitoring System    #"
        color_echo CYAN "========================================"
        echo ""
        select choice in \
            "Run Full Audit (local)" \
            "Run Short Audit (local)" \
            "Hardware Audit Only" \
            "Software Audit Only" \
            "Run Audit on All Remote Hosts" \
            "Send Last Report via Email" \
            "View Last Report" \
            "Exit"; do
            case $REPLY in
                1) REPORT_TYPE="full";  run_audit; break ;;
                2) REPORT_TYPE="short"; run_audit; break ;;
                3) hw_audit_only; break ;;
                4) sw_audit_only; break ;;
                5) run_remote_audit_all; break ;;
                6) prompt_email; break ;;
                7) view_last_report; break ;;
                8) color_echo GREEN "Goodbye."; exit 0 ;;
                *) color_echo RED "Invalid choice." ;;
            esac
        done
    done
}

# ── Core audit runner 
run_audit() {
    log_info "Starting ${REPORT_TYPE} audit on $(hostname) at $(date)"

    color_echo YELLOW "[ 1/4 ] Collecting hardware information..."
    collect_hw_info

    color_echo YELLOW "[ 2/4 ] Collecting software & OS information..."
    collect_sw_info

    color_echo YELLOW "[ 3/4 ] Generating ${REPORT_TYPE} report..."
    generate_report "${REPORT_TYPE}"

    color_echo YELLOW "[ 4/4 ] Finalising..."

    # Optional: email
    if [[ -n "${EMAIL_ADDR}" ]]; then
        color_echo YELLOW "  - Sending report to ${EMAIL_ADDR}..."
        send_report_email "${EMAIL_ADDR}" "${REPORT_TYPE}"
    fi

    # Optional: remote audit on all hosts
    if "${DO_REMOTE_ALL}"; then
        color_echo YELLOW "  - Running audit on remote hosts..."
        run_remote_audit_all
    fi

    color_echo GREEN "+ Audit complete. Reports saved to: ${REPORT_DIR}"
    log_info "Audit finished successfully."
}

hw_audit_only() {
    collect_hw_info
    color_echo GREEN "Hardware data collected."
}

sw_audit_only() {
    collect_sw_info
    color_echo GREEN "Software data collected."
}

prompt_email() {
    read -rp "Enter recipient email address: " EMAIL_ADDR
    send_report_email "${EMAIL_ADDR}" "${REPORT_TYPE}"
}

view_last_report() {
    local last
    last=$(ls -t "${REPORT_DIR}"/*.txt 2>/dev/null | head -1 || true)
    if [[ -z "${last}" ]]; then
        color_echo RED "No reports found in ${REPORT_DIR}"
    else
        less "${last}"
    fi
}

# ── Startup prompts (always run in interactive mode) 
startup_prompts() {
    color_echo CYAN "========================================"
    color_echo CYAN "#   Linux Audit & Monitoring System    #"
    color_echo CYAN "========================================"
    echo ""

    # ── Report type 
    color_echo BOLD "[ 1 / 3 ] Report type"
    echo "  1) Full report  (complete audit)"
    echo "  2) Short report (summary only)"
    echo ""
    read -rp "  Your choice [1/2, default=1]: " _choice
    case "${_choice}" in
        2) REPORT_TYPE="short" ;;
        *) REPORT_TYPE="full"  ;;
    esac
    color_echo GREEN "  → ${REPORT_TYPE} report selected."
    echo ""

    # ── Email 
    color_echo BOLD "[ 2 / 3 ] Email delivery"
    read -rp "  Send report via email? [y/N]: " _yn
    if [[ "${_yn,,}" == "y" ]]; then
        read -rp "  Recipient address: " EMAIL_ADDR
        if ! echo "${EMAIL_ADDR}" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
            color_echo YELLOW "  ⚠  That doesn't look like a valid address."
            read -rp "  Re-enter (or leave blank to skip): " EMAIL_ADDR
        fi
        if [[ -n "${EMAIL_ADDR}" ]]; then
            color_echo GREEN "  - Report will be emailed to: ${EMAIL_ADDR}"
        else
            color_echo YELLOW "  - Email skipped."
        fi
    else
        color_echo YELLOW "  - Email skipped."
    fi
    echo ""

    # ── Remote audit 
    color_echo BOLD "[ 3 / 3 ] Remote hosts audit"
    if [[ ${#REMOTE_HOSTS[@]} -gt 0 ]]; then
        echo "  ${#REMOTE_HOSTS[@]} host(s) found in config.sh"
        read -rp "  Run audit on all remote hosts? [y/N]: " _yn
        if [[ "${_yn,,}" == "y" ]]; then
            DO_REMOTE_ALL=true
            color_echo GREEN "  - Will audit all remote hosts."
        else
            color_echo YELLOW "  - Remote audit skipped."
        fi
    else
        color_echo YELLOW "  - No remote hosts configured. Skipping."
    fi
    echo ""

    # ── Confirm 
    echo "-----------------------------------------"
    color_echo BOLD "  Summary before running:"
    printf "  %-18s %s\n" "Report type:"  "${REPORT_TYPE}"
    printf "  %-18s %s\n" "Email:"        "${EMAIL_ADDR:-none}"
    printf "  %-18s %s\n" "Remote audit:" "$( ${DO_REMOTE_ALL} && echo 'yes' || echo 'no' )"
    echo "------------------------------------------"
    echo ""
    read -rp "  Start audit now? [Y/n]: " _confirm
    if [[ "${_confirm,,}" == "n" ]]; then
        color_echo YELLOW "Aborted."
        exit 0
    fi
    echo ""
}

# ── Entry point 
main() {
    mkdir -p "${REPORT_DIR}" "${LOG_DIR}"

    if "${INTERACTIVE}"; then
        interactive_menu
    else
        # Always run startup prompts unless all options were passed via flags
        if [[ -z "${EMAIL_ADDR}" ]] && ! "${DO_REMOTE_ALL}"; then
            startup_prompts
        fi
        run_audit
    fi
}

main
