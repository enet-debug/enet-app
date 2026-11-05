$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ApiUrl = 'http://127.0.0.1:8787'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw 'Node.js 22.16+ is required. Install Node.js and retry.'
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is required. Install Flutter and retry.'
}

Set-Location $Root
flutter config --enable-windows-desktop
if (-not (Test-Path (Join-Path $Root 'windows/CMakeLists.txt'))) {
  flutter create --platforms=windows .
}
flutter pub get

$ApiProcess = $null
try {
  $ApiReady = $false
  try {
    Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 2 | Out-Null
    $ApiReady = $true
    Write-Host 'Using existing eNet API on localhost:8787'
  } catch {
    $ApiProcess = Start-Process -FilePath 'node' -ArgumentList 'src/server.mjs' -WorkingDirectory (Join-Path $Root 'api') -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 15; $i++) {
      Start-Sleep -Seconds 1
      try {
        Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 2 | Out-Null
        $ApiReady = $true
        break
      } catch {}
      if ($ApiProcess.HasExited) { throw 'eNet API stopped during startup. Check Node.js and api/data permissions.' }
    }
  }
  if (-not $ApiReady) { throw 'eNet API did not start on localhost:8787.' }
  flutter run -d windows --dart-define=ENET_API_URL=$ApiUrl
} finally {
  if ($ApiProcess -and -not $ApiProcess.HasExited) {
    Stop-Process -Id $ApiProcess.Id -Force
  }
}
