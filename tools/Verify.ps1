param([switch]$SkipRuntimeChecks)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'src'
$release = Get-Content (Join-Path $root 'release.json') -Raw | ConvertFrom-Json
if ($release.version -ne '0.4.0' -or $release.variant -ne 'Vanilla') { throw 'Unexpected release metadata.' }
foreach ($entry in $release.files) {
 if ($entry.name -ne [IO.Path]::GetFileName($entry.name)) { throw 'Invalid manifest path.' }
 $path = Join-Path $source $entry.name
 if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw ('Source checksum mismatch: '+$entry.name) }
}
if (@(Get-ChildItem -LiteralPath $source -File).Count -ne $release.files.Count) { throw 'Unexpected source files.' }
foreach ($file in Get-ChildItem -LiteralPath $source -Filter '*.ps1') {
 $tokens = $null; $errors = $null
 [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
 if ($errors.Count) { throw ($file.Name+': '+($errors|Out-String)) }
}
Write-Output 'Release source checksums and PowerShell syntax verified.'
if ($SkipRuntimeChecks) { return }
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run runtime checks with Windows PowerShell 5.1 (powershell.exe).' }
. (Join-Path $source 'Memory.ps1')
. (Join-Path $source 'ModelWriter.ps1')
if (-not [Re4ModelRead]::SelfTest()) { throw 'Local-process memory read self-test failed.' }
if (-not [Re4ModelWrite]::SelfTest()) { throw 'Local-process memory write/restore self-test failed.' }
Add-Type -Path (Join-Path $source 'Camera.cs')
Add-Type -Path (Join-Path $source 'VehicleCamera.cs')
$normal = [Re4CameraHook]::Build(0x10000000,0x407446,0xC537D4,0xC05F3C,0x10001000)
$vehicle = [Re4BoatCameraHook]::Build(0x10000000,0x405768,0xC537D4,0xC05F3C,0x10001000)
if ($normal.Length -ne 332 -or $vehicle.Length -ne 371) { throw 'Unexpected native wrapper length.' }
$testDirectory = Join-Path $root ('build/verify-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDirectory)
foreach ($entry in $release.files) { [IO.File]::Copy((Join-Path $source $entry.name),(Join-Path $testDirectory $entry.name)) }
[IO.File]::WriteAllBytes((Join-Path $testDirectory 'normal-camera.bin'),$normal)
[IO.File]::WriteAllBytes((Join-Path $testDirectory 'vehicle-camera.bin'),$vehicle)
foreach ($simulateFailure in @($false,$true)) {
 $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $testDirectory 'Start.ps1'),'-SelfTest')
 if ($simulateFailure) { $arguments += '-SimulateFailure' }
 & (Join-Path $PSHOME 'powershell.exe') @arguments
 if ($LASTEXITCODE -ne 0) { throw 'Coordinator self-test failed.' }
 foreach ($worker in @('Models','Camera','Vehicle')) {
  if (-not [IO.File]::Exists((Join-Path $testDirectory ($worker+'.ready.restored')))) { throw ('Missing restoration marker: '+$worker) }
 }
 $state = Get-Content (Join-Path $testDirectory 'Session-status.json') -Raw | ConvertFrom-Json
 if (-not $state.Stopped) { throw 'Coordinator did not stop.' }
 if (-not $simulateFailure -and $state.Error) { throw $state.Error }
 if ($simulateFailure -and -not $state.Error) { throw 'Simulated failure was not recorded.' }
}
Write-Output 'C# compilation, wrapper emission, local-memory checks and coordinator shutdown/failure checks passed.'
Write-Output 'No game process was opened or modified by these self-tests.'
Write-Output ('Verification artifacts: '+$testDirectory)
