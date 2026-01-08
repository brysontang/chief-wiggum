#!/usr/bin/env bash
#
# Chief Wiggum Status Update Hook
#
# This script is called by Claude Code hooks to track task progress.
# It reads JSON from stdin containing session info and updates status files.
#
# Usage: status-update.sh <event_type>
#   event_type: post_tool | stop | notify
#
# Environment:
#   CHIEF_WIGGUM_TASK_ID - Task identifier (required for tracking)
#   CHIEF_WIGGUM_VAULT   - Path to vault (default: ~/.chief-wiggum)
#
# Stdin (JSON):
#   session_id: string
#   transcript_path: string (for stop events)
#   tool_name: string (for post_tool events)
#   notification_type: string (for notify events)

set -euo pipefail

EVENT_TYPE="${1:-unknown}"
TASK_ID="${CHIEF_WIGGUM_TASK_ID:-}"
VAULT="${CHIEF_WIGGUM_VAULT:-$HOME/.chief-wiggum}"
STATUS_DIR="$VAULT/status"
STUCK_THRESHOLD=3

# Check for jq availability
if command -v jq &> /dev/null; then
  HAS_JQ=true
else
  HAS_JQ=false
  # Warn once per session (check if we've already warned)
  if [[ -z "${CHIEF_WIGGUM_JQ_WARNED:-}" ]]; then
    echo "[chief-wiggum] Warning: jq not found. Install jq for reliable status tracking." >&2
    export CHIEF_WIGGUM_JQ_WARNED=1
  fi
fi

# Read JSON from stdin
INPUT=$(cat)

# JSON field extraction with jq fallback
get_json_field() {
  local field="$1"
  if [[ "$HAS_JQ" == "true" ]]; then
    echo "$INPUT" | jq -r ".$field // empty" 2>/dev/null || echo ""
  else
    # Fallback to grep/sed (fragile but works for simple cases)
    echo "$INPUT" | grep -o "\"$field\":[^,}]*" | sed 's/.*://' | tr -d ' "' || echo ""
  fi
}

# Get field from status JSON
get_status_field() {
  local json="$1"
  local field="$2"
  if [[ "$HAS_JQ" == "true" ]]; then
    echo "$json" | jq -r ".$field // empty" 2>/dev/null || echo ""
  else
    echo "$json" | grep -o "\"$field\":[^,}]*" | sed 's/.*://' | tr -d ' "' || echo ""
  fi
}

# Get array length from status JSON
get_history_length() {
  local json="$1"
  if [[ "$HAS_JQ" == "true" ]]; then
    echo "$json" | jq '.iterations_history | length' 2>/dev/null || echo "0"
  else
    # Count occurrences of "iter" in history
    echo "$json" | grep -o '"iter"' | wc -l | tr -d ' '
  fi
}

# Check if last N outcomes are identical (stuck detection)
check_stuck() {
  local json="$1"
  local threshold="$2"

  if [[ "$HAS_JQ" == "true" ]]; then
    local unique_count
    unique_count=$(echo "$json" | jq "[.iterations_history[-$threshold:][].outcome] | unique | length" 2>/dev/null || echo "0")
    if [[ "$unique_count" == "1" ]]; then
      return 0  # Stuck
    fi
    return 1  # Not stuck
  else
    # Fallback: check if last outcomes contain same error pattern
    local outcomes
    outcomes=$(echo "$json" | grep -o '"outcome":"[^"]*"' | tail -"$threshold" | sort -u | wc -l | tr -d ' ')
    if [[ "$outcomes" == "1" ]]; then
      return 0
    fi
    return 1
  fi
}

# Build updated status JSON
build_status_json() {
  local task="$1"
  local name="$2"
  local path="$3"
  local status="$4"
  local iteration="$5"
  local max_iter="$6"
  local history="$7"
  local started="$8"
  local timestamp="$9"

  if [[ "$HAS_JQ" == "true" ]]; then
    jq -n \
      --arg task "$task" \
      --arg name "$name" \
      --arg path "$path" \
      --arg status "$status" \
      --argjson iteration "$iteration" \
      --argjson max_iter "$max_iter" \
      --argjson history "$history" \
      --arg started "$started" \
      --arg timestamp "$timestamp" \
      '{
        task: $task,
        name: $name,
        path: $path,
        status: $status,
        iteration: $iteration,
        max_iterations: $max_iter,
        iterations_history: $history,
        started_at: $started,
        last_update: $timestamp
      }'
  else
    # Fallback: manual JSON construction
    cat <<EOF
{
  "task": "$task",
  "name": "$name",
  "path": "$path",
  "status": "$status",
  "iteration": $iteration,
  "max_iterations": $max_iter,
  "iterations_history": $history,
  "started_at": "$started",
  "last_update": "$timestamp"
}
EOF
  fi
}

# Add entry to history array
add_history_entry() {
  local current_history="$1"
  local iter="$2"
  local outcome="$3"

  # Escape special characters in outcome
  outcome=$(echo "$outcome" | tr '"' "'" | tr '\n' ' ' | cut -c1-200)

  if [[ "$HAS_JQ" == "true" ]]; then
    echo "$current_history" | jq --argjson iter "$iter" --arg outcome "$outcome" \
      '. + [{"iter": $iter, "outcome": $outcome}]'
  else
    # Fallback: string manipulation
    if [[ "$current_history" == "[]" ]]; then
      echo "[{\"iter\": $iter, \"outcome\": \"$outcome\"}]"
    else
      # Remove trailing ] and add new entry
      echo "${current_history%]}, {\"iter\": $iter, \"outcome\": \"$outcome\"}]"
    fi
  fi
}

SESSION_ID=$(get_json_field "session_id")
TRANSCRIPT_PATH=$(get_json_field "transcript_path")

# If no task ID, we're not tracking this session
if [[ -z "$TASK_ID" ]]; then
  exit 0
fi

# Ensure status directory exists
mkdir -p "$STATUS_DIR"

STATUS_FILE="$STATUS_DIR/$TASK_ID.json"
# Temp file for atomic writes (same dir to ensure same filesystem)
STATUS_TEMP="$STATUS_DIR/.$TASK_ID.json.tmp.$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Atomic write helper - writes to temp file then moves
atomic_write() {
  local content="$1"
  local dest="$2"
  local temp="$3"
  echo "$content" > "$temp"
  mv -f "$temp" "$dest"
}

# Read current status or initialize
if [[ -f "$STATUS_FILE" ]]; then
  CURRENT_STATUS=$(cat "$STATUS_FILE")
else
  if [[ "$HAS_JQ" == "true" ]]; then
    CURRENT_STATUS=$(jq -n \
      --arg task "$TASK_ID" \
      --arg timestamp "$TIMESTAMP" \
      '{
        task: $task,
        name: "",
        path: "",
        status: "running",
        iteration: 0,
        max_iterations: 20,
        iterations_history: [],
        started_at: $timestamp,
        last_update: $timestamp
      }')
  else
    CURRENT_STATUS=$(cat <<EOF
{
  "task": "$TASK_ID",
  "name": "",
  "path": "",
  "status": "running",
  "iteration": 0,
  "max_iterations": 20,
  "iterations_history": [],
  "started_at": "$TIMESTAMP",
  "last_update": "$TIMESTAMP"
}
EOF
)
  fi
fi

# Extract current values
CURRENT_ITER=$(get_status_field "$CURRENT_STATUS" "iteration")
CURRENT_ITER=${CURRENT_ITER:-0}
MAX_ITER=$(get_status_field "$CURRENT_STATUS" "max_iterations")
MAX_ITER=${MAX_ITER:-20}
CURRENT_TASK_STATUS=$(get_status_field "$CURRENT_STATUS" "status")
TASK_NAME=$(get_status_field "$CURRENT_STATUS" "name")
TASK_PATH=$(get_status_field "$CURRENT_STATUS" "path")
STARTED_AT=$(get_status_field "$CURRENT_STATUS" "started_at")

# Get current history
if [[ "$HAS_JQ" == "true" ]]; then
  CURRENT_HISTORY=$(echo "$CURRENT_STATUS" | jq '.iterations_history')
else
  CURRENT_HISTORY=$(echo "$CURRENT_STATUS" | grep -o '"iterations_history":\s*\[[^]]*\]' | sed 's/"iterations_history":\s*//' || echo "[]")
fi

case "$EVENT_TYPE" in
  post_tool)
    # Tool was used - update last_update timestamp only
    if [[ "$HAS_JQ" == "true" ]]; then
      UPDATED=$(echo "$CURRENT_STATUS" | jq --arg ts "$TIMESTAMP" '.last_update = $ts')
    else
      # Simple sed replacement
      UPDATED=$(sed "s/\"last_update\":[^,}]*/\"last_update\": \"$TIMESTAMP\"/" <<< "$CURRENT_STATUS")
    fi
    atomic_write "$UPDATED" "$STATUS_FILE" "$STATUS_TEMP"
    ;;

  stop)
    # Session stopped - analyze transcript for completion
    NEW_ITER=$((CURRENT_ITER + 1))
    OUTCOME="unknown"
    IS_DONE=false
    IS_STUCK=false

    # Check transcript for completion signals (unique markers to avoid false positives)
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      # Look for unique DONE marker in transcript
      if tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | grep -qF "###CHIEF_WIGGUM_DONE###"; then
        IS_DONE=true
        OUTCOME="completed successfully"
      elif tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | grep -qF "###CHIEF_WIGGUM_STUCK###"; then
        IS_STUCK=true
        OUTCOME=$(tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | grep -oF "###CHIEF_WIGGUM_STUCK###" -A1 | tail -1 | cut -c1-100)
      else
        # Extract last error or outcome
        LAST_ERROR=$(tail -50 "$TRANSCRIPT_PATH" 2>/dev/null | grep -iE "(error|failed|exception|cannot|unable)" | tail -1 | cut -c1-100 || echo "")
        if [[ -n "$LAST_ERROR" ]]; then
          OUTCOME="$LAST_ERROR"
        else
          OUTCOME="iteration completed, verification pending"
        fi
      fi
    fi

    # Add new entry to history
    NEW_HISTORY=$(add_history_entry "$CURRENT_HISTORY" "$NEW_ITER" "$OUTCOME")

    # Check for stuck condition
    if [[ "$IS_STUCK" != "true" && $NEW_ITER -ge $STUCK_THRESHOLD ]]; then
      # Build temp status with new history for stuck check
      TEMP_STATUS=$(build_status_json "$TASK_ID" "$TASK_NAME" "$TASK_PATH" "running" "$NEW_ITER" "$MAX_ITER" "$NEW_HISTORY" "$STARTED_AT" "$TIMESTAMP")
      if check_stuck "$TEMP_STATUS" "$STUCK_THRESHOLD"; then
        IS_STUCK=true
      fi
    fi

    # Determine new status
    if [[ "$IS_DONE" == "true" ]]; then
      NEW_STATUS="completed"
    elif [[ "$IS_STUCK" == "true" ]]; then
      NEW_STATUS="stuck"
    elif [[ $NEW_ITER -ge $MAX_ITER ]]; then
      NEW_STATUS="stuck"
      OUTCOME="max iterations ($MAX_ITER) reached"
      NEW_HISTORY=$(add_history_entry "$CURRENT_HISTORY" "$NEW_ITER" "$OUTCOME")
    else
      NEW_STATUS="running"
    fi

    # Write updated status (atomic)
    UPDATED=$(build_status_json "$TASK_ID" "$TASK_NAME" "$TASK_PATH" "$NEW_STATUS" "$NEW_ITER" "$MAX_ITER" "$NEW_HISTORY" "$STARTED_AT" "$TIMESTAMP")
    atomic_write "$UPDATED" "$STATUS_FILE" "$STATUS_TEMP"

    # Send notification for completion/stuck
    if [[ "$NEW_STATUS" == "completed" || "$NEW_STATUS" == "stuck" ]]; then
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      bash "$SCRIPT_DIR/notify.sh" "$TASK_ID" "$NEW_STATUS" "$OUTCOME" 2>/dev/null || true
    fi

    # Exit with code 2 to signal ralph-wiggum style continuation
    if [[ "$NEW_STATUS" == "running" ]]; then
      exit 2
    fi
    ;;

  notify)
    # Permission or idle prompt - may need user input
    NOTIFICATION_TYPE=$(get_json_field "notification_type")

    if [[ "$NOTIFICATION_TYPE" == "permission_prompt" ]]; then
      # Update status to needs_input (atomic)
      if [[ "$HAS_JQ" == "true" ]]; then
        UPDATED=$(echo "$CURRENT_STATUS" | jq --arg ts "$TIMESTAMP" '.status = "needs_input" | .last_update = $ts')
      else
        UPDATED=$(sed -e "s/\"status\":[^,}]*/\"status\": \"needs_input\"/" \
            -e "s/\"last_update\":[^,}]*/\"last_update\": \"$TIMESTAMP\"/" <<< "$CURRENT_STATUS")
      fi
      atomic_write "$UPDATED" "$STATUS_FILE" "$STATUS_TEMP"

      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      bash "$SCRIPT_DIR/notify.sh" "$TASK_ID" "needs_input" "Permission required" 2>/dev/null || true
    fi
    ;;
esac

exit 0
