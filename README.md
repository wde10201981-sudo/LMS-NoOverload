# LMS NoOverload and Wide Cut

Unofficial Windows Steam patch for Lawn Mowing Simulator.

## Features

- No-overload v2 behavior for mowing thick grass.
- 4x cutting footprint with flower protection.
- Rollback to 2x cutting or the original game DLL.

Expansion applies horizontally across and along the mower; the deck model stays the same. Flower protection guards finable or petalled mowable objects, not general collisions. Completion requirements are unchanged.

## Install

Close the game. Download and extract this repository, then open PowerShell in the folder containing NoOverload.ps1 and patch.json. Keep these files from the same version together.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\NoOverload.ps1 -Action Install
```

Launch normally through Steam. Default game location:

```text
C:\Program Files (x86)\Steam\steamapps\common\Lawn Mowing Simulator
```

For a custom location, append `-GamePath 'D:\SteamLibrary\steamapps\common\Lawn Mowing Simulator'` to each command.

If access is denied, reopen PowerShell as administrator. ExecutionPolicy Bypass applies to this process only.

## Status and rollback

Close the game before making changes.

```powershell
# Check version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\NoOverload.ps1 -Action Status

# Restore 2x cutting, no-overload and flower protection
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\NoOverload.ps1 -Action RevertToV3

# Remove all these patches
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\NoOverload.ps1 -Action Restore
```

## Compatibility

The root installer supports the exact original game build identified by hashes in patch.json, installed v3, and already-installed v4. Unknown DLLs are rejected.

If v2 is installed, first run Install using the matching files in versions/v3, then use the root installer. Older installers do not recognize newer patches; use the root rollback commands first.

Keep the verified backup beside the game DLL:

```text
GameAssembly.dll.lms-no-overload.original.bak
```

Steam updates or file verification may replace the patched DLL. This installer changes GameAssembly.dll, not saves or assets. This repository contains patch instructions only; supply your own game installation.

## Validation

v2 and v3 were confirmed working in-game by the original tester. A reported v3 completion stall was resolved by finding an overlooked portion of the yard.

v4 passed static byte/hash, executable bounds, and upgrade/rollback checks. In-game confirmation of v4 is not yet recorded. The installer was not executed in PowerShell in the development environment.

For issues, include Status output, patch version, mower model, and reproduction steps. Do not post game binaries or personal saves in public issues.
