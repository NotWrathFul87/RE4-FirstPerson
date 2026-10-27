param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot 'dist' }
& (Join-Path $PSScriptRoot 'tools/Verify.ps1')
$release = Get-Content (Join-Path $PSScriptRoot 'release.json') -Raw | ConvertFrom-Json
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$output = Join-Path $OutputDirectory $release.releaseArchive
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($output,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
 $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
 try {
  foreach ($entry in $release.files) {
   $name = $release.releaseFolder+'/'+$entry.name
   $file = Join-Path (Join-Path $PSScriptRoot 'src') $entry.name
   [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file,$name,[IO.Compression.CompressionLevel]::Optimal)
  }
 } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead($output)
try {
 if ($zip.Entries.Count -ne $release.files.Count) { throw 'Built archive file count mismatch.' }
 foreach ($entry in $release.files) {
  $item = $zip.GetEntry($release.releaseFolder+'/'+$entry.name)
  if ($null -eq $item) { throw ('Missing built file: '+$entry.name) }
  $inputStream = $item.Open(); $sha = [Security.Cryptography.SHA256]::Create()
  try { $actual = ([BitConverter]::ToString($sha.ComputeHash($inputStream))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose(); $inputStream.Dispose() }
  if ($actual -ne $entry.sha256) { throw ('Built payload checksum mismatch: '+$entry.name) }
 }
} finally { $zip.Dispose() }
Write-Output ('Built and verified: '+$output)
Write-Output ('Archive SHA-256: '+(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant())
Write-Output 'Every extracted file matches the original English vanilla v0.4.0 release.'
Write-Output 'ZIP compression metadata may differ; compare extracted-file hashes rather than the rebuilt ZIP hash.'
