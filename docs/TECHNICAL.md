# Technical overview

## Entry points and lifecycle

`Start.cmd` invokes Windows PowerShell with `-NoProfile -ExecutionPolicy Bypass -File Start.ps1`. `Start.ps1` coordinates three PowerShell runspace workers: `HideModels.ps1`, `CameraWorker.ps1`, and `VehicleCameraWorker.ps1`.

A named mutex prevents overlapping main sessions, including the earlier language edition. Readiness files indicate initialization. `Stop.cmd` invokes `Stop.ps1`, which creates a stop signal in the package directory. The coordinator also supports a console-local Ctrl+C Y/N prompt. It requests restoration from all workers if a worker ends or fails. Abrupt process termination can prevent cleanup; restarting the game clears process-memory changes.

## Model visibility

`Memory.ps1` supplies read-only Win32 process access. `ModelWriter.ps1` supplies checked mesh-flag writes. `Profiles.ps1` identifies complete known sets using header signatures (bone, material and vertex counts), including supported hand variants and the additional mesh recorded after the Krauser knife fight.

`HideModels.ps1` reads the controlled player's pointer and character identifier. It enumerates the controlled player's model list, not NPC Ashley's pointer. `ModelController.ps1` tracks validated model identity and sets/clears the drawing flag bit `0x8` at the relevant model-info flag field, preserving other bits. Original flag values and model identity are retained for restoration.

Recognized body/head meshes are hidden during gameplay while hands and held objects remain visible. The controller restores the supported body meshes during recorded interactions, damage/recovery and cutscenes. Unsupported or changed model sets cause it to stop applying the profile and wait. Ashley's visibility is changed only when she is the controlled character.

## Normal gameplay camera

`Camera.cs` contains both the C# Win32 interop and an explicit byte-emitter for an x86 wrapper. `CameraWorker.ps1` validates the supported call site at module-relative offset `0x19E141`, reserves code/data memory in the game, prepares the wrapper and redirects a five-byte call.

The wrapper calls the original camera function, checks the controlled character and enabled profile, then adjusts the local camera point during allowed gameplay states. It translates the target by the same offset to preserve viewing direction. Height is 1765 for Leon and 1600 for playable Ashley. Recorded interaction and cutscene states are excluded.

## Del Lago and Jet-Ski camera

`VehicleCamera.cs` emits a second x86 wrapper. `VehicleCameraWorker.ps1` validates the vehicle camera call at module-relative offset `0x19F4B2`. This later camera stage is used because the special vehicle path replaces the normal gameplay camera output.

The worker selects Del Lago or Jet-Ski mode using validated model state shared with the model controller. The wrapper requires the supported controlled character, boat state and allowed routine values, and excludes inventory/cutscene/event flags. Del Lago mode handles steering and harpoon states, including forced aiming. Jet-Ski mode handles driving and the phase immediately after landing, while the jump stunt and cutscenes retain the original camera. NPC Ashley is not enumerated or hidden.

At these allowed states, the camera position is based on the controlled player's position plus the configured height; the target receives the same displacement. Game-specific flags and routines are compatibility assumptions for the recorded executable/version, not universal offsets for every RE4 release.

## Installing and restoring calls

Both helpers use `VirtualAllocEx`, `VirtualProtectEx`, `WriteProcessMemory`, `FlushInstructionCache`, and brief target-thread suspension/resumption to replace a five-byte call. Code and data use separate pages; prepared code pages are made executable/readable. Native instruction bytes are emitted by readable `Build` methods, not loaded from a hidden binary.

The normal camera worker checks the original instruction bytes. The vehicle worker can chain a pre-existing redirection after checking the unchanged prefix, call opcode, readable target and executable target protection. It retains and restores the call that was present before installation. These checks are visible in `VehicleCameraWorker.ps1`; they do not establish trust in arbitrary third-party software.

Workers disable their wrappers, restore matching call bytes/mesh flags, and close handles during cooperative shutdown. Two 8 KB allocations are retained until RE4 exits so a thread can finish returning through a wrapper. Nothing is patched into the executable on disk.

## Local records

The release writes session status, character-state and camera-result JSON logs, plus readiness/stop files, in its own directory. `build/` and `dist/` belong to repository verification/packaging only. The source release includes no process-memory diagnostic captures or game assets.
