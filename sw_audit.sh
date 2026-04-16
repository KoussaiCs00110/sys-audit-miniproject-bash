#!/usr/bin/env bash
# ============================================================
#  sw_audit.sh — OS & Software Information Collection Module
#  Populates global associative array SW[] with all sw data.
# ============================================================
# all commands if not found save N/A


declare -A SW   # global: populated by collect_sw_info()

collect_sw_info() {
    log_info "Collecting OS & software information..."

    # ── OS identity 
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release 
        SW[os_name]="${PRETTY_NAME:-${NAME:-Unknown}}" # this command find the os name
        SW[os_id]="${ID:-unknown}" # this command find the os id
        SW[os_version]="${VERSION:-N/A}" # this command find the os version
    else
        SW[os_name]=$(uname -s) # this command find the os name
        SW[os_id]="unknown" # this command find the os id
        SW[os_version]="N/A" # this command find the os version
    fi

    SW[kernel]=$(uname -r) # this command find the kernel version
    SW[kernel_full]=$(uname -a) # this command find the kernel full version
    SW[arch]=$(uname -m) # this command find the architecture
    SW[hostname]=$(hostname -f 2>/dev/null || hostname) # this command find the hostname
    SW[timezone]=$(timedatectl 2>/dev/null | awk '/Time zone/{print $3}' || cat /etc/timezone 2>/dev/null || echo "N/A") # this command find the timezone
    SW[locale]=$(locale 2>/dev/null | grep LANG= | head -1 || echo "N/A") # this command find the locale

    # ── Installed packages 
    if command -v dpkg &>/dev/null; then 
        SW[pkg_manager]="dpkg/apt" # this command find the package manager
        SW[pkg_count]=$(dpkg -l 2>/dev/null | grep -c "^ii" || echo "0") # this command find the package count
        SW[pkg_list]=$(dpkg -l 2>/dev/null | awk '/^ii/{print $2, $3}' || echo "N/A") # this command find the package list
    elif command -v rpm &>/dev/null; then 
        SW[pkg_manager]="rpm/dnf" # this command find the package manager
        SW[pkg_count]=$(rpm -qa 2>/dev/null | wc -l || echo "0") # this command find the package count
        SW[pkg_list]=$(rpm -qa 2>/dev/null | sort || echo "N/A") # this command find the package list
    elif command -v pacman &>/dev/null; then
        SW[pkg_manager]="pacman" # this command find the package manager
        SW[pkg_count]=$(pacman -Q 2>/dev/null | wc -l || echo "0") # this command find the package count
        SW[pkg_list]=$(pacman -Q 2>/dev/null || echo "N/A") # this command find the package list
    else
        SW[pkg_manager]="unknown" # this command find the package manager
        SW[pkg_count]="N/A" # this command find the package count
        SW[pkg_list]="N/A"
    fi

    # ── Logged-in users 
    SW[logged_users]=$(who 2>/dev/null || echo "N/A") # this command find the logged-in users
    SW[last_logins]=$(last -n 10 2>/dev/null || echo "N/A") # this command find the last logins
    SW[failed_logins]=$(lastb -n 10 2>/dev/null || echo "(requires root)" ) # this command find the failed logins

    # ── Running services   
    if command -v systemctl &>/dev/null; then
        SW[services_active]=$(systemctl list-units --type=service --state=active --no-pager --no-legend 2>/dev/null | awk '{print $1, $4}' || echo "N/A") # this command find the active services
        SW[services_failed]=$(systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | awk '{print $1}' || echo "None") # this command find the failed services
    else
        SW[services_active]=$(service --status-all 2>/dev/null || echo "N/A") # this command find the active services
        SW[services_failed]="N/A" # this command find the failed services
    fi

    # ── Active processes (top 20 by CPU) 
    SW[top_processes]=$(ps aux --sort=-%cpu 2>/dev/null | head -21 || echo "N/A") # this command find the top 20 processes

    # ── Open ports 
    if command -v ss &>/dev/null; then
        SW[open_ports]=$(ss -tuln 2>/dev/null || echo "N/A") # this command find the open ports
    elif command -v netstat &>/dev/null; then
        SW[open_ports]=$(netstat -tuln 2>/dev/null || echo "N/A") # this command find the open ports
    else
        SW[open_ports]="ss/netstat not available" # this command find the open ports
    fi

    # ── Firewall status 
    if command -v ufw &>/dev/null; then
        SW[firewall]=$(ufw status 2>/dev/null || echo "N/A") # this command find the firewall status
    elif command -v firewall-cmd &>/dev/null; then
        SW[firewall]=$(firewall-cmd --state 2>/dev/null || echo "N/A") # this command find the firewall status
    elif command -v iptables &>/dev/null; then
        SW[firewall]=$(iptables -L --line-numbers 2>/dev/null | head -30 || echo "N/A") # this command find the firewall status
    else
        SW[firewall]="No firewall tool detected" # this command find the firewall status
    fi

    # ── Scheduled tasks 
    SW[crontabs]=$(crontab -l 2>/dev/null || echo "(none for current user)") # this command find the crontabs
    SW[system_cron]=$(ls /etc/cron.d/ 2>/dev/null | tr '\n' ' ' || echo "N/A") # this command find the system cron

    # ── Environment & shell    
    SW[shell]=${SHELL:-N/A}  # this command find the shell
    SW[path]=${PATH:-N/A} # this command find the path
    SW[env_vars]=$(env 2>/dev/null | sort || echo "N/A") # this command find the environment variables

    # ── Security: SUID binaries (quick check) 
    SW[suid_files]=$(find / -perm -4000 -type f 2>/dev/null | head -30 || echo "N/A") # this command find the suid files

    # ── World-writable directories (quick check) 
    SW[world_writable]=$(find /etc /tmp /var -perm -0002 -type d 2>/dev/null | head -20 || echo "N/A") # this command find the world-writable directories

    log_info "Software collection complete."
}
