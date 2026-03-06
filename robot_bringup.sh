#!/usr/bin/env bash
# robot_bringup.sh - Automates V4 robot bringup via tmux
#
# Creates a tmux session with all terminals needed for robot operation:
#   Window 1 "setup"  : CAN bus initialization (one-shot)
#   Window 2 "safety" : Heartbeat | Switches | Estop (3 panes)
#   Window 3 "isaac"  : Log | Commands (2 panes)
#
# Usage: ./robot_bringup.sh

set -euo pipefail

SESSION="robot"
SAFETY_BOARD_DIR="$HOME/safety-board"
SPINUP_DIR="$HOME/isaac_production_spinup"

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

echo "=== V4 Robot Bringup ==="
echo ""
echo "Creating tmux session '$SESSION'..."
echo ""
echo "Bringup order:"
echo "  1. Enable CAN buses (window: setup)"
echo "  2. Start heartbeat  (window: safety, pane: heartbeat)"
echo "  3. Turn on switches  (window: safety, pane: switches)"
echo "  4. Start Isaac stack (window: isaac, pane: commands)"
echo "  5. Monitor logs      (window: isaac, pane: log)"
echo "  6. Activate stack    (window: isaac, pane: commands)"
echo ""
echo "Estop is always ready in the safety window."
echo ""

# ── Window 1: setup (CAN bus initialization) ──
tmux new-session -d -s "$SESSION" -n "setup" -x "$(tput cols)" -y "$(tput lines)"
tmux send-keys -t "$SESSION:setup" "cd $SPINUP_DIR" C-m
tmux send-keys -t "$SESSION:setup" "echo '── Step 1: Enable CAN buses ──'" C-m
tmux send-keys -t "$SESSION:setup" "echo 'Run: sudo ./root_setup_can.sh'" C-m
tmux send-keys -t "$SESSION:setup" "echo 'Then switch to the safety window: Ctrl-b n'" C-m
tmux send-keys -t "$SESSION:setup" "# sudo ./root_setup_can.sh"

# ── Window 2: safety (heartbeat, switches, estop) ──
tmux new-window -t "$SESSION" -n "safety"

# Pane 0: Heartbeat
tmux send-keys -t "$SESSION:safety" "cd $SAFETY_BOARD_DIR" C-m
tmux send-keys -t "$SESSION:safety" ". venv/bin/activate" C-m
tmux send-keys -t "$SESSION:safety" "echo '── Step 2: Heartbeat ──'" C-m
tmux send-keys -t "$SESSION:safety" "echo 'Run the heartbeat (must stay running):'" C-m
tmux send-keys -t "$SESSION:safety" "# python wscp_orin_client.py --node 0x01 arm --hold"

# Pane 1: Switch control (split right)
tmux split-window -h -t "$SESSION:safety"
tmux send-keys -t "$SESSION:safety.1" "cd $SAFETY_BOARD_DIR" C-m
tmux send-keys -t "$SESSION:safety.1" ". venv/bin/activate" C-m
tmux send-keys -t "$SESSION:safety.1" "echo '── Step 3: Switch Control ──'" C-m
tmux send-keys -t "$SESSION:safety.1" "echo 'After heartbeat is running, turn on switches:'" C-m
tmux send-keys -t "$SESSION:safety.1" "echo '  Switch 1 (arms/neck):  python wscp_orin_client.py --node 0x01 switch 1 on'" C-m
tmux send-keys -t "$SESSION:safety.1" "echo '  Switch 2 (VLC):        python wscp_orin_client.py --node 0x01 switch 2 on'" C-m
tmux send-keys -t "$SESSION:safety.1" "echo '  Switch 4 (wheels):     python wscp_orin_client.py --node 0x01 switch 4 on'" C-m
tmux send-keys -t "$SESSION:safety.1" "echo ''" C-m
tmux send-keys -t "$SESSION:safety.1" "echo 'Or run all at once:'" C-m
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux send-keys -t "$SESSION:safety.1" "echo '  $SCRIPT_DIR/switch_on_all.sh'" C-m
tmux send-keys -t "$SESSION:safety.1" "# $SCRIPT_DIR/switch_on_all.sh"

# Pane 2: Estop (split below switches pane)
tmux split-window -v -t "$SESSION:safety.1"
tmux send-keys -t "$SESSION:safety.2" "cd $SAFETY_BOARD_DIR" C-m
tmux send-keys -t "$SESSION:safety.2" ". venv/bin/activate" C-m
tmux send-keys -t "$SESSION:safety.2" "echo '── ESTOP ──'" C-m
tmux send-keys -t "$SESSION:safety.2" "echo 'Press UP then ENTER to trigger estop'" C-m
tmux send-keys -t "$SESSION:safety.2" "python wscp_orin_client.py estop"

# ── Window 3: isaac (log + commands) ──
tmux new-window -t "$SESSION" -n "isaac"

# Pane 0: Log
tmux send-keys -t "$SESSION:isaac" "echo '── Step 5: Isaac Log ──'" C-m
tmux send-keys -t "$SESSION:isaac" "echo 'Run: isaac-log'" C-m
tmux send-keys -t "$SESSION:isaac" "# isaac-log"

# Pane 1: Commands (split right)
tmux split-window -h -t "$SESSION:isaac"
tmux send-keys -t "$SESSION:isaac.1" "echo '── Step 4: Isaac Commands ──'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo 'Start the stack:   start-isaac'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo 'Stop the stack:    stop-isaac'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo 'Reset cameras:     $SPINUP_DIR/bin/reset_cams'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo ''" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo 'After stack is running, activate lifecycle:'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo '  docker exec -it whole_body_coordinator bash'" C-m
tmux send-keys -t "$SESSION:isaac.1" "echo '  ros2 service call /isaac/lifecycle_manager/set_mode std_srvs/srv/SetBool \"{data: 1}\"'" C-m
tmux send-keys -t "$SESSION:isaac.1" "# start-isaac"

# Start on the setup window
tmux select-window -t "$SESSION:setup"

# Attach
echo "Attaching to tmux session '$SESSION'..."
echo "Navigate windows: Ctrl-b n (next) / Ctrl-b p (prev)"
echo ""
tmux attach-session -t "$SESSION"
