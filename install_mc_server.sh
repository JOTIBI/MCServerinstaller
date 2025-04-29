#!/bin/bash

# Minecraft Server Auto-Installer Script
# Developed and proudly powered by JOTIBI

clear

cat << "EOF"
  __  __  _____  _____                            _____           _        _ _           
 |  \/  |/ ____|/ ____|                          |_   _|         | |      | | |          
 | \  / | |    | (___   ___ _ ____   _____ _ __    | |  _ __  ___| |_ __ _| | | ___ _ __ 
 | |\/| | |     \___ \ / _ \ '__\ \ / / _ \ '__|   | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |  | | |____ ____) |  __/ |   \ V /  __/ |     _| |_| | | \__ \ || (_| | | |  __/ |   
 |_|  |_|\_____|_____/ \___|_|    \_/ \___|_|    |_____|_| |_|___/\__\__,_|_|_|\___|_|   
EOF

echo "\n==== Minecraft Server Auto-Installer - Created by JOTIBI ===="

read -p "Enter the server name (default: minecraft-server): " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-minecraft-server}

read -p "Enter the installation path (default: /home/mcserver): " SERVER_PATH
SERVER_PATH=${SERVER_PATH:-/home/mcserver}
SERVER_DIR="$SERVER_PATH/$SERVER_NAME"
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

echo "\nSelect the server type:"
echo "1) Vanilla"
echo "2) Forge"
echo "3) Fabric"
echo "4) Spigot"
echo "5) Paper"
echo "6) Bungeecord"
read -p "Choose an option (1-6, default: 1): " SERVER_TYPE
SERVER_TYPE=${SERVER_TYPE:-1}

read -p "Enter Minecraft version (default: 1.16.5): " MC_VERSION
MC_VERSION=${MC_VERSION:-1.16.5}

INSTALLER_VERSION=""
if [[ "$SERVER_TYPE" == "2" ]]; then
    read -p "Enter Forge version (default: 36.2.42): " INSTALLER_VERSION
    INSTALLER_VERSION=${INSTALLER_VERSION:-36.2.42}
elif [[ "$SERVER_TYPE" == "3" ]]; then
    read -p "Enter Fabric installer version (default: 0.11.2): " INSTALLER_VERSION
    INSTALLER_VERSION=${INSTALLER_VERSION:-0.11.2}
fi

read -p "Enter maximum RAM (default: 4G): " RAM_AMOUNT
RAM_AMOUNT=${RAM_AMOUNT:-4G}

read -p "Enter server port (default: 25565): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-25565}

JAVA_PATHS=($(update-alternatives --list java 2>/dev/null))
if [ ${#JAVA_PATHS[@]} -eq 0 ]; then
    echo "No Java versions found. Please install Java."
    exit 1
fi

echo "\nAvailable Java versions:"
for i in "${!JAVA_PATHS[@]}"; do
  echo "$((i+1))) ${JAVA_PATHS[$i]}"
done

read -p "Select the Java version to use (1-${#JAVA_PATHS[@]}): " JAVA_CHOICE
JAVA_INDEX=$((JAVA_CHOICE-1))

if [[ -z "${JAVA_PATHS[$JAVA_INDEX]}" ]]; then
    echo "Invalid choice. Aborting."
    exit 1
fi

JAVA_PATH="${JAVA_PATHS[$JAVA_INDEX]}"

case $SERVER_TYPE in
    1)
        DOWNLOAD_URL=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg MC_VERSION "$MC_VERSION" '.versions[] | select(.id==$MC_VERSION) | .url' | xargs curl -s | jq -r '.downloads.server.url')
        wget -O server.jar "$DOWNLOAD_URL"
        ;;
    2)
        wget -O forge-installer.jar "https://maven.minecraftforge.net/net/minecraftforge/forge/$MC_VERSION-$INSTALLER_VERSION/forge-$MC_VERSION-$INSTALLER_VERSION-installer.jar"
        "$JAVA_PATH" -jar forge-installer.jar --installServer
        ;;
    3)
        wget -O fabric-installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$INSTALLER_VERSION/fabric-installer-$INSTALLER_VERSION.jar"
        "$JAVA_PATH" -jar fabric-installer.jar server -mcversion "$MC_VERSION" -dir "$SERVER_DIR"
        ;;
    4)
        wget -O BuildTools.jar "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
        "$JAVA_PATH" -jar BuildTools.jar --rev "$MC_VERSION"
        mv spigot-*.jar server.jar
        ;;
    5)
        wget -O server.jar "https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION/builds/latest/downloads/paper-$MC_VERSION-latest.jar"
        ;;
    6)
        wget -O server.jar "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"
        ;;
    *)
        echo "Invalid choice. Aborting."
        exit 1
        ;;
esac

echo "eula=true" > eula.txt

SERVER_JAR=$(find . -maxdepth 1 -name "*.jar" ! -name "*installer*.jar" ! -name "BuildTools.jar" | head -n 1)

cat > start.sh <<EOF
#!/bin/bash
cd "\$(dirname "\$0")"
if screen -list | grep -q "$SERVER_NAME"; then
  echo "Server '\$SERVER_NAME' is already running."
  exit 1
fi
screen -dmS "$SERVER_NAME" "$JAVA_PATH" -Xms1G -Xmx$RAM_AMOUNT -jar "$SERVER_JAR" nogui
EOF

chmod +x start.sh
chmod +x *.jar

if command -v ufw &> /dev/null; then
    read -p "Would you like to open firewall port $SERVER_PORT? (y/n, default: n): " UFW_CHOICE
    UFW_CHOICE=${UFW_CHOICE:-n}
    if [[ "$UFW_CHOICE" == "y" ]]; then
        ufw allow "$SERVER_PORT"
    fi
fi

read -p "Do you want to start the server now? (y/n, default: n): " START_NOW
START_NOW=${START_NOW:-n}
if [[ "$START_NOW" == "y" ]]; then
    ./start.sh
    echo "Server started inside a screen session named $SERVER_NAME."
fi

clear
echo "==== Installation Completed! ===="
echo "Server directory: $SERVER_DIR"
echo "Start with: ./start.sh"
echo "Screen session name: $SERVER_NAME"
echo "RAM: $RAM_AMOUNT"
echo "Port: $SERVER_PORT"
echo "Java version: $JAVA_PATH"
echo "================================="
