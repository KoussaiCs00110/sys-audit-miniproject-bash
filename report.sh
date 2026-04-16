#!/usr/bin/env bash
# Functions to generate reports (TXT, JSON, HTML)

# helper to make filenames based on date and hostname
_report_base() {
    local type="$1"   # short or full
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    echo "${REPORT_DIR}/audit_${type}_$(hostname -s)_${ts}"
}

LAST_REPORT_TXT=""   
LAST_REPORT_HTML=""  

# main function that calls the others
generate_report() {
    local type="${1:-full}"
    local base
    base=$(_report_base "${type}")

    # write all formats
    _write_txt_report  "${type}" "${base}.txt"
    _write_json_report "${type}" "${base}.json"
    _write_html_report "${type}" "${base}.html"

    # integrity check
    sha256sum "${base}.txt" > "${base}.txt.sha256"

    LAST_REPORT_TXT="${base}.txt"
    LAST_REPORT_HTML="${base}.html"
    
    log_info "Reports saved: ${base}.{txt,json,html}"
    color_echo GREEN "  + TXT    → ${base}.txt"
    color_echo GREEN "  + HTML   → ${base}.html"
    color_echo GREEN "  + JSON   → ${base}.json"
    color_echo GREEN "  + SHA256 → ${base}.txt.sha256"
} 

# create TXT report
_write_txt_report() {
    local type="$1"
    local path="$2"

    {
        _txt_banner   "${type}"
        _txt_hw_section  "${type}"
        _txt_sw_section  "${type}"
        _txt_footer
    } > "${path}"
}

# report header
_txt_banner() {
    local type="$1"
    local label
    [[ "${type}" == "short" ]] && label="SUMMARY REPORT" || label="FULL AUDIT REPORT"

    echo "------------------------------------------------------------------------"
    printf  "|  %-68s  |\n" "LINUX SYSTEM AUDIT — ${label}"
    echo "------------------------------------------------------------------------"
    printf  "|  %-68s  |\n" "Hostname  : $(hostname -f 2>/dev/null || hostname)"
    printf  "|  %-68s  |\n" "Date/Time : $(date '+%A, %d %B %Y — %H:%M:%S %Z')"
    printf  "|  %-68s  |\n" "Run by    : $(whoami)"
    echo "------------------------------------------------------------------------"
    echo ""
}

# HW info section
_txt_hw_section() {
    local type="$1"

    echo "--------------  HARDWARE AUDIT  --------------------"
    echo ""

    # CPU
    echo "| CPU"
    printf "  %-20s %s\n" "Model:"        "${HW[cpu_model]}"
    printf "  %-20s %s\n" "Architecture:" "${HW[cpu_arch]}"
    printf "  %-20s %s\n" "Cores:"        "${HW[cpu_cores]}"
    printf "  %-20s %s\n" "Frequency:"    "${HW[cpu_freq]}"
    if [[ "${type}" == "full" ]]; then
        printf "  %-20s %s\n" "Cache:"    "${HW[cpu_cache]}"
        printf "  %-20s %s\n" "CPU Usage:""${HW[cpu_usage]}"
    fi
    echo ""

    # RAM
    echo "| MEMORY"
    printf "  %-20s %s\n" "Total RAM:"     "${HW[ram_total]}"
    printf "  %-20s %s\n" "Used:"          "${HW[ram_used]}"
    printf "  %-20s %s\n" "Available:"     "${HW[ram_available]}"
    if [[ "${type}" == "full" ]]; then
        printf "  %-20s %s\n" "Free:"      "${HW[ram_free]}"
        printf "  %-20s %s\n" "Swap Total:""${HW[swap_total]}"
        printf "  %-20s %s\n" "Swap Free:" "${HW[swap_free]}"
    fi
    echo ""

    # GPU
    echo "| GPU"
    echo "  ${HW[gpu]}"
    echo ""

    # Disk
    echo "| DISK"
    if [[ "${type}" == "short" ]]; then
        printf "  %-20s %s\n" "Root (/):" "${HW[disk_root_usage]}"
    else
        echo "  Block devices:"
        echo "${HW[disk_layout]}" | sed 's/^/    /'
        echo ""
        echo "  Filesystem usage:"
        echo "${HW[disk_usage]}" | sed 's/^/    /'
    fi
    echo ""

    # Network
    echo "| NETWORK"
    if [[ "${type}" == "short" ]]; then
        echo "${HW[net_interfaces]}" | awk '{printf "  %-15s %s\n", $1, $3}' | (head -6 || true) || true
    else
        echo "  Interfaces & IPs:"
        echo "${HW[net_interfaces]}" | sed 's/^/    /'
        echo ""
        echo "  MAC Addresses:"
        echo "${HW[net_mac]}" | sed 's/^/    /'
        printf "\n  %-20s %s\n" "Default Gateway:" "${HW[net_gateway]}"
        printf "  %-20s %s\n"   "DNS Servers:"     "${HW[net_dns]}"
    fi
    echo ""

    if [[ "${type}" == "full" ]]; then
        # Motherboard
        echo "| MOTHERBOARD / BIOS"
        printf "  %-20s %s\n" "Vendor:"       "${HW[board_vendor]}"
        printf "  %-20s %s\n" "Product:"      "${HW[board_product]}"
        printf "  %-20s %s\n" "BIOS Vendor:"  "${HW[bios_vendor]}"
        printf "  %-20s %s\n" "BIOS Version:" "${HW[bios_version]}"
        printf "  %-20s %s\n" "Serial No.:"   "${HW[sys_serial]}"
        echo ""

        # USB
        echo "| USB DEVICES"
        echo "${HW[usb_devices]}" | sed 's/^/  /'
        echo ""

        # PCI
        echo "| PCI DEVICES"
        echo "${HW[pci_devices]}" | sed 's/^/  /'
        echo ""
    fi

    printf "  %-20s %s\n" "System Uptime:" "${HW[uptime]}"
    echo ""
}

# SW info section
_txt_sw_section() {
    local type="$1"

    echo "-----------------  SOFTWARE AUDIT  --------------------"
    echo ""

    # OS
    echo "| OPERATING SYSTEM"
    printf "  %-20s %s\n" "OS:"       "${SW[os_name]}"
    printf "  %-20s %s\n" "Version:"  "${SW[os_version]}"
    printf "  %-20s %s\n" "Kernel:"   "${SW[kernel]}"
    printf "  %-20s %s\n" "Arch:"     "${SW[arch]}"
    printf "  %-20s %s\n" "Hostname:" "${SW[hostname]}"
    if [[ "${type}" == "full" ]]; then
        printf "  %-20s %s\n" "Timezone:" "${SW[timezone]}"
        printf "  %-20s %s\n" "Locale:"   "${SW[locale]}"
        echo ""
        echo "  Kernel details:"
        printf "  %s\n" "${SW[kernel_full]}"
    fi
    echo ""

    # Packages
    echo "| INSTALLED PACKAGES"
    printf "  %-20s %s\n" "Manager:" "${SW[pkg_manager]}"
    printf "  %-20s %s\n" "Count:"   "${SW[pkg_count]}"
    if [[ "${type}" == "full" ]]; then
        echo ""
        echo "  Package list:"
        echo "${SW[pkg_list]}" | (head -50 || true) | sed 's/^/    /' || true
        echo "    ... (truncated; see full file)"
    fi
    echo ""

    # Logged-in users
    echo "| LOGGED-IN USERS"
    echo "${SW[logged_users]}" | sed 's/^/  /'
    echo ""

    if [[ "${type}" == "full" ]]; then
        echo "| LAST LOGINS (10)"
        echo "${SW[last_logins]}" | sed 's/^/  /'
        echo ""
    fi

    # Services
    echo "| RUNNING SERVICES"
    if [[ "${type}" == "short" ]]; then
        echo "${SW[services_active]}" | (head -15 || true) | sed 's/^/  /' || true
        echo "  ..."
    else
        echo "${SW[services_active]}" | sed 's/^/  /'
        echo ""
        echo "| FAILED SERVICES"
        echo "${SW[services_failed]}" | sed 's/^/  /'
    fi
    echo ""

    # Processes
    echo "| TOP PROCESSES (by CPU)"
    echo "${SW[top_processes]}" | sed 's/^/  /'
    echo ""

    # Open ports
    echo "| OPEN PORTS"
    echo "${SW[open_ports]}" | sed 's/^/  /'
    echo ""

    # Firewall
    echo "| FIREWALL STATUS"
    echo "${SW[firewall]}" | sed 's/^/  /'
    echo ""

    if [[ "${type}" == "full" ]]; then
        # Cron
        echo "| SCHEDULED TASKS (crontab)"
        echo "${SW[crontabs]}" | sed 's/^/  /'
        echo ""
        echo "  /etc/cron.d entries: ${SW[system_cron]}"
        echo ""

        # SUID
        echo "| SUID BINARIES (security check)"
        echo "${SW[suid_files]}" | sed 's/^/  /'
        echo ""

        # World-writable
        echo "| WORLD-WRITABLE DIRECTORIES (security check)"
        echo "${SW[world_writable]}" | sed 's/^/  /'
        echo ""
    fi
}

# report footer
_txt_footer() {
    echo "--------------------------------------------------------------------"
    echo "  Report generated by Linux Audit System — NSCS 2025/2026"
    echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "--------------------------------------------------------------------"
}

# create HTML report
_write_html_report() {
    local type="$1"
    local path="$2"

    cat > "${path}" <<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Linux System Audit - ${type}</title>
<style>
    body { font-family: Arial, sans-serif; background-color: #f8f9fa; color: #333; margin: 20px; line-height: 1.6; }
    h1 { color: #0056b3; }
    h2 { border-bottom: 2px solid #ccc; padding-bottom: 5px; color: #444; margin-top: 30px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
    th { background-color: #0056b3; color: #fff; width: 25%; }
    .header-info { background: #fff; padding: 15px; border-left: 5px solid #0056b3; margin-bottom: 20px; }
</style>
</head>
<body>
    <h1>System Audit Report (${type})</h1>
    <div class="header-info">
        <strong>Hostname:</strong> $(hostname -f 2>/dev/null || hostname)<br>
        <strong>Date/Time:</strong> $(date '+%A, %d %B %Y — %H:%M:%S %Z')<br>
        <strong>Run by:</strong> $(whoami)
    </div>

    <h2>Hardware Summary</h2>
    <table>
        <tr><th>CPU Model</th><td>${HW[cpu_model]}</td></tr>
        <tr><th>CPU Cores</th><td>${HW[cpu_cores]}</td></tr>
        <tr><th>CPU Frequency</th><td>${HW[cpu_freq]}</td></tr>
        <tr><th>RAM Total</th><td>${HW[ram_total]}</td></tr>
        <tr><th>RAM Used</th><td>${HW[ram_used]}</td></tr>
        <tr><th>Disk (/)</th><td>${HW[disk_root_usage]}</td></tr>
        <tr><th>System Uptime</th><td>${HW[uptime]}</td></tr>
    </table>

    <h2>Software Summary</h2>
    <table>
        <tr><th>OS Name</th><td>${SW[os_name]}</td></tr>
        <tr><th>Kernel Version</th><td>${SW[kernel]}</td></tr>
        <tr><th>Architecture</th><td>${SW[arch]}</td></tr>
        <tr><th>Package Manager</th><td>${SW[pkg_manager]}</td></tr>
        <tr><th>Installed Packages</th><td>${SW[pkg_count]}</td></tr>
        <tr><th>Timezone</th><td>${SW[timezone]}</td></tr>
    </table>
</body>
</html>
HTML
}

# helper for json escaping
_json_escape() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' \
        | tr -d '\n' \
        | sed 's/\\n$//'
}

# create JSON report
_write_json_report() {
    local type="$1"
    local path="$2"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S%z')

    cat > "${path}" <<JSON
{
  "metadata": {
    "report_type": "${type}",
    "hostname": "$(hostname -f 2>/dev/null || hostname)",
    "generated_at": "${ts}",
    "generated_by": "$(whoami)",
    "kernel": "${SW[kernel]}"
  },
  "hardware": {
    "cpu_model": "$(_json_escape "${HW[cpu_model]}")",
    "cpu_arch": "${HW[cpu_arch]}",
    "cpu_cores": "${HW[cpu_cores]}",
    "cpu_freq": "${HW[cpu_freq]}",
    "cpu_usage": "${HW[cpu_usage]}",
    "ram_total": "${HW[ram_total]}",
    "ram_used": "${HW[ram_used]}",
    "ram_available": "${HW[ram_available]}",
    "swap_total": "${HW[swap_total]}",
    "gpu": "$(_json_escape "${HW[gpu]}")",
    "uptime": "$(_json_escape "${HW[uptime]}")"
  },
  "software": {
    "os_name": "$(_json_escape "${SW[os_name]}")",
    "os_version": "$(_json_escape "${SW[os_version]}")",
    "kernel": "${SW[kernel]}",
    "arch": "${SW[arch]}",
    "pkg_manager": "${SW[pkg_manager]}",
    "pkg_count": "${SW[pkg_count]}",
    "timezone": "$(_json_escape "${SW[timezone]}")"
  }
}
JSON
}
