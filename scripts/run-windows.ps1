$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ApiUrl = 'http://127.0.0.1:8787'
$ApiProcess = $null
$ExistingApi = $false

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw 'Node.js 22.16+ is required. Install Node.js and retry.'
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is required. Install Flutter and retry.'
}

Push-Location $Root
try {
  flutter config --enable-windows-desktop
  if (-not (Test-Path (Join-Path $Root 'windows\CMakeLists.txt'))) {
    flutter create --platforms=windows .
  }
  flutter pub get

  try {
    Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 2 | Out-Null
    $ExistingApi = $true
  } catch {}

  if ($ExistingApi) {
    try {
      Invoke-RestMethod -Uri "$ApiUrl/ready" -TimeoutSec 2 | Out-Null
    } catch {
      throw 'An older or unhealthy eNet API is already using port 8787. Stop it and retry.'
    }
    Write-Host 'Using existing eNet API on localhost:8787'
  } else {
    $ApiProcess = Start-Process -FilePath 'node' -ArgumentList 'src/server.mjs' -WorkingDirectory (Join-Path $Root 'api') -WindowStyle Hidden -PassThru
    $Ready = $false
    for ($i = 0; $i -lt 30; $i++) {
      Start-Sleep -Milliseconds 500
      if ($ApiProcess.HasExited) {
        throw 'eNet API stopped during startup. Check Node.js and api/data permissions.'
      }
      try {
        Invoke-RestMethod -Uri "$ApiUrl/ready" -TimeoutSec 2 | Out-Null
        $Ready = $true
        break
      } catch {}
    }
    if (-not $Ready) {
      throw 'eNet API did not become ready on localhost:8787.'
    }
    Write-Host "Started eNet API (PID $($ApiProcess.Id))"
  }

  flutter run -d windows --dart-define="ENET_API_URL=$ApiUrl"
} finally {
  if ($ApiProcess -and -not $ApiProcess.HasExited) {
    Stop-Process -Id $ApiProcess.Id -Force
  }
  Pop-Location
}
