#!/usr/bin/env bash
# Hardware info collection

declare -A HW

collect_hw_info() {
    log_info "Getting hardware stats..."

    # CPU info
    HW[cpu_model]=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' || echo "N/A")
    HW[cpu_cores]=$(nproc --all 2>/dev/null || grep -c "^processor" /proc/cpuinfo)
    HW[cpu_arch]=$(uname -m)
    HW[cpu_freq]=$(grep -m1 "cpu MHz" /proc/cpuinfo 2>/dev/null | awk -F': ' '{printf "%.0f MHz", $2}' || echo "N/A")
    HW[cpu_cache]=$(grep -m1 "cache size" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' || echo "N/A")

    # Current CPU usage
    HW[cpu_usage]=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print 100 - $8 "%" }' || echo "N/A")

    # GPU info
    if command -v lspci &>/dev/null; then
        HW[gpu]=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | sed 's/.*: //' || echo "None detected")
    else
        HW[gpu]="lspci not installed"
    fi

    # RAM stats
    HW[ram_total]=$(awk '/MemTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
    HW[ram_free]=$(awk '/MemFree/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
    HW[ram_available]=$(awk '/MemAvailable/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
    HW[ram_used]=$(free -h 2>/dev/null | awk '/Mem:/{print $3}' || echo "N/A")
    HW[swap_total]=$(awk '/SwapTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
    HW[swap_free]=$(awk '/SwapFree/{printf  "%.2f GB", $2/1024/1024}' /proc/meminfo)

    # Disk stuff
    HW[disk_layout]=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null || echo "N/A")
    HW[disk_usage]=$(df -hT 2>/dev/null | grep -v "tmpfs\|devtmpfs\|udev\|none" || echo "N/A")
    # root partition usage
    HW[disk_root_usage]=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 " used / " $2 " total (" $5 ")"}' || echo "N/A")

    # Network stuff
    if command -v ip &>/dev/null; then
        # IPs
        HW[net_interfaces]=$(ip -o addr show 2>/dev/null | awk '{print $2, $3, $4}' || echo "N/A")
        # MACs
        HW[net_mac]=$(ip link show 2>/dev/null | awk '/ether/{print prev, $2} {prev=$2}' || echo "N/A")
        # Gateway
        HW[net_gateway]=$(ip_route=$(ip route show default 2>/dev/null); echo "${ip_route}" | awk '{print $3}' || echo "N/A")
    else
        HW[net_interfaces]=$(ifconfig 2>/dev/null || echo "ip/ifconfig not found")
        HW[net_mac]="N/A"
        HW[net_gateway]="N/A"
    fi

    HW[net_dns]=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' || echo "N/A")

    # BIOS and Motherboard info
    if command -v dmidecode &>/dev/null && [[ $EUID -eq 0 ]]; then
        HW[board_vendor]=$(dmidecode -s baseboard-manufacturer 2>/dev/null || echo "N/A")
        HW[board_product]=$(dmidecode -s baseboard-product-name 2>/dev/null || echo "N/A")
        HW[bios_vendor]=$(dmidecode -s bios-vendor 2>/dev/null || echo "N/A")
        HW[bios_version]=$(dmidecode -s bios-version 2>/dev/null || echo "N/A")
        HW[sys_serial]=$(dmidecode -s system-serial-number 2>/dev/null || echo "N/A")
    else
        local note="(need root and dmidecode for this)"
        HW[board_vendor]="${note}"
        HW[board_product]="${note}"
        HW[bios_vendor]="${note}"
        HW[bios_version]="${note}"
        HW[sys_serial]="${note}"
    fi

    # USB
    if command -v lsusb &>/dev/null; then
        HW[usb_devices]=$(lsusb 2>/dev/null || echo "None")
    else
        HW[usb_devices]="lsusb not found"
    fi

    # PCI
    if command -v lspci &>/dev/null; then
        HW[pci_devices]=$(lspci 2>/dev/null || echo "None")
    else
        HW[pci_devices]="lspci not found"
    fi

    # How long the system has been running
    HW[uptime]=$(uptime -p 2>/dev/null || uptime)

    log_info "Done with hardware."
}
