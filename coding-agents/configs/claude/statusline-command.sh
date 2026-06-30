#!/usr/bin/env bash
# Claude Code status line — fish-style colors, segments separated by ` | `.
#
# Layout (left→right):
#   cwd | branch | model[effort] | tokens↑/↓ | +N/-N | 5h NN% left<pace> reset | 7d NN% left<pace> <ahead Nh / Nh available>
#
# Width-adaptive: COLUMNS is re-read every render (tracks live terminal resizes).
# `model`, the 5h limit, and the git-root cwd are NEVER dropped. As width
# shrinks, segments are sacrificed in this order:
#   7d-diff → LOC → tokens → "left" text → branch → trim cwd (toward git root) → 7d → effort
#
# Pacing glyph shows burn vs. equidistant pacing of the 5h / 7d limits: how far
# the % used is ahead of (▲, too fast) or behind (▼, headroom) the steady line
# you'd be on if you spent the window evenly. The "5h/7d NN% left" text stays
# blue; only the glyph is colored. The 7d segment also carries a time
# differential ("ahead Nh" = burning that many hours faster than the steady
# line, "Nh available" = that much headroom) — same deviation expressed as
# wall-clock hours over the week. LOC resets on /clear (statusline-loc-reset.sh).
input=$(cat)

# UTF-8 locale so ${#str} counts characters (glyphs, arrows, …), not bytes —
# otherwise width math overcounts multibyte runes and trims too aggressively.
if locale -a 2>/dev/null | grep -qix 'C.UTF-8'; then export LC_ALL=C.UTF-8
elif locale -a 2>/dev/null | grep -qix 'en_US.UTF-8'; then export LC_ALL=en_US.UTF-8
fi

# One jq pass → TSV of every field we need (far cheaper than a fork per field).
IFS=$'\t' read -r session_id cwd model tok_in tok_out lines_add lines_del \
  effort rl5_pct rl5_reset rl7_pct rl7_reset < <(
  jq -r '[
    .session_id,
    (.workspace.current_dir // .cwd),
    .model.display_name,
    .context_window.total_input_tokens,
    .context_window.total_output_tokens,
    .cost.total_lines_added,
    .cost.total_lines_removed,
    (.effort.level // .effortLevel),
    .rate_limits.five_hour.used_percentage,
    .rate_limits.five_hour.resets_at,
    .rate_limits.seven_day.used_percentage,
    .rate_limits.seven_day.resets_at
  ] | map(if . == null then "" else . end) | @tsv' <<<"$input"
)

abs_cwd="$cwd"   # keep the absolute path for git lookups

# Format token counts compactly: 1234 -> 1.2k, 1234567 -> 1.2M
fmt_tok() {
  local n=${1:-0}
  if [ "$n" -ge 1000000 ]; then awk -v n="$n" 'BEGIN{ printf "%.1fM", n/1000000 }'
  elif [ "$n" -ge 1000 ]; then awk -v n="$n" 'BEGIN{ printf "%.1fk", n/1000 }'
  else echo "$n"
  fi
}

# Format seconds -> "1h23m" / "45m" / "30s"
fmt_dur() {
  local s=$1
  if [ "$s" -le 0 ]; then echo "now"; return; fi
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf "%dh%02dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf "%dm" "$m"
  else printf "%ds" "$s"
  fi
}

C_RESET='\033[0m'
C_CWD='\033[36m'      # cyan
C_BRANCH='\033[35m'   # magenta
C_MODEL='\033[33m'    # yellow
C_EFFORT='\033[38;2;160;160;160m'  # medium grey — effort tag
C_DIM='\033[90m'      # bright black — reset countdown
C_TOK='\033[37m'      # white
C_ADD='\033[32m'      # green (+lines)
C_DEL='\033[31m'      # red (-lines)
C_RL='\033[34m'       # blue — rate-limit text (glyph colored separately)

# --- LOC since last /clear (or session start) -------------------------------
# Per-session baseline file holds the cumulative cost counters at the last reset
# point; we show `current - baseline`. statusline-loc-reset.sh deletes the file
# on SessionStart(clear), and we lazily re-baseline to the current value when
# it's missing — correct whether or not /clear changes session_id or zeroes cost
# upstream. A drop below the baseline (any upstream reset) also re-baselines, so
# the counter never goes negative.
add=${lines_add:-0}; del=${lines_del:-0}
if [ -n "$session_id" ]; then
  loc_dir="$HOME/.claude/statusline-loc"
  loc_file="$loc_dir/$session_id"
  base_add=""; base_del=""
  [ -f "$loc_file" ] && read -r base_add base_del < "$loc_file" 2>/dev/null
  if [ -z "$base_add" ] || [ "$add" -lt "$base_add" ] 2>/dev/null \
                        || [ "$del" -lt "$base_del" ] 2>/dev/null; then
    base_add=$add; base_del=$del
    mkdir -p "$loc_dir" 2>/dev/null && printf '%s %s\n' "$add" "$del" > "$loc_file" 2>/dev/null
  fi
  loc_add=$((add - base_add)); loc_del=$((del - base_del))
else
  loc_add=$add; loc_del=$del
fi

# --- cwd forms: richest → poorest -------------------------------------------
# Always keep the git-root dir; trim leading components first (replace with …).
home_cwd="${abs_cwd/#$HOME/\~}"
gitroot=$(git -C "$abs_cwd" rev-parse --show-toplevel 2>/dev/null)
cwd_forms=()
if [ -n "$gitroot" ]; then
  root_name=$(basename "$gitroot")
  rel="${abs_cwd#"$gitroot"}"; rel="${rel#/}"
  cwd_forms+=("$home_cwd")                       # ~/configs/ansible/roles
  if [ -n "$rel" ]; then
    cwd_forms+=("$root_name/$rel")               # configs/ansible/roles
    IFS='/' read -ra comps <<< "$rel"
    for ((k=1; k<${#comps[@]}; k++)); do         # configs/…/roles, configs/…/<dir>
      cwd_forms+=("$root_name/…/$(IFS=/; echo "${comps[*]:k}")")
    done
  fi
  cwd_forms+=("$root_name")                       # configs  (base, never dropped)
else
  cwd_forms+=("$home_cwd")
  cwd_forms+=("$(basename "$abs_cwd")")
fi

# --- static segment strings (plain for width math, colored for output) ------
branch=$(git -C "$abs_cwd" symbolic-ref --short HEAD 2>/dev/null \
  || git -C "$abs_cwd" rev-parse --short HEAD 2>/dev/null)

model_short="${model%% (*}"   # "Opus 4.8 (1M context)" -> "Opus 4.8"

tokens_plain=""; tokens_col=""
if [ -n "$tok_in" ] || [ -n "$tok_out" ]; then
  tokens_plain="$(fmt_tok "${tok_in:-0}")↑/$(fmt_tok "${tok_out:-0}")↓"
  tokens_col="$(printf "${C_TOK}%s${C_RESET}" "$tokens_plain")"
fi

loc_plain="+${loc_add}/-${loc_del}"
loc_col="$(printf "${C_ADD}+%s${C_RESET}/${C_DEL}-%s${C_RESET}" "$loc_add" "$loc_del")"

# Pacing segment. $1 label $2 used% $3 resets_at $4 window-length(s) $5 show-reset.
# Emits 4 TAB-separated fields: plain/colored WITH the " left" word, then
# plain/colored WITHOUT it (the word is sacrificed before the branch when width
# is tight). Shows % LEFT (= 100 − used); the "Nx NN% left" text stays blue, and
# only the glyph is colored, by deviation = used% − elapsed% (percentage points
# ahead of the equidistant line).
pace_seg() {
  local label=$1 used=$2 reset=$3 wl=$4 showreset=$5
  [ -n "$used" ] || { printf '\t\t\t'; return; }
  local now rem col glyph left
  now=$(date +%s)
  if [[ "$reset" =~ ^[0-9]+$ ]]; then rem=$((reset - now)); else rem=$wl; reset=""; fi
  read -r col glyph < <(awk -v u="$used" -v rem="$rem" -v wl="$wl" 'BEGIN{
    el=(wl-rem)/wl; if(el<0)el=0; if(el>1)el=1;
    dev=u-el*100;
    if      (dev<=-10) {c="0;200;80"     ; g="▲"}   # deep green — lots of headroom
    else if (dev<=-2)  {c="120;190;120"  ; g="▲"}   # green      — headroom
    else if (dev<2)    {c="90;150;245"   ; g="▬"}   # blue       — on pace
    else if (dev<5)    {c="220;190;60"   ; g="▼"}   # yellow     — slightly too fast
    else               {c="240;90;90"    ; g="▼"}   # red        — too fast
    printf "%s %s", c, g
  }')
  left=$(awk -v u="$used" 'BEGIN{ printf "%.0f", 100 - u }')

  local g_col cd_plain="" cd_col=""
  g_col="$(printf '\033[38;2;%sm%s\033[0m' "$col" "$glyph")"
  if [ "$showreset" = 1 ] && [ -n "$reset" ] && [ "$rem" -gt 0 ]; then
    local d; d=$(fmt_dur "$rem")
    cd_plain=" $d"
    cd_col=" $(printf "${C_DIM}%s${C_RESET}" "$d")"
  fi

  local tL="${label} ${left}% left" tS="${label} ${left}%"
  printf '%s\t%s\t%s\t%s' \
    "${tL}${glyph}${cd_plain}"  "$(printf "${C_RL}%s${C_RESET}" "$tL")${g_col}${cd_col}" \
    "${tS}${glyph}${cd_plain}"  "$(printf "${C_RL}%s${C_RESET}" "$tS")${g_col}${cd_col}"
}

# Time differential vs the steady-burn line for a limit window. Translates the
# pacing deviation (used% − elapsed%) into wall-clock hours: "ahead Nh" = burning
# that many hours faster than steady (too fast), "Nh available" = that much headroom.
# Rounded to whole hours; within ~1h of pace emits nothing (dropped first when
# width is tight). Emits plain<TAB>colored.
pace_diff() {  # $1 used% $2 resets_at $3 window-length(s)
  local used=$1 reset=$2 wl=$3
  [ -n "$used" ] || { printf '\t'; return; }
  local now rem txt
  now=$(date +%s)
  if [[ "$reset" =~ ^[0-9]+$ ]]; then rem=$((reset - now)); else rem=$wl; fi
  txt=$(awk -v u="$used" -v rem="$rem" -v wl="$wl" 'BEGIN{
    el=(wl-rem)/wl; if(el<0)el=0; if(el>1)el=1;
    dev=u-el*100;                 # percentage points over(+)/under(-) pace
    h=dev/100*wl/3600;            # same deviation as signed hours over the window
    rh=int(h<0?-h+0.5:h+0.5);     # rounded magnitude
    if(rh<1) exit;                # within ~1h of pace → no segment
    if(h>=0) printf "ahead %dh", rh;       # too fast — warn
    else     printf "%dh available", rh    # headroom — plain spare capacity
  }')
  [ -n "$txt" ] || { printf '\t'; return; }
  printf '%s\t%s' "$txt" "$(printf "${C_DIM}%s${C_RESET}" "$txt")"
}

IFS=$'\t' read -r p5_pL p5_cL p5_pS p5_cS < <(pace_seg "5h" "$rl5_pct" "$rl5_reset" 18000 1)
IFS=$'\t' read -r p7_pL p7_cL p7_pS p7_cS < <(pace_seg "7d" "$rl7_pct" "$rl7_reset" 604800 0)
IFS=$'\t' read -r d7_plain d7_col < <(pace_diff "$rl7_pct" "$rl7_reset" 604800)

# --- render at current degradation state ------------------------------------
SEP=' | '
render() {  # $1 = plain|color
  local mode=$1 parts=()
  if [ "$mode" = plain ]; then parts+=("${cwd_forms[$cwd_idx]}")
  else parts+=("$(printf "${C_CWD}%s${C_RESET}" "${cwd_forms[$cwd_idx]}")"); fi

  if [ "$show_branch" = 1 ] && [ -n "$branch" ]; then
    if [ "$mode" = plain ]; then parts+=("$branch")
    else parts+=("$(printf "${C_BRANCH}%s${C_RESET}" "$branch")"); fi
  fi

  if [ -n "$model_short" ]; then
    if [ "$mode" = plain ]; then
      local mp="$model_short"
      [ "$show_effort" = 1 ] && [ -n "$effort" ] && mp="$mp [$effort]"
      parts+=("$mp")
    else
      local mc; mc="$(printf "${C_MODEL}%s${C_RESET}" "$model_short")"
      [ "$show_effort" = 1 ] && [ -n "$effort" ] && mc="$mc $(printf "${C_EFFORT}[%s]${C_RESET}" "$effort")"
      parts+=("$mc")
    fi
  fi

  if [ "$show_tokens" = 1 ] && [ -n "$tokens_plain" ]; then
    if [ "$mode" = plain ]; then parts+=("$tokens_plain"); else parts+=("$tokens_col"); fi
  fi

  if [ "$show_loc" = 1 ]; then
    if [ "$mode" = plain ]; then parts+=("$loc_plain"); else parts+=("$loc_col"); fi
  fi

  if [ -n "$p5_pL" ]; then
    if [ "$mode" = plain ]; then
      if [ "$show_left" = 1 ]; then parts+=("$p5_pL"); else parts+=("$p5_pS"); fi
    else
      if [ "$show_left" = 1 ]; then parts+=("$p5_cL"); else parts+=("$p5_cS"); fi
    fi
  fi

  if [ "$show_7d" = 1 ] && [ -n "$p7_pL" ]; then
    local seg7p seg7c
    if [ "$show_left" = 1 ]; then seg7p="$p7_pL"; seg7c="$p7_cL"; else seg7p="$p7_pS"; seg7c="$p7_cS"; fi
    if [ "$show_7ddiff" = 1 ] && [ -n "$d7_plain" ]; then
      seg7p="$seg7p $d7_plain"; seg7c="$seg7c $d7_col"
    fi
    if [ "$mode" = plain ]; then parts+=("$seg7p"); else parts+=("$seg7c"); fi
  fi

  local out="" i
  for i in "${!parts[@]}"; do
    if [ "$i" -eq 0 ]; then out="${parts[$i]}"; else out="$out$SEP${parts[$i]}"; fi
  done
  printf '%s' "$out"
}
plain_len() { local s; s=$(render plain); echo "${#s}"; }

# Sacrifice ladder: drop one item at a time until the line fits COLUMNS.
COLS=${COLUMNS:-80}
actions=(7ddiff loc tokens left branch)
for ((i=1; i<${#cwd_forms[@]}; i++)); do actions+=(cwd); done   # trim cwd, step by step
actions+=(7d effort)

show_7ddiff=1 show_loc=1 show_tokens=1 show_left=1 show_branch=1 show_7d=1 show_effort=1 cwd_idx=0
ai=0
while [ "$(plain_len)" -gt "$COLS" ] && [ "$ai" -lt "${#actions[@]}" ]; do
  case "${actions[$ai]}" in
    7ddiff) show_7ddiff=0 ;;
    loc)    show_loc=0 ;;
    tokens) show_tokens=0 ;;
    left)   show_left=0 ;;
    branch) show_branch=0 ;;
    cwd)    cwd_idx=$((cwd_idx + 1)) ;;
    7d)     show_7d=0 ;;
    effort) show_effort=0 ;;
  esac
  ai=$((ai + 1))
done

printf '%b' "$(render color)"
