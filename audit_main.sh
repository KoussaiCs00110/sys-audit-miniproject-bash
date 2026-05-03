#!/usr/bin/env bash
# Main script for the audit project
# Author : belouadah saad eddine koussai 

set -euo pipefail

# resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# import other scripts
source "${SCRIPT_DIR}/config.sh" 
source "${SCRIPT_DIR}/lib_colors.sh" 
source "${SCRIPT_DIR}/hw_audit.sh" 
source "${SCRIPT_DIR}/sw_audit.sh" 
source "${SCRIPT_DIR}/report.sh" 
source "${SCRIPT_DIR}/email.sh" 
source "${SCRIPT_DIR}/remote.sh" 

# default values
REPORT_TYPE="full"
EMAIL_ADDR="saadbelouadahchess@gmail.com"
DO_REMOTE_ALL=false
INTERACTIVE=false

# help message
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

# parse arguments
while [[ $# -gt 0 ]]; do 
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

# interactive menu
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
            "Send Last Local Report via Email" \
            "Send Last Remote Report via Email" \
            "View Last Report" \
            "Exit"; do
            case $REPLY in
                1) REPORT_TYPE="full";  run_audit; break ;;
                2) REPORT_TYPE="short"; run_audit; break ;;
                3) hw_audit_only; break ;;
                4) sw_audit_only; break ;;
                5) run_remote_audit_all; break ;;
                6) prompt_email; break ;;
                7) prompt_remote_email; break ;;
                8) view_last_report; break ;;
                9) color_echo GREEN "Goodbye."; exit 0 ;;
                *) color_echo RED "Invalid choice." ;;
            esac
        done
    done
}

# audit runner
run_audit() {
    log_info "Starting ${REPORT_TYPE} audit on $(hostname) at $(date)"

    color_echo YELLOW "[ 1/4 ] Collecting hardware information..."
    collect_hw_info

    color_echo YELLOW "[ 2/4 ] Collecting software & OS information..."
    collect_sw_info

    color_echo YELLOW "[ 3/4 ] Generating ${REPORT_TYPE} report..."
    generate_report "${REPORT_TYPE}"

    color_echo YELLOW "[ 4/4 ] Finalising..."

    # email report
    if [[ -n "${EMAIL_ADDR}" ]]; then
        color_echo YELLOW "  - Sending report to ${EMAIL_ADDR}..."
        send_report_email "${EMAIL_ADDR}" "${REPORT_TYPE}"
    fi

    # remote audit
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

prompt_remote_email() {
    read -rp "Enter recipient email address: " EMAIL_ADDR
    send_remote_report_email "${EMAIL_ADDR}"
}

view_last_report() {
    echo ""
    color_echo CYAN "Available reports in ${REPORT_DIR}:"
    echo ""

    # list recent reports grouped by base name
    local last_txt last_html last_json
    last_txt=$(ls -t "${REPORT_DIR}"/*.txt 2>/dev/null | head -1 || true)
    last_html=$(ls -t "${REPORT_DIR}"/*.html 2>/dev/null | head -1 || true)
    last_json=$(ls -t "${REPORT_DIR}"/*.json 2>/dev/null | head -1 || true)

    if [[ -z "${last_txt}" && -z "${last_html}" && -z "${last_json}" ]]; then
        color_echo RED "No reports found in ${REPORT_DIR}"
        return
    fi

    [[ -n "${last_txt}" ]]  && color_echo GREEN "  TXT:  ${last_txt}"
    [[ -n "${last_json}" ]] && color_echo GREEN "  JSON: ${last_json}"
    [[ -n "${last_html}" ]] && color_echo GREEN "  HTML: ${last_html}"
    echo ""

    select fmt in "View TXT" "View HTML (in browser)" "View JSON" "Back"; do
        case $REPLY in
            1)
                if [[ -n "${last_txt}" ]]; then
                    less "${last_txt}"
                else
                    color_echo RED "No TXT report found."
                fi
                break ;;
            2)
                if [[ -n "${last_html}" ]]; then
                    if command -v xdg-open &>/dev/null; then
                        xdg-open "${last_html}" 2>/dev/null &
                        color_echo GREEN "  Opened in browser."
                    else
                        less "${last_html}"
                    fi
                else
                    color_echo RED "No HTML report found."
                fi
                break ;;
            3)
                if [[ -n "${last_json}" ]]; then
                    if command -v jq &>/dev/null; then
                        jq '.' "${last_json}" | less
                    else
                        less "${last_json}"
                    fi
                else
                    color_echo RED "No JSON report found."
                fi
                break ;;
            4) break ;;
            *) color_echo RED "Invalid choice." ;;
        esac
    done
}

# prompts at startup
startup_prompts() {
    color_echo CYAN "========================================"
    color_echo CYAN "#   Linux Audit & Monitoring System    #"
    color_echo CYAN "========================================"
    echo ""

    # report type
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

    # email
    color_echo BOLD "[ 2 / 3 ] Email delivery"
    read -rp "  Send report via email? [y/N]: " _yn
    if [[ "${_yn,,}" == "y" ]]; then
        read -rp "  Recipient address: " EMAIL_ADDR
        if ! echo "${EMAIL_ADDR}" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
            color_echo YELLOW "  ⚠  That doesn't look like a valid address."
            read -rp "  Re-enter (or leave blank to skip): " EMAIL_ADDR
        fi
    fi
    echo ""

    # remote hosts
    color_echo BOLD "[ 3 / 3 ] Remote hosts audit"
    if [[ ${#REMOTE_HOSTS[@]} -gt 0 ]]; then
        echo "  ${#REMOTE_HOSTS[@]} host(s) found in config.sh"
        read -rp "  Run audit on all remote hosts? [y/N]: " _yn
        if [[ "${_yn,,}" == "y" ]]; then
            DO_REMOTE_ALL=true
        fi
    else
        color_echo YELLOW "  - No remote hosts configured. Skipping."
    fi
    echo ""

    # confirm summary
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

# main
main() {
    mkdir -p "${REPORT_DIR}" "${LOG_DIR}"

    if "${INTERACTIVE}"; then
        interactive_menu
    else
        # show prompts if not everything passed by flags
        if [[ -z "${EMAIL_ADDR}" ]] && ! "${DO_REMOTE_ALL}"; then
            startup_prompts
        fi
        run_audit
    fi
}

main
