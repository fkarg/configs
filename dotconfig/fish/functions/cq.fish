# cq — "claude queue": enqueue a deferred follow-up for a running Claude Code
# session. The Claude `Stop` hook (stop-queue-hook.sh) drains one line per
# turn-end, so a queued message runs ONLY once Claude would otherwise finish —
# unlike the native input queue, which fires at the next pause (steering).
#
# Run from a second terminal/pane cd'd into the SAME repo as the Claude session
# (the queue is keyed by git root). Bang-mode `!cq ...` inside Claude does NOT
# work mid-turn — it only queues raw text.
#
#   cq run the test suite and fix failures   # enqueue a follow-up
#   cq                                        # list pending (also: cq -l)
#   cq -c | cq --clear                        # clear the queue
#   cq -h | cq --help                         # usage
#   cq -- -starts-with-dash                   # enqueue a message starting with '-'
#
# Key derivation MUST match stop-queue-hook.sh: root -> replace '/' with '%'.
function cq --description 'Queue a deferred message for a running Claude Code session'
    set -l root (git rev-parse --show-toplevel 2>/dev/null; or pwd)
    set -l key (string replace -a / % -- $root)
    set -l qdir "$HOME/.claude/queue"
    set -l queue "$qdir/$key"

    # Default action is "list" (bare `cq`). Leading flags pick another.
    set -l action list
    if test (count $argv) -gt 0
        switch $argv[1]
            case -h --help
                set action help
            case -l --list ls
                set action list
            case -c --clear clear
                set action clear
            case --
                set action add
                set -e argv[1]
            case '*'
                set action add
        end
    end

    switch $action
        case help
            echo "cq — queue deferred messages for a running Claude Code session"
            echo
            echo "The Stop hook delivers a queued line only when Claude would otherwise"
            echo "finish the turn. Queue is per-repo (git root); run from the same repo."
            echo
            echo "Usage:"
            echo "  cq <message...>    enqueue a follow-up"
            echo "  cq                 list pending messages"
            echo "  cq -l, --list      list pending messages"
            echo "  cq -c, --clear     clear the queue"
            echo "  cq -h, --help      show this help"
            echo "  cq -- <message>    enqueue a message starting with a dash"

        case list
            if test -s "$queue"
                echo "cq: "(count (cat "$queue"))" pending → $root"
                cat -n "$queue"
            else
                echo "cq: queue empty → $root"
            end

        case clear
            rm -f "$queue"
            echo "cq: cleared → $root"

        case add
            mkdir -p "$qdir"
            printf '%s\n' "$argv" >> "$queue"
            echo "cq: queued ("(count (cat "$queue"))" pending) → $root"
    end
end
