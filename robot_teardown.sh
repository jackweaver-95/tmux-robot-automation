#!/usr/bin/env bash
# robot_teardown.sh - Gracefully shut down the robot and kill the tmux session
#
# Order: deactivate lifecycle -> stop isaac -> switches off -> kill session

set -euo pipefail

SESSION="robot"
SAFETY_BOARD_DIR="$HOME/safety-board"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "No '$SESSION' tmux session found."
    exit 1
fi

echo "=== V4 Robot Teardown ==="
echo ""

read -rp "Deactivate lifecycle and stop Isaac stack? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Stopping Isaac stack..."
    tmux send-keys -t "$SESSION:isaac.1" C-c
    sleep 1
    tmux send-keys -t "$SESSION:isaac.1" "stop-isaac" C-m
    echo "  Isaac stack stop issued."
    sleep 2
fi

read -rp "Turn off all power switches? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Turning off switches..."
    cd "$SAFETY_BOARD_DIR"
    . venv/bin/activate
    python wscp_orin_client.py --node 0x01 switch 4 off
    echo "  Switch 4 (wheels): OFF"
    python wscp_orin_client.py --node 0x01 switch 2 off
    echo "  Switch 2 (VLC): OFF"
    python wscp_orin_client.py --node 0x01 switch 1 off
    echo "  Switch 1 (arms/neck): OFF"
fi

read -rp "Kill tmux session '$SESSION'? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    tmux kill-session -t "$SESSION"
    echo "Session killed."
else
    echo "Session left running."
fi

echo "Teardown complete."
