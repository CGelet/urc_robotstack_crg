#!/usr/bin/env bash
set -euo pipefail
docker compose --profile xpra up -d --build
echo "Open:"
echo "  ROS: http://localhost:14501/"
echo "   GZ: http://localhost:14502/"
echo "  CMU: http://localhost:14503/"