# RE4 First Person — Vanilla v0.4.0 (English)

Source snapshot for the public vanilla release by **WrathFul87**.

- Nexus Mods page: https://www.nexusmods.com/residentevil4/mods/940
- Intended source repository: https://github.com/NotWrathFul87/RE4-FirstPerson
- Version: **0.4.0**; edition: **English**; profile set: **Vanilla**.

## For reviewers

The complete shipped source is in [`src/`](src/). These 15 files were extracted directly from `RE4-FirstPerson-Vanilla-v0.4.0-English.zip`, without edits. `release.json` lists each file and its SHA-256. The original archive hash is in `ORIGINAL-RELEASE-SHA256.txt`.

This is a PowerShell-based mod, not a precompiled executable application. Windows PowerShell interprets the scripts and compiles the included C# helpers through `Add-Type` at startup. The native x86 camera wrappers are emitted by the `Build` methods in `Camera.cs` and `VehicleCamera.cs`; their instruction bytes and control flow are visible in those source files.

There is no separate EXE, ASI or prebuilt DLL to compile. `Build.ps1` verifies the source, runs local self-tests, and packages the exact release payload.

## Build and verify

On Windows, from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1
```

Output: `dist/RE4-FirstPerson-Vanilla-v0.4.0-English.zip`.

Use **Windows PowerShell 5.1**, not PowerShell 7, for the tested build path. The required .NET assemblies and compiler are supplied by Windows/.NET Framework. No downloads, package manager, external compiler or game installation are needed for the build and local self-tests.

See [BUILD.md](docs/BUILD.md) for the complete workflow, [TECHNICAL.md](docs/TECHNICAL.md) for implementation details, and [SECURITY-REVIEW.md](docs/SECURITY-REVIEW.md) for memory operations and review scope.

## Original release identity

```text
3820ec94d8f7ed465da2818ba9cabf4988793ed28e0603c9457a46e4a50b2983  RE4-FirstPerson-Vanilla-v0.4.0-English.zip
```

A rebuilt ZIP can have a different archive hash due to compression and metadata. The extracted payload files must match every hash in `release.json` and the original `src/SHA256SUMS.txt` manifest. The build checks this automatically.

## Running the mod

Running requires the supported RE4 UHD Steam x86 1.0.6 executable, HD Project and RE4 Tweaks (tested with 1.9.1). Extract the built ZIP, load a saved game, then run `Start.cmd`. Use `Stop.cmd`, or Ctrl+C followed by Y in the main console, to stop. See [`src/README.md`](src/README.md) for full player instructions and limitations.

Build/self-test checks do not install hooks in a game process. Do not confuse those checks with an in-game compatibility test.

## Repository contents

- `src/`: complete, unchanged release payload, including all PowerShell and C# source.
- `Build.ps1`: validation and release packaging.
- `tools/Verify.ps1`: checksums, parsing, C# compilation, native wrapper emission and local self-tests.
- `release.json`: release identity and per-file hashes.
- `docs/`: build instructions and technical/security review notes.
- `.gitattributes`: disables Git line-ending conversion so release file hashes are preserved.
- `.gitignore`: excludes build outputs and runtime logs.

This source snapshot is for the public vanilla edition. It contains no custom skin files, private skin profile, game executable, game assets, credentials or diagnostic memory captures. It is a release snapshot, not a reconstructed development history.
