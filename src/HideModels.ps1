param([switch]$Continuous,[switch]$RestoreDuringEvents,[switch]$RestoreMeleeExperimental,[switch]$FollowAreas,[string]$StopFile,[string]$ReadyFile)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Memory.ps1')
. (Join-Path $PSScriptRoot 'ModelWriter.ps1')
. (Join-Path $PSScriptRoot 'Profiles.ps1')
. (Join-Path $PSScriptRoot 'ModelController.ps1')
$games=@(Get-Process bio4 -ErrorAction SilentlyContinue)
if($games.Count-ne 1){throw 'Load a saved game in a single instance of RE4.'}
$game=$games[0];$base=$game.MainModule.BaseAddress.ToInt64()
$handle=[Re4ModelWrite]::OpenProcess(0x438,$false,$game.Id)
if($handle-eq [IntPtr]::Zero){throw 'Could not open RE4 for model control.'}
$context=New-ModelContext
function Read-ModelFlags([long]$Info){
 $b=[Re4ModelRead]::Read($handle,$Info,24)
 if($null-eq $b){return $null}
 return [pscustomobject]@{Data=[long][BitConverter]::ToUInt32($b,12);Flag=[BitConverter]::ToUInt32($b,4)}
}
function Write-ModelFlag([long]$Info,[uint32]$Flag){
 if(-not [Re4ModelWrite]::WriteFlag($handle,$Info+4,$Flag)){throw 'Could not update a mesh.'}
}
function Read-Snapshot {
 $gp=[Re4ModelRead]::Read($handle,$base+0x805F3C,4);$pp=[Re4ModelRead]::Read($handle,$base+0x8537D4,4)
 if($null-eq $gp-or $null-eq $pp){return $null}
 $global=[long][BitConverter]::ToUInt32($gp,0);$player=[long][BitConverter]::ToUInt32($pp,0)
 $character=[Re4ModelRead]::Read($handle,$global+0x4FC8,1)
 if($null-eq $character-or $character.Length-ne 1){return $null}
 $role=Get-ControlledRole $character[0]
 if($role-lt 0){return $null}
 $status=[Re4ModelRead]::Read($handle,$global+0x501C,8)
 $routine=[Re4ModelRead]::Read($handle,$player+0xFC,4)
 $first=[Re4ModelRead]::Read($handle,$player+0x15C,4)
 if($null-eq $status-or $null-eq $routine-or $null-eq $first){return $null}
 $info=[long][BitConverter]::ToUInt32($first,0)
 $entries=[Collections.Generic.List[object]]::new();$visited=[Collections.Generic.HashSet[long]]::new()
 while($info-ge 0x10000){
  if($entries.Count-ge 16-or -not $visited.Add($info)){return $null}
  $b=[Re4ModelRead]::Read($handle,$info,24)
  if($null-eq $b){return $null}
  $data=[long][BitConverter]::ToUInt32($b,12)
  $header=[Re4ModelRead]::Read($handle,$data,80)
  if($null-eq $header){return $null}
  $entries.Add([pscustomobject]@{Info=('{0:X8}' -f $info);Data=('{0:X8}' -f $data);Header=[BitConverter]::ToString($header)})
  $info=[long][BitConverter]::ToUInt32($b,20)
 }
 $snapshot=[pscustomobject]@{Role=$role;Player=$player;First=[BitConverter]::ToUInt32($first,0);Routine=$routine;Status=[BitConverter]::ToUInt32($status,0);Status2=[BitConverter]::ToUInt32($status,4);Entries=$entries.ToArray()}
 if(-not (Test-SnapshotCurrent $snapshot)){return $null}
 return $snapshot
}
function Test-SnapshotCurrent($Snapshot){
 $gp=[Re4ModelRead]::Read($handle,$base+0x805F3C,4);$pp=[Re4ModelRead]::Read($handle,$base+0x8537D4,4)
 if($null-eq $gp-or $null-eq $pp-or [BitConverter]::ToUInt32($pp,0)-ne $Snapshot.Player){return $false}
 $character=[Re4ModelRead]::Read($handle,[BitConverter]::ToUInt32($gp,0)+0x4FC8,1)
 if($null-eq $character-or (Get-ControlledRole $character[0])-ne $Snapshot.Role){return $false}
 $first=[Re4ModelRead]::Read($handle,$Snapshot.Player+0x15C,4)
 return $null-ne $first-and [BitConverter]::ToUInt32($first,0)-eq $Snapshot.First
}
try{
 $signature=[Re4ModelRead]::Read($handle,$base+0x33E4A6,7)
 if($null-eq $signature-or [BitConverter]::ToString($signature)-ne 'F7-40-58-00-00-00-40'){throw 'Unsupported game version.'}
 while(-not $game.HasExited){
  if($StopFile-and [IO.File]::Exists($StopFile)){break}
  Update-ModelContext $context (Read-Snapshot)
  [Re4SessionState]::JetSkiReady=($context.Role-eq 0-and $null-ne $context.Binding-and $context.Binding.IsJetSki)
  [Re4SessionState]::BodyRole=$context.Role
  if($context.Role-ge 0-and $ReadyFile-and -not [IO.File]::Exists($ReadyFile)){[IO.File]::WriteAllText($ReadyFile,'ready')}
  Start-Sleep -Milliseconds 50
 }
}finally{
 [Re4SessionState]::JetSkiReady=$false
 [Re4SessionState]::BodyRole=-1
 try{Restore-ModelBinding $context.Binding}
 finally{
  [void][Re4ModelRead]::CloseHandle($handle)
  $context.Log.ToArray()|ConvertTo-Json -Depth 4|Set-Content (Join-Path $PSScriptRoot 'Character-states.json') -Encoding UTF8
 }
}
Write-Output 'Model hiding stopped; matching meshes were restored.'
