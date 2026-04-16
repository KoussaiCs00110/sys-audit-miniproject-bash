#!/usr/bin/env bash
# ============================================================
#  email.sh — Simple Email Report Module
#  Sends the plain text report via email.
# ============================================================

# send_report_email <recipient> <report_type>
_build_mime() {
    local recipient="$1"
    local subject="$2"
    local txt_path="$3"
    local html_path="$4"
    local boundary="----=_Part_$(date +%s)_MIME_BOUNDARY"

    echo "To: ${recipient}"
    echo "Subject: ${subject}"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"${boundary}\""
    echo ""
    echo "This is a multi-part message in MIME format."
    echo ""
    echo "--${boundary}"
    echo "Content-Type: text/html; charset=UTF-8"
    echo ""
    if [[ -n "${html_path}" && -f "${html_path}" ]]; then
        cat "${html_path}"
    else
        echo "<p>Please find the audit report attached.</p>"
    fi
    echo ""
    echo "--${boundary}"
    echo "Content-Type: text/plain; name=\"$(basename "${txt_path}")\""
    echo "Content-Disposition: attachment; filename=\"$(basename "${txt_path}")\""
    echo "Content-Transfer-Encoding: base64"
    echo ""
    base64 "${txt_path}"
    echo ""
    echo "--${boundary}--"
}

send_report_email() {
    local recipient="${1:-${DEFAULT_EMAIL}}" # empty email address => use default email address 
    local type="${2:-full}" # empty report type => use full report type 
    local txt_path="${LAST_REPORT_TXT:-}" # empty report path => use last report path 
    local html_path="${LAST_REPORT_HTML:-}" # HTML report for the email body

    # --- Validate report file exists ---
    if [[ -z "${txt_path}" || ! -f "${txt_path}" ]]; then # check if the report file is empty or not found 
        log_error "No report found. Generate a report first."
        return 1
    fi

    # --- Validate email address ---
    if ! echo "${recipient}" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then # check if the email address is valid 
        log_error "Invalid email address: ${recipient}"
        return 1
    fi

    local subject="${EMAIL_SUBJECT_PREFIX} $(hostname -s) — ${type^} Audit — $(date '+%Y-%m-%d')" # define subject of the email 

    color_echo CYAN "  Sending report to ${recipient} using ${MAIL_TOOL}..."

    case "${MAIL_TOOL}" in # check the mail tool 
        msmtp) 
            if ! command -v msmtp &>/dev/null; then # check if the mail tool is installed 
                log_error "msmtp not found. Install: sudo apt install msmtp"
                return 1
            fi
            (echo "From: ${DEFAULT_EMAIL}"; _build_mime "${recipient}" "${subject}" "${txt_path}" "${html_path}") | msmtp -a default "${recipient}" # send the report to the recipient 
            ;;
        mail|mailx)
            if ! command -v "${MAIL_TOOL}" &>/dev/null; then # check if the mail tool is installed 
                log_error "${MAIL_TOOL} not found."
                return 1
            fi
            "${MAIL_TOOL}" -s "${subject}" "${recipient}" < "${txt_path}" # send the report to the recipient 
            ;;
        sendmail)
            if ! command -v sendmail &>/dev/null; then # check if the mail tool is installed 
                log_error "sendmail not found."
                return 1
            fi
            _build_mime "${recipient}" "${subject}" "${txt_path}" "${html_path}" | sendmail "${recipient}" # send the report to the recipient 
            ;;
        *)
            log_error "Unknown MAIL_TOOL '${MAIL_TOOL}' in config.sh" # unknown mail tool 
            return 1
            ;;
    esac

    log_info "Report emailed to ${recipient} via ${MAIL_TOOL}"
    color_echo GREEN "  ✔ Email sent successfully."
}
