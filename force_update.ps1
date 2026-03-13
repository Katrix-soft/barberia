# Force Update Script for Katrix Barber
# Usage: .\force_update.ps1 -AppVersion "0.1.3" -DbVersion 12 -Message "Actualización importante"

param (
    [string]$AppVersion,
    [int]$DbVersion,
    [string]$Message = "Nueva actualización disponible. Por favor reinicie.",
    [bool]$Force = $true,
    [bool]$Maintenance = $false
)

$VersionFile = "web/version.json"
$VersionInfoFile = "lib/core/utils/version_info.dart"

if (-not (Test-Path $VersionFile)) {
    Write-Error "No se encuentra $VersionFile"
    exit
}

# 1. Update version.json (The "Server" side)
$json = Get-Content $VersionFile | ConvertFrom-Json
if ($AppVersion) { $json.app_version = $AppVersion }
if ($DbVersion) { $json.db_version = $DbVersion }
$json.message = $Message
$json.force_update = $Force
$json.maintenance_mode = $Maintenance

$json | ConvertTo-Json | Set-Content $VersionFile
Write-Host "✅ remote version updated in $VersionFile" -ForegroundColor Green

# 2. Update version_info.dart (The "Client" side constants)
if ($AppVersion -or $DbVersion) {
    $content = Get-Content $VersionInfoFile
    if ($AppVersion) {
        $content = $content -replace "static const String appVersion = '.*';", "static const String appVersion = '$AppVersion';"
    }
    if ($DbVersion) {
        $content = $content -replace "static const int dbVersion = \d+;", "static const int dbVersion = $DbVersion;"
    }
    $content | Set-Content $VersionInfoFile
    Write-Host "✅ version_info.dart updated" -ForegroundColor Green
}

Write-Host "`n🚀 Pasos siguientes:"
Write-Host "1. Recompile la aplicación web: flutter build web"
Write-Host "2. Suba los cambios al servidor (Dockerfile/Nginx)"
Write-Host "3. Los usuarios verán la pantalla de bloqueo la próxima vez que abran o refresquen la app."
