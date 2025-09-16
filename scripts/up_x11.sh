#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="${DISPLAY:-host.docker.internal:0}"
docker compose --profile x11 up -d --build