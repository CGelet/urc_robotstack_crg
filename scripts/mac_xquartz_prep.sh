#!/usr/bin/env bash
set -euo pipefail
echo "Open XQuartz → Preferences → Security: check 'Allow connections from network clients'."
open -a XQuartz || true
sleep 2
xhost +127.0.0.1 >/dev/null 2>&1 || true
xhost +localhost  >/dev/null 2>&1 || true
echo "XQuartz ready. DISPLAY should be host.docker.internal:0"