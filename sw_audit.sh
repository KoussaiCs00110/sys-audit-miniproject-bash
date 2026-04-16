#!/usr/bin/env bash
# OS and software info

declare -A SW

collect_sw_info() {
    log_info "Getting software info..."

    # Check OS version
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release 
        SW[os_name]="${PRETTY_NAME:-${NAME:-Unknown}}"
        SW[os_id]="${ID:-unknown}"
        SW[os_version]="${VERSION:-N/A}"
    else
        SW[os_name]=$(uname -s)
        SW[os_id]="unknown"
        SW[os_version]="N/A"
    fi

    SW[kernel]=$(uname -r)
    SW[kernel_full]=$(uname -a)
    SW[arch]=$(uname -m)
    SW[hostname]=$(hostname -f 2>/dev/null || hostname)
    SW[timezone]=$(timedatectl 2>/dev/null | awk '/Time zone/{print $3}' || cat /etc/timezone 2>/dev/null || echo "N/A")
    SW[locale]=$(locale 2>/dev/null | grep LANG= | head -1 || echo "N/A")

    # figure out which package manager is used
    if command -v dpkg &>/dev/null; then 
        SW[pkg_manager]="dpkg/apt"
        SW[pkg_count]=$(dpkg -l 2>/dev/null | grep -c "^ii" || echo "0")
        SW[pkg_list]=$(dpkg -l 2>/dev/null | awk '/^ii/{print $2, $3}' || echo "N/A")
    elif command -v rpm &>/dev/null; then 
        SW[pkg_manager]="rpm/dnf"
        SW[pkg_count]=$(rpm -qa 2>/dev/null | wc -l || echo "0")
        SW[pkg_list]=$(rpm -qa 2>/dev/null | sort || echo "N/A")
    elif command -v pacman &>/dev/null; then
        SW[pkg_manager]="pacman"
        SW[pkg_count]=$(pacman -Q 2>/dev/null | wc -l || echo "0")
        SW[pkg_list]=$(pacman -Q 2>/dev/null || echo "N/A")
    else
        SW[pkg_manager]="unknown"
        SW[pkg_count]="N/A"
        SW[pkg_list]="N/A"
    fi

    # User activity
    SW[logged_users]=$(who 2>/dev/null || echo "N/A")
    SW[last_logins]=$(last -n 10 2>/dev/null || echo "N/A")
    SW[failed_logins]=$(lastb -n 10 2>/dev/null || echo "(needs root)")

    # services
    if command -v systemctl &>/dev/null; then
        SW[services_active]=$(systemctl list-units --type=service --state=active --no-pager --no-legend 2>/dev/null | awk '{print $1, $4}' || echo "N/A")
        SW[services_failed]=$(systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | awk '{print $1}' || echo "None")
    else
        SW[services_active]=$(service --status-all 2>/dev/null || echo "N/A")
        SW[services_failed]="N/A"
    fi

    # top processes by cpu
    SW[top_processes]=$(ps aux --sort=-%cpu 2>/dev/null | head -21 || echo "N/A")

    # network ports
    if command -v ss &>/dev/null; then
        SW[open_ports]=$(ss -tuln 2>/dev/null || echo "N/A")
    elif command -v netstat &>/dev/null; then
        SW[open_ports]=$(netstat -tuln 2>/dev/null || echo "N/A")
    else
        SW[open_ports]="ss/netstat not found"
    fi

    # firewall check
    if command -v ufw &>/dev/null; then
        SW[firewall]=$(ufw status 2>/dev/null || echo "N/A")
    elif command -v firewall-cmd &>/dev/null; then
        SW[firewall]=$(firewall-cmd --state 2>/dev/null || echo "N/A")
    elif command -v iptables &>/dev/null; then
        SW[firewall]=$(iptables -L --line-numbers 2>/dev/null | head -30 || echo "N/A")
    else
        SW[firewall]="None detected"
    fi

    # cron jobs
    SW[crontabs]=$(crontab -l 2>/dev/null || echo "none")
    SW[system_cron]=$(ls /etc/cron.d/ 2>/dev/null | tr '\n' ' ' || echo "N/A")

    # shell and path
    SW[shell]=${SHELL:-N/A}
    SW[path]=${PATH:-N/A}
    SW[env_vars]=$(env 2>/dev/null | sort || echo "N/A")

    # SUID files (only top 30)
    SW[suid_files]=$(find / -perm -4000 -type f 2>/dev/null | head -30 || echo "N/A")

    # World writable folders
    SW[world_writable]=$(find /etc /tmp /var -perm -0002 -type d 2>/dev/null | head -20 || echo "N/A")

    log_info "Software info done."
}
