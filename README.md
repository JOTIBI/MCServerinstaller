# Minecraft Server Installer

**Created by JOTIBI**

A user-friendly bash script to quickly and reliably set up Minecraft servers.

## Supported Server Types
- Vanilla
- Forge
- Fabric
- Spigot
- Paper
- BungeeCord

## Features
- Interactive installation with clear instructions
- Supports multiple server types and Minecraft versions
- Automatically downloads and sets up server files
- Detects installed Java versions and allows selection
- Generates a start script with screen support for easy management
- Optionally opens the necessary firewall port (UFW)
- Designed for simplicity, speed, and flexibility

## Requirements
- A Linux system with bash
- Installed tools: `wget`, `curl`, `jq`, `screen`
- One or more Java versions installed (Java 8, 11, 17, 19, or newer)

## Installation
1. Download the script to your server.
2. Make the script executable:
```bash
chmod +x install_mc_server.sh
```
3. Run the script:
```bash
./install_mc_server.sh
```
4. Follow the interactive prompts to configure and set up your server.

## Notes
- Compatible with a wide range of Minecraft versions and server types.
- Supports parallel installation of multiple servers.

## License
This project is licensed under the CC BY-NC 4.0 License.

---
