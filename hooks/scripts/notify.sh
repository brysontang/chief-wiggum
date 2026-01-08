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

# macOS notification
if [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"$SUBTITLE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

# Could add Linux (notify-send) or terminal-notifier support here

exit 0
