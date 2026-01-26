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
  if [ -x "$INFOSCREEN" ] && [ ! -f "/tmp/infoscreen_disabled" ]; then
    button="$($INFOSCREEN -m "$message" -k "A B")"
    if [ "$button" != "A" ]; then
      show_notice "Install Mega Bezel Shaders: Canceled." "" 0.5
      exit 0
    fi
  else
    echo "$message"
    read -r -p "$fallback_prompt" reply
    case "$reply" in
      y|Y) ;;
      *)
        echo "Cancelled."
        exit 0
        ;;
    esac
  fi
}

RA_DIR="$ROOT_DIR/RetroArch"
RA_CFG="$RA_DIR/retroarch.cfg"

if [ ! -d "$RA_DIR" ]; then
  show_notice "RetroArch folder not found." "red" 2
  echo "RetroArch folder not found: $RA_DIR"
  exit 1
fi

get_cfg_value() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ]; then
    sed -n "s/^${key}[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" "$file" | tail -n 1
  fi
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
    ./*) echo "$base/${path#./}" ;;
    *) echo "$base/$path" ;;
  esac
}

usage() {
  cat <<'USAGE'
Usage: Install Mega Bezel Shaders.sh [--force] [--ref <branch>]

Downloads the Mega Bezel shaders from GitHub and installs them into
RetroArch's shader directory. By default, it tries the main branch
and falls back to master.

Options:
  --force       Replace existing Mega Bezel folders without prompting.
  --ref <name>  Use a specific branch name (e.g. master, main).
USAGE
}

FORCE=0
REF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --ref)
      shift
      if [ $# -eq 0 ]; then
        show_notice "Missing value for --ref." "red" 2
        echo "Missing value for --ref."
        exit 1
      fi
      REF="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      show_notice "Unknown option: $1" "red" 2
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

shader_dir="$(get_cfg_value "$RA_CFG" "video_shader_dir")"
[ -z "$shader_dir" ] && shader_dir="./.retroarch/shaders"
SHADER_BASE="$(resolve_path "$RA_DIR" "$shader_dir")"

if [ -z "$SHADER_BASE" ]; then
  show_notice "Unable to resolve RetroArch shader directory." "red" 2
  echo "Unable to resolve RetroArch shader directory."
  exit 1
fi

TARGET_ROOT="$SHADER_BASE/shaders_slang"
parent_dir=""
case "$SHADER_BASE" in
  */shaders_slang)
    TARGET_ROOT="$SHADER_BASE"
    ;;
  */shaders_glsl)
    parent_dir="$(cd "$SHADER_BASE/.." 2>/dev/null && pwd)"
    if [ -n "$parent_dir" ]; then
      TARGET_ROOT="$parent_dir/shaders_slang"
    fi
    ;;
esac
if ! mkdir -p "$TARGET_ROOT"; then
  show_notice "Failed to create shader directory." "red" 2
  echo "Failed to create shader directory: $TARGET_ROOT"
  exit 1
fi

TARGET_BEZEL="$TARGET_ROOT/bezel"
if ! mkdir -p "$TARGET_BEZEL"; then
  show_notice "Failed to create shader directory." "red" 2
  echo "Failed to create shader directory: $TARGET_BEZEL"
  exit 1
fi

DIRS=("Mega_Bezel" "Mega_Bezel_Packs" "Mega_Bezel_Community")
existing=0
for dir in "${DIRS[@]}"; do
  if [ -d "$TARGET_BEZEL/$dir" ]; then
    existing=1
    break
  fi
done

if [ "$existing" -eq 1 ] && [ "$FORCE" -ne 1 ]; then
  confirm_or_exit "Mega Bezel is already installed. Re-download and replace? A to continue, B to cancel." "Existing Mega Bezel install found. Re-download and replace? (y/N): "
fi

have_download_tool=0
if command -v wget >/dev/null 2>&1 || [ -x "$ROOT_DIR/System/bin/wget" ]; then
  have_download_tool=1
elif command -v curl >/dev/null 2>&1 || [ -x "$ROOT_DIR/System/bin/curl-aarch64" ]; then
  have_download_tool=1
fi

if [ "$have_download_tool" -ne 1 ]; then
  show_notice "Missing curl or wget for download." "red" 3
  echo "Missing curl or wget for download."
  exit 1
fi

download_file() {
  local url="$1"
  local out="$2"
  local curl_bin=""
  local wget_bin=""

  if command -v wget >/dev/null 2>&1; then
    wget_bin="wget"
  elif [ -x "$ROOT_DIR/System/bin/wget" ]; then
    wget_bin="$ROOT_DIR/System/bin/wget"
  fi

  if command -v curl >/dev/null 2>&1; then
    curl_bin="curl"
  elif [ -x "$ROOT_DIR/System/bin/curl-aarch64" ]; then
    curl_bin="$ROOT_DIR/System/bin/curl-aarch64"
  fi

  if [ -n "$wget_bin" ]; then
    "$wget_bin" --no-check-certificate -O "$out" "$url"
    return $?
  fi
  if [ -n "$curl_bin" ]; then
    "$curl_bin" -k -L -o "$out" "$url"
    return $?
  fi
  return 1
}

extract_zip() {
  local zip="$1"
  local dest="$2"
  local arch
  arch="$(uname -m 2>/dev/null || echo "")"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$zip" -d "$dest"
  elif command -v 7zz >/dev/null 2>&1; then
    7zz x -y "$zip" -o"$dest" >/dev/null
  elif command -v 7z >/dev/null 2>&1; then
    7z x -y "$zip" -o"$dest" >/dev/null
  elif [ -x "$ROOT_DIR/System/bin/7zz" ] && [ "$arch" = "aarch64" ]; then
    "$ROOT_DIR/System/bin/7zz" x -y "$zip" -o"$dest" >/dev/null
  else
    show_notice "Missing unzip or 7z for extraction." "red" 3
    echo "Missing unzip or 7z for extraction."
    return 1
  fi
}

TMP_BASE="$RA_DIR/.retroarch/downloads"
mkdir -p "$TMP_BASE"
TMP_DIR="$TMP_BASE/mega_bezel.$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_PATH="$TMP_DIR/mega_bezel.zip"
EXTRACT_DIR="$TMP_DIR/extract"

if [ -n "$REF" ]; then
  URLS=("https://github.com/HyperspaceMadness/Mega_Bezel/archive/refs/heads/$REF.zip")
else
  URLS=(
    "https://github.com/HyperspaceMadness/Mega_Bezel/archive/refs/heads/main.zip"
    "https://github.com/HyperspaceMadness/Mega_Bezel/archive/refs/heads/master.zip"
  )
fi

echo "RetroArch shader base: $SHADER_BASE"
echo "Install target: $TARGET_ROOT/bezel"
show_notice "Downloading Mega Bezel shaders..." "" 1

repo_dir=""
download_success=0
for url in "${URLS[@]}"; do
  rm -rf "$EXTRACT_DIR"
  rm -f "$ZIP_PATH"
  mkdir -p "$EXTRACT_DIR"
  if ! download_file "$url" "$ZIP_PATH"; then
    continue
  fi
  download_success=1
  if ! extract_zip "$ZIP_PATH" "$EXTRACT_DIR"; then
    continue
  fi
  for dir in "$EXTRACT_DIR"/Mega_Bezel-* "$EXTRACT_DIR"/Mega_Bezel; do
    if [ -d "$dir" ]; then
      repo_dir="$dir"
      break
    fi
  done
  [ -n "$repo_dir" ] && break
done

if [ -z "$repo_dir" ]; then
  if [ "$download_success" -eq 0 ]; then
    show_notice "Download failed. Internet connection required (no local backup)." "red" 4
    echo "Failed to download Mega Bezel. Internet connection required."
  else
    show_notice "Failed to download or extract Mega Bezel." "red" 4
    echo "Failed to download or extract Mega Bezel."
  fi
  exit 1
fi

find_dir() {
  local root="$1"
  local name="$2"
  local path=""
  if [ -d "$root/shaders_slang/bezel" ]; then
    path="$(find "$root/shaders_slang/bezel" -type d -name "$name" 2>/dev/null | head -n 1)"
  fi
  if [ -z "$path" ] && [ -d "$root/bezel" ]; then
    path="$(find "$root/bezel" -type d -name "$name" 2>/dev/null | head -n 1)"
  fi
  if [ -z "$path" ]; then
    path="$(find "$root" -type d -name "$name" 2>/dev/null | head -n 1)"
  fi
  echo "$path"
}

installed_any=0
for dir in "${DIRS[@]}"; do
  src_dir="$(find_dir "$repo_dir" "$dir")"
  if [ -z "$src_dir" ] && [ "$dir" = "Mega_Bezel" ]; then
    if [ -z "$(find "$repo_dir" -type d -name "Mega_Bezel_Packs" 2>/dev/null | head -n 1)" ] && \
       [ -z "$(find "$repo_dir" -type d -name "Mega_Bezel_Community" 2>/dev/null | head -n 1)" ]; then
      case "$(basename "$repo_dir")" in
        Mega_Bezel*) src_dir="$repo_dir" ;;
      esac
    fi
  fi
  if [ -n "$src_dir" ]; then
    rm -rf "$TARGET_BEZEL/$dir"
    cp -R "$src_dir" "$TARGET_BEZEL/$dir"
    echo "Installed: $TARGET_BEZEL/$dir"
    installed_any=1
  fi
done

if [ "$installed_any" -eq 0 ]; then
  show_notice "Mega Bezel folders not found in the archive." "red" 3
  echo "Mega Bezel folders not found in the archive."
  exit 1
fi

show_notice "Mega Bezel shaders installed." "" 2
cat <<'EONOTE'
Done.

Note: Mega Bezel is installed in RetroArch's shader folder, which CrossMix
restores after updates. If RetroArch is updated and the shaders are missing,
re-run this script.
EONOTE
