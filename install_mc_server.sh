#!/usr/bin/env bash
set -euo pipefail

############################################
# ARGS
############################################
DEBUG=false
UNINSTALL=false
LOG_FILE=""

if [[ "${1:-}" == "--debug" ]]; then
  DEBUG=true
  LOG_FILE="./debug_$(date '+%Y-%m-%d_%H-%M-%S').log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
  set -x
  echo "🐞 Debug mode enabled"
  echo "📄 Log file: $LOG_FILE"
  echo "--------------------------------------------"
elif [[ "${1:-}" == "--uninstall" ]]; then
  UNINSTALL=true
fi

log()  { echo "➡️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
die()  { echo "❌ $*" >&2; exit 1; }

############################################
# BANNER
############################################
clear
cat << "EOF"
  __  __  _____  _____                            _____           _        _ _
 |  \/  |/ ____|/ ____|                          |_   _|         | |      | | |
 | \  / | |    | (___   ___ _ ____   _____ _ __    | |  _ __  ___| |_ __ _| | | ___ _ __
 | |\/| | |     \___ \ / _ \ '__\ \ / / _ \ '__|   | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |  | | |____ ____) |  __/ |   \ V /  __/ |     _| |_| | | \__ \ || (_| | | |  __/ |
 |_|  |_|\_____|_____/ \___|_|    \_/ \___|_|    |_____|_| |_|___/\__\__,_|_|_|\___|_|

==== Minecraft Server Auto-Installer - Created by JOTIBI ====
EOF
echo

############################################
# APT HELPERS
############################################
apt_install_if_missing() {
  local pkgs=("$@")
  local missing=()

  for p in "${pkgs[@]}"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then
      missing+=("$p")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log "Installing prerequisites: ${missing[*]}"
    sudo apt update -qq
    sudo apt install -y "${missing[@]}" >/dev/null
    ok "Prerequisites installed"
  fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

fetch_json() {
  local url="$1"
  curl -fsSL \
    --retry 8 --retry-delay 1 --retry-all-errors \
    --connect-timeout 10 --max-time 30 \
    -H "Accept: application/json" \
    "$url"
}

download_file() {
  local url="$1"
  local out="$2"
  curl -fL \
    --retry 8 --retry-delay 1 --retry-all-errors \
    --connect-timeout 10 --max-time 300 \
    -o "$out" \
    "$url"
}

ensure_eula() { echo "eula=true" > eula.txt; }

set_server_port() {
  local port="$1"
  if [[ ! -f server.properties ]]; then
    cat > server.properties <<EOF
server-port=${port}
enable-command-block=true
motd=${SERVER_NAME}
EOF
    return
  fi
  if grep -q '^server-port=' server.properties; then
    sed -i "s/^server-port=.*/server-port=${port}/" server.properties || true
  else
    echo "server-port=${port}" >> server.properties
  fi
}

############################################
# JAVA RECOMMENDATION
############################################
ver_ge() { # version compare: ver_ge a b  => a>=b
  # sort -V works for dotted versions
  [[ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

recommend_java_for_mc() {
  local mc="$1"
  # Heuristic ranges (good enough for MC server picking):
  # <=1.16.x -> Java 8
  # 1.17-1.18.x -> Java 16/17 (we recommend 17, still runs)
  # 1.18.2-1.20.4 -> Java 17
  # >=1.20.5 -> Java 21
  #
  # We'll keep it simple using thresholds:
  # >=1.20.5 -> 21
  # >=1.18.2 -> 17
  # >=1.17   -> 17 (recommended)
  # else     -> 8
  if ver_ge "$mc" "1.20.5"; then
    echo "21"
  elif ver_ge "$mc" "1.17"; then
    echo "17"
  else
    echo "8"
  fi
}

############################################
# JAVA SELECTION
############################################
select_java() {
  apt_install_if_missing default-jre
  need_cmd java

  local rec major
  rec="$(recommend_java_for_mc "$MC_VERSION")"
  log "Recommended Java for MC ${MC_VERSION}: Java ${rec}"

  local javacands
  javacands="$(update-alternatives --list java 2>/dev/null || true)"

  if [[ -z "${javacands//[[:space:]]/}" ]]; then
    JAVA_BIN="$(command -v java)"
    warn "No alternatives list found; using: $JAVA_BIN"
    return
  fi

  mapfile -t JAVA_LIST < <(printf "%s\n" "$javacands")

  echo
  echo "Installed Java alternatives:"
  for i in "${!JAVA_LIST[@]}"; do
    local path="${JAVA_LIST[$i]}"
    local vline=""
    vline="$("$path" -version 2>&1 | head -n1 || true)"
    echo "$((i+1))) $path  ->  $vline"
  done

  echo
  local def_java
  def_java="$(command -v java 2>/dev/null || true)"
  echo "Current default (PATH): ${def_java:-unknown}"
  echo "Recommendation: Java $rec"
  read -p "Which Java should this server use? (1-${#JAVA_LIST[@]}): " JAVA_PICK

  [[ "$JAVA_PICK" =~ ^[0-9]+$ ]] || die "Invalid selection."
  (( JAVA_PICK >= 1 && JAVA_PICK <= ${#JAVA_LIST[@]} )) || die "Invalid selection."

  JAVA_BIN="${JAVA_LIST[$((JAVA_PICK-1))]}"
  [[ -x "$JAVA_BIN" ]] || die "Chosen java is not executable: $JAVA_BIN"

  # Warn if mismatch with recommended major
  local chosen_major
  chosen_major="$("$JAVA_BIN" -version 2>&1 | head -n1 | sed -n 's/.*"\([0-9]\+\).*/\1/p' | head -n1)"
  if [[ -n "$chosen_major" && "$chosen_major" != "$rec" ]]; then
    warn "Chosen Java major ($chosen_major) differs from recommended ($rec) for MC $MC_VERSION."
    warn "If the server fails to start, pick another Java (recommended: $rec)."
  else
    ok "Java selection matches recommendation."
  fi

  ok "Selected java: $JAVA_BIN"
}

############################################
# UNINSTALL MODE
############################################
uninstall_flow() {
  apt_install_if_missing screen jq curl ca-certificates
  need_cmd screen

  echo "Uninstaller"
  echo "-----------"
  read -p "Enter installation path (default: /home/mcserver): " SERVER_PATH
  SERVER_PATH=${SERVER_PATH:-/home/mcserver}

  if [[ ! -d "$SERVER_PATH" ]]; then
    die "Path does not exist: $SERVER_PATH"
  fi

  # list servers (folders containing .java_path or start.sh)
  mapfile -t SERVERS < <(find "$SERVER_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  if [[ ${#SERVERS[@]} -eq 0 ]]; then
    die "No server directories found in $SERVER_PATH"
  fi

  echo
  echo "Detected server directories:"
  for i in "${!SERVERS[@]}"; do
    local name
    name="$(basename "${SERVERS[$i]}")"
    echo "$((i+1))) $name  (${SERVERS[$i]})"
  done

  echo
  read -p "Which server do you want to uninstall? (1-${#SERVERS[@]}): " PICK
  [[ "$PICK" =~ ^[0-9]+$ ]] || die "Invalid selection."
  (( PICK >= 1 && PICK <= ${#SERVERS[@]} )) || die "Invalid selection."

  local TARGET_DIR="${SERVERS[$((PICK-1))]}"
  local TARGET_NAME
  TARGET_NAME="$(basename "$TARGET_DIR")"

  echo
  echo "Selected: $TARGET_NAME"
  echo "Path:     $TARGET_DIR"

  # attempt to stop screen session with same name
  if screen -list | grep -q "\\.${TARGET_NAME}[[:space:]]"; then
    log "Stopping screen session: $TARGET_NAME"
    screen -S "$TARGET_NAME" -X stuff "stop$(printf \\r)" || true
    sleep 2
    screen -S "$TARGET_NAME" -X quit || true
    ok "Screen session stopped (if it existed)."
  else
    log "No running screen session found for: $TARGET_NAME"
  fi

  echo
  read -p "Delete the whole server directory permanently? (y/n): " CONFIRM
  CONFIRM=${CONFIRM:-n}
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$TARGET_DIR"
    ok "Deleted: $TARGET_DIR"
  else
    ok "Uninstall aborted (nothing deleted)."
  fi

  exit 0
}

############################################
# MAIN INSTALL FLOW
############################################
apt_install_if_missing curl jq ca-certificates screen
need_cmd curl
need_cmd jq
need_cmd screen

if $UNINSTALL; then
  uninstall_flow
fi

read -p "Enter the server name (default: minecraft-server): " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-minecraft-server}

read -p "Enter the installation path (default: /home/mcserver): " SERVER_PATH
SERVER_PATH=${SERVER_PATH:-/home/mcserver}

SERVER_DIR="$SERVER_PATH/$SERVER_NAME"
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

echo
echo "Select the server type:"
echo "1) Vanilla"
echo "2) Forge"
echo "3) Fabric"
echo "4) Spigot"
echo "5) Paper"
echo "6) Bungeecord"
read -p "Choose an option (1-6, default: 1): " SERVER_TYPE
SERVER_TYPE=${SERVER_TYPE:-1}

read -p "Enter Minecraft version (default: 1.21.1): " MC_VERSION
MC_VERSION=${MC_VERSION:-1.21.1}

read -p "Enter maximum RAM (default: 4G): " RAM_AMOUNT
RAM_AMOUNT=${RAM_AMOUNT:-4G}

read -p "Enter server port (default: 25565): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-25565}

# Choose Java based on installed alternatives + recommendation
select_java
echo "$JAVA_BIN" > .java_path

# per-type prerequisites
case "$SERVER_TYPE" in
  4) apt_install_if_missing git default-jdk ;;
  2) apt_install_if_missing default-jdk ;;
esac

############################################
# INSTALLERS
############################################
install_vanilla() {
  log "Resolving Vanilla server for MC $MC_VERSION ..."
  local manifest version_url server_url

  manifest="$(fetch_json "https://launchermeta.mojang.com/mc/game/version_manifest.json")"
  version_url="$(echo "$manifest" | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id==$v) | .url' | head -n1)"
  [[ -n "$version_url" && "$version_url" != "null" ]] || die "MC version not found in Mojang manifest: $MC_VERSION"

  server_url="$(fetch_json "$version_url" | jq -r '.downloads.server.url')"
  [[ -n "$server_url" && "$server_url" != "null" ]] || die "No vanilla server url for $MC_VERSION"

  download_file "$server_url" "server.jar" || die "Vanilla download failed"
  ok "Downloaded server.jar"
}

install_forge() {
  log "Forge selected."
  read -p "Enter Forge version (example: 52.0.12) for MC $MC_VERSION: " FORGE_VERSION
  [[ -n "${FORGE_VERSION:-}" ]] || die "Forge version is required."

  local installer="forge-${MC_VERSION}-${FORGE_VERSION}-installer.jar"
  local url="https://maven.minecraftforge.net/net/minecraftforge/forge/${MC_VERSION}-${FORGE_VERSION}/${installer}"

  log "Downloading Forge installer:"
  log "$url"
  download_file "$url" "$installer" || die "Forge installer download failed (check MC+Forge version combo)."

  log "Running Forge installer (server install)…"
  "$JAVA_BIN" -jar "$installer" --installServer || die "Forge installer failed."

  ensure_eula
  set_server_port "$SERVER_PORT"

  if [[ -f run.sh ]]; then
    chmod +x run.sh || true
    echo "forge_runsh" > .server_mode
    ok "Forge installed (run.sh)."
    return
  fi

  local jar_candidate
  jar_candidate="$(ls -1 forge-*.jar 2>/dev/null | head -n1 || true)"
  [[ -n "$jar_candidate" ]] || die "Forge installed but no forge-*.jar found and no run.sh."
  mv -f "$jar_candidate" server.jar || true
  ok "Forge jar prepared as server.jar"
}

install_fabric() {
  local base="https://meta.fabricmc.net/v2/versions"
  log "Resolving latest Fabric (stable) for MC $MC_VERSION …"

  local installer_json loader_json default_installer default_loader installer_ver loader_ver
  installer_json="$(fetch_json "$base/installer")" || die "Could not fetch Fabric installer list."
  loader_json="$(fetch_json "$base/loader/$MC_VERSION")" || die "Could not fetch Fabric loader list for MC $MC_VERSION."

  if $DEBUG; then
    echo "$installer_json" > fabric_installers.json
    echo "$loader_json" > "fabric_loaders_${MC_VERSION}.json"
    ok "Saved debug JSON: fabric_installers.json, fabric_loaders_${MC_VERSION}.json"
  fi

  default_installer="$(echo "$installer_json" | jq -r '.[] | select(.stable==true) | .version' | head -n1)"
  [[ -n "$default_installer" && "$default_installer" != "null" ]] || default_installer="$(echo "$installer_json" | jq -r '.[0].version')"

  default_loader="$(echo "$loader_json" | jq -r '.[] | select(.loader.stable==true) | .loader.version' | head -n1)"
  [[ -n "$default_loader" && "$default_loader" != "null" ]] || default_loader="$(echo "$loader_json" | jq -r '.[0].loader.version')"

  echo
  read -p "Fabric installer version (default: $default_installer): " installer_ver
  installer_ver="${installer_ver:-$default_installer}"

  read -p "Fabric loader version (default: $default_loader): " loader_ver
  loader_ver="${loader_ver:-$default_loader}"

  [[ -n "$installer_ver" ]] || die "Installer version empty."
  [[ -n "$loader_ver" ]] || die "Loader version empty."

  ok "Selected Fabric:"
  echo "   MC:        $MC_VERSION"
  echo "   Loader:    $loader_ver"
  echo "   Installer: $installer_ver"

  local jar_url="https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${loader_ver}/${installer_ver}/server/jar"

  log "Downloading Fabric server.jar:"
  log "$jar_url"
  download_file "$jar_url" "server.jar" || die "Fabric download failed (check MC/loader/installer combo)."
  ok "Downloaded server.jar"
}

install_spigot() {
  log "Spigot selected (BuildTools)."

  local bt_dir="./buildtools"
  mkdir -p "$bt_dir"
  cd "$bt_dir"

  download_file "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" "BuildTools.jar" \
    || die "Failed to download BuildTools.jar"

  log "Running BuildTools --rev $MC_VERSION (can take a while)…"
  "$JAVA_BIN" -Xmx2G -jar BuildTools.jar --rev "$MC_VERSION" || die "BuildTools failed."

  local spigot_jar
  spigot_jar="$(ls -1 spigot-*.jar 2>/dev/null | sort | tail -n1 || true)"
  [[ -n "$spigot_jar" ]] || die "Could not find spigot jar after BuildTools."

  mv -f "$spigot_jar" "../server.jar"
  cd ..
  ok "Spigot built as server.jar"
}

install_paper() {
  log "Resolving Paper latest build for MC $MC_VERSION …"
  local api="https://api.papermc.io/v2/projects/paper"
  local builds_json latest_build jar_name jar_url

  if ! fetch_json "$api" | jq -e --arg v "$MC_VERSION" '.versions | index($v)' >/dev/null; then
    die "Paper does not list MC version: $MC_VERSION"
  fi

  builds_json="$(fetch_json "$api/versions/$MC_VERSION/builds")" || die "Failed to fetch Paper builds."
  latest_build="$(echo "$builds_json" | jq -r '.builds[-1].build')"
  [[ -n "$latest_build" && "$latest_build" != "null" ]] || die "Could not resolve latest Paper build."

  jar_name="paper-${MC_VERSION}-${latest_build}.jar"
  jar_url="$api/versions/$MC_VERSION/builds/$latest_build/downloads/$jar_name"

  log "Downloading Paper server.jar:"
  log "$jar_url"
  download_file "$jar_url" "server.jar" || die "Paper download failed."
  ok "Downloaded server.jar"
}

install_bungeecord() {
  log "Downloading latest BungeeCord …"
  download_file "https://hub.spigotmc.org/jenkins/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar" "BungeeCord.jar" \
    || die "BungeeCord download failed."
  ok "Downloaded BungeeCord.jar"
  echo "bungee" > .server_mode
}

############################################
# DISPATCH
############################################
case "$SERVER_TYPE" in
  1) install_vanilla ;;
  2) install_forge ;;
  3) install_fabric ;;
  4) install_spigot ;;
  5) install_paper ;;
  6) install_bungeecord ;;
  *) die "Invalid choice." ;;
esac

############################################
# FINALIZE (files + screen start script)
############################################
MODE="$(cat .server_mode 2>/dev/null || true)"
MODE="${MODE:-normal}"

# normal servers: eula + port
if [[ "$MODE" != "bungee" ]]; then
  ensure_eula
  set_server_port "$SERVER_PORT"
fi

SESSION_NAME="$SERVER_NAME"

cat > start.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

SESSION="${SESSION_NAME}"
JAVA_BIN="${JAVA_BIN}"
RAM="${RAM_AMOUNT}"
DIR="\$(cd "\$(dirname "\$0")" && pwd)"

MODE_FILE="\$DIR/.server_mode"
MODE="normal"
if [[ -f "\$MODE_FILE" ]]; then
  MODE="\$(cat "\$MODE_FILE" || true)"
fi

start_server() {
  if screen -list | grep -q "\\.\${SESSION}[[:space:]]"; then
    echo "✅ screen session '\$SESSION' already running."
    exit 0
  fi

  cd "\$DIR"

  if [[ "\$MODE" == "bungee" ]]; then
    echo "▶ Starting BungeeCord in screen '\$SESSION'..."
    screen -dmS "\$SESSION" "\$JAVA_BIN" -Xms"\$RAM" -Xmx"\$RAM" -jar "BungeeCord.jar"
    echo "✅ Started. Attach with: ./start.sh attach"
    exit 0
  fi

  if [[ "\$MODE" == "forge_runsh" ]]; then
    chmod +x run.sh || true
    echo "▶ Starting Forge (run.sh) in screen '\$SESSION'..."
    screen -dmS "\$SESSION" bash -lc "./run.sh"
    echo "✅ Started. Attach with: ./start.sh attach"
    exit 0
  fi

  echo "▶ Starting server.jar in screen '\$SESSION'..."
  screen -dmS "\$SESSION" "\$JAVA_BIN" -Xms"\$RAM" -Xmx"\$RAM" -jar "server.jar" nogui
  echo "✅ Started. Attach with: ./start.sh attach"
}

attach_server() {
  screen -r "\$SESSION" || { echo "❌ No session '\$SESSION' found."; exit 1; }
}

stop_server() {
  if screen -list | grep -q "\\.\${SESSION}[[:space:]]"; then
    echo "⏹ Stopping session '\$SESSION'..."
    screen -S "\$SESSION" -X stuff "stop\$(printf \\\\r)" || true
    sleep 2
    if screen -list | grep -q "\\.\${SESSION}[[:space:]]"; then
      screen -S "\$SESSION" -X quit || true
    fi
    echo "✅ Stopped."
  else
    echo "ℹ️ No session '\$SESSION' running."
  fi
}

case "\${1:-start}" in
  start)  start_server ;;
  attach) attach_server ;;
  stop)   stop_server ;;
  *) echo "Usage: ./start.sh [start|attach|stop]"; exit 1 ;;
esac
EOF

chmod +x start.sh

echo
ok "Done!"
echo "📁 Path: $SERVER_DIR"
echo "☕ Java used: $JAVA_BIN"
echo "💡 Recommended Java for MC $MC_VERSION: Java $(recommend_java_for_mc "$MC_VERSION")"
echo "🖥  screen session: $SESSION_NAME"
echo "▶ Start:   ./start.sh"
echo "▶ Attach:  ./start.sh attach"
echo "▶ Stop:    ./start.sh stop"
echo "▶ Uninstall: ./$(basename "$0") --uninstall"
if $DEBUG; then
  echo "🐞 Debug log saved to: $LOG_FILE"
fi
