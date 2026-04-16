#!/usr/bin/env bash
# script to send emails

# helper to build the email message with HTML body and TXT attachment
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
    echo "MIME message"
    echo ""
    echo "--${boundary}"
    echo "Content-Type: text/html; charset=UTF-8"
    echo ""
    if [[ -n "${html_path}" && -f "${html_path}" ]]; then
        cat "${html_path}"
    else
        echo "<p>See attachment for audit report.</p>"
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

# main function for sending reports
send_report_email() {
    local recipient="${1:-${DEFAULT_EMAIL}}" 
    local type="${2:-full}" 
    local txt_path="${LAST_REPORT_TXT:-}" 
    local html_path="${LAST_REPORT_HTML:-}" 

    # make sure report file exists
    if [[ -z "${txt_path}" || ! -f "${txt_path}" ]]; then 
        log_error "Can't find report file."
        return 1
    fi

    # basic email check
    if ! echo "${recipient}" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then 
        log_error "Email address looks wrong: ${recipient}"
        return 1
    fi

    local subject="${EMAIL_SUBJECT_PREFIX} $(hostname -s) — ${type^} Audit — $(date '+%Y-%m-%d')" 

    color_echo CYAN "  Mailing report to ${recipient}..."

    # choose tool based on config
    case "${MAIL_TOOL}" in 
        msmtp) 
            if ! command -v msmtp &>/dev/null; then 
                log_error "msmtp is missing."
                return 1
            fi
            (echo "From: ${DEFAULT_EMAIL}"; _build_mime "${recipient}" "${subject}" "${txt_path}" "${html_path}") | msmtp -a default "${recipient}" 
            ;;
        mail|mailx)
            if ! command -v "${MAIL_TOOL}" &>/dev/null; then 
                log_error "${MAIL_TOOL} is missing."
                return 1
            fi
            "${MAIL_TOOL}" -s "${subject}" "${recipient}" < "${txt_path}" 
            ;;
        sendmail)
            if ! command -v sendmail &>/dev/null; then 
                log_error "sendmail is missing."
                return 1
            fi
            _build_mime "${recipient}" "${subject}" "${txt_path}" "${html_path}" | sendmail "${recipient}" 
            ;;
        *)
            log_error "Unknown tool in config: ${MAIL_TOOL}" 
            return 1
            ;;
    esac

    log_info "Email sent to ${recipient}"
}
