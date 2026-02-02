# Minecraft Server Auto-Installer
A **fully automated Bash script** for installing, starting, and managing Minecraft servers on Linux.
---

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I3I61SOC0C)

## Table of Contents
- Overview
- Features
- Supported Server Types
- Requirements
- Installation
- Start & Usage
- Java Selection & Recommendation
- Fabric Logic (important)
- Debug Mode
- Uninstaller
- Directory Structure
- Common Errors & Solutions
- Production Notes
---
## Overview
This script installs Minecraft servers **interactively** and always starts them inside a `screen` seYou choose:
- Server type
- Minecraft version
- RAM & port
- **specific Java version** the server should use
The script **does not modify your system Java**, but stores the selected Java binary locally per serv---
## Features
- ■ Server types:
 - Vanilla
 - Forge
 - Fabric
 - Spigot
 - Paper
 - Bungeecord
- ■ Automatic installation of all requirements (`apt`)
- ■ Server always runs inside `screen`
- ■ Selection of an installed Java version (`update-alternatives`)
- ■ Java recommendation matching the Minecraft version
- ■ `--debug` mode with clean script logging
- ■ `--uninstall` mode (including screen session cleanup)
- ■ No Python
- ■ No hardcoded Java
- ■ No broken JSON parsing
---
## Supported Server Types
| Type | Source / Method |
|------------|-----------------|
| Vanilla | Mojang version manifest |
| Forge | Official Forge installer (`--installServer`) |
| Fabric | Fabric Meta API (loader + installer) |
| Spigot | BuildTools (legally compliant) |
| Paper | PaperMC REST API |
| Bungeecord | Official BungeeCord artifact |
---
## Requirements
### Operating System
- Debian / Ubuntu
- Root or sudo privileges
### Automatically installed:
- `curl`
- `jq`
- `screen`
- `ca-certificates`
- `default-jre`
- additionally depending on type:
 - Spigot → `git`, `default-jdk`
 - Forge → `default-jdk`
You do **not** need to prepare anything manually.
---
## Installation
```bash
chmod +x mc-installer.sh
./mc-installer.sh
```
## License
Copyright (c) 2026 JOTIBI

Permission is hereby granted to use this software on any Minecraft server
(private or public) and within modpacks.

The following conditions apply:

1. This software may NOT be sold, sublicensed, or monetized in any way,
   either alone or as part of a bundle.
2. Modification of the software is permitted for own server operation,
   including public servers.
3. Modified versions may NOT be published, distributed, uploaded, or
   shared in any form.
4. Redistribution of the original software is NOT permitted.
5. When this software is used in modpacks, visible credit to the original
   author must be provided (e.g. in the modpack listing, description,
   or a README file).
6. This copyright and license notice must not be removed or altered.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED.
