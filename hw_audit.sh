#!/usr/bin/env bash
# ============================================================
#  hw_audit.sh — Hardware Information Collection Module
#  Populates global associative array HW[] with all hw data.
# ============================================================
# all commands if not found save N/A

declare -A HW   # global: populated by collect_hw_info()

collect_hw_info() {
    log_info "Collecting hardware information..."

    # ── CPU 
    HW[cpu_model]=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' || echo "N/A") # this command find the cpu model name and save it in HW[cpu_model] if not exist save N/A .
    HW[cpu_cores]=$(nproc --all 2>/dev/null || grep -c "^processor" /proc/cpuinfo) # this command find the number of cpu cores and save it in HW[cpu_cores] if not exist save N/A .
    HW[cpu_arch]=$(uname -m) # this command find the cpu architecture and save it in HW[cpu_arch] if not exist save N/A .
    HW[cpu_freq]=$(grep -m1 "cpu MHz" /proc/cpuinfo 2>/dev/null | awk -F': ' '{printf "%.0f MHz", $2}' || echo "N/A") # this command find the cpu frequency and save it in HW[cpu_freq] if not exist save N/A .
    HW[cpu_cache]=$(grep -m1 "cache size" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' || echo "N/A") # this command find the cpu cache and save it in HW[cpu_cache] if not exist save N/A .

    # ── CPU usage (current snapshot) 
    HW[cpu_usage]=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print 100 - $8 "%" }' || echo "N/A") # this command find the cpu usage and save it in HW[cpu_usage] if not exist save N/A .

    # ── GPU 
    if command -v lspci &>/dev/null; then
        HW[gpu]=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | sed 's/.*: //' || echo "None detected") # this command find the gpu and save it in HW[gpu] if not exist save N/A .
    else
        HW[gpu]="lspci not available"
    fi

    # ── RAM 
    HW[ram_total]=$(awk '/MemTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo) # this command find the ram total and save it in HW[ram_total] if not exist save N/A .
    HW[ram_free]=$(awk '/MemFree/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo) # this command find the ram free and save it in HW[ram_free] if not exist save N/A .
    HW[ram_available]=$(awk '/MemAvailable/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo) # this command find the ram available and save it in HW[ram_available] if not exist save N/A .
    HW[ram_used]=$(free -h 2>/dev/null | awk '/Mem:/{print $3}' || echo "N/A") # this command find the ram used and save it in HW[ram_used] if not exist save N/A .
    HW[swap_total]=$(awk '/SwapTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo) # this command find the swap total and save it in HW[swap_total] if not exist save N/A .
    HW[swap_free]=$(awk '/SwapFree/{printf  "%.2f GB", $2/1024/1024}' /proc/meminfo) # this command find the swap free and save it in HW[swap_free] if not exist save N/A .

    # ── Disks 
    # Full disk layout as a single block (used in full report)
    HW[disk_layout]=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null || echo "N/A") # this command find the disk layout and save it in HW[disk_layout] if not exist save N/A .
    HW[disk_usage]=$(df -hT 2>/dev/null | grep -v "tmpfs\|devtmpfs\|udev\|none" || echo "N/A") # this command find the disk usage and save it in HW[disk_usage] if not exist save N/A .
    # Short summary: root partition usage
    HW[disk_root_usage]=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 " used / " $2 " total (" $5 ")"}' || echo "N/A") # this command find the root partition usage and save it in HW[disk_root_usage] if not exist save N/A .

    # ── Network interfaces 
    if command -v ip &>/dev/null; then
        # IP addresses per interface
        HW[net_interfaces]=$(ip -o addr show 2>/dev/null | awk '{print $2, $3, $4}' || echo "N/A") # this command find the network interfaces and save it in HW[net_interfaces] if not exist save N/A .
        # MAC addresses
        HW[net_mac]=$(ip link show 2>/dev/null | awk '/ether/{print prev, $2} {prev=$2}' || echo "N/A") # this command find the mac addresses and save it in HW[net_mac] if not exist save N/A .
        # Default gateway
        HW[net_gateway]=$(ip route show default 2>/dev/null | awk '{print $3}' || echo "N/A") # this command find the default gateway and save it in HW[net_gateway] if not exist save N/A .
    else
        HW[net_interfaces]=$(ifconfig 2>/dev/null || echo "ip/ifconfig not available") # this command find the network interfaces and save it in HW[net_interfaces] if not exist save N/A .
        HW[net_mac]="N/A"
        HW[net_gateway]="N/A"
    fi

    # DNS servers
    HW[net_dns]=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' || echo "N/A") # this command find the dns servers and save it in HW[net_dns] if not exist save N/A .

    # ── Motherboard / DMI 
    if command -v dmidecode &>/dev/null && [[ $EUID -eq 0 ]]; then
        HW[board_vendor]=$(dmidecode -s baseboard-manufacturer 2>/dev/null || echo "N/A") # this command find the motherboard vendor and save it in HW[board_vendor] if not exist save N/A .
        HW[board_product]=$(dmidecode -s baseboard-product-name 2>/dev/null || echo "N/A") # this command find the motherboard product and save it in HW[board_product] if not exist save N/A .
        HW[bios_vendor]=$(dmidecode -s bios-vendor 2>/dev/null || echo "N/A") # this command find the bios vendor and save it in HW[bios_vendor] if not exist save N/A .
        HW[bios_version]=$(dmidecode -s bios-version 2>/dev/null || echo "N/A") # this command find the bios version and save it in HW[bios_version] if not exist save N/A .
        HW[sys_serial]=$(dmidecode -s system-serial-number 2>/dev/null || echo "N/A") # this command find the system serial number and save it in HW[sys_serial] if not exist save N/A .
    else
        local note="(run as root + dmidecode for full details)"
        HW[board_vendor]="${note}"
        HW[board_product]="${note}"
        HW[bios_vendor]="${note}"
        HW[bios_version]="${note}"
        HW[sys_serial]="${note}"
    fi

    # ── USB devices 
    if command -v lsusb &>/dev/null; then
        HW[usb_devices]=$(lsusb 2>/dev/null || echo "None") # this command find the usb devices and save it in HW[usb_devices] if not exist save N/A .
    else
        HW[usb_devices]="lsusb not available"
    fi

    # ── PCI devices (summary) 
    if command -v lspci &>/dev/null; then
        HW[pci_devices]=$(lspci 2>/dev/null || echo "None") # this command find the pci devices and save it in HW[pci_devices] if not exist save N/A .
    else
        HW[pci_devices]="lspci not available"
    fi

    # ── System uptime 
    HW[uptime]=$(uptime -p 2>/dev/null || uptime) # this command find the system uptime and save it in HW[uptime] if not exist save N/A .

    log_info "Hardware collection complete."
}
