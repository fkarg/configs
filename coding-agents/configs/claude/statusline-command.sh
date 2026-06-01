#!/usr/bin/env bash
# Claude Code status line — fish-style colors, segments separated by ` | `.
# Segments: cwd | branch | model + ctx% | session tokens | lines +/- | 5h limit + reset
input=$(cat)

j() { echo "$input" | jq -r "$1 // empty"; }

cwd=$(j '.workspace.current_dir // .cwd')
model=$(j '.model.display_name')
ctx_pct=$(j '.context_window.used_percentage')
ctx_used=$(j '.context_window.current_usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)')
tok_in=$(j '.context_window.total_input_tokens')
tok_out=$(j '.context_window.total_output_tokens')
lines_add=$(j '.cost.total_lines_added')
lines_del=$(j '.cost.total_lines_removed')
rl_pct=$(j '.rate_limits.five_hour.used_percentage')
rl_reset=$(j '.rate_limits.five_hour.resets_at')
effort=$(j '.effort.level // .effortLevel')
# Default permission mode (auto / plan / default) — Claude Code does not expose
# the live runtime mode to the statusline, so this reflects settings.json's
# defaultMode and won't update after shift+tab toggles mid-session.
perm_mode=""
if [ -f "$HOME/.claude/settings.json" ]; then
  perm_mode=$(jq -r '.permissions.defaultMode // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

cwd="${cwd/#$HOME/\~}"

# Format token counts compactly: 1234 -> 1.2k, 1234567 -> 1.2M
fmt_tok() {
  local n=${1:-0}
  if [ "$n" -ge 1000000 ]; then
    awk -v n="$n" 'BEGIN{ printf "%.1fM", n/1000000 }'
  elif [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN{ printf "%.1fk", n/1000 }'
  else
    echo "$n"
  fi
}

# Format seconds -> "1h23m" or "45m" or "30s"
fmt_dur() {
  local s=$1
  if [ "$s" -le 0 ]; then echo "now"; return; fi
  local h=$((s / 3600))
  local m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf "%dh%02dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf "%dm" "$m"
  else printf "%ds" "$s"
  fi
}

C_RESET='\033[0m'
C_CWD='\033[36m'      # cyan
C_BRANCH='\033[35m'   # magenta
C_MODEL='\033[33m'    # yellow
C_CTX='\033[37m'      # white/dim
C_TOK='\033[37m'      # white
C_ADD='\033[32m'      # green (+lines)
C_DEL='\033[31m'      # red (-lines)
C_RL='\033[34m'       # blue
C_MODE='\033[1;33m'   # bold yellow (auto/plan mode)

segments=()

segments+=("$(printf "${C_CWD}%s${C_RESET}" "$cwd")")

branch=$(git -C "${cwd/#\~/$HOME}" symbolic-ref --short HEAD 2>/dev/null \
  || git -C "${cwd/#\~/$HOME}" rev-parse --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  segments+=("$(printf "${C_BRANCH}%s${C_RESET}" "$branch")")
fi

if [ -n "$model" ]; then
  model_seg=$(printf "${C_MODEL}%s${C_RESET}" "$model")
  if [ -n "$effort" ]; then
    model_seg+=$(printf " ${C_CTX}[%s]${C_RESET}" "$effort")
  fi
  # Show permission mode inside the model segment when it's elevated
  # (anything other than "default" — the safest baseline).
  if [ -n "$perm_mode" ] && [ "$perm_mode" != "default" ]; then
    model_seg+=$(printf " ${C_MODE}[%s]${C_RESET}" "$perm_mode")
  fi
  segments+=("$model_seg")
fi

if [ -n "$tok_in" ] || [ -n "$tok_out" ]; then
  segments+=("$(printf "${C_TOK}%s↑/%s↓${C_RESET}" "$(fmt_tok "${tok_in:-0}")" "$(fmt_tok "${tok_out:-0}")")")
fi

if [ -n "$lines_add" ] || [ -n "$lines_del" ]; then
  segments+=("$(printf "${C_ADD}+%s${C_RESET}/${C_DEL}-%s${C_RESET}" "${lines_add:-0}" "${lines_del:-0}")")
fi

if [ -n "$rl_pct" ]; then
  rl_seg=$(printf "${C_RL}5h %.0f%%${C_RESET}" "$rl_pct")
  if [ -n "$rl_reset" ]; then
    # resets_at is either a Unix epoch integer or an ISO 8601 string
    if [[ "$rl_reset" =~ ^[0-9]+$ ]]; then
      reset_epoch=$rl_reset
    else
      reset_epoch=$(date -d "$rl_reset" +%s 2>/dev/null)
    fi
    if [ -n "$reset_epoch" ]; then
      remaining=$((reset_epoch - $(date +%s)))
      rl_seg+=$(printf " ${C_RL}(reset %s)${C_RESET}" "$(fmt_dur "$remaining")")
    fi
  fi
  segments+=("$rl_seg")
fi

# Context usage — placed last (far right): "ctx 45.7k (5%)"
if [ -n "$ctx_used" ] || [ -n "$ctx_pct" ]; then
  ctx_seg=$(printf "${C_CTX}ctx${C_RESET}")
  if [ -n "$ctx_used" ]; then
    ctx_seg+=$(printf " ${C_CTX}%s${C_RESET}" "$(fmt_tok "$ctx_used")")
  fi
  if [ -n "$ctx_pct" ]; then
    ctx_seg+=$(printf " ${C_CTX}(%.0f%%)${C_RESET}" "$ctx_pct")
  fi
  segments+=("$ctx_seg")
fi

# Join with ` | `
out=""
for i in "${!segments[@]}"; do
  if [ "$i" -eq 0 ]; then out="${segments[i]}"
  else out+=" | ${segments[i]}"
  fi
done
printf "%b" "$out"
