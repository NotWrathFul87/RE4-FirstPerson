param([string]$StopFile,[string]$ReadyFile)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Memory.ps1')
if(-not ('Re4BoatCameraHook' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'VehicleCamera.cs')}
$games=@(Get-Process bio4 -ErrorAction SilentlyContinue)
if($games.Count-ne 1){throw 'Load an RE4 saved game before starting the mod.'}
$game=$games[0];$path=$game.Path;$base=$game.MainModule.BaseAddress.ToInt64()
$exe=[IO.File]::ReadAllBytes($path);$pe=[BitConverter]::ToInt32($exe,60)
if([BitConverter]::ToUInt16($exe,$pe+4)-ne 0x14c){throw 'The game executable is not x86.'}
$optional=$pe+24;$preferred=[BitConverter]::ToUInt32($exe,$optional+28)
$sections=$pe+24+[BitConverter]::ToUInt16($exe,$pe+20)
$site=[pscustomobject]@{Rva=0x19F4B2;FileOffset=0}
for($section=0;$section-lt [BitConverter]::ToUInt16($exe,$pe+6);$section++){
 $at=$sections+40*$section;$rva=[BitConverter]::ToUInt32($exe,$at+12);$length=[BitConverter]::ToUInt32($exe,$at+16)
 if($site.Rva-ge $rva -and $site.Rva-lt $rva+$length){$site.FileOffset=[BitConverter]::ToUInt32($exe,$at+20)+$site.Rva-$rva}
}
if(-not $site.FileOffset){throw 'The vehicle camera call was not found.'}
$callAddress=$base+$site.Rva
$expected=[byte[]]$exe[($site.FileOffset-14)..($site.FileOffset+4)]
$originalCall=[byte[]]$exe[$site.FileOffset..($site.FileOffset+4)]
if([BitConverter]::ToString($originalCall)-ne 'E8-B1-62-E6-FF'){throw 'The game version does not match. Nothing was changed.'}
$originalTarget=$callAddress+5+[BitConverter]::ToInt32($originalCall,1)
if($originalTarget-lt $base -or $originalTarget-ge $base+[BitConverter]::ToUInt32($exe,$optional+56)){throw 'The original call target is outside the game module.'}
$mutex=[Threading.Mutex]::new($false,'Local\RE4PruebaCamaraDelLago')
$owns=$false;$handle=[IntPtr]::Zero;$allocation=[IntPtr]::Zero;$installed=$false;$patch=$null;$dataAddress=0
$log=[ordered]@{CallRva=('{0:X8}' -f $site.Rva);OriginalTarget=('{0:X8}' -f $originalTarget);Installed=$false;AdjustedFrames=0;Restored=$false;Error=$null}
try{
 try{$owns=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owns=$true}
 if(-not $owns){throw 'This camera worker is already running.'}
 $handle=[Re4BoatCameraHook]::OpenProcess(0x438,$false,$game.Id)
 if($handle-eq [IntPtr]::Zero){throw 'Could not open RE4 for camera control.'}
 $live=[Re4ModelRead]::Read($handle,$callAddress-14,19)
 $log.ExpectedBytes=[BitConverter]::ToString($expected)
 $log.LiveBytes=if($null-ne $live){[BitConverter]::ToString($live)}else{'Lectura fallida'}
 if($null-eq $live -or $live.Length-ne 19 -or [BitConverter]::ToString($live,0,14)-ne [BitConverter]::ToString($expected,0,14) -or $live[14]-ne 0xE8){
  Write-Output ('Expected bytes: '+$log.ExpectedBytes)
  Write-Output ('Current bytes:  '+$log.LiveBytes)
  throw 'The call does not match. Details were saved to Vehicle-camera-result.json. The game was not changed.'
 }
 # Chain the existing call, including another component's executable trampoline.
 $originalCall=[byte[]]$live[14..18]
 $originalTarget=$callAddress+5+[BitConverter]::ToInt32($originalCall,1)
 if($originalTarget-lt 0x10000 -or $originalTarget-gt 4294967295 -or -not [Re4BoatCameraHook]::Executable($handle,$originalTarget)){throw 'The current target is not executable memory. Nothing was changed.'}
 $targetCode=[Re4ModelRead]::Read($handle,$originalTarget,16)
 if($null-eq $targetCode -or $targetCode.Length-ne 16){throw 'Could not validate the current call target.'}
 $log.OriginalTarget=('{0:X8}' -f $originalTarget)
 $log.ChainedExistingCall=($log.LiveBytes-ne $log.ExpectedBytes)
 if($log.ChainedExistingCall){Write-Output 'Existing redirection validated; it will be preserved while running and after shutdown.'}
 $playerPointer=[Re4ModelRead]::Read($handle,$base+0x8537d4,4)
 if(-not $playerPointer -or [BitConverter]::ToUInt32($playerPointer,0)-lt 0x10000){throw 'No saved game is currently loaded.'}
 $allocation=[Re4BoatCameraHook]::VirtualAllocEx($handle,[IntPtr]::Zero,[UIntPtr]::new(8192),0x3000,4)
 if($allocation-eq [IntPtr]::Zero -or $allocation.ToInt64()-gt [long]4294959103){throw 'Could not allocate x86 memory.'}
 $codeAddress=$allocation.ToInt64();$dataAddress=$codeAddress+4096
 $code=[Re4BoatCameraHook]::Build([uint32]$codeAddress,[uint32]$originalTarget,[uint32]($base+0x8537d4),[uint32]($base+0x805f3c),[uint32]$dataAddress)
 $data=New-Object byte[] 32
 [BitConverter]::GetBytes([single]1765).CopyTo($data,16)
 [BitConverter]::GetBytes([single]1600).CopyTo($data,28)
 if(-not [Re4BoatCameraHook]::Write($handle,$codeAddress,$code)-or -not [Re4BoatCameraHook]::Write($handle,$dataAddress,$data)){throw 'Could not prepare the camera component.'}
 $previous=[uint32]0
 if(-not [Re4BoatCameraHook]::VirtualProtectEx($handle,$allocation,[UIntPtr]::new(4096),0x20,[ref]$previous)){throw 'Could not enable the camera code.'}
 if(-not [Re4BoatCameraHook]::FlushInstructionCache($handle,$allocation,[UIntPtr]::new($code.Length))){throw 'Could not flush the instruction cache.'}

 $live=[Re4ModelRead]::Read($handle,$callAddress,5)
 if(-not $live -or [BitConverter]::ToString($live)-ne [BitConverter]::ToString($originalCall)){throw 'The call changed during setup. The camera component was not installed.'}
 $patch=[Re4BoatCameraHook]::Call([uint32]$callAddress,[uint32]$codeAddress)
 [Re4BoatCameraHook]::ReplaceCall($handle,$game.Id,$callAddress,$patch)
 $installed=$true;$log.Installed=$true
 if($ReadyFile){[IO.File]::WriteAllText($ReadyFile,'ready')}
 $lastState=''
 while(-not $game.HasExited){
  if($StopFile-and [IO.File]::Exists($StopFile)){break}
  $enabled=[int]([Re4SessionState]::BodyRole-eq 0)
  $mode=[int][Re4SessionState]::JetSkiReady
  $state=($enabled.ToString()+'/'+$mode)
  if($state-ne $lastState){
   if(-not [Re4BoatCameraHook]::Write($handle,$dataAddress,[byte[]](0,0,0,0))){throw 'Could not suspend the vehicle camera.'}
   if(-not [Re4BoatCameraHook]::Write($handle,$dataAddress+8,[BitConverter]::GetBytes($mode))){throw 'Could not select the vehicle camera mode.'}
   if(-not [Re4BoatCameraHook]::Write($handle,$dataAddress,[BitConverter]::GetBytes($enabled))){throw 'Could not update the vehicle camera.'}
   $lastState=$state
  }
  Start-Sleep -Milliseconds 50
 }
}catch{$log.Error=$_.Exception.Message;throw}
finally{
 if($handle-ne [IntPtr]::Zero){
  if($dataAddress){
   [void][Re4BoatCameraHook]::Write($handle,$dataAddress,[byte[]](0,0,0,0))
   $counter=[Re4ModelRead]::Read($handle,$dataAddress+4,4)
   if($counter){$log.AdjustedFrames=[BitConverter]::ToUInt32($counter,0)}
  }
  if($installed -and -not $game.HasExited){
   $live=[Re4ModelRead]::Read($handle,$callAddress,5)
   if($live -and [BitConverter]::ToString($live)-eq [BitConverter]::ToString($patch)){
    try{[Re4BoatCameraHook]::ReplaceCall($handle,$game.Id,$callAddress,$originalCall);$log.Restored=$true}catch{Write-Warning 'Could not restore the camera call. Restart RE4.'}
   }else{Write-Warning 'Another component changed the camera call. Restart RE4.'}
  }
  [void][Re4BoatCameraHook]::CloseHandle($handle)
 }
 if($owns){$mutex.ReleaseMutex()};$mutex.Dispose()
 $log|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'Vehicle-camera-result.json') -Encoding UTF8
 Write-Output ('Frames adjusted: '+$log.AdjustedFrames)
 Write-Output 'Camera stopped.'
 # Retain 8 KB until RE4 exits: another thread may still be returning through it.
}

