# RE4 First Person Vanilla — v0.4.0

English edition of v0.4.0. The gameplay behavior and version number are unchanged. Console messages, package filenames and instructions are in English. Ctrl+C confirmation uses Y/N.

One Start.cmd handles Leon and playable Ashley automatically, with no time limit. Del Lago and the Jet-Ski are included; no separate test launcher is needed.

## Requirements

- Resident Evil 4 UHD for Steam, supported x86 executable version 1.0.6.
- HD Project and RE4 Tweaks; tested with RE4 Tweaks 1.9.1.
- Windows PowerShell 5.1 and .NET Framework, included with Windows.

The game location is detected from the running process. No commercial trainer is required. Game files on disk are not modified.

## Start and stop

1. Stop any older mod or test launcher. Extract the entire ZIP into a new writable folder. Do not mix files from different packages or run from inside the ZIP.
2. Open one instance of RE4 and load a saved game with Leon or playable Ashley.
3. Run **Start.cmd**, then return to the game within **15 seconds**. Keep its window open.
4. Play normally. Character, outfit and area changes are handled automatically when the models match a supported profile.
5. Run **Stop.cmd** from the same folder to stop. Alternatively, press **Ctrl+C** in the main window, then **Y** to stop or **N** to keep playing. Wait for the restoration message.

Run only one package at a time. Keep DPF_PL and Free Camera disabled in RE4 Tweaks. Do not run the old standalone camera or model tests alongside this package.

An early stop request during the initial wait may take up to 15 seconds. Exiting RE4 also ends the session. If you force-close the console or terminate its process, restart RE4 before starting another session to ensure all memory changes are cleared.

## Supported behavior

Supports vanilla Leon: jacket, normal outfit, tactical vest, RPD and Mafia. The private custom-skin profile is not included.

Ashley: normal, Special 1 (Popstar) and Special 2 (Armor), with or without her flashlight. Only playable Ashley is hidden. NPC Ashley remains visible, including on the Jet-Ski.

Hands, weapons, knife and flashlight remain visible in normal gameplay. The body and original camera return for supported cutscenes and interactions, including melee, damage and recovery, ladders, pushing furniture, platform jumps, ledge climbing, fence vaults, zip lines, chandelier swings and crank interactions. First person resumes when normal gameplay resumes. Profiles include the additional mesh recorded after the Krauser knife fight.

**Del Lago:** first person while steering, aiming and throwing harpoons, including forced aiming. The body and original camera return for boarding, leaving the boat, falling and swimming back. Inventory is excluded from the vehicle camera adjustment.

**Jet-Ski:** first person while driving and immediately after landing. The body and original camera return during the jump stunt and cutscenes. NPC Ashley stays visible.

## Validation and limitations

The underlying components were tested in game across the recorded Leon/Ashley outfits and interactions. Jet-Ski driving, stunts and the return to first person on landing were validated with the private skin. Vanilla Jet-Ski hand profiles were checked with simulated fixtures; those outfits still need visual verification on the Jet-Ski. The combined v0.4.0 launchers passed profile, character-transition, shutdown/failure and native camera checks; the complete combined package still needs an in-game playthrough. Every animation in the game has not been verified.

Unknown characters or incompatible model sets are left unchanged. If a worker fails, the launcher asks the remaining workers to stop and restore matching data. Two small allocations, 16 KB total, remain in the game process until RE4 exits so pending thread returns can finish safely.

## Included files

- **Start.cmd / Stop.cmd:** start and stop the session.
- **Start.ps1 / Stop.ps1:** session coordination and stop request.
- **Memory.ps1 / ModelWriter.ps1:** memory access helpers.
- **Profiles.ps1 / ModelController.ps1 / HideModels.ps1:** validated model selection and visibility.
- **Camera.cs / CameraWorker.ps1:** normal gameplay camera.
- **VehicleCamera.cs / VehicleCameraWorker.ps1:** Del Lago and Jet-Ski camera.
- **SHA256SUMS.txt:** checksums for the distributed files.

The mod creates local Session-status.json, Character-states.json, Camera-result.json and Vehicle-camera-result.json logs, plus temporary readiness and stop files. These are not included in the ZIP. Do not add personal logs, diagnostic captures or game/skin assets when distributing the vanilla ZIP.

The vehicle camera preserves an existing call redirection only when its checks pass, then restores the previous call on shutdown. RE4 Tweaks configuration files are not changed. Windows-generated errors may follow the language of your Windows installation; the messages supplied by this mod are in English.
