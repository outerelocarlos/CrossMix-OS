#!/bin/bash
set -u

PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
for _ in 1 2 3 4 5 6; do
  if [ -d "$ROOT_DIR/Apps" ] && [ -d "$ROOT_DIR/System" ]; then
    break
  fi
  if [ "$ROOT_DIR" = "/" ]; then
    break
  fi
  ROOT_DIR="$(dirname "$ROOT_DIR")"
done

INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"

show_notice() {
  message="$1"
  color="${2:-}"
  time="${3:-2}"
  if [ -x "$INFOSCREEN" ] && [ ! -f "/tmp/infoscreen_disabled" ]; then
    if [ -n "$color" ]; then
      "$INFOSCREEN" -m "$message" -c "$color" -t "$time"
    else
      "$INFOSCREEN" -m "$message" -t "$time"
    fi
  else
    echo "$message"
  fi
}

confirm_or_exit() {
  message="$1"
  fallback_prompt="$2"
  color="${3:-}"
  if [ -x "$INFOSCREEN" ] && [ ! -f "/tmp/infoscreen_disabled" ]; then
    if [ -n "$color" ]; then
      button="$("$INFOSCREEN" -m "$message" -c "$color" -k "A B")"
    else
      button="$("$INFOSCREEN" -m "$message" -k "A B")"
    fi
    if [ "$button" != "A" ]; then
      show_notice "Remove all savegames: Canceled." "" 0.5
      exit 1
    fi
  else
    echo "$message"
    read -r -p "$fallback_prompt" confirm
    if [ "$confirm" != "DELETE" ]; then
      echo "Cancelled."
      exit 1
    fi
  fi
}

if [ ! -d "$ROOT_DIR/Apps" ] || [ ! -d "$ROOT_DIR/System" ]; then
  show_notice "Could not locate SD root (missing Apps/System)." "red" 2
  exit 1
fi

echo "Root directory: $ROOT_DIR"
echo "WARNING: This will permanently delete ALL save files and savestates on this SD card."
echo "This affects RetroArch and standalone emulators."

echo
confirm_or_exit "This will permanently delete ALL savegames and savestates. Press A to continue, B to cancel." "Type DELETE to continue: "
confirm_or_exit "FINAL WARNING: Delete ALL savegames and savestates? Press A to delete, B to cancel." "Type DELETE again to confirm: " "red"

targets=()

add_target_dir() {
  local dir="$1"
  [ -n "$dir" ] || return 0
  targets+=("$dir")
}

resolve_path() {
  local base="$1"
  local path="$2"
  if [ -z "$path" ]; then
    return 1
  fi
  case "$path" in
    "~/"*) echo "$HOME/${path#~/}" ;;
    /*) echo "$path" ;;
    *) echo "$base/$path" ;;
  esac
}

RA_DIR="$ROOT_DIR/RetroArch"
RA_CFG="$RA_DIR/retroarch.cfg"
if [ -f "$RA_CFG" ]; then
  save_dir="$(sed -n 's/^savefile_directory[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$RA_CFG")"
  state_dir="$(sed -n 's/^savestate_directory[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$RA_CFG")"
  [ -z "$save_dir" ] && save_dir="./.retroarch/saves"
  [ -z "$state_dir" ] && state_dir="./.retroarch/states"
  add_target_dir "$(resolve_path "$RA_DIR" "$save_dir")"
  add_target_dir "$(resolve_path "$RA_DIR" "$state_dir")"
else
  add_target_dir "$RA_DIR/.retroarch/saves"
  add_target_dir "$RA_DIR/.retroarch/states"
fi

add_target_dir "$ROOT_DIR/Emus/NDS/drastic/savestates"
add_target_dir "$ROOT_DIR/Emus/NDS/drastic/backup"
add_target_dir "$ROOT_DIR/Emus/N64/mupen64plus/save"
add_target_dir "$ROOT_DIR/Emus/OPENBOR/Saves"
add_target_dir "$ROOT_DIR/Emus/GBA/.config/mgba/savestates"

if [ -d "$ROOT_DIR/Emus/PSP" ]; then
  for ppsspp_dir in "$ROOT_DIR/Emus/PSP"/PPSSPP_*; do
    [ -d "$ppsspp_dir" ] || continue
    add_target_dir "$ppsspp_dir/.config/ppsspp/PSP/SAVEDATA"
    add_target_dir "$ppsspp_dir/.config/ppsspp/PSP/PPSSPP_STATE"
  done
fi

if [ -d "$ROOT_DIR/Emus" ]; then
  while IFS= read -r dir; do
    targets+=("$dir")
  done < <(find "$ROOT_DIR/Emus" -type d \( -name 'saves' -o -name 'savestates' -o -name 'states' -o -name 'SAVEDATA' -o -name 'PPSSPP_STATE' \) 2>/dev/null)
fi

safe_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 1
  local real
  real="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  case "$real" in
    "$ROOT_DIR" | "$ROOT_DIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

echo
if [ "${#targets[@]}" -gt 0 ]; then
  echo "Directories to wipe:"
  for dir in "${targets[@]}"; do
    if safe_dir "$dir"; then
      echo "  $dir"
    fi
  done
  if [ -d "$ROOT_DIR/Roms" ]; then
    echo "Save files in ROM folders will also be removed by extension."
  fi
else
  echo "No save directories detected."
fi
echo

show_notice "Removing savegames..." "" 1

delete_dir_contents() {
  local dir="$1"
  if safe_dir "$dir"; then
    echo "Wiping: $dir"
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null
  fi
}

for dir in "${targets[@]}"; do
  delete_dir_contents "$dir"
done

if [ -d "$ROOT_DIR/Roms" ]; then
  echo "Removing save files from ROM folders..."
  find "$ROOT_DIR/Roms" -type f \( \
    -iname '*.sav' -o -iname '*.srm' -o -iname '*.sram' -o -iname '*.rtc' -o -iname '*.dsv' -o \
    -iname '*.eep' -o -iname '*.sra' -o -iname '*.fla' -o -iname '*.mpk' -o \
    -iname '*.mcr' -o -iname '*.mc' -o -iname '*.gme' -o \
    -iname '*.state*' -o -iname '*.ss[0-9]' -o -iname '*.st[0-9]' \
  \) -delete 2>/dev/null
fi

show_notice "Remove all savegames: Done." "" 1
