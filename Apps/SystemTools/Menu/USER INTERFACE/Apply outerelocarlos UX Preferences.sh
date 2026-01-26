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

if [ ! -d "$ROOT_DIR/Apps" ] || [ ! -d "$ROOT_DIR/System" ]; then
  echo "Could not locate SD root (missing Apps/System)."
  exit 1
fi

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

run_script() {
  local script="$1"
  shift || true
  if [ -f "$script" ]; then
    echo "Running: $script"
    "$script" "$@"
  else
    echo "Missing: $script"
  fi
}

show_notice "Applying outerelocarlos UX preferences..." "" 1

# Base Theme (Theme Pack)
show_notice "Applying theme pack: Epic Noir" "" 1
run_script "$ROOT_DIR/Apps/SystemTools/Menu/THEME##THEME PACK (value)/Epic Noir.sh"

# Emulator Labels
show_notice "Applying emulator labels: Console Short Name - EU" "" 1
run_script "$ROOT_DIR/Apps/SystemTools/Menu/ADVANCED SETTINGS##EMULATOR LABELS (value)/Console Short Name - EU.sh"

# Titles Fontsize
show_notice "Applying title size: default" "" 1
run_script "$ROOT_DIR/Apps/SystemTools/Menu/ADVANCED SETTINGS##TITLES FONTSIZE (value)/default.sh"

# Top Left Logo
show_notice "Applying top-left logo: Enable" "" 1
run_script "$ROOT_DIR/Apps/SystemTools/Menu/ADVANCED SETTINGS##TOP LEFT LOGO (state)/Top-left logo  - Enable.sh"

# Start Tab
show_notice "Setting start tab: Tab 4" "" 1
run_script "$ROOT_DIR/Apps/SystemTools/Menu/USER INTERFACE##START TAB (value)/Tab 4.sh" -s

show_notice "UX preferences applied." "" 1
echo "Done."
