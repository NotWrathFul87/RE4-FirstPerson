# Build and verification instructions

## 1. Obtain the source

Clone this repository, or download and extract its source ZIP. Open a terminal in the repository root, where `Build.ps1`, `release.json` and `src/` are located.

Do not edit or re-save files under `src/` before verification: text encoding, BOM and line endings are part of the original file hashes. Git line-ending conversion is disabled by `.gitattributes`.

## 2. Requirements

- Windows with Windows PowerShell 5.1 (`powershell.exe`, Desktop edition).
- .NET Framework and the compiler used by PowerShell `Add-Type`.
- Permission to write to the checkout's `build/` and `dist/` folders.

No game files, Steam account, administrator elevation, Visual Studio, package manager, downloaded dependency or network connection is required to build or run the local self-tests. If a machine policy restricts script execution, follow the review environment's policy; the command below does not alter the machine-wide execution policy.

## 3. Run the build

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1
```

The process-scoped `-ExecutionPolicy Bypass` option matches the launcher convention. It applies only to that PowerShell invocation; the scripts do not call `Set-ExecutionPolicy` or change registry policy settings.

The build performs these steps:

1. Checks all 15 source-file SHA-256 hashes against `release.json`.
2. Parses every PowerShell source file and rejects syntax errors.
3. Compiles `Camera.cs` and `VehicleCamera.cs` using `Add-Type`.
4. Emits the 332-byte normal camera wrapper and 371-byte vehicle wrapper at fixed test addresses for inspection. These bytes are not executed by the verifier.
5. Tests memory reading, writing and restoration on allocations in the verifier's own PowerShell process.
6. Copies the release payload into a temporary test directory under `build/`, then runs the coordinator's `-SelfTest` and `-SelfTest -SimulateFailure` paths in child Windows PowerShell processes. These paths substitute dummy workers for the actual game workers.
7. Checks all three workers' restoration markers and session status.
8. Writes the distributable ZIP under `dist/` and verifies every archived payload file against the original source manifest.

Expected final messages include:

```text
Every extracted file matches the original English vanilla v0.4.0 release.
ZIP compression metadata may differ; compare extracted-file hashes rather than the rebuilt ZIP hash.
```

An optional output directory can be supplied:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1 -OutputDirectory .\dist-review
```

The build overwrites a ZIP of the same name in the selected output directory. It does not remove directories recursively. Test artifacts remain under `build/verify-<unique-id>/` for inspection and are excluded from Git.

## 4. Verify without packaging

Full local checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Verify.ps1
```

Checksums and syntax only, without compiling or performing local-memory self-tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Verify.ps1 -SkipRuntimeChecks
```

## 5. Compare the originally submitted file

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath .\RE4-FirstPerson-Vanilla-v0.4.0-English.zip
```

Compare with `ORIGINAL-RELEASE-SHA256.txt`. A different original archive hash means the submitted ZIP is not byte-for-byte the same archive identified here. If files were repackaged, compare extracted files against `release.json`; do not assume two ZIPs match simply because their filenames match.

## 6. Runtime compilation

There is no prebuilt application binary in the release. `Start.ps1` loads `Memory.ps1` and `ModelWriter.ps1`, whose C# interop helpers are supplied as readable source in those scripts. It then compiles `Camera.cs` and `VehicleCamera.cs`. Workers use those classes to emit and install the camera wrappers in the running game. The standard .NET compilation process may use compiler temporary files; no compiler or external binary is downloaded by the mod.

The ZIP contains the same 15 source/documentation files as the original release. Build tools, emitted test `.bin` files and verification logs are not added to the game release ZIP.

## 7. In-game verification is separate

For an in-game test, use the supported RE4 UHD Steam 1.0.6 x86 executable with HD Project and RE4 Tweaks. Stop other mod instances, load a game, then launch the extracted `Start.cmd`. Exit through `Stop.cmd` or Ctrl+C/Y, and observe the restoration messages. Restart RE4 after forcibly terminating the mod console.

The local build checks establish source identity and basic component behavior; they are not an antivirus verdict, moderation approval or proof that every game animation has been tested.
