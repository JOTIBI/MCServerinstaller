# Minecraft Java Auto-Installer

This script provides an automated installation process for multiple Java versions on Debian-based Linux systems, optimized for running Minecraft servers.

---

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I3I61SOC0C)

## Features

- Interactive selection of Java versions to install
- Supports Java 8 (manual install), Java 11, 17, 19, and default-jdk from APT
- Auto-detection of missing packages (`curl`, `sudo`, `tar`) and guided installation
- Optional logging of all output to a log file
- Displays currently installed Java versions
- Guides the user through setting default `java` and `javac` versions

## Supported Java Versions

| Option | Java Version | Minecraft Version Range       |
|--------|--------------|-------------------------------|
| 1      | Java 8       | Minecraft 1.8 – 1.16.x        |
| 2      | Java 11      | Minecraft 1.17 – 1.18.x       |
| 3      | Java 17      | Minecraft 1.18.2 – 1.20.4     |
| 4      | Java 19      | Experimental / Snapshots      |
| 5      | Default JDK  | Future Versions (1.21+)       |

## Requirements

- Debian/Ubuntu-based system
- Shell access with `sudo` privileges
- Internet access

## How to Use

1. Download the script: `install_mc_java.sh`
2. Make it executable:
   ```bash
   chmod +x install_mc_java.sh
   ```
3. Run the script:
   ```bash
   ./install_mc_java.sh
   ```
4. Follow the on-screen prompts to select and install Java versions.

## Optional Logging

To log all output to `install_java.log`, run:
```bash
./install_mc_java.sh --log
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
