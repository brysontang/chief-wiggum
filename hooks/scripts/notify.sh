#!/usr/bin/env bash
#
# Chief Wiggum Notification Helper
#
# Sends system notifications for task events.
# Currently supports macOS via osascript.
#
# Usage: notify.sh <task_id> <status> <message>

set -euo pipefail

TASK_ID="${1:-unknown}"
STATUS="${2:-unknown}"
MESSAGE="${3:-}"

# Notification titles by status
case "$STATUS" in
    completed)
        TITLE="Task Complete"
        SUBTITLE="$TASK_ID finished successfully"
        SOUND="Glass"
        ;;
    stuck)
        TITLE="Task Stuck"
        SUBTITLE="$TASK_ID needs help"
        SOUND="Basso"
        ;;
    needs_input)
        TITLE="Input Required"
        SUBTITLE="$TASK_ID is waiting"
        SOUND="Purr"
        ;;
    *)
        TITLE="Chief Wiggum"
        SUBTITLE="$TASK_ID: $STATUS"
        SOUND="Pop"
        ;;
esac

# Truncate message for notification
MESSAGE="${MESSAGE:0:100}"

# Escape values for AppleScript (prevent injection)
# Replace backslashes first, then double quotes
escape_applescript() {
    local str="$1"
    str="${str//\\/\\\\}"  # Escape backslashes
    str="${str//\"/\\\"}"  # Escape double quotes
    echo "$str"
}

TITLE_SAFE=$(escape_applescript "$TITLE")
SUBTITLE_SAFE=$(escape_applescript "$SUBTITLE")
MESSAGE_SAFE=$(escape_applescript "$MESSAGE")

# macOS notification
if [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "display notification \"$MESSAGE_SAFE\" with title \"$TITLE_SAFE\" subtitle \"$SUBTITLE_SAFE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

# Could add Linux (notify-send) or terminal-notifier support here

exit 0
