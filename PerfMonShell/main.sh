#!/bin/bash

# Define log file paths
CPU_LOG_FILE="$(dirname "$0")/cpu_logs.log"
NETWORK_LOG_FILE="$(dirname "$0")/network_logs.log"
DISK_LOG_FILE="$(dirname "$0")/disk_logs.log"
MEMORY_LOG_FILE="$(dirname "$0")/memory_logs.log"

# Ensure the log files exist
for LOG_FILE in "$CPU_LOG_FILE" "$NETWORK_LOG_FILE" "$DISK_LOG_FILE" "$MEMORY_LOG_FILE"; do
    if [ ! -e "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 0640 "$LOG_FILE"
    fi
done

# Enhanced log_network_info_to_file function with additional network details
log_network_info_to_file() {
    echo "Logging network information to $NETWORK_LOG_FILE... Press any button to continue"
    {
        echo "--------------------------------------"
        echo "Network Information Log: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "--------------------------------------"

        # Existing network info and traffic
        get_network_info
        get_network_traffic

        # Network interface statistics
        echo -e "\nNetwork Interface Statistics:"
        ifconfig | awk '/flags/{print $1} /RX packets/{print "Received: " $5} /TX packets/{print "Transmitted: " $5 "\n"}'

        # Connection statistics (requires netstat or ss)
        echo -e "\nCurrent Network Connections:"
        ss -tuln

        echo "--------------------------------------"
    } >>"$NETWORK_LOG_FILE"
}

# Enhanced log_memory_usage_to_file function with additional memory details
log_memory_usage_to_file() {
    echo "Logging enhanced memory usage information to $MEMORY_LOG_FILE... Press any button to continue"
    {
        echo "Enhanced Memory Usage Information Log: $(date '+%Y-%m-%d %H:%M:%S')"
        display_memory_usage
        # Display buffers and cache
        free -m | awk '/Mem:/ {printf "Buffers/Cache: Used: %sMB, Free: %sMB\n", $6, $7}'
        # Display top memory-consuming processes
        echo "Top memory-consuming processes:"
        ps aux --sort=-%mem | head -n 11
        echo "--------------------------------------"
    } >>"$MEMORY_LOG_FILE"
}

# Enhanced log_disk_usage_to_file function with additional disk details
log_disk_usage_to_file() {
    echo "Logging enhanced disk usage information to $DISK_LOG_FILE... Press any button to continue"
    {
        echo "Enhanced Disk Usage Information Log: $(date '+%Y-%m-%d %H:%M:%S')"
        # Basic disk usage
        echo "Basic Disk Usage:"
        df -h | grep '^/dev/'
        # Inode usage
        echo "Inode Usage:"
        df -hi | grep '^/dev/'
        # Disk read/write summary (requires iostat from sysstat package)
        echo "Disk Read/Write Summary (last 1 minute):"
        iostat -d 1 6 | grep -v '^Linux' | grep -v '^$' | tail -n +3
        echo "--------------------------------------"
    } >>"$DISK_LOG_FILE"
}

log_cpu_info_to_file() {
    echo "Logging CPU information to $CPU_LOG_FILE... Press any button to continue"
    {
        echo "--------------------------------------"
        echo "CPU Information Log: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "--------------------------------------"

        # CPU usage and temperature
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
        cpu_temp=$(sensors | awk '/^Core 0:/ {print $3}')
        echo "CPU Temperature: $cpu_temp"

        # Detailed CPU information
        cpu_info=$(lscpu | grep -E 'Model name|Socket\(s\)|Core\(s\) per socket|Thread\(s\) per core|L1d cache|L1i cache|L2 cache|L3 cache')
        echo "$cpu_info"

        # Top 10 processes consuming the most CPU
        echo "Top 10 CPU-consuming processes:"
        ps -eo %cpu,pid,user,command --sort=-%cpu | head -n 11
        echo

        process_count=$(ps -e --no-headers | wc -l)
        uptime_info=$(uptime -p)

        echo "Processes Utilizing the CPU: $process_count"
        echo "$uptime_info"

        echo "--------------------------------------"
    } >>"$CPU_LOG_FILE"
}

# Function to get network information
get_network_info() {
    # Detect Wi-Fi and Ethernet interfaces
    wifi_interface=$(iw dev | awk '$1=="Interface"{print $2}')
    ethernet_interface=$(ip link | awk -F': ' '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')

    # Wi-Fi SSID, if available
    if [ -n "$wifi_interface" ]; then
        ssid=$(iwgetid -r)
        echo "Wi-Fi Interface: $wifi_interface"
        echo "SSID: $ssid"
    fi

    # IP addresses for all interfaces
    for interface in $wifi_interface $ethernet_interface; do
        if [ -n "$interface" ]; then
            ipv4=$(ip -4 addr show "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            ipv6=$(ip -6 addr show "$interface" | grep -oP '(?<=inet6\s)[\da-f:]+')
            echo "Interface: $interface"
            echo "IPv4: $ipv4"
            echo "IPv6: $ipv6"
            echo "--------------------------------------"
        fi
    done
}

# Function to get the number of bytes received and transmitted by the interface
get_network_traffic() {
    # Dynamically determine the active network interface if not set
    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n 1)
    fi

    # Ensure INTERFACE is not empty
    if [ -z "$INTERFACE" ]; then
        echo "No active network interface found."
        return 1
    fi

    # Paths to the network statistics
    rx_bytes_path="/sys/class/net/$INTERFACE/statistics/rx_bytes"
    tx_bytes_path="/sys/class/net/$INTERFACE/statistics/tx_bytes"

    # Check if the statistics files exist
    if [ ! -f "$rx_bytes_path" ] || [ ! -f "$tx_bytes_path" ]; then
        echo "Network statistics not available for interface $INTERFACE."
        return 1
    fi

    # Read the initial number of bytes received and transmitted
    rx_bytes_before=$(cat "$rx_bytes_path")
    tx_bytes_before=$(cat "$tx_bytes_path")
    sleep 1 # Wait for a second to measure the traffic

    # Read the number of bytes received and transmitted after 1 second
    rx_bytes_after=$(cat "$rx_bytes_path")
    tx_bytes_after=$(cat "$tx_bytes_path")

    # Calculate the difference and convert to KB
    rx_diff_kb=$(((rx_bytes_after - rx_bytes_before) / 1024))
    tx_diff_kb=$(((tx_bytes_after - tx_bytes_before) / 1024))

    echo "Network In: $rx_diff_kb KB/s"
    echo "Network Out: $tx_diff_kb KB/s"
}

# Function to get disk usage with capacity and type
get_disk_usage() {
    echo "Disk"
    df -h | grep '^/dev/' | while IFS= read -r line; do
        device=$(echo "$line" | awk '{print $1}')
        mount_point=$(echo "$line" | awk '{print $6}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        avail=$(echo "$line" | awk '{print $4}')
        use_perc=$(echo "$line" | awk '{print $5}')
        # Determine if SSD or HDD
        type=$(lsblk -no ROTA "$device" | awk '{if ($1=="1") print "HDD"; else print "SSD"}')
        echo "$device mounted on $mount_point: Total=$size, Used=$used, Avail=$avail, Use%=$use_perc, Type=$type"

    done
}

display_memory_usage() {
    total_mem=$(free -m | awk '/Mem:/ {print $2}')
    used_mem=$(free -m | awk '/Mem:/ {print $3}')
    free_mem=$(free -m | awk '/Mem:/ {print $4}')
    available_mem=$(free -m | awk '/Mem:/ {print $7}')
    used_mem_perc=$(awk "BEGIN {printf \"%.2f\", ($used_mem/$total_mem)*100}")

    # Swap space details
    total_swap=$(free -m | awk '/Swap:/ {print $2}')
    used_swap=$(free -m | awk '/Swap:/ {print $3}')
    free_swap=$(free -m | awk '/Swap:/ {print $4}')
    used_swap_perc=$(awk "BEGIN {printf \"%.2f\", ($used_swap/$total_swap)*100}")

    echo "Memory Total: ${total_mem}MB"
    echo "Memory Used: ${used_mem}MB (${used_mem_perc}%)"
    echo "Memory Free: ${free_mem}MB"
    echo "Memory Available: ${available_mem}MB"
    echo "Swap Total: ${total_swap}MB"
    echo "Swap Used: ${used_swap}MB (${used_swap_perc}%)"
    echo "Swap Free: ${free_swap}MB"
    echo "--------------------------------------"

}

display_cpu_info() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
    cpu_temp=$(sensors | awk '/^Core 0:/ {print $3}')
    cpu_info=$(lscpu | grep -E 'Model name|Socket\(s\)|Core\(s\) per socket|Thread\(s\) per core|L1d cache|L1i cache|L2 cache|L3 cache')
    process_count=$(ps -e --no-headers | wc -l)
    uptime_info=$(uptime -p)

    echo "CPU Usage: $cpu_usage"
    echo "CPU Temperature: $cpu_temp"
    echo
    echo "$cpu_info"
    echo "Processes Utilizing the CPU: $process_count"
    echo "$uptime_info"
    echo "--------------------------------------"
}

update_monitoring() {
    local choice
    local pause=0 # Flag to control pausing

    while true; do
        clear

        display_cpu_info
        display_memory_usage
        get_network_traffic
        get_network_info
        get_disk_usage

        if [[ $pause -eq 0 ]]; then
            echo
            echo "--------------------------------------------------------------------------------------------------------"
            echo "Press 'p' to pause and access more options and log information, or wait for auto-refresh in 10s (press any button to instantly refresh)."

            read -t 10 -n 1 -s -r choice
            echo
            if [[ $choice == "p" || $choice == "P" ]]; then
                pause=1
            fi
        fi

        if [[ $pause -eq 1 ]]; then
            echo "Monitoring paused. Choose an option:"
            echo "1) Continue monitoring"
            echo "2) Log network information and continue"
            echo "3) Log memory usage information and continue"
            echo "4) Log disk usage information and continue"
            echo "5) Log CPU information and continue"
            echo "6) Quit"
            read -n 1 -s -r -p "Select an option: " choice
            echo

            case $choice in
            1)
                pause=0
                ;;
            2)
                log_network_info_to_file
                read -n 1 -s -r # Pause for user to acknowledge
                pause=0
                ;;
            3)
                log_memory_usage_to_file
                read -n 1 -s -r # Pause for user to acknowledge
                pause=0
                ;;
            4)
                log_disk_usage_to_file
                read -n 1 -s -r # Pause for user to acknowledge
                pause=0
                ;;
            5)
                log_cpu_info_to_file
                read -n 1 -s -r # Pause for user to acknowledge
                pause=0
                ;;
            6)
                echo "Quitting..."
                exit 0
                ;;
            *)
                echo "Invalid choice, please select a valid option."
                ;;
            esac
        fi
    done
}

# Start the monitoring loop
update_monitoring
