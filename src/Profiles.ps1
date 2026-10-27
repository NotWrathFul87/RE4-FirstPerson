function Select-LeonModels($Entries) {
 $profiles=@(
  @{Name='Jacket';Body='119/11/5080';Knife='119/2/163';Hide=@('119/11/5080','113/8/2487','33/1/224','35/3/3127','33/39/2432')},
  @{Name='Normal';Body='119/14/7473';Knife='119/2/163';Hide=@('119/14/7473','119/2/107','119/2/330','33/1/224','35/3/3127','33/39/2432')},
  @{Name='Vest';Body='119/16/7938';Knife='119/2/163';Hide=@('119/16/7938','119/2/126','119/2/330','33/1/224','35/3/3127','33/39/2432')},
  @{Name='RPD';Body='119/13/6458';Knife='121/2/163';Hide=@('119/13/6458','119/2/102','119/2/330','33/1/224','35/3/3127','33/39/2432')},
  @{Name='Mafia';Body='111/8/4215';Knife='117/1/406';Hide=@('111/8/4215','35/3/3091','33/1/224','17/7/1746')}
 )
 $hands=@('2/2/824','2/2/800','2/2/804','2/2/808','2/2/806','2/2/802','2/2/814','2/2/838')
 $found=[System.Collections.Generic.HashSet[string]]::new()
 $byIdentity=@{}
 $targets=[System.Collections.Generic.List[object]]::new()
 if($Entries.Count -notin @(7,8,9,10)) { throw 'The model list changed. Nothing was changed.' }
 foreach($entry in $Entries) {
  $header=[byte[]]@($entry.Header.Split('-') | ForEach-Object { [Convert]::ToByte($_,16) })
  $identity='{0}/{1}/{2}' -f $header[25],([BitConverter]::ToUInt16($header,26)),([BitConverter]::ToUInt16($header,56))
  if(-not $found.Add($identity)) { throw ('Duplicate mesh: '+$identity+'. Nothing was changed.') }
  $byIdentity[$identity]=$entry
 }
 $matches=@($profiles | Where-Object { $found.Contains($_.Body) })
 if($matches.Count -ne 1) { throw 'A unique Leon costume could not be identified. Nothing was changed.' }
 $profile=$matches[0]
 if($profile.Name-in @('Normal','RPD','Mafia','Vest','Jacket')-and $found.Contains('119/1/13')){$profile.Hide=@($profile.Hide)+@('119/1/13')}
 if($Entries.Count -ne $profile.Hide.Count+3) { throw 'The mesh count does not match the costume. Nothing was changed.' }
 foreach($required in ($profile.Hide+@($profile.Knife))) {
  if(-not $found.Contains($required)) { throw ('Missing mesh for '+$profile.Name+': '+$required+'. Nothing was changed.') }
 }
 foreach($identity in $found) {
  if($identity -notin ($profile.Hide+@($profile.Knife)+$hands)) { throw ('Unrecognized mesh: '+$identity+'. Nothing was changed.') }
 }
 foreach($identity in $profile.Hide) { $targets.Add($byIdentity[$identity]) }
 return ,$targets.ToArray()
}
function Select-AshleyModels($Entries) {
 $expected=@('141/6/5933','9/2/2939','9/3/2650','82/41/3515','2/1/140','3/1/715','2/1/681')
 $identities=@($Entries|ForEach-Object {
  $h=[byte[]]@($_.Header.Split('-')|ForEach-Object{[Convert]::ToByte($_,16)})
  if($h.Length-lt 80){throw 'Incomplete mesh header.'}
  '{0}/{1}/{2}' -f $h[25],[BitConverter]::ToUInt16($h,26),[BitConverter]::ToUInt16($h,56)
 })
 $armor=@('86/8/12838','4/15/474','3/2/283','2/2/279')
 $armorFlash=@($armor|ForEach-Object{if($_-eq '3/2/283'){'3/3/405'}else{$_}})
 $armorMatches=@(Compare-Object ($armor|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 $armorFlashMatches=@(Compare-Object ($armorFlash|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 if($Entries.Count-eq 4-and ($armorMatches-or $armorFlashMatches)){
  $armorTargets=[Collections.Generic.List[object]]::new()
  for($i=0;$i-lt $Entries.Count;$i++){if($identities[$i]-in @('86/8/12838','4/15/474')){$armorTargets.Add($Entries[$i])}}
  return ,$armorTargets.ToArray()
 }
 $flashlight=@($expected|ForEach-Object{if($_-eq '3/1/715'){'3/3/939'}else{$_}})
 $normalMatches=@(Compare-Object ($expected|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 $flashlightMatches=@(Compare-Object ($flashlight|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 $popstar=@('156/10/4519','9/2/2939','9/3/2650','26/36/2709','156/5/3923','5/1/709','5/1/681')
 $popstarMatches=@(Compare-Object ($popstar|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 $popstarFlash=@($popstar|ForEach-Object{if($_-eq '5/1/709'){'3/3/939'}else{$_}})
 $popstarFlashMatches=@(Compare-Object ($popstarFlash|Sort-Object) ($identities|Sort-Object)).Count-eq 0
 if($Entries.Count-ne 7-or -not ($normalMatches-or $flashlightMatches-or $popstarMatches-or $popstarFlashMatches)){throw 'The seven Ashley meshes do not match a supported profile. Nothing was changed.'}
 $targets=[Collections.Generic.List[object]]::new()
 for($i=0;$i-lt 7;$i++){if($identities[$i]-notin @('3/1/715','3/3/939','2/1/681','5/1/709','5/1/681')){$targets.Add($Entries[$i])}}
 return ,$targets.ToArray()
}

function Select-HiddenModels($Entries,[int]$Role=0){
 if($Role-eq 0){return ,(Select-LeonModels $Entries)}
 if($Role-eq 1){return ,(Select-AshleyModels $Entries)}
 throw 'Unsupported character.'
}
