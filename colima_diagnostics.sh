#!/bin/bash
echo "Running Colima Diagnostics: $(date +"%Y-%m-%d %H:%M:%S")"

echo "\n=== 1. Colima status ==="
su - "$ORIGINAL_USER" -c ''$COLIMA_PATH' status --verbose || echo "Colima not running"'

echo "\n=== 2. macOS resource limits (host) ==="
echo "Max file descriptors on host machine: $(ulimit -n)"
echo "File descriptor usage on runner:"
RUNNER_PID=$(pgrep runner | head -n 1)
if [ -z "$RUNNER_PID" ]; then
    echo "No runner is running"
else
    echo "File descriptor usage on runner (PID $RUNNER_PID):"
    lsof -p "$RUNNER_PID"
    echo "Total: $(lsof -p $RUNNER_PID | wc -l)"
fi
echo "Max user processes: $(ulimit -u)"
echo "Processes for current user ($ORIGINAL_USER): $(ps -u $ORIGINAL_USER | wc -l)"

echo "\n=== 3. macOS CPU pressure check ==="
ps -Ao pid,pcpu,command -ww | tail -n +2 | sort -k2 -nr | head -n 10 | awk '{cmd=""; for(i=3;i<=NF;i++) cmd=cmd $i " "; if(length(cmd)>200) cmd=substr(cmd,1,200) "..."; printf "%-7s %-6s %s\n",$1,$2,cmd}'

echo "\n=== 4. macOS Memory pressure check ==="
ps -Ao pid,pmem,command -ww | tail -n +2 | sort -k2 -nr | head -n 10 | awk '{cmd=""; for(i=3;i<=NF;i++) cmd=cmd $i " "; if(length(cmd)>200) cmd=substr(cmd,1,200) "..."; printf "%-7s %-6s %s\n",$1,$2,cmd}'

echo "\n=== 5. macOS recent process kills or memory pressure ==="
log show --predicate 'eventMessage CONTAINS "memory pressure" OR eventMessage CONTAINS "killed process"' --debug --last 1m

echo "\n=== 6. SSH into Colima VM and inspect ==="
su - "$ORIGINAL_USER" -c 'COLIMA_PATH='$COLIMA_PATH' bash -s' <<'EOF'
echo -e "\n--- Disk usage ---"
"$COLIMA_PATH" ssh <<'INNER_EOF'
df -h /

echo -e "\n--- Memory usage ---"
free -m

echo -e "\n--- CPU throttling check ---"
grep -i throttling /sys/fs/cgroup/*/cpu.stat 2>/dev/null || echo "No cgroup throttling info found"

echo -e "\n--- File descriptor usage ---"
echo "Open file descriptors: $(ls /proc/*/fd 2>/dev/null | wc -l)"
echo "Max file descriptors: $(ulimit -n)"

echo -e "\n--- Top File descriptor usage ---"
sudo lsof | awk "{print \$2}" | sort | uniq -c | sort -nr | head -20

echo -e "\n--- Docker daemon status ---"
sudo systemctl status docker --no-pager

echo -e "\n--- Recent Docker daemon logs ---"
sudo journalctl -u docker --since "2 minutes ago" --no-pager | tail -n 100

echo -e "\n--- Docker containers ---"
docker ps -a 2>/dev/null || echo "Cannot list Docker containers"

echo -e "\n--- Docker system info ---"
docker system df 2>/dev/null || echo "Cannot get Docker system info"

echo -e "\n--- Docker networks details ---"
for net in $(docker network ls -q); do
    docker network inspect --format \
      '{{.Name}} | Driver={{.Driver}} | Scope={{.Scope}} | Created={{.Created}}' "$net"
done

echo -e "\n--- Check if dockerd is running ---"
pgrep -a dockerd || echo "dockerd not running"

echo -e "\n--- Check if sshd process exists ---"
pgrep -a sshd || echo "sshd not running"

echo -e "\n--- Recent SSH daemon logs ---"
sudo journalctl | grep sshd | tail -n 100

echo -e "\n--- Check OOM kills ---"
sudo dmesg | grep -i kill | tail -n 10
INNER_EOF
EOF
