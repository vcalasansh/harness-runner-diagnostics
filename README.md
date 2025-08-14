**Usage:**

1. Check if the `colima_diagnostics.sh` script works:
```
sudo ORIGINAL_USER="${SUDO_USER:-$USER}" COLIMA_PATH=$(sudo -u "${SUDO_USER:-$USER}" command -v colima) ./colima_diagnostics.sh
```
Make any necessary adjustments to the `colima_diagnostics.sh` script.

2. Install MacOS service for obtaining Colima and Runner diagnostics every 30 seconds:
```
sudo ./install_colima_diagnostics.sh 
```

3. Check logs:
```
tail -f /var/log/HarnessColimaDiagnostics/colima_diagnostics.log
```
