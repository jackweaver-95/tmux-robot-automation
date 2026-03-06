#!/usr/bin/env bash
# robot_estop.sh - Emergency stop. Can be run from any terminal.

set -euo pipefail

cd "$HOME/safety-board"
. venv/bin/activate

echo "!!! TRIGGERING ESTOP !!!"
python wscp_orin_client.py estop
echo "Estop triggered."
