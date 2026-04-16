#!/usr/bin/env bash
# ============================================================
#  remote.sh — Multi-Host Remote Audit Module
#  Connects to hosts defined in REMOTE_HOSTS (config.sh),
#  copies hw_audit.sh & sw_audit.sh to each remote host,
#  runs them, collects the output, and sends the report to
#  the administrator's PC.
# ============================================================

# _parse_host_entry <entry>
# Parses "user@host:port:ssh_key" into variables.
_parse_host_entry() {
    local entry="$1"
    # Format: user@host:port:key_path
    R_USERHOST="${entry%%:*}"
    local rest="${entry#*:}"
    if [[ "${rest}" == "${entry}" ]]; then
        # No colon found — only user@host
        R_PORT="22"
        R_KEY=""
    else
        R_PORT="${rest%%:*}"
        R_KEY="${rest#*:}"
        # If port was empty, default to 22
        [[ -z "${R_PORT}" ]] && R_PORT="22"
        # If key is same as port (no second colon), clear it
        [[ "${R_KEY}" == "${R_PORT}" ]] && R_KEY=""
    fi
}

# _build_ssh_opts
# Builds SSH options string from parsed host entry.
_build_ssh_opts() {
    local opts="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 -p ${R_PORT}"
    [[ -n "${R_KEY}" ]] && opts="${opts} -i ${R_KEY}"
    echo "${opts}"
}

# _build_scp_opts
# Builds SCP options string from parsed host entry.
_build_scp_opts() {
    local opts="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 -P ${R_PORT}"
    [[ -n "${R_KEY}" ]] && opts="${opts} -i ${R_KEY}"
    echo "${opts}"
}

# run_remote_audit_single <host_entry>
# Connects to one host, copies hw_audit.sh & sw_audit.sh,
# runs them, and saves the output locally.
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
    local output_file="${REPORT_DIR}/remote_${safe_name}_${ts}.txt"

    # Remote temporary directory for audit scripts
    local remote_tmp="/tmp/sys_audit_${ts}"

    color_echo CYAN "  Connecting to ${R_USERHOST} (port ${R_PORT})..."

    # --- Step 1: Create temp directory on remote host ---
    # shellcheck disable=SC2086
    if ! ssh ${ssh_opts} "${R_USERHOST}" "mkdir -p '${remote_tmp}'" 2>/dev/null; then
        log_error "SSH connection failed: ${R_USERHOST} (port ${R_PORT})"
        color_echo RED "  - ${R_USERHOST} — connection failed"
        echo "CONNECTION FAILED at $(date)" > "${output_file}"
        return 1
    fi

    # --- Step 2: Copy audit scripts to remote host ---
    color_echo CYAN "  Uploading hw_audit.sh & sw_audit.sh to ${R_USERHOST}..."
    # shellcheck disable=SC2086
    scp ${scp_opts} \
        "${SCRIPT_DIR}/hw_audit.sh" \
        "${SCRIPT_DIR}/sw_audit.sh" \
        "${SCRIPT_DIR}/lib_colors.sh" \
        "${R_USERHOST}:${remote_tmp}/" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        log_error "SCP upload failed: ${R_USERHOST}"
        color_echo RED "  ✖ ${R_USERHOST} — failed to upload audit scripts"
        echo "SCP UPLOAD FAILED at $(date)" > "${output_file}"
        return 1
    fi

    # --- Step 3: Run hw_audit.sh & sw_audit.sh on remote host ---
    color_echo CYAN "  Running hw_audit.sh & sw_audit.sh on ${R_USERHOST}..."

    # Build a wrapper script that sources the audit modules and runs them.
    # The wrapper generates a text report directly on the remote host.
    # shellcheck disable=SC2086,SC2029
    ssh ${ssh_opts} "${R_USERHOST}" bash <<REMOTE_WRAPPER > "${output_file}" 2>/dev/null
#!/usr/bin/env bash
# --- Setup logging stubs & color helpers ---
AUDIT_LOG="/dev/null"
source '${remote_tmp}/lib_colors.sh'
source '${remote_tmp}/hw_audit.sh'
source '${remote_tmp}/sw_audit.sh'

# --- Run both audits ---
collect_hw_info
collect_sw_info

# --- Generate a text report to stdout ---
echo "########################################################################"
printf "#  %-68s  #\n" "REMOTE SYSTEM AUDIT REPORT"
echo "########################################################################"
printf "#  %-68s  #\n" "Hostname  : \$(hostname -f 2>/dev/null || hostname)"
printf "#  %-68s  #\n" "Date/Time : \$(date '+%A, %d %B %Y — %H:%M:%S %Z')"
printf "#  %-68s  #\n" "Run by    : \$(whoami)"
echo "########################################################################"
echo ""

echo "--------------------  HARDWARE AUDIT  ------------------------------"
echo ""
echo "| CPU"
printf "  %-20s %s\n" "Model:"        "\${HW[cpu_model]}"
printf "  %-20s %s\n" "Architecture:" "\${HW[cpu_arch]}"
printf "  %-20s %s\n" "Cores:"        "\${HW[cpu_cores]}"
printf "  %-20s %s\n" "Frequency:"    "\${HW[cpu_freq]}"
printf "  %-20s %s\n" "Cache:"        "\${HW[cpu_cache]}"
printf "  %-20s %s\n" "CPU Usage:"    "\${HW[cpu_usage]}"
echo ""
echo "| MEMORY"
printf "  %-20s %s\n" "Total RAM:"   "\${HW[ram_total]}"
printf "  %-20s %s\n" "Used:"        "\${HW[ram_used]}"
printf "  %-20s %s\n" "Available:"   "\${HW[ram_available]}"
printf "  %-20s %s\n" "Free:"        "\${HW[ram_free]}"
printf "  %-20s %s\n" "Swap Total:"  "\${HW[swap_total]}"
printf "  %-20s %s\n" "Swap Free:"   "\${HW[swap_free]}"
echo ""
echo "| GPU"
echo "  \${HW[gpu]}"
echo ""
echo "| DISK"
echo "  Root (/) : \${HW[disk_root_usage]}"
echo ""
echo "  Block devices:"
echo "\${HW[disk_layout]}" | sed 's/^/    /'
echo ""
echo "  Filesystem usage:"
echo "\${HW[disk_usage]}" | sed 's/^/    /'
echo ""
echo "| NETWORK"
echo "  Interfaces & IPs:"
echo "\${HW[net_interfaces]}" | sed 's/^/    /'
echo ""
echo "  MAC Addresses:"
echo "\${HW[net_mac]}" | sed 's/^/    /'
printf "\n  %-20s %s\n" "Default Gateway:" "\${HW[net_gateway]}"
printf "  %-20s %s\n"   "DNS Servers:"     "\${HW[net_dns]}"
echo ""
printf "  %-20s %s\n" "System Uptime:" "\${HW[uptime]}"
echo ""

echo "----------------------  SOFTWARE AUDIT  ----------------------------"
echo ""
echo "| OPERATING SYSTEM"
printf "  %-20s %s\n" "OS:"       "\${SW[os_name]}"
printf "  %-20s %s\n" "Version:"  "\${SW[os_version]}"
printf "  %-20s %s\n" "Kernel:"   "\${SW[kernel]}"
printf "  %-20s %s\n" "Arch:"     "\${SW[arch]}"
printf "  %-20s %s\n" "Hostname:" "\${SW[hostname]}"
printf "  %-20s %s\n" "Timezone:" "\${SW[timezone]}"
echo ""
echo "| INSTALLED PACKAGES"
printf "  %-20s %s\n" "Manager:" "\${SW[pkg_manager]}"
printf "  %-20s %s\n" "Count:"   "\${SW[pkg_count]}"
echo ""
echo "| LOGGED-IN USERS"
echo "\${SW[logged_users]}" | sed 's/^/  /'
echo ""
echo "| RUNNING SERVICES"
echo "\${SW[services_active]}" | sed 's/^/  /'
echo ""
echo "| FAILED SERVICES"
echo "\${SW[services_failed]}" | sed 's/^/  /'
echo ""
echo "| TOP PROCESSES (by CPU)"
echo "\${SW[top_processes]}" | sed 's/^/  /'
echo ""
echo "| OPEN PORTS"
echo "\${SW[open_ports]}" | sed 's/^/  /'
echo ""
echo "| FIREWALL STATUS"
echo "\${SW[firewall]}" | sed 's/^/  /'
echo ""

echo "--------------------------------------------------------------------"
echo "  Report generated by Linux Audit System — NSCS 2025/2026"
echo "  \$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "--------------------------------------------------------------------"
REMOTE_WRAPPER

    local audit_rc=$?

    # --- Step 4: Clean up remote temp files ---
    # shellcheck disable=SC2086,SC2029
    ssh ${ssh_opts} "${R_USERHOST}" "rm -rf '${remote_tmp}'" 2>/dev/null

    if [[ ${audit_rc} -eq 0 ]] && [[ -s "${output_file}" ]]; then
        log_info "Remote audit completed: ${R_USERHOST} -> ${output_file}"
        color_echo GREEN "  + ${R_USERHOST} — audit saved to ${output_file}"
        return 0
    else
        log_error "Remote audit execution failed: ${R_USERHOST}"
        color_echo RED "  - ${R_USERHOST} — audit execution failed"
        [[ ! -s "${output_file}" ]] && echo "AUDIT EXECUTION FAILED at $(date)" > "${output_file}"
        return 1
    fi
}

# run_remote_audit_all
# Loops through all REMOTE_HOSTS and runs audit on each one.
run_remote_audit_all() {
    if [[ ${#REMOTE_HOSTS[@]} -eq 0 ]]; then
        color_echo YELLOW "  No remote hosts configured in config.sh"
        color_echo YELLOW "  Add hosts to the REMOTE_HOSTS array to use this feature."
        return 0
    fi

    local total=${#REMOTE_HOSTS[@]}
    local success=0
    local failed=0

    color_echo CYAN "  Starting remote audit on ${total} host(s)..."
    echo ""

    for entry in "${REMOTE_HOSTS[@]}"; do
        # Skip empty lines and comments
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
    if [[ ${failed} -gt 0 ]]; then
        color_echo RED "  - Failed:  ${failed}"
    fi
    color_echo CYAN "  Reports saved to: ${REPORT_DIR}"
    color_echo GREEN "  + All reports collected on this PC (administrator)."
}


# push_report_remote <user@host>
# Pushes the last generated report to a single remote server via SCP.
push_report_remote() {
    local target="${1:-}"
    local report_path="${LAST_REPORT_TXT:-}"

    if [[ -z "${target}" ]]; then
        log_error "No remote target specified."
        return 1
    fi

    if [[ -z "${report_path}" || ! -f "${report_path}" ]]; then
        log_error "No report file found. Generate a report first."
        return 1
    fi

    _parse_host_entry "${target}"
    local ssh_opts scp_opts
    ssh_opts=$(_build_ssh_opts)
    scp_opts=$(_build_scp_opts)

    color_echo CYAN "  Creating remote directory on ${R_USERHOST}..."
    # shellcheck disable=SC2029,SC2086
    if ssh ${ssh_opts} "${R_USERHOST}" "mkdir -p '${REMOTE_REPORT_DIR}'" 2>/dev/null; then
        color_echo CYAN "  Transferring report..."
        # shellcheck disable=SC2086
        scp ${scp_opts} "${report_path}" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        # Also send JSON and SHA256 if they exist
        [[ -f "${report_path%.txt}.json" ]] && scp ${scp_opts} "${report_path%.txt}.json" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        [[ -f "${report_path}.sha256" ]] && scp ${scp_opts} "${report_path}.sha256" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null

        log_info "Report pushed to ${R_USERHOST}:${REMOTE_REPORT_DIR}/"
        color_echo GREEN "  + Remote push complete."
    else
        log_error "SSH connection to ${R_USERHOST} failed."
        return 1
    fi
}
