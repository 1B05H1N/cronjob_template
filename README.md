# Cronjob Script Template

This template provides a foundation for creating error-checked scripts that run as cronjobs. It includes comprehensive error handling, logging, and monitoring capabilities.

## Features

- Comprehensive error handling and logging
- Lock file mechanism to prevent concurrent runs
- Email notifications for failures
- Detailed logging with timestamps
- Environment variable validation
- Graceful cleanup on exit
- Health check functionality
- Prerequisite validation
- Automatic cleanup of stale lock files
- Exit code tracking and reporting

## Prerequisites

- Bash shell
- `mail` command for email notifications (optional)
- Basic understanding of cron syntax
- Common Unix utilities (awk, sed, grep)

## Usage

1. Copy the template script (`cronjob_template.sh`) to your desired location
2. Make the script executable: `chmod +x cronjob_template.sh`
3. Customize the script variables and functions for your specific needs
4. Set up your cronjob using `crontab -e`

Example cronjob entry:
```bash
# Run every day at 2:30 AM
30 2 * * * /path/to/your/script/cronjob_template.sh >> /path/to/logs/cronjob.log 2>&1
```

## Script Components

### Configuration Variables
```bash
SCRIPT_NAME="cronjob_template"        # Name of your script
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"  # Lock file location
LOG_FILE="/var/log/${SCRIPT_NAME}.log" # Log file location
EMAIL_RECIPIENTS="admin@example.com"  # Email recipients for notifications
REQUIRED_ENV_VARS=("ENV_VAR1" "ENV_VAR2") # Required environment variables
```

### Core Functions

1. **Logging System**
   - Timestamped log entries
   - Multiple log levels (INFO, WARNING, ERROR)
   - Simultaneous output to console and log file
   - Configurable log file location

2. **Email Notifications**
   - Automatic failure notifications
   - Configurable recipients
   - Graceful fallback if mail command is unavailable

3. **Environment Validation**
   - Checks for required environment variables
   - Detailed error reporting for missing variables
   - Email notification for missing variables

4. **Lock File Management**
   - Prevents concurrent script execution
   - Automatic cleanup of stale lock files
   - PID-based process verification

5. **Prerequisite Checking**
   - Validates required system commands
   - Configurable list of required utilities
   - Early failure detection

6. **Health Check System**
   - Customizable health check function
   - Integration with monitoring systems
   - Failure notification capability

7. **Cleanup Handler**
   - Automatic cleanup on script exit
   - Lock file removal
   - Exit code tracking
   - Final status reporting

## Error Handling

The script includes several layers of error handling:
- Command execution checks
- Environment variable validation
- Lock file mechanism
- Email notifications for critical failures
- Detailed logging
- Automatic cleanup on failures
- Process status verification

## Logging

Logs are written to both a file and stdout/stderr. The log file location is configurable via the `LOG_FILE` variable. Log entries include:
- Timestamp
- Log level (INFO, WARNING, ERROR)
- Detailed message
- Process ID (where relevant)

## Monitoring

The script includes a health check function that can be used to monitor the script's status. It also sends email notifications for:
- Script failures
- Missing environment variables
- Concurrent execution attempts
- Health check failures
- Missing prerequisites

## Customization

Key variables to customize:
- `SCRIPT_NAME`: Name of your script
- `LOCK_FILE`: Path to lock file
- `LOG_FILE`: Path to log file
- `EMAIL_RECIPIENTS`: Email addresses for notifications
- `REQUIRED_ENV_VARS`: List of required environment variables
- `required_commands`: List of required system commands

## Best Practices

1. Always test your script before adding it to cron
2. Use absolute paths in your script
3. Set appropriate permissions
4. Monitor your logs regularly
5. Keep your error handling up to date
6. Use the lock file mechanism to prevent concurrent runs
7. Implement meaningful health checks
8. Set up proper email notifications
9. Use descriptive log messages
10. Keep environment variables documented

## Troubleshooting

Common issues and solutions:
- Permission denied: Check file permissions and ownership
- Lock file issues: Remove stale lock files manually
- Email not working: Check mail server configuration
- Environment variables: Ensure all required variables are set
- Log file issues: Check directory permissions and disk space
- Concurrent execution: Verify lock file mechanism is working
- Missing commands: Install required system utilities

## Security Considerations

1. Set appropriate file permissions
2. Use secure locations for lock and log files
3. Validate all input and environment variables
4. Implement proper error handling
5. Use secure email configurations
6. Follow principle of least privilege

## Examples

### Basic Usage Example
```bash
# Set required environment variables
export ENV_VAR1="value1"
export ENV_VAR2="value2"

# Run the script
./cronjob_template.sh
```

### Custom Health Check Example
```bash
health_check() {
    # Check if a specific service is running
    if ! systemctl is-active --quiet myservice; then
        log "ERROR" "Service myservice is not running"
        return 1
    fi
    
    # Check if a port is listening
    if ! nc -z localhost 8080; then
        log "ERROR" "Port 8080 is not listening"
        return 1
    fi
    
    # Check disk space
    if [ $(df / | awk 'NR==2 {print $5}' | sed 's/%//') -gt 90 ]; then
        log "ERROR" "Disk space is above 90%"
        return 1
    fi
    
    return 0
}
```

### Custom Main Function Example
```bash
main() {
    log "INFO" "Starting ${SCRIPT_NAME}"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Check environment variables
    check_env_vars
    
    # Check if script is already running
    check_running
    
    # Perform health check
    if ! health_check; then
        log "ERROR" "Health check failed"
        send_email "${SCRIPT_NAME} - Health Check Failed" \
            "The script failed its health check. Please investigate."
        exit 1
    fi
    
    # Your custom logic here
    process_data
    backup_files
    send_reports
    
    log "INFO" "Main task completed"
}
```

## Performance Considerations

1. **Resource Usage**
   - Monitor CPU and memory usage
   - Implement resource limits if needed
   - Consider using `nice` for CPU-intensive tasks
   - Use `ionice` for I/O intensive operations

2. **Execution Time**
   - Set appropriate cron intervals
   - Implement timeout mechanisms
   - Log execution duration
   - Consider parallel processing for long tasks

3. **Disk Space**
   - Implement log rotation
   - Clean up temporary files
   - Monitor disk usage
   - Set up alerts for low disk space

4. **Network Considerations**
   - Implement retry mechanisms
   - Set appropriate timeouts
   - Handle network failures gracefully
   - Cache results when possible

## Integration Guidelines

### Monitoring Systems
```bash
# Example: Prometheus metrics
prometheus_metrics() {
    local metric_name=$1
    local value=$2
    echo "${metric_name} ${value}" >> /var/lib/node_exporter/textfile_collector/${SCRIPT_NAME}.prom
}
```

### Log Aggregation
```bash
# Example: Logstash configuration
input {
    file {
        path => "/var/log/${SCRIPT_NAME}.log"
        type => "cronjob"
    }
}
```

### Alerting Systems
```bash
# Example: Integration with alertmanager
# https://prometheus.io/docs/alerting/latest/alertmanager/
send_alert() {
    local severity=$1
    local message=$2
    curl -X POST http://alertmanager:9093/api/v1/alerts -d "[{
        \"labels\": {
            \"alertname\": \"${SCRIPT_NAME}_failure\",
            \"severity\": \"${severity}\"
        },
        \"annotations\": {
            \"summary\": \"${message}\"
        }
    }]"
}
```

## Testing Guidelines

1. **Unit Testing**
   - Test individual functions
   - Mock external dependencies
   - Verify error handling
   - Check edge cases

2. **Integration Testing**
   - Test with real dependencies
   - Verify email notifications
   - Check lock file behavior
   - Test concurrent execution

3. **Performance Testing**
   - Measure execution time
   - Check resource usage
   - Test under load
   - Verify cleanup

4. **Security Testing**
   - Check file permissions
   - Verify environment isolation
   - Test input validation
   - Check for injection vulnerabilities

## Maintenance

1. **Regular Tasks**
   - Review and rotate logs
   - Update dependencies
   - Check for stale lock files
   - Verify email configurations

2. **Monitoring**
   - Set up log monitoring
   - Configure alert thresholds
   - Track execution patterns
   - Monitor resource usage

3. **Documentation**
   - Keep README updated
   - Document changes
   - Maintain runbooks
   - Update troubleshooting guides

## Version Control

1. **Best Practices**
   - Use meaningful commit messages
   - Tag releases
   - Maintain changelog
   - Document breaking changes

2. **Branch Strategy**
   - Use feature branches
   - Implement pull requests
   - Maintain stable branch
   - Follow semantic versioning

## License

This template is provided under the MIT License.