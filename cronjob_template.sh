#!/bin/bash

# =============================================================================
# Configuration Section
# =============================================================================
# Basic script configuration
SCRIPT_NAME="cronjob_template"        # Name of your script
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"  # Lock file location
LOG_FILE="/var/log/${SCRIPT_NAME}.log" # Log file location

# Log management configuration
LOG_RETENTION_DAYS=30                 # Number of days to keep old log files
MAX_LOG_SIZE_MB=10                    # Maximum log file size before rotation

# Notification configuration
EMAIL_RECIPIENTS="admin@example.com"  # Email recipients for notifications

# Environment configuration
REQUIRED_ENV_VARS=("ENV_VAR1" "ENV_VAR2") # Required environment variables
required_commands=("awk" "sed" "grep" "mail") # Required system commands

# Retry mechanism configuration
MAX_RETRIES=3                         # Maximum number of retry attempts
RETRY_DELAY=60                        # Delay between retries in seconds

# Resource monitoring thresholds (percentage)
CPU_THRESHOLD=80                      # CPU usage warning threshold
MEMORY_THRESHOLD=90                   # Memory usage warning threshold
DISK_THRESHOLD=90                     # Disk usage warning threshold

# =============================================================================
# Variable Initialization
# =============================================================================
EXIT_CODE=0                           # Script exit code
SCRIPT_START_TIME=$(date +%s)         # Script start timestamp
RETRY_COUNT=0                         # Current retry attempt counter

# =============================================================================
# Resource Monitoring Function
# =============================================================================
# Monitors system resources (CPU, memory, disk) and logs warnings if thresholds
# are exceeded. This helps identify potential performance issues.
monitor_resources() {
    # Get current CPU usage percentage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    
    # Get current memory usage percentage
    local memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
    
    # Get current disk usage percentage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Check CPU usage
    if [ "${cpu_usage}" -gt "${CPU_THRESHOLD}" ]; then
        log "WARNING" "High CPU usage detected: ${cpu_usage}%"
    fi
    
    # Check memory usage
    if [ "${memory_usage}" -gt "${MEMORY_THRESHOLD}" ]; then
        log "WARNING" "High memory usage detected: ${memory_usage}%"
    fi
    
    # Check disk usage
    if [ "${disk_usage}" -gt "${DISK_THRESHOLD}" ]; then
        log "WARNING" "High disk usage detected: ${disk_usage}%"
    fi
}

# =============================================================================
# Log Management Functions
# =============================================================================
# Rotates log files when they exceed the maximum size and cleans up old log files
# based on retention policy. This prevents log files from growing too large and
# consuming disk space.
rotate_logs() {
    # Check if log file exists and its size
    if [ -f "${LOG_FILE}" ]; then
        local log_size=$(du -m "${LOG_FILE}" | cut -f1)
        
        # Rotate if log file exceeds maximum size
        if [ "${log_size}" -gt "${MAX_LOG_SIZE_MB}" ]; then
            log "INFO" "Rotating log file (size: ${log_size}MB)"
            mv "${LOG_FILE}" "${LOG_FILE}.$(date +%Y%m%d%H%M%S)"
            touch "${LOG_FILE}"
        fi
    fi
    
    # Clean up old log files based on retention policy
    find /var/log -name "${SCRIPT_NAME}.log.*" -mtime +${LOG_RETENTION_DAYS} -delete
}

# =============================================================================
# Retry Mechanism
# =============================================================================
# Implements a retry mechanism for critical operations that might fail temporarily.
# This helps handle transient issues and improves script reliability.
retry_operation() {
    local command=$1                  # Command to execute
    local max_retries=$2              # Maximum number of retries
    local delay=$3                    # Delay between retries in seconds
    
    # Attempt the operation up to max_retries times
    while [ ${RETRY_COUNT} -lt ${max_retries} ]; do
        if eval "${command}"; then
            return 0                  # Success
        fi
        
        # Increment retry counter
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        # If we haven't reached max retries, wait and try again
        if [ ${RETRY_COUNT} -lt ${max_retries} ]; then
            log "WARNING" "Operation failed, retrying in ${delay} seconds (attempt ${RETRY_COUNT}/${max_retries})"
            sleep ${delay}
        fi
    done
    
    return 1                          # All retries failed
}

# =============================================================================
# Logging Function
# =============================================================================
# Provides consistent logging functionality with timestamps, log levels, and
# process IDs. Logs are written to both file and system journal when available.
log() {
    local level=$1                    # Log level (INFO, WARNING, ERROR)
    local message=$2                  # Log message
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_entry="[${timestamp}] [${level}] [$$] ${message}"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # Write to log file
    echo "${log_entry}" | tee -a "${LOG_FILE}"
    
    # Also log to system journal if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "${SCRIPT_NAME}" "${log_entry}"
    fi
}

# =============================================================================
# Email Notification Function
# =============================================================================
# Sends email notifications for important events and errors. Falls back gracefully
# if mail command is not available.
send_email() {
    local subject=$1                  # Email subject
    local body=$2                     # Email body
    
    if command -v mail >/dev/null 2>&1; then
        echo "${body}" | mail -s "${subject}" "${EMAIL_RECIPIENTS}"
    else
        log "WARNING" "mail command not available, cannot send email notification"
    fi
}

# =============================================================================
# Lock File Management
# =============================================================================
# Prevents concurrent execution of the script by using a lock file. Handles stale
# lock files and provides proper error reporting.
check_running() {
    if [ -f "${LOCK_FILE}" ]; then
        local pid=$(cat "${LOCK_FILE}")
        
        # Check if process is still running
        if ps -p "${pid}" > /dev/null 2>&1; then
            log "ERROR" "Script is already running with PID ${pid}"
            send_email "${SCRIPT_NAME} - Concurrent Execution" \
                "Script is already running with PID ${pid}. Please check if this is expected."
            exit 1
        else
            # Remove stale lock file
            log "WARNING" "Stale lock file found, removing it"
            rm -f "${LOCK_FILE}"
        fi
    fi
    
    # Create new lock file
    echo $$ > "${LOCK_FILE}"
}

# =============================================================================
# Prerequisite Validation
# =============================================================================
# Validates that all required system commands are available before proceeding.
validate_prerequisites() {
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log "ERROR" "Required command '${cmd}' not found"
            send_email "${SCRIPT_NAME} - Missing Prerequisite" \
                "Required command '${cmd}' not found. Please install it."
            exit 1
        fi
    done
}

# =============================================================================
# Environment Variable Validation
# =============================================================================
# Ensures all required environment variables are set before proceeding.
check_env_vars() {
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR" "Required environment variable '${var}' is not set"
            send_email "${SCRIPT_NAME} - Missing Environment Variable" \
                "Required environment variable '${var}' is not set."
            exit 1
        fi
    done
}

# =============================================================================
# Health Check Function
# =============================================================================
# Performs system health checks to ensure the environment is suitable for the
# script to run. Customize these checks based on your specific requirements.
health_check() {
    # Check if required service is running
    if ! systemctl is-active --quiet myservice 2>/dev/null; then
        log "ERROR" "Service myservice is not running"
        return 1
    fi
    
    # Check if required port is listening
    if ! nc -z localhost 8080 2>/dev/null; then
        log "ERROR" "Port 8080 is not listening"
        return 1
    fi
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "${disk_usage}" -gt 90 ]; then
        log "ERROR" "Disk space is above 90%"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Cleanup Function
# =============================================================================
# Handles script cleanup on exit, including lock file removal, final status
# reporting, and resource monitoring.
cleanup() {
    local exit_code=$?                # Capture exit code
    local script_end_time=$(date +%s)
    local duration=$((script_end_time - SCRIPT_START_TIME))
    
    # Log script duration
    log "INFO" "Script execution time: ${duration} seconds"
    
    # Remove lock file
    if [ -f "${LOCK_FILE}" ]; then
        rm -f "${LOCK_FILE}"
    fi
    
    # Handle script failure
    if [ ${exit_code} -ne 0 ]; then
        log "ERROR" "Script failed with exit code ${exit_code}"
        send_email "${SCRIPT_NAME} - Script Failed" \
            "Script failed with exit code ${exit_code}. Please check the logs for details."
    else
        log "INFO" "Script completed successfully"
    fi
    
    # Perform final resource monitoring
    monitor_resources
    
    exit ${exit_code}
}

# =============================================================================
# Main Function
# =============================================================================
# Orchestrates the script execution flow, including initialization, validation,
# and the main task execution.
main() {
    log "INFO" "Starting ${SCRIPT_NAME}"
    
    # Rotate logs if needed
    rotate_logs
    
    # Validate prerequisites
    validate_prerequisites
    
    # Check environment variables
    check_env_vars
    
    # Check if script is already running
    check_running
    
    # Perform health check with retry
    if ! retry_operation "health_check" "${MAX_RETRIES}" "${RETRY_DELAY}"; then
        log "ERROR" "Health check failed after ${MAX_RETRIES} attempts"
        send_email "${SCRIPT_NAME} - Health Check Failed" \
            "The script failed its health check after ${MAX_RETRIES} attempts. Please investigate."
        exit 1
    fi
    
    # Monitor system resources
    monitor_resources
    
    # Your custom logic here
    # Example:
    # process_data
    # backup_files
    # send_reports
    
    log "INFO" "Main task completed"
}

# =============================================================================
# Script Execution
# =============================================================================
# Set up trap for cleanup on script exit
# A trap is a command that is executed when a script exits
trap cleanup EXIT

# Run main function
main 