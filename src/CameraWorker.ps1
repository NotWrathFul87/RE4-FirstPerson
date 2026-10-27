param([string]$StopFile,[string]$ReadyFile)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Memory.ps1')
if(-not ('Re4CameraHook' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'Camera.cs')}
$games=@(Get-Process bio4 -ErrorAction SilentlyContinue)
if($games.Count-ne 1){throw 'Load an RE4 saved game before starting the mod.'}
$game=$games[0];$path=$game.Path;$base=$game.MainModule.BaseAddress.ToInt64()
$exe=[IO.File]::ReadAllBytes($path);$pe=[BitConverter]::ToInt32($exe,60)
if([BitConverter]::ToUInt16($exe,$pe+4)-ne 0x14c){throw 'The game executable is not x86.'}
$optional=$pe+24;$preferred=[BitConverter]::ToUInt32($exe,$optional+28)
$sections=$pe+24+[BitConverter]::ToUInt16($exe,$pe+20)
$callSites=[Collections.Generic.List[object]]::new()
$pattern='\x52\x8D\x85.{4}\x50\x8D\x4D.\x51\x8B\xCB\xE8'
for($section=0;$section-lt [BitConverter]::ToUInt16($exe,$pe+6);$section++){
 $at=$sections+40*$section
 if(([BitConverter]::ToUInt32($exe,$at+36)-band 0x20000000)-eq 0){continue}
 $rva=[BitConverter]::ToUInt32($exe,$at+12);$raw=[BitConverter]::ToUInt32($exe,$at+20);$length=[BitConverter]::ToUInt32($exe,$at+16)
 $text=[Text.Encoding]::GetEncoding(28591).GetString($exe,$raw,$length)
 foreach($match in [regex]::Matches($text,$pattern,[Text.RegularExpressions.RegexOptions]::Singleline)){
  $callSites.Add([pscustomobject]@{Rva=$rva+$match.Index+14;FileOffset=$raw+$match.Index+14})
 }
}
if($callSites.Count-ne 1){throw 'A unique camera call could not be found.'}
$site=$callSites[0];$callAddress=$base+$site.Rva
if($site.Rva-ne 0x19E141){throw 'The camera function does not match the supported game version. Nothing was changed.'}
$expected=[byte[]]$exe[($site.FileOffset-14)..($site.FileOffset+4)]
$originalCall=[byte[]]$exe[$site.FileOffset..($site.FileOffset+4)]
$originalTarget=$callAddress+5+[BitConverter]::ToInt32($originalCall,1)
if($originalTarget-lt $base -or $originalTarget-ge $base+[BitConverter]::ToUInt32($exe,$optional+56)){throw 'The original call target is outside the game module.'}
$mutex=[Threading.Mutex]::new($false,'Local\RE4PruebaCamaraFotograma')
$owns=$false;$handle=[IntPtr]::Zero;$allocation=[IntPtr]::Zero;$installed=$false;$patch=$null;$dataAddress=0
$log=[ordered]@{CallRva=('{0:X8}' -f $site.Rva);OriginalTarget=('{0:X8}' -f $originalTarget);Installed=$false;AdjustedFrames=0;Restored=$false;Error=$null}
try{
 try{$owns=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owns=$true}
 if(-not $owns){throw 'This camera worker is already running.'}
 $handle=[Re4CameraHook]::OpenProcess(0x438,$false,$game.Id)
 if($handle-eq [IntPtr]::Zero){throw 'Could not open RE4 for camera control.'}
 $live=[Re4ModelRead]::Read($handle,$callAddress-14,19)
 if(-not $live -or [BitConverter]::ToString($live)-ne [BitConverter]::ToString($expected)){throw 'The camera call is already modified or does not match. The component was not installed.'}
 $playerPointer=[Re4ModelRead]::Read($handle,$base+0x8537d4,4)
 if(-not $playerPointer -or [BitConverter]::ToUInt32($playerPointer,0)-lt 0x10000){throw 'No saved game is currently loaded.'}
 $allocation=[Re4CameraHook]::VirtualAllocEx($handle,[IntPtr]::Zero,[UIntPtr]::new(8192),0x3000,4)
 if($allocation-eq [IntPtr]::Zero -or $allocation.ToInt64()-gt [long]4294959103){throw 'Could not allocate x86 memory.'}
 $codeAddress=$allocation.ToInt64();$dataAddress=$codeAddress+4096
 $code=[Re4CameraHook]::Build([uint32]$codeAddress,[uint32]$originalTarget,[uint32]($base+0x8537d4),[uint32]($base+0x805f3c),[uint32]$dataAddress)
 $data=New-Object byte[] 32
 [BitConverter]::GetBytes([single]1765).CopyTo($data,20)
 [BitConverter]::GetBytes([single]1600).CopyTo($data,28)
 if(-not [Re4CameraHook]::Write($handle,$codeAddress,$code)-or -not [Re4CameraHook]::Write($handle,$dataAddress,$data)){throw 'Could not prepare the camera component.'}
 $previous=[uint32]0
 if(-not [Re4CameraHook]::VirtualProtectEx($handle,$allocation,[UIntPtr]::new(4096),0x20,[ref]$previous)){throw 'Could not enable the camera code.'}
 if(-not [Re4CameraHook]::FlushInstructionCache($handle,$allocation,[UIntPtr]::new($code.Length))){throw 'Could not flush the instruction cache.'}

 $live=[Re4ModelRead]::Read($handle,$callAddress,5)
 if(-not $live -or [BitConverter]::ToString($live)-ne [BitConverter]::ToString($originalCall)){throw 'The call changed during setup. The camera component was not installed.'}
 $patch=[Re4CameraHook]::Call([uint32]$callAddress,[uint32]$codeAddress)
 [Re4CameraHook]::ReplaceCall($handle,$game.Id,$callAddress,$patch)
 $installed=$true;$log.Installed=$true
 $lastRole=-2
 if($ReadyFile){[IO.File]::WriteAllText($ReadyFile,'ready')}
 while(-not $game.HasExited){
  if($StopFile -and [IO.File]::Exists($StopFile)){break}
  $role=if([Re4SessionState]::JetSkiReady){-1}else{[Re4SessionState]::BodyRole}
  if($role-ne $lastRole){
   if(-not [Re4CameraHook]::Write($handle,$dataAddress,[byte[]](0,0,0,0))){throw 'Could not suspend the camera.'}
   if($role-in @(0,1)){
    if(-not [Re4CameraHook]::Write($handle,$dataAddress+8,[BitConverter]::GetBytes([int]$role))){throw 'Could not select the camera.'}
    if(-not [Re4CameraHook]::Write($handle,$dataAddress,[byte[]](1,0,0,0))){throw 'Could not enable the camera.'}
   }
   $lastRole=$role
  }
  Start-Sleep -Milliseconds 50
 }
}catch{$log.Error=$_.Exception.Message;throw}
finally{
 if($handle-ne [IntPtr]::Zero){
  if($dataAddress){
   [void][Re4CameraHook]::Write($handle,$dataAddress,[byte[]](0,0,0,0))
   $counter=[Re4ModelRead]::Read($handle,$dataAddress+4,4)
   if($counter){$log.AdjustedFrames=[BitConverter]::ToUInt32($counter,0)}
  }
  if($installed -and -not $game.HasExited){
   $live=[Re4ModelRead]::Read($handle,$callAddress,5)
   if($live -and [BitConverter]::ToString($live)-eq [BitConverter]::ToString($patch)){
    try{[Re4CameraHook]::ReplaceCall($handle,$game.Id,$callAddress,$originalCall);$log.Restored=$true}catch{Write-Warning 'Could not restore the camera call. Restart RE4.'}
   }else{Write-Warning 'Another component changed the camera call. Restart RE4.'}
  }
  [void][Re4CameraHook]::CloseHandle($handle)
 }
 if($owns){$mutex.ReleaseMutex()};$mutex.Dispose()
 $log|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'Camera-result.json') -Encoding UTF8
 Write-Output ('Frames adjusted: '+$log.AdjustedFrames)
 Write-Output 'Camera stopped.'
 # Retain 8 KB until RE4 exits: another thread may still be returning through it.
}

