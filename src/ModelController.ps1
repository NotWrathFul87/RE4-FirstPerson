function Get-ControlledRole([int]$Character) {
 if($Character-in @(0,6)){return 0}
 if($Character-eq 1){return 1}
 return -1
}
function Test-KnockdownBody([int]$Role,[byte[]]$Routine) {
 # Leon damage state, including minor hits and all recorded recoveries.
 return $Role-eq 0-and $Routine.Length-eq 4-and $Routine[0]-eq 1
}
function Test-ForceEventBody([int]$Role,[byte[]]$Routine) {
 if($Role-eq 0-and $Routine.Length-eq 4-and $Routine[0]-eq 5){return $true}
 return $Role-eq 0-and $Routine.Length-eq 4-and $Routine[0]-eq 4-and $Routine[1]-eq 0-and $Routine[2]-eq 9-and $Routine[3]-eq 1
}
function Test-JetSkiModels($Entries){
 foreach($e in $Entries){
  $h=[byte[]]@($e.Header.Split('-')|ForEach-Object{[Convert]::ToByte($_,16)})
  if($h.Length-ge 80-and $h[25]-eq 2-and [BitConverter]::ToUInt16($h,26)-eq 2-and [BitConverter]::ToUInt16($h,56)-eq 838){return $true}
 }
 return $false
}
function Test-RestoreBody([int]$Role,[byte[]]$Routine,[uint32]$Status,[uint32]$Status2=0,[bool]$IsJetSki=$false) {
 if(($Status-band 0x14041000)-ne 0){return $true}
 if($Routine.Length-ne 4){return $false}
 if($Role-eq 0-and $IsJetSki-and ($Status2-band 0x200000)-ne 0-and $Routine[0]-eq 0-and $Routine[1]-eq 15){return $Routine[2]-notin @(1,3)}
 if(Test-KnockdownBody $Role $Routine){return $true}
 if($Role-eq 1){return $Routine[0]-in @(4,5)-or ($Routine[0]-eq 0-and $Routine[1]-in @(9,16))}
 if($Role-eq 0-and $Routine[0]-eq 0-and $Routine[1]-eq 15-and $Routine[2]-in @(0,1,5,6,7,8)){return $true}
 if($Role-eq 0){return $Routine[0]-in @(4,5)-or ($Routine[0]-eq 0-and $Routine[1]-in @(7,9,12,14,16,19))}
 return $false
}
function New-ModelContext {
 return [pscustomobject]@{Binding=$null;Role=-1;WasEvent=$false;Reason='Waiting for a supported character';LastState='';Log=[Collections.Generic.List[object]]::new()}
}
function Restore-ModelBinding($Binding) {
 if($null-eq $Binding){return}
 foreach($entry in $Binding.Targets){
  $current=Read-ModelFlags $entry.Info
  # Restore the previous actor even after it is no longer the controlled player.
  # This includes Ashley becoming an NPC; never enumerate the NPC pointer.
  if($null-ne $current-and $current.Data-eq $entry.Data){
   $flag=[uint32](($current.Flag-band [long]4294967287)-bor ($entry.Original-band 8))
   if($flag-ne $current.Flag){Write-ModelFlag $entry.Info $flag}
  }
 }
}
function Clear-ModelContext($Context,[string]$Reason) {
 $Context.Role=-1
 Restore-ModelBinding $Context.Binding
 $Context.Binding=$null;$Context.WasEvent=$false;$Context.Reason=$Reason
}
function Update-ModelContext($Context,$Snapshot) {
 if($null-eq $Snapshot-or $Snapshot.Role-notin @(0,1)){
  Clear-ModelContext $Context 'Waiting for Leon or playable Ashley';return
 }
 try{$targets=Select-HiddenModels $Snapshot.Entries -Role $Snapshot.Role}
 catch{Clear-ModelContext $Context 'Waiting for compatible models';return}
 $parts=@($Snapshot.Entries|ForEach-Object {($_.Info+'/'+$_.Data+'/'+$_.Header)})
 $key=($Snapshot.Role.ToString()+'/'+$Snapshot.Player+'/'+($parts-join ';'))
 if($null-eq $Context.Binding-or $Context.Binding.Key-ne $key){
  $Context.Role=-1
  Restore-ModelBinding $Context.Binding
  $saved=[Collections.Generic.List[object]]::new()
  foreach($entry in $targets){
   $info=[Convert]::ToInt64($entry.Info,16);$data=[Convert]::ToInt64($entry.Data,16)
   $current=Read-ModelFlags $info
   if($null-eq $current-or $current.Data-ne $data){Clear-ModelContext $Context 'Loading models';return}
   $saved.Add([pscustomobject]@{Info=$info;Data=$data;Original=$current.Flag})
  }
  $Context.Binding=[pscustomobject]@{Key=$key;Targets=$saved.ToArray();Role=$Snapshot.Role;Player=$Snapshot.Player;IsJetSki=(Test-JetSkiModels $Snapshot.Entries)}
  $Context.WasEvent=$false
 }
 $restore=Test-RestoreBody $Snapshot.Role $Snapshot.Routine $Snapshot.Status $Snapshot.Status2 $Context.Binding.IsJetSki
 foreach($entry in $Context.Binding.Targets){
  if(-not (Test-SnapshotCurrent $Snapshot)){Clear-ModelContext $Context 'Character or area changed';return}
  $current=Read-ModelFlags $entry.Info
  if($null-eq $current-or $current.Data-ne $entry.Data){Clear-ModelContext $Context 'Models changed';return}
  if($restore-and $Context.WasEvent-and -not (Test-ForceEventBody $Snapshot.Role $Snapshot.Routine)-and -not (Test-KnockdownBody $Snapshot.Role $Snapshot.Routine)){continue}
  $flag=[uint32]($current.Flag-band [long]4294967287)
  if($restore){$flag=[uint32]($flag-bor ($entry.Original-band 8))}
  if($flag-ne $current.Flag){Write-ModelFlag $entry.Info $flag}
 }
 $Context.WasEvent=$restore;$Context.Role=$Snapshot.Role
 $Context.Reason=if($Snapshot.Role-eq 1){'Playable Ashley'}else{'Leon'}
 $state=($Snapshot.Role.ToString()+'/'+[BitConverter]::ToString($Snapshot.Routine)+'/'+$restore)
 if($state-ne $Context.LastState){
  if($Context.Log.Count-ge 5000){$Context.Log.RemoveAt(0)}
  $Context.Log.Add([pscustomobject]@{Time=(Get-Date -Format o);Role=$Snapshot.Role;Routine=[BitConverter]::ToString($Snapshot.Routine);RestoreBody=$restore;Status=('{0:X8}' -f $Snapshot.Status);Status2=('{0:X8}' -f $Snapshot.Status2)})
  $Context.LastState=$state
 }
}
