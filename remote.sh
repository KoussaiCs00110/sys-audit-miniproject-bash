#!/usr/bin/env bash
# Functions for running remote audits via SSH

# parse "user@host:port:key" into variables
_parse_host_entry() {
    local entry="$1"
    R_USERHOST="${entry%%:*}"
    local rest="${entry#*:}"
    if [[ "${rest}" == "${entry}" ]]; then
        R_PORT="22"
        R_KEY=""
    else
        R_PORT="${rest%%:*}"
        R_KEY="${rest#*:}"
        [[ -z "${R_PORT}" ]] && R_PORT="22"
        [[ "${R_KEY}" == "${R_PORT}" ]] && R_KEY=""
    fi
}

# helper for ssh flags
_build_ssh_opts() {
    local opts="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 -p ${R_PORT}"
    [[ -n "${R_KEY}" ]] && opts="${opts} -i ${R_KEY}"
    echo "${opts}"
}

# helper for scp flags
_build_scp_opts() {
    local opts="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 -P ${R_PORT}"
    [[ -n "${R_KEY}" ]] && opts="${opts} -i ${R_KEY}"
    echo "${opts}"
}

# audit one remote machine - produces TXT, JSON, HTML (same as local)
run_remote_audit_single() {
    local entry="$1"
    _parse_host_entry "${entry}"
    local ssh_opts scp_opts
    ssh_opts=$(_build_ssh_opts)
    scp_opts=$(_build_scp_opts)

    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local safe_name
    safe_name=$(echo "${R_USERHOST}" | tr '@' '_' | tr '.' '_')

    # local output paths (will be filled after download)
    local out_base="${REPORT_DIR}/remote_${safe_name}_${ts}"

    # temp folder on the remote side
    local remote_tmp="/tmp/sys_audit_${ts}"
    local remote_report_dir="${remote_tmp}/reports"

    color_echo CYAN "  Connecting to ${R_USERHOST} (port ${R_PORT})..."

    # 1. create temp folder + report dir on remote
    if ! ssh ${ssh_opts} "${R_USERHOST}" "mkdir -p '${remote_tmp}' '${remote_report_dir}'" 2>/dev/null; then
        log_error "SSH connection failed: ${R_USERHOST} (port ${R_PORT})"
        color_echo RED "  - ${R_USERHOST} - connection failed"
        echo "CONNECTION FAILED at $(date)" > "${out_base}.txt"
        return 1
    fi

    # 2. upload all scripts needed for a full report
    color_echo CYAN "  Uploading audit scripts to ${R_USERHOST}..."
    scp ${scp_opts} \
        "${SCRIPT_DIR}/hw_audit.sh" \
        "${SCRIPT_DIR}/sw_audit.sh" \
        "${SCRIPT_DIR}/lib_colors.sh" \
        "${SCRIPT_DIR}/report.sh" \
        "${SCRIPT_DIR}/config.sh" \
        "${R_USERHOST}:${remote_tmp}/" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        log_error "SCP upload failed: ${R_USERHOST}"
        color_echo RED "  - ${R_USERHOST} - failed to upload audit scripts"
        echo "SCP UPLOAD FAILED at $(date)" > "${out_base}.txt"
        return 1
    fi

    # 3. run the full audit on the remote machine (generates TXT + JSON + HTML)
    color_echo CYAN "  Running full audit on ${R_USERHOST}..."

    ssh ${ssh_opts} "${R_USERHOST}" bash <<REMOTE_WRAPPER 2>/dev/null
#!/usr/bin/env bash
set +e

# override config paths so reports go into our temp dir
REPORT_DIR='${remote_report_dir}'
LOG_DIR='/tmp'
AUDIT_LOG='/dev/null'

source '${remote_tmp}/lib_colors.sh'
source '${remote_tmp}/hw_audit.sh'
source '${remote_tmp}/sw_audit.sh'
source '${remote_tmp}/report.sh'

# collect data
collect_hw_info
collect_sw_info

# generate all three report formats (TXT, JSON, HTML) using the same
# functions as the local audit - full report by default
generate_report "full"
REMOTE_WRAPPER

    local audit_rc=$?

    # 4. download all generated reports from remote
    color_echo CYAN "  Downloading reports from ${R_USERHOST}..."

    # download TXT
    scp ${scp_opts} "${R_USERHOST}:${remote_report_dir}/"*.txt  "${REPORT_DIR}/" 2>/dev/null
    # download JSON
    scp ${scp_opts} "${R_USERHOST}:${remote_report_dir}/"*.json "${REPORT_DIR}/" 2>/dev/null
    # download HTML
    scp ${scp_opts} "${R_USERHOST}:${remote_report_dir}/"*.html "${REPORT_DIR}/" 2>/dev/null
    # download SHA256
    scp ${scp_opts} "${R_USERHOST}:${remote_report_dir}/"*.sha256 "${REPORT_DIR}/" 2>/dev/null

    # find the downloaded files and rename them with our prefix
    local downloaded_txt downloaded_json downloaded_html downloaded_sha
    downloaded_txt=$(ls -t "${REPORT_DIR}"/audit_full_*.txt 2>/dev/null | head -1)
    downloaded_json=$(ls -t "${REPORT_DIR}"/audit_full_*.json 2>/dev/null | head -1)
    downloaded_html=$(ls -t "${REPORT_DIR}"/audit_full_*.html 2>/dev/null | head -1)
    downloaded_sha=$(ls -t "${REPORT_DIR}"/audit_full_*.sha256 2>/dev/null | head -1)

    # rename to our remote_ prefix
    if [[ -n "${downloaded_txt}" && -f "${downloaded_txt}" ]]; then
        mv "${downloaded_txt}" "${out_base}.txt" 2>/dev/null
    fi
    if [[ -n "${downloaded_json}" && -f "${downloaded_json}" ]]; then
        mv "${downloaded_json}" "${out_base}.json" 2>/dev/null
    fi
    if [[ -n "${downloaded_html}" && -f "${downloaded_html}" ]]; then
        mv "${downloaded_html}" "${out_base}.html" 2>/dev/null
    fi
    if [[ -n "${downloaded_sha}" && -f "${downloaded_sha}" ]]; then
        mv "${downloaded_sha}" "${out_base}.txt.sha256" 2>/dev/null
    fi

    # 5. cleanup remote temp
    ssh ${ssh_opts} "${R_USERHOST}" "rm -rf '${remote_tmp}'" 2>/dev/null

    if [[ ${audit_rc} -eq 0 ]] && [[ -s "${out_base}.txt" ]]; then
        # store paths so email can pick them up
        LAST_REMOTE_TXT="${out_base}.txt"
        LAST_REMOTE_HTML="${out_base}.html"
        LAST_REMOTE_JSON="${out_base}.json"

        log_info "Remote audit completed: ${R_USERHOST}"
        color_echo GREEN "  + ${R_USERHOST} - audit saved"
        color_echo GREEN "    + TXT    : ${out_base}.txt"
        color_echo GREEN "    + JSON   : ${out_base}.json"
        color_echo GREEN "    + HTML   : ${out_base}.html"
        color_echo GREEN "    + SHA256 : ${out_base}.txt.sha256"
        return 0
    else
        log_error "Remote audit execution failed: ${R_USERHOST}"
        color_echo RED "  - ${R_USERHOST} - audit execution failed"
        [[ ! -s "${out_base}.txt" ]] && echo "AUDIT EXECUTION FAILED at $(date)" > "${out_base}.txt"
        return 1
    fi
}

# send the last remote report via email
send_remote_report_email() {
    local recipient="${1:-${DEFAULT_EMAIL}}"
    local txt_path="${LAST_REMOTE_TXT:-}"
    local html_path="${LAST_REMOTE_HTML:-}"

    if [[ -z "${txt_path}" || ! -f "${txt_path}" ]]; then
        log_error "No remote report file to email."
        color_echo RED "  - No remote report found. Run a remote audit first."
        return 1
    fi

    # basic email check
    if ! echo "${recipient}" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
        log_error "Email address looks wrong: ${recipient}"
        return 1
    fi

    local remote_host
    remote_host=$(basename "${txt_path}" | sed 's/^remote_//; s/_[0-9]*\.txt$//' | tr '_' '.')

    local subject="${EMAIL_SUBJECT_PREFIX} Remote Audit - ${remote_host} - $(date '+%Y-%m-%d')"

    color_echo CYAN "  Mailing remote report to ${recipient}..."

    # temporarily swap the LAST_REPORT paths so the email function picks up remote reports
    local saved_txt="${LAST_REPORT_TXT:-}"
    local saved_html="${LAST_REPORT_HTML:-}"
    LAST_REPORT_TXT="${txt_path}"
    LAST_REPORT_HTML="${html_path}"

    send_report_email "${recipient}" "full"

    # restore
    LAST_REPORT_TXT="${saved_txt}"
    LAST_REPORT_HTML="${saved_html}"
}

# loop through all remote hosts
run_remote_audit_all() {
    if [[ ${#REMOTE_HOSTS[@]} -eq 0 ]]; then
        color_echo YELLOW "  No remote hosts configured in config.sh"
        return 0
    fi

    local total=${#REMOTE_HOSTS[@]}
    local success=0
    local failed=0

    color_echo CYAN "  Starting remote audit on ${total} host(s)..."
    echo ""

    for entry in "${REMOTE_HOSTS[@]}"; do
        [[ -z "${entry}" || "${entry}" == \#* ]] && continue

        if run_remote_audit_single "${entry}"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    color_echo CYAN "  -- Remote Audit Summary --"
    color_echo GREEN "  + Success: ${success}"
    [[ ${failed} -gt 0 ]] && color_echo RED "  - Failed:  ${failed}"
    color_echo CYAN "  Reports saved to: ${REPORT_DIR}"
}

# push report to remote server
push_report_remote() {
    local target="${1:-}"
    local report_path="${LAST_REPORT_TXT:-}"

    if [[ -z "${target}" ]]; then
        log_error "No remote target specified."
        return 1
    fi

    if [[ -z "${report_path}" || ! -f "${report_path}" ]]; then
        log_error "No report file found."
        return 1
    fi

    _parse_host_entry "${target}"
    local ssh_opts scp_opts
    ssh_opts=$(_build_ssh_opts)
    scp_opts=$(_build_scp_opts)

    color_echo CYAN "  Creating remote directory on ${R_USERHOST}..."
    if ssh ${ssh_opts} "${R_USERHOST}" "mkdir -p '${REMOTE_REPORT_DIR}'" 2>/dev/null; then
        color_echo CYAN "  Transferring report..."
        scp ${scp_opts} "${report_path}" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        [[ -f "${report_path%.txt}.json" ]] && scp ${scp_opts} "${report_path%.txt}.json" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        [[ -f "${report_path%.txt}.html" ]] && scp ${scp_opts} "${report_path%.txt}.html" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        [[ -f "${report_path}.sha256" ]] && scp ${scp_opts} "${report_path}.sha256" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        log_info "Report pushed to ${R_USERHOST}"
        color_echo GREEN "  + Remote push complete."
    else
        log_error "SSH connection failed."
        return 1
    fi
}
