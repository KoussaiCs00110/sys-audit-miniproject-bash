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

# audit one remote machine
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

    # temp folder on the remote side
    local remote_tmp="/tmp/sys_audit_${ts}"

    color_echo CYAN "  Connecting to ${R_USERHOST} (port ${R_PORT})..."

    # 1. create temp folder
    if ! ssh ${ssh_opts} "${R_USERHOST}" "mkdir -p '${remote_tmp}'" 2>/dev/null; then
        log_error "SSH connection failed: ${R_USERHOST} (port ${R_PORT})"
        color_echo RED "  - ${R_USERHOST} — connection failed"
        echo "CONNECTION FAILED at $(date)" > "${output_file}"
        return 1
    fi

    # 2. upload scripts
    color_echo CYAN "  Uploading hw_audit.sh & sw_audit.sh to ${R_USERHOST}..."
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

    # 3. run the audit on the remote machine
    color_echo CYAN "  Running hw_audit.sh & sw_audit.sh on ${R_USERHOST}..."

    ssh ${ssh_opts} "${R_USERHOST}" bash <<REMOTE_WRAPPER > "${output_file}" 2>/dev/null
#!/usr/bin/env bash
AUDIT_LOG="/dev/null"
source '${remote_tmp}/lib_colors.sh'
source '${remote_tmp}/hw_audit.sh'
source '${remote_tmp}/sw_audit.sh'

collect_hw_info
collect_sw_info

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

    # 4. cleanup
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
        [[ -f "${report_path}.sha256" ]] && scp ${scp_opts} "${report_path}.sha256" "${R_USERHOST}:${REMOTE_REPORT_DIR}/" 2>/dev/null
        log_info "Report pushed to ${R_USERHOST}"
        color_echo GREEN "  + Remote push complete."
    else
        log_error "SSH connection failed."
        return 1
    fi
}
