# Bug Analysis Report - Minecraft Server Installer

## Overview
Analysis of `install_mc_server.sh` reveals several bugs, security issues, and potential improvements.

## Critical Bugs & Security Issues

### 1. **Shell Command Injection Vulnerability** (HIGH SEVERITY)
**Location**: Lines 74-75, 91-93, 96-98, 100-102, 104-105, 118-120
**Issue**: User input is directly used in shell commands without proper validation or escaping.

```bash
# Vulnerable examples:
curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg MC_VERSION "$MC_VERSION" '.versions[] | select(.id==$MC_VERSION) | .url'
wget -O forge-installer.jar "https://maven.minecraftforge.net/net/minecraftforge/forge/$MC_VERSION-$INSTALLER_VERSION/forge-$MC_VERSION-$INSTALLER_VERSION-installer.jar"
```

**Risk**: Malicious input could execute arbitrary commands.
**Fix**: Validate and sanitize all user inputs, use parameter expansion safely.

### 2. **Missing Error Handling** (MEDIUM SEVERITY)
**Location**: Throughout the script
**Issue**: Commands like `wget`, `curl`, `jq` can fail silently.

```bash
# No error checking:
wget -O server.jar "$DOWNLOAD_URL"
"$JAVA_PATH" -jar forge-installer.jar --installServer
```

**Risk**: Script continues execution even if critical downloads fail.
**Fix**: Add error checking after each critical command.

### 3. **Unsafe Directory Creation and Navigation** (MEDIUM SEVERITY)
**Location**: Lines 17-19
**Issue**: 
```bash
SERVER_DIR="$SERVER_PATH/$SERVER_NAME"
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"
```

**Risk**: If `mkdir` fails or directory contains special characters, `cd` could fail or navigate to wrong location.
**Fix**: Check return codes and validate paths.

### 4. **Improper Array Handling** (MEDIUM SEVERITY)
**Location**: Lines 47-48, 60-61
**Issue**: Array access without bounds checking.

```bash
JAVA_PATH="${JAVA_PATHS[$JAVA_INDEX]}"
if [[ -z "${JAVA_PATHS[$JAVA_INDEX]}" ]]; then
```

**Risk**: Array index out of bounds if user enters invalid number.
**Fix**: Validate array index before access.

### 5. **File Overwriting Without Warning** (LOW-MEDIUM SEVERITY)
**Location**: Lines 107, 109-118
**Issue**: Files like `eula.txt` and `start.sh` are overwritten without checking if they exist.

**Risk**: Loss of existing configuration.
**Fix**: Check for existing files and prompt user.

## Logic Bugs

### 6. **Inconsistent Server JAR Detection** (MEDIUM SEVERITY)
**Location**: Lines 109-114
**Issue**: Complex file finding logic that may not work correctly in all cases.

```bash
if [[ "$SERVER_TYPE" == "2" ]]; then
  SERVER_JAR=$(find . -maxdepth 1 -name "forge-*.jar" ! -name "*installer*" | head -n 1)
elif [[ "$SERVER_TYPE" == "3" ]]; then
  SERVER_JAR=$(find . -maxdepth 1 -name "fabric-server-launch.jar" | head -n 1)
else
  SERVER_JAR=$(find . -maxdepth 1 -name "*.jar" ! -name "*installer*.jar" ! -name "BuildTools.jar" | head -n 1)
fi
```

**Risk**: Wrong JAR file selected or no file found.
**Fix**: Verify the found file exists and is valid.

### 7. **Missing Validation for External Dependencies** (MEDIUM SEVERITY)
**Location**: Lines 74-105
**Issue**: No validation that external URLs/APIs are accessible or return valid data.

**Risk**: Script fails if external services are down or return unexpected data.
**Fix**: Add connectivity checks and response validation.

### 8. **Race Condition in Screen Session Check** (LOW SEVERITY)
**Location**: Lines 116-119 (in generated start.sh)
**Issue**: Screen session check and creation are not atomic.

**Risk**: Two instances could start simultaneously.
**Fix**: Use file locking or more robust session management.

## Code Quality Issues

### 9. **Inconsistent Error Handling**
- Some commands have error checking, others don't
- Exit codes not consistently used

### 10. **Hard-coded Defaults**
- Default versions may become outdated
- No validation of version compatibility

### 11. **Missing Input Validation**
- No validation of RAM amount format
- No validation of port numbers (1-65535)
- No validation of version strings

### 12. **Poor Resource Management**
- No cleanup on failure
- Temporary files not removed

## Recommendations

### Immediate Fixes (High Priority)
1. **Input Sanitization**: Validate all user inputs with regex patterns
2. **Error Handling**: Add `set -e` and check return codes
3. **Path Safety**: Use absolute paths and validate directory operations

### Medium Priority Fixes
1. **Dependency Checks**: Verify required tools are installed before use
2. **Network Validation**: Check connectivity to external services
3. **File Existence Checks**: Prompt before overwriting existing files

### Long-term Improvements
1. **Configuration File**: Support config files instead of interactive prompts
2. **Logging**: Add proper logging throughout the script
3. **Rollback Capability**: Allow reverting failed installations
4. **Version Compatibility Matrix**: Validate version combinations

## Security Best Practices Violations

1. **No input sanitization**
2. **Direct shell command execution with user input**
3. **Downloads over HTTP without integrity verification**
4. **No checksum validation for downloaded files**
5. **Automatic execution of downloaded files**

## Conclusion

The script has several critical security vulnerabilities and logic bugs that should be addressed before production use. The most critical issue is the shell command injection vulnerability that could allow arbitrary code execution.