# pi Chinese localization (yuloop/pi) one-click installer - Windows x64 (PowerShell 5.1+)
#
# Usage:
#   powershell -Command "irm https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install.ps1 | iex"
#   powershell -Command "irm https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install-preview.ps1 | iex"
#
# Options:
#   -Preview    install latest realtime preview release (*-cn-nightly)
#   -Version X  install exact tag (e.g. v0.84.2-cn-nightly-0123456789ab)
#
# Install dir: %LOCALAPPDATA%\pi-cn (user data lives in ~/.pi/agent, untouched)

param(
    [switch]$Preview,
    [string]$Version = ""
)

$ErrorActionPreference = 'Stop'

# Compat: install-preview.ps1 may set $script:Preview before invoking this script
if (-not $Preview -and $script:Preview) { $Preview = $true }

$ApiBase = 'https://api.github.com/repos/yuloop/pi/releases'
$DownloadBase = 'https://github.com/yuloop/pi/releases/download'
$ApiHeaders = @{ 'User-Agent' = 'pi-cn-installer' }

$tmpDir = $null

function Resolve-Tag {
    if ($Version) { return $Version }
    if ($Preview) {
        $releases = Invoke-RestMethod -Uri ($ApiBase + '?per_page=10') -Headers $ApiHeaders
        $rel = $releases | Where-Object { $_.prerelease -and $_.tag_name -like '*cn-nightly*' } | Select-Object -First 1
        if (-not $rel) { throw 'No available realtime preview release found (*-cn-nightly)' }
        return $rel.tag_name
    }
    $rel = Invoke-RestMethod -Uri ($ApiBase + '/latest') -Headers $ApiHeaders
    return $rel.tag_name
}

function Get-AssetName {
    param($Release, [string]$Pattern)
    return ($Release.assets | Where-Object { $_.name -like $Pattern } | Select-Object -First 1).name
}

try {
    $tag = Resolve-Tag
    if ($tag -notmatch '^[A-Za-z0-9._-]+$') { throw "Release tag contains invalid characters: $tag" }
    Write-Host "[1/5] Target release: $tag"

    $release = Invoke-RestMethod -Uri ($ApiBase + '/tags/' + $tag) -Headers $ApiHeaders
    $zipName = Get-AssetName $release 'pi-cn-*-windows-x64.zip'
    $sumsName = Get-AssetName $release 'SHA256SUMS'
    if (-not $zipName -or -not $sumsName) {
        throw "Release $tag has no windows-x64 package or SHA256SUMS asset"
    }

    $installDir = Join-Path $env:LOCALAPPDATA 'pi-cn'
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pi-cn-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $zipPath = Join-Path $tmpDir $zipName
    $sumsPath = Join-Path $tmpDir $sumsName

    Write-Host "[2/5] Downloading $zipName ..."
    Invoke-WebRequest -Uri "$DownloadBase/$tag/$zipName" -OutFile $zipPath -UseBasicParsing
    Invoke-WebRequest -Uri "$DownloadBase/$tag/$sumsName" -OutFile $sumsPath -UseBasicParsing

    Write-Host "[3/5] Verifying SHA-256 ..."
    $sumLine = Get-Content $sumsPath | Where-Object { $_ -like ('*' + $zipName + '*') } | Select-Object -First 1
    if (-not $sumLine) { throw "SHA256SUMS contains no entry for $zipName" }
    $expected = ($sumLine -split '\s+')[0].ToUpper()
    $actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToUpper()
    if ($expected -ne $actual) {
        throw "SHA-256 mismatch for $zipName`: expected $expected, got $actual"
    }
    Write-Host "Checksum OK: $actual"

    Write-Host "[4/5] Installing to $installDir ..."
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Get-ChildItem -Path $installDir -Force | Remove-Item -Recurse -Force
    Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

    Write-Host "[5/5] Updating user PATH ..."
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -and $userPath.Contains($installDir)) {
        Write-Host "PATH already contains $installDir, skipped"
    } else {
        $newPath = if ([string]::IsNullOrEmpty($userPath)) { $installDir } else { "$installDir;$userPath" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Appended user PATH: $installDir"
    }
    $env:Path = if ([string]::IsNullOrEmpty($env:Path)) { $installDir } else { "$installDir;$env:Path" }

    Write-Host ""
    Write-Host "Install complete: pi-cn $tag"
    Write-Host "Install dir: $installDir"
    Write-Host "Run: pi   (open a new terminal, then type pi)"
    Write-Host "Update: re-run the same one-line command"
}
catch {
    Write-Host ("Install failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if ($tmpDir -and (Test-Path $tmpDir)) { Remove-Item -Path $tmpDir -Recurse -Force }
}