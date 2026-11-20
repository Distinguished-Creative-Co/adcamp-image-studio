#!/bin/bash
# AdCamp Image Studio helper. It hands a prompt to Codex (ChatGPT) on this Mac
# and brings back an image or a written second look.
#
#   studio.sh check
#   studio.sh login
#   studio.sh image <prompt-file> <out.png> [--size square|portrait|story|wide|asis] [--ref image]...
#   studio.sh look  <prompt-file> <out.txt> --ref image [--ref image]...
#   studio.sh crops <story.png>
#   studio.sh picker <folder>
#
# Sizes: square 1080x1080, portrait 1080x1350, story 1080x1920, wide 1920x1080,
# asis keeps whatever Codex made. Every run prints one final line that starts
# with OK: or FAIL: so the caller never has to guess.

set -u

STUDIO_HOME="${STUDIO_HOME:-$HOME/AdCamp Image Studio}"
LIMIT="${STUDIO_TIMEOUT:-480}"

find_codex() {
  local c app b
  for c in "${CODEX_BIN:-}" "$HOME/.local/bin/codex" "$(command -v codex 2>/dev/null)" /opt/homebrew/bin/codex /usr/local/bin/codex; do
    if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  for app in "/Applications/ChatGPT.app" "/Applications/Codex.app" "$HOME/Applications/ChatGPT.app" "$HOME/Applications/Codex.app"; do
    b="$app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
    if [ -x "$b" ]; then echo "$b"; return 0; fi
  done
  return 1
}

# Per-call switches. Nothing here changes the member's own Codex settings.
quiet_flags() {
  local config="$HOME/.codex/config.toml" name
  if [ -f "$config" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] && printf '%s\n' "-c" "mcp_servers.${name}.enabled=false"
    done < <(grep -E '^\[mcp_servers\.[A-Za-z0-9_-]+\]$' "$config" | sed -E 's/^\[mcp_servers\.([A-Za-z0-9_-]+)\]$/\1/')
  fi
  printf '%s\n' "-c" "memories.use_memories=false" "-c" "memories.generate_memories=false"
}

usage() { sed -n '2,14p' "$0" | sed -E 's/^# ?//'; }

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  check)
    ok=1
    if [ "$(uname)" != "Darwin" ] || ! command -v sips >/dev/null 2>&1; then
      echo "FAIL: Image Studio needs to run on the Mac itself. This session is not running there."
      exit 1
    fi
    if CODEX="$(find_codex)"; then
      echo "CODEX: found at $CODEX, $("$CODEX" --version 2>/dev/null | head -1)"
      STATUS="$("$CODEX" login status 2>&1)"
      if echo "$STATUS" | grep -qi "not logged in"; then
        echo "SIGNED IN: no"
        ok=0
      elif echo "$STATUS" | grep -qi "api key"; then
        echo "SIGNED IN: with an API key, not a ChatGPT account"
        ok=0
      elif echo "$STATUS" | grep -qi "logged in"; then
        echo "SIGNED IN: yes"
      else
        echo "SIGNED IN: no"
        ok=0
      fi
    else
      echo "CODEX: not found"
      echo "SIGNED IN: unknown"
      ok=0
    fi
    mkdir -p "$STUDIO_HOME/images" "$STUDIO_HOME/work"
    # Scratch folders from old runs are cleared after a week.
    find "$STUDIO_HOME/work" -maxdepth 1 -type d -name 'run.*' -mtime +7 -exec rm -rf {} + 2>/dev/null
    echo "FOLDER: $STUDIO_HOME"
    if [ -s "$STUDIO_HOME/brand.md" ]; then echo "BRAND CARD: yes"; else echo "BRAND CARD: not yet"; fi
    if [ $ok -eq 1 ]; then echo "OK: ready"; else echo "FAIL: not ready"; exit 1; fi
    ;;

  login)
    CODEX="$(find_codex)" || { echo "FAIL: Codex is not installed. Run: studio.sh check"; exit 3; }
    echo "A browser window will open for the ChatGPT sign-in."
    "$CODEX" login
    AFTER="$("$CODEX" login status 2>&1)"
    if echo "$AFTER" | grep -qi "not logged in"; then echo "FAIL: sign-in did not finish"; exit 1; fi
    if echo "$AFTER" | grep -qi "api key"; then echo "FAIL: still signed in with an API key, not a ChatGPT account"; exit 1; fi
    echo "OK: signed in"
    ;;

  picker)
    # Put a copy of the look picker page in a folder the caller can publish from.
    DEST="${1:-}"
    case "$DEST" in /*) : ;; *) echo "FAIL: give a full folder path starting with /"; exit 2 ;; esac
    SRCDIR="$(cd "$(dirname "$0")/.." && pwd)/picker"
    [ -s "$SRCDIR/picker.html" ] && [ -d "$SRCDIR/samples" ] || { echo "FAIL: the picker page is missing from this copy of Image Studio"; exit 1; }
    # Its own subfolder, so nothing already in the caller's folder can be picked up or overwritten.
    DEST="$DEST/image-studio-picker"
    [ -e "$DEST/samples" ] && [ ! -e "$DEST/image-studio-looks.html" ] && { echo "FAIL: $DEST already holds something else"; exit 1; }
    mkdir -p "$DEST/samples" && cp "$SRCDIR/picker.html" "$DEST/image-studio-looks.html" && cp "$SRCDIR"/samples/*.jpg "$DEST/samples/" || { echo "FAIL: could not write to $DEST"; exit 1; }
    # The list of pictures the page shows, ready to hand to the Artifact tool as its files.
    { printf '{'; first=1; for j in "$SRCDIR"/samples/*.jpg; do n="$(basename "$j")"; [ $first -eq 1 ] || printf ','; first=0; printf '"samples/%s": "samples/%s"' "$n" "$n"; done; printf '}\n'; } > "$DEST/files-map.json"
    echo "PAGE: $DEST/image-studio-looks.html"
    echo "FILES: $DEST/files-map.json"
    echo "ROOT: $DEST"
    echo "OK: picker page ready"
    ;;

  crops)
    # Preview copies of a 1080x1920 ad image as Meta will crop it: 4:5 and square.
    SRC="${1:-}"
    [ -s "$SRC" ] || { echo "FAIL: picture is missing or empty: $SRC"; exit 2; }
    sw="$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/{print $2}')"
    sh="$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/{print $2}')"
    if [ "$sw" != "1080" ] || [ "$sh" != "1920" ]; then echo "FAIL: crops needs a 1080x1920 picture, this one is ${sw}x${sh}"; exit 2; fi
    # Previews go in the work folder, never beside the finished picture, so nobody uploads one by mistake.
    mkdir -p "$STUDIO_HOME/work"
    BASE="$STUDIO_HOME/work/$(basename "${SRC%.png}")"
    cp "$SRC" "$BASE-preview-4x5.png" && sips -c 1350 1080 "$BASE-preview-4x5.png" >/dev/null 2>&1
    cp "$SRC" "$BASE-preview-square.png" && sips -c 1080 1080 "$BASE-preview-square.png" >/dev/null 2>&1
    a="$(sips -g pixelHeight "$BASE-preview-4x5.png" 2>/dev/null | awk '/pixelHeight/{print $2}')"
    b="$(sips -g pixelHeight "$BASE-preview-square.png" 2>/dev/null | awk '/pixelHeight/{print $2}')"
    if [ "$a" != "1350" ] || [ "$b" != "1080" ]; then echo "FAIL: the previews could not be made"; exit 1; fi
    echo "OK: previews saved as $BASE-preview-4x5.png and $BASE-preview-square.png"
    ;;

  image|look)
    PROMPT_FILE="${1:-}"; OUT="${2:-}"
    if [ -z "$PROMPT_FILE" ] || [ -z "$OUT" ]; then usage; echo "FAIL: missing prompt file or output path"; exit 2; fi
    shift 2
    SIZE="portrait"; REFS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --size) [ $# -ge 2 ] || { echo "FAIL: --size needs a value"; exit 2; }; SIZE="$2"; shift 2 ;;
        --ref)  [ $# -ge 2 ] || { echo "FAIL: --ref needs a picture path"; exit 2; }; REFS+=("$2"); shift 2 ;;
        *) echo "FAIL: unknown option $1"; exit 2 ;;
      esac
    done
    [ -s "$PROMPT_FILE" ] || { echo "FAIL: prompt file is missing or empty: $PROMPT_FILE"; exit 2; }
    case "$OUT" in /*) : ;; *) echo "FAIL: the output path must be a full path starting with /"; exit 2 ;; esac
    [ -e "$OUT" ] && { echo "FAIL: a file with that name already exists. Pick a new name: $OUT"; exit 2; }
    CODEX="$(find_codex)" || { echo "FAIL: Codex is not installed. Run: studio.sh check"; exit 3; }
    if [ ${#REFS[@]} -gt 0 ]; then
      for r in "${REFS[@]}"; do
        [ -s "$r" ] || { echo "FAIL: reference image is missing or empty: $r"; exit 2; }
      done
    fi
    if [ "$cmd" = "look" ] && [ ${#REFS[@]} -eq 0 ]; then echo "FAIL: look needs at least one --ref image"; exit 2; fi

    case "$SIZE" in
      square)   W=1080; H=1080; SHAPE="Square, 1:1." ;;
      portrait) W=1080; H=1350; SHAPE="Portrait, 4:5." ;;
      story)    W=1080; H=1920; SHAPE="Tall portrait, 9:16." ;;
      wide)     W=1920; H=1080; SHAPE="Landscape, 16:9." ;;
      asis)     W=0;    H=0;    SHAPE="" ;;
      *) echo "FAIL: size must be square, portrait, story, wide or asis"; exit 2 ;;
    esac

    mkdir -p "$STUDIO_HOME/work" "$(dirname "$OUT")"
    WORK="$(mktemp -d "$STUDIO_HOME/work/run.XXXXXX")"
    LOG="$WORK/codex.log"
    SEND="$WORK/prompt.txt"
    ARGS=(exec --skip-git-repo-check -C "$WORK")
    while IFS= read -r f; do ARGS+=("$f"); done < <(quiet_flags)
    if [ ${#REFS[@]} -gt 0 ]; then
      for r in "${REFS[@]}"; do ARGS+=(-i "$r"); done
    fi

    if [ "$cmd" = "image" ]; then
      {
        echo "Do not read any files on this computer other than the attached images and the file you create."
        echo
        echo "Generate one image with your image generation tool, then save it into the current folder as result.png."
        echo "Save it with a plain file copy of the file your image tool wrote. Do not rebuild the picture from text, and do not write anything outside the current folder."
        echo
        cat "$PROMPT_FILE"
        echo
        [ -n "$SHAPE" ] && echo "Shape: $SHAPE"
        echo "The outer edges of the picture will be trimmed to fit an exact size. Keep the main subject and any words inside the middle 60 percent of the frame."
        echo
        echo "When the file is saved, reply with only the word SAVED."
      } > "$SEND"
      ARGS+=(-s workspace-write -o "$WORK/answer.txt" -)
    else
      {
        echo "Judge only the attached images and this message. Do not read any files on this computer and do not run commands."
        echo
        cat "$PROMPT_FILE"
      } > "$SEND"
      # A second look leans on judgment, so it runs at medium effort whatever the member's default is.
      ARGS+=(-c 'model_reasoning_effort="medium"' -s read-only --ephemeral -o "$WORK/answer.txt" -)
    fi

    # macOS has no timeout command. perl ends the call if Codex hangs.
    perl -e 'alarm shift; exec @ARGV' "$LIMIT" "$CODEX" "${ARGS[@]}" < "$SEND" > "$LOG" 2>&1
    CODE=$?
    TOKENS="$(grep -A1 'tokens used' "$LOG" | tail -1 | tr -d ', ')"

    if [ $CODE -eq 142 ]; then echo "FAIL: Codex took longer than ${LIMIT} seconds and was stopped. Log: $LOG"; exit 1; fi
    if [ $CODE -ne 0 ]; then
      # Only a failed run is searched for a reason, and only its last lines,
      # so words in the member's own prompt can never look like an error.
      TAIL="$(tail -15 "$LOG")"
      if echo "$TAIL" | grep -qiE "not logged in|login required|401 unauthorized|please log in"; then
        echo "FAIL: Codex is not signed in. Run: studio.sh check"; exit 1
      fi
      if echo "$TAIL" | grep -qiE "usage limit|rate limit|quota"; then
        echo "FAIL: the ChatGPT plan's Codex limit was reached. Log: $LOG"; exit 1
      fi
      echo "FAIL: Codex stopped with code $CODE. Log: $LOG"; exit 1
    fi

    if [ "$cmd" = "look" ]; then
      [ -s "$WORK/answer.txt" ] || { echo "FAIL: Codex finished but wrote no answer. Log: $LOG"; exit 1; }
      cp "$WORK/answer.txt" "$OUT"
      rm -rf "$WORK"
      echo "OK: second look saved to $OUT (tokens: ${TOKENS:-unknown})"
      exit 0
    fi

    # Find the image. Codex's own copy of what its image tool made is the truth,
    # so it is used first. result.png is only trusted when that copy is missing,
    # because Codex has rebuilt result.png from a stale temp file and saved an old picture.
    FOUND=""
    SID="$(grep -m1 -E '^session id: ' "$LOG" | sed -E 's/^session id: //')"
    if [ -n "$SID" ] && [ -d "$HOME/.codex/generated_images/$SID" ]; then
      FOUND="$(find "$HOME/.codex/generated_images/$SID" -type f -name '*.png' -size +10k -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
    fi
    if [ -z "$FOUND" ] && [ -s "$WORK/result.png" ]; then
      FOUND="$WORK/result.png"
    fi
    if [ -z "$FOUND" ]; then
      FOUND="$(find "$WORK" -maxdepth 2 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) -size +10k 2>/dev/null | head -1)"
    fi
    if [ -z "$FOUND" ] && { cat "$WORK/answer.txt" 2>/dev/null; tail -15 "$LOG"; } | grep -qiE "usage limit|rate limit|quota"; then
      echo "FAIL: the ChatGPT plan's Codex limit was reached. Log: $LOG"; exit 1
    fi
    [ -n "$FOUND" ] || { echo "FAIL: Codex finished but made no image. Its reply: $(head -c 300 "$WORK/answer.txt" 2>/dev/null) Log: $LOG"; exit 1; }

    TMP="$WORK/final.png"
    sips -s format png "$FOUND" --out "$TMP" >/dev/null 2>&1 || cp "$FOUND" "$TMP"

    if [ "$W" -gt 0 ]; then
      w="$(sips -g pixelWidth "$TMP" | awk '/pixelWidth/{print $2}')"
      h="$(sips -g pixelHeight "$TMP" | awk '/pixelHeight/{print $2}')"
      case "$w$h" in ''|*[!0-9]*) echo "FAIL: Codex saved a file that is not a readable picture. Log: $LOG"; exit 1 ;; esac
      # Scale so the image covers the target, then trim the overhang from the middle.
      read -r nw nh < <(awk -v w="$w" -v h="$h" -v W="$W" -v H="$H" 'BEGIN{s=W/w; if(H/h>s)s=H/h; nw=int(w*s+0.999); nh=int(h*s+0.999); if(nw<W)nw=W; if(nh<H)nh=H; print nw, nh}')
      sips -z "$nh" "$nw" "$TMP" >/dev/null 2>&1
      sips -c "$H" "$W" "$TMP" >/dev/null 2>&1
    fi

    cp "$TMP" "$OUT"
    fw="$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/{print $2}')"
    fh="$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/{print $2}')"
    if [ "$W" -gt 0 ] && { [ "$fw" != "$W" ] || [ "$fh" != "$H" ]; }; then
      rm -f "$OUT"
      echo "FAIL: the picture came out ${fw}x${fh}, not ${W}x${H}, so it was not kept"; exit 1
    fi
    rm -rf "$WORK"
    echo "OK: image saved to $OUT (${fw}x${fh}, tokens: ${TOKENS:-unknown})"
    ;;

  *)
    usage
    [ -z "$cmd" ] && exit 0
    echo "FAIL: unknown command $cmd"; exit 2
    ;;
esac
