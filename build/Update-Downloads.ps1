$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$repo='akasha-code/CastBridge'
$metadata=& gh api ('repos/'+$repo)
if($LASTEXITCODE -ne 0){throw 'Could not read repository metadata. Authenticate GitHub CLI first.'}
$repository=$metadata|ConvertFrom-Json
if($repository.full_name -ne $repo){throw 'Unexpected repository identity.'}
$response=& gh api ('repos/'+$repo+'/releases') --paginate --slurp
if($LASTEXITCODE -ne 0){throw 'Could not read GitHub releases.'}
$pages=$response|ConvertFrom-Json
function Get-PublishedInstant($value) {
    if($value -is [DateTime] -or $value -is [DateTimeOffset]){return [DateTimeOffset]$value}
    return [DateTimeOffset]::Parse([string]$value,[Globalization.CultureInfo]::InvariantCulture)
}
$releases=@(foreach($page in $pages){foreach($release in $page){if(-not $release.draft){$release}}})
$releases=@($releases|Sort-Object {Get-PublishedInstant $_.published_at} -Descending)
$snapshot=@(foreach($release in $releases){
    [ordered]@{tag=$release.tag_name;prerelease=[bool]$release.prerelease;publishedAt=(Get-PublishedInstant $release.published_at).ToString('o');url=$release.html_url;assets=@(foreach($asset in $release.assets){[ordered]@{name=$asset.name;bytes=$asset.size;url=$asset.browser_download_url}})}
})
$docs=Join-Path $root 'docs'
if(-not(Test-Path -LiteralPath $docs)){New-Item -ItemType Directory -Path $docs|Out-Null}
$locale=@{
    en=@{file='downloads.md';title='Download CastBridge';credit='A MateKraft production';private='Private validation builds. Sign in to GitHub with an account that has repository access to download these files.';preview='Latest preview';stable='Latest stable';noStable='No stable version has been published yet.';noPreview='No preview version has been published yet.';installer='Download Windows x64 installer';zip='Download ZIP package';checksums='SHA-256 checksums';notes='Release notes';older='Previous versions';legacy='This older preview uses ZIP-based setup; it does not include the compiled EXE installer.';warning='Preview executables are not digitally signed yet. Read the release notes and validation limits before installation.';guide='Installation guide';history='Complete release history';source='Build instructions';published='Published';updated='Generated from published GitHub Releases. Times: Europe/Oslo.';home='Project overview'}
    es=@{file='downloads.es.md';title='Descargar CastBridge';credit='Una producción de MateKraft';private='Versiones privadas de validación. Iniciá sesión en GitHub con una cuenta que tenga acceso al repositorio para descargar los archivos.';preview='Última versión preliminar';stable='Última versión estable';noStable='Todavía no se publicó una versión estable.';noPreview='Todavía no se publicó una versión preliminar.';installer='Descargar instalador Windows x64';zip='Descargar paquete ZIP';checksums='Checksums SHA-256';notes='Notas de la versión';older='Versiones anteriores';legacy='Esta versión anterior usa instalación mediante ZIP; no incluye el instalador EXE compilado.';warning='Los ejecutables preliminares todavía no tienen firma digital. Revisá las notas y los límites de validación antes de instalar.';guide='Guía de instalación en inglés';history='Historial completo de versiones';source='Instrucciones de compilación en inglés';published='Publicada';updated='Generado desde GitHub Releases publicadas. Horarios: Europe/Oslo.';home='Presentación del proyecto'}
    nb=@{file='downloads.no.md';title='Last ned CastBridge';credit='En produksjon fra MateKraft';private='Private valideringsversjoner. Logg inn på GitHub med en konto som har tilgang til repositoriet for å laste ned filene.';preview='Nyeste forhåndsversjon';stable='Nyeste stabile versjon';noStable='Ingen stabil versjon er publisert ennå.';noPreview='Ingen forhåndsversjon er publisert ennå.';installer='Last ned installasjonsprogram for Windows x64';zip='Last ned ZIP-pakke';checksums='SHA-256-kontrollsummer';notes='Versjonsnotater';older='Tidligere versjoner';legacy='Denne eldre forhåndsversjonen bruker ZIP-basert installasjon og har ikke det kompilerte EXE-installasjonsprogrammet.';warning='Forhåndsversjonenes programfiler er ikke digitalt signert ennå. Les versjonsnotatene og valideringsgrensene før installasjon.';guide='Installasjonsveiledning på engelsk';history='Full versjonshistorikk';source='Bygginstruksjoner på engelsk';published='Publisert';updated='Generert fra publiserte GitHub Releases. Tidssone: Europe/Oslo.';home='Prosjektoversikt'}
}
$zone=[TimeZoneInfo]::FindSystemTimeZoneById('W. Europe Standard Time')
function Assert-ReleaseUrl([string]$url) {
    $uri=[uri]$url
    if($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or -not $uri.AbsolutePath.StartsWith('/'+$repo+'/releases/',[StringComparison]::OrdinalIgnoreCase) -or $uri.Query){throw 'Unexpected release URL.'}
    return $url
}
function Add-Release($lines,$release,$text) {
    $tag=([string]$release.tag_name).Replace('`','').Replace('[','').Replace(']','')
    $time=[TimeZoneInfo]::ConvertTime((Get-PublishedInstant $release.published_at),$zone).ToString('yyyy-MM-dd HH:mm')
    $lines.Add('### '+$tag);$lines.Add('');$lines.Add($text.published+': '+$time+' (Europe/Oslo)');$lines.Add('')
    $exe=@($release.assets|Where-Object {$_.name -eq 'CastBridge-Setup.exe'})
    $zip=@($release.assets|Where-Object {$_.name -match '\.zip$'})
    if($exe.Count){$lines.Add('**['+$text.installer+']('+(Assert-ReleaseUrl $exe[0].browser_download_url)+')**');$lines.Add('')}
    foreach($asset in $zip){$lines.Add('['+$text.zip+']('+(Assert-ReleaseUrl $asset.browser_download_url)+')');$lines.Add('')}
    if(-not $exe.Count){$lines.Add($text.legacy);$lines.Add('')}
    foreach($asset in @($release.assets|Where-Object {$_.name -match 'SHA256SUMS|\.sha256\.txt$'})){$lines.Add('['+$text.checksums+']('+(Assert-ReleaseUrl $asset.browser_download_url)+')');$lines.Add('')}
    $lines.Add('['+$text.notes+']('+(Assert-ReleaseUrl $release.html_url)+')');$lines.Add('')
}
$preview=@($releases|Where-Object {$_.prerelease}|Select-Object -First 1)
$stable=@($releases|Where-Object {-not $_.prerelease}|Select-Object -First 1)
foreach($code in @('en','es','nb')) {
    $text=$locale[$code];$lines=[Collections.Generic.List[string]]::new()
    $lines.Add('[English](downloads.md) · [Español](downloads.es.md) · [Norsk](downloads.no.md)');$lines.Add('');$lines.Add('![CastBridge — MateKraft](../assets/castbridge-banner.svg)');$lines.Add('');$lines.Add('# '+$text.title);$lines.Add('');$lines.Add('**'+$text.credit+' · [matekraft.tech](https://matekraft.tech)**');$lines.Add('');$lines.Add('[Buy me a coffee](https://www.buymeacoffee.com/matekraft)');$lines.Add('');$notice=if($repository.private){$text.private}else{switch($code){'es'{'Versiones preliminares públicas. Revisá los requisitos y los límites de validación antes de instalar.'};'nb'{'Offentlige forhåndsversjoner. Les kravene og valideringsgrensene før installasjon.'};default{'Public preview builds. Review prerequisites and validation limits before installing.'}}};$lines.Add('> '+$notice);$lines.Add('')
    $lines.Add('## '+$text.preview);$lines.Add('');if($preview.Count){Add-Release $lines $preview[0] $text}else{$lines.Add($text.noPreview);$lines.Add('')}
    $lines.Add('## '+$text.stable);$lines.Add('');if($stable.Count){Add-Release $lines $stable[0] $text}else{$lines.Add($text.noStable);$lines.Add('')}
    $lines.Add('## '+$text.older);$lines.Add('');$selected=@($preview.tag_name)+@($stable.tag_name);foreach($release in $releases){if($release.tag_name -notin $selected){Add-Release $lines $release $text}}
    $lines.Add('> '+$text.warning);$lines.Add('');$lines.Add('['+$text.guide+'](../INSTALL.md) · ['+$text.source+'](https://github.com/akasha-code/CastBridge/tree/main/build) · ['+$text.history+'](https://github.com/'+$repo+'/releases)');$lines.Add('');$projectReadme=if($code -eq 'es'){'README.es.md'}elseif($code -eq 'nb'){'README.no.md'}else{'README.md'};$lines.Add('['+$text.home+'](../'+$projectReadme+')');$lines.Add('');$lines.Add('[Code signing policy](signing.md)');$lines.Add('');$lines.Add($text.updated)
    [IO.File]::WriteAllLines((Join-Path $docs $text.file),$lines,[Text.UTF8Encoding]::new($false))
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'releases.json'),(ConvertTo-Json -InputObject $snapshot -Depth 6)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
'Download pages refreshed from '+$releases.Count+' published releases. Visibility: '+$repository.visibility
