# Linux Docker Diagnostics

This repository contains scripts to capture detailed Docker diagnostics on Linux AMD VMs, adapted from the original macOS/Colima version.

## Files

- `linux_docker_diagnostics.sh` - Main diagnostics script that captures system and Docker information
- `install_linux_docker_diagnostics.sh` - Installer script that sets up the diagnostics as a systemd service
- `README_Linux.md` - This file with Linux-specific instructions

## What the diagnostics capture

The Linux version captures:

1. **Docker Status** - Service status, version, and daemon info
2. **System Resource Limits** - File descriptors, process limits, and usage
3. **CPU Pressure** - Top processes by CPU usage
4. **Memory Pressure** - Top processes by memory usage, system memory info
5. **System Load** - Load averages, memory usage, disk usage
6. **Docker-specific diagnostics**:
   - Docker daemon status and logs
   - Container listings
   - Docker system disk usage
   - File descriptor usage
   - CPU throttling (both cgroups v1 and v2)
   - OOM kill detection
   - Network connectivity (Docker socket)
   - Recent systemd errors

## Prerequisites

- Linux system with systemd (Ubuntu, CentOS, RHEL, etc.)
- Docker installed (optional, but diagnostics will show if missing)
- Root/sudo access for installation
- Standard Linux utilities: `ps`, `lsof`, `journalctl`, `dmesg`

## Usage

### 1. Test the diagnostics script

First, test that the diagnostics script works correctly:

```bash
sudo ./linux_docker_diagnostics.sh
```

Review the output and make any necessary adjustments.

### 2. Install as a systemd service

Install the diagnostics to run automatically every 30 seconds:

```bash
sudo ./install_linux_docker_diagnostics.sh
```

This will:
- Create a systemd service and timer
- Set up log rotation (daily, keeping 7 days)
- Start the service automatically
- Enable it to start on boot

### 3. Monitor logs

Check the diagnostic logs:

```bash
# Follow logs in real-time
tail -f /var/log/HarnessDockerDiagnostics/docker_diagnostics.log

# View recent logs
journalctl -u harness-docker-diagnostics.timer -f

# Check service status
systemctl status harness-docker-diagnostics.timer
```

## Service Management

```bash
# Stop the diagnostics service
sudo systemctl stop harness-docker-diagnostics.timer

# Start the diagnostics service
sudo systemctl start harness-docker-diagnostics.timer

# Check status
systemctl status harness-docker-diagnostics.timer

# View recent service logs
journalctl -u harness-docker-diagnostics.service -n 50

# Disable the service (won't start on boot)
sudo systemctl disable harness-docker-diagnostics.timer

# Re-enable the service
sudo systemctl enable harness-docker-diagnostics.timer
```

## Uninstallation

To completely remove the diagnostics service:

```bash
sudo systemctl stop harness-docker-diagnostics.timer
sudo systemctl disable harness-docker-diagnostics.timer
sudo rm /etc/systemd/system/harness-docker-diagnostics.service
sudo rm /etc/systemd/system/harness-docker-diagnostics.timer
sudo rm /etc/logrotate.d/harness-docker-diagnostics
sudo rm -rf /var/log/HarnessDockerDiagnostics/
sudo systemctl daemon-reload
```


### Permission issues
Make sure the script has execute permissions:
```bash
chmod +x linux_docker_diagnostics.sh
chmod +x install_linux_docker_diagnostics.sh
```

### Service not running
Check service status and logs:
```bash
systemctl status harness-docker-diagnostics.timer
journalctl -u harness-docker-diagnostics.service -n 20
```

### High log volume
If logs are too verbose, you can:
1. Increase the timer interval by editing `/etc/systemd/system/harness-docker-diagnostics.timer`
2. Modify log rotation in `/etc/logrotate.d/harness-docker-diagnostics`
3. Filter the diagnostics script output

## Log File Locations

- Main log: `/var/log/HarnessDockerDiagnostics/docker_diagnostics.log`
- Service logs: `journalctl -u harness-docker-diagnostics.service`
- Timer logs: `journalctl -u harness-docker-diagnostics.timer`
