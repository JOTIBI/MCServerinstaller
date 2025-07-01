#!/bin/bash

# Exit on any error
set -e

# Function to validate input
validate_port() {
    local port=$1
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Port must be a number between 1 and 65535"
        exit 1
    fi
}

validate_ram() {
    local ram=$1
    if [[ ! "$ram" =~ ^[0-9]+[GMgm]?$ ]]; then
        echo "Error: RAM format should be like '4G' or '2048M'"
        exit 1
    fi
}

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    for tool in wget curl jq screen; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}"
        echo "Please install them first."
        exit 1
    fi
}

clear

cat << "EOF"
  __  __  _____  _____                            _____           _        _ _           
 |  \/  |/ ____|/ ____|                          |_   _|         | |      | | |          
 | \  / | |    | (___   ___ _ ____   _____ _ __    | |  _ __  ___| |_ __ _| | | ___ _ __ 
 | |\/| | |     \___ \ / _ \ '__\ \ / / _ \ '__|   | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |  | | |____ ____) |  __/ |   \ V /  __/ |     _| |_| | | \__ \ || (_| | | |  __/ |   
 |_|  |_|\_____|_____/ \___|_|    \_/ \___|_|    |_____|_| |_|___/\__\__,_|_|_|\___|_|   
EOF

echo -e "\n==== Minecraft Server Auto-Installer - Created by JOTIBI ===="

# Check dependencies first
check_dependencies

read -p "Enter the server name (default: minecraft-server): " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-minecraft-server}

read -p "Enter the installation path (default: /home/mcserver): " SERVER_PATH
SERVER_PATH=${SERVER_PATH:-/home/mcserver}
SERVER_DIR="$SERVER_PATH/$SERVER_NAME"

# Create directory with error checking
if ! mkdir -p "$SERVER_DIR"; then
    echo "Error: Could not create directory $SERVER_DIR"
    exit 1
fi

# Change to directory with error checking
if ! cd "$SERVER_DIR"; then
    echo "Error: Could not access directory $SERVER_DIR"
    exit 1
fi

echo -e "\nSelect the server type:"
echo "1) Vanilla"
echo "2) Forge"
echo "3) Fabric"
echo "4) Spigot"
echo "5) Paper"
echo "6) Bungeecord"
read -p "Choose an option (1-6, default: 1): " SERVER_TYPE
SERVER_TYPE=${SERVER_TYPE:-1}

# Validate server type
if [[ ! "$SERVER_TYPE" =~ ^[1-6]$ ]]; then
    echo "Error: Invalid server type. Please choose 1-6."
    exit 1
fi

# Updated default to more recent version
read -p "Enter Minecraft version (default: 1.20.1): " MC_VERSION
MC_VERSION=${MC_VERSION:-1.20.1}

INSTALLER_VERSION=""
if [[ "$SERVER_TYPE" == "2" ]]; then
    read -p "Enter Forge version (default: 47.2.20): " INSTALLER_VERSION
    INSTALLER_VERSION=${INSTALLER_VERSION:-47.2.20}
elif [[ "$SERVER_TYPE" == "3" ]]; then
    read -p "Enter Fabric installer version (default: 0.15.3): " INSTALLER_VERSION
    INSTALLER_VERSION=${INSTALLER_VERSION:-0.15.3}
fi

read -p "Enter maximum RAM (default: 4G): " RAM_AMOUNT
RAM_AMOUNT=${RAM_AMOUNT:-4G}
validate_ram "$RAM_AMOUNT"

read -p "Enter server port (default: 25565): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-25565}
validate_port "$SERVER_PORT"

JAVA_PATHS=($(update-alternatives --list java 2>/dev/null))
if [ ${#JAVA_PATHS[@]} -eq 0 ]; then
    echo "No Java versions found. Please install Java."
    exit 1
fi

echo -e "\nAvailable Java versions:"
for i in "${!JAVA_PATHS[@]}"; do
  echo "$((i+1))) ${JAVA_PATHS[$i]}"
done

read -p "Select the Java version to use (1-${#JAVA_PATHS[@]}): " JAVA_CHOICE

# Validate Java choice
if [[ ! "$JAVA_CHOICE" =~ ^[0-9]+$ ]] || [ "$JAVA_CHOICE" -lt 1 ] || [ "$JAVA_CHOICE" -gt ${#JAVA_PATHS[@]} ]; then
    echo "Error: Invalid choice. Please select a number between 1 and ${#JAVA_PATHS[@]}"
    exit 1
fi

JAVA_INDEX=$((JAVA_CHOICE-1))
JAVA_PATH="${JAVA_PATHS[$JAVA_INDEX]}"

echo -e "\nDownloading server files..."

case $SERVER_TYPE in
    1)
        echo "Downloading Vanilla server..."
        DOWNLOAD_URL=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg MC_VERSION "$MC_VERSION" '.versions[] | select(.id==$MC_VERSION) | .url')
        if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
            echo "Error: Minecraft version $MC_VERSION not found"
            exit 1
        fi
        DOWNLOAD_URL=$(curl -s "$DOWNLOAD_URL" | jq -r '.downloads.server.url')
        if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
            echo "Error: Server download URL not found for version $MC_VERSION"
            exit 1
        fi
        if ! wget -O server.jar "$DOWNLOAD_URL"; then
            echo "Error: Failed to download Vanilla server"
            exit 1
        fi
        ;;
    2)
        echo "Downloading Forge installer..."
        FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$MC_VERSION-$INSTALLER_VERSION/forge-$MC_VERSION-$INSTALLER_VERSION-installer.jar"
        if ! wget -O forge-installer.jar "$FORGE_URL"; then
            echo "Error: Failed to download Forge installer"
            exit 1
        fi
        echo "Installing Forge server (this may take a few minutes)..."
        if ! "$JAVA_PATH" -jar forge-installer.jar --installServer; then
            echo "Error: Forge installation failed"
            exit 1
        fi
        ;;
    3)
        echo "Downloading Fabric installer..."
        FABRIC_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/$INSTALLER_VERSION/fabric-installer-$INSTALLER_VERSION.jar"
        if ! wget -O fabric-installer.jar "$FABRIC_URL"; then
            echo "Error: Failed to download Fabric installer"
            exit 1
        fi
        echo "Installing Fabric server..."
        if ! "$JAVA_PATH" -jar fabric-installer.jar server -mcversion "$MC_VERSION" -dir "$SERVER_DIR"; then
            echo "Error: Fabric installation failed"
            exit 1
        fi
        ;;
    4)
        echo "Downloading Spigot BuildTools..."
        if ! wget -O BuildTools.jar "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"; then
            echo "Error: Failed to download BuildTools"
            exit 1
        fi
        echo "Building Spigot (this will take 10-30 minutes, please be patient)..."
        if ! "$JAVA_PATH" -jar BuildTools.jar --rev "$MC_VERSION"; then
            echo "Error: Spigot build failed"
            exit 1
        fi
        if ! mv spigot-*.jar server.jar 2>/dev/null; then
            echo "Error: Could not find built Spigot jar file"
            exit 1
        fi
        ;;
    5)
        echo "Downloading Paper server..."
        PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION/builds/latest/downloads/paper-$MC_VERSION-latest.jar"
        if ! wget -O server.jar "$PAPER_URL"; then
            echo "Error: Failed to download Paper server. Version $MC_VERSION might not be available."
            exit 1
        fi
        ;;
    6)
        echo "Downloading BungeeCord..."
        if ! wget -O server.jar "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"; then
            echo "Error: Failed to download BungeeCord"
            exit 1
        fi
        ;;
esac

# Create EULA file
echo "eula=true" > eula.txt

# Find the correct server JAR file
if [[ "$SERVER_TYPE" == "2" ]]; then
  SERVER_JAR=$(find . -maxdepth 1 -name "forge-*.jar" ! -name "*installer*" | head -n 1)
elif [[ "$SERVER_TYPE" == "3" ]]; then
  SERVER_JAR=$(find . -maxdepth 1 -name "fabric-server-launch.jar" | head -n 1)
else
  SERVER_JAR=$(find . -maxdepth 1 -name "*.jar" ! -name "*installer*.jar" ! -name "BuildTools.jar" | head -n 1)
fi

# Validate that SERVER_JAR exists and is not empty
if [[ ! -f "$SERVER_JAR" ]] || [[ ! -s "$SERVER_JAR" ]]; then
    echo "Error: Server JAR file not found or is empty"
    echo "Expected file: $SERVER_JAR"
    exit 1
fi

echo "Server JAR found: $SERVER_JAR"

# Create server.properties with correct port
cat > server.properties <<EOF
server-port=$SERVER_PORT
motd=A Minecraft Server
difficulty=easy
gamemode=survival
max-players=20
pvp=true
view-distance=10
spawn-protection=16
white-list=false
enforce-whitelist=false
spawn-monsters=true
spawn-animals=true
spawn-npcs=true
generate-structures=true
allow-nether=true
EOF

# Create start script
cat > start.sh <<EOF
#!/bin/bash
cd "\$(dirname "\$0")"

# Check if server is already running
if screen -list | grep -wq "$SERVER_NAME"; then
  echo "Server '$SERVER_NAME' is already running."
  echo "Use 'screen -r $SERVER_NAME' to attach to the session."
  exit 1
fi

# Check if server JAR exists
if [[ ! -f "$SERVER_JAR" ]]; then
    echo "Error: Server JAR file '$SERVER_JAR' not found"
    exit 1
fi

echo "Starting Minecraft server '$SERVER_NAME' on port $SERVER_PORT..."
echo "Use 'screen -r $SERVER_NAME' to attach to the server console."
echo "Use Ctrl+A, then D to detach from the console."

screen -dmS "$SERVER_NAME" "$JAVA_PATH" -Xms1G -Xmx$RAM_AMOUNT -jar "$SERVER_JAR" nogui

# Wait a moment and check if the server started successfully
sleep 2
if screen -list | grep -wq "$SERVER_NAME"; then
    echo "Server started successfully!"
else
    echo "Error: Server failed to start. Check the logs for details."
    exit 1
fi
EOF

chmod +x start.sh

# Make JAR files executable (if any exist)
chmod +x *.jar 2>/dev/null || true

# Firewall configuration
if command -v ufw &> /dev/null; then
    read -p "Would you like to open firewall port $SERVER_PORT? (y/n, default: n): " UFW_CHOICE
    UFW_CHOICE=${UFW_CHOICE:-n}
    if [[ "$UFW_CHOICE" == "y" || "$UFW_CHOICE" == "Y" ]]; then
        if ufw allow "$SERVER_PORT"; then
            echo "Firewall port $SERVER_PORT opened successfully."
        else
            echo "Warning: Failed to open firewall port $SERVER_PORT"
        fi
    fi
else
    echo "Note: 'ufw' not installed. No firewall rule was created."
fi

# Option to start server immediately
read -p "Do you want to start the server now? (y/n, default: n): " START_NOW
START_NOW=${START_NOW:-n}
if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    ./start.sh
fi

clear
echo "==== Installation Completed! ===="
echo "Server directory: $SERVER_DIR"
echo "Start command: ./start.sh"
echo "Screen session name: $SERVER_NAME"
echo "RAM allocation: $RAM_AMOUNT"
echo "Server port: $SERVER_PORT"
echo "Java version: $JAVA_PATH"
echo "Server JAR: $SERVER_JAR"
echo ""
echo "To manage your server:"
echo "  Start: ./start.sh"
echo "  Attach to console: screen -r $SERVER_NAME"
echo "  Detach from console: Ctrl+A, then D"
echo "  Stop server: Execute 'stop' command in the server console"
echo "================================="
