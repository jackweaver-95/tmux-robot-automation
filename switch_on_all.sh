#!/usr/bin/env bash
# switch_on_all.sh - Turn on all power switches in sequence
#
# Turns on switches 1 (arms/neck), 2 (VLC), and 4 (wheels).
# The heartbeat must already be running before calling this.

set -euo pipefail

SAFETY_BOARD_DIR="$HOME/safety-board"

cd "$SAFETY_BOARD_DIR"
. venv/bin/activate

echo "Turning on Switch 1 (arms, grippers, neck)..."
python wscp_orin_client.py --node 0x01 switch 1 on
echo "  Switch 1: ON"

echo "Turning on Switch 2 (VLC)..."
python wscp_orin_client.py --node 0x01 switch 2 on
echo "  Switch 2: ON"

echo "Turning on Switch 4 (wheels)..."
python wscp_orin_client.py --node 0x01 switch 4 on
echo "  Switch 4: ON"

echo ""
echo "All switches ON. You can now start the Isaac stack."
