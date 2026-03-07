#!/usr/bin/env bash
# robot_command_center.sh - Opens a tmux session for commanding the robot
#
# Run this after robot_bringup.sh and the stack is running.
#
# Creates a tmux session with 3 windows:
#   Window 1 "lifecycle"     : exec into WBC, activate lifecycle manager
#   Window 2 "wbm-result"    : echo whole_body_manager result topic
#   Window 3 "wbm-request"   : publish request_state to whole_body_manager
#
# Usage: ./robot_command_center.sh

set -euo pipefail

SESSION="command-center"
WBC_CONTAINER="whole_body_coordinator"

# Kill existing session if present
if tmux has-session -t "$SESSION" 2>/dev/null; then
    read -rp "Session '$SESSION' already exists. Kill it? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        tmux kill-session -t "$SESSION"
    else
        echo "Attaching to existing session."
        tmux attach-session -t "$SESSION"
        exit 0
    fi
fi

echo "=== Robot Command Center ==="
echo ""

# ── Window 1: lifecycle ──
tmux new-session -d -s "$SESSION" -n "lifecycle" -x "$(tput cols)" -y "$(tput lines)"
tmux send-keys -t "$SESSION:lifecycle" "docker exec -it $WBC_CONTAINER bash" C-m
tmux send-keys -t "$SESSION:lifecycle" "ros2 service call /isaac/lifecycle_manager/set_mode std_srvs/srv/SetBool \"{data: 1}\""

# ── Window 2: wbm-result ──
tmux new-window -t "$SESSION" -n "wbm-result"
tmux send-keys -t "$SESSION:wbm-result" "docker exec -it $WBC_CONTAINER bash" C-m
tmux send-keys -t "$SESSION:wbm-result" "ros2 topic echo /isaac/whole_body_manager/result"

# ── Window 3: wbm-request ──
tmux new-window -t "$SESSION" -n "wbm-request"
tmux send-keys -t "$SESSION:wbm-request" "docker exec -it $WBC_CONTAINER bash" C-m
tmux send-keys -t "$SESSION:wbm-request" "ros2 topic pub -1 /isaac/whole_body_manager/request_state std_msgs/msg/String \"{data: start}\""

# Start on the lifecycle window
tmux select-window -t "$SESSION:lifecycle"

echo "Attaching to tmux session '$SESSION'..."
echo "Navigate windows: Ctrl-b n (next) / Ctrl-b p (prev)"
echo ""
tmux attach-session -t "$SESSION"
