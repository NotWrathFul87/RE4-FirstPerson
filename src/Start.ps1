param([switch]$SelfTest,[switch]$SimulateFailure)
$ErrorActionPreference='Stop'
$script:ConfirmStop=$false
function Update-StopConfirmation([string]$Key){
 if($Key-eq 'CtrlC'){
  $script:ConfirmStop=$true
  Write-Host 'Stop the mod? [Y/N] ' -NoNewline
  return $false
 }
 if($script:ConfirmStop-and $Key-eq 'Y'){$script:ConfirmStop=$false;Write-Host 'Y';return $true}
 if($script:ConfirmStop-and $Key-eq 'N'){$script:ConfirmStop=$false;Write-Host 'N - The mod is still running.'}
 return $false
}
function Test-ConsoleStop {
 if(-not $script:ConsoleKeys){return $false}
 while([Console]::KeyAvailable){
  $key=[Console]::ReadKey($true)
  $name=if($key.Key-eq [ConsoleKey]::C-and ($key.Modifiers-band [ConsoleModifiers]::Control)){'CtrlC'}else{$key.Key.ToString()}
  if(Update-StopConfirmation $name){return $true}
 }
 return $false
}
$script:ConsoleKeys=$false;$savedCtrlC=$false

$mutex=[Threading.Mutex]::new($false,'Local\RE4PrimeraPersonaVanilla')
$owns=$false;$workers=[Collections.Generic.List[object]]::new()
$stopFile=Join-Path $PSScriptRoot 'Stop.signal'
$readyBody=Join-Path $PSScriptRoot 'Models.ready'
$readyCamera=Join-Path $PSScriptRoot 'Camera.ready'
$readyBoat=Join-Path $PSScriptRoot 'Vehicle.ready'
$workerErrors=[Collections.Generic.List[string]]::new()
$status=[ordered]@{Version='0.4.0';Variant='Vanilla';Active=$false;Stopped=$false;Error=$null}
try{
 if(-not $SelfTest-and -not [Console]::IsInputRedirected){
  $savedCtrlC=[Console]::TreatControlCAsInput
  [Console]::TreatControlCAsInput=$true;$script:ConsoleKeys=$true
 }
 try{$owns=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owns=$true}
 if(-not $owns){throw 'A first-person tool is already running. Stop it before starting another.'}
 foreach($file in @($stopFile,$readyBoat,($readyBoat+'.restored'),$readyBody,$readyCamera,($readyBody+'.restored'),($readyCamera+'.restored'))){if([IO.File]::Exists($file)){[IO.File]::Delete($file)}}
 . (Join-Path $PSScriptRoot 'Memory.ps1')
 . (Join-Path $PSScriptRoot 'ModelWriter.ps1')
 if(-not ('Re4CameraHook' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'Camera.cs')}
 [Re4SessionState]::BodyRole=-1
 [Re4SessionState]::JetSkiReady=$false
 if(-not ('Re4BoatCameraHook' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'VehicleCamera.cs')}
 if(-not $SelfTest){
  $games=@(Get-Process bio4 -ErrorAction SilentlyContinue)
  if($games.Count-ne 1){throw 'Open one instance of RE4 and load a saved game.'}
  Write-Output 'First Person Vanilla. Return to the game within 15 seconds.'
  Write-Output 'No time limit. To stop, open Stop.cmd or press Ctrl+C here and confirm with Y.'
  $wait=[Diagnostics.Stopwatch]::StartNew()
  while($wait.Elapsed.TotalSeconds-lt 15-and -not [IO.File]::Exists($stopFile)){
   if(Test-ConsoleStop){[IO.File]::WriteAllText($stopFile,'stop');break}
   Start-Sleep -Milliseconds 100
  }
  if([IO.File]::Exists($stopFile)){return}
 }
 foreach($kind in @('Models','Camera','Vehicle')){
  $ps=[PowerShell]::Create()
  $ready=if($kind-eq 'Models'){$readyBody}elseif($kind-eq 'Vehicle'){$readyBoat}else{$readyCamera}
  if($SelfTest){
   $script={param($stop,$ready,$fail)
    try{
     [IO.File]::WriteAllText($ready,'ready')
     if($fail){throw 'Simulated worker failure.'}
     while(-not [IO.File]::Exists($stop)){Start-Sleep -Milliseconds 50}
    }finally{[IO.File]::WriteAllText(($ready+'.restored'),'yes')}
   }
   [void]$ps.AddScript($script.ToString()).AddArgument($stopFile).AddArgument($ready).AddArgument([bool]($SimulateFailure-and $kind-eq 'Camera'))
  }elseif($kind-eq 'Models'){
   [void]$ps.AddCommand((Join-Path $PSScriptRoot 'HideModels.ps1')).AddParameter('Continuous').AddParameter('RestoreDuringEvents').AddParameter('RestoreMeleeExperimental').AddParameter('FollowAreas').AddParameter('StopFile',$stopFile).AddParameter('ReadyFile',$ready)
  }elseif($kind-eq 'Vehicle'){
   [void]$ps.AddCommand((Join-Path $PSScriptRoot 'VehicleCameraWorker.ps1')).AddParameter('StopFile',$stopFile).AddParameter('ReadyFile',$ready)
  }else{
   [void]$ps.AddCommand((Join-Path $PSScriptRoot 'CameraWorker.ps1')).AddParameter('StopFile',$stopFile).AddParameter('ReadyFile',$ready)
  }
  $workers.Add([pscustomobject]@{Name=$kind;PowerShell=$ps;Async=$ps.BeginInvoke();Finished=$false})
 }
 $lastRoleShown=-2
 $testDeadline=[DateTime]::UtcNow.AddSeconds(1)
 while(-not [IO.File]::Exists($stopFile)){
  if(Test-ConsoleStop){break}
  if(@($workers|Where-Object {$_.Async.IsCompleted}).Count){break}
  if(-not $status.Active-and [IO.File]::Exists($readyBody)-and [IO.File]::Exists($readyCamera)-and [IO.File]::Exists($readyBoat)){
   $status.Active=$true
   Write-Output 'Camera and model hiding are active.'
  }
  if($SelfTest-and [DateTime]::UtcNow-ge $testDeadline){break}
  if(-not $SelfTest){
   $currentRole=[Re4SessionState]::BodyRole
   if($currentRole-ne $lastRoleShown){
    if($currentRole-eq 0){Write-Output 'Active character: Leon.'}
    elseif($currentRole-eq 1){Write-Output 'Active character: playable Ashley.'}
    else{Write-Output 'Waiting for compatible models or a supported character.'}
    $lastRoleShown=$currentRole
   }
  }
  Start-Sleep -Milliseconds 200
 }
}catch{$status.Error=$_.Exception.Message;throw}
finally{
 if($owns){
  [IO.File]::WriteAllText($stopFile,'stop')
  $deadline=[DateTime]::UtcNow.AddSeconds(15)
  while(@($workers|Where-Object {-not $_.Async.IsCompleted}).Count-and [DateTime]::UtcNow-lt $deadline){[Threading.Thread]::Sleep(100)}
  foreach($worker in $workers){
   if(-not $worker.Async.IsCompleted){
    $workerErrors.Add($worker.Name+': did not stop in time. Restart RE4 to ensure restoration.')
    $worker.PowerShell.Stop()
   }
   try{
    $output=$worker.PowerShell.EndInvoke($worker.Async)
    foreach($line in $output){Write-Output $line}
   }catch{$workerErrors.Add($worker.Name+': '+$_.Exception.Message)}
   foreach($errorItem in $worker.PowerShell.Streams.Error){$workerErrors.Add($worker.Name+': '+$errorItem.ToString())}
   foreach($warning in $worker.PowerShell.Streams.Warning){Write-Warning $warning.Message}
   $worker.PowerShell.Dispose()
  }
  $status.Stopped=$true
  if($workerErrors.Count){$status.Error=$workerErrors.ToArray()-join "`n"}
  if($SelfTest){
   foreach($file in @($readyBody,$readyCamera,$readyBoat)){
    if(-not [IO.File]::Exists($file+'.restored')){throw 'Simulated restoration failed.'}
   }
   if($SimulateFailure-and $workerErrors.Count-eq 0){throw 'The simulated failure was not detected.'}
   Write-Output 'Coordination and shutdown self-test completed.'
  }
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'Session-status.json'),($status|ConvertTo-Json))
  foreach($file in @($readyBody,$readyCamera,$readyBoat)){if([IO.File]::Exists($file)){[IO.File]::Delete($file)}}
  $mutex.ReleaseMutex()
  Write-Output 'Session ended; all three workers received the restoration request.'
 }
 $mutex.Dispose()
 if($script:ConsoleKeys){[Console]::TreatControlCAsInput=$savedCtrlC}
}
if($workerErrors.Count-and -not $SelfTest){throw ($workerErrors.ToArray()-join "`n")}




