
# Description
Implementation of a script that monitors system performance metrics such as CPU usage,
memory usage, disk I/O, and network I/O in real-1me and logs the data for analysis.


# Make the Script Executable

Before you can run the script, you need to make it executable. This is done by setting the execute
permission on the file. Open a terminal and navigate to the directory where main.sh is saved.

# Run the following command:
"chmod +x main.sh"

This command changes the mode of the file to add (+) execute (x) permissions.

# Run the Script:

With the script now executable, you can run it directly from the terminal. the script, use the
following command:

"/path/main.sh"



# How does the script work:
This Script is designed to continuously monitor and display system information, including
CPU, memory, network, and disk usage, with an interactive mode for additional actions.
Here's a detailed overview of its functionality and user interaction:

# Core Functionality:

• Continuous Monitoring: Automatically updates and displays system information in
real-time, refreshing every 10 seconds.

• Interactive Pause: Allows the user to pause the automatic refresh by pressing 'p',
enabling access to a menu for additional actions.

• Automatic Refresh: If no input is received within 10 seconds, the script refreshes
the displayed system information.

• Pause and Menu: Pressing 'p' pauses the refresh and presents a menu with options
to log detailed information or quit.

• Logging Options: The user can choose to log detailed network, memory, disk, or
CPU information to respective log files.

• Resuming Monitoring: After an action is selected or logging is completed, the user
can resume the automatic refresh.

• Quitting: The user has the option to exit the monitoring script.

# Behind the Scenes:

System Information Display: Utilizes functions like display_cpu_info,
display_memory_usage, get_network_traffic, get_network_info, and get_disk_usage to
gather and display relevant system metrics.

Logging to Files: Specific functions (log_network_info_to_file, log_memory_usage_to_file,
log_disk_usage_to_file, log_cpu_info_to_file) are called based on user selection to log
detailed information into predefined log files.

User Input Handling: Uses the read command with a timeout for the initial pause prompt
and without a timeout for menu selection, capturing user choices and controlling the
script's flow based on those choices.


# How to use:
1. The script will continuously monitor and display system information, and will refresh
every 10 seconds

3. If the user presses “p” it will pause the continues monitoring and the user will get
additional options.

5. The user has the option to log specific information by selecting one of the available
choices, continue with real-time monitoring, or exit.


