#!/bin/bash
echo "Running Linux Docker Diagnostics: $(date +"%Y-%m-%d %H:%M:%S")"

echo -e "\n=== 1. Docker status ==="
systemctl status docker --no-pager || echo "Docker service not running or accessible"
docker version 2>/dev/null || echo "Docker client not accessible"
docker info 2>/dev/null | head -20 || echo "Docker daemon not accessible"

echo -e "\n=== 2. Linux resource limits (host) ==="
echo "Max file descriptors on host machine: $(ulimit -n)"
echo "File descriptor usage on runner:"
RUNNER_PID=$(pgrep runner | head -n 1)
if [ -z "$RUNNER_PID" ]; then
    echo "No runner is running"
else
    echo "File descriptor usage on runner (PID $RUNNER_PID):"
    lsof -p "$RUNNER_PID" 2>/dev/null || echo "lsof not available or permission denied"
    lsof -p "$RUNNER_PID" 2>/dev/null | wc -l | xargs echo "Total:"
fi
echo "Max user processes: $(ulimit -u)"
echo "Processes for current user ($USER): $(ps -u $USER | wc -l)"

echo -e "\n=== 3. Linux CPU pressure check ==="
echo "Top 10 processes by CPU usage:"
ps -Ao pid,pcpu,command --no-headers | sort -k2 -nr | head -n 10 | awk '{cmd=""; for(i=3;i<=NF;i++) cmd=cmd $i " "; if(length(cmd)>200) cmd=substr(cmd,1,200) "..."; printf "%-7s %-6s %s\n",$1,$2,cmd}'

echo -e "\n=== 4. Linux Memory pressure check ==="
echo "Top 10 processes by memory usage:"
ps -Ao pid,pmem,command --no-headers | sort -k2 -nr | head -n 10 | awk '{cmd=""; for(i=3;i<=NF;i++) cmd=cmd $i " "; if(length(cmd)>200) cmd=substr(cmd,1,200) "..."; printf "%-7s %-6s %s\n",$1,$2,cmd}'

echo -e "\n=== 5. Linux system load and memory info ==="
echo "System load averages:"
cat /proc/loadavg
echo -e "\nMemory information:"
free -h
echo -e "\nDisk usage:"
df -h / /var/lib/docker 2>/dev/null

echo -e "\n=== 6. Docker-specific diagnostics ==="
echo -e "\n--- Docker daemon status ---"
systemctl status docker --no-pager -l

echo -e "\n--- Recent Docker daemon logs ---"
journalctl -u docker --since "2 minutes ago" --no-pager | tail -n 100

echo -e "\n--- Docker daemon process ---"
pgrep -a dockerd || echo "dockerd not running"

echo -e "\n--- Docker containers ---"
docker ps -a 2>/dev/null || echo "Cannot list Docker containers"

echo -e "\n--- Docker system info ---"
docker system df 2>/dev/null || echo "Cannot get Docker system info"

echo -e "\n--- Docker networks ---"
for net in $(docker network ls -q); do
    docker network inspect --format \
      '{{.Name}} | Driver={{.Driver}} | Scope={{.Scope}} | Created={{.Created}}' "$net"
done

echo -e "\n--- File descriptor usage ---"
echo "Open file descriptors in system: $(find /proc/*/fd -type l 2>/dev/null | wc -l)"
echo "Max file descriptors: $(ulimit -n)"

echo -e "\n--- Top processes by file descriptor usage ---"
if command -v lsof >/dev/null 2>&1; then
    lsof 2>/dev/null | awk '{print $2}' | sort | uniq -c | sort -nr | head -20
else
    echo "lsof not available"
fi

echo -e "\n--- CPU throttling check (cgroups v1) ---"
find /sys/fs/cgroup -name "cpu.stat" -exec grep -H throttled {} \; 2>/dev/null | head -10 || echo "No cgroup v1 CPU throttling info found"

echo -e "\n--- CPU throttling check (cgroups v2) ---"
if [ -f /sys/fs/cgroup/cpu.stat ]; then
    echo "Cgroups v2 CPU stats:"
    grep -E "(throttled|wait)" /sys/fs/cgroup/cpu.stat 2>/dev/null || echo "No CPU throttling info in cgroups v2"
fi

echo -e "\n--- Check OOM kills ---"
dmesg | grep -i "killed process" | tail -n 10 || echo "No recent OOM kills found"

echo -e "\n--- Recent kernel messages ---"
dmesg | tail -n 20

echo -e "\n--- Network connectivity check ---"
echo "Docker daemon socket:"
if [ -S /var/run/docker.sock ]; then
    ls -la /var/run/docker.sock
else
    echo "/var/run/docker.sock not found"
fi

echo -e "\n--- Systemd journal errors ---"
journalctl --since "2 minutes ago" --priority=err --no-pager | tail -n 50 || echo "No recent systemd errors"
