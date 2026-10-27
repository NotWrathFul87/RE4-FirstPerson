# Security review notes

## Scope of this snapshot

This repository contains the complete source payload of English vanilla v0.4.0 and separate, readable verification/packaging scripts. The private custom-skin edition is not part of this submission. `release.json` and `ORIGINAL-RELEASE-SHA256.txt` identify the local original release archive used to prepare this snapshot.

The mod intentionally changes the memory of the supported running `bio4.exe` process to implement camera hooks and mesh visibility. Those operations should be reviewed directly. Their presence may be relevant to a scanner detection, but no scanner report was supplied here and this document does not assert a particular cause or a clean verdict.

## Operations that warrant inspection

| Operation | Purpose and source |
| --- | --- |
| Process lookup and handle access | Locate one running `bio4` instance and read its module base/path. `HideModels.ps1`, `CameraWorker.ps1`, `VehicleCameraWorker.ps1`; interop in the C# helpers. |
| `ReadProcessMemory` | Read character state, model headers/flags and expected instruction bytes. `Memory.ps1`. |
| `WriteProcessMemory` | Update selected mesh flags and write native wrappers/call patches into the game process. `ModelWriter.ps1`, `Camera.cs`, `VehicleCamera.cs`. |
| `VirtualAllocEx` / `VirtualProtectEx` | Reserve code/data pages and set page protections for camera wrappers and call replacement. Both camera helpers/workers. |
| `OpenThread` / `SuspendThread` / `ResumeThread` | Briefly suspend target game threads while replacing a five-byte call, then resume and close handles. Both camera helpers. |
| `FlushInstructionCache` | Synchronize instruction changes after writing hook code/calls. Both camera helpers. |
| `VirtualQueryEx` | Check the current vehicle-camera call target's memory protection before preserving/chaining it. `VehicleCamera.cs` / `VehicleCameraWorker.ps1`. |
| PowerShell `Add-Type` | Compile the provided C# source and Win32 interop declarations. No external helper binary is fetched. |
| `-ExecutionPolicy Bypass` | Process-scoped launcher option; no persistent policy or registry change is made by the scripts. `Start.cmd` / `Stop.cmd`. |
| Console input | Read the mod console's Ctrl+C confirmation. No system-wide input hook is installed. `Start.ps1`. |

## What the supplied source does not implement

The supplied files contain no network downloader, updater, telemetry endpoint, credential collection, registry persistence, scheduled task, service installation, startup registration, security-software configuration changes or requested elevation. They do not install a driver or redistribute an EXE, ASI, prebuilt DLL, game asset or custom-skin asset.

This statement describes the supplied source, not a promise that process-memory modification will be accepted by every security product. The mod does not request that users disable antivirus protection or add exclusions.

## Source-to-release comparison

1. Verify the submitted archive SHA-256 against `ORIGINAL-RELEASE-SHA256.txt` where possible.
2. Compare every extracted file with `release.json` and `src/SHA256SUMS.txt`.
3. Run the documented local build to reproduce an archive with matching extracted payload files.
4. Inspect the complete native byte emitters in the two `.cs` files and the code that installs/restores them.
5. Treat an in-game runtime test, antivirus analysis and platform approval as separate review activities.

The build and verifier do not access a game process. Their memory self-tests operate only on private allocations in their own PowerShell process; coordinator self-tests use dummy workers. Emitted test wrappers are saved for inspection, not executed by the verifier.

## Platform review

Nexus Mods submission guidelines: https://help.nexusmods.com/article/28-file-submission-guidelines

This repository is provided to support source and behavior inspection. No moderation approval, antivirus clearance, code-signing status or third-party audit is claimed.
