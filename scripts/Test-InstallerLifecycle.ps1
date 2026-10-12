param([Parameter(Mandatory=$true)][string]$PreviousInstaller)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$artifacts=Join-Path $root 'artifacts'
$installer=Join-Path $artifacts 'CastBridge-Setup.exe'
$token=[Guid]::NewGuid().ToString('N')
$target=Join-Path $artifacts ('release-validation-'+$token)
$resolved=[IO.Path]::GetFullPath($target)
if(-not $resolved.StartsWith(([IO.Path]::GetFullPath($artifacts)+'\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Validation target escapes workspace artifacts.'}
if(Test-Path -LiteralPath $target){throw 'Validation requires a fresh directory.'}
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MateKraft.CastBridge'
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'MateKraft\CastBridge.lnk'
if((Test-Path $key) -or (Test-Path -LiteralPath $shortcut)){throw 'An existing user installation exists. Refusing to replace its registration.'}
function Invoke-Validation([string]$Exe,[string]$Mode,[string]$Report) {
    $process=Start-Process -FilePath $Exe -ArgumentList @($Mode,('"'+$target+'"'),('"'+$Report+'"')) -WindowStyle Hidden -PassThru
    if(-not $process.WaitForExit(900000)){throw 'Installer validation timed out; inspect its own log before cleanup.'}
    $result=Get-Content -LiteralPath $Report -Raw|ConvertFrom-Json
    if($process.ExitCode -ne 0){throw ('Validation failed: '+($result|ConvertTo-Json -Depth 8 -Compress))}
    return $result
}
$previousReport=Join-Path $artifacts ('previous-install-'+$token+'.json')
$null=Invoke-Validation $PreviousInstaller '--install-test' $previousReport
$manifestPath=Join-Path $target 'castbridge-install.json'
$previous=Get-Content $manifestPath -Raw|ConvertFrom-Json
if(-not $previous.complete){throw 'Previous release did not finish installing.'}
$marker=@{token=$token}|ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $target '.castbridge-validation.json'),$marker,[Text.UTF8Encoding]::new($false))
$saved=@{language='es'}|ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $target 'artifacts\ui-settings.json'),$saved,[Text.UTF8Encoding]::new($false))
$preferences='{"id":"00000000-0000-0000-0000-000000000001","name":"Validation only","model":"Chromecast","displayName":"Validation only","lowLatency":false,"aggressiveLatency":false}'
[IO.File]::WriteAllText((Join-Path $target 'artifacts\preferences.json'),$preferences,[Text.UTF8Encoding]::new($false))
$layout='{"version":1,"displays":{}}'
[IO.File]::WriteAllText((Join-Path $target 'artifacts\display-layout.json'),$layout,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $target 'keep-user-note.txt'),'User-owned file retained.');[IO.File]::WriteAllText((Join-Path $target 'obsolete-owned.txt'),'Old application-owned file.')
$previous.files=@($previous.files)+@('obsolete-owned.txt')
[IO.File]::WriteAllText($manifestPath,($previous|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
$upgradeReport=Join-Path $artifacts ('upgrade-'+$token+'.json')
$null=Invoke-Validation $installer '--upgrade-test' $upgradeReport
$upgraded=Get-Content $manifestPath -Raw|ConvertFrom-Json
if(-not $upgraded.complete -or $upgraded.version -ne '0.2.0-alpha.2'){throw 'Upgrade version was not recorded.'}
foreach($file in @('LICENSE','NOTICE','TRADEMARKS.md','THIRD_PARTY_NOTICES.md','third_party\licenses\zeroconf-0.151.5\COPYING')){if(-not(Test-Path -LiteralPath (Join-Path $target $file))){throw ('Missing release notice: '+$file)}}
if((Get-Content (Join-Path $target 'artifacts\preferences.json') -Raw) -ne $preferences -or (Get-Content (Join-Path $target 'artifacts\display-layout.json') -Raw) -ne $layout){throw 'Upgrade changed user display preferences.'}
if((Get-Content (Join-Path $target 'artifacts\ui-settings.json') -Raw|ConvertFrom-Json).language -ne 'es'){throw 'Upgrade lost the selected language.'}
if($upgraded.files -notcontains 'obsolete-owned.txt'){throw 'Upgrade lost ownership tracking for obsolete application files.'}
$registration=Get-ItemProperty $key
if($registration.InstallLocation -ne $target -or $registration.Publisher -ne 'MateKraft' -or $registration.DisplayVersion -ne '0.2.0-alpha.2' -or -not(Test-Path -LiteralPath $shortcut)){throw 'Windows application registration failed.'}
$uninstallReport=Join-Path $artifacts ('uninstall-'+$token+'.json')
$null=Invoke-Validation $installer '--uninstall-test' $uninstallReport
foreach($file in @('CastBridge.exe','Uninstall.exe','obsolete-owned.txt','.venv')){if(Test-Path -LiteralPath (Join-Path $target $file)){throw ('Uninstall retained an owned runtime file: '+$file)}}
foreach($file in @('keep-user-note.txt','artifacts\preferences.json','artifacts\display-layout.json','artifacts\ui-settings.json','install.log')){if(-not(Test-Path -LiteralPath (Join-Path $target $file))){throw ('Uninstall removed retained user data: '+$file)}}
if((Test-Path $key) -or (Test-Path -LiteralPath $shortcut)){throw 'Uninstall left Windows registration behind.'}
$result=[ordered]@{success=$true;previousVersion=$previous.version;newVersion=$upgraded.version;upgradePreservedPreferences=$true;upgradePreservedLanguage=$true;windowsRegistrationVerified=$true;uninstallRemovedRuntime=$true;uninstallRetainedUserData=$true;target=$target}
$result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $artifacts 'installer-lifecycle.json') -Encoding UTF8
$result|ConvertTo-Json
