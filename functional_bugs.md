# Funktionale Bugs - Minecraft Server Installer

## Kritische Funktionsfehler (Server startet nicht)

### 1. **Fehlende Fehlerbehandlung bei Downloads** 
**Zeilen**: 74-105
**Problem**: Wenn `wget` oder `curl` fehlschlägt, wird trotzdem weitergemacht
```bash
wget -O server.jar "$DOWNLOAD_URL"  # Kann fehlschlagen
# Script läuft weiter, auch wenn server.jar leer/defekt ist
```
**Symptom**: Server startet nicht, weil JAR-Datei fehlt oder defekt ist
**Fix**: Download-Erfolg prüfen

### 2. **SERVER_JAR wird nicht gefunden**
**Zeilen**: 109-114
**Problem**: Nach Installation wird die richtige JAR-Datei nicht erkannt
```bash
# Für Forge:
SERVER_JAR=$(find . -maxdepth 1 -name "forge-*.jar" ! -name "*installer*" | head -n 1)
```
**Symptom**: `start.sh` versucht nicht-existente JAR zu starten
**Fix**: Prüfen ob $SERVER_JAR existiert

### 3. **Java-Path ungültig**
**Zeilen**: 60-61
**Problem**: Wenn Benutzer ungültige Zahl eingibt, wird ungültiger Java-Pfad verwendet
```bash
JAVA_INDEX=$((JAVA_CHOICE-1))  # Kann negativ werden
JAVA_PATH="${JAVA_PATHS[$JAVA_INDEX]}"  # Array out of bounds
```
**Symptom**: Server startet nicht wegen fehlendem Java
**Fix**: Index validieren

## Mittlere Funktionsfehler (Server läuft, aber Probleme)

### 4. **Falsche Minecraft-Version für Paper**
**Zeile**: 104-105
**Problem**: Paper API-URL funktioniert nicht für alle Versionen
```bash
wget -O server.jar "https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION/builds/latest/downloads/paper-$MC_VERSION-latest.jar"
```
**Symptom**: Download schlägt fehl für ältere/neuere Versionen
**Fix**: API-Verfügbarkeit prüfen

### 5. **BungeeCord Download immer "latest"**
**Zeile**: 106-107
**Problem**: BungeeCord wird immer in neuester Version heruntergeladen, ignoriert MC_VERSION
```bash
wget -O server.jar "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"
```
**Symptom**: Version passt nicht zu gewünschter Minecraft-Version

### 6. **Spigot BuildTools kann sehr lange dauern**
**Zeilen**: 100-102
**Problem**: BuildTools kompiliert Spigot, kann 10-30 Minuten dauern
```bash
"$JAVA_PATH" -jar BuildTools.jar --rev "$MC_VERSION"
```
**Symptom**: Benutzer denkt Script ist "hängengeblieben"
**Lösung**: Warnung/Progress-Info anzeigen

## Kleinere Funktionsfehler

### 7. **cd fehlschlägt stillschweigend**
**Zeilen**: 17-19
**Problem**: Wenn `mkdir` fehlschlägt oder Pfad ungültig ist, läuft Script im falschen Verzeichnis
```bash
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"  # Kann fehlschlagen
```
**Symptom**: Dateien werden im falschen Verzeichnis erstellt

### 8. **Screen-Session schon vorhanden**
**Zeilen**: 116-119 (in start.sh)
**Problem**: Wenn Screen-Session bereits existiert, startet Server nicht
```bash
if screen -list | grep -wq "$SERVER_NAME"; then
  echo "Server '$SERVER_NAME' is already running."
  exit 1
fi
```
**Symptom**: Fehlermeldung auch wenn Server eigentlich gestoppt ist

### 9. **Forge/Fabric Installation kann fehlschlagen**
**Zeilen**: 93, 96-98
**Problem**: Installer-JARs werden ausgeführt, aber Erfolg wird nicht geprüft
```bash
"$JAVA_PATH" -jar forge-installer.jar --installServer
```
**Symptom**: Installer läuft durch, aber Server-JAR wird nicht erstellt

## Kompatibilitätsprobleme

### 10. **Veraltete Standard-Versionen**
- Minecraft 1.16.5 (Standard) ist veraltet
- Forge 36.2.42 funktioniert nur mit 1.16.5
- Fabric 0.11.2 ist sehr alt

### 11. **Java-Versions-Kompatibilität**
**Problem**: Keine Prüfung ob gewählte Java-Version mit Minecraft-Version kompatibel ist
- Minecraft 1.17+ braucht Java 16+
- Minecraft 1.18+ braucht Java 17+

## Empfohlene Fixes für funktionale Probleme

### Sofortige Fixes:
1. **Download-Erfolg prüfen**: `wget` Return-Code checken
2. **SERVER_JAR validieren**: Prüfen ob Datei existiert und nicht leer ist
3. **Java-Index validieren**: Sicherstellen dass Auswahl im gültigen Bereich liegt

### Mittelfristige Verbesserungen:
1. **Progress-Anzeigen** für lange Operationen (BuildTools)
2. **Version-Kompatibilität** prüfen
3. **Bessere Standard-Versionen** (aktuellere MC-Version)

### Code-Beispiel für wichtigste Fixes:
```bash
# Download mit Fehlerprüfung:
if ! wget -O server.jar "$DOWNLOAD_URL"; then
    echo "Error: Download failed"
    exit 1
fi

# SERVER_JAR validieren:
if [[ ! -f "$SERVER_JAR" ]] || [[ ! -s "$SERVER_JAR" ]]; then
    echo "Error: Server JAR not found or empty"
    exit 1
fi

# Java-Index validieren:
if [[ $JAVA_CHOICE -lt 1 ]] || [[ $JAVA_CHOICE -gt ${#JAVA_PATHS[@]} ]]; then
    echo "Invalid choice. Please select 1-${#JAVA_PATHS[@]}"
    exit 1
fi
```

Diese Bugs führen zu konkreten Problemen beim Einrichten von Minecraft-Servern!