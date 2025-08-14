#!/bin/bash
set -e

# Determine the original user (even if running via sudo)
ORIGINAL_USER="${SUDO_USER:-$USER}"

# Get the full path to colima for that user
COLIMA_PATH=$(sudo -u "$ORIGINAL_USER" command -v colima)

if [ -z "$COLIMA_PATH" ]; then
    echo "ERROR: colima executable not found for user $ORIGINAL_USER"
    exit 1
fi

echo "Using original user: $ORIGINAL_USER"
echo "Using colima path: $COLIMA_PATH"

# ------------------------
# Config
# ------------------------
PLIST_NAME="com.harness.colimadiagnostics"
PLIST_PATH="/Library/LaunchDaemons/${PLIST_NAME}.plist"
NEWSYSLOG_CONF="/etc/newsyslog.d/colimadiagnostics.conf"
LOG_STDOUT="/var/log/HarnessColimaDiagnostics/colima_diagnostics.log"

# Auto-detect script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/colima_diagnostics.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: Script $SCRIPT_PATH not found in installer directory."
    exit 1
fi

# ------------------------
# 1. Create plist with correct script path
# ------------------------
cat > "${PLIST_NAME}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPT_PATH}</string>
    </array>

    <!-- Run every 30 seconds -->
    <key>StartInterval</key>
    <integer>30</integer>

    <!-- Run at startup -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Log stdout and stderr -->
    <key>StandardOutPath</key>
    <string>${LOG_STDOUT}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_STDOUT}</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>COLIMA_PATH</key>
        <string>${COLIMA_PATH}</string>
        <key>ORIGINAL_USER</key>
        <string>${ORIGINAL_USER}</string>
    </dict>
</dict>
</plist>
EOF

# ------------------------
# 2. Copy plist to LaunchDaemons
# ------------------------
sudo cp "${PLIST_NAME}.plist" "$PLIST_PATH"
sudo chown root:wheel "$PLIST_PATH"
sudo chmod 644 "$PLIST_PATH"

# ------------------------
# 3. Create log files
# ------------------------
sudo mkdir -p "$(dirname "$LOG_STDOUT")"
sudo touch "$LOG_STDOUT"
sudo chown root:wheel "$LOG_STDOUT"
sudo chmod 644 "$LOG_STDOUT"

# ------------------------
# 4. Configure hourly log rotation (last 6 logs)
# ------------------------
sudo mkdir -p /etc/newsyslog.d
sudo bash -c "cat > $NEWSYSLOG_CONF" <<EOF
$LOG_STDOUT root:wheel 644 6 5M 0 Z
EOF
sudo chown root:wheel "$NEWSYSLOG_CONF"
sudo chmod 644 "$NEWSYSLOG_CONF"

# ------------------------
# 5. Load and start LaunchDaemon
# ------------------------
sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
sudo launchctl load "$PLIST_PATH"
sudo launchctl start "$PLIST_NAME"

echo "✅ Service '${PLIST_NAME}' installed and started."
echo "📜 Logs: $LOG_STDOUT"
echo "🔄 Rotates every day or after 5MB file size, keeping last 6 log files."
