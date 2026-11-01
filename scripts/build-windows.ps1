# Builds the Windows installer (NSIS setup .exe) into dist\.
# Requires Node.js 22+, Rust (rustup, MSVC toolchain) and Visual Studio C++ Build Tools.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

foreach ($tool in 'node', 'npm', 'cargo') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool was not found on PATH. See README for prerequisites." }
}

npm install --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
npx tauri icon assets/icon.svg
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed' }
node --check ui/app.js
if ($LASTEXITCODE -ne 0) { throw 'ui/app.js has a syntax error' }

Push-Location src-tauri
cargo test --release
$tests = $LASTEXITCODE
Pop-Location
if ($tests -ne 0) { throw 'Rust tests failed' }

npx tauri build --bundles nsis
if ($LASTEXITCODE -ne 0) { throw 'Tauri build failed' }

$setup = Get-ChildItem 'src-tauri\target\release\bundle\nsis\*.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) { throw 'No installer was produced' }
New-Item -ItemType Directory -Force dist | Out-Null
Copy-Item $setup.FullName dist\ -Force
Write-Host "Installer ready: dist\$($setup.Name)"
