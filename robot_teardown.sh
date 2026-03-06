#!/usr/bin/env bash
# robot_teardown.sh - Gracefully shut down the robot and kill the tmux session
#
# Order:
#   1. Deactivate lifecycle nodes
#   2. Stop Isaac stack
#   3. Stop docker containers
#   4. Turn off power switches (reverse order: wheels, VLC, arms)
#   5. Stop heartbeat
#   6. Kill tmux session

set -uo pipefail

SESSION="robot"
SAFETY_BOARD_DIR="$HOME/safety-board"
WBC_CONTAINER="whole_body_coordinator"

echo "=== V4 Robot Teardown ==="
echo ""

# ── Step 1: Deactivate lifecycle nodes ──
read -rp "Step 1: Deactivate lifecycle nodes? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Deactivating lifecycle..."
    if docker ps --format '{{.Names}}' | grep -q "^${WBC_CONTAINER}$"; then
        docker exec "$WBC_CONTAINER" bash -c \
            'ros2 service call /isaac/lifecycle_manager/set_mode std_srvs/srv/SetBool "{data: 0}"' \
            2>/dev/null || echo "  Warning: lifecycle deactivation call failed (may already be inactive)"
        echo "  Lifecycle deactivated."
        sleep 2
    else
        echo "  Container '$WBC_CONTAINER' not running, skipping."
    fi
fi

# ── Step 2: Stop Isaac stack ──
read -rp "Step 2: Stop Isaac stack? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Stopping Isaac stack..."
    # Try stop-isaac alias (send to isaac commands pane if tmux session exists)
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux send-keys -t "$SESSION:isaac.1" C-c
        sleep 1
        tmux send-keys -t "$SESSION:isaac.1" "stop-isaac" C-m
        echo "  stop-isaac issued via tmux."
    else
        # Fallback: try running directly
        stop-isaac 2>/dev/null && echo "  Isaac stack stopped." || echo "  Warning: stop-isaac failed."
    fi
    sleep 3
fi

# ── Step 3: Stop remaining docker containers ──
read -rp "Step 3: Stop remaining Isaac docker containers? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Checking for running Isaac-related containers..."
    running=$(docker ps --format '{{.Names}}' 2>/dev/null || true)
    if [[ -n "$running" ]]; then
        echo "  Running containers:"
        echo "$running" | sed 's/^/    /'
        read -rp "  Stop ALL running containers? [y/N] " stop_all
        if [[ "$stop_all" =~ ^[Yy]$ ]]; then
            docker stop $(docker ps -q) 2>/dev/null
            echo "  All containers stopped."
        fi
    else
        echo "  No running containers found."
    fi
fi

# ── Step 4: Turn off power switches ──
read -rp "Step 4: Turn off all power switches? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # Check if CAN bus is up before trying
    if ! ip link show can0 up &>/dev/null; then
        echo "  CAN bus (can0) is down — switches cannot be reached. Skipping."
    else
        echo "Turning off switches (reverse order)..."
        cd "$SAFETY_BOARD_DIR"
        . venv/bin/activate
        python wscp_orin_client.py --node 0x01 switch 4 off 2>/dev/null \
            && echo "  Switch 4 (wheels): OFF" \
            || echo "  Warning: failed to turn off switch 4"
        python wscp_orin_client.py --node 0x01 switch 2 off 2>/dev/null \
            && echo "  Switch 2 (VLC): OFF" \
            || echo "  Warning: failed to turn off switch 2"
        python wscp_orin_client.py --node 0x01 switch 1 off 2>/dev/null \
            && echo "  Switch 1 (arms/neck): OFF" \
            || echo "  Warning: failed to turn off switch 1"
    fi
fi

# ── Step 5: Stop heartbeat ──
if tmux has-session -t "$SESSION" 2>/dev/null; then
    read -rp "Step 5: Stop heartbeat process? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Sending Ctrl-C to heartbeat pane..."
        tmux send-keys -t "$SESSION:safety.0" C-c
        echo "  Heartbeat stopped."
    fi
fi

# ── Step 6: Kill tmux session ──
if tmux has-session -t "$SESSION" 2>/dev/null; then
    read -rp "Step 6: Kill tmux session '$SESSION'? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        tmux kill-session -t "$SESSION"
        echo "  Session killed."
    else
        echo "  Session left running."
    fi
else
    echo "No tmux session '$SESSION' to kill."
fi

echo ""
echo "Teardown complete."
