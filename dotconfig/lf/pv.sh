#!/bin/sh

file=$1
width=${2:-80}
height=${3:-40}

batpreview() {
  if command -v bat >/dev/null 2>&1; then
    bat --color=always --style=numbers --paging=never \
        --terminal-width="$width" "$file" 2>/dev/null || true
  else
    sed -n '1,200p' "$file" || true
  fi
}

case "$file" in
  *.md|*.markdown|*.mdown|*.mkd|*.mkdn)
    glow -s dark -w "$width" "$file" || batpreview
    ;;
  *.json)
    jq -C . "$file" 2>/dev/null || batpreview
    ;;
  *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst)
    tar tf "$file" || true
    ;;
  *.zip|*.jar)
    unzip -l "$file" || true
    ;;
  *.rar) unrar l "$file" || true ;;
  *.7z)  7z l "$file" || true ;;
  *.pdf)
    if command -v pdftotext >/dev/null 2>&1; then
      pdftotext -l 10 -nopgbrk -q -- "$file" - | sed -n "1,${height}p" || true
    else
      file -- "$file"
    fi
    ;;
  *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.tiff|*.svg|*.ico)
    if command -v exiftool >/dev/null 2>&1; then
      exiftool -- "$file" || true
    else
      file -- "$file"
    fi
    ;;
  *.mp3|*.flac|*.ogg|*.opus|*.wav|*.m4a|*.mp4|*.mkv|*.webm|*.avi|*.mov)
    if command -v mediainfo >/dev/null 2>&1; then
      mediainfo -- "$file" || true
    else
      file -- "$file"
    fi
    ;;
  *)
    if command -v file >/dev/null 2>&1; then
      mime=$(file -Lb --mime-type -- "$file" 2>/dev/null)
      case "$mime" in
        text/*|application/json|application/javascript|application/xml)
          batpreview ;;
        *) file -- "$file" ;;
      esac
    else
      batpreview
    fi
    ;;
esac
